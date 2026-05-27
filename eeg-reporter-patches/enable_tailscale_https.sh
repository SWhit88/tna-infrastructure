#!/bin/bash
# Enable HTTPS for the EEG Reporter dashboard via Tailscale Serve.
# Result: https://leige-thinkstation-p340.tail7b3d8f.ts.net  (tailnet-only, real LE cert)
#
# Pre-reqs:
#  1. Admin console at https://login.tailscale.com/admin/dns must have:
#     - MagicDNS enabled
#     - HTTPS Certificates enabled
#  2. tailscale CLI installed (it is, you're already on the tailnet)
set -e

echo "=== Tailscale status ==="
tailscale status | head -5

echo ""
echo "=== Confirm HTTPS prerequisites enabled in admin console ==="
echo "If 'tailscale cert' below errors, go to:"
echo "  https://login.tailscale.com/admin/dns"
echo "and enable MagicDNS + HTTPS Certificates first."
echo ""

# Attempt cert (idempotent — re-fetches if needed)
HOST=$(hostname).tail7b3d8f.ts.net
echo "=== Provisioning cert for $HOST ==="
sudo tailscale cert "$HOST" 2>&1 || {
    echo ""
    echo "ERROR: cert provisioning failed. Likely fix:"
    echo "  1. Open https://login.tailscale.com/admin/dns"
    echo "  2. Enable MagicDNS"
    echo "  3. Under 'HTTPS Certificates', click 'Enable HTTPS'"
    echo "  4. Re-run this script"
    exit 1
}

echo ""
echo "=== Clearing any existing serve config ==="
sudo tailscale serve --https=443 off 2>/dev/null || true
sudo tailscale serve reset 2>/dev/null || true

echo ""
echo "=== Configuring Tailscale Serve: 443/HTTPS → 8060/HTTP ==="
sudo tailscale serve --bg --https=443 http://localhost:8060

echo ""
echo "=== Current serve status ==="
sudo tailscale serve status

echo ""
echo "=== DONE ==="
echo ""
echo "EEG Dashboard now available at:"
echo "  https://$HOST"
echo ""
echo "Old http://100.113.163.65:8060 still works (Dash itself is unchanged)."
echo "Tailscale Serve runs as a system daemon — survives reboots, auto-renews cert."
echo ""
echo "To disable HTTPS later: sudo tailscale serve --https=443 off"
