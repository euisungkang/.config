"""Tests for usage.py: normalizing each provider's response, the cache and HTTP errors.

No real request is made: each provider's `fetch` is replaced with a stub.
"""

import io
import json
import sys
import urllib.error
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import usage  # noqa: E402

GROK = {
    "config": {
        "currentPeriod": {
            "type": "USAGE_PERIOD_TYPE_WEEKLY",
            "start": "2026-11-03T22:19:29.515+00:00",
            "end": "2026-11-10T22:19:29.515+00:00",
        },
        "creditUsagePercent": 12.5,
        "productUsage": [{"product": "GrokBuild", "usagePercent": 12.5}],
        "isUnifiedBillingUser": True,
        "prepaidBalance": {"val": 0},
    }
}

CLAUDE = {
    "five_hour": {"utilization": 48.0, "resets_at": "2026-11-03T20:00:00+00:00"},
    "seven_day": {"utilization": 71.0, "resets_at": "2026-11-07T00:00:00+00:00"},
    "seven_day_breakdown": {"rows": [{"display_name": "Opus", "percent": 30.0}]},
}


def test_grok_has_one_weekly_window():
    assert usage.normalize_grok(GROK) == {
        "session": None,
        "weekly": {"percent": 12.5, "resets_at": "2026-11-10T22:19:29.515+00:00"},
        "breakdown": [{"name": "GrokBuild", "percent": 12.5}],
    }


def test_grok_with_no_usage_yet_reads_zero():
    config = {k: v for k, v in GROK["config"].items() if k != "creditUsagePercent"}
    assert usage.normalize_grok({"config": config})["weekly"]["percent"] == 0


def test_claude_has_session_and_weekly_windows():
    assert usage.normalize_claude(CLAUDE) == {
        "session": {"percent": 48.0, "resets_at": "2026-11-03T20:00:00+00:00"},
        "weekly": {"percent": 71.0, "resets_at": "2026-11-07T00:00:00+00:00"},
        "breakdown": [{"name": "Opus", "percent": 30.0}],
    }


@pytest.fixture
def run(tmp_path, monkeypatch, capsys):
    """Run usage.main for a provider whose fetch returns or raises `answer`."""
    monkeypatch.setattr(usage, "CACHE_DIR", str(tmp_path))
    calls = []

    def go(name, answer, now=1000.0):
        def fetch():
            calls.append(name)
            if isinstance(answer, Exception):
                raise answer
            return answer

        monkeypatch.setitem(
            usage.PROVIDERS, name, usage.PROVIDERS[name]._replace(fetch=fetch)
        )
        monkeypatch.setattr(usage.time, "time", lambda: now)
        usage.main([name])
        return json.loads(capsys.readouterr().out)

    go.calls = calls
    return go


def http_error(code, headers=None):
    return urllib.error.HTTPError("u", code, "x", headers or {}, io.BytesIO())


def test_fetches_then_reuses_the_cache(run):
    first = run("grok", GROK)
    assert run("grok", GROK, now=1100.0) == first
    assert run.calls == ["grok"]


def test_providers_have_separate_caches(run):
    run("grok", GROK)
    assert run("claude", CLAUDE)["session"]["percent"] == 48.0
    assert run.calls == ["grok", "claude"]


def test_expired_grok_login_says_to_open_grok(run):
    assert run("grok", http_error(401)) == {
        "error": "Token expired - open Grok to refresh"
    }


def test_claude_work_sends_the_work_login(tmp_path, monkeypatch):
    for d, token in [(".claude", "personal"), (".claude-work", "work")]:
        (tmp_path / d).mkdir()
        (tmp_path / d / ".credentials.json").write_text(
            json.dumps({"claudeAiOauth": {"accessToken": token}})
        )
    monkeypatch.setenv("HOME", str(tmp_path))
    sent = []
    monkeypatch.setattr(
        usage, "get_json", lambda url, headers: sent.append(headers["Authorization"])
    )
    usage.PROVIDERS["claude-work"].fetch()
    usage.PROVIDERS["claude"].fetch()
    assert sent == ["Bearer work", "Bearer personal"]


def test_expired_claude_work_login_says_to_open_claude_work(run):
    assert run("claude-work", http_error(401)) == {
        "error": "Token expired - open claude-work to refresh"
    }


def test_claude_accounts_have_separate_caches(run):
    run("claude", CLAUDE)
    assert run("claude-work", CLAUDE)["weekly"]["percent"] == 71.0
    assert run.calls == ["claude", "claude-work"]


def test_rate_limit_keeps_the_last_numbers(run):
    good = run("grok", GROK)
    assert run("grok", http_error(429, {"Retry-After": "30"}), now=2000.0) == good
    # within the backoff, no request is made
    assert run("grok", GROK, now=2050.0) == good
    assert run.calls == ["grok", "grok"]


def test_saved_response_file_is_normalized(tmp_path, capsys):
    saved = tmp_path / "grok.json"
    saved.write_text(json.dumps(GROK))
    usage.main(["grok", str(saved)])
    assert json.loads(capsys.readouterr().out)["weekly"]["percent"] == 12.5


def test_force_refetches_despite_a_fresh_cache(run, monkeypatch, capsys):
    run("grok", GROK)
    monkeypatch.setattr(usage.time, "time", lambda: 1100.0)
    usage.main(["grok", "--force"])
    assert run.calls == ["grok", "grok"]


def test_force_ignores_the_rate_limit_backoff(run, monkeypatch):
    run("grok", http_error(429, {"Retry-After": "600"}))
    run("grok", GROK, now=1100.0)  # still backing off: no request
    monkeypatch.setattr(usage.time, "time", lambda: 1100.0)
    usage.main(["grok", "--force"])
    assert run.calls == ["grok", "grok"]
