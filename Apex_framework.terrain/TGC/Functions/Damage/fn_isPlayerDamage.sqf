/*
Function: TGC_fnc_isPlayerDamage

Description:
    Return whether HandleDamage arguments identify a player as the cause.

*/
params ["_unit", "", "", "_source", "_projectile", "", "_instigator", "", "_directHit"];

if ([_instigator] call TGC_fnc_isPlayerControlled) exitWith {true};
if (
    (!isNull _source) &&
    {_source isNotEqualTo _unit} &&
    {[_source] call TGC_fnc_isPlayerControlled}
) exitWith {true};

// Arma can report the victim (or objNull) as the source of collision damage.
// EpeContactStart records a same-locality player collision for this fallback.
if (
    (_projectile isEqualTo "") &&
    {!_directHit} &&
    {(isNull _source) || {_source isEqualTo _unit}}
) exitWith {
    diag_tickTime <= (_unit getVariable ["TGC_playerDamageCollisionUntil", -1])
};

false
