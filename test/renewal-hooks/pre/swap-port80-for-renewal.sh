#!/bin/bash
# /etc/letsencrypt/renewal-hooks/pre/swap-port80-for-renewal.sh
#
# Runs BEFORE certbot attempts renewal.
#
# The production iptables setup routes port 80 → 443 so all HTTP traffic
# is upgraded to HTTPS. However, Let's Encrypt HTTP-01 validation sends
# PLAIN HTTP to port 80. Routing plain HTTP through the TLS listener (443)
# causes a TLS handshake failure and the validation fails.
#
# This hook temporarily swaps the iptables rule from 80→443 to 80→APP_PORT
# so that certbot's webroot plugin can serve the challenge file over plain HTTP.
#
# Restored by: post/restore-port80-after-renewal.sh

APP_PORT=3000          # Change to your application port
NETWORK_INTERFACE=eth0 # Change to your network interface (check with: ip addr)

logger -t certbot-renewal "pre-hook: swapping port 80 redirect from 443 to $APP_PORT for ACME validation"

# Remove the production rule (80 → 443)
iptables -t nat -D PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port 443 2>/dev/null || true

# Add the validation rule (80 → APP_PORT direct, plain HTTP)
iptables -t nat -A PREROUTING \
  -i "$NETWORK_INTERFACE" -p tcp --dport 80 \
  -j REDIRECT --to-port "$APP_PORT"

logger -t certbot-renewal "pre-hook: port 80 now redirecting to $APP_PORT"
