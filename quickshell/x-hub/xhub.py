#!/usr/bin/env python3
"""Backend for the X Hub widget: plan the day's draft slots, draft posts, take reviews.

  xhub.py plan                  plan today's 5 slots (once a day) and arm a timer for each
  xhub.py draft ID              write a draft for slot ID with Grok Build (subscription), or
                                Claude Sonnet (the default ~/.claude login) when Grok's
                                usage runs out
  xhub.py reject ID [--text TEXT] [FEEDBACK]
                                reject the draft (TEXT: my edit of it) and redraft it at
                                once with the feedback
  xhub.py discard ID [REASON]   reject the topic outright and draft a new one at once
  xhub.py approve ID TEXT       post TEXT to X; the slot is done once that succeeds

This script is the only writer of slots.json; the widget watches it. Slots that are not
posted stay until they are, whatever day they belong to. Cadence follows dump's
schedule-today.sh: a daily planner arms one-shot systemd-run timers at random times.
Only one draft is staged at a time: a slot whose time comes while another is staged
waits, and approving the staged one releases the earliest waiting slot.
"""

import base64
import contextlib
import fcntl
import hashlib
import hmac
import json
import os
import random
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from datetime import time as clock
from pathlib import Path
from urllib.parse import quote
from zoneinfo import ZoneInfo

TZ = ZoneInfo("America/Chicago")
WINDOW = (clock(9), clock(21))
COUNT = 5
LIMIT = 280
STAGED = ("review", "drafting", "error")  # a slot in one of these holds the others back
KEEP_DAYS = 14  # posted slots older than this are pruned; history.jsonl keeps them
STATE = Path(os.path.expanduser("~/.local/state/x-hub"))  # slots.json
DATA = Path(
    os.path.expanduser("~/.local/share/x-hub")
)  # brief.md, credentials.json, history.jsonl
GROK = os.path.expanduser("~/.local/bin/grok")  # systemd's PATH has no ~/.local/bin
GROK_HOME = Path(os.path.expanduser("~/.grok"))  # Grok Build's login and settings
CLAUDE = "claude"  # the fallback when Grok's usage runs out
POST_SCHEMA = json.dumps(
    {
        "type": "object",
        "properties": {"post": {"type": "string"}},
        "required": ["post"],
        "additionalProperties": False,
    }
)
TWEETS = "https://api.x.com/2/tweets"

SYSTEM = (
    "You write posts for the user's X account. The audience is AI Twitter: engineers and "
    "builders who use AI tools and follow every model release. Search the web for what's "
    "new in AI this week before writing anything about news. Follow the brief, learn from "
    "my approved posts, my edits and my feedback, and never repeat a post. Reply with the "
    "post text only: no quotes, no preamble, no "
    f"commentary. Keep it as short as the brief asks; {LIMIT} characters is X's hard "
    "limit, not a target."
)


class DraftError(Exception):
    pass


class OutOfUsage(DraftError):
    pass


class PostError(Exception):
    pass


# --- storage ----------------------------------------------------------------


def load():
    try:
        return json.loads((STATE / "slots.json").read_text())
    except FileNotFoundError:
        return []


