IA_sequence = 0;
IA_role = if (isServer) then {'server'} else {profileName};
IA_fnc_log = {
    params ['_kind',['_data',[]]];
    IA_sequence = IA_sequence + 1;
    diag_log text ('FRZ|' + toJSON [IA_role,_kind,diag_tickTime,IA_sequence,_data]);
};
IA_fnc_assert = {
    params ['_name',['_passed',FALSE],['_details',[]]];
    _passed = (_passed isEqualType TRUE) && {_passed};
    ['check',[_name,_passed,_details]] call IA_fnc_log;
};
IA_fnc_finish = {
    missionNamespace setVariable ['IA_finished_' + IA_role,TRUE,TRUE];
    ['suite_finished',[]] call IA_fnc_log;
};
IA_errorCount = 0;
addMissionEventHandler ['ScriptError',{
    IA_errorCount = IA_errorCount + 1;
    if (IA_errorCount <= 25) then {diag_log text ('FRZ_SCRIPT_ERROR|' + str _this);};
    if (IA_errorCount isEqualTo 25) then {
        ['script_error_limit',FALSE,[IA_role]] call IA_fnc_assert;
        missionNamespace setVariable ['IA_abort',TRUE,TRUE];
    };
}];
// HARNESS_ABORT_BEGIN
if (isServer) then {
    [] spawn {
        waitUntil {uiSleep 0.5; missionNamespace getVariable ['IA_abort',FALSE]};
        ['aborted_due_to_script_errors',FALSE] call IA_fnc_assert;
        ['phase',['complete']] call IA_fnc_log;
    };
};
// HARNESS_DISPATCH_BEGIN
[] spawn {
    waitUntil {uiSleep 0.1; time > 0};
    ['ready',[productVersion]] call IA_fnc_log;
    private _dependencies = 'tests\__SUITE__-dependencies.sqf';
    if (fileExists _dependencies) then {call compile preprocessFileLineNumbers _dependencies;};
    if (isServer) then {
        [] execVM 'tests\__SUITE__-server.sqf';
        waitUntil {uiSleep 0.2; missionNamespace getVariable ['IA_finished_server',FALSE]};
        private _until = diag_tickTime + 90;
        waitUntil {
            uiSleep 0.2;
            private _done = TRUE;
            for '_i' from 0 to (__PLAYERS__ - 1) do {
                _done = _done && {missionNamespace getVariable ['IA_finished_client' + str _i,FALSE]};
            };
            _done || {diag_tickTime > _until}
        };
        for '_i' from 0 to (__PLAYERS__ - 1) do {
            ['client_finished_' + str _i,missionNamespace getVariable ['IA_finished_client' + str _i,FALSE]] call IA_fnc_assert;
        };
        ['phase',['complete']] call IA_fnc_log;
    } else {
        waitUntil {uiSleep 0.1; !isNull player && {isPlayer player}};
        [] execVM 'tests\__SUITE__-client.sqf';
    };
};
