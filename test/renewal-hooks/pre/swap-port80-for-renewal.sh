#!/bin/bash
# /etc/letsencrypt/renewal-hooks/pre/swap-port80-for-renewal.sh
#
# Runs BEFORE certbot attempts renewal.
#
# Lifecycle:
#   1. Stop the HTTPS app server
#   2. Swap iptables: remove 80→443, add 80→APP_PORT (plain HTTP, direct)
#   3. Add ACME-only INPUT filter: ONLY /.well-known/acme-challenge/ passes;
#      all other port-80 traffic is dropped during the validation window
#   4. Start the app in HTTP mode so it can serve the challenge file
#
# Why no 80→443 hop:
#   Let's Encrypt sends PLAIN HTTP to port 80. Routing through the TLS
#   listener (443) causes a TLS handshake failure and validation fails.
#
# Restored by: post/restore-port80-after-renewal.sh
#
# Installation:
#   sudo cp this-file /etc/letsencrypt/renewal-hooks/pre/
#   sudo chmod +x /etc/letsencrypt/renewal-hooks/pre/swap-port80-for-renewal.sh

# ── Configuration (edit these) ─────────────────────────────────────────────
APP_PORT=3000                         # Your app port (e.g. 3000)
NETWORK_INTERFACE=eth0                # Your network interface (ip addr to check)
APP_DIR=/home/node-user/my_web_app    # Absolute path to your app directory
APP_USER=node-user                    # Non-root user that runs the app
# ──────────────────────────────────────────────────────────────────────────

log() { logger -t certbot-pre-hook "$1"; echo "[certbot-pre-hook] $1"; }

log "Starting pre-hook: switching to HTTP validation mode"

# ── 1. Stop the HTTPS server ───────────────────────────────────────────────
log "Stopping HTTPS server (npm run stop)..."
su --login "$APP_USER" --command "cd $APP_DIR && npm run stop" || true

# ── 2. Swap iptables: 80 → APP_PORT (remove 80→443, add 80→APP_PORT) ──────
log "Updating iptables: removing 80→443, adding 80→${APP_PORT}..."

iptables -t nat -D PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port 443 2>/dev/null || true

iptables -t nat -A PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port "$APP_PORT"

# ── 3. Add ACME-only INPUT filter ─────────────────────────────────────────
# After PREROUTING REDIRECT (80→APP_PORT), the INPUT chain sees dst_port=APP_PORT.
# conntrack records the original dst_port=80. Use --ctorigdstport 80 to scope
# these rules ONLY to traffic that originally arrived on port 80.
log "Adding ACME-only INPUT filter on port 80..."

# ACCEPT: port-80 traffic whose payload contains the ACME challenge path
iptables -A INPUT \
  -i "$NETWORK_INTERFACE" -p tcp \
  -m conntrack --ctorigdstport 80 \
  -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
  -j ACCEPT

# DROP: all other port-80 traffic (catches both non-ACME HTTP and TCP handshake
# packets; the ACCEPT above fires first for established ACME connections)
iptables -A INPUT \
  -i "$NETWORK_INTERFACE" -p tcp \
  -m conntrack --ctorigdstport 80 \
  -j DROP

# ── 4. Start the app in HTTP mode ─────────────────────────────────────────
log "Starting HTTP server (npm run http)..."
su --login "$APP_USER" --command "cd $APP_DIR && npm run http" &
sleep 3  # Allow app time to bind to port $APP_PORT

log "Pre-hook complete: HTTP validation mode active on port 80 → ${APP_PORT} (ACME-only)"

