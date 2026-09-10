"""Run installed CfgConvert against the actual candidate configuration."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import uuid


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    tool_env = os.environ.get("ARMA3_CFGCONVERT")
    parser.add_argument("--tool", type=Path, default=Path(tool_env) if tool_env else None,
                        help="CfgConvert.exe path (or set ARMA3_CFGCONVERT)")
    args = parser.parse_args()
    if args.tool is None:
        parser.error("Provide --tool or set ARMA3_CFGCONVERT to CfgConvert.exe")
    args.tool = args.tool.resolve()
    if not args.tool.is_file():
        parser.error(f"CfgConvert executable not found: {args.tool}")
    repo = Path(__file__).resolve().parents[2]
    mission = repo / "Apex_framework.terrain"
    output = repo.parent / "420th-Arma3-Server-Lab/artifacts/ia-update" / (uuid.uuid4().hex[:12] + "-config")
    output.mkdir(parents=True)
    results = []
    for relative in ("description.ext", "mission.sqm", "code/config/security.hpp"):
        path = mission / relative
        completed = subprocess.run([str(args.tool), "-test", str(path)], cwd=mission, capture_output=True, timeout=60)
        (output / (path.name + ".stdout.txt")).write_bytes(completed.stdout)
        (output / (path.name + ".stderr.txt")).write_bytes(completed.stderr)
        results.append(dict(file=relative, returncode=completed.returncode, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    result = dict(tool_sha256=hashlib.sha256(args.tool.read_bytes()).hexdigest(), files=results,
                  passed=all(row["returncode"] == 0 for row in results))
    (output / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(dict(output=str(output), **result)))
    raise SystemExit(0 if result["passed"] else 1)
