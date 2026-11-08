"""Tests for xhub.py: planning, drafting, rejecting, approving, and OAuth signing.

No real model, systemd or X call is made: `grok` and `claude` are stub scripts on disk, and
`arm`, `notify` and `post_tweet` are replaced with recorders.
"""

import json
import stat
import sys
from datetime import datetime
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import xhub  # noqa: E402

TZ = xhub.TZ


def at(text):
    return datetime.fromisoformat(text).replace(tzinfo=TZ)


@pytest.fixture
def hub(tmp_path, monkeypatch):
    monkeypatch.setattr(xhub, "STATE", tmp_path / "state")
    monkeypatch.setattr(xhub, "DATA", tmp_path / "data")
    (tmp_path / "data").mkdir()
    (tmp_path / "data" / "brief.md").write_text("Voice: dry. Topics: Rust, testing.\n")
    armed, notes, posts = [], [], []
    monkeypatch.setattr(
        xhub, "arm", lambda unit, when, args: armed.append((unit, when, args))
    )
    monkeypatch.setattr(xhub, "notify", lambda *a, **k: notes.append(a))

    def post(text):
        posts.append(text)
        return "1850000000000000001"

    monkeypatch.setattr(xhub, "post_tweet", post)
    return type(
        "Hub", (), {"armed": armed, "notes": notes, "posts": posts, "tmp": tmp_path}
    )


@pytest.fixture
def stub_grok(tmp_path, monkeypatch):
    """A fake `grok` that records its argv, prompt file and env, then prints JSON."""
    log = tmp_path / "grok.log"
    script = tmp_path / "grok"
    script.write_text(
        "#!/usr/bin/env bash\n"
        f'printf "%s\\n" "$@" > {log}.argv\n'
        'while [ "$#" -gt 0 ]; do\n'
        f'  [ "$1" = --prompt-file ] && cp "$2" {log}.prompt\n'
        "  shift\n"
        "done\n"
        f"env > {log}.env\n"
        # The default is a variable: a "}" inside ${STUB_JSON:-...} would end it early
        # Grok's text can carry narration ("I'll look at..."); the post is in structuredOutput
        'reply=\'{"text": "I will look at the posts.", "stopReason": "end_turn", '
        '"structuredOutput": {"post": "Tests that never fail are not tests."}}\'\n'
        'echo "${STUB_JSON:-$reply}"\n'
        "exit ${STUB_EXIT:-0}\n"
    )
    script.chmod(script.stat().st_mode | stat.S_IEXEC)
    monkeypatch.setattr(xhub, "GROK", str(script))
    monkeypatch.setenv("XAI_API_KEY", "xai-should-not-leak")
    return log


@pytest.fixture
def stub_claude(tmp_path, monkeypatch):
    """A fake `claude` that records its argv, stdin and env, then prints JSON."""
    log = tmp_path / "claude.log"
    script = tmp_path / "claude"
    script.write_text(
        "#!/usr/bin/env bash\n"
        f'printf "%s\\n" "$@" > {log}.argv\n'
        f"cat > {log}.prompt\n"
        f"env > {log}.env\n"
        'reply=\'{"type": "result", "subtype": "success", "is_error": false, '
        '"structured_output": {"post": "the agent fixed it by deleting it"}}\'\n'
        'echo "${STUB_CLAUDE_JSON:-$reply}"\n'
        "exit ${STUB_CLAUDE_EXIT:-0}\n"
    )
    script.chmod(script.stat().st_mode | stat.S_IEXEC)
    monkeypatch.setattr(xhub, "CLAUDE", str(script))
    # This shell may run under claude-work; the fallback must use the default login
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(tmp_path / ".claude-work"))
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-should-not-leak")
    return log


GROK_OUT_OF_USAGE = json.dumps(
    {
        "type": "error",
        "message": 'Internal error: {\n  "message": "API error (status 402 Payment '
        'Required): Grok Build usage balance exhausted",\n  "http_status": 402\n}',
    }
)


def slots():
    return xhub.load()


# --- planning ---------------------------------------------------------------


