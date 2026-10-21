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
