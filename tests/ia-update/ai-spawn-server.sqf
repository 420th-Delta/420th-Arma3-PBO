// execVM from the native harness. No production scripts are patched for tests.
private _started = diag_tickTime;
private _anchor = [];
{
	QS_groundSpawn_claims = [];
	private _slots = ['SLOTS',_x,12,0,'O_Soldier_F',TRUE,FALSE,-1,{TRUE}] call QS_fnc_spawnGroup;
	if (count _slots isEqualTo 12) exitWith {_anchor = _x;};
} forEach [missionNamespace getVariable ['IA_spawn_anchor',[14100,16200,0]],[14000,16200,0],[13900,16100,0]];
['spawn_fixture_terrain',_anchor isNotEqualTo [],[_anchor]] call IA_fnc_assert;
if (_anchor isEqualTo []) exitWith {[] call IA_fnc_finish;};
QS_groundSpawn_claims = [];
['spawn_test_dependencies',['production placement/helicopter/controller/cleanup; inert loadout, unit setup and AI task dispatch']] call IA_fnc_log;

private _fn_separated = {
	params ['_points'];
	private _ok = TRUE;
	{
		private _point = _x;
		if (((_points select [_forEachIndex + 1]) findIf {(_point distance2D _x) < 14.99}) >= 0) exitWith {_ok = FALSE;};
	} forEach _points;
	_ok
};
private _fn_deleteGroup = {
	params ['_group'];
	{deleteVehicle _x;} forEach units _group;
	deleteGroup _group;
};
private _syntheticPlayer = _anchor vectorAdd [-250,-250,0];
private _syntheticBase = _anchor vectorAdd [-850,-850,0];
private _validatorScheduled = [];
private _fn_boundary = {
	params ['_point'];
	_validatorScheduled pushBack canSuspend;
	(_point distance2D _syntheticPlayer) > 350 && {(_point distance2D _syntheticBase) > 1200}
};
private _slots = ['SLOTS',_anchor,12,0,'O_Soldier_F',TRUE,FALSE,-1,_fn_boundary] call QS_fnc_spawnGroup;
['spawn_actual_slots_keep_boundaries',count _slots isEqualTo 12 && {(_slots findIf {!([_x] call _fn_boundary)}) < 0},[_slots]] call IA_fnc_assert;
['spawn_full_squad_separation',[_slots] call _fn_separated,[count _slots]] call IA_fnc_assert;
['spawn_terrain_search_can_suspend',_validatorScheduled isNotEqualTo [] && {(_validatorScheduled findIf {!_x}) < 0},[count _validatorScheduled]] call IA_fnc_assert;

// A complete rejected footprint leaves no group or units; an existing group
// also remains intact. The caller gets grpNull without losing its old roster.
private _groupsBefore = count allGroups;
['spawn_invalid_input_returns_null_group',isNull ([[],0,EAST,'ia_fixture_sentry',FALSE] call QS_fnc_spawnGroup),[]] call IA_fnc_assert;
private _rejected = [_anchor,0,EAST,'ia_fixture_squad',FALSE,grpNull,FALSE,TRUE,{FALSE}] call QS_fnc_spawnGroup;
['spawn_rejected_group_creates_nothing',isNull _rejected && {count allGroups isEqualTo _groupsBefore},[]] call IA_fnc_assert;
QS_groundSpawn_claims = [];
private _position = _anchor vectorAdd [200,0,0];
private _sentryTypes = ['ia_fixture_sentry',1];
private _legacy = call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-forest-guard-call.sqf';
private _before = +units _legacy;
_rejected = [_position,0,EAST,'ia_fixture_sentry',FALSE,_legacy,FALSE,TRUE,{FALSE}] call QS_fnc_spawnGroup;
['spawn_existing_group_rejection_preserves_members',isNull _rejected && {units _legacy isEqualTo _before},[count _before]] call IA_fnc_assert;
[_legacy] call _fn_deleteGroup;

