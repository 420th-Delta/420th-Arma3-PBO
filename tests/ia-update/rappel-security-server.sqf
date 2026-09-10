if (!isServer) exitWith {};
['rappel.serverDedicated',isDedicated] call IA_fnc_assert;
private _until = diag_tickTime + 45;
waitUntil {uiSleep 0.1; ({isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}} count allPlayers) > 0 || {diag_tickTime >= _until}};
private _client = (allPlayers select {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}}) param [0,objNull];
['rappel.clientConnected',!isNull _client] call IA_fnc_assert;
if (isNull _client) exitWith {call IA_fnc_finish;};

private _safe = createVehicle ['B_Heli_Light_01_F',[14100,16200,30],[],0,'FLY'];
private _unsafe = createVehicle ['B_Heli_Light_01_F',[14200,16200,80],[],0,'FLY'];
{
    _x allowDamage FALSE;
    _x lock FALSE;
    _x setVectorUp [0,0,1];
    _x setVelocity [0,0,0];
    _x enableSimulationGlobal FALSE;
} forEach [_safe,_unsafe];
_safe setPosATL [14100,16200,30];
_unsafe setPosATL [14200,16200,80];
['rappel.fixtureAnchorAvailable',count ([_safe] call AR_Get_Heli_Rappel_Points) isEqualTo 1] call IA_fnc_assert;
_client setVariable ['IA_rappel_helis',[_safe,_unsafe],TRUE];

// Wait for the cargo assignment to reach the authoritative server before the
// client sends the action. This removes a fixture race from normal MP latency.
_until = diag_tickTime + 10;
waitUntil {uiSleep 0.05; (_client getVariable ['IA_rappel_seated',FALSE]) && {_client in _safe} || {diag_tickTime >= _until}};
private _seatObserved = (_client getVariable ['IA_rappel_seated',FALSE]) && {_client in _safe};
private _role = assignedVehicleRole _client;
private _pos = getPosATL _safe;
private _ray = lineIntersectsSurfaces [(_safe modelToWorldWorld [0,0,-1]),(_safe modelToWorldWorld [0,0,-6]),_safe,objNull,TRUE,-1,'GEOM','ROADWAY',TRUE];
private _actionDetails = [
    [_safe] call AR_Is_Supported_Vehicle,
    _client isNotEqualTo currentPilot _safe,
    _pos # 2,
    _ray isEqualTo [],
    vectorMagnitude velocity _safe,
    _role,
    fullCrew _safe,
    owner _safe
];
['rappel.serverObservedCargoSeat',_seatObserved,_actionDetails] call IA_fnc_assert;
['rappel.serverActionPredicate',[_client,_safe] call AR_Rappel_From_Heli_Action_Check,_actionDetails] call IA_fnc_assert;
_client setVariable ['IA_rappel_seatObserved',_seatObserved,TRUE];

