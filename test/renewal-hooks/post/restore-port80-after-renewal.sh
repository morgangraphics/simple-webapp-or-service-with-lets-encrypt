#!/bin/bash
# /etc/letsencrypt/renewal-hooks/post/restore-port80-after-renewal.sh
#
# Runs AFTER certbot completes renewal (success or failure).
#
# Restores the production iptables rule so that port 80 redirects back to
# 443 (HTTPS upgrade), replacing the temporary validation rule added by
# pre/swap-port80-for-renewal.sh

APP_PORT=3000          # Change to your application port
NETWORK_INTERFACE=eth0 # Change to your network interface (check with: ip addr)

logger -t certbot-renewal "post-hook: restoring port 80 redirect from $APP_PORT back to 443"

# Remove the temporary validation rule (80 → APP_PORT)
iptables -t nat -D PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port "$APP_PORT" 2>/dev/null || true

# Restore the production rule (80 → 443)
iptables -t nat -A PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port 443

logger -t certbot-renewal "post-hook: port 80 restored to 443"
