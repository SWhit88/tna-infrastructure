#!/usr/bin/env bash
# eeg_https_setup.sh
# Stand up real browser-trusted HTTPS for the EEG Reporter dashboard using
# Tailscale Serve. Tailnet-only access, Let's Encrypt cert managed by Tailscale,
# persists across reboots, no nginx, no Cloudflare.
#
# Result: https://<p340-hostname>.<tailnet>.ts.net  -> localhost:8060
# Old URL http://100.113.163.65:8060 keeps working too (Serve is additive).

set -euo pipefail

echo "===== EEG Reporter HTTPS via Tailscale Serve ====="
echo

# 1) Sanity: tailscale installed and up
if ! command -v tailscale >/dev/null 2>&1; then
  echo "ERROR: tailscale CLI not found. Install it first: https://tailscale.com/download"
  exit 1
fi

ts_status=$(tailscale status --json 2>/dev/null || true)
if [ -z "$ts_status" ]; then
  echo "ERROR: tailscale is not running or you can't reach the daemon."
  exit 1
fi

# 2) Get the tailnet HTTPS name (e.g. leige-thinkstation-p340.tail7b3d8f.ts.net)
ts_name=$(tailscale status --json | python3 -c "
import json,sys
d=json.load(sys.stdin)
dns=d.get('Self',{}).get('DNSName','')
# DNSName has trailing dot, strip it
print(dns.rstrip('.'))
")

if [ -z "$ts_name" ]; then
  echo "ERROR: couldn't determine tailnet DNS name."
  echo "Run: tailscale status   to see what's wrong"
  exit 1
fi

echo "Tailnet HTTPS name: $ts_name"
echo

# 3) Confirm the reporter is actually running on 8060
if ! ss -ltn | awk '{print $4}' | grep -q ':8060$'; then
  echo "WARNING: nothing listening on localhost:8060 right now."
  echo "  The HTTPS proxy will still be set up, but it will 502 until the"
  echo "  reporter is started: cd ~/eeg-reporter && python3 app.py"
  echo
fi

# 4) Issue a cert proactively (so the first hit isn't slow). Idempotent.
echo "Issuing/refreshing Let's Encrypt cert via Tailscale..."
sudo tailscale cert "$ts_name" >/dev/null 2>&1 || {
  echo "  cert command returned non-zero - usually fine if a cert already exists."
  echo "  Continuing..."
}

# 5) Set up the HTTPS proxy. --bg makes it survive across reboots.
echo "Configuring Tailscale Serve: https://${ts_name} -> http://localhost:8060 ..."
sudo tailscale serve --bg --https=443 http://localhost:8060

echo
echo "===== Current Tailscale Serve config ====="
tailscale serve status

echo
echo "===== Test ====="
echo "From this P340, testing the local HTTPS endpoint..."
sleep 2
if curl -sSf -m 5 "https://${ts_name}/" -o /dev/null; then
  echo "  ✓ HTTPS responding (cert valid, proxy alive)"
else
  echo "  ⚠ HTTPS request did not return 2xx - check reporter is up and try again"
fi

echo
echo "===== DONE ====="
echo
echo "New URL (bookmark this on any tailnet device):"
echo "    https://${ts_name}"
echo
echo "Old URL still works:"
echo "    http://100.113.163.65:8060"
echo
echo "Controls:"
echo "    tailscale serve status              # show current config"
echo "    sudo tailscale serve reset          # tear it down"
echo "    sudo tailscale serve --bg --https=443 http://localhost:8060   # re-add"
