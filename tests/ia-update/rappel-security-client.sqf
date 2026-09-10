if (!hasInterface) exitWith {};
waitUntil {uiSleep 0.1; !isNull player && {isPlayer player} && {!isNull findDisplay 46}};
private _until = diag_tickTime + 45;
private _helis = [];
waitUntil {uiSleep 0.1; _helis = player getVariable ['IA_rappel_helis',[]]; (count _helis) isEqualTo 2 || {diag_tickTime >= _until}};
['rappel.helisReceived',(count _helis) isEqualTo 2] call IA_fnc_assert;
if ((count _helis) isNotEqualTo 2) exitWith {player setVariable ['IA_rappel_done',TRUE,TRUE]; call IA_fnc_finish;};
_helis params ['_safe','_unsafe'];

// No server-issued serial/session exists yet. A client-owned helper must not
// acquire the global hide/collision privilege merely by publishing variables.
private _forged = createVehicle ['Land_Can_V2_F',[14105,16200,0],[],0,'CAN_COLLIDE'];
_forged hideObject FALSE;
player setVariable ['IA_rappel_forged',_forged,TRUE];
player setVariable ['AR_Is_Rappelling',TRUE,TRUE];
player setVariable ['AR_Rappelling_Vehicle',_safe,TRUE];
player setVariable ['QS_AR_serial',700001,TRUE];
[75,[_forged,player,700001,_safe],'AR_Hide_Object_Global',TRUE] remoteExecCall ['QS_fnc_remoteExec',2,FALSE];
uiSleep 0.75;
['rappel.forgedPublishedStateRejected',!isObjectHidden _forged] call IA_fnc_assert;
player setVariable ['AR_Is_Rappelling',nil,TRUE];
player setVariable ['AR_Rappelling_Vehicle',nil,TRUE];
player setVariable ['QS_AR_serial',nil,TRUE];

player moveInCargo _safe;
_until = diag_tickTime + 5;
waitUntil {uiSleep 0.05; (objectParent player) isEqualTo _safe || {diag_tickTime >= _until}};
['rappel.safeCargoSeat',(objectParent player) isEqualTo _safe] call IA_fnc_assert;
['rappel.safeActionPredicate',[player,_safe] call AR_Rappel_From_Heli_Action_Check] call IA_fnc_assert;
player setVariable ['IA_rappel_seated',TRUE,TRUE];
_until = diag_tickTime + 10;
waitUntil {uiSleep 0.05; player getVariable ['IA_rappel_seatObserved',FALSE] || {diag_tickTime >= _until}};
['rappel.serverObservedCargoSeat',player getVariable ['IA_rappel_seatObserved',FALSE]] call IA_fnc_assert;
[player,_safe] call AR_Rappel_From_Heli;
player setVariable ['IA_rappel_requested',TRUE,TRUE];
_until = diag_tickTime + 10;
waitUntil {uiSleep 0.05; (player getVariable ['AR_Is_Rappelling',FALSE]) &&
    {(player getVariable ['QS_AR_serial',-1]) > 0} || {diag_tickTime >= _until}};
private _serial = player getVariable ['QS_AR_serial',-1];
['rappel.serverIssuedSerial',_serial > 0 && {_serial isNotEqualTo 700001}] call IA_fnc_assert;
_until = diag_tickTime + 3;
waitUntil {uiSleep 0.05; isNull (objectParent player) || {diag_tickTime >= _until}};
['rappel.actualDismount',isNull (objectParent player)] call IA_fnc_assert;

