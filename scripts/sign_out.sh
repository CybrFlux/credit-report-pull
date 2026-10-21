#!/bin/bash
# Log out of IdentityIQ or MyScoreIQ in the local Chrome browser and confirm it worked.
# Usage: sign_out.sh <identityiq|myscoreiq>
set -euo pipefail
SITE="${1:?identityiq or myscoreiq}"
source "$(dirname "$0")/lib.sh"
case "$SITE" in
  identityiq) HOST=member.identityiq.com ;;
  myscoreiq)  HOST=member.myscoreiq.com ;;
  *) echo "unknown site: $SITE" >&2; exit 2 ;;
esac
# Always close Chrome, even if the logout page fails
trap 'brw close >/dev/null 2>&1 || true' EXIT
brw url >/dev/null 2>&1 || { echo "signed out: browser was not running"; exit 0; }
brw goto "https://$HOST/Logout.aspx" >/dev/null || true
sleep 4
NOW=$(echo "location.href + ' | ' + document.title" | brw eval 2>/dev/null | tail -1 || true)
if echo "$NOW" | grep -qi 'login'; then echo "signed out: $NOW"; else echo "check sign-out, now at: $NOW" >&2; exit 1; fi
