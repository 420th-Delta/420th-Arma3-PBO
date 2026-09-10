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
/* Legacy Code as of 9.9.2026 */
//|params [["_unit", objNull, [objNull]]];
// Updated Code
params [["_unit", objNull, [objNull]], ["_speechOnly", false, [false]]];
// End Updated Code

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
// Added Code

// BLUFOR_SPEECH_BEGIN
// The existing global creation/JIP hook calls this on every machine because
// setSpeaker has a local effect. RADIOPROTOCOL also stops automatic text
// reports; movement, targeting and orders remain enabled.
private _silent = !isPlayer _unit && {_unit isKindOf "CAManBase"} && {side (group _unit) isEqualTo WEST};
private _savedSpeaker = _unit getVariable ["TGC_bluforSpeech_speaker", []];
if (_silent) then {
    if (_savedSpeaker isEqualTo [] || {(_savedSpeaker # 0) isNotEqualTo _unit}) then {
        _unit setVariable ["TGC_bluforSpeech_speaker", [_unit, speaker _unit]];
    };
    _unit setSpeaker "NoVoice";
    _unit disableConversation true;
    if (local _unit) then {
        if (isNil {_unit getVariable "TGC_bluforSpeech_radio"}) then {
            _unit setVariable ["TGC_bluforSpeech_radio", _unit checkAIFeature "RADIOPROTOCOL"];
        };
        _unit enableAIFeature ["RADIOPROTOCOL", false];
    };
} else {
    // If an AI becomes a player, restore only the speaker/radio state we
    // changed. Player VOIP and scripted Crossroads announcements are separate.
    if (_savedSpeaker isNotEqualTo []) then {
        if (speaker _unit isEqualTo "NoVoice") then {_unit setSpeaker (_savedSpeaker # 1);};
        _unit setVariable ["TGC_bluforSpeech_speaker", nil];
    };
    if (local _unit && {!isNil {_unit getVariable "TGC_bluforSpeech_radio"}}) then {
        _unit enableAIFeature ["RADIOPROTOCOL", _unit getVariable "TGC_bluforSpeech_radio"];
        _unit setVariable ["TGC_bluforSpeech_radio", nil];
    };
};
// Locality transfers reapply owner-only AI settings without moving the
// damage handler or installing another mission loop.
private _speechEH = _unit getVariable ["TGC_bluforSpeech_localEH", -1];
if !(_speechEH >= 0 && {(_unit getEventHandlerInfo ["Local", _speechEH]) param [0, false]}) then {
    _speechEH = _unit addEventHandler ["Local", {
        params ["_unit"];
        [_unit, true] call TGC_fnc_addFriendlyAIHandlers;
    }];
    _unit setVariable ["TGC_bluforSpeech_localEH", _speechEH];
};
if (_speechOnly) exitWith {};
// BLUFOR_SPEECH_END
// End Updated Code

private _existingCollisionEH = _unit getVariable ["TGC_friendlyAI_collisionEH", -1];
if !(
    (_existingCollisionEH >= 0) &&
    {(_unit getEventHandlerInfo ["EpeContactStart", _existingCollisionEH]) param [0, false]}
) then {
    private _collisionEH = _unit addEventHandler ["EpeContactStart", {
        params ["_unit", "_collider"];
        if (!local _unit) exitWith {};
        private _now = diag_tickTime;
        if (_now < (_unit getVariable ["TGC_collisionCheckAfter", -1])) exitWith {};
        _unit setVariable ["TGC_collisionCheckAfter", _now + 0.05];

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
