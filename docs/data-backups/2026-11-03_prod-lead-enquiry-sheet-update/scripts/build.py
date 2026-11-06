"""Build the Lead update/insert plan from sheet.psv. READ-ONLY against au-prod."""
import csv, json, os, subprocess, sys
from datetime import datetime

S = sys.argv[1]
ORG = "au-prod"
COLS = ["Date", "First", "Last", "SF", "Class", "AdmYear", "Programme", "Major", "AppNo",
        "Email", "Phone", "City", "SourceType", "SchoolBoard", "College", "Counsellor", "Enquiry"]
# Phone-only matches whose Lead belongs to a different person -> never update these
EXCLUDE = {"00Qfv00000RUifHEAT", "00Qfv00000RUs0DEAT", "00Qfv00000bgvvqEAA",
           "00Qfv00000Nh377EAB", "00Qfv000007nlUoEAI"}
BOARDS = {"CBSE", "ICSE", "IB", "IGCSE", "GSEB", "STATE BOARD"}
ADM_YEAR_OK = {"Admission Year - 2027", "Admission Year - 2028"}
FIELDS = ["Enquiry_Type__c", "Educator_Counsellor_Text__c", "Programme_Interested_in__c", "Major__c",
          "School_City__c", "Board_c__c", "School__c", "Name_of_University_College__c", "Admission_Year__c"]

def q(soql):
    out = subprocess.run(["sf", "data", "query", "-o", ORG, "-q", soql, "--json"],
                         capture_output=True, text=True, shell=True).stdout
    return json.loads(out)["result"]["records"]

def last10(s):
    return "".join(c for c in (s or "") if c.isdigit())[-10:]

rows = []
for line in open(os.path.join(S, "sheet.psv"), encoding="utf-8"):
    r = dict(zip(COLS, line.rstrip("\n").split("|")))
    r["Email"] = r["Email"].lower()
    r["phones"] = [p for p in r["Phone"].split("/") if p]
    r["dt"] = datetime.strptime(r["Date"], "%d-%m-%Y")
    rows.append(r)

def sheet_values(r):
    """Map one sheet row to Lead fields (blank sheet cells are not written)."""
    v = {"Enquiry_Type__c": r["Enquiry"], "Educator_Counsellor_Text__c": r["Counsellor"],
         "Programme_Interested_in__c": r["Programme"], "Major__c": r["Major"],
         "School_City__c": r["City"], "Name_of_University_College__c": r["College"]}
    sb = r["SchoolBoard"]
    if sb:
        if sb.upper() in BOARDS:
            v["Board_c__c"] = sb
        elif r["SF"] == "Lateral":
            v["Name_of_University_College__c"] = v["Name_of_University_College__c"] or sb
        else:
            v["School__c"] = sb
    if r["AdmYear"] in ADM_YEAR_OK:
        v["Admission_Year__c"] = r["AdmYear"]
    return {k: x for k, x in v.items() if x}

F = ("Id, FirstName, LastName, Email, Phone, MobilePhone, Status, IsConverted, CreatedDate, OwnerId, "
     "RecordType.Name, LeadSource, Class__c, " + ", ".join(FIELDS))
emails = sorted({r["Email"] for r in rows if r["Email"]})
phones = sorted({p for r in rows for p in r["phones"]})
leads = {}
for x in q(f"SELECT {F} FROM Lead WHERE Email IN ({','.join(repr(e) for e in emails)})"):
    leads[x["Id"]] = x
for i in range(0, len(phones), 15):
    cond = " OR ".join(f"Phone LIKE '%{p}' OR MobilePhone LIKE '%{p}'" for p in phones[i:i + 15])
    for x in q(f"SELECT {F} FROM Lead WHERE {cond}"):
        leads[x["Id"]] = x

targets, converted_only, creates = {}, [], {}
for r in sorted(rows, key=lambda r: r["dt"]):
    m = [l for l in leads.values() if l["Id"] not in EXCLUDE and (
        (r["Email"] and (l["Email"] or "").lower() == r["Email"]) or
        any(p in (last10(l["Phone"]), last10(l["MobilePhone"])) for p in r["phones"]))]
    open_ = sorted([l for l in m if not l["IsConverted"]], key=lambda l: l["CreatedDate"])
    name = f'{r["First"]} {r["Last"]}'.strip()
    if open_:
        t = open_[-1]
        e = targets.setdefault(t["Id"], {"lead": t, "rows": [], "vals": {}})
        e["rows"].append(name)
        e["vals"].update(sheet_values(r))  # later sheet row wins per field
    elif m:
        converted_only.append((name, [l["Id"] for l in m]))
    else:
        key = r["Email"] or r["phones"][0]
        c = creates.setdefault(key, {"row": r, "vals": {}})
        c["row"] = {**c["row"], **{k: v for k, v in r.items() if v}}
        c["vals"].update(sheet_values(r))

# Backup of current values for every target Lead
with open(os.path.join(S, "backup_current_values.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["Id"] + FIELDS)
    for lid, e in targets.items():
        w.writerow([lid] + [e["lead"].get(f) or "" for f in FIELDS])

# Update CSV: only fields that actually change
changes = 0
with open(os.path.join(S, "lead_update.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["Id"] + FIELDS)
    for lid, e in targets.items():
        new = {f: e["vals"].get(f, e["lead"].get(f) or "") for f in FIELDS}
        if any(new[f] != (e["lead"].get(f) or "") for f in FIELDS):
            w.writerow([lid] + [new[f] for f in FIELDS])
            changes += 1

print(f"UPDATE targets: {len(targets)} open leads, {changes} with actual changes")
for lid, e in targets.items():
    l = e["lead"]
    diff = {f: f'{l.get(f) or "∅"} -> {v}' for f, v in e["vals"].items() if v != (l.get(f) or "")}
    print(f"  {lid} {l['FirstName'] or ''} {l['LastName']} [{l['Status']}, {(l.get('RecordType') or {}).get('Name')}] rows={e['rows']}")
    for f, d in diff.items():
        print(f"      {f}: {d}")
print(f"\nSKIP (all matching leads converted): {len(converted_only)} rows")
for n, ids in converted_only:
    print("  ", n, ids)
print(f"\nCREATE candidates: {len(creates)} people")
for k, c in creates.items():
    r = c["row"]
    print(f'   {r["First"]} {r["Last"]} | {r["Email"] or "-"} | {r["Phone"] or "-"} | {r["SF"]}/{r["Class"]}/{r["AdmYear"]} | {r["SourceType"]} | {c["vals"]}')
json.dump({k: {"row": {kk: vv for kk, vv in c["row"].items() if kk != "dt"}, "vals": c["vals"]}
           for k, c in creates.items()}, open(os.path.join(S, "creates.json"), "w"), indent=1)
