/*
Function: TGC_fnc_isPlayerControlled

Description:
    Return whether an entity, its active pilot, or its UAV crew is controlled
    by a player. Supports the mission's remote-control ownership variable.

*/
params [["_entity", objNull, [objNull]]];
if (isNull _entity) exitWith {false};
if (!isNil {_entity getVariable "TGC_playerPlacedExplosiveUID"}) exitWith {true};

private _isPlayerActor = {
    params ["_actor"];
    if (isNull _actor) exitWith {false};
    if (isPlayer _actor) exitWith {true};

    private _remoteOwner = _actor getVariable ["bis_fnc_moduleRemoteControl_owner", objNull];
    isPlayer _remoteOwner
};

if ([_entity] call _isPlayerActor) exitWith {true};

private _vehicle = vehicle _entity;
if ([currentPilot _vehicle] call _isPlayerActor) exitWith {true};
if ([driver _vehicle] call _isPlayerActor) exitWith {true};
if ([effectiveCommander _vehicle] call _isPlayerActor) exitWith {true};
if (
    ((fullCrew [_vehicle, "turret", false]) findIf {
        [(_x # 0)] call _isPlayerActor
    }) >= 0
) exitWith {true};

if (unitIsUAV _vehicle) exitWith {
    // Parse the legacy UAVControl format for compatibility with the mission's
    // Arma 3 2.14 baseline. Ignore a terminal-only connection with role "".
    private _uavControl = UAVControl _vehicle;
    private _hasActivePlayer = false;
    for "_index" from 0 to ((count _uavControl) - 2) step 2 do {
        if (
            ((_uavControl # (_index + 1)) in ["DRIVER", "GUNNER"]) &&
            {[_uavControl # _index] call _isPlayerActor}
        ) exitWith {
            _hasActivePlayer = true;
        };
    };
    _hasActivePlayer
};

false
