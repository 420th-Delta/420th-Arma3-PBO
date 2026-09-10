// Called from support-client after its mortar cleanup; same real player/UID.
private _sequence = 1000;
private _art = {
    params [['_mode','ART_SNAPSHOT']];
    _sequence = _sequence + 1;
    [_mode,player,_sequence] remoteExecCall ['QS_fnc_iaSupportTest',2,FALSE];
    private _until = diag_tickTime + 5;
    waitUntil {uiSleep 0.05; ((player getVariable ['IA_support_artillerySnapshot',[-1]]) # 0) isEqualTo _sequence || {diag_tickTime >= _until}};
    private _result = player getVariable ['IA_support_artillerySnapshot',[-1,-1,[],[],[], '',[],[]]];
    ['support_artillery_snapshot_reply',(_result # 0) isEqualTo _sequence,[_mode]] call IA_fnc_assert;
    _until = diag_tickTime + 2;
    waitUntil {uiSleep 0.05; (player getVariable ['QS_artillerySupport_status',[]]) isEqualTo (_result # 6) || {diag_tickTime >= _until}};
    ['support_artillery_status_delivered',(player getVariable ['QS_artillerySupport_status',[]]) isEqualTo (_result # 6),[_mode]] call IA_fnc_assert;
    _result
};
private _snapshot = ['ART_SETUP_FO'] call _art;
private _epoch = _snapshot # 1;
private _stock = +(_snapshot # 2);
private _target = player getPos [650,0];
uiSleep 2.2;
private _menu = (localNamespace getVariable ['QS_artillerySupport_menuOwner',[objNull,-1,'']]) # 1;
['support_forward_observer_menu_valid',_menu >= 0] call IA_fnc_assert;
['START','DEFENSE','client-injection'] remoteExecCall ['QS_fnc_artillerySupport',2,FALSE];
for '_i' from 1 to 6 do {['REQUEST',player,_epoch,_target,0,2,0] remoteExec ['QS_fnc_artillerySupport',2,FALSE];};
uiSleep 0.3;
_snapshot = [] call _art;
['support_fo_request_reserves_stock',(_snapshot # 1) isEqualTo _epoch && {count (_snapshot # 3) isEqualTo 1} &&
    {((_snapshot # 2) # 0) isEqualTo ((_stock # 0) - 2)}] call IA_fnc_assert;
_snapshot = ['ART_REPEAT'] call _art;
['support_same_activity_does_not_refill',(_snapshot # 1) isEqualTo _epoch && {((_snapshot # 2) # 0) isEqualTo ((_stock # 0) - 2)}] call IA_fnc_assert;
for '_i' from 1 to 6 do {['CANCEL',player] remoteExec ['QS_fnc_artillerySupport',2,FALSE];};
uiSleep 0.3;
_snapshot = [] call _art;
['support_cancel_refunds_pending_rounds',(_snapshot # 3) isEqualTo [] && {(_snapshot # 2) isEqualTo _stock}] call IA_fnc_assert;
['CANCEL',player] remoteExecCall ['QS_fnc_artillerySupport',2,FALSE];
uiSleep 0.2;
['support_repeat_cancel_cannot_mint_stock',(([] call _art) # 2) isEqualTo _stock] call IA_fnc_assert;
uiSleep 2.2;
['REQUEST',player,_epoch - 1,_target,0,2,0] remoteExecCall ['QS_fnc_artillerySupport',2,FALSE];
uiSleep 0.2;
_snapshot = [] call _art;
['support_stale_epoch_cannot_spend',(_snapshot # 3) isEqualTo [] && {(_snapshot # 2) isEqualTo _stock}] call IA_fnc_assert;
uiSleep 2.2;
['REQUEST',player,_epoch,_target,0,2,0] remoteExecCall ['QS_fnc_artillerySupport',2,FALSE];
uiSleep 0.2;
_snapshot = ['ART_NEXT'] call _art;
['support_next_activity_replaces_pending_worker',(_snapshot # 1) isEqualTo (_epoch + 1) &&
    {(_snapshot # 3) isEqualTo []} && {(_snapshot # 2) isEqualTo _stock}] call IA_fnc_assert;
_snapshot = ['ART_STALE_END'] call _art;
['support_old_activity_end_cannot_end_current',(_snapshot # 5) isEqualTo 'PRIMARY'] call IA_fnc_assert;
_snapshot = ['ART_END'] call _art;
['support_activity_end_clears_availability',(_snapshot # 5) isEqualTo '' && {(_snapshot # 6) isEqualTo []}] call IA_fnc_assert;

_snapshot = ['ART_SETUP_JTAC'] call _art;
_epoch = _snapshot # 1;
['support_jtac_fixed_two_slot_issuance',(_snapshot # 7) isEqualTo [6,4,2] && {((_snapshot # 6) param [2,[]]) isEqualTo [3,2,1]}] call IA_fnc_assert;
uiSleep 2.2;
['REQUEST',player,_epoch,_target,5,8,0] remoteExec ['QS_fnc_artillerySupport',2,FALSE];
uiSleep 0.3;
_snapshot = [] call _art;
['support_jtac_custom_volley_clamps_to_one',(_snapshot # 4) isEqualTo [1,0,0] &&
    {count (_snapshot # 3) isEqualTo 1} && {(((_snapshot # 3) # 0) # 1) isEqualTo 1}] call IA_fnc_assert;
// Let the actual production worker release one remote, unoccupied test strike.
// This verifies UID usage after expenditure, not just a synthetic debit array.
uiSleep 28;
_snapshot = [] call _art;
['support_jtac_worker_completed_one_debit',(_snapshot # 3) isEqualTo [] && {(_snapshot # 4) isEqualTo [1,0,0]}] call IA_fnc_assert;
// The original target was safe at admission. Moving a real player onto it
// exercises the worker's release-time rejection and its own refund path.
private _originalPosition = getPosATL player;
['REQUEST',player,_epoch,_target,5,1,0] remoteExec ['QS_fnc_artillerySupport',2,FALSE];
uiSleep 0.3;
_snapshot = [] call _art;
['support_rejected_release_initially_reserved',(_snapshot # 4) isEqualTo [2,0,0] &&
    {count (_snapshot # 3) isEqualTo 1}] call IA_fnc_assert;
player setPosATL _target;
uiSleep 28;
_snapshot = [] call _art;
['support_rejected_release_refunds_uid',(_snapshot # 3) isEqualTo [] && {(_snapshot # 4) isEqualTo [1,0,0]}] call IA_fnc_assert;
player setPosATL _originalPosition;
_snapshot = [] call _art;
['support_watchdog_after_release_refund_cannot_mint',(_snapshot # 4) isEqualTo [1,0,0] &&
    {((_snapshot # 6) param [2,[]]) isEqualTo [2,2,1]}] call IA_fnc_assert;
['ART_LEAVE'] call _art;
uiSleep 2.2;
_snapshot = ['ART_REJOIN'] call _art;
['support_jtac_same_uid_rejoin_keeps_usage',(_snapshot # 4) isEqualTo [1,0,0] && {((_snapshot # 6) param [2,[]]) isEqualTo [2,2,1]}] call IA_fnc_assert;
_snapshot = ['ART_DUPLICATE_ROLE'] call _art;
['support_jtac_duplicate_uid_slot_does_not_grant',(_snapshot # 7) isEqualTo [6,4,2] &&
    {(_snapshot # 4) isEqualTo [1,0,0]} && {((_snapshot # 6) param [2,[]]) isEqualTo [2,2,1]}] call IA_fnc_assert;
['ART_FINISH'] call _art;
