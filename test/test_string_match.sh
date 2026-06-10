#!/bin/bash
# test_string_match.sh
#
# Validates that iptables string match (-m string) correctly:
#   ALLOWS  requests to /.well-known/acme-challenge/*
#   BLOCKS  all other port 80 traffic
#
# This test uses the loopback interface and NO PREROUTING REDIRECT.
# It tests the string match logic in isolation.
# See test_with_redirect.sh for the full PREROUTING+conntrack pipeline test.
#
# Requires: iptables, python3, curl (all present in the test Dockerfile)
# Run inside the Docker container via: docker compose up --build

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0
TEST_PORT=80
IFACE=lo

pass()  { echo -e "  ${GREEN}✓ PASS${NC}: $1"; ((PASS++)); }
fail()  { echo -e "  ${RED}✗ FAIL${NC}: $1"; ((FAIL++)); }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
note()  { echo -e "  ${YELLOW}⚠ NOTE${NC}: $1"; }
hr()    { echo "  --------------------------------------------------"; }

cleanup() {
  info "Cleaning up..."
  kill "$SERVER_PID" 2>/dev/null || true
  iptables -D INPUT -i "$IFACE" -p tcp --dport "$TEST_PORT" \
    -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
    -j ACCEPT 2>/dev/null || true
  iptables -D INPUT -i "$IFACE" -p tcp --dport "$TEST_PORT" -j DROP 2>/dev/null || true
}
trap cleanup EXIT

http_code() {
  curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 3 "$1" 2>/dev/null || echo "0"
}

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Test 1: Basic iptables String Match (no redirect)   ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo ""

# ── Setup ──────────────────────────────────────────────────────────────────
echo "  [Setup]"
mkdir -p /tmp/webroot/.well-known/acme-challenge
echo "valid-acme-token-abc123" > /tmp/webroot/.well-known/acme-challenge/validtoken
echo "second-token-xyz789"    > /tmp/webroot/.well-known/acme-challenge/secondtoken
echo "<html>Home page</html>" > /tmp/webroot/index.html
mkdir -p /tmp/webroot/admin
echo "admin panel"            > /tmp/webroot/admin/index.html

cd /tmp/webroot
python3 -m http.server $TEST_PORT >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1

# Baseline: server must respond before we add rules
STATUS=$(http_code "http://127.0.0.1:$TEST_PORT/")
if [ "$STATUS" = "200" ]; then
  pass "Baseline: HTTP server responding on port $TEST_PORT before rules"
else
  fail "Baseline: HTTP server not responding (got $STATUS) — aborting"
  exit 1
fi

# ── Apply rules ────────────────────────────────────────────────────────────
echo ""
echo "  [Rules applied]"
iptables -A INPUT -i "$IFACE" -p tcp --dport "$TEST_PORT" \
  -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
  -j ACCEPT
iptables -A INPUT -i "$IFACE" -p tcp --dport "$TEST_PORT" -j DROP

iptables -L INPUT -n | grep -E "ACCEPT|DROP" | sed 's/^/    /'
echo ""

# ── Test cases ─────────────────────────────────────────────────────────────
echo "  [Allow cases — must return HTTP 200]"
hr

STATUS=$(http_code "http://127.0.0.1:$TEST_PORT/.well-known/acme-challenge/validtoken")
[ "$STATUS" = "200" ] && pass "ACME challenge token (valid path)" \
                        || fail "ACME challenge token blocked (HTTP $STATUS)"

STATUS=$(http_code "http://127.0.0.1:$TEST_PORT/.well-known/acme-challenge/secondtoken")
[ "$STATUS" = "200" ] && pass "ACME challenge with different token" \
                        || fail "Different token blocked (HTTP $STATUS)"

echo ""
echo "  [Block cases — must timeout/refuse (code 0 or 000)]"
hr

STATUS=$(http_code "http://127.0.0.1:$TEST_PORT/")
[ "$STATUS" = "0" ] || [ "$STATUS" = "000" ] && pass "Root / blocked" \
                                               || fail "Root / NOT blocked (HTTP $STATUS)"

STATUS=$(http_code "http://127.0.0.1:$TEST_PORT/admin")
[ "$STATUS" = "0" ] || [ "$STATUS" = "000" ] && pass "/admin blocked" \
                                               || fail "/admin NOT blocked (HTTP $STATUS)"

STATUS=$(http_code "http://127.0.0.1:$TEST_PORT/index.html")
[ "$STATUS" = "0" ] || [ "$STATUS" = "000" ] && pass "/index.html blocked" \
                                               || fail "/index.html NOT blocked (HTTP $STATUS)"

echo ""
echo "  [Known limitations — documented, not failures]"
hr

# Query string bypass: GET /?x=/.well-known/acme-challenge/foo  → will match string, be ALLOWED
# This is acceptable: the threat model is blocking scanners, not adversarial bypass
STATUS=$(http_code "http://127.0.0.1:$TEST_PORT/?x=/.well-known/acme-challenge/bypass")
if [ "$STATUS" != "0" ] && [ "$STATUS" != "000" ]; then
  note "Query-string bypass allowed (HTTP $STATUS)"
  note "  GET /?x=/.well-known/acme-challenge/bypass matches the string"
  note "  Acceptable: string match is L4/L7-lite, not a full HTTP parser"
  note "  Threat model is blocking automated scanners, not targeted bypass"
else
  note "Query-string bypass was blocked — implementation may vary"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "  [Summary]"
hr
echo -e "  ${GREEN}PASSED: $PASS${NC}  |  $([ $FAIL -gt 0 ] && echo -e "${RED}FAILED: $FAIL${NC}" || echo "FAILED: $FAIL")"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
