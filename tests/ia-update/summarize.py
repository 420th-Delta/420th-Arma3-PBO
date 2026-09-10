"""Print bounded, identity-free native results; raw RPTs stay in ignored artifacts."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re


def records(path):
    result, malformed = [], 0
    for line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        if not re.match(r"^\d{1,2}:\d{2}:\d{2} FRZ\|", line):
            continue
        try:
            result.append(json.loads(line.split("FRZ|", 1)[1]))
        except ValueError:
            malformed += 1
    return result, malformed


def summarize(cell):
    result = {"cell": cell.name, "records": 0, "malformed": 0, "checks": 0, "failures": [], "damage": {}}
    counts = Counter()
    for path in cell.glob("*.rpt"):
        rows, malformed = records(path)
        result["records"] += len(rows)
        result["malformed"] += malformed
        for row in rows:
            if row[1] == "check":
                result["checks"] += 1
                if row[4][1] is not True:
                    result["failures"].append([row[0], row[4][0]])
            elif row[1] == "damage_event" and row[4][1] == "HandleDamage":
                case, _, _, payload = row[4]
                # Actual projectile events with a known instigator, on-foot victims.
                if payload[0].startswith("FOOT_") and payload[3] and not payload[9][3]:
                    counts[(case, payload[8][3], payload[11])] += 1
    result["damage"] = [{"case": k[0], "source_null": k[1], "multiplier": k[2], "events": v} for k, v in sorted(counts.items())]
    report = cell / "report.json"
    if report.exists():
        native = json.loads(report.read_text(encoding="utf-8-sig"))
        result.update(completed=native["completed"], error=native["error"], cleanup_errors=native["cleanup_errors"],
                      script_errors=sum(r["script_errors"] for r in native["rpts"]))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("cell", type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(args.cell), indent=2))
