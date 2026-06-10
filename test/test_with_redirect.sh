#!/bin/bash
# test_with_redirect.sh
#
# Validates the FULL production-equivalent pipeline:
#
#   PREROUTING nat:  port 80  → port 443   (redirect)
#   PREROUTING nat:  port 443 → port 8080  (app port, simulating 3000)
#   INPUT filter:    conntrack --ctorigdstport 80 + string match → ACCEPT/DROP
#
# KEY POINT: After PREROUTING REDIRECT the INPUT chain sees the post-NAT port
# (e.g. 8080), NOT the original port 80. Using --dport 80 in INPUT will NOT
# match. We use conntrack --ctorigdstport 80 to identify packets that were
# originally destined for port 80 before NAT rewrote them.
#
# Requires: iptables, python3, curl (all present in the test Dockerfile)
# Run inside the Docker container via: docker compose up --build

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0
APP_PORT=8080   # simulates your Node/app port (e.g. 3000 in production)
IFACE=lo

pass()  { echo -e "  ${GREEN}✓ PASS${NC}: $1"; ((PASS++)); }
fail()  { echo -e "  ${RED}✗ FAIL${NC}: $1"; ((FAIL++)); }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
note()  { echo -e "  ${YELLOW}⚠ NOTE${NC}: $1"; }
hr()    { echo "  --------------------------------------------------"; }

cleanup() {
  info "Cleaning up..."
  kill "$SERVER_PID" 2>/dev/null || true

  # Remove PREROUTING redirect rules
  iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 80 \
    -j REDIRECT --to-port 443 2>/dev/null || true
  iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 443 \
    -j REDIRECT --to-port "$APP_PORT" 2>/dev/null || true

  # Remove INPUT filter rules
  iptables -D INPUT -i "$IFACE" -p tcp \
    -m conntrack --ctorigdstport 80 \
    -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
    -j ACCEPT 2>/dev/null || true
  iptables -D INPUT -i "$IFACE" -p tcp \
    -m conntrack --ctorigdstport 80 \
    -j DROP 2>/dev/null || true

  # Remove app-port block rule
  iptables -D INPUT -i "$IFACE" -p tcp \
    -m conntrack --ctorigdstport "$APP_PORT" \
    -j DROP 2>/dev/null || true
}
trap cleanup EXIT

