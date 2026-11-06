"""Row-by-row summary of sheet.psv vs au-prod Leads. READ-ONLY."""
import csv, json, os, subprocess, sys
from datetime import datetime

S = sys.argv[1]
COLS = ["Date", "First", "Last", "SF", "Class", "AdmYear", "Programme", "Major", "AppNo",
        "Email", "Phone", "City", "SourceType", "SchoolBoard", "College", "Counsellor", "Enquiry"]
EXCLUDE = {"00Qfv00000RUifHEAT": "Jayati Sethi", "00Qfv00000RUs0DEAT": "Jayati Sethi",
           "00Qfv00000bgvvqEAA": "Punya Bhudiya", "00Qfv00000Nh377EAB": "Hensi Solanki",
           "00Qfv000007nlUoEAI": "'Customer'"}

def q(soql):
    out = subprocess.run(["sf", "data", "query", "-o", "au-prod", "-q", soql, "--json"],
                         capture_output=True, text=True, shell=True).stdout
    return json.loads(out)["result"]["records"]

def last10(s):
    return "".join(c for c in (s or "") if c.isdigit())[-10:]

rows = []
for line in open(os.path.join(S, "sheet.psv"), encoding="utf-8"):
    r = dict(zip(COLS, line.rstrip("\n").split("|")))
    r["Email"] = r["Email"].lower()
    r["phones"] = [p for p in r["Phone"].split("/") if p]
    rows.append(r)

F = "Id, FirstName, LastName, Email, Phone, MobilePhone, Status, IsConverted, CreatedDate"
emails = sorted({r["Email"] for r in rows if r["Email"]})
phones = sorted({p for r in rows for p in r["phones"]})
leads = {x["Id"]: x for x in q(f"SELECT {F} FROM Lead WHERE Email IN ({','.join(repr(e) for e in emails)})")}
for i in range(0, len(phones), 15):
    cond = " OR ".join(f"Phone LIKE '%{p}' OR MobilePhone LIKE '%{p}'" for p in phones[i:i + 15])
    leads.update({x["Id"]: x for x in q(f"SELECT {F} FROM Lead WHERE {cond}")})

out = []
for n, r in enumerate(rows, 1):
    by_e = {l["Id"] for l in leads.values() if r["Email"] and (l["Email"] or "").lower() == r["Email"]}
    by_p = {l["Id"] for l in leads.values()
            if any(p in (last10(l["Phone"]), last10(l["MobilePhone"])) for p in r["phones"])}
    allm = by_e | by_p
    good = [leads[i] for i in allm if i not in EXCLUDE]
    excluded = sorted({EXCLUDE[i] for i in allm if i in EXCLUDE})
    via = " + ".join(x for x, s in (("Email", by_e - set(EXCLUDE)), ("Phone", by_p - set(EXCLUDE))) if s) or "—"
    open_ = sorted([l for l in good if not l["IsConverted"]], key=lambda l: l["CreatedDate"])
    conv = [l for l in good if l["IsConverted"]]
    if open_:
        action, target = "UPDATE", open_[-1]["Id"]
    elif conv:
        action, target = "SKIP (converted)", conv[0]["Id"]
    else:
        action, target = "CREATE", ""
    notes = []
    if len(good) > 1:
        notes.append(f"{len(good)} leads in prod ({len(conv)} converted)")
    if excluded:
        notes.append("phone also on other person's lead: " + ", ".join(excluded))
    if target == "00Qfv00000aXFV2EAO":
        notes.append("only open lead is Closed / Exec Ed")
    out.append([n, r["Date"], f'{r["First"]} {r["Last"]}'.strip(), r["Email"] or "", r["Phone"] or "",
                via, len(good), action, target, "; ".join(notes)])

hdr = ["#", "Date", "Name", "Email", "Phone", "Matched by", "Leads", "Action", "Target Lead", "Notes"]
with open(os.path.join(S, "row_summary.csv"), "w", newline="", encoding="utf-8") as fh:
    csv.writer(fh).writerows([hdr] + out)
print("| " + " | ".join(hdr) + " |")
print("|" + "---|" * len(hdr))
for o in out:
    print("| " + " | ".join(str(x) if x != "" else "—" for x in o) + " |")
from collections import Counter
print("\nACTIONS", Counter(o[7] for o in out), "| VIA", Counter(o[5] for o in out))
