#!/bin/bash
# Send the summarized report to the Next Level Wealth portal ("Cybr IQ Report" page).
# The portal links it to the client by IdentityIQ member id, then by email; anything it can't match
# lands in the page's "Needs match" tab for an admin. Re-running the same client on the same report
# date updates that report instead of creating a duplicate.
#
# Usage: post_to_portal.sh "<client name>" [report.json]
#   report.json defaults to ~/Library/Application Support/credit-report-pull/outbox/report.json
#   (the agent writes it after the pull; it is deleted after a successful post).
# Prints only a short status - never the report, email, member id or secret.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"
NAME="${1:?client name}"
REPORT="${2:-$CR_OUTBOX/report.json}"
[ -f "$REPORT" ] || { echo "STOP: no report file at $REPORT - write it first (see SKILL.md, 'Post to the portal')" >&2; exit 2; }

cr_load_token
cr_load_portal

MATCHES=$("$DIR/find_client.sh" "$NAME")
COUNT=$(printf '%s' "$MATCHES" | grep -c . || true)
if [ "$COUNT" -eq 0 ]; then echo "NOT FOUND: no client matching \"$NAME\" in the \"$CR_VAULT\" vault." >&2; exit 5
elif [ "$COUNT" -gt 1 ]; then echo "MORE THAN ONE MATCH for \"$NAME\" - use the full name:" >&2; echo "$MATCHES" >&2; exit 6; fi
ITEM=$(echo "$MATCHES" | cut -d'|' -f1 | xargs)
SITE=$(cr_site_key "$(echo "$MATCHES" | cut -d'|' -f3)")
[ -n "$SITE" ] || { echo "ERROR: could not tell IdentityIQ from MyScoreIQ for this entry" >&2; exit 2; }

TMP=$(mktemp -d); chmod 700 "$TMP"; trap 'rm -rf "$TMP"' EXIT
op item get "$ITEM" --vault "$CR_VAULT" --format json | python3 -I "$DIR/portal_payload.py" "$SITE" "$REPORT" "$TMP/payload.json"

# Secret and key go in a private header file, not on the command line.
{ printf 'x-cybr-iq-secret: %s\n' "$CR_PORTAL_SECRET"; printf 'Content-Type: application/json\n'
  [ -n "${CR_PORTAL_APIKEY:-}" ] && { printf 'apikey: %s\n' "$CR_PORTAL_APIKEY"; printf 'Authorization: Bearer %s\n' "$CR_PORTAL_APIKEY"; }
  true; } > "$TMP/headers"; chmod 600 "$TMP/headers"

CODE=$(curl -sS -m 60 -o "$TMP/response.json" -w '%{http_code}' -X POST -H "@$TMP/headers" --data-binary "@$TMP/payload.json" "$CR_PORTAL_URL") || { echo "ERROR: could not reach the portal" >&2; exit 7; }

python3 -I - "$CODE" "$TMP/response.json" <<'PY'
import json, sys
code, path = sys.argv[1], sys.argv[2]
try: body = json.load(open(path))
except Exception: body = {}
if code != "200" or not body.get("ok"):
    err = body.get("error") or (body.get("results") or [{}])[0].get("error") or "unexpected response"
    print("PORTAL REFUSED (HTTP %s): %s" % (code, str(err)[:200])); sys.exit(8)
r = body["results"][0]
status = r.get("matchStatus")
meaning = {"auto_linked": "linked to the client automatically",
           "unmatched": "no client matched - it is in the Needs match tab for an admin",
           "ambiguous": "several possible clients - it is in the Needs match tab for an admin"}.get(status, str(status))
print("posted: %s; %s" % ("new report" if r.get("created") else "updated the existing report", meaning))
PY
rm -f "$REPORT"