// Exact legacy forest-objective call with all expanded cells reserved. This
// reproduces the imported helper's missing mandatory-guard regression.
_position = +_anchor;
private _blocked = [];
for '_x' from -50 to 50 step 5 do {for '_y' from -50 to 50 step 5 do {_blocked pushBack (_anchor vectorAdd [_x,_y,0]);};};
QS_groundSpawn_claims = [[diag_tickTime + 20,+_anchor,+_blocked,FALSE]];
_legacy = call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-forest-guard-call.sqf';
['spawn_legacy_objective_guards_ignore_expanded_rejection',!isNull _legacy && {count units _legacy isEqualTo 2},[count units _legacy]] call IA_fnc_assert;
[_legacy] call _fn_deleteGroup;
if (fileExists 'tests\ai-spawn-baseline\spawnGroup.sqf') then {
	private _fixed = QS_fnc_spawnGroup;
	QS_fnc_spawnGroup = compile preprocessFileLineNumbers 'tests\ai-spawn-baseline\spawnGroup.sqf';
	_legacy = call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-forest-guard-call.sqf';
	['spawn_baseline_reproduces_missing_objective_guards',isNull _legacy,[count units _legacy]] call IA_fnc_assert;
	[_legacy] call _fn_deleteGroup;
	QS_fnc_spawnGroup = _fixed;
};

// Expired claims must not continue blocking this footprint.
QS_groundSpawn_claims = [[diag_tickTime - 1,+_anchor,+_blocked,FALSE]];
_slots = ['SLOTS',_anchor,12,0,'O_Soldier_F',TRUE,FALSE,-1,{TRUE}] call QS_fnc_spawnGroup;
['spawn_expired_reservation_released',count _slots isEqualTo 12,[count _slots]] call IA_fnc_assert;

// Two scheduled requests complete one at a time at the claim commit. Their
// admitted layouts must not intersect even if both started from stale scans.
QS_groundSpawn_claims = [];
IA_spawn_results = [];
private _workers = [];
for '_index' from 1 to 2 do {
	_workers pushBack ([_anchor] spawn {
		params ['_anchor'];
		private _result = ['SLOTS',_anchor,8,0,'O_Soldier_F',TRUE,FALSE,-1,{uiSleep 0.001; TRUE}] call QS_fnc_spawnGroup;
		isNil {IA_spawn_results pushBack _result;};
	});
};
waitUntil {uiSleep 0.05; (_workers findIf {!scriptDone _x}) < 0};
private _joined = [];
{_joined append _x;} forEach IA_spawn_results;
['spawn_concurrent_reservations_do_not_overlap',count IA_spawn_results isEqualTo 2 && {count _joined >= 8} && {[_joined] call _fn_separated},IA_spawn_results apply {count _x}] call IA_fnc_assert;

// Insert a competing claim after terrain evaluation starts but before this
// request can commit. The final atomic validation must reject stale slots.
QS_groundSpawn_claims = [];
private _injected = FALSE;
_slots = ['SLOTS',_anchor,2,0,'O_Soldier_F',TRUE,FALSE,-1,{
	if (!_injected) then {_injected = TRUE; QS_groundSpawn_claims = [[diag_tickTime + 20,+_anchor,+_blocked,FALSE]];};
	TRUE
}] call QS_fnc_spawnGroup;
['spawn_stale_candidates_rejected',_slots isEqualTo [],[]] call IA_fnc_assert;

