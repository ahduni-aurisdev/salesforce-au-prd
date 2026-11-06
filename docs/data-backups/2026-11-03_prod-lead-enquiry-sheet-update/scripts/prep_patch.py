"""Build composite PATCH body (changed fields only) and verify prod still matches backup."""
import csv, json, os, subprocess, sys

S = sys.argv[1]
old = {r["Id"]: r for r in csv.DictReader(open(os.path.join(S, "backup_current_values.csv"), encoding="utf-8"))}
new = {r["Id"]: r for r in csv.DictReader(open(os.path.join(S, "lead_update.csv"), encoding="utf-8"))}
fields = [f for f in next(iter(new.values())) if f != "Id"]

ids = ",".join(f"'{i}'" for i in new)
out = subprocess.run(["sf", "data", "query", "-o", "au-prod", "-q",
                      f"SELECT Id, {', '.join(fields)} FROM Lead WHERE Id IN ({ids})", "--json"],
                     capture_output=True, text=True, shell=True).stdout
live = {r["Id"]: r for r in json.loads(out)["result"]["records"]}
drift = [(i, f) for i in new for f in fields if (live[i].get(f) or "") != old[i][f]]
if drift:
    print("DRIFT since backup - aborting:", drift)
    sys.exit(1)

records, nchg = [], 0
for i, r in new.items():
    chg = {f: (r[f] or None) for f in fields if r[f] != old[i][f]}
    if chg:
        records.append({"attributes": {"type": "Lead"}, "id": i, **chg})
        nchg += len(chg)
json.dump({"allOrNone": False, "records": records},
          open(os.path.join(S, "lead_update.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print(f"No drift. {len(records)} records, {nchg} field changes -> lead_update.json")
