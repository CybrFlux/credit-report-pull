#!/bin/bash
# One-shot setup for a Mac that will run the credit-report automation under Hermes Agent.
# Run it in your own Terminal (it asks a few questions; secrets are typed hidden):
#     cd ~/credit-report-pull && git checkout hermes-version && scripts/bootstrap_mac.sh
# Safe to re-run: it skips whatever is already done, then finishes with check_setup.sh.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"
say()  { printf '\n\033[1m== %s\033[0m\n' "$1"; }
ask()  { local a; read -r -p "$1 " a; echo "$a"; }
yes()  { local a; read -r -p "$1 [y/N] " a; [[ "$a" =~ ^[Yy] ]]; }
NEED=()

[ "$(uname)" = "Darwin" ] || { echo "This setup is for macOS."; exit 1; }
[ -d "$HOME/.hermes" ] || { echo "Hermes Agent is not installed on this Mac (no ~/.hermes). Install Hermes first, then run this again."; exit 1; }

say "1. Google Chrome"
if [ -d "/Applications/Google Chrome.app" ]; then echo "already installed"
elif command -v brew >/dev/null; then brew install --cask google-chrome || NEED+=("Install Google Chrome from google.com/chrome")
else NEED+=("Install Google Chrome from google.com/chrome"); fi

say "2. 1Password CLI"
if command -v op >/dev/null; then echo "already installed ($(op --version))"
elif command -v brew >/dev/null; then brew install 1password-cli || NEED+=("Install the 1Password CLI: developer.1password.com/docs/cli/get-started")
else NEED+=("Install the 1Password CLI: developer.1password.com/docs/cli/get-started (Homebrew isn't installed here)"); fi

say "3. Playwright (drives Chrome)"
if python3 -c "import playwright" 2>/dev/null; then echo "already installed"
else python3 -m pip install --user --quiet playwright && echo "installed" || NEED+=("Run: python3 -m pip install --user playwright"); fi

say "4. Install the skill into Hermes"
"$DIR/install_hermes.sh" || NEED+=("scripts/install_hermes.sh failed - see the message above")

say "5. 1Password access for the automation"
if security find-generic-password -s "$CR_KEYCHAIN_SERVICE" -a "$CR_KEYCHAIN_ACCOUNT" >/dev/null 2>&1; then
  echo "this Mac already has the 1Password automation token"
elif ! command -v op >/dev/null; then
  NEED+=("After installing the 1Password CLI, run scripts/bootstrap_mac.sh again (it sets up the 1Password token)")
else
  echo "This Mac needs its own read-only 1Password service account (it can only read the \"$CR_VAULT\" vault)."
  echo "You will be asked to approve in the 1Password app (Touch ID)."
  if yes "Create it now?"; then
    ACCT=$(ask "1Password account uuid for Next Level Wealth [press Enter for the one in SKILL.md]:")
    ACCT="${ACCT:-G5OON3EKSZEU5JMJP7T7OMF4LI}"
    "$DIR/setup_automation.sh" "$ACCT" || NEED+=("1Password setup failed - run: scripts/setup_automation.sh $ACCT")
  else NEED+=("Later: scripts/setup_automation.sh <account_uuid>"); fi
fi

say "6. Portal connection"
if [ -f "$CR_SUPPORT/portal.conf" ] && security find-generic-password -s "$CR_PORTAL_KEYCHAIN_SERVICE" -a "$CR_KEYCHAIN_ACCOUNT" >/dev/null 2>&1; then
  echo "already set up ($(grep -m1 '^CR_PORTAL_URL=' "$CR_SUPPORT/portal.conf" | cut -d= -f2- | sed -E 's#(https://[^/]+).*#\1/...#'))"
  yes "Change it?" && { URL=$(ask "Ingest function URL (https://.../functions/v1/cybr-iq-ingest):"); KEY=$(ask "Public apikey (only for a self-hosted portal; Enter to skip):"); "$DIR/setup_portal.sh" "$URL" $KEY; }
else
  URL=$(ask "Ingest function URL (https://.../functions/v1/cybr-iq-ingest):")
  KEY=$(ask "Public apikey (only for a self-hosted portal; Enter to skip):")
  if [ -n "$URL" ]; then "$DIR/setup_portal.sh" "$URL" $KEY || NEED+=("Portal setup failed - run: scripts/setup_portal.sh <url>")
  else NEED+=("Later: scripts/setup_portal.sh <ingest URL>"); fi
fi

say "7. Check everything"
"$DIR/check_setup.sh"; RC=$?
if [ "${#NEED[@]}" -gt 0 ]; then printf '\nStill to do by hand:\n'; printf '  - %s\n' "${NEED[@]}"; fi
exit $RC