def test_plan_makes_five_sorted_slots_inside_the_window(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    day = slots()
    assert len(day) == 5
    dues = [s["due"] for s in day]
    assert dues == sorted(dues)
    for s in day:
        due = datetime.fromtimestamp(s["due"], TZ)
        assert at("2026-11-03T09:00:00") <= due <= at("2026-11-03T21:00:00")
        assert s["day"] == "2026-11-03"
        assert s["status"] == "scheduled"
    assert len({s["id"] for s in day}) == 5


def test_plan_arms_one_timer_per_future_slot(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    assert len(hub.armed) == 5
    for (unit, when, args), s in zip(hub.armed, slots()):
        assert when == s["due"]
        assert args == ["draft", s["id"]]
        assert unit.startswith("x-hub-draft-")


def test_plan_is_once_per_day(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    first = slots()
    xhub.plan(at("2026-11-03T08:00:00"))
    assert slots() == first


def test_plan_after_9am_uses_what_is_left_of_the_window(hub):
    now = at("2026-11-03T15:00:00")
    xhub.plan(now)
    assert all(s["due"] > now.timestamp() for s in slots())


def test_plan_after_9pm_still_makes_five_slots_due_soon(hub):
    now = at("2026-11-03T22:30:00")
    xhub.plan(now)
    assert len(slots()) == 5
    assert all(s["due"] <= now.timestamp() + 60 for s in slots())


def test_plan_drafts_missed_slots_at_once(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    hub.armed.clear()
    xhub.plan(at("2026-11-03T23:00:00"))  # machine was off all day
    assert len(hub.armed) == 5
    assert all(when is None for _, when, _ in hub.armed)


def test_plan_keeps_unfinished_days_and_adds_the_next(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    xhub.plan(at("2026-11-04T00:05:00"))
    days = [s["day"] for s in slots()]
    assert days.count("2026-11-03") == 5
    assert days.count("2026-11-04") == 5


def test_plan_prunes_posted_slots_older_than_two_weeks(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    with xhub.locked() as all_slots:
        for s in all_slots:
            s["status"] = "posted"
    xhub.plan(at("2026-11-18T00:05:00"))
    assert {s["day"] for s in slots()} == {"2026-11-18"}


# --- drafting ---------------------------------------------------------------


def planned(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    return slots()[0]["id"]


def test_draft_failure_is_shown_on_the_slot(hub, monkeypatch):
    monkeypatch.setattr(xhub, "GROK", "/bin/false")
    sid = planned(hub)
    xhub.draft(sid)
    s = xhub.find(slots(), sid)
    assert s["status"] == "error"
    assert s["error"]


def test_grok_draft_puts_its_answer_up_for_review(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    s = xhub.find(slots(), sid)
    assert s["status"] == "review"
    assert s["text"] == "Tests that never fail are not tests."
    assert (
        "Voice: dry. Topics: Rust, testing." in Path(f"{stub_grok}.prompt").read_text()
    )


def test_grok_runs_isolated_on_the_subscription(hub, stub_grok):
    xhub.draft(planned(hub))
    argv = Path(f"{stub_grok}.argv").read_text().splitlines()
    assert argv[argv.index("--system-prompt-override") + 1] == xhub.SYSTEM
    # Web search only, so drafts can riff on this week's AI news
    assert argv[argv.index("--tools") + 1] == "web_search"
    assert argv[argv.index("--disallowed-tools") + 1] == "Agent"
    assert "--disable-web-search" not in argv
    # Room to search and open a page or two before answering
    assert argv[argv.index("--max-turns") + 1] == "6"
    assert argv[argv.index("--reasoning-effort") + 1] == "low"
    schema = json.loads(argv[argv.index("--json-schema") + 1])
    assert schema["required"] == ["post"]
    env = dict(
        line.split("=", 1)
        for line in Path(f"{stub_grok}.env").read_text().splitlines()
        if "=" in line
    )
    assert env["XAI_API_KEY"] == ""
    # A throwaway HOME hides ~/.claude (CLAUDE.md, skills, plugins, MCP); the login stays
    assert env["HOME"] != str(Path.home())
    assert env["GROK_HOME"] == str(xhub.GROK_HOME)
    assert env["GROK_MEMORY"] == "0"


def test_grok_strips_wrapping_quotes(hub, stub_grok, monkeypatch):
    monkeypatch.setenv(
        "STUB_JSON",
        '{"stopReason": "end_turn", "structuredOutput": {"post": "\\"ship small.\\""}}',
    )
    sid = planned(hub)
    xhub.draft(sid)
    assert xhub.find(slots(), sid)["text"] == "ship small."


def test_grok_runs_by_full_path():
    # systemd's user PATH has no ~/.local/bin, where Grok Build installs
    assert Path(xhub.GROK).is_absolute()


def test_grok_unfinished_answer_is_an_error(hub, stub_grok, monkeypatch):
    monkeypatch.setenv(
        "STUB_JSON",
        '{"text": "I\'ll look at the posts.", "stopReason": "max_turn_requests"}',
    )
    monkeypatch.setenv("STUB_EXIT", "1")
    sid = planned(hub)
    xhub.draft(sid)
    s = xhub.find(slots(), sid)
    assert s["status"] == "error"
    assert "max_turn_requests" in s["error"]


def test_grok_out_of_usage_falls_back_to_claude(
    hub, stub_grok, stub_claude, monkeypatch
):
    monkeypatch.setenv("STUB_JSON", GROK_OUT_OF_USAGE)
    monkeypatch.setenv("STUB_EXIT", "1")
    sid = planned(hub)
    xhub.draft(sid)
    s = xhub.find(slots(), sid)
    assert s["status"] == "review"
    assert s["text"] == "the agent fixed it by deleting it"
    assert (
        Path(f"{stub_claude}.prompt").read_text()
        == Path(f"{stub_grok}.prompt").read_text()
    )


def test_claude_runs_isolated_on_the_default_subscription(
    hub, stub_grok, stub_claude, monkeypatch
):
    monkeypatch.setenv("STUB_JSON", GROK_OUT_OF_USAGE)
    monkeypatch.setenv("STUB_EXIT", "1")
    xhub.draft(planned(hub))
    argv = Path(f"{stub_claude}.argv").read_text().splitlines()
    assert "-p" in argv
    assert argv[argv.index("--model") + 1] == "sonnet"
    assert argv[argv.index("--system-prompt") + 1] == xhub.SYSTEM
    # No CLAUDE.md, skills, plugins, hooks or MCP servers; web search only
    assert "--safe-mode" in argv
    assert "--strict-mcp-config" in argv
    assert argv[argv.index("--tools") + 1] == "WebSearch"
    assert argv[argv.index("--allowedTools") + 1] == "WebSearch"
    assert "--no-session-persistence" in argv
    schema = json.loads(argv[argv.index("--json-schema") + 1])
    assert schema["required"] == ["post"]
    env = dict(
        line.split("=", 1)
        for line in Path(f"{stub_claude}.env").read_text().splitlines()
        if "=" in line
    )
    # The default ~/.claude login, on the subscription, not claude-work or an API key
    assert "CLAUDE_CONFIG_DIR" not in env
    assert "ANTHROPIC_API_KEY" not in env


def test_claude_failure_is_an_error(hub, stub_grok, stub_claude, monkeypatch):
    monkeypatch.setenv("STUB_JSON", GROK_OUT_OF_USAGE)
    monkeypatch.setenv("STUB_EXIT", "1")
    monkeypatch.setenv(
        "STUB_CLAUDE_JSON",
        '{"type": "result", "subtype": "error_max_turns", "is_error": true}',
    )
    monkeypatch.setenv("STUB_CLAUDE_EXIT", "1")
    sid = planned(hub)
    xhub.draft(sid)
    s = xhub.find(slots(), sid)
    assert s["status"] == "error"
    assert "error_max_turns" in s["error"]


def test_other_grok_errors_do_not_fall_back(hub, stub_grok, stub_claude, monkeypatch):
    monkeypatch.setenv("STUB_JSON", '{"stopReason": "max_turn_requests"}')
    monkeypatch.setenv("STUB_EXIT", "1")
    sid = planned(hub)
    xhub.draft(sid)
    assert xhub.find(slots(), sid)["status"] == "error"
    assert not Path(f"{stub_claude}.argv").exists()


def test_draft_leaves_a_finished_slot_alone(hub, stub_grok):
    sid = planned(hub)
    with xhub.locked() as all_slots:
        xhub.find(all_slots, sid).update(status="posted", text="done")
    xhub.draft(sid)
    assert xhub.find(slots(), sid)["text"] == "done"


# --- rejecting --------------------------------------------------------------


def test_reject_records_feedback_and_redrafts_at_once(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    hub.armed.clear()
    xhub.reject(sid, "too preachy")
    s = xhub.find(slots(), sid)
    assert s["status"] == "drafting"
    assert s["attempts"] == [
        {
            "text": "Tests that never fail are not tests.",
            "feedback": "too preachy",
            "edited": False,
        }
    ]
    [(unit, when, args)] = hub.armed
    assert when is None
    assert args == ["draft", sid]


def test_redraft_units_are_unique_per_attempt(hub, stub_grok):
    sid = planned(hub)
    hub.armed.clear()
    for _ in range(2):
        xhub.draft(sid)
        xhub.reject(sid, "again")
    assert len({unit for unit, _, _ in hub.armed}) == 2


def test_redraft_prompt_carries_the_rejections(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    xhub.reject(sid, "too preachy")
    xhub.draft(sid)
    prompt = Path(f"{stub_grok}.prompt").read_text()
    assert "Tests that never fail are not tests." in prompt
    assert "too preachy" in prompt


def test_redraft_sends_my_edit_of_the_draft(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    xhub.reject(sid, "punchier", "tests that never fail aren't tests")
    assert xhub.find(slots(), sid)["attempts"] == [
        {
            "text": "tests that never fail aren't tests",
            "feedback": "punchier",
            "edited": True,
        }
    ]
    xhub.draft(sid)
    prompt = Path(f"{stub_grok}.prompt").read_text()
    assert '"tests that never fail aren\'t tests" (edited by me) -> punchier' in prompt
    assert "Tests that never fail are not tests." not in prompt


def test_redraft_sends_my_edit_without_feedback(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    xhub.reject(sid, "", "my version")
    xhub.draft(sid)
    assert '"my version" (edited by me)' in Path(f"{stub_grok}.prompt").read_text()


def test_redraft_of_an_unedited_draft_is_not_marked_edited(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    xhub.reject(sid, "again", "Tests that never fail are not tests.")
    assert xhub.find(slots(), sid)["attempts"][0]["edited"] is False


def test_reject_command_takes_the_edited_text(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    assert xhub.main(["reject", sid, "--text", "my version", "too", "long"]) == 0
    attempt = xhub.find(slots(), sid)["attempts"][0]
    assert attempt["text"] == "my version"
    assert attempt["feedback"] == "too long"


@pytest.mark.skip(
    reason="rejected-draft history disabled: it pulled every draft to one topic"
)
def test_rejection_feedback_reaches_other_slots(hub, stub_grok):
    xhub.plan(at("2026-11-03T00:05:00"))
    first, second = slots()[0]["id"], slots()[1]["id"]
    xhub.draft(first)
    xhub.reject(first, "never use hashtags")
    xhub.draft(first)
    xhub.approve(first, "A post.")
    xhub.draft(second)
    assert "never use hashtags" in Path(f"{stub_grok}.prompt").read_text()


def test_rejected_drafts_do_not_steer_other_slots(hub, stub_grok):
    xhub.plan(at("2026-11-03T00:05:00"))
    first, second = slots()[0]["id"], slots()[1]["id"]
    xhub.draft(first)
    xhub.reject(first, "never use hashtags", "a rejected wording about Rust")
    xhub.draft(first)
    xhub.approve(first, "A post.")
    xhub.draft(second)
    assert (
        "a rejected wording about Rust" not in Path(f"{stub_grok}.prompt").read_text()
    )


def test_feedback_reaches_other_slots_as_style_rules(hub, stub_grok):
    xhub.plan(at("2026-11-03T00:05:00"))
    first, second = slots()[0]["id"], slots()[1]["id"]
    xhub.draft(first)
    xhub.reject(first, "never use hashtags")
    xhub.reject(first, "")  # no feedback: nothing to send
    xhub.draft(first)
    xhub.approve(first, "A post.")
    xhub.draft(second)
    prompt = Path(f"{stub_grok}.prompt").read_text()
    assert "# My feedback on earlier drafts" in prompt
    assert "- never use hashtags" in prompt
    assert "- \n" not in prompt


def test_approved_posts_are_framed_as_my_voice(hub, stub_grok):
    xhub.plan(at("2026-11-03T00:05:00"))
    first, second = slots()[0]["id"], slots()[1]["id"]
    with xhub.locked() as all_slots:
        xhub.find(all_slots, first).update(status="review", text="x")
    xhub.approve(first, "An approved post about Rust.")
    xhub.draft(second)
    prompt = Path(f"{stub_grok}.prompt").read_text()
    assert "match their tone, length and phrasing" in prompt
    assert "Do not repeat" in prompt or "Never repeat" in prompt


def test_approving_an_edit_keeps_the_draft_with_it(hub):
    sid = reviewed(hub)
    xhub.approve(sid, "Edited text.")
    [rec] = xhub.history()
    assert rec["text"] == "Edited text."
    assert rec["draft"] == "Draft text."


def test_approving_an_unedited_draft_records_no_draft(hub):
    sid = reviewed(hub)
    xhub.approve(sid, "Draft text.")
    [rec] = xhub.history()
    assert "draft" not in rec


def test_my_edits_reach_later_prompts_as_before_and_after(hub, stub_grok):
    xhub.plan(at("2026-11-03T00:05:00"))
    first, second = slots()[0]["id"], slots()[1]["id"]
    with xhub.locked() as all_slots:
        xhub.find(all_slots, first).update(status="review", text="Leverage synergies.")
    xhub.approve(first, "Use less jargon.")
    xhub.draft(second)
    prompt = Path(f"{stub_grok}.prompt").read_text()
    assert "# How I edited your drafts" in prompt
    assert '"Leverage synergies." -> "Use less jargon."' in prompt


def test_prompt_without_edits_has_no_edit_section(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    assert "How I edited" not in Path(f"{stub_grok}.prompt").read_text()


# --- holding while a draft is staged ----------------------------------------


def two_slots(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    hub.armed.clear()
    return slots()[0]["id"], slots()[1]["id"]


@pytest.mark.parametrize("staged", ["review", "drafting", "error"])
def test_draft_waits_while_another_draft_is_staged(hub, stub_grok, staged):
    first, second = two_slots(hub)
    with xhub.locked() as all_slots:
        xhub.find(all_slots, first).update(status=staged, text="Staged.")
    xhub.draft(second)
    s = xhub.find(slots(), second)
    assert s["status"] == "waiting"
    assert s["text"] is None
    assert not Path(f"{stub_grok}.prompt").exists()


def test_approving_releases_the_earliest_waiting_slot(hub, stub_grok):
    xhub.plan(at("2026-11-03T00:05:00"))
    ids = [s["id"] for s in slots()]
    xhub.draft(ids[0])
    xhub.draft(ids[2])
    xhub.draft(ids[1])
    hub.armed.clear()
    xhub.approve(ids[0], "Posted.")
    [(unit, when, args)] = hub.armed
    assert when is None
    assert args == ["draft", ids[1]]


def test_a_failed_post_releases_nothing(hub, stub_grok, monkeypatch):
    first, second = two_slots(hub)
    xhub.draft(first)
    xhub.draft(second)
    hub.armed.clear()

    def boom(text):
        raise xhub.PostError("503")

    monkeypatch.setattr(xhub, "post_tweet", boom)
    xhub.approve(first, "Hello.")
    assert hub.armed == []


def test_plan_retries_waiting_slots(hub, stub_grok):
    first, second = two_slots(hub)
    xhub.draft(first)
    xhub.draft(second)
    hub.armed.clear()
    xhub.plan(at("2026-11-03T23:00:00"))
    assert ("draft", second) in {tuple(args) for _, _, args in hub.armed}


# --- rejecting a topic outright ---------------------------------------------


def test_reject_topic_starts_over_on_a_new_topic(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    xhub.reject(sid, "shorter")
    xhub.draft(sid)
    hub.armed.clear()
    xhub.discard(sid, "")
    s = xhub.find(slots(), sid)
    assert s["status"] == "drafting"
    assert s["attempts"] == []
    [(unit, when, args)] = hub.armed
    assert when is None
    assert args == ["draft", sid]


def test_rejected_topics_are_avoided_in_every_later_prompt(hub, stub_grok):
    sid = planned(hub)
    xhub.draft(sid)
    xhub.discard(sid, "I never write about crypto")
    xhub.draft(sid)
    prompt = Path(f"{stub_grok}.prompt").read_text()
    assert "Topics rejected outright" in prompt
    assert "Tests that never fail are not tests." in prompt
    assert "I never write about crypto" in prompt
    assert "Redraft using the feedback" not in prompt


def test_reject_topic_ignores_a_slot_not_in_review(hub):
    sid = planned(hub)
    xhub.discard(sid, "")
    assert xhub.find(slots(), sid)["status"] == "scheduled"
    assert len(hub.armed) == 5  # only plan's timers


def test_retry_after_an_error_needs_no_feedback(hub, monkeypatch):
    monkeypatch.setattr(xhub, "GROK", "/bin/false")
    sid = planned(hub)
    xhub.draft(sid)
    hub.armed.clear()
    xhub.reject(sid, "")
    assert xhub.find(slots(), sid)["attempts"] == []
    assert len(hub.armed) == 1


# --- approving --------------------------------------------------------------


def reviewed(hub):
    sid = planned(hub)
    with xhub.locked() as all_slots:
        xhub.find(all_slots, sid).update(status="review", text="Draft text.")
    return sid


def test_approve_posts_the_text_as_edited(hub):
    sid = reviewed(hub)
    xhub.approve(sid, "Edited text.")
    assert hub.posts == ["Edited text."]
    s = xhub.find(slots(), sid)
    assert s["status"] == "posted"
    assert s["text"] == "Edited text."
    assert s["tweet_id"] == "1850000000000000001"


def test_approved_posts_go_into_the_next_prompt(hub, stub_grok):
    xhub.plan(at("2026-11-03T00:05:00"))
    first, second = slots()[0]["id"], slots()[1]["id"]
    with xhub.locked() as all_slots:
        xhub.find(all_slots, first).update(status="review", text="x")
    xhub.approve(first, "An approved post about Rust.")
    xhub.draft(second)
    assert "An approved post about Rust." in Path(f"{stub_grok}.prompt").read_text()


def test_approve_twice_posts_once(hub):
    sid = reviewed(hub)
    xhub.approve(sid, "Once.")
    xhub.approve(sid, "Once.")
    assert hub.posts == ["Once."]


def test_approve_refuses_an_overlong_post(hub):
    sid = reviewed(hub)
    xhub.approve(sid, "x" * 281)
    assert hub.posts == []
    s = xhub.find(slots(), sid)
    assert s["status"] == "review"
    assert "280" in s["error"]


def test_failed_post_stays_in_review_with_the_error(hub, monkeypatch):
    sid = reviewed(hub)

    def boom(text):
        raise xhub.PostError("403 Forbidden: not permitted")

    monkeypatch.setattr(xhub, "post_tweet", boom)
    xhub.approve(sid, "Hello.")
    s = xhub.find(slots(), sid)
    assert s["status"] == "review"
    assert s["text"] == "Hello."
    assert "403" in s["error"]


# --- storage ----------------------------------------------------------------


def test_slots_file_is_replaced_atomically(hub):
    xhub.plan(at("2026-11-03T00:05:00"))
    assert json.loads((xhub.STATE / "slots.json").read_text())
    assert not list(xhub.STATE.glob("*.tmp"))


# --- OAuth 1.0a -------------------------------------------------------------


def test_oauth_signature_matches_the_documented_example():
    # The worked example from X's "Creating a signature" documentation.
    header = xhub.oauth_header(
        "POST",
        "https://api.twitter.com/1.1/statuses/update.json",
        {
            "include_entities": "true",
            "status": "Hello Ladies + Gentlemen, a signed OAuth request!",
        },
        {
            "api_key": "xvz1evFS4wEEPTGEFPHBog",
            "api_secret": "kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw",
            "access_token": "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb",
            "access_secret": "LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE",
        },
        nonce="kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg",
        timestamp="1318622958",
    )
    assert 'oauth_signature="hCtSmYh%2BiHYCEqBWrE7C7hYmtUk%3D"' in header
    assert header.startswith("OAuth ")


def test_post_tweet_without_credentials_says_where_they_go(hub, monkeypatch):
    monkeypatch.undo()  # the real post_tweet
    monkeypatch.setattr(xhub, "DATA", hub.tmp / "data")
    with pytest.raises(xhub.PostError, match="credentials.json"):
        xhub.post_tweet("hi")


def test_post_tweet_treats_blank_skeleton_values_as_missing(hub, monkeypatch):
    monkeypatch.undo()
    monkeypatch.setattr(xhub, "DATA", hub.tmp / "data")
    (hub.tmp / "data" / "credentials.json").write_text(
        json.dumps(
            {
                "api_key": "k",
                "api_secret": "",
                "access_token": "t",
                "access_secret": "s",
            }
        )
    )
    with pytest.raises(xhub.PostError, match="api_secret"):
        xhub.post_tweet("hi")
