if (!isServer) exitWith {};
['support_server_is_dedicated',isDedicated] call IA_fnc_assert;
['support_no_client_observer_on_server',!(localNamespace getVariable ['QS_artillerySupport_clientStarted',FALSE])] call IA_fnc_assert;
private _until = diag_tickTime + 210;
private _artilleryStep = compile preprocessFileLineNumbers 'tests\support-artillery-server.sqf';
private _nextMortarTick = 0;
waitUntil {
    uiSleep 0.05;
    // A client RPC cannot impersonate the trusted core tick. This fixture's
    // local server loop starts fast for adversarial probes, then switches to
    // the real three-second cadence for ordinary handoff/debit/section tests.
    if (diag_tickTime >= (_nextMortarTick max (serverNamespace getVariable ['IA_support_mortarTickAfter',0]))) then {
        _nextMortarTick = diag_tickTime + (serverNamespace getVariable ['IA_support_mortarTickInterval',0.25]);
        ['TICK'] call QS_fnc_mortarSupport;
    };
    private _queue = serverNamespace getVariable ['IA_support_artilleryQueue',[]];
    if (_queue isNotEqualTo []) then {(_queue deleteAt 0) call _artilleryStep;};
    (allPlayers findIf {_x getVariable ['IA_support_done',FALSE]}) >= 0 || {diag_tickTime >= _until}
};
['support_client_suite_completed',(allPlayers findIf {_x getVariable ['IA_support_done',FALSE]}) >= 0] call IA_fnc_assert;
['support_server_finished',[]] call IA_fnc_log;
call IA_fnc_finish;
