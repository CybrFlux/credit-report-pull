#!/bin/bash
# Add a client to the "Credit Reports" vault in the standard format.
#
# Interactive (for the team; asks for the password and last 4 without showing them):
#   add_client.sh <account_uuid>
# Copy an existing 1Password login into the standard format (the original is left untouched):
#   add_client.sh <account_uuid> --copy <item_id> "<Client Full Name>"
#
# Uses your own 1Password sign-in (Touch ID), because the automation token is read-only.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ACCT="${1:?1Password account uuid}"
unset OP_SERVICE_ACCOUNT_TOKEN

if [ "${2:-}" = "--copy" ]; then
  SRC="${3:?item id to copy}"; NAME="${4:?client full name}"
  JSON=$(op item get "$SRC" --account "$ACCT" --reveal --format json | python3 -I -c "
import json,sys,re
i=json.load(sys.stdin); f=i.get('fields',[])
val=lambda pred:next((str(x.get('value') or '') for x in f if pred(x)),'')
user=val(lambda x:x.get('purpose')=='USERNAME'); pw=val(lambda x:x.get('purpose')=='PASSWORD')
last4=''
for x in f:
    v=str(x.get('value') or '').strip(); m=re.search(r'secret=([^&]+)',v); v=m.group(1) if m else v
    if (re.search(r'ssn|last ?4|last ?four',x.get('label') or '',re.I) or x.get('type')=='OTP') and re.fullmatch(r'\d{4}',v): last4=v; break
url=next((u.get('href') for u in (i.get('urls') or []) if re.search(r'identityiq|myscoreiq',u.get('href',''),re.I)),'')
site='https://member.myscoreiq.com/' if 'myscoreiq' in url.lower() else 'https://member.identityiq.com/'
if not (user and pw and last4): sys.exit('ERROR: source entry is missing username, password or a 4-digit last 4')
print(json.dumps({'title':sys.argv[1],'category':'LOGIN','urls':[{'href':site,'primary':True}],'fields':[
  {'id':'username','type':'STRING','purpose':'USERNAME','label':'username','value':user},
  {'id':'password','type':'CONCEALED','purpose':'PASSWORD','label':'password','value':pw},
  {'id':'ssn_last4','type':'CONCEALED','label':'SSN last 4','value':last4}]}))
" "$NAME")
else
  read -r -p "Client full name: " NAME
  read -r -p "Site (identityiq/myscoreiq): " SITE_IN
  read -r -p "Username: " USER_IN
  read -r -s -p "Password: " PW_IN; echo
  read -r -s -p "SSN last 4: " L4_IN; echo
  [[ "$L4_IN" =~ ^[0-9]{4}$ ]] || { echo "ERROR: last 4 must be 4 digits" >&2; exit 1; }
  SITE_KEY=$(cr_site_key "$SITE_IN"); [ -n "$SITE_KEY" ] || { echo "ERROR: site must be identityiq or myscoreiq" >&2; exit 1; }
  JSON=$(NAME="$NAME" HOST="$(cr_site_host "$SITE_KEY")" U="$USER_IN" P="$PW_IN" L="$L4_IN" python3 -I -c "
import json,os
print(json.dumps({'title':os.environ['NAME'],'category':'LOGIN','urls':[{'href':'https://'+os.environ['HOST']+'/','primary':True}],'fields':[
  {'id':'username','type':'STRING','purpose':'USERNAME','label':'username','value':os.environ['U']},
  {'id':'password','type':'CONCEALED','purpose':'PASSWORD','label':'password','value':os.environ['P']},
  {'id':'ssn_last4','type':'CONCEALED','label':'SSN last 4','value':os.environ['L']}]}))")
  unset PW_IN L4_IN
fi

printf '%s' "$JSON" | op item create - --account "$ACCT" --vault "$CR_VAULT" --format json | python3 -I -c "import json,sys;i=json.load(sys.stdin);print('added:',i['title'],'| item',i['id'],'| vault',i['vault']['name'])"
unset JSON
