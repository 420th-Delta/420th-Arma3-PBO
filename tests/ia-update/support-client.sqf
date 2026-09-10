if (!hasInterface) exitWith {};
waitUntil {uiSleep 0.1; !isNull player && {isPlayer player} && {!isNull findDisplay 46}};
private _sequence = 0;
private _snapshot = {
    params [['_mode','SNAPSHOT']];
    _sequence = _sequence + 1;
    [_mode,player,_sequence] remoteExecCall ['QS_fnc_iaSupportTest',2,FALSE];
    private _until = diag_tickTime + 5;
    waitUntil {uiSleep 0.05; ((player getVariable ['IA_support_snapshot',[-1]]) # 0) isEqualTo _sequence || {diag_tickTime >= _until}};
    private _result = player getVariable ['IA_support_snapshot',[-1,[],'',objNull]];
    ['support_snapshot_reply',(_result # 0) isEqualTo _sequence,[_mode]] call IA_fnc_assert;
    _result
};
private _waitEntries = {
    params ['_condition',['_timeout',8]];
    private _until = diag_tickTime + _timeout;
    private _result = [];
    private _ok = FALSE;
    waitUntil {
        uiSleep 0.2;
        _result = ['TICK'] call _snapshot;
        _ok = [_result # 1] call _condition;
        _ok || {diag_tickTime >= _until}
    };
    [_ok,_result]
};
private _freshTube = {
    removeBackpack player;
    player addBackpack 'B_Mortar_01_weapon_F';
    private _until = diag_tickTime + 5;
    waitUntil {uiSleep 0.1; private _state = [] call _snapshot;
        ((_state # 3) isEqualTo backpackContainer player && {!isNull (_state # 3)}) || {diag_tickTime >= _until}};
};
private _reset = {
    ['RESET',player] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
    private _result = [{params ['_entries']; _entries isEqualTo []}] call _waitEntries;
    ['support_reset_clears_section',_result # 0] call IA_fnc_assert;
};
// Real CfgFunctions postInit should already have started one observer.
['support_postinit_starts_observer',localNamespace getVariable ['QS_artillerySupport_clientStarted',FALSE]] call IA_fnc_assert;
private _lifecycle = localNamespace getVariable ['QS_artillerySupport_clientLifecycle',[]];
['postInit',FALSE] call QS_fnc_artillerySupport;
['postInit',TRUE] spawn QS_fnc_artillerySupport;
['INIT'] spawn QS_fnc_artillerySupport;
uiSleep 0.2;
['support_postinit_idempotent',count _lifecycle isEqualTo 3 &&
    {_lifecycle isEqualTo (localNamespace getVariable ['QS_artillerySupport_clientLifecycle',[]])} &&
    {!scriptDone (_lifecycle # 2)}] call IA_fnc_assert;

['SETUP'] call _snapshot;
uiSleep 2.2;
['support_observer_adds_mortar_menus',count ((localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]]) # 1) isEqualTo 3] call IA_fnc_assert;
['support_mortar_menu_ids_valid',(((localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]]) # 1) findIf {!(_x isEqualType 0) || {_x < 0}}) < 0] call IA_fnc_assert;
player setUnconscious TRUE;
uiSleep 2.2;
['support_incapacitation_removes_mortar_menus',((localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]]) # 1) isEqualTo []] call IA_fnc_assert;
player setUnconscious FALSE;
uiSleep 2.2;
['support_recovery_restores_mortar_menus',count ((localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]]) # 1) isEqualTo 3] call IA_fnc_assert;
private _controlGroup = createGroup [WEST,TRUE];
private _controlUnit = _controlGroup createUnit ['B_Soldier_F',player getPos [10,0],[],0,'NONE'];
_controlUnit setVariable ['bis_fnc_moduleRemoteControl_owner',player,TRUE];
player remoteControl _controlUnit;
uiSleep 2.2;
['support_remote_control_removes_mortar_menus',isRemoteControlling player &&
    {((localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]]) # 1) isEqualTo []}] call IA_fnc_assert;
objNull remoteControl _controlUnit;
_controlUnit setVariable ['bis_fnc_moduleRemoteControl_owner',nil,TRUE];
deleteVehicle _controlUnit;
deleteGroup _controlGroup;
uiSleep 2.2;
['support_control_exit_restores_mortar_menus',!isRemoteControlling player &&
    {count ((localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]]) # 1) isEqualTo 3}] call IA_fnc_assert;
// Recovery leaves the engine player prone. Mortar construction requires the
// standing/crouched posture a real user would select before opening the menu.
player switchMove 'AmovPercMstpSnonWnonDnon';
uiSleep 0.5;
private _admissionState = [] call _snapshot;
['support_actor_ready_for_construction',stance player in ['STAND','CROUCH'] &&
    {(lifeState player) isNotEqualTo 'INCAPACITATED'},_admissionState # 4] call IA_fnc_assert;
localNamespace setVariable ['IA_support_holdPlacement',TRUE];
// Exercise the authenticated production DEBIT receiver with a delayed packet
// after a backpack swap, independently of the REQUEST transport under test.
call _freshTube;
private _capturedTube = (['CAPTURE_TUBE'] call _snapshot) # 5;
['DEBIT_CAPTURED_TUBE'] call _snapshot;
uiSleep 0.5;
private _probeSnapshot = [] call _snapshot;
['support_debit_receiver_consumes_worn_container',isNull _capturedTube && {backpack player isEqualTo ''} &&
    {(_probeSnapshot # 2) isEqualTo ''},[isNull _capturedTube,backpack player,_probeSnapshot # 2]] call IA_fnc_assert;
call _freshTube;
_capturedTube = (['CAPTURE_TUBE'] call _snapshot) # 5;
private _oldHolders = nearestObjects [player,['GroundWeaponHolder','WeaponHolderSimulated'],20];
player addBackpack 'B_AssaultPack_blk';
player addItemToBackpack 'FirstAidKit';
uiSleep 0.5;
private _newHolders = (nearestObjects [player,['GroundWeaponHolder','WeaponHolderSimulated'],20]) - _oldHolders;
private _droppedTubes = [];
{_droppedTubes append (everyBackpack _x);} forEach _newHolders;
['support_drop_preserves_container_identity',_capturedTube in _droppedTubes] call IA_fnc_assert;
['DEBIT_CAPTURED_TUBE'] call _snapshot;
uiSleep 0.5;
_droppedTubes = [];
{_droppedTubes append (everyBackpack _x);} forEach _newHolders;
['support_delayed_debit_preserves_replacement_and_original',!isNull _capturedTube && {backpack player isEqualTo 'B_AssaultPack_blk'} &&
    {'FirstAidKit' in backpackItems player} && {_capturedTube in _droppedTubes},
    [isNull _capturedTube,backpack player,backpackItems player,_droppedTubes apply {typeOf _x}]] call IA_fnc_assert;
{deleteVehicle _x;} forEach _newHolders;
call _freshTube;
// Scheduled remoteExec deliberately exercises the previously unguarded path.
for '_i' from 1 to 6 do {['REQUEST',player,'TUBE',[]] remoteExec ['QS_fnc_mortarSupport',2,FALSE];};
private _result = [{params ['_entries']; count _entries isEqualTo 1 && {(_entries # 0) # 7}}] call _waitEntries;
['support_concurrent_requests_one_reservation',_result # 0,(_result # 1) param [4,[]]] call IA_fnc_assert;
private _entries = ((_result # 1) # 1);
if (_entries isEqualTo []) exitWith {player setVariable ['IA_support_done',TRUE,TRUE]; call IA_fnc_finish;};
private _entry = _entries # 0;
['support_pending_mortar_empty',(_entry # 2) && {(_entry # 6) isEqualTo 0}] call IA_fnc_assert;
['support_handoff_has_player_ownership',(_entry # 8) isEqualTo clientOwner,
    [_entry # 7,_entry # 8,_entry # 9,clientOwner]] call IA_fnc_assert;
['ACK',player,_entry # 0,(_entry # 1) + 99,TRUE] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
uiSleep 0.2;
private _state = [] call _snapshot;
['support_wrong_nonce_preserves_tube',(_state # 2) isEqualTo 'B_Mortar_01_weapon_F' && {!(((_state # 1) # 0) # 4)}] call IA_fnc_assert;
// Forged TRUE does not run the normal client handoff or any inventory removal.
['ACK',player,_entry # 0,_entry # 1,TRUE] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
_result = [{params ['_entries']; count _entries isEqualTo 1 && {!((_entries # 0) # 2)} && {((_entries # 0) # 6) isEqualTo 8}}] call _waitEntries;
['support_forged_ack_still_pays_tube',_result # 0 && {backpack player isEqualTo ''} && {((_result # 1) # 2) isEqualTo ''}] call IA_fnc_assert;
['ACK',player,_entry # 0,_entry # 1,TRUE] remoteExec ['QS_fnc_mortarSupport',2,FALSE];
['REQUEST',player,'TUBE',[]] remoteExec ['QS_fnc_mortarSupport',2,FALSE];
uiSleep 0.5;
_state = ['TICK'] call _snapshot;
['support_replay_no_stock_or_second_mortar',count (_state # 1) isEqualTo 1 && {(((_state # 1) # 0) # 6) isEqualTo 8}] call IA_fnc_assert;
call _reset;
['ACK',player,_entry # 0,_entry # 1,TRUE] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
uiSleep 0.2;
['support_late_ack_after_reset_ignored',(([] call _snapshot) # 1) isEqualTo []] call IA_fnc_assert;

// Cancel and timeout before an accepted handoff consume nothing.
{
    private _scenario = _x;
    call _freshTube;
    ['REQUEST',player,'TUBE',[]] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
    _result = [{params ['_entries']; count _entries isEqualTo 1 && {(_entries # 0) # 7}}] call _waitEntries;
    _entries = ((_result # 1) # 1);
    if (_entries isNotEqualTo []) then {
        _entry = _entries # 0;
        if (_scenario isEqualTo 'false_ack') then {['ACK',player,_entry # 0,_entry # 1,FALSE] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];};
        if (_scenario isEqualTo 'reset') then {['RESET',player] remoteExec ['QS_fnc_mortarSupport',2,FALSE];};
        if (_scenario isEqualTo 'timeout') then {['EXPIRE'] call _snapshot;};
        _result = [{params ['_entries']; _entries isEqualTo []}] call _waitEntries;
        ['support_' + _scenario + '_preserves_tube',_result # 0 && {backpack player isEqualTo 'B_Mortar_01_weapon_F'}] call IA_fnc_assert;
        ['ACK',player,_entry # 0,_entry # 1,TRUE] remoteExec ['QS_fnc_mortarSupport',2,FALSE];
    } else {['support_' + _scenario + '_admission',FALSE] call IA_fnc_assert;};
    call _reset;
} forEach ['false_ack','reset','timeout'];

// Swap to a fresh identical-class backpack after admission. Object identity,
// rather than a client Boolean or class comparison, protects the replacement.
call _freshTube;
['REQUEST',player,'TUBE',[]] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
_result = [{params ['_entries']; count _entries isEqualTo 1 && {(_entries # 0) # 7}}] call _waitEntries;
_entries = ((_result # 1) # 1);
if (_entries isNotEqualTo []) then {
    _entry = _entries # 0;
    call _freshTube;
    ['ACK',player,_entry # 0,_entry # 1,TRUE] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
    _result = [{params ['_entries']; _entries isEqualTo []}] call _waitEntries;
    ['support_replacement_tube_not_debited',_result # 0 && {backpack player isEqualTo 'B_Mortar_01_weapon_F'}] call IA_fnc_assert;
};
call _reset;
localNamespace setVariable ['IA_support_holdPlacement',FALSE];
// Exercise the production PLACE worker and its own ACK with a native attach.
call _freshTube;
['SLOW_TICK'] call _snapshot;
private _normalStartedAt = diag_tickTime;
['REQUEST',player,'TUBE',[]] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
_result = [{params ['_entries']; count _entries isEqualTo 1}] call _waitEntries;
_entries = ((_result # 1) # 1);
if (_entries isNotEqualTo []) then {
    _entry = _entries # 0;
    ['support_slot_reserved_before_handoff',!(_entry # 7) && {_entry # 2} && {(_entry # 6) isEqualTo 0}] call IA_fnc_assert;
    ['ACK',player,_entry # 0,_entry # 1,TRUE] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
    uiSleep 0.2;
    _state = [] call _snapshot;
    ['support_ack_before_handoff_cannot_debit',backpack player isEqualTo 'B_Mortar_01_weapon_F' &&
        {count (_state # 1) isEqualTo 1} && {!(((_state # 1) # 0) # 5)}] call IA_fnc_assert;
};
_result = [{params ['_entries']; count _entries isEqualTo 1 && {!((_entries # 0) # 2)} && {((_entries # 0) # 6) isEqualTo 8}},14] call _waitEntries;
['support_normal_place_debits_and_arms',_result # 0 && {backpack player isEqualTo ''},
    [diag_tickTime - _normalStartedAt,((_result # 1) # 1) apply {_x select [7,3]}]] call IA_fnc_assert;
for '_count' from 2 to 3 do {
    call _freshTube;
    ['REQUEST',player,'TUBE',[]] remoteExec ['QS_fnc_mortarSupport',2,FALSE];
    _result = [{params ['_entries']; count _entries isEqualTo _count && {(_entries findIf {_x # 2}) < 0} &&
        {(_entries findIf {(_x # 6) isNotEqualTo 8}) < 0}},14] call _waitEntries;
    ['support_section_admits_' + str _count,_result # 0] call IA_fnc_assert;
};
call _freshTube;
for '_i' from 1 to 4 do {['REQUEST',player,'TUBE',[]] remoteExec ['QS_fnc_mortarSupport',2,FALSE];};
uiSleep 0.5;
_state = ['TICK'] call _snapshot;
['support_full_section_keeps_fourth_tube',count (_state # 1) isEqualTo 3 && {backpack player isEqualTo 'B_Mortar_01_weapon_F'}] call IA_fnc_assert;
call _reset;
['REQUEST',player,'MORTAR',[]] remoteExec ['QS_fnc_mortarSupport',2,FALSE];
_result = [{params ['_entries']; count _entries isEqualTo 1 && {!((_entries # 0) # 2)} && {((_entries # 0) # 6) isEqualTo 8}},14] call _waitEntries;
['support_free_request_preserves_backpack',_result # 0 && {backpack player isEqualTo 'B_Mortar_01_weapon_F'}] call IA_fnc_assert;
call _reset;
['REQUEST',player,'MORTAR',[]] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
uiSleep 0.5;
['support_reset_preserves_free_request_cooldown',(([] call _snapshot) # 1) isEqualTo []] call IA_fnc_assert;
call _reset;
player setVariable ['QS_unit_role','rifleman',TRUE];
['CLIENT'] call QS_fnc_artillerySupport;
['support_role_departure_removes_menus',((localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]]) # 1) isEqualTo []] call IA_fnc_assert;
call compile preprocessFileLineNumbers 'tests\support-artillery-client.sqf';
player setVariable ['IA_support_done',TRUE,TRUE];
call IA_fnc_finish;
