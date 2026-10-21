#!/bin/bash
# Save the credit report currently loaded in the local Chrome browser as a PDF on the Desktop.
# Usage: save_report_pdf.sh "<Site>" "<Client Name>" "<YYYY-MM-DD>"
set -euo pipefail

SITE="${1:?site, e.g. IdentityIQ}"
CLIENT="${2:?client name}"
DATE="${3:?report date YYYY-MM-DD}"
source "$(dirname "$0")/lib.sh"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="$HOME/Desktop/Credit Report - $SITE - $CLIENT - $DATE.pdf"

TMP=$(mktemp -d)
chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

# Read the fully loaded page (read-only), drop scripts, and point relative links at the site
ORIGIN=$(echo "location.origin" | brw eval 2>/dev/null)
echo "document.documentElement.outerHTML" | brw eval 2>/dev/null | python3 -I -c "
import sys,re
v=sys.stdin.read()
v=re.sub(r'<script\b[^>]*>.*?</script>','',v,flags=re.S|re.I)
v=re.sub(r'<head([^>]*)>',r'<head\1><base href=\"'+sys.argv[2]+'/\">',v,count=1,flags=re.I)
open(sys.argv[1],'w').write(v)
print('accounts in page:',v.count('Account #:'))" "$TMP/report.html" "$ORIGIN"

"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --user-data-dir="$TMP/chrome" --virtual-time-budget=15000 \
  --print-to-pdf="$OUT" "file://$TMP/report.html" >/dev/null 2>&1

python3 -I -c "import re,sys;d=open(sys.argv[1],'rb').read();print('pages:',len(re.findall(rb'/Type\s*/Page[^s]',d)))" "$OUT"
echo "saved: $OUT"
