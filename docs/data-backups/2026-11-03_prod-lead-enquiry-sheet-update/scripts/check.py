import json, subprocess, sys, os
S = sys.argv[1]
rows = []
for l in open(os.path.join(S, "rows.tsv")):
    f, ln, em, ph = l.rstrip("\n").split("|")
    rows.append((f, ln, em.lower(), [p for p in ph.split("/") if p]))
emails = sorted({r[2] for r in rows if r[2]})
phones = sorted({p for r in rows for p in r[3]})
def q(soql):
    out = subprocess.run(["sf","data","query","-o","au-prod","-q",soql,"--json"],capture_output=True,text=True,shell=True).stdout
    return json.loads(out)["result"]["records"]
F = "Id, FirstName, LastName, Email, Phone, MobilePhone, Status, IsConverted, CreatedDate"
leads = {}
for r in q(f"SELECT {F} FROM Lead WHERE Email IN ({','.join(repr(e) for e in emails)})"):
    leads[r["Id"]] = r
for i in range(0, len(phones), 15):
    chunk = phones[i:i+15]
    cond = " OR ".join(f"Phone LIKE '%{p}' OR MobilePhone LIKE '%{p}'" for p in chunk)
    for r in q(f"SELECT {F} FROM Lead WHERE {cond}"):
        leads[r["Id"]] = r
def digits(s): return "".join(c for c in (s or "") if c.isdigit())[-10:]
res = []
for f, ln, em, ph in rows:
    m = [l for l in leads.values() if (em and (l["Email"] or "").lower()==em) or any(p and p in (digits(l["Phone"]), digits(l["MobilePhone"])) for p in ph)]
    res.append((f, ln, em, "/".join(ph), m))
json.dump({"rows":[[a,b,c,d,[{k:x[k] for k in ("Id","FirstName","LastName","Email","Phone","MobilePhone","Status","IsConverted","CreatedDate")} for x in m]] for a,b,c,d,m in res],"uniqueLeads":len(leads)}, open(os.path.join(S,"result.json"),"w"), indent=1)
found = sum(1 for r in res if r[4])
print(f"Input rows: {len(rows)} | rows with match: {found} | rows without: {len(rows)-found} | unique Lead records matched: {len(leads)}")
print(f"Unique contacts (email/phone) checked: {len(emails)} emails, {len(phones)} phones")
for a,b,c,d,m in res:
    tag = f"{len(m)} lead(s)" if m else "NOT FOUND"
    det = "; ".join(f"{x['Id']} {x['FirstName'] or ''} {x['LastName']} [{x['Status']}{', converted' if x['IsConverted'] else ''}] {x['CreatedDate'][:10]}" for x in m)
    print(f"{tag:10} | {a} {b} | {c or '-'} | {d or '-'} | {det}")