_until = diag_tickTime + 10;
waitUntil {uiSleep 0.05; player getVariable ['IA_rappel_sessionObserved',FALSE] || {diag_tickTime >= _until}};
['rappel.serverObservedSession',player getVariable ['IA_rappel_sessionObserved',FALSE]] call IA_fnc_assert;
// Capture the actual objects while they exist; a missing record after descent
// must not turn an uncaptured or leaked helper into a passing cleanup check.
private _helperRecord = player getVariable ['QS_AR_helpers',[]];
private _helpers = +(_helperRecord param [1,[],[[]]]);
private _helpersCaptured = (count _helperRecord) isEqualTo 2 &&
    {(_helperRecord # 0) isEqualTo _serial} && {(count _helpers) isEqualTo 3} &&
    {(_helpers findIf {isNull _x}) < 0} && {(_helpers # 2) in (ropes (_helpers # 1))};
['rappel.localHelpersCaptured',_helpersCaptured] call IA_fnc_assert;
private _extra = createVehicle ['Land_Can_V2_F',[14107,16200,0],[],0,'CAN_COLLIDE'];
_extra hideObject FALSE;
player setVariable ['IA_rappel_extra',_extra,TRUE];
[75,[_extra,player,_serial,_unsafe],'AR_Hide_Object_Global',TRUE] remoteExecCall ['QS_fnc_remoteExec',2,FALSE];
[75,[player],'AR_Enable_Rappelling_Animation',TRUE] remoteExecCall ['QS_fnc_remoteExec',2,FALSE];
player setVariable ['IA_rappel_duplicateSent',TRUE,TRUE];
uiSleep 0.75;
['rappel.secondHelperRejected',!isObjectHidden _extra] call IA_fnc_assert;
_until = diag_tickTime + 10;
waitUntil {uiSleep 0.05; player getVariable ['IA_rappel_duplicateObserved',FALSE] || {diag_tickTime >= _until}};
['rappel.serverObservedDuplicate',player getVariable ['IA_rappel_duplicateObserved',FALSE]] call IA_fnc_assert;

// The graphical fixture drives the same state as the normal MoveBack key.
player setVariable ['AR_DECEND_PRESSED',TRUE];
_until = diag_tickTime + 30;
waitUntil {uiSleep 0.1; !(player getVariable ['AR_Is_Rappelling',FALSE]) || {diag_tickTime >= _until}};
['rappel.descentCompletes',!(player getVariable ['AR_Is_Rappelling',FALSE])] call IA_fnc_assert;
_until = diag_tickTime + 4;
waitUntil {uiSleep 0.1; isDamageAllowed player || {diag_tickTime >= _until}};
['rappel.playerDamageRestored',isDamageAllowed player] call IA_fnc_assert;
_until = diag_tickTime + 6;
waitUntil {uiSleep 0.1; (isNil {player getVariable 'QS_AR_helpers'} &&
    {(_helpers findIf {!isNull _x}) < 0}) || {diag_tickTime >= _until}};
['rappel.localHelperRecordCleared',_helpersCaptured && {isNil {player getVariable 'QS_AR_helpers'}}] call IA_fnc_assert;
['rappel.localHelperObjectsDeleted',_helpersCaptured && {isNull (_helpers # 0)} && {isNull (_helpers # 1)}] call IA_fnc_assert;
['rappel.localRopeDeleted',_helpersCaptured && {isNull (_helpers # 2)}] call IA_fnc_assert;

player moveInCargo _unsafe;
_until = diag_tickTime + 5;
waitUntil {uiSleep 0.05; (objectParent player) isEqualTo _unsafe || {diag_tickTime >= _until}};
['rappel.unsafeCargoSeat',(objectParent player) isEqualTo _unsafe] call IA_fnc_assert;
['rappel.unsafeActionPredicateRejected',!([player,_unsafe] call AR_Rappel_From_Heli_Action_Check)] call IA_fnc_assert;
private _before = player getVariable ['QS_AR_serial',-1];
[75,[player,_unsafe],'AR_Rappel_From_Heli',TRUE] remoteExecCall ['QS_fnc_remoteExec',2,FALSE];
uiSleep 0.75;
['rappel.directUnsafeRequestRejected',(objectParent player) isEqualTo _unsafe &&
    {!(player getVariable ['AR_Is_Rappelling',FALSE])} && {(player getVariable ['QS_AR_serial',-1]) isEqualTo _before}] call IA_fnc_assert;

moveOut player;
player setVariable ['IA_rappel_done',TRUE,TRUE];
call IA_fnc_finish;