http_code() {
  curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 3 "$1" 2>/dev/null || echo "0"
}

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Test 2: Full Pipeline (PREROUTING REDIRECT +        ${NC}"
echo -e "${CYAN}          conntrack ctorigdstport + string match)      ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo ""
echo "  Traffic flow under test:"
echo "    client → :80 → [PREROUTING 80→443] → [PREROUTING 443→$APP_PORT] → app"
echo "    INPUT filter uses ctorigdstport to identify original-port-80 packets"
echo ""

# ── Setup ──────────────────────────────────────────────────────────────────
echo "  [Setup]"
mkdir -p /tmp/webroot2/.well-known/acme-challenge
echo "pipeline-test-token" > /tmp/webroot2/.well-known/acme-challenge/pipelinetoken
echo "<html>Home</html>"   > /tmp/webroot2/index.html

cd /tmp/webroot2
python3 -m http.server $APP_PORT >/dev/null 2>&1 &
SERVER_PID=$!
sleep 1

# Baseline: app accessible directly on APP_PORT before rules
STATUS=$(http_code "http://127.0.0.1:$APP_PORT/")
if [ "$STATUS" = "200" ]; then
  pass "Baseline: app server responding on port $APP_PORT"
else
  fail "Baseline: app server not responding on port $APP_PORT (got $STATUS) — aborting"
  exit 1
fi

# ── Apply rules ────────────────────────────────────────────────────────────
echo ""
echo "  [Applying PREROUTING REDIRECT rules]"
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80  -j REDIRECT --to-port 443
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 443 -j REDIRECT --to-port "$APP_PORT"
info "80 → 443 → $APP_PORT (PREROUTING nat)"

echo ""
echo "  [Applying INPUT filter rules (using ctorigdstport)]"

# Allow ACME challenge traffic that was originally on port 80
iptables -A INPUT -i "$IFACE" -p tcp \
  -m conntrack --ctorigdstport 80 \
  -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
  -j ACCEPT

# Block all other traffic that was originally on port 80
iptables -A INPUT -i "$IFACE" -p tcp \
  -m conntrack --ctorigdstport 80 \
  -j DROP

# Block direct access to app port from external (bypass prevention)
iptables -A INPUT -i "$IFACE" -p tcp \
  -m conntrack --ctorigdstport "$APP_PORT" \
  -j DROP

info "INPUT rules:"
iptables -L INPUT -n | grep -E "ACCEPT|DROP|conntrack" | sed 's/^/    /'
echo ""

# ── Test cases ─────────────────────────────────────────────────────────────
echo "  [Allow cases — must return HTTP 200 via port 80]"
hr

# ACME challenge via port 80 (goes through 80→443→$APP_PORT redirect chain)
STATUS=$(http_code "http://127.0.0.1:80/.well-known/acme-challenge/pipelinetoken")
[ "$STATUS" = "200" ] && pass "ACME challenge via :80 allowed (ctorigdstport=80, string match)" \
                        || fail "ACME challenge via :80 blocked (HTTP $STATUS)"

# ACME challenge direct on app port should still work (conntrack sees ctorigdst=$APP_PORT, not 80)
STATUS=$(http_code "http://127.0.0.1:$APP_PORT/.well-known/acme-challenge/pipelinetoken")
[ "$STATUS" = "200" ] \
  && note "ACME on direct app port :$APP_PORT also accessible (ctorigdst=$APP_PORT, no ACME filter applied)" \
  || note "ACME on direct app port :$APP_PORT blocked (ctorigdst=$APP_PORT DROP rule active)"

echo ""
echo "  [Block cases — must timeout/refuse]"
hr

STATUS=$(http_code "http://127.0.0.1:80/")
[ "$STATUS" = "0" ] || [ "$STATUS" = "000" ] \
  && pass "Root / via :80 blocked (ctorigdstport=80, no string match)" \
  || fail "Root / via :80 NOT blocked (HTTP $STATUS)"

STATUS=$(http_code "http://127.0.0.1:80/admin")
[ "$STATUS" = "0" ] || [ "$STATUS" = "000" ] \
  && pass "/admin via :80 blocked" \
  || fail "/admin via :80 NOT blocked (HTTP $STATUS)"

echo ""
echo "  [Direct app port access — bypass prevention]"
hr

STATUS=$(http_code "http://127.0.0.1:$APP_PORT/")
[ "$STATUS" = "0" ] || [ "$STATUS" = "000" ] \
  && pass "Direct :$APP_PORT access blocked (prevents HTTP bypass of HTTPS)" \
  || fail "Direct :$APP_PORT access NOT blocked (HTTP $STATUS) — security gap!"

echo ""
echo "  [Port 443 behavior — should redirect to app, no ACME filter]"
hr

# Port 443 traffic goes through 443→$APP_PORT but is NOT subject to the port-80 ACME filter
STATUS=$(http_code "http://127.0.0.1:443/")
if [ "$STATUS" = "200" ]; then
  pass "Port 443 traffic (redirect to app) unaffected by port-80 ACME filter"
elif [ "$STATUS" = "0" ] || [ "$STATUS" = "000" ]; then
  note "Port 443 blocked — if no TLS server is listening this is expected on loopback"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "  [Summary]"
hr
echo -e "  ${GREEN}PASSED: $PASS${NC}  |  $([ $FAIL -gt 0 ] && echo -e "${RED}FAILED: $FAIL${NC}" || echo "FAILED: $FAIL")"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
