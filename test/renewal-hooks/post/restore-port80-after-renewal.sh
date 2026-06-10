#!/bin/bash
# /etc/letsencrypt/renewal-hooks/post/restore-port80-after-renewal.sh
#
# Runs AFTER certbot completes renewal (success OR failure).
#
# Lifecycle:
#   1. Stop the HTTP app server
#   2. Remove the ACME-only INPUT filter rules
#   3. Swap iptables back: remove 80→APP_PORT, restore 80→443
#   4. Start the app in HTTPS mode
#
# Installation:
#   sudo cp this-file /etc/letsencrypt/renewal-hooks/post/
#   sudo chmod +x /etc/letsencrypt/renewal-hooks/post/restore-port80-after-renewal.sh

# ── Configuration (must match pre-hook values) ─────────────────────────────
APP_PORT=3000                         # Your app port (e.g. 3000)
NETWORK_INTERFACE=eth0                # Your network interface (ip addr to check)
APP_DIR=/home/node-user/my_web_app    # Absolute path to your app directory
APP_USER=node-user                    # Non-root user that runs the app
# ──────────────────────────────────────────────────────────────────────────

log() { logger -t certbot-post-hook "$1"; echo "[certbot-post-hook] $1"; }

log "Starting post-hook: restoring HTTPS production mode"

# ── 1. Stop the HTTP server ────────────────────────────────────────────────
log "Stopping HTTP server (npm run stop)..."
su --login "$APP_USER" --command "cd $APP_DIR && npm run stop" || true

# ── 2. Remove ACME-only INPUT filter rules ─────────────────────────────────
log "Removing ACME-only INPUT filter..."

iptables -D INPUT \
  -i "$NETWORK_INTERFACE" -p tcp \
  -m conntrack --ctorigdstport 80 \
  -m string --string "/.well-known/acme-challenge/" --algo bm --to 500 \
  -j ACCEPT 2>/dev/null || true

iptables -D INPUT \
  -i "$NETWORK_INTERFACE" -p tcp \
  -m conntrack --ctorigdstport 80 \
  -j DROP 2>/dev/null || true

# ── 3. Swap iptables back: 80 → 443 (restore production) ──────────────────
log "Restoring iptables: removing 80→${APP_PORT}, restoring 80→443..."

iptables -t nat -D PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port "$APP_PORT" 2>/dev/null || true

iptables -t nat -A PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port 443

# ── 4. Start the app in HTTPS mode ────────────────────────────────────────
log "Starting HTTPS server (npm run prod)..."
su --login "$APP_USER" --command "cd $APP_DIR && npm run prod" &

log "Post-hook complete: HTTPS production mode restored on port 80 → 443 → ${APP_PORT}"

