"""READ-ONLY: re-check the 22 'create' people against Lead parent/WhatsApp fields and Contacts."""
import json, os, subprocess, sys

S = sys.argv[1]
creates = json.load(open(os.path.join(S, "creates.json"), encoding="utf-8"))

def q(soql):
    out = subprocess.run(["sf", "data", "query", "-o", "au-prod", "-q", soql, "--json"],
                         capture_output=True, text=True, shell=True).stdout
    return json.loads(out)["result"]["records"]

def last10(s):
    return "".join(c for c in (s or "") if c.isdigit())[-10:]

people = []
for c in creates.values():
    r = c["row"]
    people.append({"name": f'{r.get("First","")} {r.get("Last","")}'.strip(), "email": r.get("Email", "").lower(),
                   "phones": [p for p in r.get("Phone", "").split("/") if p], "first": r.get("First", "")})
emails = sorted({p["email"] for p in people if p["email"]})
phones = sorted({x for p in people for x in p["phones"]})
el = ",".join(f"'{e}'" for e in emails)

LF = "Id, Name, Email, Phone, MobilePhone, Parent_Email_Id__c, Parent_Phone__c, Whatsapp_Number__c, Status, IsConverted, CreatedDate"
CF = "Id, Name, Email, Phone, MobilePhone, Account.Name, CreatedDate"
hits = []
hits += [("Lead", x) for x in q(f"SELECT {LF} FROM Lead WHERE Parent_Email_Id__c IN ({el})")]
hits += [("Contact", x) for x in q(f"SELECT {CF} FROM Contact WHERE Email IN ({el})")]
for i in range(0, len(phones), 10):
    ch = phones[i:i + 10]
    lc = " OR ".join(f"Parent_Phone__c LIKE '%{p}' OR Whatsapp_Number__c LIKE '%{p}'" for p in ch)
    hits += [("Lead", x) for x in q(f"SELECT {LF} FROM Lead WHERE {lc}")]
    cc = " OR ".join(f"Phone LIKE '%{p}' OR MobilePhone LIKE '%{p}'" for p in ch)
    hits += [("Contact", x) for x in q(f"SELECT {CF} FROM Contact WHERE {cc}")]

seen = set()
for p in people:
    found = []
    for obj, x in hits:
        why = []
        if p["email"]:
            for f in ("Email", "Parent_Email_Id__c"):
                if (x.get(f) or "").lower() == p["email"]:
                    why.append(f"{obj}.{f}")
        for ph in p["phones"]:
            for f in ("Phone", "MobilePhone", "Parent_Phone__c", "Whatsapp_Number__c"):
                if f in x and last10(x.get(f)) == ph:
                    why.append(f"{obj}.{f}")
        if why and (obj, x["Id"]) not in {(o, i) for o, i, _ in found}:
            found.append((obj, x["Id"], f'{x["Name"]} [{x.get("Status") or (x.get("Account") or {}).get("Name") or ""}'
                          f'{", converted" if x.get("IsConverted") else ""}] {x["CreatedDate"][:10]} via {"/".join(sorted(set(why)))}'))
    tag = "FOUND" if found else "NOT FOUND"
    print(f'{tag:9} | {p["name"]} | {p["email"] or "-"} | {"/".join(p["phones"]) or "-"}')
    for o, i, d in found:
        print(f"            {o} {i} {d}")
