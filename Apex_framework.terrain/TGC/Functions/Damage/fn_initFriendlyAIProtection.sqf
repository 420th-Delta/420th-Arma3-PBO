/*
Function: TGC_fnc_initFriendlyAIProtection

Description:
    Install friendly-AI protection globally. CfgFunctions runs this post-init
    on every server, client, headless client, and joining client.

Author:
    thegamecracks

*/
if (is3DEN) exitWith {};
if (localNamespace getVariable ["TGC_friendlyAIProtection_initialized", false]) exitWith {};
localNamespace setVariable ["TGC_friendlyAIProtection_initialized", true];

private _isSupportedUnit = {
    params ["_entity"];
    (_entity isKindOf "CAManBase") ||
    {(_entity isKindOf "B_UAV_AI")} ||
    {(_entity isKindOf "O_UAV_AI")} ||
    {(_entity isKindOf "I_UAV_AI")} ||
    {(_entity isKindOf "C_UAV_AI_F")}
};

// Install immediately so a newly created entity never has an unprotected frame.
// Respawn copies persistent handlers and the old entity namespace afterward, so
// remember these IDs and discard the temporary copies if that happens.
private _createdEH = addMissionEventHandler ["EntityCreated", {
    params ["_entity"];

    if !(
        (_entity isKindOf "CAManBase") ||
        {(_entity isKindOf "B_UAV_AI")} ||
        {(_entity isKindOf "O_UAV_AI")} ||
        {(_entity isKindOf "I_UAV_AI")} ||
        {(_entity isKindOf "C_UAV_AI_F")}
    ) exitWith {};

    [_entity] call TGC_fnc_addFriendlyAIHandlers;
    [
        _entity,
        _entity getVariable ["TGC_friendlyAI_collisionEH", -1],
/* Legacy Code as of 9.9.2026 */
//|        _entity getVariable ["TGC_friendlyAI_damageEH", -1]
// Updated Code
        _entity getVariable ["TGC_friendlyAI_damageEH", -1],
        _entity getVariable ["TGC_bluforSpeech_localEH", -1]
// End Updated Code
    ] spawn {
/* Legacy Code as of 9.9.2026 */
//|        params ["_entity", "_createdCollisionEH", "_createdDamageEH"];
// Updated Code
        params ["_entity", "_createdCollisionEH", "_createdDamageEH", "_createdSpeechEH"];
// End Updated Code
        uiSleep 0;
        if (isNull _entity) exitWith {};

        private _trackedCollisionEH = _entity getVariable ["TGC_friendlyAI_collisionEH", -1];
        if (
            (_createdCollisionEH >= 0) &&
            {_createdCollisionEH isNotEqualTo _trackedCollisionEH} &&
            {(_entity getEventHandlerInfo ["EpeContactStart", _createdCollisionEH]) param [0, false]}
        ) then {
            _entity removeEventHandler ["EpeContactStart", _createdCollisionEH];
        };

        private _trackedDamageEH = _entity getVariable ["TGC_friendlyAI_damageEH", -1];
        if (
            (_createdDamageEH >= 0) &&
            {_createdDamageEH isNotEqualTo _trackedDamageEH} &&
            {(_entity getEventHandlerInfo ["HandleDamage", _createdDamageEH]) param [0, false]}
        ) then {
            _entity removeEventHandler ["HandleDamage", _createdDamageEH];
// Added Code
        };

        // Match the existing respawn cleanup for the new locality handler.
        // EntityCreated can run before Arma copies the old body's namespace.
        private _trackedSpeechEH = _entity getVariable ["TGC_bluforSpeech_localEH", -1];
        if (
            (_createdSpeechEH >= 0) &&
            {_createdSpeechEH isNotEqualTo _trackedSpeechEH} &&
            {(_entity getEventHandlerInfo ["Local", _createdSpeechEH]) param [0, false]}
        ) then {
            _entity removeEventHandler ["Local", _createdSpeechEH];
// End Updated Code
        };

        [_entity] call TGC_fnc_addFriendlyAIHandlers;
    };
}];
localNamespace setVariable ["TGC_friendlyAIProtection_createdEH", _createdEH];

private _respawnedEH = addMissionEventHandler ["EntityRespawned", {
    params ["_newEntity"];
    // Respawn copies the entity namespace and persistent object handlers.
    // Validate the copied IDs and add only anything that is missing.
    [_newEntity] call TGC_fnc_addFriendlyAIHandlers;
}];
localNamespace setVariable ["TGC_friendlyAIProtection_respawnedEH", _respawnedEH];

// Cover editor units and network entities that existed before post-init/JIP.
private _units = allUnits + (agents apply {agent _x});
{
    _units append (crew _x);
} forEach allUnitsUAV;

{
    if (!isNull _x && {[_x] call _isSupportedUnit}) then {
        [_x] call TGC_fnc_addFriendlyAIHandlers;
    };
} forEach (_units arrayIntersect _units);
