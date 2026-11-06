"""Build composite POST body for Phase 2 Lead creates (no org writes)."""
import json, os, sys

S = sys.argv[1]
RT_UG = "0125g000002SMZSAA4"  # Undergraduation, same Id in au-prod and au-uat (verified via describe)
creates = json.load(open(os.path.join(S, "creates.json"), encoding="utf-8"))
records = []
for c in creates.values():
    r, v = c["row"], dict(c["vals"])
    first, last = r.get("First", ""), r.get("Last", "")
    if not last:  # user decision: Sumit -> LastName 'Sumit', FirstName blank
        first, last = "", first
    if v.get("Educator_Counsellor_Text__c") == "Neela":  # user decision: typo -> Neelam
        v["Educator_Counsellor_Text__c"] = "Neelam"
    phones = [p for p in r.get("Phone", "").split("/") if p]
    rec = {"attributes": {"type": "Lead"}, "LastName": last, "RecordTypeId": RT_UG,
           "Department__c": "Undergraduation", "LeadSource": r["SourceType"],
           "Class__c": "Lateral" if r["SF"] == "Lateral" else r["Class"]}
    if first: rec["FirstName"] = first
    if r.get("Email"): rec["Email"] = r["Email"]
    if phones:
        rec["MobilePhone"] = phones[0]
        rec["Phone"] = phones[1] if len(phones) > 1 else phones[0]
    rec.update(v)
    records.append(rec)
json.dump({"allOrNone": False, "records": records}, open(os.path.join(S, "lead_create.json"), "w", encoding="utf-8"),
          indent=1, ensure_ascii=False)
print(f"{len(records)} records")
print("| # | First | Last | Email | Mobile | Source | Class | Adm Year | Programme | Major | Counsellor | Enquiry Type | Other |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for i, x in enumerate(records, 1):
    other = "; ".join(f"{k.replace('__c','').replace('_',' ')}: {x[k]}" for k in
                      ("School_City__c", "Board_c__c", "School__c", "Name_of_University_College__c") if x.get(k))
    print(f"| {i} | {x.get('FirstName','—')} | {x['LastName']} | {x.get('Email','—')} | {x.get('MobilePhone','—')}"
          f"{' / ' + x['Phone'] if x.get('Phone') and x['Phone'] != x.get('MobilePhone') else ''} | {x['LeadSource']} | {x['Class__c']} | "
          f"{x.get('Admission_Year__c','—')} | {x.get('Programme_Interested_in__c','—')} | {x.get('Major__c','—')} | "
          f"{x.get('Educator_Counsellor_Text__c')} | {x.get('Enquiry_Type__c')} | {other or '—'} |")
