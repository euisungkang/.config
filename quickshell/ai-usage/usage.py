#!/usr/bin/env python3
"""Fetch a plan's usage and print normalized JSON.

  usage.py claude [FILE]   Claude plan usage (same data as /usage)
  usage.py claude-work [FILE]   the same for the claude-work login (~/.claude-work)
  usage.py grok [FILE]     Grok Build / SuperGrok plan usage (same data Grok Build fetches)

Reads each CLI's OAuth token locally and sends it only to that provider: Claude Code's to
api.anthropic.com, Grok Build's to cli-chat-proxy.grok.com. Neither token is refreshed here;
the CLI refreshes its own. Pass a JSON file path as FILE to parse a saved response instead
(for testing).
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Callable, NamedTuple

CACHE_DIR = os.path.expanduser("~/.cache/ai-usage")
MIN_AGE = 240  # seconds; reuse the cached result instead of hitting the API again
DEFAULT_BACKOFF = 600  # seconds to wait after a 429 with no Retry-After header


def get_json(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def window(d):
    if not d:
        return None
    return {"percent": d.get("utilization"), "resets_at": d.get("resets_at")}


def fetch_claude(config_dir="~/.claude"):
    with open(os.path.expanduser(config_dir + "/.credentials.json")) as f:
        token = json.load(f)["claudeAiOauth"]["accessToken"]
    return get_json(
        "https://api.anthropic.com/api/oauth/usage",
        {"Authorization": f"Bearer {token}", "anthropic-beta": "oauth-2025-04-20"},
    )


def normalize_claude(d):
    return {
        "session": window(d.get("five_hour")),
        "weekly": window(d.get("seven_day")),
        "breakdown": [
            {"name": r["display_name"], "percent": r["percent"]}
            for r in (d.get("seven_day_breakdown") or {}).get("rows", [])
        ],
    }


def fetch_grok():
    # One entry per login scope ("https://auth.x.ai::<client id>")
    with open(os.path.expanduser("~/.grok/auth.json")) as f:
        token = next(iter(json.load(f).values()))["key"]
    # Undocumented: the endpoint Grok Build itself calls for its credits config
    return get_json(
        "https://cli-chat-proxy.grok.com/v1/billing?format=credits",
        {"Authorization": f"Bearer {token}"},
    )


def normalize_grok(d):
    c = d["config"]
    # Grok has one pool per period (weekly so far) and no session window; a field that is
    # zero is left out of the response
    return {
        "session": None,
        "weekly": {
            "percent": c.get("creditUsagePercent", 0),
            "resets_at": (c.get("currentPeriod") or {}).get("end"),
        },
        "breakdown": [
            {"name": p["product"], "percent": p.get("usagePercent", 0)}
            for p in c.get("productUsage", [])
        ],
    }


class Provider(NamedTuple):
    fetch: Callable[[], dict]
    normalize: Callable[[dict], dict]
    app: str  # the CLI whose login holds the token


PROVIDERS = {
    "claude": Provider(fetch_claude, normalize_claude, "Claude Code"),
    "claude-work": Provider(
        lambda: fetch_claude("~/.claude-work"), normalize_claude, "claude-work"
    ),
    "grok": Provider(fetch_grok, normalize_grok, "Grok"),
}


def load_cache(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(path, c):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(c, f)


def report(name, force=False):
    p = PROVIDERS[name]
    path = os.path.join(CACHE_DIR, name + ".json")
    cache = load_cache(path)
    now = time.time()
    result = cache.get("result")

    if (
        not force
        and result
        and (
            now - cache.get("fetched_at", 0) < MIN_AGE
            or now < cache.get("retry_until", 0)
        )
    ):
        return result

    if not force and now < cache.get("retry_until", 0):
        return {"error": "Rate limited - retrying later"}

    try:
        result = p.normalize(p.fetch())
        save_cache(path, {"result": result, "fetched_at": now})
        return result
    except urllib.error.HTTPError as e:
        if e.code == 429:
            try:
                wait = int(e.headers.get("Retry-After", DEFAULT_BACKOFF))
            except ValueError:
                wait = DEFAULT_BACKOFF
            cache["retry_until"] = now + max(wait, 60)
            save_cache(path, cache)
            # keep showing the last good numbers rather than an error
            return result or {"error": "Rate limited - retrying later"}
        if e.code == 401:
            return {"error": f"Token expired - open {p.app} to refresh"}
        return {"error": f"HTTP {e.code}"}
    except Exception as e:
        return {"error": type(e).__name__}


def main(argv):
    force = "--force" in argv
    argv = [a for a in argv if a != "--force"]
    name = argv[0]
    if len(argv) > 1:
        with open(argv[1]) as f:
            print(json.dumps(PROVIDERS[name].normalize(json.load(f))))
        return
    print(json.dumps(report(name, force)))


if __name__ == "__main__":
    main(sys.argv[1:])
