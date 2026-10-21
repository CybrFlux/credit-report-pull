#!/bin/bash
# ONE-TIME SETUP, run in your own Terminal: tell this Mac where the portal's ingest function is and
# store its secret in the macOS Keychain (the secret is typed hidden, never shown or saved to a file).
# Usage: setup_portal.sh <ingest function URL> [public apikey]
#   e.g. setup_portal.sh https://<project>.supabase.co/functions/v1/cybr-iq-ingest
# The optional apikey is the project's public anon key, only needed for a self-hosted gateway.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
URL="${1:?ingest function URL}"
[[ "$URL" == https://* ]] || { echo "ERROR: the URL must start with https://" >&2; exit 2; }
[[ "$URL" == */functions/v1/cybr-iq-ingest ]] || echo "note: expected the URL to end with /functions/v1/cybr-iq-ingest" >&2
umask 077
mkdir -p "$CR_SUPPORT"
{ echo "CR_PORTAL_URL=$URL"; [ -n "${2:-}" ] && echo "CR_PORTAL_APIKEY=$2"; true; } > "$CR_SUPPORT/portal.conf"
read -r -s -p "Portal ingest secret (hidden): " SECRET; echo
[ "${#SECRET}" -ge 24 ] || { echo "ERROR: that is too short to be the ingest secret (24+ characters)" >&2; exit 2; }
security add-generic-password -s "$CR_PORTAL_KEYCHAIN_SERVICE" -a "$CR_KEYCHAIN_ACCOUNT" -l "Cybr IQ portal ingest secret" -w "$SECRET" -U
unset SECRET
echo "saved: URL in $CR_SUPPORT/portal.conf, secret in the Keychain"
