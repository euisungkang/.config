#!/usr/bin/env python3
"""One-time helper: connect a bank/card issuer via Plaid Link and store its access token.

Serves a tiny page on http://localhost:8765, opens it in your browser, and on success
appends the new item to ~/.local/share/plaid-balance/credentials.json. Run once per institution.
"""
import json, os, sys, threading, urllib.request, webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

sys.path.insert(0, os.path.dirname(__file__))
CREDS = os.path.expanduser("~/.local/share/plaid-balance/credentials.json")
HOSTS = {"sandbox": "https://sandbox.plaid.com", "production": "https://production.plaid.com"}
PORT = 8765
INVEST = "--invest" in sys.argv  # link a brokerage/retirement account for the plaid-invest widget

creds = json.load(open(CREDS))


def post(path, body):
    body = dict(body, client_id=creds["client_id"], secret=creds["secret"])
    req = urllib.request.Request(HOSTS[creds.get("env", "production")] + path,
                                 data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


# --update [institution]: re-authenticate an existing item (no new item, same access token)
UPDATE = None
if "--update" in sys.argv:
    want = (sys.argv[sys.argv.index("--update") + 1:] or [None])[0]
    items = [i for i in creds.get("items", []) if not want or (i.get("institution") or "").lower() == want.lower()]
    if not items:
        sys.exit("No matching item. Linked: " + ", ".join(i.get("institution") or "?" for i in creds.get("items", [])))
    UPDATE = items[0]
    print("Re-authenticating", UPDATE.get("institution"))

req = {
    "client_name": "Desktop Balance Widget",
    "language": "en",
    "country_codes": ["US"],
    "user": {"client_user_id": "local-user"},
}
if UPDATE:
    req["access_token"] = UPDATE["access_token"]
    if "--transactions" in sys.argv:  # grant Transactions consent on an existing item (needed for pending charges)
        req["additional_consented_products"] = ["transactions"]
else:
    req["products"] = ["investments"] if INVEST else creds.get("products", ["liabilities"])
link_token = post("/link/token/create", req)["link_token"]

PAGE = """<!doctype html><meta charset=utf-8><title>Plaid Link</title>
<body style="font-family:sans-serif;background:#111;color:#eee;padding:2em">
<h2 id=s>Opening Plaid Link…</h2>
<script src="https://cdn.plaid.com/link/v2/stable/link-initialize.js"></script>
<script>
const s = document.getElementById('s');
Plaid.create({
  token: %s,
  onSuccess: async (public_token, md) => {
    await fetch('/exchange', {method:'POST', body: JSON.stringify({public_token, institution: md.institution && md.institution.name})});
    s.textContent = 'Linked ' + (md.institution ? md.institution.name : '') + '. You can close this tab.';
  },
  onExit: () => { s.textContent = 'Closed. Re-run plaid-link.py to try again.'; fetch('/done', {method:'POST'}); },
}).open();
</script>"""


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        self.send_response(200); self.send_header("Content-Type", "text/html"); self.end_headers()
        self.wfile.write((PAGE % json.dumps(link_token)).encode())

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        data = json.loads(self.rfile.read(n) or b"{}")
        if self.path == "/exchange" and UPDATE:
            print("Re-authenticated", UPDATE.get("institution"))  # token unchanged
        elif self.path == "/exchange":
            r = post("/item/public_token/exchange", {"public_token": data["public_token"]})
            group = "invest" if INVEST else None
            inst = data.get("institution")
            dup = any((i.get("institution") == inst) and (i.get("group") == group) for i in creds.get("items", []))
            if dup:  # a second Item at the same institution would be a duplicate, separately billed link
                post("/item/remove", {"access_token": r["access_token"]})
                print("Already linked:", inst, "- removed the duplicate")
            else:
                item = {"access_token": r["access_token"], "item_id": r["item_id"], "institution": inst}
                if group:
                    item["group"] = group
                creds.setdefault("items", []).append(item)
            with open(CREDS, "w") as f:
                json.dump(creds, f, indent=2)
            os.chmod(CREDS, 0o600)
            if not dup:
                print("Linked", inst)
        self.send_response(200); self.end_headers()
        threading.Thread(target=self.server.shutdown).start()


print(f"Open http://localhost:{PORT} (launching browser)…")
webbrowser.open(f"http://localhost:{PORT}")
HTTPServer(("localhost", PORT), H).serve_forever()
