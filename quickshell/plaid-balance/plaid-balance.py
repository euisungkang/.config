#!/usr/bin/env python3
"""Fetch credit card balances from Plaid and print normalized JSON.

Credentials + linked items live in ~/.local/share/plaid-balance/credentials.json
(outside the dotfiles repo). Run plaid-link.py to connect a new institution.
Pass a JSON file path as argv[1] to parse a saved /accounts/get response instead.
"""
import datetime, json, os, re, sys, time, urllib.error, urllib.request

CREDS = os.path.expanduser("~/.local/share/plaid-balance/credentials.json")
CACHE = os.path.expanduser("~/.cache/plaid-balance/balances.json")
SYNC = os.path.expanduser("~/.cache/plaid-balance/sync.json")  # per-item sync cursor + pending charges
WARN_DAYS = 30  # show the re-auth button this long before a known consent expiry
TIP_SLACK = 1.00  # max |posted - pending| when pairing a posted charge with its stale pending twin
POSTED_KEEP_DAYS = 21
MIN_AGE = 840  # seconds; reuse the cached result instead of hitting Plaid again
HOSTS = {
    "sandbox": "https://sandbox.plaid.com",
    "production": "https://production.plaid.com",
}


def load_cache():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(c):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w") as f:
        json.dump(c, f)


