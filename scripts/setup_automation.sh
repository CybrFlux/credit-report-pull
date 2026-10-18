#!/bin/bash
# ONE-TIME SETUP (asks for Touch ID once): create the "Credit Reports" vault, create a read-only
# 1Password service account for it, and store its token in the macOS Keychain.
# After this, the other scripts never need Touch ID.
# Usage: setup_automation.sh <account_uuid>
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ACCT="${1:?1Password account uuid (Next Level Wealth)}"
unset OP_SERVICE_ACCOUNT_TOKEN

if op vault get "$CR_VAULT" --account "$ACCT" >/dev/null 2>&1; then
  echo "vault \"$CR_VAULT\" already exists"
else
  op vault create "$CR_VAULT" --account "$ACCT" --description "Client logins for credit-report automation (read by a service account)" >/dev/null
  echo "created vault \"$CR_VAULT\""
fi

if security find-generic-password -s "$CR_KEYCHAIN_SERVICE" -a "$CR_KEYCHAIN_ACCOUNT" >/dev/null 2>&1; then
  echo "a token is already in the Keychain - delete it first to make a new one:"
  echo "  security delete-generic-password -s $CR_KEYCHAIN_SERVICE -a $CR_KEYCHAIN_ACCOUNT"
  exit 0
fi

# The token is printed by 1Password only once; capture it straight into the Keychain, never to the screen.
TOKEN=$(op service-account create "Credit Report Automation" --account "$ACCT" --vault "$CR_VAULT:read_items" --raw)
[[ "$TOKEN" == ops_* ]] || { echo "ERROR: service account was not created" >&2; exit 1; }
security add-generic-password -s "$CR_KEYCHAIN_SERVICE" -a "$CR_KEYCHAIN_ACCOUNT" -l "1Password - Credit Report Automation" -w "$TOKEN" -U
unset TOKEN
echo "service account \"Credit Report Automation\" created (read-only, \"$CR_VAULT\" vault only); token saved to the macOS Keychain"

cr_load_token
op vault list --format json | python3 -I -c "import json,sys;print('token check - vaults it can see:',[v['name'] for v in json.load(sys.stdin)])"
