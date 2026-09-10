/*
Optional full-mission server driver. The artifact-only harness must set
IA_integrationCycle_allowed = TRUE and call this from scheduled code.
Returns Boolean and logs checks; the caller owns final harness completion.
Exercises forced Defense and cancellation, not objective victory or timeout.
*/
params [['_budget',660,[0]],['_observeDefense',90,[0]]];
if (!isServer || {!canSuspend} || {isNil 'IA_fnc_assert'} || {isNil 'IA_fnc_log'} ||
    {!(missionNamespace getVariable ['IA_integrationCycle_allowed',FALSE])}) exitWith {
    diag_log '[IA cycle] Requires the opted-in private full-mission server harness.';
    FALSE
};
private _finishBy = diag_tickTime + ((_budget max 300) min 900);
_observeDefense = (_observeDefense max 75) min 180;
private _allPassed = TRUE;
private _fn_assert = {
    params ['_label','_passed'];
    _allPassed = _allPassed && {_passed};
    _this call IA_fnc_assert;
};
private _nextLog = 0;
private _fn_snapshot = {
    params ['_phase'];
    private _humans = allPlayers select {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}};
    private _owners = [2] + (missionNamespace getVariable ['QS_headlessClients',[]]);
    private _pressure = missionNamespace getVariable ['QS_primaryPressure_state',createHashMap];
    private _support = serverNamespace getVariable ['QS_artillerySupport_state',createHashMap];
    ['cycle_snapshot',[_phase,diag_fps,time,count _humans,
        _humans apply {[netId _x,owner _x,alive _x,getPosATL _x]},
        _owners apply {private _ownerID = _x; [_ownerID,{owner _x isEqualTo _ownerID} count allUnits]},
        count allUnits,count allGroups,
        missionNamespace getVariable ['QS_megaDefense_core',[]],
        missionNamespace getVariable ['QS_megaDefense_state',[]],
        missionNamespace getVariable ['QS_classic_AI_active',FALSE],
        missionNamespace getVariable ['QS_classic_AI_triggerDeinit',FALSE],
        missionNamespace getVariable ['QS_primaryPressure_running',FALSE],
        missionNamespace getVariable ['QS_primaryPressure_groundCount',0],
        _pressure getOrDefault ['epoch',-1],_pressure getOrDefault ['used',0],
        _pressure getOrDefault ['reserved',0],count (_pressure getOrDefault ['initial',[]]),
        missionNamespace getVariable ['QS_defendActive',FALSE],
        missionNamespace getVariable ['QS_defendControl_epoch',-1],
        missionNamespace getVariable ['QS_defendControl_groundCount',0],
        _support getOrDefault ['kind',''],_support getOrDefault ['epoch',-1],
        keys (_support getOrDefault ['jobs',createHashMap])]] call IA_fnc_log;
};
private _fn_wait = {
    params ['_label','_condition','_seconds'];
    private _until = (diag_tickTime + _seconds) min _finishBy;
    while {!(call _condition) && {diag_tickTime < _until} &&
        {!(missionNamespace getVariable ['IA_abort',FALSE])}} do {
        if (diag_tickTime >= _nextLog) then {[_label] call _fn_snapshot; _nextLog = diag_tickTime + 5;};
        uiSleep 0.5;
    };
    private _passed = call _condition && {!(missionNamespace getVariable ['IA_abort',FALSE])};
    [_label,_passed,[diag_tickTime,_until]] call _fn_assert;
    _passed
};
private _fn_primaryReady = {
    private _core = missionNamespace getVariable ['QS_megaDefense_core',[]];
    private _support = serverNamespace getVariable ['QS_artillerySupport_state',createHashMap];
    private _pressureEpoch = missionNamespace getVariable ['QS_primaryPressure_epoch',-1];
    missionNamespace getVariable ['QS_mission_init',FALSE] &&
    {(missionNamespace getVariable ['QS_mission_aoType','']) isEqualTo 'CLASSIC'} &&
    {worldName isEqualTo 'Altis'} &&
    {(_core param [0,'']) isEqualTo 'PRIMARY'} &&
    {missionNamespace getVariable ['QS_classic_AI_active',FALSE]} &&
    {!(missionNamespace getVariable ['QS_classic_AI_triggerInit',FALSE])} &&
    {missionNamespace getVariable ['QS_primaryPressure_running',FALSE]} &&
    {count (missionNamespace getVariable ['QS_primaryPressure_state',createHashMap]) > 0} &&
    {(_support getOrDefault ['activity',[]]) isEqualTo ['PRIMARY',_pressureEpoch]} &&
    {!(missionNamespace getVariable ['QS_defendActive',FALSE])} &&
    {({isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}} count allPlayers) >= 1}
};
private _ready = ['cycle_primary_ready',_fn_primaryReady,240] call _fn_wait;
if (!_ready) exitWith {FALSE};
private _oldState = missionNamespace getVariable 'QS_primaryPressure_state';
private _oldEpoch = _oldState get 'epoch';
private _oldCoreEpoch = (missionNamespace getVariable 'QS_megaDefense_core') # 1;
private _oldWorker = _oldState get 'worker';
private _oldFire = _oldState get 'fireHandle';
private _oldSupportEpoch = (serverNamespace getVariable ['QS_artillerySupport_state',createHashMap]) getOrDefault ['epoch',-1];
private _oldHQ = (missionNamespace getVariable ['QS_aoHQ',[]]) select {_x isEqualType objNull && {!isNull _x}};
private _fn_geometryHits = {
    params ['_object','_rays'];
    if (isNull _object) exitWith {0};
    private _count = 0;
    {
        private _hits = lineIntersectsSurfaces [_x # 0,_x # 1,objNull,objNull,TRUE,20,'GEOM','NONE'];
        if ((_hits findIf {((_x # 2) isEqualTo _object) || {(_x # 3) isEqualTo _object}}) >= 0) then {
            _count = _count + 1;
        };
    } forEach _rays;
    _count
};
IA_cycleHQ_deleted = [];
private _beforeWorld = allMissionObjects 'All';
private _oldHQMetadata = [];
{
    private _object = _x;
    private _position = getPosWorld _object;
    private _rays = [];
    private _house = _object isKindOf 'House';
    if (_house) then {
        (boundingBoxReal _object) params ['_lo','_hi'];
        {
            private _fx = _x;
            {
                private _mx = (_lo # 0) + (((_hi # 0) - (_lo # 0)) * _fx);
                private _my = (_lo # 1) + (((_hi # 1) - (_lo # 1)) * _x);
                _rays pushBack [_object modelToWorldWorld [_mx,_my,(_hi # 2) + 2],
                    _object modelToWorldWorld [_mx,_my,(_lo # 2) - 2]];
            } forEach [0.2,0.5,0.8];
        } forEach [0.2,0.5,0.8];
        _object setVariable ['IA_cycleHQ_index',_forEachIndex];
        _object addEventHandler ['Deleted',{
            params ['_deleted'];
            private _index = _deleted getVariable ['IA_cycleHQ_index',-1];
            IA_cycleHQ_deleted pushBackUnique _index;
            ['cycle_hq_deleted_event',[_index]] call IA_fnc_log;
        }];
    };
    private _identity = netId _object;
    _oldHQMetadata pushBack [_identity,_position,_rays,_house,
        _object in _beforeWorld,_object in nearestObjects [ASLToAGL _position,[],50,TRUE],
        [_object,_rays] call _fn_geometryHits,
        !(_identity in ['','0:0']) && {(objectFromNetId _identity) isEqualTo _object}];
} forEach _oldHQ;
private _fn_hqPresence = {
    params ['_index'];
    private _object = _oldHQ # _index;
    (_oldHQMetadata # _index) params ['_identity','_position','_rays'];
    [isNull _object,owner _object,isNull objectFromNetId _identity,
        _object in allMissionObjects 'All',
        _object in nearestObjects [ASLToAGL _position,[],50,TRUE],
        [_object,_rays] call _fn_geometryHits,_index in IA_cycleHQ_deleted]
};
private _fn_hqRetired = {
    params ['_index'];
    private _object = _oldHQ # _index;
    if (isNull _object) exitWith {TRUE};
    (_oldHQMetadata # _index) params ['_identity','','','_house','_wasInWorld','_wasNear','_hadGeometry','_hadNetwork'];
    if (!_house || {!_wasInWorld} || {!_wasNear} || {_hadGeometry <= 0} || {!_hadNetwork} ||
        {owner _object isNotEqualTo 0} || {!(_index in IA_cycleHQ_deleted)} ||
        {!isNull objectFromNetId _identity}) exitWith {FALSE};
    private _presence = [_index] call _fn_hqPresence;
    !(_presence # 3) && {!(_presence # 4)} && {(_presence # 5) isEqualTo 0}
};
private _fn_hqDiagnostic = {
    params ['_phase'];
    {
        private _object = _x;
        private _details = if (isNull _object) then {[]} else {
            [str _object,netId _object,typeOf _object,owner _object,local _object,
                isSimpleObject _object,getObjectType _object,alive _object,getPosASL _object,
                getModelInfo _object,_object getVariable ['QS_cleanup_protected',FALSE],
                isNull attachedTo _object,count attachedObjects _object]
        };
        ['cycle_hq_object',[_phase,_forEachIndex,isNull _object,_details]] call IA_fnc_log;
        ['cycle_hq_presence',[_phase,_forEachIndex,
            (_oldHQMetadata # _forEachIndex) select [3,5],
            [_forEachIndex] call _fn_hqPresence]] call IA_fnc_log;
    } forEach _oldHQ;
};
['captured'] call _fn_hqDiagnostic;
private _oldTermination = missionNamespace getVariable ['QS_defend_terminate',FALSE];
['cycle_primary_native_roster',count (_oldState get 'initial') > 0,
    [count (_oldState get 'initial'),count (_oldState get 'entities'),_oldEpoch,count _oldHQ]] call _fn_assert;
['primary_before_request'] call _fn_snapshot;
private _requestControl = compile preprocessFileLineNumbers 'code\scripts\IA_MegaDefense.sqf';
private _request = ['START'] call _requestControl;
['cycle_request_accepted',(_request param [0,'']) isEqualTo 'FORCE_REQUESTED',_request] call _fn_assert;
if ((_request param [0,'']) isNotEqualTo 'FORCE_REQUESTED') exitWith {FALSE};
private _defenseReady = ['cycle_defense_ready',{
    missionNamespace getVariable ['QS_defendActive',FALSE] &&
    {missionNamespace getVariable ['QS_defendControl_active',FALSE]} &&
    {((missionNamespace getVariable ['QS_megaDefense_state',[]]) param [0,'']) isEqualTo 'RUNNING'}
},120] call _fn_wait;
if (!_defenseReady) exitWith {
    ['CANCEL'] call _requestControl;
    if (missionNamespace getVariable ['QS_defendActive',FALSE]) then {
        missionNamespace setVariable ['QS_defend_terminate',TRUE,FALSE];
    };
    FALSE
};
private _defenseEpoch = missionNamespace getVariable 'QS_defendControl_epoch';
private _defenseSupport = serverNamespace getVariable ['QS_artillerySupport_state',createHashMap];
private _defenseSupportEpoch = _defenseSupport getOrDefault ['epoch',-1];
['cycle_primary_released_before_defense',
    !(missionNamespace getVariable ['QS_classic_AI_active',FALSE]) &&
    {!(missionNamespace getVariable ['QS_classic_AI_triggerDeinit',FALSE])} &&
    {!(missionNamespace getVariable ['QS_primaryPressure_running',FALSE])} &&
    {count (missionNamespace getVariable ['QS_primaryPressure_state',createHashMap]) isEqualTo 0} &&
    {scriptDone _oldWorker} && {scriptDone _oldFire} &&
    {scriptDone (_oldState get 'worker')} && {scriptDone (_oldState get 'fireHandle')} &&
    {(_oldState get 'reserved') isEqualTo 0},
    [_oldEpoch,_defenseEpoch]] call _fn_assert;
['cycle_defense_support_started',(_defenseSupport getOrDefault ['kind','']) isEqualTo 'DEFENSE' &&
    {_defenseSupportEpoch > _oldSupportEpoch},[_oldSupportEpoch,_defenseSupportEpoch]] call _fn_assert;
private _defenseHQ = +(missionNamespace getVariable 'QS_HQpos');
private _beforeDefenseUnits = +allUnits;
private _seenNewHostiles = [];
private _newHostileRecords = [];
private _observedFrom = diag_tickTime;
private _observeUntil = (_observedFrom + _observeDefense) min _finishBy;
while {diag_tickTime < _observeUntil && {missionNamespace getVariable ['QS_defendActive',FALSE]} &&
    {missionNamespace getVariable ['QS_defendControl_active',FALSE]} &&
    {!(missionNamespace getVariable ['IA_abort',FALSE])}} do {
    {
        if (!(_x in _beforeDefenseUnits) && {!(_x in _seenNewHostiles)} && {alive _x} &&
            {(side group _x) in [EAST,RESISTANCE]} && {(_x distance2D _defenseHQ) < 2500}) then {
            _seenNewHostiles pushBack _x;
            _newHostileRecords pushBack [netId _x,typeOf _x,groupOwner group _x,getPosATL _x,diag_tickTime];
        };
    } forEach allUnits;
    ['defense_observation'] call _fn_snapshot;
    uiSleep 5;
};
// Proximity/new-object evidence is deliberately not labelled a Defense-owned roster:
// native Defense keeps _allArray private, and ambient creation can run concurrently.
['cycle_defense_observed',[diag_tickTime - _observedFrom,_newHostileRecords]] call IA_fnc_log;
if (missionNamespace getVariable ['QS_defendActive',FALSE] &&
    {(missionNamespace getVariable ['QS_defendControl_epoch',-1]) isEqualTo _defenseEpoch}) then {
    missionNamespace setVariable ['QS_defend_terminate',TRUE,FALSE];
    ['cycle_native_cancel_requested',[_defenseEpoch]] call IA_fnc_log;
};
private _nextPrimary = ['cycle_next_primary_ready',{
    call _fn_primaryReady &&
    {(missionNamespace getVariable ['QS_primaryPressure_epoch',-1]) > _oldEpoch} &&
    {((missionNamespace getVariable ['QS_megaDefense_core',[]]) param [1,-1]) > _oldCoreEpoch}
},180] call _fn_wait;
if (!_nextPrimary) exitWith {FALSE};
missionNamespace setVariable ['QS_defend_terminate',_oldTermination,FALSE];
private _nextSupport = serverNamespace getVariable ['QS_artillerySupport_state',createHashMap];
['cycle_defense_released',!(missionNamespace getVariable ['QS_defendControl_active',FALSE]) &&
    {(missionNamespace getVariable ['QS_megaDefense_state',[]]) isEqualTo []} &&
    {!(missionNamespace getVariable ['QS_megaDefense_pending',FALSE])}] call _fn_assert;
['cycle_next_primary_support_started',(_nextSupport getOrDefault ['kind','']) isEqualTo 'PRIMARY' &&
    {(_nextSupport getOrDefault ['epoch',-1]) > _defenseSupportEpoch},
    [_defenseSupportEpoch,_nextSupport getOrDefault ['epoch',-1]]] call _fn_assert;
private _hqClean = ['cycle_old_hq_cleanup',{
    private _retired = TRUE;
    {if (!([_forEachIndex] call _fn_hqRetired)) then {_retired = FALSE;};} forEach _oldHQ;
    _retired
},45] call _fn_wait;
['after_cleanup_wait'] call _fn_hqDiagnostic;
['cycle_completed'] call _fn_snapshot;
['cycle_result',[_allPassed,_oldEpoch,
    missionNamespace getVariable ['QS_primaryPressure_epoch',-1],_defenseEpoch]] call IA_fnc_log;
_allPassed