def post(creds, path, body):
    body = dict(body, client_id=creds["client_id"], secret=creds["secret"])
    req = urllib.request.Request(
        HOSTS[creds.get("env", "production")] + path,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def normalize(resp, institution=None, pending=None):
    cards = []
    for a in resp.get("accounts", []):
        if a.get("subtype") != "credit card":
            continue
        b = a.get("balances") or {}
        cards.append({
            "name": a.get("official_name") or a.get("name"),
            "mask": a.get("mask"),
            "institution": institution,
            "balance": b.get("current"),
            "limit": b.get("limit"),
            "available": b.get("available"),
            "pending": round((pending or {}).get(a.get("account_id"), 0), 2),
        })
    return cards


def summarize(cards):
    cards.sort(key=lambda c: -(c["balance"] or 0) - (c.get("pending") or 0))
    return {
        "cards": cards,
        "total": sum((c["balance"] or 0) + (c.get("pending") or 0) for c in cards),
        "pending": sum(c.get("pending") or 0 for c in cards),
    }


def load_sync():
    try:
        with open(SYNC) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_sync(d):
    os.makedirs(os.path.dirname(SYNC), exist_ok=True)
    with open(SYNC, "w") as f:
        json.dump(d, f)


def _tokens(name):
    return {w for w in re.findall(r"[a-z0-9]+", (name or "").lower()) if len(w) >= 4}


def _brief(t):
    return {"account_id": t["account_id"], "amount": t["amount"], "date": t["date"],
            "name": t.get("merchant_name") or t.get("name") or ""}


def dedupe(pending, posted):
    """Drop pending charges whose posted twin Plaid didn't link (BoA): same account + sign, same merchant
    word, amount within TIP_SLACK, posted on/after the pending date. One posted charge cancels at most one pending."""
    used, stale = set(), set()
    for pid, p in sorted(pending.items()):  # an authorization and its reversal cancel each other first
        for qid, q in pending.items():
            if (pid < qid and pid not in stale and qid not in stale and p["account_id"] == q["account_id"]
                    and abs(p["amount"] + q["amount"]) < 0.005 and _tokens(p["name"]) & _tokens(q["name"])):
                stale.update((pid, qid))
    pending = {k: v for k, v in pending.items() if k not in stale}
    for pid, p in sorted(pending.items(), key=lambda kv: kv[1].get("date", "")):
        want = _tokens(p.get("name"))
        for qid, q in posted.items():
            if (qid in used or q["account_id"] != p["account_id"] or q["date"] < p.get("date", "")
                    or (q["amount"] < 0) != (p["amount"] < 0) or abs(q["amount"] - p["amount"]) > TIP_SLACK
                    or not want & _tokens(q["name"])):
                continue
            used.add(qid)
            stale.add(pid)
            break
    return {k: v for k, v in pending.items() if k not in stale}


def sync_pending(creds, item, state):
    """Return {account_id: pending_total} via /transactions/sync, keeping the cursor + pending/posted sets in `state`."""
    key = item.get("item_id") or item["access_token"][-12:]
    st = state.get(key, {"cursor": "", "pending": {}, "posted": {}})
    for _ in range(3):  # restart from the pre-loop cursor if data mutates mid-pagination
        cursor, pending, first = st["cursor"], dict(st["pending"]), st["cursor"] == ""
        posted = dict(st.get("posted", {}))
        try:
            while True:
                body = {"access_token": item["access_token"], "cursor": cursor, "count": 500}
                if first and cursor == "":
                    body["options"] = {"days_requested": 30}
                r = post(creds, "/transactions/sync", body)
                for t in r.get("added", []) + r.get("modified", []):
                    if t.get("pending"):
                        pending[t["transaction_id"]] = _brief(t)
                        posted.pop(t["transaction_id"], None)
                    else:
                        pending.pop(t["transaction_id"], None)
                        if t.get("pending_transaction_id"):  # posted charge replaces its pending twin
                            pending.pop(t["pending_transaction_id"], None)
                        posted[t["transaction_id"]] = _brief(t)
                for t in r.get("removed", []):
                    pending.pop(t["transaction_id"], None)
                    posted.pop(t["transaction_id"], None)
                cursor = r["next_cursor"]
                if not r["has_more"]:
                    break
            cutoff = (datetime.date.today() - datetime.timedelta(days=POSTED_KEEP_DAYS)).isoformat()
            posted = {k: v for k, v in posted.items() if v["date"] >= cutoff}
            st = {"cursor": cursor, "pending": pending, "posted": posted}
            break
        except urllib.error.HTTPError as e:
            if error_code(e) != "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION":
                raise
    state[key] = st
    out = {}
    for t in dedupe(st["pending"], st["posted"]).values():
        out[t["account_id"]] = out.get(t["account_id"], 0) + t["amount"]
    return out


def error_code(e):
    if not hasattr(e, "plaid_code"):  # the body can only be read once
        try:
            e.plaid_code = json.load(e).get("error_code", f"HTTP {e.code}")
        except Exception:
            e.plaid_code = f"HTTP {e.code}"
    return e.plaid_code


def days_left(iso):
    t = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return (t - datetime.datetime.now(datetime.timezone.utc)).total_seconds() / 86400


def fetch(creds):
    cards, alerts, errors = [], [], []
    state = load_sync()
    for item in creds.get("items", []):
        if item.get("group") == "invest":
            continue
        name = item.get("institution") or "Bank"
        pending = {}
        try:
            pending = sync_pending(creds, item, state)
        except urllib.error.HTTPError as e:
            code = error_code(e)
            if code == "ADDITIONAL_CONSENT_REQUIRED":
                alerts.append({"institution": name, "state": "consent", "transactions": True,
                               "text": f"{name}: enable pending charges"})
            elif code == "ITEM_LOGIN_REQUIRED":
                alerts.append({"institution": name, "state": "expired", "text": f"{name}: sign in again"})
                continue
            # PRODUCT_NOT_READY etc.: no pending data yet, fall through to plain balances
        except Exception:
            pass
        try:
            # Real-time balances; /accounts/get is cached by the institution and lags posted charges by days.
            try:
                resp = post(creds, "/accounts/balance/get", {"access_token": item["access_token"]})
            except urllib.error.HTTPError as e:
                if error_code(e) == "ITEM_LOGIN_REQUIRED":
                    raise
                resp = post(creds, "/accounts/get", {"access_token": item["access_token"]})
            cards += normalize(resp, name, pending)
        except urllib.error.HTTPError as e:
            code = error_code(e)
            if code == "ITEM_LOGIN_REQUIRED":
                alerts.append({"institution": name, "state": "expired", "text": f"{name}: sign in again"})
            else:
                errors.append(f"{name}: {code}")
            continue
        try:  # not every institution reports a consent expiry
            exp = post(creds, "/item/get", {"access_token": item["access_token"]})["item"].get("consent_expiration_time")
            if exp and days_left(exp) <= WARN_DAYS:
                d = max(0, int(days_left(exp)))
                alerts.append({"institution": name, "state": "expiring",
                               "text": f"{name}: access expires in {d}d"})
        except Exception:
            pass
    save_sync(state)
    out = summarize(cards)
    out["alerts"] = alerts
    if errors:
        out["error"] = "\n".join(errors)
    return out


if len(sys.argv) > 1 and sys.argv[1] != "--force":
    print(json.dumps(summarize(normalize(json.load(open(sys.argv[1]))))))
    sys.exit()

cache = load_cache()
now = time.time()
result = cache.get("result")

if result and "--force" not in sys.argv and now - cache.get("fetched_at", 0) < MIN_AGE:
    print(json.dumps(result))
    sys.exit()

try:
    with open(CREDS) as f:
        creds = json.load(f)
    if not [i for i in creds.get("items", []) if i.get("group") != "invest"]:
        print(json.dumps({"error": "No cards linked - run plaid-link.py"}))
        sys.exit()
    result = fetch(creds)
    save_cache({"result": result, "fetched_at": now})
    print(json.dumps(result))
except FileNotFoundError:
    print(json.dumps({"error": "Missing credentials.json"}))
except urllib.error.HTTPError as e:
    try:
        code = json.load(e).get("error_code", f"HTTP {e.code}")
    except Exception:
        code = f"HTTP {e.code}"
    if code == "ITEM_LOGIN_REQUIRED":
        code = "Re-link needed - run plaid-link.py"
    # keep showing the last good numbers rather than an error
    print(json.dumps(result or {"error": code}))
except Exception as e:
    print(json.dumps(result or {"error": type(e).__name__}))
