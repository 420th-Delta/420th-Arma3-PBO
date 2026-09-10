// Narrow fixture dependencies, not substitutes for the integrated mission pass.
// Compile these before the support suites; the actual support functions remain
// the production CfgFunctions. The PLACE dependency uses real engine attachTo.
QS_data_listItems = {
    ['i_mortar_01_weapon_f','o_mortar_01_weapon_f','i_e_mortar_01_weapon_f','b_mortar_01_weapon_f','b_mortar_01_weapon_grn_f']
};
missionNamespace setVariable ['QS_mortarSupport_diagnostics',TRUE];
QS_fnc_inZone = {[FALSE,0,FALSE]};
// Capacity lookup dependency; authorization itself reads the production role
// registry. Each declared JTAC role has two allowed slots in this fixture.
QS_fnc_roles = {params ['','_role']; [_role,2]};
QS_fnc_eventAttach = {
    params ['_mode','_object',['_args',[]]];
    if (_mode isEqualTo 0) then {detach _object;} else {_object attachTo _args;};
};
QS_fnc_showNotification = {['support_notification',_this] call IA_fnc_log;};
QS_fnc_remoteExecCmd = {['support_message',_this] call IA_fnc_log;};
QS_fnc_unloadCargoPlacementMode = {
    params ['_unit','_mortar'];
    ['support_placement_handoff',[_mortar getVariable ['QS_mortarSupport_nonce',-1],local _mortar,
        localNamespace getVariable ['IA_support_holdPlacement',FALSE]]] call IA_fnc_log;
    // HOLD deliberately keeps the real PLACE worker before its ACK. Tests can
    // send custom RPCs while this dependency waits, without replacing the API.
    private _until = diag_tickTime + 30;
    waitUntil {uiSleep 0.05; isNull _mortar ||
        {!(localNamespace getVariable ['IA_support_holdPlacement',FALSE])} || {diag_tickTime >= _until}};
    if (!isNull _mortar && {!(_mortar getVariable ['QS_mortarSupport_retiring',FALSE])}) then {
        _mortar attachTo [_unit,[0,2,0.5]];
    };
};
QS_fnc_iaSupportTest = compile preprocessFileLineNumbers 'tests\support-rpc.sqf';
