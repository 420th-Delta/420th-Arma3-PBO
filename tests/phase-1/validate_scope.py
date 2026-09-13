#!/usr/bin/env python3
"""Reject Phase 2/3 feature leakage from the Phase 1 rollout branch."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Apex_framework.terrain"


def read(relative: str) -> str:
    path = MISSION / relative
    if not path.is_file():
        raise AssertionError(f"missing Phase 1 file: {relative}")
    return path.read_text(encoding="utf-8")


def required(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing {token!r}")


def forbidden(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} leaks deferred functionality: {token!r}")


def main() -> int:
    ai = read("code/functions/fn_AI.sqf")
    fire = read("code/functions/fn_AIFireMission.sqf")
    defend = read("code/functions/fn_aoDefend.sqf")
    core = read("code/functions/fn_core.sqf")
    heli = read("code/functions/fn_AIXHeliInsert.sqf")
    remote = read("code/functions/fn_remoteExec.sqf")
    rappel = read("code/scripts/AR_AdvancedRappelling_ext.sqf")
    building = read("code/functions/fn_eventBuildingChanged.sqf")
    kavala = read("code/functions/fn_missionKavala.sqf")

    for token in (
        "PRIMARY_AO_CONTROLLER_BEGIN",
        "PRIMARY_CONTACT_CONTROLLER_BEGIN",
        "GROUND_TARGET_PRIORITY_BEGIN",
        "TARU_ADMISSION_BEGIN",
    ):
        required(ai, token, "fn_AI.sqf")
    required(fire, "private _primaryMortar", "fn_AIFireMission.sqf")
    for token in ("DEFENSE_FLANK_CONTROLLER_BEGIN", "MEGA_DEFENSE_ENTRY_BEGIN"):
        required(defend, token, "fn_aoDefend.sqf")
    for token in ("HOUSEKEEPING_HELPERS_BEGIN", "HOUSEKEEPING_TICK_BEGIN", "RUIN_ROTATION_BEGIN"):
        required(core, token, "fn_core.sqf")
    required(building, "QS_cleanup_ruinQueue", "fn_eventBuildingChanged.sqf")
    for token in ("TARU_POLICY", "TARU_CREATE", "TARU_DELIVER"):
        required(heli, token, "fn_AIXHeliInsert.sqf")
    for token in ("case 65", "case 75"):
        required(remote, token, "fn_remoteExec.sqf")
    required(rappel, "AR_Rappel_All_Cargo", "AR_AdvancedRappelling_ext.sqf")
    forbidden(kavala, "QS_kavalaRevive", "fn_missionKavala.sqf")

    phase_one = {
        "fn_AI.sqf": ai,
        "fn_AIFireMission.sqf": fire,
        "fn_aoDefend.sqf": defend,
        "fn_core.sqf": core,
        "fn_AIXHeliInsert.sqf": heli,
        "fn_remoteExec.sqf": remote,
        "AR_AdvancedRappelling_ext.sqf": rappel,
    }
    deferred = (
        "QS_fnc_combatAir",
        "QS_combatAir_",
        "QS_fnc_artillerySupport",
        "QS_fnc_mortarSupport",
        "QS_kavalaRevive",
        "KAVALA_DISCREET",
        "case 111",
    )
    for source, text in phase_one.items():
        for token in deferred:
            forbidden(text, token, source)

    print("Phase 1 scope guard passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"Phase 1 scope guard failed: {error}", file=sys.stderr)
        raise SystemExit(1)
