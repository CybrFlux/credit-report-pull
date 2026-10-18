#!/bin/bash
# Log out of IdentityIQ or MyScoreIQ in Orca's browser and confirm it worked.
# Usage: sign_out.sh <identityiq|myscoreiq>
set -euo pipefail
SITE="${1:?identityiq or myscoreiq}"
O=/Applications/Orca.app/Contents/Resources/bin/orca
case "$SITE" in
  identityiq) HOST=member.identityiq.com ;;
  myscoreiq)  HOST=member.myscoreiq.com ;;
  *) echo "unknown site: $SITE" >&2; exit 2 ;;
esac
"$O" goto --url "https://$HOST/Logout.aspx" >/dev/null
sleep 4
NOW=$("$O" eval --expression "location.href + ' | ' + document.title" 2>/dev/null | tail -1)
if echo "$NOW" | grep -qi 'login'; then echo "signed out: $NOW"; else echo "check sign-out, now at: $NOW" >&2; exit 1; fi
