/*
Legacy mission smoke: real original Tigris/barrier composition, crew, task and
abort cleanup. The unchanged guard generator, notification/reward effects and
position-search callback are isolated; callback arguments are verified below.
*/
private _saved = [];
private _stub = {
	params ['_name','_code'];
	_saved pushBack [_name,missionNamespace getVariable [_name,nil]];
	missionNamespace setVariable [_name,_code];
};
private _ordinaryMarkers = ['QS_marker_sideMarker','QS_marker_sideCircle'] apply {[_x,markerPos _x,markerText _x,markerAlpha _x]};
private _previousAbort = missionNamespace getVariable ['QS_smAbort',FALSE];
private _previousSuccess = missionNamespace getVariable ['QS_smSuccess',FALSE];
private _previousVehicles = +(missionNamespace getVariable ['QS_AI_vehicles',[]]);
private _previousGarbage = +(missionNamespace getVariable ['QS_garbageCollector',[]]);
QS_AI_vehicles = [];
QS_garbageCollector = [];
QS_hashmap_simpleObjectInfo = createHashMap;
QS_core_vehicles_map = createHashMap;
QS_priorityAA_legacyActive = FALSE;
QS_smAbort = FALSE;
QS_smSuccess = FALSE;
private _base = markerPos 'QS_marker_base_marker';
private _position = [];
private _searchUntil = diag_tickTime + 10;
for '_attempt' from 1 to 200 do {
	if (diag_tickTime >= _searchUntil) exitWith {};
	private _candidate = _base getPos [2200 + random 2200,random 360];
	if (
		!surfaceIsWater _candidate &&
		{(_candidate isFlatEmpty [20,0,0.2,20,0,FALSE,objNull]) isNotEqualTo []} &&
		{(_candidate nearRoads 25) isEqualTo []} &&
		{(_candidate distance2D (missionNamespace getVariable 'QS_AOpos')) > 500} &&
		{(_candidate distance2D (markerPos 'QS_marker_module_fob')) > 250} &&
		{!([_candidate,30,8] call QS_fnc_waterInRadius)}
	) exitWith {_position = _candidate};
};
[_position isNotEqualTo [],'legacy.real_safe_candidate_in_original_base_window',_position] call T420_AA_fnc_assert;
T420_AA_legacyPosition = _position;
T420_AA_legacyPositionCalls = [];
T420_AA_legacyGuardCalls = [];
T420_AA_legacyDebriefs = [];
T420_AA_legacyRegistered = [];
T420_AA_legacyComposition = [];
T420_AA_legacyMapper = QS_fnc_serverObjectsMapper;
['QS_fnc_findRandomPos',{
	T420_AA_legacyPositionCalls pushBack +_this;
	+T420_AA_legacyPosition
}] call _stub;
['QS_fnc_smEnemyEast',{
	T420_AA_legacyGuardCalls pushBack +_this;
	[]
}] call _stub;
['QS_fnc_serverObjectsMapper',{
	private _objects = _this call T420_AA_legacyMapper;
	T420_AA_legacyComposition append _objects;
	_objects
}] call _stub;
['QS_fnc_smDebrief',{
	T420_AA_legacyDebriefs pushBack +_this;
	['QS_IA_TASK_SM_0'] call BIS_fnc_deleteTask;
}] call _stub;
['QS_fnc_airDefenseRegister',{
	params ['_vehicle',['_register',TRUE]];
	if (_register) then {T420_AA_legacyRegistered pushBackUnique _vehicle};
}] call _stub;
['QS_fnc_perfBegin',{diag_tickTime}] call _stub;
['QS_fnc_perfEnd',{}] call _stub;
if (_position isNotEqualTo []) then {
	private _script = [] spawn QS_fnc_SMpriorityAALegacy;
	private _spawnDeadline = diag_tickTime + 15;
	waitUntil {uiSleep 0.1; (['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists) || {scriptDone _script} || {diag_tickTime >= _spawnDeadline}};
	[QS_priorityAA_legacyActive && {!scriptDone _script},'legacy.active_flag_claims_ordinary_channel'] call T420_AA_fnc_assert;
	private _hulls = T420_AA_legacyComposition select {(typeOf _x) isEqualTo 'O_APC_Tracked_02_AA_F'};
	[(count _hulls) isEqualTo 2,'legacy.exact_original_two_tigrises',T420_AA_legacyComposition apply {typeOf _x}] call T420_AA_fnc_assert;
	[(_hulls findIf {alive driver _x || {!alive gunner _x}}) isEqualTo -1,'legacy.original_fixed_tigris_crew_layout'] call T420_AA_fnc_assert;
	[(T420_AA_legacyComposition findIf {(typeOf _x) in ['O_SAM_System_04_F','O_Radar_System_02_F']}) isEqualTo -1,'legacy.no_enhanced_radar_or_sam'] call T420_AA_fnc_assert;
	[(count T420_AA_legacyPositionCalls) > 0 && {private _call = T420_AA_legacyPositionCalls # 0; (_call # 0) isEqualTo 'RADIUS' && {(_call # 1) isEqualTo _base} && {(_call # 2) isEqualTo 4500}},'legacy.original_base_centered_search_arguments',T420_AA_legacyPositionCalls] call T420_AA_fnc_assert;
	[(_position distance2D _base) > 2000 && {(_position distance2D _base) <= 4500},'legacy.original_spawn_distance_window',_position distance2D _base] call T420_AA_fnc_assert;
	[(count T420_AA_legacyGuardCalls) isEqualTo 1 && {(count (T420_AA_legacyGuardCalls # 0)) isEqualTo 1},'legacy.uses_ordinary_guard_default_without_viper_preset',T420_AA_legacyGuardCalls] call T420_AA_fnc_assert;
	[(['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists) && {(markerAlpha 'QS_marker_sideMarker') isEqualTo 1},'legacy.uses_ordinary_task_and_markers'] call T420_AA_fnc_assert;
	[(_hulls findIf {!(_x in T420_AA_legacyRegistered)}) isEqualTo -1,'legacy.tigrises_use_shared_targeting_registration'] call T420_AA_fnc_assert;
	private _owned = +T420_AA_legacyComposition;
	// TRUE task owners resolve to players. Give the existing task a real local
	// observer for native deletion in this otherwise playerless dedicated fixture.
	private _observerGroup = createGroup [WEST,TRUE];
	private _observer = _observerGroup createUnit ['B_Soldier_F',_base,[],0,'NONE'];
	_observer enableSimulationGlobal FALSE;
	_owned append [_observer,_observerGroup];
	['QS_IA_TASK_SM_0',_observer,[localize 'STR_QS_Task_094_Legacy',localize 'STR_QS_Task_095',''],markerPos 'QS_marker_sideMarker','CREATED',5,FALSE,TRUE,'destroy',TRUE] call BIS_fnc_setTask;
	{
		_owned append crew _x;
		_owned pushBack group gunner _x;
		_x setVariable ['QS_airDefense_savedCrew',[[gunner _x,TRUE,TRUE,'RED']],TRUE];
	} forEach _hulls;
	QS_smAbort = TRUE;
	private _abortDeadline = diag_tickTime + 8;
	waitUntil {uiSleep 0.1; scriptDone _script || {diag_tickTime >= _abortDeadline}};
	[scriptDone _script && {!QS_priorityAA_legacyActive},'legacy.abort_clears_active_flag'] call T420_AA_fnc_assert;
	if (!scriptDone _script) then {terminate _script};
	uiSleep 0.25;
	[(count T420_AA_legacyDebriefs) isEqualTo 1 && {((T420_AA_legacyDebriefs # 0) # 0) isEqualTo 0},'legacy.abort_uses_ordinary_debrief',T420_AA_legacyDebriefs] call T420_AA_fnc_assert;
	private _taskDeadline = diag_tickTime + 5;
	waitUntil {uiSleep 0.1; !(['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists) || {diag_tickTime >= _taskDeadline}};
	[!(['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists) && {(markerAlpha 'QS_marker_sideMarker') isEqualTo 0},'legacy.abort_removes_ordinary_task_and_marker'] call T420_AA_fnc_assert;
	[(QS_garbageCollector findIf {!((_x # 0) isEqualType objNull)}) isEqualTo -1,'legacy.cleanup_has_no_turret_records'] call T420_AA_fnc_assert;
	[(T420_AA_legacyComposition findIf {private _object = _x; (QS_garbageCollector findIf {(_x # 0) isEqualTo _object}) < 0}) < 0,'legacy.all_composition_objects_queued'] call T420_AA_fnc_assert;
	{[_x] call QS_fnc_airDefenseRelease} forEach _hulls;
	uiSleep 1;
	[(_hulls findIf {((magazinesAllTurrets _x) findIf {(_x # 2) > 0}) >= 0}) < 0,'legacy.retired_tigrises_stay_empty_after_late_release'] call T420_AA_fnc_assert;
	[_owned] call T420_AA_fnc_cleanup;
};
{
	_x params ['_name'];
	missionNamespace setVariable [_name,_x # 1];
} forEach _saved;
{
	_x params ['_marker','_position','_text','_alpha'];
	_marker setMarkerPos _position;
	_marker setMarkerText _text;
	_marker setMarkerAlpha _alpha;
} forEach _ordinaryMarkers;
QS_smAbort = _previousAbort;
QS_smSuccess = _previousSuccess;
QS_AI_vehicles = _previousVehicles;
QS_garbageCollector = _previousGarbage;
TRUE
