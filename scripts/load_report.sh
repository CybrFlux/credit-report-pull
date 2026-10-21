#!/bin/bash
# Open the latest credit report in the local Chrome browser and make sure every account is shown.
# The report data arrives with all accounts, but the page only renders them when its own loader
# runs (the same loader its "Download this report" button calls). Scrolling sometimes triggers it
# and sometimes doesn't, so call the loader directly and fall back to scrolling.
# Usage: load_report.sh <identityiq|myscoreiq>
set -euo pipefail
SITE="${1:?identityiq or myscoreiq}"
source "$(dirname "$0")/lib.sh"
case "$SITE" in
  identityiq) HOST=member.identityiq.com ;;
  myscoreiq)  HOST=member.myscoreiq.com ;;
  *) echo "unknown site: $SITE" >&2; exit 2 ;;
esac

js() { printf '%s' "$1" | brw eval 2>/dev/null | tail -1; }
count() { js "(document.body.innerText.match(/Account #:/g)||[]).length"; }

brw goto "https://$HOST/CreditReport.aspx" >/dev/null

# Wait for the report data (up to ~60s)
for i in $(seq 1 20); do
  READY=$(js "(()=>{try{const s=angular.element(document.getElementById('ctrlCreditReport')).scope();return s&&s.isLoaded?'yes':'no'}catch(e){return 'no'}})()")
  [ "$READY" = "yes" ] && break
  sleep 3
done

# Render every account with the page's own loader
js "(()=>{try{const s=angular.element(document.getElementById('ctrlCreditReport')).scope();s.loadLimitedTradlineList(true);s.\$apply();return 'ok'}catch(e){return 'loader unavailable'}})()" >/dev/null
sleep 4

# Fallback: scroll until the count stops changing (only if the loader didn't work)
if [ "$(count)" = "0" ]; then
  PREV=-1; SAME=0
  for i in $(seq 1 30); do
    js "window.scrollBy(0, window.innerHeight*0.8)" >/dev/null
    sleep 2
    N=$(count)
    if [ "$N" = "$PREV" ] && [ "$N" != "0" ]; then SAME=$((SAME+1)); else SAME=0; fi
    PREV=$N
    [ "$SAME" -ge 3 ] && break
  done
fi

LOADED=$(count)
INFO=$(js "(()=>{const t=document.body.innerText;const a=(t.match(/Total Accounts:([^\n]*)/)||['',''])[1].trim().split(/\s+/);const d=(t.match(/Report Date:\s*([0-9\/]+)/)||['',''])[1];return 'expected (TU EX EQ): '+a.join(' ')+' | report date: '+d})()")
echo "accounts loaded: $LOADED"
echo "$INFO"
MAX=$(echo "$INFO" | sed -E 's/.*expected \(TU EX EQ\): ([0-9 ]*).*/\1/' | tr ' ' '\n' | sort -n | tail -1)
if [ -n "$MAX" ] && [ "$LOADED" -lt "$MAX" ]; then echo "WARNING: fewer accounts loaded than expected" >&2; exit 4; fi
