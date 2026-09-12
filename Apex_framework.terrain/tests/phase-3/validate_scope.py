#!/usr/bin/env python3
"""Protect the Phase 1 and Phase 2 boundaries on the Phase 3 staging branch."""

from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
BASE_REF = os.environ.get(
    "PHASE2_BASE_REF", "stage/phase2-aa-turrets-20260912"
)
TARU_PATH = "Apex_framework.terrain/code/functions/fn_AIXHeliInsert.sqf"

# These files implement the Jolly systems explicitly deferred from this rollout.
IMMUTABLE_FILES = (
    "Apex_framework.terrain/code/functions/fn_AIXMissileCountermeasure.sqf",
    "Apex_framework.terrain/code/functions/fn_enemyCAS.sqf",
)

# Phase 2 owns these controller and deployable-AA files. Description.ext is
# intentionally absent because Phase 3 registers the Support functions there.
IMMUTABLE_PHASE2_FILES = (
    "Apex_framework.terrain/code/config/airDefense.sqf",
    "Apex_framework.terrain/code/functions/fn_deployAssetPreset.sqf",
    "Apex_framework.terrain/code/functions/fn_spawnMenu.sqf",
    "Apex_framework.terrain/code/functions/fn_spawnMenuServerSpawn.sqf",
    "Apex_framework.terrain/code/functions/fn_vSetup2.sqf",
    "Apex_framework.terrain/code/functions/fn_vSetupContainer.sqf",
    "Apex_framework.terrain/mission.sqm",
)

PHASE2_CONTROLLER_PREFIXES = (
    "Apex_framework.terrain/code/functions/fn_airDefense",
    "Apex_framework.terrain/code/functions/fn_priorityAA",
)
PHASE2_CONTROLLER_FILES = (
    "Apex_framework.terrain/code/functions/fn_SMpriorityAA.sqf",
    "Apex_framework.terrain/code/functions/fn_SMpriorityAALegacy.sqf",
    "Apex_framework.terrain/code/functions/fn_sideMissionPositions.sqf",
)

# Scan added and removed production-source lines only. Baseline references are
# allowed; a Phase 3 edit may not introduce or rearrange the deferred systems.
FORBIDDEN_SOURCE_PATTERN = re.compile(
    r"QS_fnc_combatAir|QS_combatAir|enemyCAS|AIXMissileCountermeasure",
    re.IGNORECASE,
)


def git(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *arguments],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if check and result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise AssertionError(f"git {' '.join(arguments)} failed: {detail}")
    return result


def require_base() -> None:
    git("rev-parse", "--verify", f"{BASE_REF}^{{commit}}")


def is_changed(relative: str) -> bool:
    result = git("diff", "--quiet", BASE_REF, "--", relative, check=False)
    if result.returncode == 0:
        return False
    if result.returncode == 1:
        return True
    detail = result.stderr.strip() or result.stdout.strip()
    raise AssertionError(f"could not compare {relative}: {detail}")


def changed_paths() -> set[str]:
    result = git("diff", "--name-only", BASE_REF, "--")
    return {line for line in result.stdout.splitlines() if line}


def production_change_lines() -> list[str]:
    result = git(
        "diff",
        "--no-ext-diff",
        "--unified=0",
        BASE_REF,
        "--",
        "Apex_framework.terrain/code",
        "Apex_framework.terrain/TGC",
        "Apex_framework.terrain/description.ext",
    )
    return [
        line
        for line in result.stdout.splitlines()
        if line[:1] in {"+", "-"} and not line.startswith(("+++", "---"))
    ]


def base_text(relative: str) -> str:
    return git("show", f"{BASE_REF}:{relative}").stdout.replace("\r\n", "\n")


def worktree_text(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise AssertionError(f"missing required file: {relative}")
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def taru_block(text: str) -> str:
    begin = "// TARU_INTEGRATION_BEGIN"
    end = "// TARU_INTEGRATION_END"
    try:
        start = text.index(begin)
        finish = text.index(end, start) + len(end)
    except ValueError as error:
        raise AssertionError("Taru integration markers are missing") from error
    return text[start:finish]


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing {token!r}")


def main() -> int:
    require_base()

    for relative in (*IMMUTABLE_FILES, *IMMUTABLE_PHASE2_FILES):
        if is_changed(relative):
            raise AssertionError(f"Phase 3 changes protected Phase 2 source: {relative}")

    for relative in changed_paths():
        if relative.startswith(PHASE2_CONTROLLER_PREFIXES) or relative in PHASE2_CONTROLLER_FILES:
            raise AssertionError(f"Phase 3 changes the Phase 2 AA controller: {relative}")

    forbidden_lines = [
        line
        for line in production_change_lines()
        if FORBIDDEN_SOURCE_PATTERN.search(line)
    ]
    if forbidden_lines:
        raise AssertionError(
            "Phase 3 diff contains deferred Combat Air, enemy-CAS, or "
            f"missile-countermeasure source: {forbidden_lines[0]!r}"
        )

    base_taru = taru_block(base_text(TARU_PATH))
    current_taru = taru_block(worktree_text(TARU_PATH))
    if current_taru != base_taru:
        raise AssertionError(
            "Phase 1 Taru integration changed; keep the early Taru modes exactly intact"
        )
    for token in ("TARU_POLICY", "TARU_CREATE", "TARU_DELIVER"):
        require(current_taru, token, TARU_PATH)

    # The Phase 2 registration remains present even though description.ext has
    # legitimate Phase 3 Support registrations beside it.
    description = worktree_text("Apex_framework.terrain/description.ext")
    for token in ("class airDefenseInit", "class priorityAAScheduler"):
        require(description, token, "description.ext")
    require(
        worktree_text("Apex_framework.terrain/code/functions/fn_init.sqf"),
        "call QS_fnc_airDefenseInit",
        "fn_init.sqf",
    )

    print(f"Phase 3 scope guard passed against {BASE_REF}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"Phase 3 scope guard failed: {error}", file=sys.stderr)
        raise SystemExit(1)