@contextlib.contextmanager
def locked():
    """Yield every slot under an exclusive lock, then write them back atomically."""
    STATE.mkdir(parents=True, exist_ok=True)
    with open(STATE / "slots.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        slots = load()
        yield slots
        tmp = STATE / "slots.json.tmp"
        tmp.write_text(json.dumps(slots, indent=1))
        os.replace(tmp, STATE / "slots.json")


def find(slots, sid):
    return next((s for s in slots if s["id"] == sid), None)


def history():
    try:
        lines = (DATA / "history.jsonl").read_text().splitlines()
    except FileNotFoundError:
        return []
    return [json.loads(line) for line in lines if line.strip()]


def remember(kind, **fields):
    DATA.mkdir(parents=True, exist_ok=True)
    with open(DATA / "history.jsonl", "a") as f:
        f.write(json.dumps({"kind": kind, "at": int(time.time()), **fields}) + "\n")


# --- side effects (replaced in tests) ---------------------------------------


def notify(summary, body, urgency="normal"):
    subprocess.run(
        ["notify-send", "-a", "X Hub", "-u", urgency, summary, body], check=False
    )


def arm(unit, when, args):
    """Run this script with args at `when` (a timestamp), or now if None, as its own unit."""
    for suffix in (".timer", ".service"):
        state = subprocess.run(
            [
                "systemctl",
                "--user",
                "show",
                "-p",
                "LoadState",
                "--value",
                unit + suffix,
            ],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
        if state == "loaded":
            return
    cmd = ["systemd-run", "--user", "--quiet", f"--unit={unit}"]
    if when is not None:
        stamp = datetime.fromtimestamp(when, TZ).strftime("%F %T")
        cmd += [
            f"--on-calendar={stamp} America/Chicago",
            "--timer-property=AccuracySec=1s",
        ]
    subprocess.run(cmd + [str(Path(__file__).resolve()), *args], check=True)


def unit_for(slot):
    return f"x-hub-draft-{slot['id']}-{slot['runs']}"


# --- planning ---------------------------------------------------------------


def plan(now=None):
    now = now or datetime.now(TZ)
    today = now.date()
    with locked() as slots:
        cutoff = (today - timedelta(days=KEEP_DAYS)).isoformat()
        slots[:] = [
            s for s in slots if not (s["status"] == "posted" and s["day"] < cutoff)
        ]
        if not any(s["day"] == today.isoformat() for s in slots):
            start = max(
                datetime.combine(today, WINDOW[0], TZ).timestamp(), now.timestamp() + 60
            )
            end = max(datetime.combine(today, WINDOW[1], TZ).timestamp(), start)
            dues = sorted(random.randint(int(start), int(end)) for _ in range(COUNT))
            for i, due in enumerate(dues, 1):
                slots.append(
                    {
                        "id": f"{today.isoformat()}-{i}",
                        "day": today.isoformat(),
                        "due": due,
                        "status": "scheduled",
                        "text": None,
                        "attempts": [],
                        "runs": 0,
                        "error": None,
                    }
                )
        todo = [
            (
                unit_for(s),
                s["due"] if s["due"] > now.timestamp() else None,
                ["draft", s["id"]],
            )
            for s in slots
            if s["status"] in ("scheduled", "waiting")
        ]
    for args in todo:
        arm(*args)


# --- drafting ---------------------------------------------------------------


def build_prompt(slots, slot):
    try:
        brief = (DATA / "brief.md").read_text().strip()
    except FileNotFoundError:
        brief = "(no brief yet)"
    past = history()
    posted = [h["text"] for h in reversed(past) if h["kind"] == "posted"][:30]
    edits = [h for h in reversed(past) if h["kind"] == "posted" and h.get("draft")][:10]
    feedback = list(
        dict.fromkeys(
            h["feedback"]
            for h in reversed(past)
            if h["kind"] == "rejected" and h.get("feedback")
        )
    )[:20]
    discarded = [h for h in reversed(past) if h["kind"] == "discarded"][:30]
    waiting = [
        s["text"]
        for s in slots
        if s is not slot and s["status"] == "review" and s["text"]
    ]

    parts = ["# Brief", brief]
    if posted:
        parts += [
            "# My approved posts (newest first). They are my voice: match their tone, "
            "length and phrasing. Never repeat or closely paraphrase one."
        ]
        parts += [f"- {t}" for t in posted]
    if edits:
        parts += [
            "# How I edited your drafts (your draft -> my version). "
            "Move your wording toward mine."
        ]
        parts += [f'- "{h["draft"]}" -> "{h["text"]}"' for h in edits]
    # Only my feedback goes in, not the rejected drafts: their text pulled every new
    # draft back to the same topic.
    if feedback:
        parts += ["# My feedback on earlier drafts. Apply it to every post."]
        parts += [f"- {f}" for f in feedback]
    if discarded:
        parts += ["# Topics rejected outright. Never write about these again."]
        parts += [
            f'- "{h["text"]}"' + (f" -> {h['reason']}" if h["reason"] else "")
            for h in discarded
        ]
    if waiting:
        parts += ["# Drafts already waiting for review. Write about something else."]
        parts += [f"- {t}" for t in waiting]
    if slot["attempts"]:
        parts += [
            "# Your earlier drafts of this post were rejected. Redraft using the feedback. "
            "A draft marked (edited by me) is my wording: build on it."
        ]
        parts += [
            f'- "{a["text"]}"'
            + (" (edited by me)" if a.get("edited") else "")
            + f" -> {a['feedback'] or '(rejected, no reason given)'}"
            for a in slot["attempts"]
        ]
    parts += ["Write the next post."]
    return "\n\n".join(parts)


def ask_grok(prompt):
    """One answer from Grok Build with only web search, no memory or ~/.claude config, on the subscription.

    Grok reads Claude Code's CLAUDE.md, skills, plugins and MCP servers from ~/.claude, so
    it runs under a throwaway HOME, with GROK_HOME keeping the grok.com login.
    """
    with tempfile.TemporaryDirectory() as tmp:
        home, cwd, file = Path(tmp, "home"), Path(tmp, "work"), Path(tmp, "prompt.txt")
        home.mkdir()
        cwd.mkdir()
        file.write_text(prompt)
        env = dict(
            os.environ,
            HOME=str(home),
            GROK_HOME=str(GROK_HOME),
            GROK_MEMORY="0",
            GROK_SUBAGENTS="0",
            XAI_API_KEY="",
        )
        cmd = [
            GROK,
            "--prompt-file",
            str(file),
            "--system-prompt-override",
            SYSTEM,
            # Web search only, so drafts can riff on this week's AI news
            "--tools",
            "web_search",
            "--disallowed-tools",
            "Agent",
            "--no-plan",
            # Room to search and open a page or two before answering
            "--max-turns",
            "6",
            "--reasoning-effort",
            "low",
            # The answer's text can carry narration ("I'll look at..."); the post is in
            # structuredOutput
            "--json-schema",
            POST_SCHEMA,
        ]
        try:
            done = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=cwd,
                env=env,
                timeout=300,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as e:
            raise DraftError(str(e)) from e
    try:
        answer = json.loads(done.stdout)
    except json.JSONDecodeError:
        detail = (done.stderr or done.stdout).strip().splitlines()
        raise DraftError(
            detail[-1] if detail else f"grok exited {done.returncode}"
        ) from None
    if "402 Payment Required" in answer.get("message", ""):
        raise OutOfUsage("Grok Build usage balance exhausted")
    text = ((answer.get("structuredOutput") or {}).get("post") or "").strip()
    if done.returncode != 0 or answer.get("stopReason") != "end_turn" or not text:
        raise DraftError(f"grok stopped: {answer.get('stopReason')}")
    if len(text) >= 2 and text[0] == text[-1] == '"':
        text = text[1:-1].strip()
    return text


def ask_claude(prompt):
    """One answer from Claude Sonnet with only web search, on the default ~/.claude login.

    --safe-mode leaves out CLAUDE.md, skills, plugins, hooks and MCP servers but keeps the
    subscription login, which --bare would skip. CLAUDE_CONFIG_DIR is dropped so a shell
    running under claude-work still uses the first subscription.
    """
    env = {
        k: v
        for k, v in os.environ.items()
        if k not in ("CLAUDE_CONFIG_DIR", "ANTHROPIC_API_KEY")
    }
    cmd = [
        CLAUDE,
        "-p",
        "--model",
        "sonnet",
        "--system-prompt",
        SYSTEM,
        "--safe-mode",
        "--strict-mcp-config",
        "--tools",
        "WebSearch",
        "--allowedTools",
        "WebSearch",
        "--no-session-persistence",
        # The structured answer takes a turn of its own after the searches
        "--max-turns",
        "8",
        "--effort",
        "low",
        "--output-format",
        "json",
        "--json-schema",
        POST_SCHEMA,
    ]
    with tempfile.TemporaryDirectory() as cwd:
        try:
            done = subprocess.run(
                cmd,
                input=prompt,
                capture_output=True,
                text=True,
                cwd=cwd,
                env=env,
                timeout=300,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as e:
            raise DraftError(str(e)) from e
    try:
        answer = json.loads(done.stdout)
    except json.JSONDecodeError:
        detail = (done.stderr or done.stdout).strip().splitlines()
        raise DraftError(
            detail[-1] if detail else f"claude exited {done.returncode}"
        ) from None
    text = ((answer.get("structured_output") or {}).get("post") or "").strip()
    if done.returncode != 0 or answer.get("subtype") != "success" or not text:
        raise DraftError(f"claude stopped: {answer.get('subtype')}")
    return text


def write_post(prompt):
    try:
        return ask_grok(prompt)
    except OutOfUsage:
        return ask_claude(prompt)


def draft(sid):
    with locked() as slots:
        slot = find(slots, sid)
        if slot is None or slot["status"] in ("review", "posted"):
            return
        # One draft at a time: wait until the staged one is posted (approve releases it)
        if any(s is not slot and s["status"] in STAGED for s in slots):
            slot["status"] = "waiting"
            return
        slot.update(status="drafting", error=None)
        prompt = build_prompt(slots, slot)
    try:
        text = write_post(prompt)
    except DraftError as e:
        with locked() as slots:
            slot = find(slots, sid)
            if slot is not None:
                slot.update(status="error", error=f"Draft failed: {e}")
        notify("X Hub: draft failed", str(e), "critical")
        return
    with locked() as slots:
        slot = find(slots, sid)
        if slot is None or slot["status"] != "drafting":
            return
        slot.update(status="review", text=text, error=None)
    notify("New X draft to review", text)


def reject(sid, feedback, text=None):
    """Redraft from the latest wording: TEXT, my edit of the draft, when given."""
    feedback = feedback.strip()
    with locked() as slots:
        slot = find(slots, sid)
        if slot is None or slot["status"] not in ("review", "error"):
            return
        if slot["text"]:
            latest = (text or "").strip() or slot["text"]
            edited = latest != slot["text"]
            slot["attempts"].append(
                {"text": latest, "feedback": feedback, "edited": edited}
            )
            if feedback:
                remember("rejected", text=latest, feedback=feedback)
        slot.update(status="drafting", text=None, error=None, runs=slot["runs"] + 1)
        unit = unit_for(slot)
    arm(unit, None, ["draft", sid])


def discard(sid, reason):
    """Reject the topic, not the wording: drop this slot's drafts and start a new topic."""
    reason = reason.strip()
    with locked() as slots:
        slot = find(slots, sid)
        if slot is None or slot["status"] != "review":
            return
        remember("discarded", text=slot["text"], reason=reason)
        slot.update(
            status="drafting", text=None, error=None, attempts=[], runs=slot["runs"] + 1
        )
        unit = unit_for(slot)
    arm(unit, None, ["draft", sid])


# --- approving --------------------------------------------------------------


def approve(sid, text):
    text = text.strip()
    release = None
    with locked() as slots:
        slot = find(slots, sid)
        if slot is None or slot["status"] != "review":
            return
        if not text:
            slot["error"] = "The post is empty."
            return
        if len(text) > LIMIT:
            slot.update(
                text=text, error=f"{len(text)} characters; the limit is {LIMIT}."
            )
            return
        slot_draft = slot["text"]  # Grok's wording, before my edit
        try:
            tweet_id = post_tweet(text)
        except PostError as e:
            slot.update(text=text, error=f"Not posted: {e}")
            return
        slot.update(
            status="posted",
            text=text,
            tweet_id=tweet_id,
            posted_at=int(time.time()),
            error=None,
        )
        fields = {"draft": slot_draft} if slot_draft != text else {}
        remember("posted", text=text, tweet_id=tweet_id, **fields)
        waiting = sorted(
            (s for s in slots if s["status"] == "waiting"), key=lambda s: s["due"]
        )
        if waiting:
            release = (unit_for(waiting[0]), None, ["draft", waiting[0]["id"]])
    if release:
        arm(*release)


def q(s):
    return quote(str(s), safe="-._~")


def oauth_header(method, url, params, creds, nonce=None, timestamp=None):
    """An OAuth 1.0a (HMAC-SHA1) Authorization header for a user-context request."""
    oauth = {
        "oauth_consumer_key": creds["api_key"],
        "oauth_nonce": nonce or secrets.token_hex(16),
        "oauth_signature_method": "HMAC-SHA1",
        "oauth_timestamp": timestamp or str(int(time.time())),
        "oauth_token": creds["access_token"],
        "oauth_version": "1.0",
    }
    pairs = sorted((q(k), q(v)) for k, v in {**params, **oauth}.items())
    base = "&".join([method.upper(), q(url), q("&".join(f"{k}={v}" for k, v in pairs))])
    key = f"{q(creds['api_secret'])}&{q(creds['access_secret'])}"
    digest = hmac.new(key.encode(), base.encode(), hashlib.sha1).digest()
    oauth["oauth_signature"] = base64.b64encode(digest).decode()
    return "OAuth " + ", ".join(f'{q(k)}="{q(v)}"' for k, v in sorted(oauth.items()))


CREDENTIALS = ("api_key", "api_secret", "access_token", "access_secret")


def post_tweet(text):
    path = DATA / "credentials.json"
    try:
        creds = json.loads(path.read_text())
    except (OSError, ValueError) as e:
        raise PostError(f"no X credentials ({', '.join(CREDENTIALS)}) in {path}") from e
    missing = [k for k in CREDENTIALS if not str(creds.get(k, "")).strip()]
    if missing:
        raise PostError(f"fill in {', '.join(missing)} in {path}")
    header = oauth_header("POST", TWEETS, {}, creds)
    req = urllib.request.Request(
        TWEETS,
        data=json.dumps({"text": text}).encode(),
        method="POST",
        headers={"Authorization": header, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)["data"]["id"]
    except urllib.error.HTTPError as e:
        raise PostError(
            f"{e.code} {e.reason}: {e.read().decode(errors='replace')[:300]}"
        ) from e
    except urllib.error.URLError as e:
        raise PostError(str(e.reason)) from e


def main(argv):
    match argv:
        case ["plan"]:
            try:
                plan()
            except Exception as e:
                notify(
                    "X Hub: planning failed",
                    f"{e}\njournalctl --user -u x-hub-plan",
                    "critical",
                )
                raise
        case ["draft", sid]:
            draft(sid)
        case ["reject", sid, "--text", text, *feedback]:
            reject(sid, " ".join(feedback), text)
        case ["reject", sid, *feedback]:
            reject(sid, " ".join(feedback))
        case ["discard", sid, *reason]:
            discard(sid, " ".join(reason))
        case ["approve", sid, text]:
            approve(sid, text)
        case _:
            sys.stderr.write(__doc__ or "")
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
