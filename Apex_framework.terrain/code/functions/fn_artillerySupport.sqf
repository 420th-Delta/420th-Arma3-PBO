// Added Code
/*
File: fn_artillerySupport.sqf
Description:
    Forward Observer and JTAC Support menus, server ammunition and virtual fire.
    Separate service pools; JTAC shares follow authorized role capacity, including
    empty slots. No physical battery, aircraft, crew or editor support module.
*/
private _mode = 'INIT';
if (_this isEqualType [] && {(_this param [0,FALSE]) isEqualType ''}) then {_mode = _this # 0;};
if (_mode isEqualTo 'postInit') then {_mode = 'INIT';};
if (isRemoteExecuted && {isRemoteExecutedJIP || {
    !((_mode in ['REQUEST','CANCEL'] && {isServer}) ||
    {_mode in ['CLIENT','PING','CLEAR_PING'] && {hasInterface} && {remoteExecutedOwner isEqualTo 2}})
}}) exitWith {};
// Client initialization has no remote caller and must latch exactly once.
if (canSuspend && {_mode isEqualTo 'INIT'}) exitWith {
    private _args = +_this;
    isNil {_args call QS_fnc_artillerySupport;};
};

// ROLE_SUPPORT_POLICY_BEGIN
private _fn_allowance = {
    params ['_population','_defense','_kind',['_slots',1]];
    // Each allowed JTAC slot receives the same stock, including vacant slots.
    // Only activity start issues ammunition; occupancy and population cannot refill it.
    if (_kind isEqualTo 'JTAC') exitWith {
        [3,2,1] apply {_x * ((floor _slots) max 0 min 64) * ([1,2] select _defense)}
    };
    private _base = [16,4,2,4];
    private _factor = 0.5 + (0.5 * (((_population - 10) / 21) max 0 min 1));
    (_base apply {round (_x * _factor)}) apply {_x * ([1,2] select _defense)}
};
private _fn_service = {
    params ['_role'];
    if (_role isEqualTo 'forward_observer') exitWith {'FO'};
    if (_role in ['jtac','jtac_WL']) exitWith {'JTAC'};
    ''
};
private _fn_eligible = {
    params ['_kind','_west','_alive','_incapacitated','_controlled'];
    (_kind in ['FO','JTAC']) && {_west} && {_alive} && {!_incapacitated} && {!_controlled}
};
private _fn_dangerClose = {
    params ['_aim','_positions','_dispersion'];
    (_positions findIf {(_x distance2D _aim) < (175 + _dispersion)}) >= 0
};
// Empty slots retain shares. Whole-round remainders rotate per activity.
// Debits include reservations and closed slots. Population changes never mint ammo.
private _fn_allocate = {
    params ['_issued','_slots','_debits','_rotation'];
    if (_slots <= 0) exitWith {[]};
    private _result = [];
    for '_i' from 0 to (_slots - 1) do {_result pushBack (_issued apply {0});};
    {
        private _pool = _forEachIndex;
        private _total = _x;
        private _share = floor (_total / _slots);
        private _extra = _total mod _slots;
        private _spent = 0;
        {_spent = _spent + (_x param [_pool,0]);} forEach _debits;
        private _sum = 0;
        for '_i' from 0 to (_slots - 1) do {
            private _rank = (_i - (_rotation mod _slots) + _slots) mod _slots;
            private _quota = _share + ([0,1] select (_rank < _extra));
            private _left = (_quota - ((_debits param [_i,[]]) param [_pool,0])) max 0;
            (_result # _i) set [_pool,_left]; _sum = _sum + _left;
        };
        private _excess = (_sum - ((_total - _spent) max 0)) max 0;
        private _cursor = _rotation mod _slots;
        for '_take' from 1 to _excess do {
            for '_try' from 1 to _slots do {
                private _row = _result # _cursor;
                _cursor = (_cursor + 1) mod _slots;
                if ((_row # _pool) > 0) exitWith {_row set [_pool,(_row # _pool) - 1];};
            };
        };
    } forEach _issued;
    _result
};
// UID usage survives role departure and respawn, including a return to another slot.
private _fn_personalStock = {
    params ['_stock','_issued','_slots','_uidSpent'];
    if (_slots <= 0) exitWith {_issued apply {0}};
    private _result = [];
    {
        _result pushBack (_x min (((ceil ((_issued # _forEachIndex) / _slots)) - (_uidSpent param [_forEachIndex,0])) max 0));
    } forEach _stock;
    _result
};
private _fn_admission = {
    params ['_stock','_pool','_rounds','_busy','_epoch','_requestedEpoch'];
    !_busy && {_epoch isEqualTo _requestedEpoch} &&
    {finite _pool && {_pool isEqualTo floor _pool} && {_pool >= 0} && {_pool < count _stock}} &&
    {finite _rounds && {_rounds isEqualTo floor _rounds} && {_rounds >= 1} && {_rounds <= 8}} &&
    {_rounds <= (_stock # _pool)}
};
private _fn_rounds = {
    params ['_kind','_requested'];
    [ _requested,1 ] select (_kind isEqualTo 'JTAC')
};
private _fn_schedule = {
    params ['_accepted','_rounds','_height','_speed','_announceDelay','_completionDelay'];
    // Ballistic estimate only: Arma guidance, drag and terrain determine impacts.
    // The final release includes its estimated flight; eight shells fit one window.
    private _flight = (2 * _height) / (_speed + sqrt ((_speed * _speed) + (19.62 * _height)));
    private _complete = _accepted + _completionDelay;
    private _releases = [];
    for '_i' from 0 to (_rounds - 1) do {
        _releases pushBack (_complete - _flight - (0.5 * (_rounds - 1 - _i)));
    };
    [_accepted + _announceDelay,_complete,_releases,_flight]
};
// ROLE_SUPPORT_POLICY_END

// id, service, label, pool, magazine, guidance, dispersion, height, speed.
// Fixed vanilla whitelist. Limited ICM/bombs; no mines, SDBs or cluster rockets.
private _profiles = [
    ['HE','FO','155 mm HE',0,'32Rnd_155mm_Mo_shells','NONE',[0,25,50,100],500,150],
    ['LASER','FO','155 mm laser guided',1,'2Rnd_155mm_Mo_LG','LASER',[0],500,150],
    ['IR','FO','155 mm IR guided',1,'4Rnd_155mm_Mo_guided','IR',[0],500,150],
    ['ICM','FO','155 mm ICM (cluster)',2,'2Rnd_155mm_Mo_Cluster','NONE',[0],500,150],
    ['ROCKET','FO','230 mm HE rocket',3,'12Rnd_230mm_rockets','NONE',[0,25,50,100],500,150],
    ['BOMB_HE','JTAC','Mk82 unguided',0,'2Rnd_Mk82','NONE',[0,25,50,100],500,100],
    ['BOMB_LASER','JTAC','GBU-12 laser guided',1,'2Rnd_GBU12_LGB','LASER',[0],500,100],
    ['BOMB_CLUSTER','JTAC','CBU-85 cluster (laser)',2,'4Rnd_BombCluster_01_F','LASER',[0],500,100]
];
private _fn_resolveAmmo = {
    params ['_profile'];
    private _class = getText (configFile >> 'CfgMagazines' >> (_profile # 4) >> 'ammo');
    if ((_profile # 0) in ['LASER','IR']) then {
        // Vertical virtual release of these shell carriers corrupts their native
        // child's orientation. Release the configured missile directly instead.
        _class = getText (configFile >> 'CfgAmmo' >> _class >> 'submunitionAmmo');
        if ((toLowerANSI getText (configFile >> 'CfgAmmo' >> _class >> 'simulation')) isNotEqualTo 'shotmissile') then {_class = '';};
    };
    _class
};
if (_mode isEqualTo 'INIT') exitWith {
    if (!hasInterface || {localNamespace getVariable ['QS_artillerySupport_clientStarted',FALSE]}) exitWith {};
    localNamespace setVariable ['QS_artillerySupport_clientStarted',TRUE];
    private _killedEH = addMissionEventHandler ['EntityKilled',{
        if ((_this # 0) isEqualTo player || {(_this # 0) isEqualTo ((localNamespace getVariable ['QS_artillerySupport_menuOwner',[objNull,-1,'']]) # 0)}) then {['CLIENT'] call QS_fnc_artillerySupport;};
    }];
    private _respawnEH = addMissionEventHandler ['EntityRespawned',{
        if ((_this # 0) isEqualTo player || {(_this # 1) isEqualTo ((localNamespace getVariable ['QS_artillerySupport_menuOwner',[objNull,-1,'']]) # 0)}) then {['CLIENT'] call QS_fnc_artillerySupport;};
    }];
    // One observer for all role Supports: JIP, revive, role and control changes.
    private _observer = [] spawn {while {TRUE} do {['CLIENT'] call QS_fnc_artillerySupport; uiSleep 2;};};
    localNamespace setVariable ['QS_artillerySupport_clientLifecycle',[_killedEH,_respawnEH,_observer]];
};
if (_mode in ['PING','CLEAR_PING']) exitWith {
    if (!hasInterface || {!isRemoteExecuted} || {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
    private _marks = localNamespace getVariable ['QS_artillerySupport_pings',[]];
    private _token = _this param [1,'',['']];
    _marks = _marks select {(_x # 0) isNotEqualTo _token && {diag_tickTime < (_x # 2)}};
    if (_mode isEqualTo 'PING') then {
        _marks pushBack [_token,_this # 2,diag_tickTime + 35];
        if ((localNamespace getVariable ['QS_artillerySupport_pingEH',-1]) < 0) then {
            private _eh = addMissionEventHandler ['Draw3D',{
                {if (diag_tickTime < (_x # 2)) then {
                    drawIcon3D ['\a3\ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa',[0.1,0.55,1,1],
                        (_x # 1) vectorAdd [0,0,1],1,1,0,'Fire support',1,0.035,'RobotoCondensed','center'];
                };} forEach (localNamespace getVariable ['QS_artillerySupport_pings',[]]);
            }];
            localNamespace setVariable ['QS_artillerySupport_pingEH',_eh];
        };
    };
    localNamespace setVariable ['QS_artillerySupport_pings',_marks];
};
if (_mode isEqualTo 'CLIENT') exitWith {
    if (!hasInterface) exitWith {};
    ['CLIENT'] call QS_fnc_mortarSupport;
    private _marks = (localNamespace getVariable ['QS_artillerySupport_pings',[]]) select {diag_tickTime < (_x # 2)};
    localNamespace setVariable ['QS_artillerySupport_pings',_marks];
    private _pingEH = localNamespace getVariable ['QS_artillerySupport_pingEH',-1];
    if (_marks isEqualTo [] && {_pingEH >= 0}) then {
        removeMissionEventHandler ['Draw3D',_pingEH]; localNamespace setVariable ['QS_artillerySupport_pingEH',-1];
    };
    private _kind = [player getVariable ['QS_unit_role','']] call _fn_service;
    private _eligible = [_kind,(player getVariable ['QS_unit_side',WEST]) isEqualTo WEST,alive player,
        (lifeState player) isEqualTo 'INCAPACITATED',isRemoteControlling player || {!isNull curatorCamera}] call _fn_eligible;
    private _owner = localNamespace getVariable ['QS_artillerySupport_menuOwner',[objNull,-1,'']];
    _owner params ['_unit','_menu','_oldKind'];
    if (_menu >= 0 && {!_eligible || {player isNotEqualTo _unit} || {_kind isNotEqualTo _oldKind}}) then {
        if (!isNull _unit) then {
            [_unit,_menu] call BIS_fnc_removeCommMenuItem;
            ['CANCEL',_unit] remoteExecCall ['QS_fnc_artillerySupport',2,FALSE];
        }; _menu = -1;
        localNamespace setVariable ['QS_artillerySupport_selection',[]];
        if ((commandingMenu find '#USER:QS_artillerySupport_') isEqualTo 0) then {showCommandingMenu '';};
    };
    if (_eligible && {_menu < 0}) then {
        _unit = player;
        _menu = [_unit,['QS_CallForFire','QS_CallAirstrike'] select (_kind isEqualTo 'JTAC'),[],[],''] call BIS_fnc_addCommMenuItem;
    };
    localNamespace setVariable ['QS_artillerySupport_menuOwner',[_unit,_menu,_kind]];
};

if (_mode in ['MENU','ROUNDS','DISPERSION','CONFIRM','SEND']) exitWith {
    if (!hasInterface || {isRemoteExecuted}) exitWith {};
    private _kind = [player getVariable ['QS_unit_role','']] call _fn_service;
    if (!([_kind,(player getVariable ['QS_unit_side',WEST]) isEqualTo WEST,alive player,
        (lifeState player) isEqualTo 'INCAPACITATED',isRemoteControlling player || {!isNull curatorCamera}] call _fn_eligible)) exitWith {};
    if ((player getVariable ['QS_tto',0]) > 1) exitWith {systemChat 'Too much reported friendly fire';};
    private _status = player getVariable ['QS_artillerySupport_status',[]];
    if (count _status isNotEqualTo 7 || {(_status # 1) isNotEqualTo _kind}) exitWith {systemChat 'Fire support is unavailable between missions.';};
    _status params ['_epoch','','_stock','_busy','_available','_slots','_slot'];
    if (_busy) exitWith {systemChat 'This support is completing a fire mission.';};
    if (_mode isEqualTo 'MENU') exitWith {
        private _target = _this param [1,[],[[]]];
        if (count _target < 2) exitWith {systemChat 'Select a ground target on the map or in your sights.';};
        localNamespace setVariable ['QS_artillerySupport_selection',[_epoch,+_target,player,_kind,-1,1,0]];
        private _menu = [[['Artillery Order','Airstrike Order'] select (_kind isEqualTo 'JTAC'),TRUE]];
        {if ((_x # 1) isEqualTo _kind && {_forEachIndex in _available}) then {
            private _left = _stock # (_x # 3);
            _menu pushBack [format ['%1 (%2 left)',_x # 2,_left],[count _menu + 1],'',-5,
                [['expression',format ["['ROUNDS',%1] call QS_fnc_artillerySupport",_forEachIndex]]],'1',['0','1'] select (_left > 0)];
        };} forEach _profiles;
        missionNamespace setVariable ['QS_artillerySupport_menu',_menu]; showCommandingMenu '#USER:QS_artillerySupport_menu';
    };
    private _selection = localNamespace getVariable ['QS_artillerySupport_selection',[]];
    if (count _selection isNotEqualTo 7 || {(_selection # 0) isNotEqualTo _epoch} ||
        {(_selection # 2) isNotEqualTo player} || {(_selection # 3) isNotEqualTo _kind}) exitWith {systemChat 'Fire support changed. Select your target again.';};
    if (_mode isEqualTo 'ROUNDS') exitWith {
        private _index = _this param [1,-1,[0]];
        if !(_index in _available) exitWith {};
        private _profile = _profiles # _index;
        if ((_profile # 1) isNotEqualTo _kind) exitWith {};
        _selection set [4,_index]; localNamespace setVariable ['QS_artillerySupport_selection',_selection];
        // JTAC selects a payload, then its dispersion: every request is one bomb.
        if (_kind isEqualTo 'JTAC') exitWith {['DISPERSION',1] call QS_fnc_artillerySupport;};
        private _left = (_stock # (_profile # 3)) min 8;
        private _menu = [[_profile # 2,TRUE]];
        for '_n' from 1 to _left do {
            _menu pushBack [format ['%1 round%2',_n,['s',''] select (_n isEqualTo 1)],[count _menu + 1],'',-5,
                [['expression',format ["['DISPERSION',%1] call QS_fnc_artillerySupport",_n]]],'1','1'];
        };
        missionNamespace setVariable ['QS_artillerySupport_roundMenu',_menu]; showCommandingMenu '#USER:QS_artillerySupport_roundMenu';
    };
    private _index = _selection # 4;
    if !(_index in _available) exitWith {};
    private _profile = _profiles # _index;
    if (_mode isEqualTo 'DISPERSION') exitWith {
        _selection set [5,[_kind,_this param [1,1,[0]]] call _fn_rounds]; localNamespace setVariable ['QS_artillerySupport_selection',_selection];
        private _choices = _profile # 6;
        if (count _choices isEqualTo 1) exitWith {['CONFIRM',_choices # 0] call QS_fnc_artillerySupport;};
        private _menu = [['Dispersion radius',TRUE]];
        {_menu pushBack [format ['%1 m',_x],[count _menu + 1],'',-5,
            [['expression',format ["['CONFIRM',%1] call QS_fnc_artillerySupport",_x]]],'1','1'];} forEach _choices;
        missionNamespace setVariable ['QS_artillerySupport_dispersionMenu',_menu]; showCommandingMenu '#USER:QS_artillerySupport_dispersionMenu';
    };
    if (_mode isEqualTo 'CONFIRM') exitWith {
        private _dispersion = _this param [1,0,[0]];
        if !(_dispersion in (_profile # 6)) exitWith {};
        _selection set [6,_dispersion]; localNamespace setVariable ['QS_artillerySupport_selection',_selection];
        missionNamespace setVariable ['QS_artillerySupport_confirmMenu',[
            [format ['%1: %2 %3, %4 m',_profile # 2,_selection # 5,['rounds','bomb'] select (_kind isEqualTo 'JTAC'),_dispersion],TRUE],
            ['Request Fire Mission',[2],'',-5,[['expression',"['SEND'] call QS_fnc_artillerySupport"]],'1','1']
        ]]; showCommandingMenu '#USER:QS_artillerySupport_confirmMenu';
    };
    if (diag_tickTime < (localNamespace getVariable ['QS_artillerySupport_nextRequest',0])) exitWith {};
    localNamespace setVariable ['QS_artillerySupport_nextRequest',diag_tickTime + 2];
    ['REQUEST',player,_epoch,_selection # 1,_index,_selection # 5,_selection # 6] remoteExecCall ['QS_fnc_artillerySupport',2,FALSE];
    localNamespace setVariable ['QS_artillerySupport_selection',[]]; showCommandingMenu '';
};

if (!isServer) exitWith {};
// Preserve engine-authenticated provenance before isNil can clear that context.
// Lifecycle, requests and refunds share one atomic server transition, including
// CANCEL delivered through scheduled remoteExec. No network argument supplies
// either of these provenance values.
private _remoteCall = isRemoteExecuted;
private _remoteOwner = remoteExecutedOwner;
private _serverArgs = +_this;
private _fn_serverDispatch = {
// Native remote-control queries need local arguments. The mission and Zeus
// publish owner markers on the controlled actor. Resolve them at each readiness
// check, including the independently spawned fire worker after role/control changes.
private _state = serverNamespace getVariable ['QS_artillerySupport_state',createHashMap];
private _fn_private = {
    params ['_unit','_text'];
    if (!isNull _unit && {isPlayer _unit}) then {['sideChat',[WEST,'BLU'],_text] remoteExec ['QS_fnc_remoteExecCmd',_unit,FALSE];};
};
private _fn_holder = {
    params ['_unit',['_ready',TRUE]];
    if (isNull _unit || {!isPlayer _unit} || {(side group _unit) isNotEqualTo WEST}) exitWith {''};
    private _kind = [_unit getVariable ['QS_unit_role','']] call _fn_service;
    if (_kind isEqualTo '') exitWith {''};
    if (_ready && {!([_kind,TRUE,alive _unit,(lifeState _unit) isEqualTo 'INCAPACITATED',
        (_unit getVariable ['QS_client_remoteControlling',FALSE]) ||
        {(allUnits findIf {(_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull]) isEqualTo _unit}) >= 0} ||
        {local _unit && {isRemoteControlling _unit}}] call _fn_eligible)}) exitWith {''};
    private _uid = getPlayerUID _unit;
    private _roles = (missionNamespace getVariable ['QS_unit_roles',[[],[],[],[]]]) # 1;
    private _found = _roles findIf {
        ([(_x # 0) # 0] call _fn_service) isEqualTo _kind && {((_x # 1) findIf {(_x # 0) isEqualTo _uid}) >= 0}
    };
    if (_uid isEqualTo '' || {_found < 0}) exitWith {''};
    if (_kind isEqualTo 'FO' && {count ((_roles # _found) # 1) isNotEqualTo 1}) exitWith {''};
    _kind
};
private _fn_penalty = {
    params ['_unit'];
    (missionNamespace getVariable ['QS_robocop',createHashMap]) getOrDefault [getPlayerUID _unit,0]
};
private _fn_capacity = {
    private _slots = 0;
    {
        private _name = (_x # 0) # 0;
        if (_name in ['jtac','jtac_WL']) then {
            private _row = ['GET_ROLE_COUNT',_name,WEST,FALSE] call QS_fnc_roles;
            _slots = _slots + ((_row param [1,0]) max 0);
        };
    } forEach ((missionNamespace getVariable ['QS_unit_roles',[[],[],[],[]]]) # 1);
    (floor _slots) min 64
};
private _fn_live = {
    private _kind = _state getOrDefault ['kind',''];
    if (_kind isEqualTo 'PRIMARY') exitWith {
        missionNamespace getVariable ['QS_classic_AI_active',FALSE] && {!(missionNamespace getVariable ['QS_defendActive',FALSE])}
    };
    if (_kind isEqualTo 'DEFENSE') exitWith {
        missionNamespace getVariable ['QS_defendActive',FALSE] && {!(missionNamespace getVariable ['QS_defend_terminate',FALSE])}
    };
    FALSE
};
private _fn_seat = {
    params ['_unit','_slots'];
    if (_slots <= 0) exitWith {-1};
    private _uid = getPlayerUID _unit;
    private _owners = _state get 'owners';
    while {count _owners < _slots} do {_owners pushBack '';};
    private _index = _owners find _uid;
    if (_index >= 0 && {_index < _slots}) exitWith {_index};
    private _held = [];
    {if (([_x,FALSE] call _fn_holder) isEqualTo 'JTAC') then {_held pushBackUnique (getPlayerUID _x);};} forEach allPlayers;
    private _found = -1;
    for '_i' from 0 to (_slots - 1) do {if (!((_owners # _i) in _held)) exitWith {_found = _i;};};
    if (_found >= 0) then {
        if (_index >= 0) then {_owners set [_index,''];};
        _owners set [_found,_uid];
    };
    _found
};
private _fn_stock = {
    params ['_unit','_kind'];
    if (_kind isEqualTo 'FO') exitWith {[+(_state get 'foStock'),1,0]};
    private _slots = call _fn_capacity;
    // Keep the activity's issued shares fixed. Closing a slot does not donate
    // its rounds; newly allowed slots wait until the next activity's refill.
    private _issuedSlots = _state get 'jtacSlots';
    _slots = _slots min _issuedSlots;
    private _seat = [_unit,_slots] call _fn_seat;
    if (_seat < 0) exitWith {[[0,0,0],_slots,-1]};
    private _issued = _state get 'jtacIssued';
    private _allocation = [_issued,_issuedSlots,_state get 'jtacDebits',_state get 'epoch'] call _fn_allocate;
    private _used = (_state get 'uidDebits') getOrDefault [getPlayerUID _unit,[0,0,0]];
    [[_allocation # _seat,_issued,_issuedSlots,_used] call _fn_personalStock,_slots,_seat]
};
private _fn_publish = {
    private _live = call _fn_live;
    private _published = _state getOrDefault ['published',createHashMap];
    _state set ['published',_published];
    {
        private _unit = _x;
        private _status = [];
        private _kind = [_unit,FALSE] call _fn_holder;
        if (_live && {_kind isNotEqualTo ''}) then {
            private _balance = [_unit,_kind] call _fn_stock;
            _status = [_state get 'epoch',_kind,_balance # 0,((_state get 'jobs') getOrDefault [_kind,[]]) isNotEqualTo [],
                +(_state get 'available'),_balance # 1,_balance # 2];
        };
        // Numeric-target setVariable writes only on that client. Keep the last
        // publication in server state so END/role departure sends the empty
        // status, and an ownership change receives the current status again.
        private _identity = netId _unit;
        private _publication = [owner _unit,_status];
        if ((_published getOrDefault [_identity,[]]) isNotEqualTo _publication) then {
            _published set [_identity,_publication];
            _unit setVariable ['QS_artillerySupport_status',_status,owner _unit];
        };
    } forEach (allPlayers select {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}});
};
// Job: id, worker, deadline, caller, seat, pool, pending, smoke, service, UID,
// server acceptance time, schedule [announcement, completion, releases, flight ETA].
private _fn_refund = {
    params ['_job'];
    _job params ['','','','_caller','_seat','_pool','_pending','','_kind','_uid'];
    if (_pending <= 0) exitWith {};
    if (_kind isEqualTo 'FO') then {
        private _stock = _state get 'foStock'; _stock set [_pool,(_stock # _pool) + _pending];
    } else {
        private _debits = (_state get 'jtacDebits') # _seat;
        _debits set [_pool,((_debits # _pool) - _pending) max 0];
        private _used = (_state get 'uidDebits') getOrDefault [_uid,[0,0,0]];
        _used set [_pool,((_used # _pool) - _pending) max 0];
    };
    _job set [6,0];
};
private _fn_clearJob = {
    params ['_job',['_terminate',TRUE],['_message','']];
    if (_terminate && {!scriptDone (_job # 1)}) then {terminate (_job # 1);};
    if (!isNull (_job # 7)) then {deleteVehicle (_job # 7);};
    ['CLEAR_PING',_job # 0] remoteExecCall ['QS_fnc_artillerySupport',WEST,FALSE];
    if (_message isNotEqualTo '') then {[_job # 3,_message] call _fn_private;};
};
private _fn_aim = {
    params ['_caller','_target','_guide'];
    if (_guide isEqualTo 'NONE') exitWith {[+_target,objNull]};
    private _candidates = [];
    if (_guide isEqualTo 'LASER') then {
        _candidates = (allMissionObjects 'LaserTargetW') select {alive _x && {(_x distance2D _target) <= 50}};
    } else {
        _candidates = vehicles select {alive _x && {!isNull (effectiveCommander _x)} &&
            {((side group (effectiveCommander _x)) getFriend WEST) < 0.6} &&
            {(_caller knowsAbout _x) >= 1.5} && {(_x distance2D _target) <= 50}};
    };
    private _nearest = objNull; private _distance = 51;
    {private _d = _x distance2D _target; if (_d < _distance) then {_nearest = _x; _distance = _d;};} forEach _candidates;
    if (isNull _nearest) exitWith {[]};
    [getPosATL _nearest,_nearest]
};
private _fn_friendPositions = {
    (allPlayers select {alive _x && {!(_x isKindOf 'HeadlessClient_F')}}) apply {getPosATL _x}
};
if (_mode isEqualTo 'START') exitWith {
    params ['','_kind','_key'];
    if (!(_kind in ['PRIMARY','DEFENSE']) || {[_kind,_key] isEqualTo (_state getOrDefault ['activity',[]])}) exitWith {};
    private _oldJobs = _state getOrDefault ['jobs',createHashMap];
    {[_oldJobs get _x,TRUE,'Activity changed. Fire mission cancelled.'] call _fn_clearJob;} forEach (keys _oldJobs);
    private _population = {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}} count allPlayers;
    private _jtacSlots = call _fn_capacity;
    private _available = []; private _ammo = [];
    {
        private _class = [_x] call _fn_resolveAmmo;
        if (_class isNotEqualTo '' && {isClass (configFile >> 'CfgAmmo' >> _class)}) then {_available pushBack _forEachIndex;}
        else {diag_log format ['[Role Support] Unsupported ammunition omitted: %1',_x # 4];};
        _ammo pushBack _class;
    } forEach _profiles;
    _state = createHashMapFromArray [
        ['epoch',1 + (_state getOrDefault ['epoch',0])],['kind',_kind],['activity',[_kind,_key]],['serial',0],
        ['foStock',[_population,_kind isEqualTo 'DEFENSE','FO'] call _fn_allowance],
        ['jtacSlots',_jtacSlots],
        ['jtacIssued',[_population,_kind isEqualTo 'DEFENSE','JTAC',_jtacSlots] call _fn_allowance],
        ['jtacDebits',[]],['uidDebits',createHashMap],['owners',[]],['jobs',createHashMap],['available',_available],['ammo',_ammo],
        ['published',createHashMap]
    ];
    serverNamespace setVariable ['QS_artillerySupport_state',_state];
    call _fn_publish;
    {if (([_x] call _fn_holder) isNotEqualTo '') then {[_x,'Fire support resupplied.'] call _fn_private;};} forEach allPlayers;
};
if (count _state isEqualTo 0) exitWith {};
if (_mode isEqualTo 'END') exitWith {
    params ['','_kind','_key'];
    if ([_kind,_key] isNotEqualTo (_state get 'activity')) exitWith {};
    private _jobs = _state get 'jobs';
    {[_jobs get _x,TRUE,'Activity ended. Fire mission cancelled.'] call _fn_clearJob;} forEach (keys _jobs);
    _state set ['kind','']; _state set ['jobs',createHashMap]; call _fn_publish;
};
if (_mode isEqualTo 'WATCHDOG') exitWith {
    private _jobs = _state get 'jobs';
    {
        private _job = _jobs get _x;
        if (scriptDone (_job # 1) || {diag_tickTime >= (_job # 2)} || {!(call _fn_live)} ||
            {([_job # 3] call _fn_holder) isNotEqualTo (_job # 8)} || {([_job # 3] call _fn_penalty) > 1}) then {
            [_job,TRUE,'Fire mission cancelled. Unfired rounds returned.'] call _fn_clearJob;
            [_job] call _fn_refund; _jobs deleteAt _x;
        };
    } forEach (keys _jobs);
    call _fn_publish;
};
if (_mode isEqualTo 'CANCEL') exitWith {
    if (!_remoteCall || {count _this isNotEqualTo 2}) exitWith {};
    private _unit = _this param [1,objNull,[objNull]];
    if (isNull _unit || {(owner _unit) isNotEqualTo _remoteOwner}) exitWith {};
    private _jobs = _state get 'jobs';
    {
        private _job = _jobs get _x;
        if ((_job # 3) isEqualTo _unit) then {
            [_job,TRUE,'Fire mission cancelled. Unfired rounds returned.'] call _fn_clearJob;
            [_job] call _fn_refund; _jobs deleteAt _x;
        };
    } forEach (keys _jobs);
    call _fn_publish;
};
if (_mode isNotEqualTo 'REQUEST' || {!_remoteCall} || {count _this isNotEqualTo 7}) exitWith {};
params ['',['_caller',objNull,[objNull]],['_epoch',-1,[0]],['_target',[],[[]]],['_index',-1,[0]],['_rounds',0,[0]],['_dispersion',0,[0]]];
if (isNull _caller || {(owner _caller) isNotEqualTo _remoteOwner}) exitWith {};
private _kind = [_caller] call _fn_holder;
if (_kind isEqualTo '') exitWith {};
if (([_caller] call _fn_penalty) > 1) exitWith {[_caller,'Too much reported friendly fire'] call _fn_private;};
if (diag_tickTime < (_caller getVariable ['QS_artillerySupport_nextRequest',0])) exitWith {};
_caller setVariable ['QS_artillerySupport_nextRequest',diag_tickTime + 2,FALSE];
if (!(count _target in [2,3]) || {(_target findIf {!(_x isEqualType 0) || {!finite _x}}) >= 0} ||
    {!finite _index} || {_index isNotEqualTo floor _index} || {!(_index in (_state get 'available'))} ||
    {!finite _epoch} || {!finite _rounds} || {!finite _dispersion}) exitWith {};
private _profile = _profiles # _index;
if ((_profile # 1) isNotEqualTo _kind || {!(_dispersion in (_profile # 6))}) exitWith {};
// A custom client cannot obtain a JTAC volley by bypassing its single-bomb menu.
_rounds = [_kind,_rounds] call _fn_rounds;
_target = [_target # 0,_target # 1,0];
if ((_target # 0) < 0 || {(_target # 1) < 0} || {(_target # 0) > worldSize} || {(_target # 1) > worldSize}) exitWith {};
if (!(call _fn_live)) exitWith {[_caller,'Fire support is unavailable between missions.'] call _fn_private;};
([_target,'SAFE'] call QS_fnc_inZone) params ['_inSafe','_level','_safeActive'];
if (_inSafe && {_safeActive} && {_level > 1}) exitWith {[_caller,localize 'STR_QS_Text_067'] call _fn_private;};
private _aim = [_caller,_target,_profile # 5] call _fn_aim;
if (_aim isEqualTo []) exitWith {[_caller,'No eligible designation within 50 m of the selected target.'] call _fn_private;};
private _danger = 'Requested Artillery fire mission is danger close to friendlies, request denied.';
if (_kind isEqualTo 'JTAC') then {_danger = 'Requested airstrike is danger close to friendlies, request denied.';};
if ([_aim # 0,call _fn_friendPositions,_dispersion] call _fn_dangerClose) exitWith {[_caller,_danger] call _fn_private;};
private _accepted = FALSE; private _job = [];
isNil {
    private _balance = [_caller,_kind] call _fn_stock;
    private _jobs = _state get 'jobs'; private _pool = _profile # 3;
    _accepted = [_balance # 0,_pool,_rounds,(_jobs getOrDefault [_kind,[]]) isNotEqualTo [],_state get 'epoch',_epoch] call _fn_admission;
    if (_accepted) then {
        private _uid = getPlayerUID _caller; private _seat = _balance # 2;
        if (_kind isEqualTo 'FO') then {
            private _stock = _state get 'foStock'; _stock set [_pool,(_stock # _pool) - _rounds];
        } else {
            private _rows = _state get 'jtacDebits';
            while {count _rows <= _seat} do {_rows pushBack [0,0,0];};
            private _row = _rows # _seat; _row set [_pool,(_row # _pool) + _rounds];
            private _used = (_state get 'uidDebits') getOrDefault [_uid,[0,0,0]];
            _used set [_pool,(_used # _pool) + _rounds]; (_state get 'uidDebits') set [_uid,_used];
        };
        private _serial = 1 + (_state get 'serial'); _state set ['serial',_serial];
        private _acceptedAt = diag_tickTime;
        private _schedule = [_acceptedAt,_rounds,_profile # 7,_profile # 8,10 + random 2,20 + random 5] call _fn_schedule;
        _job = [format ['%1:%2',_epoch,_serial],scriptNull,(_schedule # 1) + 5,_caller,_seat,_pool,_rounds,objNull,_kind,_uid,_acceptedAt,_schedule];
        _jobs set [_kind,_job]; call _fn_publish;
    };
};
if (!_accepted) exitWith {[_caller,'Support busy, share exhausted, or mission changed. Select your target again.'] call _fn_private;};
['PING',_job # 0,_target] remoteExecCall ['QS_fnc_artillerySupport',WEST,FALSE];
[_caller,format ['Fire mission accepted. Payload %1 x %2. Stand by; estimated completion in %3 seconds.',
    _rounds,_profile # 2,ceil (((_job # 11) # 1) - (_job # 10))]] call _fn_private;

// Closures are passed explicitly: spawn does not retain its caller's locals.
// Shot attribution keeps ordinary mission damage and Robocop handling available.
private _worker = [_state,_job,_epoch,+_target,_profile,(_state get 'ammo') # _index,_dispersion,
    _fn_holder,_fn_service,_fn_eligible,_fn_penalty,_fn_live,_fn_aim,_fn_friendPositions,_fn_dangerClose,
    _fn_refund,_fn_clearJob,_fn_private,_fn_publish,_fn_stock,_fn_capacity,_fn_seat,_fn_allocate,_fn_personalStock,_danger] spawn {
    params ['_state','_job','_epoch','_target','_profile','_ammo','_dispersion',
        '_fn_holder','_fn_service','_fn_eligible','_fn_penalty','_fn_live','_fn_aim','_fn_friendPositions','_fn_dangerClose',
        '_fn_refund','_fn_clearJob','_fn_private','_fn_publish','_fn_stock','_fn_capacity','_fn_seat','_fn_allocate','_fn_personalStock','_danger'];
    private _caller = _job # 3; private _kind = _job # 8; private _reason = '';
    (_job # 11) params ['_announceAt','_completeAt','_releaseTimes','_flightTime'];
    private _rounds = _job # 6;
    private _fn_valid = {
        ((serverNamespace getVariable ['QS_artillerySupport_state',createHashMap]) getOrDefault ['epoch',-1]) isEqualTo _epoch &&
        {((_state get 'jobs') getOrDefault [_kind,[]]) isEqualTo _job} &&
        {call _fn_live} && {([_caller] call _fn_holder) isEqualTo _kind} &&
        {([_caller] call _fn_penalty) <= 1} && {diag_tickTime < (_job # 2)}
    };
    private _fn_waitUntil = {
        params ['_when'];
        // The same guards run throughout each delay, including the announcement.
        // No per-client workers or uninterruptible long sleeps.
        while {call _fn_valid && {diag_tickTime < _when}} do {
            uiSleep (((_when - diag_tickTime) max 0) min 0.25);
        };
        call _fn_valid
    };
    if ([_announceAt] call _fn_waitUntil) then {
        // Do not emit a late announcement and then dump overdue rounds after a stall.
        private _latestAnnouncement = ((_job # 10) + 12.25) min (_announceAt + 1);
        if (diag_tickTime > _latestAnnouncement) then {_reason = 'Fire mission delayed. Unfired rounds returned.';} else {
            isNil {
                if (call _fn_valid) then {
                    _job set [7,createVehicle ['SmokeShellBlue',_target,[],0,'CAN_COLLIDE']];
                    private _roleName = ['Forward Observer','JTAC'] select (_kind isEqualTo 'JTAC');
                    private _payload = format ['%1 x %2',_rounds,_profile # 2];
                    ['sideChat',[WEST,'BLU'],format ['%1 Fire Mission requested at grid %2. Payload %3. Time to target %4 seconds.',
                        _roleName,mapGridPosition _target,_payload,ceil ((((_releaseTimes # 0) + _flightTime) - diag_tickTime) max 0)]] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
                };
            };
            for '_round' from 1 to _rounds do {
                private _releaseAt = _releaseTimes # (_round - 1);
                if (!([_releaseAt] call _fn_waitUntil)) exitWith {_reason = 'Fire mission cancelled. Unfired rounds returned.';};
                if (diag_tickTime > (_releaseAt + 0.5)) exitWith {_reason = 'Fire mission delayed. Unfired rounds returned.';};
                private _designation = [_caller,_target,_profile # 5] call _fn_aim;
                if (_designation isEqualTo []) exitWith {_reason = 'Designation lost. Unfired rounds returned.';};
                private _aim = _designation # 0;
                if ([_aim,call _fn_friendPositions,_dispersion] call _fn_dangerClose) exitWith {_reason = _danger;};
                if (_dispersion > 0) then {_aim = _aim getPos [sqrt (random 1) * _dispersion,random 360];};
                ([_aim,'SAFE'] call QS_fnc_inZone) params ['_inSafe','_level','_active'];
                if (_inSafe && {_active} && {_level > 1}) exitWith {_reason = localize 'STR_QS_Text_067';};
                private _released = FALSE;
                // Release and debit cannot be split by a scheduled cancellation.
                isNil {
                    if (call _fn_valid) then {
                        private _projectile = createVehicle [_ammo,_aim vectorAdd [0,0,_profile # 7],[],0,'CAN_COLLIDE'];
                        if (!isNull _projectile) then {
                            // Virtual fire still has a physical source for damage and Hit attribution.
                            _projectile setShotParents [_caller,_caller];
                            _projectile setVectorDirAndUp [[0,0,-1],[0,1,0]];
                            private _targetAccepted = TRUE;
                            if ((_profile # 5) isNotEqualTo 'NONE') then {
                                private _target = _designation # 1;
                                // New IR missiles can reject an already validated target on their first frame.
                                _targetAccepted = !isNull _target && {alive _target} && {_projectile setMissileTarget [_target,TRUE]};
                            };
                            if (_targetAccepted) then {
                                _projectile setVelocity [0,0,-(_profile # 8)];
                                _job set [6,(_job # 6) - 1];
                                _released = TRUE;
                            } else {
                                deleteVehicle _projectile;
                            };
                        };
                    };
                };
                if (!_released) exitWith {_reason = 'Fire mission cancelled. Unfired rounds returned.';};
                if (_round isEqualTo 1) then {
                    [_caller,format ['Fire mission firing. Estimated final impact in %1 seconds.',ceil ((_completeAt - diag_tickTime) max 0)]] call _fn_private;
                };
            };
            if ((_job # 6) isEqualTo 0 && {_reason isEqualTo ''}) then {
                if ([_completeAt] call _fn_waitUntil) then {
                    [_caller,'Fire mission complete. All requested ordnance dispatched.'] call _fn_private;
                } else {_reason = 'Fire mission closed. All requested ordnance was already dispatched.';};
            };
        };
    } else {_reason = 'Fire mission cancelled. Unfired rounds returned.';};
    if (((serverNamespace getVariable ['QS_artillerySupport_state',createHashMap]) getOrDefault ['epoch',-1]) isEqualTo _epoch &&
        {((_state get 'jobs') getOrDefault [_kind,[]]) isEqualTo _job}) then {
        isNil {
            [_job] call _fn_refund; [_job,FALSE] call _fn_clearJob;
            (_state get 'jobs') deleteAt _kind; call _fn_publish;
        };
        if (_reason isNotEqualTo '') then {[_caller,_reason] call _fn_private;};
    };
};
_job set [1,_worker];
};
isNil {_serverArgs call _fn_serverDispatch;};
// End Updated Code
