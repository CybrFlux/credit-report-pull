#!/bin/bash
# List 1Password logins for IdentityIQ / MyScoreIQ (or a client name) across every signed-in account.
# Shows account, item id, title, vault, username and last update. Never shows passwords.
# Usage: find_login.sh [search term]   (default: identityiq|myscoreiq)
#
# Note: on this Mac, `op --account <uuid>` fails for the default account ("multiple accounts
# signed in"), so each lookup falls back to running without --account. sign_in.sh does the same.
set -uo pipefail
TERM_RE="${1:-identityiq|myscoreiq}"

op_acct() {  # op_acct <uuid> <op args...>: try with --account, fall back to the default account
  local uuid="$1"; shift
  op "$@" --account "$uuid" 2>/dev/null || op "$@" 2>/dev/null
}

op account list --format json | python3 -I -c "
import json,sys
for a in json.load(sys.stdin): print(a['account_uuid'], a['email'])" | while read -r UUID EMAIL; do
  ITEMS=$(op_acct "$UUID" item list --categories Login --format json)
  # The fallback can return the default account's items for a different account; skip duplicates.
  echo "$ITEMS" | python3 -I -c "
import json,sys,re
try: items=json.load(sys.stdin)
except Exception: sys.exit(0)
term=re.compile(sys.argv[1],re.I)
for i in items:
    urls=' '.join(u.get('href','') for u in (i.get('urls') or []))
    if term.search(i.get('title','')+' '+urls):
        print(i['id'], i['title'], i.get('vault',{}).get('name',''), (i.get('updated_at') or '')[:10], sep='\t')
" "$TERM_RE" | while IFS=$'\t' read -r ID TITLE VAULT UPDATED; do
    USERNAME=$(op_acct "$UUID" item get "$ID" --fields label=username || echo "?")
    echo "account: $EMAIL | account_uuid: $UUID | item: $ID | $TITLE | $VAULT | updated $UPDATED | username: $USERNAME"
  done
done | awk -F' \\| ' '!seen[$3]++'
