#!/bin/bash
# Sign in to IdentityIQ or MyScoreIQ in a local Chrome browser from a client entry in the "Credit Reports" vault,
# including the "Last four digits of your SSN?" question. Secrets go straight from 1Password into
# the page and are never printed. The site comes from the entry's website field.
# Usage: sign_in.sh <item_id>
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ITEM="${1:?1Password item id}"
cr_load_token

opv() { op "$@" --vault "$CR_VAULT"; }
url() { brw url 2>/dev/null | tail -1; }

SITE=$(cr_site_key "$(opv item get "$ITEM" --format json | python3 -I -c "import json,sys;print(' '.join(u.get('href','') for u in (json.load(sys.stdin).get('urls') or [])))")")
[ -n "$SITE" ] || { echo "ERROR: entry's website must be identityiq.com or myscoreiq.com" >&2; exit 2; }
HOST=$(cr_site_host "$SITE")

brw open "https://$HOST/" >/dev/null
brw login-form >/dev/null || { echo "ERROR: login form not found at $(url)" >&2; exit 1; }
# Test hook: only confirm the login form is there, enter nothing
if [ -n "${CR_FORM_CHECK_ONLY:-}" ]; then brw login-form; exit 0; fi

# Secrets go through the environment of the one process that needs them, never argv
CR_USER="$(opv item get "$ITEM" --fields label=username)" \
CR_PASS="$(opv item get "$ITEM" --fields label=password --reveal)" brw login

if url | grep -qi 'security-question'; then
  # Standard field "SSN last 4"; older entries kept it in the one-time-password field.
  LAST4=$(opv item get "$ITEM" --reveal --format json | python3 -I -c "
import json,sys,re
fields=json.load(sys.stdin).get('fields',[])
cands=[f for f in fields if re.search(r'ssn|last ?4|last ?four',f.get('label') or '',re.I)]
cands+=[f for f in fields if f.get('type')=='OTP']
for f in cands:
    v=str(f.get('value') or '').strip()
    m=re.search(r'secret=([^&]+)',v); v=m.group(1) if m else v
    if re.fullmatch(r'\d{4}',v): print(v); break")
  if [ -z "$LAST4" ]; then echo "STOP: this entry has no 4-digit \"SSN last 4\" field - add it in 1Password" >&2; exit 3; fi
  CR_ANSWER="$LAST4" brw answer
  unset LAST4
fi

NOW=$(url)
if echo "$NOW" | grep -qi 'dashboard'; then echo "signed in ($SITE): $NOW"; else echo "ERROR: not signed in, now at: $NOW" >&2; exit 1; fi
