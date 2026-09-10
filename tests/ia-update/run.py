"""Source-snapshotted, serial native regression cells using the local Server Lab."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid


def braced(text, anchor):
    if text.count(anchor) != 1:
        raise ValueError(f"Expected one extraction anchor: {anchor}")
    start = text.index(anchor)
    opening = text.index("{", start)
    depth, quote, comment, i = 0, None, None, opening
    while i < len(text):
        c, pair = text[i], text[i:i + 2]
        if comment == "//":
            if c == "\n":
                comment = None
        elif comment == "/*":
            if pair == "*/":
                comment = None
                i += 1
        elif quote:
            if c == quote:
                if text[i + 1:i + 2] == quote:
                    i += 1
                else:
                    quote = None
        elif pair in ("//", "/*"):
            comment = pair
            i += 1
        elif c in ("'", '"'):
            quote = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1] + ";\n"
        i += 1
    raise ValueError(f"Unclosed extraction: {anchor}")


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("suite", choices=["damage", "guided", "support", "radio-cleanup", "ai-spawn", "rappel-security", "hq-delete", "integration"])
    parser.add_argument("--players", type=int, choices=[0, 1, 2], default=0)
    parser.add_argument("--client-start-gap", type=int, default=3, help="Seconds between owned graphical client launches (1..120)")
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--headless", type=int, choices=[0, 1, 2], default=0)
    parser.add_argument("--observe", type=int, default=120)
    parser.add_argument("--cycle", action="store_true", help="Integration only: exercise Primary, forced Defense, cancellation and next Primary")
    parser.add_argument("--mfd-control", choices=["off", "reviewed-scout-v1"], default="off", help="Integration only: use the lab's pinned altered-content Scout display control")
    parser.add_argument("--port", type=int, default=2392)
    parser.add_argument("--lab", type=Path)
    arma_env = os.environ.get("ARMA3_ROOT")
    parser.add_argument("--arma", type=Path, default=Path(arma_env) if arma_env else None,
                        help="Arma 3 install root (or set ARMA3_ROOT)")
    args = parser.parse_args()
    tests = Path(__file__).resolve().parent
    repo = tests.parents[1]
    lab = (args.lab or repo.parent / "420th-Arma3-Server-Lab").resolve()
    if args.arma is None:
        parser.error("Provide --arma or set ARMA3_ROOT to the Arma 3 install root")
    args.arma = args.arma.resolve()
    if not (args.arma / "arma3server_x64.exe").is_file():
        parser.error(f"Arma 3 server executable not found under {args.arma}")
    if not 30 <= args.timeout <= 1800 or not 1024 <= args.port <= 65530:
        parser.error("Require timeout 30..1800 seconds and port 1024..65530")
    if not 1 <= args.client_start_gap <= 120:
        parser.error("Require client start gap 1..120 seconds")
    if not 30 <= args.observe <= 600 or (args.headless and args.suite != "integration"):
        parser.error("Require observation 30..600 seconds; headless clients use integration mode")
    if args.cycle and (args.suite != "integration" or args.players < 1 or args.timeout < 1000):
        parser.error("--cycle requires integration, at least one graphical player and --timeout >=1000 (recommended 1200)")
    if args.mfd_control != "off" and args.suite != "integration":
        parser.error("--mfd-control requires integration")
    sys.path.insert(0, str(lab / "scripts"))
    from freeze.common import Context, sha256, write_json
    from run_freeze_scenarios import execution_lock

    token = uuid.uuid4().hex[:12]
    output = lab / "artifacts/ia-update" / (token + "-" + args.suite)
    fixture = output / "fixture"
    mission = fixture / "mission"
    source = repo / "Apex_framework.terrain"
    runner_source = lab / "scripts/freeze/engine/Run-EngineCell.ps1"
    cleanup_source = lab / "scripts/freeze/engine/Cleanup-EngineCell.ps1"
    with execution_lock(token):
        mission.mkdir(parents=True)
        manifest = {}
        for path in sorted(source.rglob("*")):
            if path.is_file() and path.suffix.lower() in (".sqf", ".hpp", ".ext", ".sqm"):
                relative = path.relative_to(source)
                destination = mission / "production" / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, destination)
                manifest[relative.as_posix()] = sha256(destination)
        write_json(output / "source-manifest.json", manifest)
        shutil.copytree(tests, mission / "tests", ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(lab / "scripts/freeze/engine/mission/mission.sqm", mission / "mission.sqm")
        shutil.copy2(lab / "scripts/freeze/engine/client-start.sqf", fixture / "client-start.sqf")
        description = '''author="420th local review";
class Header { gameType=Coop; minPlayers=0; maxPlayers=2; };
disabledAI=1; joinUnassigned=0; skipLobby=1; respawn=3; respawnDelay=2; saving=0;
class CfgFunctions { class QS { tag="QS"; class Support {
file="production\\code\\functions";
class artillerySupport {postInit=1;}; class mortarSupport {};
class clientApplyEntityState {}; class serverPublishEntityState {};
}; }; };
class CfgRemoteExec { class Functions { mode=1; jip=0;
class QS_fnc_artillerySupport {allowedTargets=0;};
class QS_fnc_mortarSupport {allowedTargets=0;};
class QS_fnc_iaSupportTest {allowedTargets=2;};
class QS_fnc_eventAttach {allowedTargets=0;};
class QS_fnc_remoteExec {allowedTargets=0;};
class QS_fnc_remoteExecCmd {allowedTargets=0;};
class QS_fnc_showNotification {allowedTargets=0;};
class QS_fnc_serverSetEntityFeatureType {allowedTargets=2;};
class QS_fnc_clientApplyEntityState {allowedTargets=1; jip=0;};
}; class Commands {mode=0; jip=0;}; };
'''
        description += braced((mission / "production/description.ext").read_text(encoding="utf-8-sig"), "class CfgCommunicationMenu {")
        (mission / "description.ext").write_text(description, encoding="utf-8")
        init = (tests / "harness-init.sqf").read_text(encoding="utf-8-sig")
        init = init.replace("__SUITE__", args.suite).replace("__PLAYERS__", str(args.players))
        (mission / "init.sqf").write_text(init, encoding="utf-8")
        if args.suite == "ai-spawn":
            extractor = [sys.executable, str(tests / "ai_spawn_extract.py"), "--repo", str(repo)]
            subprocess.run(extractor + ["--source-root", str(mission / "production"), "--output", str(mission / "tests/ai-spawn-extracted")], check=True, timeout=30)
            # Verify the frozen text, normalized to LF, that the staged mission will execute.
            baseline = mission / "tests/ai-spawn-baseline"
            baseline_manifest = json.loads((baseline / "manifest.json").read_text(encoding="utf-8"))
            for record in baseline_manifest["files"]:
                path = baseline / record["path"]
                digest = hashlib.sha256(path.read_text(encoding="utf-8").encode()).hexdigest()
                if digest != record["sha256"]:
                    raise ValueError(f"AI baseline hash changed: {record['path']}")
        mfd = None
        if args.suite == "integration":
            import integration
            integration.stage(source, mission, tests, args.headless, args.players, args.observe, cycle=args.cycle)
            if args.mfd_control != "off":
                import mfd_control
                mfd = mfd_control.stage(lab, args.arma, fixture, mission)
        if args.suite == "radio-cleanup":
            from radio_cleanup_extract import extract
            extract(mission / "production", mission / "tests/radio-cleanup-extracted")
        if args.suite == "hq-delete":
            from hq_delete_extract import extract
            extract(mission / "production", mission / "tests/hq-delete-extracted")
            description_path = mission / "description.ext"
            description_text = description_path.read_text(encoding="utf-8")
            receiver_class = "class clientApplyEntityState {};"
            if description_text.count(receiver_class) != 1:
                raise ValueError("Expected one HQ fixture entity-state receiver registration")
            description_path.write_text(description_text.replace(receiver_class,
                'class clientApplyEntityState {file="tests\\hq-delete-entity-state-observer.sqf";};'), encoding="utf-8")
            init_path = mission / "init.sqf"
            init_path.write_text(f"IA_hqDelete_expectedClients = {args.players};\n" + init_path.read_text(encoding="utf-8"), encoding="utf-8")
        if args.suite == "damage":
            from damage_extract import extract
            extract(mission / "production", mission / "tests/damage-extracted")
        runner = runner_source.read_text(encoding="utf-8-sig")
        old = "Get-NetUDPEndpoint -ErrorAction Stop | Where-Object {$_.LocalPort -ge $spec.port -and $_.LocalPort -le ($spec.port+4)}"
        new = "[Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveUdpListeners() | Where-Object {$_.Port -ge $spec.port -and $_.Port -le ($spec.port+4)}"
        if runner.count(old) != 1:
            raise ValueError("Native runner port preflight changed")
        runner = runner.replace(old, new)
        if args.suite == "integration":
            runner = integration.runner(runner, args.headless)
        (output / "Run-Cell.ps1").write_text(runner, encoding="utf-8")
        cleanup = cleanup_source.read_text(encoding="utf-8-sig")
        cleanup = cleanup.replace("'artifacts\\fe'", "'artifacts\\ia-update'")
        cleanup = cleanup.replace("'^E(0[1-9]|1[0-9]|2[0-2])$'", "'^(damage|guided|support|radio-cleanup|ai-spawn|rappel-security|hq-delete|integration)$'")
        old_name = "('^'+$spec.run_token+'-'+$spec.scenario+'-[0-2][AB](-X(08|09)-[01][01])?$')"
        if cleanup.count(old_name) != 1:
            raise ValueError("Cleanup identity guard changed")
        cleanup = cleanup.replace(old_name, "('^'+$spec.run_token+'-'+$spec.scenario+'$')")
        if args.suite == "integration":
            cleanup = integration.cleanup(cleanup, args.headless)
        (output / "Cleanup-Cell.ps1").write_text(cleanup, encoding="utf-8")
        spec = dict(lab=str(lab), output=str(output), arma_root=str(args.arma), fixture=str(fixture),
                    players=args.players, headless=args.headless, port=args.port, server_mods=[], client_mods=[], scenario=args.suite,
                    visible_graphical=False, render_mode="fixed", mission_addons=["A3_Characters_F_BLUFOR"],
                    extra_compile_sources=[], interaction={}, parameters=[], max_evidence_bytes=64 * 1024 * 1024,
                    client_start_gap_seconds=args.client_start_gap, timeout_seconds=args.timeout, run_token=token)
        spec["mfd_control_mode"] = args.mfd_control
        if mfd is not None:
            spec["server_mods"] = [str(mfd[0])]
            spec["client_mods"] = [str(mfd[0])]
            spec["mfd_control_identity"] = mfd[1]
        if args.suite == "integration":
            spec["cycle"] = args.cycle
            if args.cycle:
                spec["cycle_budget_seconds"] = 660
                spec["cycle_defense_observation_seconds"] = 90
            # Arma places a packed copy of the full mission in each profile.
            mission_bytes = sum(p.stat().st_size for p in mission.rglob("*") if p.is_file())
            spec["max_evidence_bytes"] += 2 * mission_bytes * (1 + args.players + args.headless)
            spec["profile_mission_cache_budget"] = spec["max_evidence_bytes"] - 64 * 1024 * 1024
        write_json(output / "spec.json", spec)
        fixture_manifest = {p.relative_to(fixture).as_posix(): sha256(p) for p in fixture.rglob("*") if p.is_file()}
        write_json(output / "fixture-manifest.json", fixture_manifest)
        write_json(output / "harness-identity.json", {str(p.relative_to(lab)) if p.is_relative_to(lab) else p.name: sha256(p)
                   for p in (runner_source, cleanup_source, output / "Run-Cell.ps1", output / "Cleanup-Cell.ps1", Path(__file__))})
        print(json.dumps({"output": str(output), "suite": args.suite}), flush=True)
        ctx = Context(lab, output, token, timeout_seconds=args.timeout + 180)
        argv = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]
        try:
            ctx.command(argv + [str(output / "Run-Cell.ps1"), "-SpecPath", str(output / "spec.json")], args.timeout + 90)
        finally:
            with ctx.cleanup_window():
                ctx.command(argv + [str(output / "Cleanup-Cell.ps1"), "-SpecPath", str(output / "spec.json")], 90)
        records, malformed = [], []
        for rpt in output.glob("*.rpt"):
            for line in rpt.read_text(encoding="utf-8-sig", errors="replace").splitlines():
                # Arma left-pads one-digit local hours in RPT timestamps.
                if re.match(r"^\s*\d{1,2}:\d{2}:\d{2} FRZ\|", line):
                    try:
                        records.append(json.loads(line.split("FRZ|", 1)[1]))
                    except json.JSONDecodeError:
                        malformed.append(dict(role=rpt.stem, length=len(line)))
        checks = [r for r in records if r[1] == "check"]
        failures = [r for r in checks if r[4][1] is not True]
        report = json.loads((output / "report.json").read_text(encoding="utf-8-sig"))
        cleanup_report = json.loads((output / "cleanup.json").read_text(encoding="utf-8-sig"))
        changed = [p for p, digest in manifest.items() if sha256(mission / "production" / p) != digest]
        fixture_changed = [p for p, digest in fixture_manifest.items() if sha256(fixture / p) != digest]
        runtime = output / "home/MPMissions/FRZ_Engine.Altis"
        runtime_changed = []
        for relative, digest in fixture_manifest.items():
            if not relative.startswith("mission/"):
                continue
            deployed = runtime / relative[len("mission/"):]
            if not deployed.is_file() or sha256(deployed) != digest:
                runtime_changed.append(relative)
        result = dict(suite=args.suite, completed=report["completed"], checks=len(checks), failures=failures,
                      script_errors=sum(r["script_errors"] for r in report["rpts"]),
                      error=report["error"], cleanup_errors=report["cleanup_errors"] + cleanup_report["errors"],
                      frozen_source_changed=changed, fixture_changed=fixture_changed, runtime_changed=runtime_changed,
                      malformed_records=malformed, mfd_control_mode=args.mfd_control)
        if args.suite == "integration":
            result["cycle"] = args.cycle
        result["passed"] = bool(checks) and not any((not result["completed"], failures, result["script_errors"], result["error"], result["cleanup_errors"], changed, fixture_changed, runtime_changed, malformed))
        write_json(output / "result.json", result)
        write_json(output / "records.json", records)
        print(json.dumps(result), flush=True)
        return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
