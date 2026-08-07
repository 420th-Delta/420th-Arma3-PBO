/*
Function: TGC_fnc_addFriendlyAIHandlers

Description:
    Attach friendly-AI protection object handlers to a unit. This function is
    called on every machine by TGC_fnc_initFriendlyAIProtection, so the
    handlers are present wherever the unit is local now or later.

Parameters:
    Object unit:
        Infantry or virtual UAV crew to protect when it is friendly AI.

Author:
    thegamecracks

*/
params [["_unit", objNull, [objNull]]];

if (
    (isNull _unit) ||
    {
        !(_unit isKindOf "CAManBase") &&
        {!(_unit isKindOf "B_UAV_AI")} &&
        {!(_unit isKindOf "O_UAV_AI")} &&
        {!(_unit isKindOf "I_UAV_AI")} &&
        {!(_unit isKindOf "C_UAV_AI_F")}
    }
) exitWith {};

private _existingCollisionEH = _unit getVariable ["TGC_friendlyAI_collisionEH", -1];
if !(
    (_existingCollisionEH >= 0) &&
    {(_unit getEventHandlerInfo ["EpeContactStart", _existingCollisionEH]) param [0, false]}
) then {
    private _collisionEH = _unit addEventHandler ["EpeContactStart", {
        params ["_unit", "_collider"];
        if (!local _unit) exitWith {};

        if ([_collider] call TGC_fnc_isPlayerControlled) then {
            _unit setVariable ["TGC_playerDamageCollisionUntil", diag_tickTime + 1];
        };
    }];
    _unit setVariable ["TGC_friendlyAI_collisionEH", _collisionEH];
};

private _existingDamageEH = _unit getVariable ["TGC_friendlyAI_damageEH", -1];
private _existingDamageEHInfo = if (_existingDamageEH >= 0) then {
    _unit getEventHandlerInfo ["HandleDamage", _existingDamageEH]
} else {
    []
};
if (
    (_existingDamageEHInfo param [0, false]) &&
    {_existingDamageEHInfo param [1, false]}
) exitWith {};

// Only the last numeric HandleDamage return is honored. If another handler was
// added after ours, move this protection back to the end of the handler list.
if (_existingDamageEHInfo param [0, false]) then {
    _unit removeEventHandler ["HandleDamage", _existingDamageEH];
};

private _damageEH = _unit addEventHandler ["HandleDamage", {
    call {
        params ["_unit", "", "_damage", "_source", "", "_hitIndex", "_instigator"];

        if !([_unit] call TGC_fnc_isFriendlyAI) exitWith {};

        private _oldDamage = if (_hitIndex >= 0) then {
            _unit getHitIndex _hitIndex
        } else {
            damage _unit
        };

        // Player damage is always rejected, regardless of the player's side.
        if (_this call TGC_fnc_isPlayerDamage) exitWith {_oldDamage};

        // Preserve protection from non-civilian AI friendly fire as well. A side
        // is friendly when BLUFOR's current relationship meets the 0.6 threshold.
        private _attacker = [_source, _instigator] select (!isNull _instigator);
        private _isFriendlyAttacker = false;
        if (!isNull _attacker && {_attacker isNotEqualTo _unit}) then {
            private _attackerSide = side (group _attacker);
            if (_attackerSide isEqualTo sideUnknown) then {
                _attackerSide = side _attacker;
            };
            _isFriendlyAttacker =
                (_attackerSide isNotEqualTo sideUnknown) &&
                {(_attackerSide isNotEqualTo CIVILIAN)} &&
                {(WEST getFriend _attackerSide) >= 0.6};
        };
        if (_isFriendlyAttacker) exitWith {_oldDamage};

        // Recruited AI historically receives reduced non-friendly damage. Keep
        // that behavior in this handler instead of a separate later numeric
        // return that would override the player-damage rejection above.
        if (_unit getVariable ["QS_unit_isRecruited", false]) exitWith {
            _oldDamage + ((_damage - _oldDamage) * 0.333)
        };
    };
}];

_unit setVariable ["TGC_friendlyAI_damageEH", _damageEH];
