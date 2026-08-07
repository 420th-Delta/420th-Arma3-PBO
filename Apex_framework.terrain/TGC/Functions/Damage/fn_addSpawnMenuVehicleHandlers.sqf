/*
Function: TGC_fnc_addSpawnMenuVehicleHandlers

Description:
    Keep friendly-fire protection attached to a Spawn Menu vehicle on whichever
    machine currently owns it.

Parameters:
    Object vehicle:
        The Spawn Menu vehicle to protect.

Author:
    thegamecracks

*/
params ["_vehicle"];

if (
    (isNull _vehicle) ||
    {((["LandVehicle", "Air", "Ship"] findIf {_vehicle isKindOf _x}) isEqualTo -1)}
) exitWith {};

if (isNil {_vehicle getVariable "TGC_spawnMenuVehicle_localEH"}) then {
    private _localEH = _vehicle addEventHandler ["Local", {
        params ["_vehicle", "_isLocal"];

        if (!_isLocal) exitWith {
            private _damageEH = _vehicle getVariable ["TGC_spawnMenuVehicle_damageEH", -1];
            if (
                (_damageEH >= 0) &&
                {(_vehicle getEventHandlerInfo ["HandleDamage", _damageEH]) param [0, false]}
            ) then {
                _vehicle removeEventHandler ["HandleDamage", _damageEH];
            };
            _vehicle setVariable ["TGC_spawnMenuVehicle_damageEH", nil];
        };

        _vehicle setVariable ["TGC_spawnMenuVehicle_damageEH", nil];
        [_vehicle] call TGC_fnc_addSpawnMenuVehicleHandlers;
    }];
    _vehicle setVariable ["TGC_spawnMenuVehicle_localEH", _localEH];
};

if (!local _vehicle) exitWith {};

private _existingDamageEH = _vehicle getVariable ["TGC_spawnMenuVehicle_damageEH", -1];
if (
    (_existingDamageEH >= 0) &&
    {(_vehicle getEventHandlerInfo ["HandleDamage", _existingDamageEH]) param [0, false]}
) exitWith {
    [_vehicle] call TGC_fnc_addEmptyVehicleHandlers;
};

private _damageEH = _vehicle addEventHandler [
    "HandleDamage",
    {call QS_fnc_clientVehicleEventHandleDamage}
];
_vehicle setVariable ["TGC_spawnMenuVehicle_damageEH", _damageEH];
[_vehicle] call TGC_fnc_addEmptyVehicleHandlers;
