#!/usr/bin/env python3
"""Build the Cybr IQ Report payload for the Next Level Wealth portal.

Reads the 1Password client entry (JSON, stdin) and the report file the agent wrote, checks
everything, and writes the payload to the path given as argv[3]. Prints only a short status:
never the report text, the email, the member id or any secret.

Usage: portal_payload.py <identityiq|myscoreiq> <report.json> <out.json>   (item JSON on stdin)

Report file (written by the agent):
{
  "reportDate": "YYYY-MM-DD",
  "scores": {"experian": 712, "equifax": 705, "transunion": 709},
  "summary": {"negativeItems": {"collections": 2, "latePayments": 3, "chargeOffs": 1},
              "utilizationPercent": 47, "inquiries": {"last2Years": 6}, "openAccounts": 9,
              "oldestAccountYears": 8, "topIssues": ["..."]},
  "summaryText": "plain-English summary"
}
"""
import datetime
import json
import re
import sys

BUREAUS = ("experian", "equifax", "transunion")
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
# Anything that looks like an SSN or a full account number must never reach the portal.
SSN_LIKE = re.compile(r"(?<!\d)\d{3}[- ]?\d{2}[- ]?\d{4}(?!\d)")
LONG_DIGITS = re.compile(r"\d{9,}")
MAX_TEXT = 20000


def fail(message):
    sys.exit("STOP: " + message)


def walk_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from walk_strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from walk_strings(v)


def field(item, *labels):
    wanted = {label.lower() for label in labels}
    for f in item.get("fields") or []:
        if (f.get("label") or "").strip().lower() in wanted:
            value = str(f.get("value") or "").strip()
            if value:
                return value
    return ""


def main():
    if len(sys.argv) != 4:
        sys.exit("usage: portal_payload.py <site> <report.json> <out.json>")
    site, report_path, out_path = sys.argv[1:4]
    item = json.load(sys.stdin)
    try:
        with open(report_path, encoding="utf-8") as fh:
            report = json.load(fh)
    except (OSError, ValueError) as exc:
        fail("the report file is missing or is not valid JSON (%s)" % type(exc).__name__)
    if not isinstance(report, dict):
        fail("the report file must be a JSON object")

    scores = report.get("scores")
    if not isinstance(scores, dict) or not scores:
        fail('"scores" must be an object like {"experian": 712, "equifax": 705, "transunion": 709}')
    clean_scores = {}
    for bureau, value in scores.items():
        if bureau not in BUREAUS:
            fail("unknown bureau in scores: %r (use experian, equifax, transunion)" % bureau)
        if value is None:
            clean_scores[bureau] = None
        elif isinstance(value, int) and not isinstance(value, bool) and 300 <= value <= 850:
            clean_scores[bureau] = value
        else:
            fail("%s score must be a whole number from 300 to 850, or null" % bureau)
    if all(v is None for v in clean_scores.values()):
        fail("at least one bureau score is required")

    summary = report.get("summary", {})
    if not isinstance(summary, dict):
        fail('"summary" must be a JSON object')
    text = report.get("summaryText")
    if not isinstance(text, str) or not text.strip():
        fail('"summaryText" (the plain-English summary) is required')
    if len(text) > MAX_TEXT:
        fail('"summaryText" is too long (limit %d characters)' % MAX_TEXT)

    for s in list(walk_strings(summary)) + [text]:
        if SSN_LIKE.search(s) or LONG_DIGITS.search(s):
            fail("the summary contains what looks like an SSN or a full account number - remove it")

    date = str(report.get("reportDate") or "")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        date = datetime.date.today().isoformat()
    try:
        datetime.date.fromisoformat(date)
    except ValueError:
        fail("reportDate is not a real date")

    # Who the report is for. Email: an "Email" field, else the login username if it is an email.
    email = field(item, "email", "e-mail", "client email")
    if not email:
        username = field(item, "username")
        email = username if EMAIL.match(username) else ""
    if email and not EMAIL.match(email):
        email = ""
    member_id = field(item, "member id", "memberid", "idiq member id", "identityiq member id")

    payload = {
        "sourceReportId": "%s:%s:%s" % (site, item.get("id", ""), date),
        "clientName": (item.get("title") or "").strip()[:200],
        "pulledAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "scores": clean_scores,
        "summary": summary,
        "summaryText": text.strip(),
    }
    if email:
        payload["email"] = email
    if member_id:
        payload["memberId"] = member_id[:100]
    if not item.get("id"):
        fail("the 1Password entry has no id")

    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh)
    print("payload ready: scores=%s, email=%s, memberId=%s, reportDate=%s" % (
        ",".join(k for k, v in clean_scores.items() if v is not None),
        "yes" if email else "NO (needs a member id or an email on the entry to auto-link)",
        "yes" if member_id else "no", date))


if __name__ == "__main__":
    main()
