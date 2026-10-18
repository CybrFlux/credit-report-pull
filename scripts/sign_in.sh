#!/bin/bash
# Sign in to IdentityIQ or MyScoreIQ in Orca's browser from a client entry in the "Credit Reports" vault,
# including the "Last four digits of your SSN?" question. Secrets go straight from 1Password into
# the page and are never printed. The site comes from the entry's website field.
# Usage: sign_in.sh <item_id>
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ITEM="${1:?1Password item id}"
cr_load_token
WORKTREE="${ORCA_WORKTREE:-name:Z3R0}"

opv() { op "$@" --vault "$CR_VAULT"; }
ref() { "$O" snapshot 2>/dev/null | grep -iE "$1" | head -1 | grep -o 'ref=e[0-9]*' | cut -d= -f2; }
url() { "$O" eval --expression "location.href" 2>/dev/null | tail -1; }

SITE=$(cr_site_key "$(opv item get "$ITEM" --format json | python3 -I -c "import json,sys;print(' '.join(u.get('href','') for u in (json.load(sys.stdin).get('urls') or [])))")")
[ -n "$SITE" ] || { echo "ERROR: entry's website must be identityiq.com or myscoreiq.com" >&2; exit 2; }
HOST=$(cr_site_host "$SITE")

"$O" tab create --url "https://$HOST/" --worktree "$WORKTREE" >/dev/null
sleep 6

USER_REF=$(ref 'textbox "Enter Username"'); PASS_REF=$(ref 'textbox "Enter Password"')
[ -n "$USER_REF" ] && [ -n "$PASS_REF" ] || { echo "ERROR: login form not found at $(url)" >&2; exit 1; }

"$O" fill --element "$USER_REF" --value "$(opv item get "$ITEM" --fields label=username)" >/dev/null
"$O" fill --element "$PASS_REF" --value "$(opv item get "$ITEM" --fields label=password --reveal)" >/dev/null
"$O" click --element "$(ref 'button "Login"')" >/dev/null
sleep 8

if url | grep -qi 'security-question'; then
  ANSWER_REF=$(ref 'textbox'); SUBMIT_REF=$(ref 'button "Submit"')
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
  "$O" fill --element "$ANSWER_REF" --value "$LAST4" >/dev/null
  unset LAST4
  "$O" click --element "$SUBMIT_REF" >/dev/null
  sleep 8
fi

NOW=$(url)
if echo "$NOW" | grep -qi 'dashboard'; then echo "signed in ($SITE): $NOW"; else echo "ERROR: not signed in, now at: $NOW" >&2; exit 1; fi
