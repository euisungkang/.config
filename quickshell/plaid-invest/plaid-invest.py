#!/usr/bin/env python3
"""Fetch investment/savings account values from Plaid and print normalized JSON.

Uses the items tagged "group": "invest" in ~/.local/share/plaid-balance/credentials.json
(link them with: plaid-link.py --invest). Accounts can be hidden with
"hide_accounts": [{"institution": "SoFi", "subtype": "checking"}] in that file, and fold one
account into another with "merge_accounts": [{"institution": "SoFi", "subtype": "savings", "into": "cash management"}]. Pass --force to skip the cache.
Pass a JSON file path as argv[1] to parse a saved {"accounts":[...],"holdings":[...]} response instead.
"""
import datetime, json, os, sys, time, urllib.error, urllib.request

CREDS = os.path.expanduser("~/.local/share/plaid-balance/credentials.json")
CACHE = os.path.expanduser("~/.cache/plaid-balance/invest.json")
MANUAL = os.path.expanduser("~/.local/share/plaid-balance/manual.json")  # hand-entered balances; see invest-update
WARN_DAYS = 30  # show the re-auth button this long before a known consent expiry
MIN_AGE = 1500  # seconds; holdings only update a few times a day
HOSTS = {"sandbox": "https://sandbox.plaid.com", "production": "https://production.plaid.com"}
LABELS = {
    "roth": "Roth IRA", "roth 401k": "Roth 401(k)", "401k": "401(k)", "ira": "IRA", "hsa": "HSA",
    "brokerage": "Brokerage", "cryptocurrency": "Crypto", "savings": "Savings", "cash management": "HYSA",
    "money market": "Money Market", "checking": "Checking",
}


