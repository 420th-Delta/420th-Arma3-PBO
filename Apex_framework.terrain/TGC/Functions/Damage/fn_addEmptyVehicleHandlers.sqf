/*
Function: TGC_fnc_addEmptyVehicleHandlers

Description:
    Prevent players and BLUFOR-friendly AI from damaging an unoccupied Spawn
    Menu vehicle. Install the object handlers idempotently and keep
    HandleDamage last.

Parameters:
    Object vehicle:
        Spawn Menu land, air, or sea vehicle to protect while its crew is empty.

Author:
    thegamecracks

*/
params [["_vehicle", objNull, [objNull]]];

if (
    (isNull _vehicle) ||
    {(_vehicle getVariable ["QS_spawnMenu_spawnedBy", ""]) isEqualTo ""} ||
    {((["LandVehicle", "Air", "Ship"] findIf {_vehicle isKindOf _x}) isEqualTo -1)}
) exitWith {};

private _existingLocalEH = _vehicle getVariable ["TGC_emptyVehicle_localEH", -1];
if !(
    (_existingLocalEH >= 0) &&
    {(_vehicle getEventHandlerInfo ["Local", _existingLocalEH]) param [0, false]}
) then {
    private _localEH = _vehicle addEventHandler ["Local", {
        params ["_vehicle", "_isLocal"];
        if (_isLocal) then {
            [_vehicle] call TGC_fnc_addEmptyVehicleHandlers;
        };
    }];
    _vehicle setVariable ["TGC_emptyVehicle_localEH", _localEH];
};

private _existingCollisionEH = _vehicle getVariable ["TGC_emptyVehicle_collisionEH", -1];
if !(
    (_existingCollisionEH >= 0) &&
    {(_vehicle getEventHandlerInfo ["EpeContactStart", _existingCollisionEH]) param [0, false]}
) then {
    private _collisionEH = _vehicle addEventHandler ["EpeContactStart", {
        params ["_vehicle", "_collider"];
        if (!local _vehicle || {(crew _vehicle) isNotEqualTo []}) exitWith {};

        if (
            [_vehicle, "", 0, _collider, "", -1, objNull, "", false]
            call TGC_fnc_isProtectedEmptyVehicleDamage
        ) then {
            _vehicle setVariable ["TGC_playerDamageCollisionUntil", diag_tickTime + 1];
        };
    }];
    _vehicle setVariable ["TGC_emptyVehicle_collisionEH", _collisionEH];
};

private _existingGetOutEH = _vehicle getVariable ["TGC_emptyVehicle_getOutEH", -1];
if !(
    (_existingGetOutEH >= 0) &&
    {(_vehicle getEventHandlerInfo ["GetOut", _existingGetOutEH]) param [0, false]}
) then {
    private _getOutEH = _vehicle addEventHandler ["GetOut", {
        params ["_vehicle"];
        if ((crew _vehicle) isEqualTo []) then {
            [_vehicle] call TGC_fnc_addEmptyVehicleHandlers;
        };
    }];
    _vehicle setVariable ["TGC_emptyVehicle_getOutEH", _getOutEH];
};

private _existingDamageEH = _vehicle getVariable ["TGC_emptyVehicle_damageEH", -1];
private _existingDamageEHInfo = if (_existingDamageEH >= 0) then {
    _vehicle getEventHandlerInfo ["HandleDamage", _existingDamageEH]
} else {
    []
};
if (
    (_existingDamageEHInfo param [0, false]) &&
    {_existingDamageEHInfo param [1, false]}
) exitWith {};

if (_existingDamageEHInfo param [0, false]) then {
    _vehicle removeEventHandler ["HandleDamage", _existingDamageEH];
};

private _damageEH = _vehicle addEventHandler ["HandleDamage", {call {
    params ["_vehicle", "", "", "", "", "_hitIndex"];
    if ((_vehicle getVariable ["QS_spawnMenu_spawnedBy", ""]) isEqualTo "") exitWith {};
    if ((crew _vehicle) isNotEqualTo []) exitWith {};
    if !(_this call TGC_fnc_isProtectedEmptyVehicleDamage) exitWith {};

    if (_hitIndex >= 0) then {
        _vehicle getHitIndex _hitIndex
    } else {
        damage _vehicle
    }
}}];
_vehicle setVariable ["TGC_emptyVehicle_damageEH", _damageEH];
