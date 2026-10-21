#!/usr/bin/env python3
"""Browser helper for the credit-report-pull scripts: one persistent Google Chrome on a fixed
CDP port (127.0.0.1 only) with its own profile, driven through Playwright. Run as `python3 cr_browser.py` (not -I: Playwright lives in the user site-packages).
Secrets arrive only through environment variables (CR_USER, CR_PASS, CR_ANSWER), never argv.

Commands: open <url> | login-form | login | answer | url | goto <url> | eval (JS on stdin) | close
"""
import os, subprocess, sys, time, urllib.request
from pathlib import Path
from playwright.sync_api import sync_playwright

PORT = int(os.environ.get("CR_CDP_PORT", "9223"))
PROFILE = Path(os.environ.get("CR_PROFILE", Path.home() / "Library/Application Support/credit-report-pull/chrome-profile"))
CHROME = os.environ.get("CR_CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
CDP = f"http://127.0.0.1:{PORT}"


def chrome_up():
    try:
        urllib.request.urlopen(CDP + "/json/version", timeout=1).read()
        return True
    except Exception:
        return False


def start_chrome():
    if chrome_up():
        return
    PROFILE.mkdir(parents=True, exist_ok=True, mode=0o700)
    args = [CHROME, f"--remote-debugging-port={PORT}", "--remote-debugging-address=127.0.0.1",
            f"--user-data-dir={PROFILE}", "--no-first-run", "--no-default-browser-check", "about:blank"]
    if os.environ.get("CR_HEADLESS") == "1":
        args.insert(1, "--headless=new")
    subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(40):
        if chrome_up():
            return
        time.sleep(0.5)
    sys.exit("ERROR: Chrome did not start (CDP port %d)" % PORT)


def page_of(p):
    b = p.chromium.connect_over_cdp(CDP)
    ctx = b.contexts[0]
    pages = ctx.pages
    return b, (pages[-1] if pages else ctx.new_page())


def box(page, name):
    loc = page.get_by_role("textbox", name=name)
    return loc if loc.count() else page.get_by_placeholder(name)


def main():
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "open":
        start_chrome()
    elif cmd != "close" and not chrome_up():
        sys.exit("ERROR: browser is not running - run sign_in.sh first")
    if cmd == "close" and not chrome_up():
        return
    with sync_playwright() as p:
        b, page = page_of(p)
        if cmd == "open":
            page.goto(args[0], wait_until="domcontentloaded", timeout=60000)
            page.wait_for_timeout(4000)
            print(page.url)
        elif cmd == "login-form":
            u, w = box(page, "Enter Username"), box(page, "Enter Password")
            btn = page.get_by_role("button", name="Login")
            if not (u.count() and w.count() and btn.count()):
                sys.exit("ERROR: login form not found at " + page.url)
            print("login form found at %s: Username textbox, Password textbox, Login button" % page.url)
        elif cmd == "login":
            box(page, "Enter Username").fill(os.environ["CR_USER"])
            box(page, "Enter Password").fill(os.environ["CR_PASS"])
            page.get_by_role("button", name="Login").first.click()
            page.wait_for_timeout(8000)
        elif cmd == "answer":
            page.get_by_role("textbox").first.fill(os.environ["CR_ANSWER"])
            page.get_by_role("button", name="Submit").first.click()
            page.wait_for_timeout(8000)
        elif cmd == "url":
            print(page.url)
        elif cmd == "goto":
            page.goto(args[0], wait_until="domcontentloaded", timeout=60000)
        elif cmd == "eval":
            r = page.evaluate(sys.stdin.read())
            print("" if r is None else r)
        elif cmd == "close":
            try:
                b.new_browser_cdp_session().send("Browser.close")
            except Exception:
                pass
            return
        else:
            sys.exit("unknown command: " + cmd)


if __name__ == "__main__":
    main()
