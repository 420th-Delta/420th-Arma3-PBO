/*
Function: TGC_fnc_isFriendlyFire

Description:
    Check if the given damage should be considered friendly fire.
    Parameters are the same as those passed to the HandleDamage EH.
// Added Code
    ['ATTACKER', source, instigator, victim] returns the firing unit for other damage
    handlers. This shares Zeus attribution without adding another function file.
    The optional victim prevents collision/self-source events inventing a shooter.
// End Updated Code
    https://community.bistudio.com/wiki/Arma_3:_Event_Handlers#HandleDamage

Author:
    thegamecracks

*/
// Added Code
// ZEUS_ATTACKER_BEGIN
if ((_this param [0, objNull]) isEqualTo 'ATTACKER') exitWith {
    _this params ['', ['_source', objNull], ['_instigator', objNull], ['_victim', objNull]];
    // A victim reported as its own source is not evidence of who fired.
    // Keep the supplied instigator, including objNull for unattributed damage.
    if (!isNull _victim && {_source isEqualTo _victim}) exitWith {_instigator};
    // An identified gunner in the firing vehicle takes precedence over any
    // remote-controlled passenger. Infantry source is the physical shooter.
    if (!isNull _instigator && {!isNull _source} &&
        {(vehicle _instigator) isEqualTo (vehicle _source)}) exitWith {_instigator};
    if (!isNull _source && {_source isKindOf 'CAManBase'}) exitWith {_source};

    private _attacker = _instigator;
    if (isPlayer _instigator && {!isNull _source}) then {
        private _controlled = remoteControlled _instigator;
        if (!isNull _controlled && {(vehicle _controlled) isEqualTo (vehicle _source)}) then {
            _attacker = _controlled;
        } else {
            // The replicated BIS marker also covers the mission's custom remote
            // control. Require this instigator AND this firing vehicle to match.
            private _crew = crew (vehicle _source);
            private _index = _crew findIf {
                (remoteControlled _x) isEqualTo _instigator ||
                {(_x getVariable ['bis_fnc_moduleRemoteControl_owner', objNull]) isEqualTo _instigator}
            };
            if (_index >= 0) then {_attacker = _crew # _index;};
        };
    };
    if (isNull _attacker && {!isNull _source}) then {
        _attacker = effectiveCommander (vehicle _source);
        if (isNull _attacker) then {_attacker = _source;};
    };
    _attacker
};
// ZEUS_ATTACKER_END
// End Updated Code
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

/* Legacy Code as of 9.9.2026 */
//|// A remote-controlled AI keeps its own combat side even when Arma reports the
//|// controlling player's body as the instigator. Prefer that AI (including a
//|// vehicle crew member) when the mission's remote-control owner marker exists.
//|private _attacker = _instigator;
//|private _remoteControlledAttacker = objNull;
//|private _sourceVehicle = vehicle _source;
//|private _attackerCandidates = [_source];
//|if (!isNull _sourceVehicle) then {
//|    _attackerCandidates append (crew _sourceVehicle);
//|};
//|{
//|    if (
//|        (!isNull _x) &&
//|        {isPlayer (_x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}
//|    ) exitWith {
//|        _remoteControlledAttacker = _x;
//|    };
//|} forEach _attackerCandidates;
//|if (!isNull _remoteControlledAttacker) then {
//|    _attacker = _remoteControlledAttacker;
//|};
// Updated Code
private _attacker = ['ATTACKER', _source, _instigator, _unit] call TGC_fnc_isFriendlyFire;
// End Updated Code

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
