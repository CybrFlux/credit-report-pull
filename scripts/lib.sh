#!/bin/bash
# Shared settings and helpers for the credit-report-pull scripts. Source it; don't run it.
#
# Client logins live in one 1Password vault, read by a 1Password *service account* whose token
# is kept in the macOS Keychain. With the token loaded, `op` never asks for Touch ID, and it can
# only read that one vault.
#
# Standard client entry (Login item in the vault):
#   title     = client's full name (e.g. "Victor Colon")
#   website   = https://member.identityiq.com or https://member.myscoreiq.com
#   username / password
#   field "SSN last 4" (concealed) = last four digits of the client's SSN

# Browser: one persistent Chrome (CDP on 127.0.0.1, own profile) driven by cr_browser.py via Playwright.
# Needs: Google Chrome, and `python3 -m pip install playwright` (uses installed Chrome, no browser download).
# CR_HEADLESS=1 runs it without a window.
CR_BROWSER_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cr_browser.py"
brw() { NODE_OPTIONS=--no-deprecation python3 "$CR_BROWSER_PY" "$@"; }
CR_VAULT="${CR_VAULT:-Credit Reports}"
CR_KEYCHAIN_SERVICE="op-service-account-credit-reports"
CR_KEYCHAIN_ACCOUNT="credit-report-pull"

# Load the service account token from the Keychain into OP_SERVICE_ACCOUNT_TOKEN.
cr_load_token() {
  if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    local t
    t=$(security find-generic-password -s "$CR_KEYCHAIN_SERVICE" -a "$CR_KEYCHAIN_ACCOUNT" -w 2>/dev/null) || true
    [ -n "$t" ] && export OP_SERVICE_ACCOUNT_TOKEN="$t"
  fi
  if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    echo "ERROR: no 1Password automation token in the Keychain. Run setup_automation.sh once." >&2
    return 1
  fi
}

# Site key / host / label from a URL or site name
cr_site_key()   { case "$(echo "$1" | tr 'A-Z' 'a-z')" in *myscoreiq*) echo myscoreiq ;; *identityiq*) echo identityiq ;; *) echo "" ;; esac; }
cr_site_host()  { case "$1" in identityiq) echo member.identityiq.com ;; myscoreiq) echo member.myscoreiq.com ;; esac; }
cr_site_label() { case "$1" in identityiq) echo IdentityIQ ;; myscoreiq) echo MyScoreIQ ;; esac; }

# ---- Portal posting (post_to_portal.sh / setup_portal.sh) ----
CR_SUPPORT="${CR_SUPPORT:-$HOME/Library/Application Support/credit-report-pull}"
CR_OUTBOX="${CR_OUTBOX:-$CR_SUPPORT/outbox}"
CR_PORTAL_KEYCHAIN_SERVICE="cybr-iq-portal-ingest-secret"

# Load the portal URL (portal.conf), optional public apikey, and the ingest secret (Keychain).
# CR_PORTAL_URL / CR_PORTAL_APIKEY / CR_PORTAL_SECRET in the environment win (used for tests).
cr_load_portal() {
  local conf="$CR_SUPPORT/portal.conf" v
  if [ -f "$conf" ]; then
    [ -n "${CR_PORTAL_URL:-}" ] || { v=$(grep -m1 '^CR_PORTAL_URL=' "$conf" | cut -d= -f2-) && CR_PORTAL_URL="$v"; } || true
    [ -n "${CR_PORTAL_APIKEY:-}" ] || { v=$(grep -m1 '^CR_PORTAL_APIKEY=' "$conf" | cut -d= -f2-) && CR_PORTAL_APIKEY="$v"; } || true
  fi
  if [ -z "${CR_PORTAL_SECRET:-}" ]; then
    CR_PORTAL_SECRET=$(security find-generic-password -s "$CR_PORTAL_KEYCHAIN_SERVICE" -a "$CR_KEYCHAIN_ACCOUNT" -w 2>/dev/null) || true
  fi
  if [ -z "${CR_PORTAL_URL:-}" ] || [ -z "${CR_PORTAL_SECRET:-}" ]; then
    echo "ERROR: the portal is not set up on this Mac. Ask the user to run setup_portal.sh <ingest URL> in their own Terminal." >&2
    return 1
  fi
  case "$CR_PORTAL_URL" in https://*) ;; *) echo "ERROR: portal URL must be https://" >&2; return 1 ;; esac
  export CR_PORTAL_URL CR_PORTAL_SECRET
  export CR_PORTAL_APIKEY="${CR_PORTAL_APIKEY:-}"
}
