# iptables ACME Challenge Filter — Test Suite

Validates the `iptables` `-m string` approach for filtering port 80 traffic so that **only Let's Encrypt ACME HTTP-01 challenge requests are allowed** while all other HTTP traffic is dropped.

## Requirements

- Docker with Compose plugin (`docker compose version`)

## Run

```bash
cd test/
docker compose up --build
```

Expected exit: `0` (all tests pass). Non-zero means a test failed.

---

## What is being tested

### Test 1 — `test_string_match.sh` (basic, no redirect)

Tests the `iptables` string match in isolation with the app listening directly on port 80 (loopback interface, no NAT redirect). Validates the core claim:

| Request | Expected |
|---------|----------|
| `GET /.well-known/acme-challenge/TOKEN` | ✓ 200 allowed |
| `GET /` | ✗ blocked |
| `GET /admin` | ✗ blocked |
| `GET /?x=/.well-known/acme-challenge/foo` | ⚠ allowed (known limitation) |

Rules under test:
```bash
iptables -A INPUT -i lo -p tcp --dport 80 \
  -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
  -j ACCEPT
iptables -A INPUT -i lo -p tcp --dport 80 -j DROP
```

---

### Test 2 — `test_with_redirect.sh` (full production pipeline)

Tests the full PREROUTING REDIRECT + conntrack `--ctorigdstport` pipeline, which matches what a real server runs:

```
client → :80 → [PREROUTING 80→443] → [PREROUTING 443→8080] → app
```

**Key point:** after PREROUTING REDIRECT, the INPUT chain sees port `8080` (the app port), *not* the original port `80`. Using `--dport 80` in `INPUT` will **not** match. Use `conntrack --ctorigdstport 80` to identify packets originally destined for port 80 before NAT.

Rules under test:
```bash
# PREROUTING (NAT table)
iptables -t nat -A PREROUTING -i lo -p tcp --dport 80  -j REDIRECT --to-port 443
iptables -t nat -A PREROUTING -i lo -p tcp --dport 443 -j REDIRECT --to-port 8080

# INPUT (filter table) — use ctorigdstport, not dport
iptables -A INPUT -i lo -p tcp \
  -m conntrack --ctorigdstport 80 \
  -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
  -j ACCEPT

iptables -A INPUT -i lo -p tcp \
  -m conntrack --ctorigdstport 80 \
  -j DROP

# Block direct access to app port (prevents bypassing HTTPS)
iptables -A INPUT -i lo -p tcp \
  -m conntrack --ctorigdstport 8080 \
  -j DROP
```

| Request | Expected |
|---------|----------|
| `GET :80 /.well-known/acme-challenge/TOKEN` | ✓ 200 (via redirect chain) |
| `GET :80 /` | ✗ blocked (ctorigdstport=80, no string match) |
| `GET :80 /admin` | ✗ blocked |
| `GET :8080 /` | ✗ blocked (direct app port bypass prevented) |

---

## Known limitation

`-m string` is a substring scan — it cannot distinguish:
- `GET /.well-known/acme-challenge/token` ← legitimate
- `GET /?redirect=/.well-known/acme-challenge/token` ← also matches

For the article's threat model (blocking automated scanners during the cert renewal window), this is acceptable. Certbot's renewal window is typically a few seconds; the surface for abuse is extremely small.

To narrow the match further, you can anchor to the start of the HTTP request line using `--from 0 --to 80` and match `GET /.well-known/acme-challenge/` exactly, though this would fail for HEAD requests from some validators.
