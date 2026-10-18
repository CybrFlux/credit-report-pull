#!/bin/bash
# Find a client's entry in the "Credit Reports" vault by name (partial, case-insensitive).
# No argument lists every client. Prints: item id | title | site | username. Never prints secrets.
# Usage: find_client.sh ["<client name>"]
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cr_load_token

op item list --vault "$CR_VAULT" --categories Login --format json | python3 -I -c "
import json,sys
q=sys.argv[1].lower().split()
for i in sorted(json.load(sys.stdin), key=lambda i:i.get('title','').lower()):
    t=i.get('title','')
    if all(w in t.lower() for w in q):
        url=' '.join(u.get('href','') for u in (i.get('urls') or []))
        site='MyScoreIQ' if 'myscoreiq' in url.lower() else 'IdentityIQ' if 'identityiq' in url.lower() else '?'
        print(i['id'], t, site, sep='\t')
" "${1:-}" | while IFS=$'\t' read -r ID TITLE SITE; do
  USERNAME=$(op item get "$ID" --vault "$CR_VAULT" --fields label=username 2>/dev/null || echo "?")
  echo "$ID | $TITLE | $SITE | $USERNAME"
done