def post(creds, path, body):
    body = dict(body, client_id=creds["client_id"], secret=creds["secret"])
    req = urllib.request.Request(HOSTS[creds.get("env", "production")] + path,
                                 data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def error_code(e):
    if not hasattr(e, "plaid_code"):  # the body can only be read once
        try:
            e.plaid_code = json.load(e).get("error_code", f"HTTP {e.code}")
        except Exception:
            e.plaid_code = f"HTTP {e.code}"
    return e.plaid_code


def build(accounts, holdings, institution, hide=()):
    by_acct = {}
    for h in holdings:
        by_acct.setdefault(h["account_id"], []).append(h)
    out = []
    for a in accounts:
        if a.get("type") == "credit":
            continue
        if any(h.get("institution") == institution and h.get("subtype") == a.get("subtype") for h in hide):
            continue
        hs = by_acct.get(a["account_id"], [])
        with_basis = [h for h in hs if h.get("cost_basis") is not None and not h.get("is_cash")]
        value_b = sum(h["institution_value"] for h in with_basis)
        basis = sum(h["cost_basis"] for h in with_basis)
        gain = round(value_b - basis, 2) if with_basis and basis else None
        sub = a.get("subtype") or a.get("type")
        cash = round(sum(h["institution_value"] for h in hs if h.get("is_cash")), 2) or None
        balance = (a.get("balances") or {}).get("current") or 0
        # SoFi reports a $0 balance while holdings are synced: fall back to the holdings total. Otherwise the
        # broker's balance excludes uninvested cash holdings, so add them.
        value = round(sum(h["institution_value"] for h in hs), 2) if not balance and hs else balance + (cash or 0)
        out.append({
            "id": a["account_id"],
            "institution": institution,
            "label": LABELS.get(sub, a.get("official_name") or a.get("name")),
            "name": a.get("name"),
            "mask": a.get("mask"),
            "type": a.get("type"),
            "subtype": a.get("subtype"),
            "value": value,
            "holdings": len(hs),
            "cash": cash,  # shown as subtext, already included in value
            "gain": gain,
            "gain_pct": round(gain / basis * 100, 2) if gain is not None else None,
            # share of non-cash holdings that report a cost basis (gain is only over those)
            "basis_coverage": round(len(with_basis) / max(1, len([h for h in hs if not h.get("is_cash")])), 2) if hs else None,
        })
    return out


def merge_accounts(accts, rules):
    """Fold one account into another at the same institution, e.g. SoFi savings into SoFi cash management."""
    for r in rules:
        src = next((a for a in accts if a["institution"] == r["institution"] and a["subtype"] == r["subtype"]), None)
        dst = next((a for a in accts if a["institution"] == r["institution"] and a["subtype"] == r["into"]), None)
        if src and dst and src is not dst:
            dst["value"] = (dst["value"] or 0) + (src["value"] or 0)
            accts.remove(src)
    return accts


def summarize(accts, alerts=(), errors=()):
    accts.sort(key=lambda a: -(a["value"] or 0))
    out = {"accounts": accts, "total": sum(a["value"] or 0 for a in accts), "alerts": list(alerts)}
    gains = [a["gain"] for a in accts if a["gain"] is not None]
    out["gain"] = round(sum(gains), 2) if gains else None
    if errors:
        out["error"] = "\n".join(errors)
    return out


def days_left(iso):
    t = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return (t - datetime.datetime.now(datetime.timezone.utc)).total_seconds() / 86400


# Cash movements that are money you put in or took out (not investment return)
FLOW_SUBTYPES = {"contribution", "deposit", "withdrawal", "distribution", "rollover"}


def net_contributions(creds, tok, account_ids):
    """{account_id: (net money in, earliest transaction date)} from /investments/transactions/get."""
    out, offset = {}, 0
    start = (datetime.date.today() - datetime.timedelta(days=730)).isoformat()
    while True:
        r = post(creds, "/investments/transactions/get", dict(
            tok, start_date=start, end_date=datetime.date.today().isoformat(),
            options={"count": 500, "offset": offset, "account_ids": account_ids}))
        for t in r["investment_transactions"]:
            net, first = out.get(t["account_id"], (0.0, t["date"]))
            # Plaid amounts: negative = cash into the account
            if t["type"] == "transfer" or (t["type"] == "cash" and t["subtype"] in FLOW_SUBTYPES):
                net -= t["amount"]
            out[t["account_id"]] = (net, min(first, t["date"]))
        offset += len(r["investment_transactions"])
        if not r["investment_transactions"] or offset >= r["total_investment_transactions"]:
            return out


def holdings_flat(resp):
    secs = {s["security_id"]: s for s in resp.get("securities", [])}
    out = []
    for h in resp.get("holdings", []):
        s = secs.get(h["security_id"], {})
        out.append(dict(h, is_cash=bool(s.get("is_cash_equivalent")) or s.get("type") == "cash"))
    return out


def fetch(creds):
    accts, alerts, errors = [], [], []
    for item in creds.get("items", []):
        if item.get("group") != "invest":
            continue
        name = item.get("institution") or "Bank"
        tok = {"access_token": item["access_token"]}
        try:
            accounts = post(creds, "/accounts/get", tok)["accounts"]
            try:
                holdings = holdings_flat(post(creds, "/investments/holdings/get", tok))
            except urllib.error.HTTPError as e:
                if error_code(e) not in ("PRODUCTS_NOT_SUPPORTED", "NO_INVESTMENT_ACCOUNTS", "PRODUCT_NOT_READY", "ADDITIONAL_CONSENT_REQUIRED"):
                    raise
                holdings = []  # e.g. a savings-only login: balance only
            built = build(accounts, holdings, name, creds.get("hide_accounts", []))
            # No cost basis (e.g. Fidelity returns no holdings): measure return as value minus net money put in
            need = [a["id"] for a in built if a["type"] == "investment" and a["gain"] is None and a["value"]]
            if need:
                try:
                    flows = net_contributions(creds, tok, need)
                    for a in built:
                        if a["id"] in flows and flows[a["id"]][0] > 0:
                            net, since = flows[a["id"]]
                            a["gain"] = round(a["value"] - net, 2)
                            a["gain_pct"] = round(a["gain"] / net * 100, 2)
                            a["gain_since"] = since
                except urllib.error.HTTPError:
                    pass
            accts += merge_accounts(built, creds.get("merge_accounts", []))
            try:  # not every institution reports a consent expiry
                exp = post(creds, "/item/get", tok)["item"].get("consent_expiration_time")
                if exp and days_left(exp) <= WARN_DAYS:
                    alerts.append({"institution": name, "state": "expiring",
                                   "text": f"{name}: access expires in {max(0, int(days_left(exp)))}d"})
            except Exception:
                pass
        except urllib.error.HTTPError as e:
            code = error_code(e)
            if code == "ITEM_LOGIN_REQUIRED":
                alerts.append({"institution": name, "state": "expired", "text": f"{name}: sign in again"})
            else:
                errors.append(f"{name}: {code}")
    return summarize(accts, alerts, errors)


def last_due(today):
    """Most recent reminder day (the 2nd or 16th, the day after payday) on or before today."""
    if today.day >= 16:
        return today.replace(day=16)
    if today.day >= 2:
        return today.replace(day=2)
    return (today.replace(day=1) - datetime.timedelta(days=1)).replace(day=16)


def with_manual(result):
    """Add hand-entered accounts (e.g. 401(k), HSA) to a result. Applied after the cache so edits show instantly."""
    try:
        with open(MANUAL) as f:
            manual = json.load(f).get("accounts", [])
    except (OSError, ValueError):
        return result
    rows = [{"id": "manual-" + m["label"], "institution": m.get("institution", ""), "label": m["label"], "name": m["label"],
             "mask": None, "type": "investment", "subtype": "manual", "holdings": 0,
             # "bonus" is added on top of the typed balance for display (e.g. HSA +500 not in the balance yet)
             "value": None if m.get("value") is None else round(m["value"] + m.get("bonus", 0), 2),
             "gain": None, "gain_pct": None, "basis_coverage": None, "updated": m.get("updated")} for m in manual]
    out = dict(result, accounts=sorted(result.get("accounts", []) + rows, key=lambda a: -(a["value"] or 0)))
    out["total"] = sum(a["value"] or 0 for a in out["accounts"])
    out.pop("empty", None)
    due = last_due(datetime.date.today()).isoformat()
    # due until every row has been confirmed (see invest-update) since the latest reminder day
    out["manual_due"] = bool(manual) and any((m.get("updated") or "") < due for m in manual)
    return out


def emit(result):
    print(json.dumps(with_manual(result)))


def load_cache():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


if len(sys.argv) > 1 and sys.argv[1] != "--force":
    d = json.load(open(sys.argv[1]))
    print(json.dumps(summarize(build(d["accounts"], holdings_flat(d), "Test"))))
    sys.exit()

cache = load_cache()
now = time.time()
result = cache.get("result")
if result and "--force" not in sys.argv and now - cache.get("fetched_at", 0) < MIN_AGE:
    emit(result)
    sys.exit()

try:
    with open(CREDS) as f:
        creds = json.load(f)
    if not [i for i in creds.get("items", []) if i.get("group") == "invest"]:
        emit({"accounts": [], "total": 0, "alerts": [], "empty": True})
        sys.exit()
    result = fetch(creds)
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w") as f:
        json.dump({"result": result, "fetched_at": now}, f)
    emit(result)
except FileNotFoundError:
    print(json.dumps({"error": "Missing credentials.json"}))
except Exception as e:
    emit(result or {"error": type(e).__name__})
