#!/bin/bash
# Verify this Mac is ready to pull credit reports and post them to the portal. Changes nothing, prints
# no secrets. Run it any time: after setup, or when something stops working.
# Usage: check_setup.sh        (exit 0 = everything ready)
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"
BAD=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✘\033[0m %s\n      → %s\n' "$1" "$2"; BAD=$((BAD+1)); }

echo "This Mac"
[ "$(uname)" = "Darwin" ] && ok "macOS" || bad "not macOS" "this skill needs a Mac"
[ -d "/Applications/Google Chrome.app" ] && ok "Google Chrome" || bad "Google Chrome is missing" "install it from google.com/chrome (the pull drives a real Chrome window)"
command -v op >/dev/null && ok "1Password CLI (op)" || bad "1Password CLI is missing" "brew install 1password-cli, or download it from developer.1password.com/docs/cli/get-started"
python3 -c "import playwright" 2>/dev/null && ok "Playwright (python)" || bad "Playwright is missing" "python3 -m pip install --user playwright"
[ -x "${HERMES_HOME:-$HOME/.hermes}/skills/finance/credit-report-pull/scripts/pull_report.sh" ] && ok "skill installed in Hermes" || bad "skill is not installed in Hermes" "run scripts/install_hermes.sh from this repo"

echo "1Password"
if command -v op >/dev/null && cr_load_token 2>/dev/null; then
  if N=$("$DIR/find_client.sh" 2>/dev/null); then ok "automation token works; $(printf '%s' "$N" | grep -c .) client login(s) in the \"$CR_VAULT\" vault"
  else bad "the token is saved but could not read the \"$CR_VAULT\" vault" "run setup_automation.sh again (in your own Terminal), or check the service account in 1Password"; fi
else bad "no 1Password automation token in this Mac's Keychain" "run scripts/bootstrap_mac.sh (it offers to create one) or setup_automation.sh <account_uuid>"; fi

echo "Portal"
if cr_load_portal 2>/dev/null; then
  ok "portal address and secret are saved"
  CODE=$(curl -sS -m 30 -o /dev/null -w '%{http_code}' -X POST \
    -H "x-cybr-iq-secret: $CR_PORTAL_SECRET" -H 'Content-Type: application/json' \
    ${CR_PORTAL_APIKEY:+-H "apikey: $CR_PORTAL_APIKEY"} ${CR_PORTAL_APIKEY:+-H "Authorization: Bearer $CR_PORTAL_APIKEY"} \
    -d '{"reports":[]}' "$CR_PORTAL_URL" 2>/dev/null) || CODE=000
  case "$CODE" in
    400) ok "portal reachable and accepted the secret (this test stores nothing)" ;;
    401|403) bad "the portal refused the secret (HTTP $CODE)" "run scripts/setup_portal.sh again and type the current secret" ;;
    503) bad "the portal has no ingest secret configured yet" "an admin has to set CYBR_IQ_INGEST_SECRET on the portal's functions" ;;
    000) bad "could not reach the portal" "check this Mac's internet, and that the URL is right (it may have changed): scripts/setup_portal.sh <url>" ;;
    *)   bad "unexpected answer from the portal (HTTP $CODE)" "check the URL ends with /functions/v1/cybr-iq-ingest" ;;
  esac
else bad "the portal is not set up on this Mac" "run scripts/setup_portal.sh <ingest URL> (or scripts/bootstrap_mac.sh)"; fi

echo
if [ "$BAD" -eq 0 ]; then echo "All set. Ask Hermes: \"pull the credit report for <client name>\"."; else echo "$BAD thing(s) to fix (see → lines above)."; fi
exit $((BAD>0))
