# Set up a Mac to pull credit reports and post them to the portal

Run on the Mac that will do the pulls (it needs a normal home/office internet connection: IdentityIQ blocks cloud servers). Hermes Agent must already be installed on it.

## The fast way (about 5 minutes)

In Terminal:

```bash
git clone -b hermes-version https://github.com/CybrFlux/credit-report-pull.git ~/credit-report-pull
cd ~/credit-report-pull
scripts/bootstrap_mac.sh
```

It installs what it can (Playwright, and Chrome / the 1Password CLI when Homebrew is there), installs the skill into Hermes, then asks you for:

| It asks | What to give it |
|---|---|
| Create the 1Password service account? | `y`, then approve with Touch ID in the 1Password app. Skip if this Mac already has the token. |
| 1Password account uuid | Press Enter (the Next Level Wealth one is built in). |
| Ingest function URL | The portal's address ending in `/functions/v1/cybr-iq-ingest`. |
| Public apikey | Only for the self-hosted VPS portal. Press Enter for the normal cloud portal. |
| Portal ingest secret | Type or paste it. It is hidden and goes straight into the Keychain. |

It finishes by running `scripts/check_setup.sh`, which prints a ✔ or ✘ for every piece and the exact fix for each ✘. When everything is ✔:

> Ask Hermes: **"pull the credit report for <client name>"**

Hermes pulls the report, saves the PDF to the Desktop, writes the summary, and posts it to the portal's **Clients → Cybr IQ Report** page. You can check the setup again any time with `scripts/check_setup.sh`.

## One-time prep that can't be scripted

1. **Each client needs an entry** in the 1Password vault **Credit Reports** (title = full name, website = identityiq.com or myscoreiq.com, username, password, field `SSN last 4`).
2. **So reports link to the right client on their own**, add an `Email` field (the client's email in the portal) and, if you have it, a `Member ID` field. Without either, the report still arrives, in the portal's **Needs match** tab for an admin to assign.

## If you'd rather do it by hand

1. Install Google Chrome and the 1Password CLI (`brew install --cask google-chrome` and `brew install 1password-cli`).
2. `python3 -m pip install --user playwright`
3. `scripts/install_hermes.sh`
4. `scripts/setup_automation.sh G5OON3EKSZEU5JMJP7T7OMF4LI` (1Password token, Touch ID once)
5. `scripts/setup_portal.sh https://<project>.supabase.co/functions/v1/cybr-iq-ingest`
6. `scripts/check_setup.sh`

## Keeping it working

| Symptom | Fix |
|---|---|
| `PORTAL REFUSED (HTTP 401)` | The portal secret changed. Run `scripts/setup_portal.sh <url>` again. |
| `could not reach the portal` | Internet down, or the portal address changed. Re-run `setup_portal.sh` with the current URL. |
| `NOT FOUND` for a client | Not in the 1Password vault yet. Add the entry. |
| `Access Denied - Error 15` | The pull is running from a cloud server or a blocked network. Run it on this Mac. |
| Nothing runs overnight | The Mac was asleep. Scheduled pulls only run while it is awake and logged in. |
| After pulling updates from GitHub | Re-run `scripts/install_hermes.sh`. |

Never paste the portal secret, a 1Password token, or a client's password into chat. Only the setup scripts above should ever receive them.
