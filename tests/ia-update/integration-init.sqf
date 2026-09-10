[] spawn {
    private _until = diag_tickTime + 150;
    waitUntil {uiSleep 0.2; missionNamespace getVariable ['QS_mission_init',FALSE] || {diag_tickTime > _until}};
    ['mission_initialized',missionNamespace getVariable ['QS_mission_init',FALSE]] call IA_fnc_assert;
    ['ready',[productVersion,hasInterface,isDedicated]] call IA_fnc_log;
    if (isServer) then {
        private _fn_connections = {
            private _registry = +(missionNamespace getVariable ['QS_headlessClients',[]]);
            private _actualOwners = (allPlayers select {_x isKindOf 'HeadlessClient_F'}) apply {owner _x};
            private _humans = allPlayers select {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}};
            _registry sort TRUE;
            _actualOwners sort TRUE;
            [count _humans >= __PLAYERS__,count _registry isEqualTo __HEADLESS__ &&
                {count _actualOwners isEqualTo __HEADLESS__} && {_registry isEqualTo _actualOwners},
                [count _humans,_registry,_actualOwners]]
        };
        private _fn_ownership = {
            private _owners = [2] + (missionNamespace getVariable ['QS_headlessClients',[]]) +
                ((allPlayers select {_x isKindOf 'HeadlessClient_F'}) apply {owner _x});
            _owners = _owners arrayIntersect _owners;
            _owners apply {
                private _ownerID = _x;
                [_ownerID,{!isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')} && {owner _x isEqualTo _ownerID}} count allUnits,
                    {groupOwner _x isEqualTo _ownerID} count allGroups]
            }
        };
        _until = diag_tickTime + 150;
        waitUntil {
            uiSleep 0.5;
            private _connections = call _fn_connections;
            ((_connections # 0) && {_connections # 1}) || {diag_tickTime > _until}
        };
        private _connections = call _fn_connections;
        ['headless_connected',_connections # 1,_connections # 2] call IA_fnc_assert;
        ['players_connected',_connections # 0,_connections # 2] call IA_fnc_assert;
        ['mission_classic',(missionNamespace getVariable ['QS_mission_aoType','']) isEqualTo 'CLASSIC'] call IA_fnc_assert;
        ['database_absent_for_isolated_test',!(missionNamespace getVariable ['TGC_db_ready',FALSE])] call IA_fnc_assert;
        _until = diag_tickTime + __OBSERVE__;
        while {diag_tickTime < _until} do {
            ['heartbeat',[diag_fps,diag_deltaTime,count allUnits,count allGroups,
                count (allUnits select {local _x}),missionNamespace getVariable ['QS_classic_AI_active',FALSE],
                missionNamespace getVariable ['QS_aoPos',[0,0,0]],
                count (missionNamespace getVariable ['QS_headlessClients',[]])]] call IA_fnc_log;
            ['ownership_snapshot',call _fn_ownership] call IA_fnc_log;
            uiSleep 5;
        };
        // INTEGRATION_EXECUTION_END
        _connections = call _fn_connections;
        ['players_present_after_execution',_connections # 0,_connections # 2] call IA_fnc_assert;
        ['headless_present_and_registered_after_execution',_connections # 1,_connections # 2] call IA_fnc_assert;
        private _primaryActive = missionNamespace getVariable ['QS_classic_AI_active',FALSE] &&
            {missionNamespace getVariable ['QS_primaryPressure_running',FALSE]} &&
            {count (missionNamespace getVariable ['QS_primaryPressure_state',createHashMap]) > 0};
        private _defenseActive = missionNamespace getVariable ['QS_defendActive',FALSE] &&
            {missionNamespace getVariable ['QS_defendControl_active',FALSE]};
        ['activity_controller_active_after_execution',_primaryActive || {_defenseActive},
            [_primaryActive,_defenseActive,missionNamespace getVariable ['QS_megaDefense_core',[]]]] call IA_fnc_assert;
        ['ownership_snapshot_final',call _fn_ownership] call IA_fnc_log;
        ['mission_initialized_after_execution',missionNamespace getVariable ['QS_mission_init',FALSE]] call IA_fnc_assert;
        ['phase',['complete']] call IA_fnc_log;
    } else {
        if (hasInterface) then {
            _until = diag_tickTime + 120;
            waitUntil {uiSleep 0.2; !isNull player && {!isNil {player getVariable 'QS_5551212'}} || {diag_tickTime > _until}};
            ['player_admitted',!isNull player && {!isNil {player getVariable 'QS_5551212'}}] call IA_fnc_assert;
            ['support_observer_started',localNamespace getVariable ['QS_artillerySupport_clientStarted',FALSE]] call IA_fnc_assert;
        };
        while {TRUE} do {
            ['heartbeat',[diag_fps,diag_deltaTime,count (allUnits select {local _x}),clientOwner]] call IA_fnc_log;
            uiSleep 5;
        };
    };
};
