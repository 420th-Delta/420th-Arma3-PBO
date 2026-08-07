/*
Function: TGC_fnc_isProtectedEmptyVehicleDamage

Description:
    Return whether HandleDamage arguments identify a player or an AI from a
    non-civilian side BLUFOR currently considers friendly.

*/
params ["_vehicle", "", "", "_source", "_projectile", "", "_instigator", "", "_directHit"];

if (_this call TGC_fnc_isPlayerDamage) exitWith {true};

private _getSide = {
    params ["_entity"];
    if (isNull _entity) exitWith {sideUnknown};

    private _controller = effectiveCommander _entity;
    private _side = if (!isNull _controller) then {
        side (group _controller)
    } else {
        sideUnknown
    };
    if (_side isEqualTo sideUnknown) then {
        _side = side (group _entity);
    };
    if (_side isEqualTo sideUnknown) then {
        _side = side _entity;
    };
    if (_side isEqualTo sideUnknown) then {
        _side = _entity getVariable ["TGC_vehicle_side", sideUnknown];
    };
    _side
};

private _attacker = [_source, _instigator] select (!isNull _instigator);
if (_attacker isEqualTo _vehicle) then {
    _attacker = objNull;
};

private _attackerSide = [_attacker] call _getSide;
if (
    (_attackerSide in [sideUnknown, sideEnemy]) &&
    {!isNull _source} &&
    {_source isNotEqualTo _vehicle}
) then {
    _attackerSide = [_source] call _getSide;
};
if (
    (_attackerSide isNotEqualTo sideUnknown) &&
    {_attackerSide isNotEqualTo CIVILIAN} &&
    {(_attackerSide isEqualTo WEST) || {(WEST getFriend _attackerSide) >= 0.6}}
) exitWith {true};

// Collision damage can identify the victim as its own source. The contact
// handler records a protected collider for this fallback.
if (
    (_projectile isEqualTo "") &&
    {!_directHit} &&
    {(isNull _source) || {_source isEqualTo _vehicle}}
) exitWith {
    diag_tickTime <= (_vehicle getVariable ["TGC_playerDamageCollisionUntil", -1])
};

false