// Exact ROTARY worker branch (population admission/task dispatch are stubs),
// actual helicopter spawner, actual STOP, actual Classic native retirement.
private _fn_register = compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-register.sqf';
private _fn_track = compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-track.sqf';
private _fn_rotary = compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-rotary.sqf';
private _fn_admit = {TRUE};
private _fn_activate = {};
private _goal = +_anchor;
private _key = 'FINAL';
private _state = createHashMapFromArray [
	['epoch',91],['entities',[]],['men',[]],['initial',[]],['seen',[]],['nodes',[]],
	['worker',scriptNull],['fireHandle',scriptNull],['air',[]],['mortarMarkers',[]],['used',0],['vehicleUsed',0],['reserved',4]
];
QS_primaryPressure_state = _state;
call _fn_rotary;
private _owned = +(_state get 'entities');
private _planes = _owned select {_x isKindOf 'Helicopter'};
private _aircrew = _owned select {_x isKindOf 'CAManBase'};
['rotary_worker_registers_aircraft_and_crew',count _planes isEqualTo 1 && {count _aircrew > 0} && {count _owned isEqualTo count (_state get 'initial')},[count _planes,count _aircrew,count _owned]] call IA_fnc_assert;
if (_planes isNotEqualTo [] && {_aircrew isNotEqualTo []}) then {
	private _aircraft = _planes # 0;
	_aircraft setVariable ['QS_primaryAO_exempt',TRUE];
	if (fileExists 'tests\ai-spawn-baseline\stop-entity-selection.sqf') then {
		private _fn_exempt = compile preprocessFileLineNumbers 'tests\ai-spawn-baseline\stop-exempt.sqf';
		private _baselineStop = compile preprocessFileLineNumbers 'tests\ai-spawn-baseline\stop-entity-selection.sqf';
		private _unsafe = [_state,_fn_exempt] call _baselineStop;
		['rotary_baseline_reproduces_exempt_hull_crew_cleanup',count _unsafe isEqualTo count _aircrew,[count _unsafe,count _aircrew]] call IA_fnc_assert;
	};
	private _protected = ['STOP'] call QS_fnc_aoPressure;
	['rotary_exempt_hull_preserves_crew',_protected isEqualTo [],[count _protected]] call IA_fnc_assert;
	_aircraft setVariable ['QS_primaryAO_exempt',FALSE];
	(_aircrew # 0) setVariable ['QS_primaryAO_exempt',TRUE];
	QS_primaryPressure_state = _state;
	_protected = ['STOP'] call QS_fnc_aoPressure;
	['rotary_exempt_crew_preserves_aircraft',_protected isEqualTo [],[count _protected]] call IA_fnc_assert;
	(_aircrew # 0) setVariable ['QS_primaryAO_exempt',FALSE];
	QS_primaryPressure_state = _state;
};
private _QS_module_classic_enemy_0 = ['STOP'] call QS_fnc_aoPressure;
['rotary_stop_returns_owned_roster',count _QS_module_classic_enemy_0 isEqualTo count _owned && {(_owned findIf {!(_x in _QS_module_classic_enemy_0)}) < 0},[count _QS_module_classic_enemy_0]] call IA_fnc_assert;
private _false = FALSE;
private _fn_serverObjectsRecycler = {FALSE};
call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-native-cleanup.sqf';
uiSleep 0.5;
call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-cas-provider-prune.sqf';
call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-intel-provider-prune.sqf';
['rotary_native_cleanup_retires_aircraft_and_crew',(_owned findIf {alive _x}) < 0 && {(_planes findIf {!(_x in QS_normalAO_deferredAIObjects)}) < 0},[count QS_normalAO_deferredAIObjects]] call IA_fnc_assert;
['rotary_native_provider_prune',QS_AI_supportProviders_CASHELI isEqualTo [] && {QS_AI_supportProviders_INTEL isEqualTo []},[]] call IA_fnc_assert;
{deleteVehicleCrew _x; deleteVehicle _x;} forEach _planes;

// Pause the real spawner in a loadout dependency immediately after aircraft
// creation, then terminate through STOP. The aircraft must already be owned.
_state = createHashMapFromArray [
	['epoch',92],['entities',[]],['men',[]],['initial',[]],['seen',[]],['nodes',[]],
	['worker',scriptNull],['fireHandle',scriptNull],['air',[]],['mortarMarkers',[]],['used',0],['vehicleUsed',0],['reserved',4]
];
QS_primaryPressure_state = _state;
QS_fnc_vehicleLoadouts = {missionNamespace setVariable ['IA_spawn_heliPaused',TRUE]; uiSleep 30;};
IA_spawn_heliPaused = FALSE;
private _worker = [_state] spawn {
	params ['_state'];
	private _fn_register = compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-register.sqf';
	[0,_fn_register] call QS_fnc_scSpawnHeli;
};
_state set ['worker',_worker];
private _deadline = diag_tickTime + 15;
waitUntil {uiSleep 0.05; IA_spawn_heliPaused || {scriptDone _worker} || {diag_tickTime > _deadline}};
_owned = +(_state get 'entities');
_QS_module_classic_enemy_0 = ['STOP'] call QS_fnc_aoPressure;
['rotary_cancel_immediate_cleanup_owner',IA_spawn_heliPaused && {count _QS_module_classic_enemy_0 isEqualTo 1} && {_QS_module_classic_enemy_0 isEqualTo _owned},[IA_spawn_heliPaused,count _owned,count _QS_module_classic_enemy_0]] call IA_fnc_assert;
// terminate takes effect when the scheduler next processes the target script.
// Ownership must be returned immediately; stopped execution is observed later.
_deadline = diag_tickTime + 2;
waitUntil {uiSleep 0.05; scriptDone _worker || {diag_tickTime > _deadline}};
['rotary_cancel_during_creation_keeps_cleanup_owner',scriptDone _worker && {(_state get 'entities') isEqualTo _owned},[scriptDone _worker,count _owned,count (_state get 'entities')]] call IA_fnc_assert;
call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-native-cleanup.sqf';
{deleteVehicleCrew _x; deleteVehicle _x;} forEach _owned;
QS_fnc_vehicleLoadouts = {};
QS_groundSpawn_claims = [];
['spawn_suite_elapsed',[diag_tickTime - _started]] call IA_fnc_log;
[] call IA_fnc_finish;
