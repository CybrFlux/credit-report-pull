#!/bin/bash
# One command for the whole job: find the client in the "Credit Reports" vault, sign in, load the
# full report, save the PDF to the Desktop, print the data for the summary, and always sign out.
# Usage: pull_report.sh "<client name>"
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"
NAME="${1:?client name}"

MATCHES=$("$DIR/find_client.sh" "$NAME")
COUNT=$(printf '%s' "$MATCHES" | grep -c . || true)
if [ "$COUNT" -eq 0 ]; then
  echo "NOT FOUND: no client matching \"$NAME\" in the \"$CR_VAULT\" vault. Clients on file:"; "$DIR/find_client.sh"; exit 5
elif [ "$COUNT" -gt 1 ]; then
  echo "MORE THAN ONE MATCH for \"$NAME\" - say which one:"; echo "$MATCHES"; exit 6
fi
ITEM=$(echo "$MATCHES" | cut -d'|' -f1 | xargs)
CLIENT=$(echo "$MATCHES" | cut -d'|' -f2 | xargs)
SITE=$(cr_site_key "$(echo "$MATCHES" | cut -d'|' -f3)")
echo "client: $CLIENT | site: $(cr_site_label "$SITE")"

trap '"$DIR/sign_out.sh" "$SITE" || true' EXIT

"$DIR/sign_in.sh" "$ITEM"
LOAD=$("$DIR/load_report.sh" "$SITE"); echo "$LOAD"
DATE_US=$(echo "$LOAD" | sed -nE 's/.*report date: ([0-9]{2})\/([0-9]{2})\/([0-9]{4}).*/\3-\1-\2/p')
"$DIR/save_report_pdf.sh" "$(cr_site_label "$SITE")" "$CLIENT" "${DATE_US:-$(date +%F)}"
"$DIR/extract_accounts.sh"
