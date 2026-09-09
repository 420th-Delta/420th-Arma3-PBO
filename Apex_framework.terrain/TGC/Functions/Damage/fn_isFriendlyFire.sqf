/*
Function: TGC_fnc_isFriendlyFire

Description:
    Check if the given damage should be considered friendly fire.
    Parameters are the same as those passed to the HandleDamage EH.
    https://community.bistudio.com/wiki/Arma_3:_Event_Handlers#HandleDamage

Author:
    thegamecracks

*/
params ["_unit", "", "", "_source", "_projectile", "", "_instigator"];

private _getSide = {
    params ["_entity"];
    if (isNull _entity) exitWith {sideUnknown};

    private _side = side group _entity;
    if (_side isEqualTo sideUnknown) then {
        _side = side _entity;
    };
    if (_side isEqualTo sideUnknown) then {
        _side = _entity getVariable ["TGC_vehicle_side", sideUnknown];
    };
    _side
};

private _sideA = [_unit] call _getSide;

// A remote-controlled AI keeps its own combat side even when Arma reports the
// controlling player's body as the instigator. Prefer that AI (including a
// vehicle crew member) when the mission's remote-control owner marker exists.
private _attacker = _instigator;
private _remoteControlledAttacker = objNull;
private _sourceVehicle = vehicle _source;
private _attackerCandidates = [_source];
if (!isNull _sourceVehicle) then {
    _attackerCandidates append (crew _sourceVehicle);
};
{
    if (
        (!isNull _x) &&
        {isPlayer (_x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}
    ) exitWith {
        _remoteControlledAttacker = _x;
    };
} forEach _attackerCandidates;
if (!isNull _remoteControlledAttacker) then {
    _attacker = _remoteControlledAttacker;
};

private _sideB = [_attacker] call _getSide;

// Explosive and missile damage may report no instigator, or report its
// instigator as the sideEnemy pseudo-side. Resolve either case from the firing
// vehicle or its effective commander. Do not use the victim as its own source,
// which occurs for collision damage.
if (
    (_sideB in [sideUnknown, sideEnemy]) &&
    {!isNull _source} &&
    {_source isNotEqualTo _unit}
) then {
    private _sourceController = effectiveCommander _source;
    _sideB = [_sourceController] call _getSide;
    if (_sideB isEqualTo sideUnknown) then {
        _sideB = [_source] call _getSide;
    };
};

(_sideA isNotEqualTo sideUnknown) && {_sideA isEqualTo _sideB}
