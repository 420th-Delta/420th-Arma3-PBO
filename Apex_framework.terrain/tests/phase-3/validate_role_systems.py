#!/usr/bin/env python3
"""Check the static wiring of the Phase 3 role and lifecycle systems."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
MISSION = ROOT / "Apex_framework.terrain"


def read(relative: str) -> str:
    path = MISSION / relative
    if not path.is_file():
        raise AssertionError(f"missing Phase 3 file: {relative}")
    return path.read_text(encoding="utf-8")


def required(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing {token!r}")


def require_all(relative: str, *tokens: str) -> None:
    text = read(relative)
    for token in tokens:
        required(text, token, relative)


def main() -> int:
    require_all(
        "description.ext",
        "class artillerySupport",
        "class mortarSupport",
        "QS_RequestMk6Mortar",
        "QS_fnc_artillerySupport",
        "QS_fnc_mortarSupport",
        "ReviveBleedOutDelay = 300",
    )
    require_all(
        "code/config/security.hpp",
        "class QS_fnc_artillerySupport",
        "class QS_fnc_mortarSupport",
    )
    require_all(
        "code/functions/fn_roles.sqf",
        "forward_observer",
        "mortar_gunner",
        "['CLIENT'] call QS_fnc_artillerySupport",
    )
    require_all(
        "code/functions/fn_artillerySupport.sqf",
        "forward_observer",
        "['REQUEST'",
        "QS_artillerySupport_menuOwner",
    )
    require_all(
        "code/functions/fn_mortarSupport.sqf",
        "mortar_gunner",
        "QS_mortarSupport_owner",
        "['REQUEST'",
    )
    require_all(
        "code/functions/fn_AI.sqf",
        "['WATCHDOG'] call QS_fnc_artillerySupport",
        "['START','PRIMARY'",
        "forward_observer",
        "mortar_gunner",
    )
    require_all(
        "code/functions/fn_aoDefend.sqf",
        "['START','DEFENSE'",
        "forward_observer",
        "mortar_gunner",
    )
    require_all(
        "code/functions/fn_core.sqf",
        "['TICK'] call QS_fnc_mortarSupport",
        "QS_kavalaRevive_active",
        "_fn_cleanupKavalaSafe",
    )

    require_all(
        "code/functions/fn_config.sqf",
        "QS_missionConfig_sharedRadioChannels",
        "QS_radio_sharedBroadcastsEnabled",
    )
    require_all(
        "code/functions/fn_clientRadio.sqf",
        "QS_radio_sharedBroadcastsEnabled",
        "radioChannelRemove [_oldBody]",
    )
    require_all(
        "TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf",
        "QS_radio_sharedBroadcastsEnabled",
        "radioChannelAdd [player]",
    )

    require_all(
        "code/functions/fn_incapacitated.sqf",
        "QS_kavalaRevive_active",
        "forward_observer",
        "mortar_gunner",
        "['CLIENT'] call QS_fnc_artillerySupport",
    )
    require_all(
        "code/functions/fn_missionKavala.sqf",
        "QS_kavalaRevive_active",
        "KAVALA_DISCREET",
    )

    require_all(
        "code/functions/fn_serverObjectsMapper.sqf",
        "QS_client_houseVectors",
        "vectorDir _mappedHouse",
        "vectorUp _mappedHouse",
    )
    require_all(
        "code/functions/fn_serverPublishEntityState.sqf",
        "QS_client_houseVectors",
        "_houseVectors",
    )
    require_all(
        "code/functions/fn_clientApplyEntityState.sqf",
        "_houseVectors",
        "setVectorDirAndUp _houseVectors",
    )

    print("Phase 3 role and lifecycle static checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"Phase 3 role/lifecycle check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
