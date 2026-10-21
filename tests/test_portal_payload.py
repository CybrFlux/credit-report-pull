import json
import os
import subprocess
import sys
import tempfile
import unittest

HELPER = os.path.join(os.path.dirname(__file__), "..", "scripts", "portal_payload.py")

ITEM = {"id": "abc123", "title": "Victor Colon", "fields": [
    {"label": "username", "value": "victor@example.com"},
    {"label": "password", "value": "never-sent"},
    {"label": "SSN last 4", "value": "1234"},
    {"label": "Member ID", "value": "IQ-778899"},
]}
GOOD = {"reportDate": "2026-10-21",
        "scores": {"experian": 712, "equifax": 705, "transunion": None},
        "summary": {"utilizationPercent": 47, "topIssues": ["High utilization on 2 cards"]},
        "summaryText": "Scores 705-712. Two cards are above 80% utilization."}


def run(item, report):
    with tempfile.TemporaryDirectory() as d:
        rp, op = os.path.join(d, "r.json"), os.path.join(d, "p.json")
        with open(rp, "w") as fh:
            json.dump(report, fh)
        proc = subprocess.run([sys.executable, HELPER, "identityiq", rp, op], input=json.dumps(item),
                              capture_output=True, text=True)
        payload = None
        if proc.returncode == 0:
            with open(op) as fh:
                payload = json.load(fh)
        return proc, payload


class PortalPayload(unittest.TestCase):
    def test_good_report(self):
        proc, p = run(ITEM, GOOD)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(p["sourceReportId"], "identityiq:abc123:2026-10-21")
        self.assertEqual((p["email"], p["memberId"], p["clientName"]), ("victor@example.com", "IQ-778899", "Victor Colon"))
        self.assertEqual(p["scores"], {"experian": 712, "equifax": 705, "transunion": None})
        self.assertNotIn("never-sent", json.dumps(p))
        self.assertNotIn("1234", json.dumps(p))
        self.assertNotIn("never-sent", proc.stdout + proc.stderr)

    def test_email_field_beats_username_and_non_email_username_is_ignored(self):
        item = dict(ITEM, fields=[{"label": "username", "value": "vcolon77"}, {"label": "Email", "value": "v@x.co"}])
        self.assertEqual(run(item, GOOD)[1]["email"], "v@x.co")
        item = dict(ITEM, fields=[{"label": "username", "value": "vcolon77"}])
        self.assertNotIn("email", run(item, GOOD)[1])

    def test_scores_are_checked(self):
        for bad in ({"experian": 900}, {"experian": "712"}, {"experian": True}, {"fico": 700}, {}, {"experian": None}):
            proc, _ = run(ITEM, dict(GOOD, scores=bad))
            self.assertNotEqual(proc.returncode, 0, bad)

    def test_ssn_and_account_numbers_are_refused(self):
        for text in ("SSN 123-45-6789 on file", "account 4111111111111111 is open", "id 123456789"):
            proc, _ = run(ITEM, dict(GOOD, summaryText=text))
            self.assertNotEqual(proc.returncode, 0, text)
        proc, _ = run(ITEM, dict(GOOD, summary={"topIssues": ["card 123456789012"]}))
        self.assertNotEqual(proc.returncode, 0)
        self.assertNotIn("123456789012", proc.stdout + proc.stderr)

    def test_summary_text_required_and_date_defaults(self):
        self.assertNotEqual(run(ITEM, dict(GOOD, summaryText="  "))[0].returncode, 0)
        bad_date = run(ITEM, dict(GOOD, reportDate="soon"))[1]
        self.assertRegex(bad_date["sourceReportId"], r"^identityiq:abc123:\d{4}-\d{2}-\d{2}$")

    def test_same_client_same_day_gets_the_same_report_id(self):
        self.assertEqual(run(ITEM, GOOD)[1]["sourceReportId"], run(ITEM, GOOD)[1]["sourceReportId"])


if __name__ == "__main__":
    unittest.main()