_until = diag_tickTime + 45;
waitUntil {uiSleep 0.05; _client getVariable ['IA_rappel_requested',FALSE] || {diag_tickTime >= _until}};
['rappel.clientRequested',_client getVariable ['IA_rappel_requested',FALSE]] call IA_fnc_assert;
private _session = [];
private _key = netId _client;
_until = diag_tickTime + 20;
waitUntil {
    uiSleep 0.05;
    private _sessions = serverNamespace getVariable ['QS_AR_clientSessions',createHashMap];
    _session = _sessions getOrDefault [_key,[]];
    ((count _session) >= 8 && {!isNull (_session # 5)} && {!isNull (_session # 6)} && {_session # 7} &&
        {isObjectHidden (_session # 5)} && {isObjectHidden (_session # 6)} &&
        {(serverNamespace getVariable ['IA_rappel_animationCalls',0]) >= 1}) || {diag_tickTime >= _until}
};
private _sessionComplete = (count _session) >= 8 && {!isNull (_session # 5)} && {!isNull (_session # 6)} && {_session # 7};
['rappel.sessionBound',_sessionComplete && {(_session # 0) isEqualTo _client} &&
    {(_session # 1) isEqualTo (_client getVariable ['QS_AR_serial',-1])} &&
    {(_session # 2) isEqualTo owner _client} && {(_session # 3) isEqualTo _safe}] call IA_fnc_assert;
['rappel.helpersBoundToSender',_sessionComplete && {(owner (_session # 5)) isEqualTo owner _client} &&
    {(owner (_session # 6)) isEqualTo owner _client}] call IA_fnc_assert;
['rappel.helpersGloballyHidden',_sessionComplete && {isObjectHidden (_session # 5)} && {isObjectHidden (_session # 6)}] call IA_fnc_assert;
['rappel.animationRelayLatched',_sessionComplete && {_session # 7}] call IA_fnc_assert;
private _realHelpers = [_session param [5,objNull],_session param [6,objNull]];
private _capturedSerial = _session param [1,-1];
private _anchorBound = _sessionComplete &&
    {(_safe getVariable ['AR_Rappelling_Player_0',objNull]) isEqualTo _client} &&
    {(_safe getVariable ['QS_AR_anchorSerial_0',-1]) isEqualTo _capturedSerial};
['rappel.anchorInitiallyBound',_anchorBound] call IA_fnc_assert;
['rappel.animationInitialRelayOnce',(serverNamespace getVariable ['IA_rappel_animationCalls',0]) isEqualTo 1] call IA_fnc_assert;
_client setVariable ['IA_rappel_sessionObserved',_sessionComplete,TRUE];

_until = diag_tickTime + 15;
waitUntil {uiSleep 0.05; _client getVariable ['IA_rappel_duplicateSent',FALSE] || {diag_tickTime >= _until}};
private _duplicateSent = _client getVariable ['IA_rappel_duplicateSent',FALSE];
uiSleep 0.75;
['rappel.animationDuplicateDoesNotRelay',_duplicateSent &&
    {(serverNamespace getVariable ['IA_rappel_animationCalls',0]) isEqualTo 1}] call IA_fnc_assert;
_client setVariable ['IA_rappel_duplicateObserved',_duplicateSent,TRUE];

_until = diag_tickTime + 45;
waitUntil {uiSleep 0.1; _client getVariable ['IA_rappel_done',FALSE] || {diag_tickTime >= _until}};
['rappel.clientCompleted',_client getVariable ['IA_rappel_done',FALSE]] call IA_fnc_assert;
private _forged = _client getVariable ['IA_rappel_forged',objNull];
private _extra = _client getVariable ['IA_rappel_extra',objNull];
['rappel.forgedHelperNotGloballyHidden',!isNull _forged && {!isObjectHidden _forged}] call IA_fnc_assert;
['rappel.extraHelperNotGloballyHidden',!isNull _extra && {!isObjectHidden _extra}] call IA_fnc_assert;
// The production anchor monitor polls every two seconds. Give that worker and
// the owner's actual object deletions a bounded window before fixture teardown.
_until = diag_tickTime + 6;
waitUntil {
    uiSleep 0.1;
    private _sessions = serverNamespace getVariable ['QS_AR_clientSessions',createHashMap];
    (!(_key in _sessions) && {isNil {_safe getVariable 'AR_Rappelling_Player_0'}} &&
        {isNil {_safe getVariable 'QS_AR_anchorSerial_0'}} &&
        {(_realHelpers findIf {!isNull _x}) < 0}) || {diag_tickTime >= _until}
};
['rappel.sessionRemoved',_sessionComplete &&
    {!(_key in (serverNamespace getVariable ['QS_AR_clientSessions',createHashMap]))}] call IA_fnc_assert;
['rappel.anchorReleased',_anchorBound && {isNil {_safe getVariable 'AR_Rappelling_Player_0'}} &&
    {isNil {_safe getVariable 'QS_AR_anchorSerial_0'}}] call IA_fnc_assert;
['rappel.serverHelperObjectsDeleted',_sessionComplete && {(_realHelpers findIf {!isNull _x}) < 0}] call IA_fnc_assert;
['rappel.animationFinalRelayOnce',_duplicateSent &&
    {(serverNamespace getVariable ['IA_rappel_animationCalls',0]) isEqualTo 1}] call IA_fnc_assert;

{if (!isNull _x) then {deleteVehicle _x;};} forEach [_forged,_extra,_safe,_unsafe];
call IA_fnc_finish;
