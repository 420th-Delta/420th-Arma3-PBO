/*
Native battery lifecycle test. Unrelated cosmetics, AI patrol management, reward
delivery and targeting registration are stubbed and restored. Vehicle/crew/unit
creation, safe-site search, composition mapping, ammunition and mission lifecycle
execute the production functions against real Altis terrain and game classes.
*/
private _saved = [];
{
	_saved pushBack [_x,missionNamespace getVariable [_x,nil]];
} forEach [
	'QS_system_AI_owners','QS_AI_vehicles','QS_garbageCollector','QS_hashmap_simpleObjectInfo','QS_core_vehicles_map',
	'QS_priorityAA_abort','QS_priorityAA_success','QS_priorityAA_instanceId','QS_priorityAA_spawnedInstance',
	'QS_priorityAA_position','QS_priorityAA_assets','QS_missionConfig_priorityAA_aoDistance',
	'QS_missionConfig_priorityAA_baseDistance','QS_missionConfig_priorityAA_satelliteCount','QS_missionConfig_priorityAA_satelliteDistance'
];
private _stub = {
	params ['_name','_code'];
	_saved pushBack [_name,missionNamespace getVariable [_name,nil]];
	missionNamespace setVariable [_name,_code];
};
{
	[_x,{}] call _stub;
} forEach [
	'QS_fnc_setCollectible','QS_fnc_serverSetAISkill','QS_fnc_taskPatrol',
	'QS_fnc_garrisonUnits','QS_fnc_AIXDismountDisabled','QS_fnc_vKilled2',
	'QS_fnc_vSetup2','QS_fnc_taskPatrolVehicle','QS_fnc_perfEnd'
];
['QS_fnc_unitSetup',{_this}] call _stub;
['QS_fnc_perfBegin',{diag_tickTime}] call _stub;
T420_AA_batteryRegistered = [];
['QS_fnc_airDefenseRegister',{
	params ['_vehicle',['_register',TRUE]];
	if (_register) then {
		T420_AA_batteryRegistered pushBackUnique _vehicle;
	} else {
		T420_AA_batteryRegistered = T420_AA_batteryRegistered - [_vehicle];
	};
}] call _stub;
T420_AA_batteryDebriefs = [];
['QS_fnc_priorityAADebrief',{
	params ['_result','_position','_context'];
	T420_AA_batteryDebriefs pushBack [_result,+_position,+_context];
	_context params ['_task','_marker','_circle'];
	[_task] call BIS_fnc_deleteTask;
	deleteMarker _marker;
	deleteMarker _circle;
}] call _stub;
QS_system_AI_owners = [2];
QS_AI_vehicles = [];
QS_garbageCollector = [];
QS_hashmap_simpleObjectInfo = createHashMap;
QS_core_vehicles_map = createHashMap;
QS_priorityAA_abort = FALSE;
QS_priorityAA_success = FALSE;
QS_missionConfig_priorityAA_aoDistance = [1200,3500];
QS_missionConfig_priorityAA_baseDistance = 5000;
QS_missionConfig_priorityAA_satelliteCount = 2;
QS_missionConfig_priorityAA_satelliteDistance = [50,200];
private _aoPosition = [22000,21000,0];
private _start = diag_tickTime;
private _site = [_aoPosition,_start + 15] call QS_fnc_priorityAAFindSite;
[(diag_tickTime - _start) < 17,'battery.site_search_bounded',diag_tickTime - _start] call T420_AA_fnc_assert;
[(count _site) isEqualTo 4,'battery.real_altis_site_found',_site] call T420_AA_fnc_assert;
private _timeoutStart = diag_tickTime;
private _expired = [_aoPosition,_timeoutStart - 1] call QS_fnc_priorityAAFindSite;
[_expired isEqualTo [] && {(diag_tickTime - _timeoutStart) < 1},'battery.expired_search_has_no_fallback',_expired] call T420_AA_fnc_assert;
if (_site isNotEqualTo []) then {
	_site params ['_center','_satellites','_vehiclePositions','_direction'];
	private _base = markerPos 'QS_marker_base_marker';
	private _aoRange = _center distance2D _aoPosition;
	[_aoRange >= 1200 && {_aoRange <= 5000},'battery.site_is_ao_relative_with_bounded_wider_fallback',_aoRange] call T420_AA_fnc_assert;
	[(_center distance2D _base) >= 5032,'battery.full_site_respects_base_exclusion',_center distance2D _base] call T420_AA_fnc_assert;
	[(count _satellites) isEqualTo 2 && {(count _vehiclePositions) isEqualTo 3},'battery.site_reserves_all_assets'] call T420_AA_fnc_assert;
	[(_satellites findIf {(_x distance2D _center) < 50 || {(_x distance2D _center) > 200}}) isEqualTo -1,'battery.satellites_outside_perimeter',_satellites] call T420_AA_fnc_assert;
	private _footprints = [[_center,32]] + (_satellites apply {[_x,12]}) + (_vehiclePositions apply {[_x,9]});
	private _clear = TRUE;
	{
		_x params ['_point','_radius'];
		if (surfaceIsWater _point || {(_point isFlatEmpty [_radius,0,0.2,_radius,0,FALSE,objNull]) isEqualTo []}) then {_clear = FALSE};
		for '_otherIndex' from 0 to (_forEachIndex - 1) do {
			private _other = _footprints # _otherIndex;
			if ((_point distance2D (_other # 0)) < (_radius + (_other # 1) + 5)) then {_clear = FALSE};
		};
	} forEach _footprints;
	[_clear,'battery.whole_footprints_clear_and_separated',_footprints] call T420_AA_fnc_assert;

	// Reuse the engine-validated site, isolating lifecycle tests from random search.
	T420_AA_batterySite = _site;
	['QS_fnc_priorityAAFindSite',{+T420_AA_batterySite}] call _stub;
	private _ordinaryPosition = markerPos 'QS_marker_sideMarker';
	private _ordinaryText = markerText 'QS_marker_sideMarker';
	private _ordinarySuccess = missionNamespace getVariable ['QS_smSuccess',FALSE];
	private _ordinaryAbort = missionNamespace getVariable ['QS_smAbort',FALSE];
	private _allOwned = [];
	for '_scenario' from 0 to 1 do {
		private _instance = format ['fixture_%1',_scenario];
		QS_priorityAA_instanceId = _instance;
		QS_priorityAA_abort = FALSE;
		QS_priorityAA_success = FALSE;
		QS_priorityAA_spawnedInstance = '';
		QS_priorityAA_position = [];
		QS_garbageCollector = [];
		private _script = [_instance,_aoPosition] spawn QS_fnc_SMpriorityAA;
		private _spawnDeadline = diag_tickTime + 20;
		waitUntil {uiSleep 0.1; (QS_priorityAA_spawnedInstance isEqualTo _instance) || {scriptDone _script} || {diag_tickTime > _spawnDeadline}};
		private _spawned = QS_priorityAA_spawnedInstance isEqualTo _instance;
		[_spawned,format ['battery.instance_%1_spawned',_scenario]] call T420_AA_fnc_assert;
		private _assets = +(missionNamespace getVariable ['QS_priorityAA_assets',[]]);
		private _groups = (_assets select {_x isKindOf 'CAManBase'}) apply {group _x};
		_allOwned append (_assets + _groups);
		if (_spawned) then {
			private _launchers = _assets select {(typeOf _x) isEqualTo 'O_SAM_System_04_F'};
			private _radars = _assets select {(typeOf _x) isEqualTo 'O_Radar_System_02_F'};
			private _mobile = _assets select {(typeOf _x) isEqualTo 'O_APC_Tracked_02_AA_F'};
			private _tanks = _assets select {(typeOf _x) isEqualTo 'O_MBT_02_cannon_F'};
			private _infantry = _assets select {_x isKindOf 'CAManBase' && {isNull objectParent _x}};
			[(count _launchers) isEqualTo 3 && {(count _radars) isEqualTo 1},'battery.exact_rhea_cronus_count',[count _launchers,count _radars]] call T420_AA_fnc_assert;
			private _circle = format ['QS_marker_priorityAACircle_%1',_instance];
			[((_launchers + _radars) findIf {(_x distance2D (markerPos _circle)) + 12 > ((markerSize _circle) # 0)}) isEqualTo -1,'battery.search_area_contains_all_required_platforms'] call T420_AA_fnc_assert;
			[(count _mobile) isEqualTo 2 && {(count _tanks) isEqualTo 1},'battery.required_mobile_guard_count',[count _mobile,count _tanks]] call T420_AA_fnc_assert;
			[((_mobile + _tanks) findIf {!alive driver _x}) isEqualTo -1,'battery.guards_have_live_drivers'] call T420_AA_fnc_assert;
			[(count _infantry) >= 24 && {(count _infantry) <= 48},'battery.usual_infantry_count',count _infantry] call T420_AA_fnc_assert;
			[(_infantry findIf {((toLowerANSI typeOf _x) find 'o_v_soldier_') isNotEqualTo 0}) isEqualTo -1,'battery.all_foot_guards_are_vipers',_infantry apply {typeOf _x}] call T420_AA_fnc_assert;
			[(count (_launchers select {(_x distance2D _center) < 20})) isEqualTo 1,'battery.one_internal_launcher'] call T420_AA_fnc_assert;
			private _walls = _assets select {isSimpleObject _x};
			private _gateClear = TRUE;
			{
				private _gateStart = (_center getPos [28,_direction + 180]) getPos [abs _x,_direction + ([270,90] select (_x >= 0))];
				private _gateEnd = (_center getPos [20,_direction + 180]) getPos [abs _x,_direction + ([270,90] select (_x >= 0))];
				_gateStart set [2,1];
				_gateEnd set [2,1];
				private _hits = lineIntersectsSurfaces [AGLToASL _gateStart,AGLToASL _gateEnd,objNull,objNull,TRUE,-1,'GEOM','NONE'];
				if ((_hits findIf {(_x # 2) in _walls}) isNotEqualTo -1) then {_gateClear = FALSE};
			} forEach [-4,0,4];
			[_gateClear,'battery.vehicle_width_entrance_clear'] call T420_AA_fnc_assert;
			[(markerPos 'QS_marker_sideMarker') isEqualTo _ordinaryPosition && {(markerText 'QS_marker_sideMarker') isEqualTo _ordinaryText},'battery.ordinary_marker_unchanged'] call T420_AA_fnc_assert;
			if (_scenario isEqualTo 0 && {(count _launchers) isEqualTo 3} && {(count _radars) isEqualTo 1}) then {
				private _launcher = _launchers # 0;
				{_x setMagazineTurretAmmo ['magazine_Missile_s750_x4',0,[0]]} forEach _launchers;
				[(_launcher magazineTurretAmmo ['FakeWeapon',[-1]]) > 0,'battery.missile_depletion_preserves_uav_fake_magazine',magazinesAllTurrets _launcher] call T420_AA_fnc_assert;
				private _emptyAt = diag_tickTime;
				uiSleep 12;
				[(_launchers findIf {(_x magazineTurretAmmo ['magazine_Missile_s750_x4',[0]]) > 0}) isEqualTo -1,'battery.rearm_is_delayed'] call T420_AA_fnc_assert;
				waitUntil {uiSleep 0.25; (_launchers findIf {(_x magazineTurretAmmo ['magazine_Missile_s750_x4',[0]]) isEqualTo 0}) isEqualTo -1 || {diag_tickTime > (_emptyAt + 34)}};
				private _refillElapsed = diag_tickTime - _emptyAt;
				[(_launchers findIf {(_x magazineTurretAmmo ['magazine_Missile_s750_x4',[0]]) isEqualTo 0}) isEqualTo -1 && {_refillElapsed >= 15} && {_refillElapsed <= 34},'battery.all_launchers_refill_after_exhaustion',_refillElapsed] call T420_AA_fnc_assert;
				_launcher = _launchers # 2;
				_launcher setMagazineTurretAmmo ['magazine_Missile_s750_x4',0,[0]];
				_emptyAt = diag_tickTime;
				waitUntil {uiSleep 0.25; (_launcher magazineTurretAmmo ['magazine_Missile_s750_x4',[0]]) > 0 || {diag_tickTime > (_emptyAt + 34)}};
				[(_launcher magazineTurretAmmo ['magazine_Missile_s750_x4',[0]]) > 0 && {(diag_tickTime - _emptyAt) >= 15},'battery.satellite_refill_repeats',diag_tickTime - _emptyAt] call T420_AA_fnc_assert;
				(_radars # 0) setDamage [1,FALSE];
				uiSleep 2;
				[!scriptDone _script,'battery.radar_only_not_completion'] call T420_AA_fnc_assert;
				(_launchers # 0) setDamage [1,FALSE];
				(_launchers # 1) setDamage [1,FALSE];
				uiSleep 2;
				[!scriptDone _script,'battery.last_satellite_required'] call T420_AA_fnc_assert;
				(_launchers # 2) setDamage [1,FALSE];
			} else {
				QS_priorityAA_abort = TRUE;
			};
		};
		private _finishDeadline = diag_tickTime + 8;
		waitUntil {uiSleep 0.1; scriptDone _script || {diag_tickTime > _finishDeadline}};
		[scriptDone _script,format ['battery.instance_%1_exits',_scenario]] call T420_AA_fnc_assert;
		if (!scriptDone _script) then {terminate _script};
		private _expectedResult = [1,0] # _scenario;
		private _matchingDebrief = T420_AA_batteryDebriefs select {((_x # 2) # 3) isEqualTo _instance};
		[(count _matchingDebrief) isEqualTo 1 && {((_matchingDebrief # 0) # 0) isEqualTo _expectedResult},'battery.debrief_result_matches_lifecycle',_matchingDebrief] call T420_AA_fnc_assert;
		[QS_priorityAA_position isEqualTo [],'battery.active_position_cleared'] call T420_AA_fnc_assert;
		private _liveTigrises = _assets select {alive _x && {_x isKindOf 'O_APC_Tracked_02_AA_F'}};
		[(count _liveTigrises) isEqualTo 2 && {(_liveTigrises findIf {!(_x in T420_AA_batteryRegistered)}) isEqualTo -1},'battery.live_guard_targeting_remains_until_garbage_collection'] call T420_AA_fnc_assert;
		[((_assets select {_x isKindOf 'O_SAM_System_04_F'}) findIf {_x in T420_AA_batteryRegistered}) isEqualTo -1,'battery.objective_launchers_unregister_at_retirement'] call T420_AA_fnc_assert;
		private _retiredLaunchers = _assets select {alive _x && {(typeOf _x) isEqualTo 'O_SAM_System_04_F'}};
		{[_x] call QS_fnc_airDefenseRelease} forEach _retiredLaunchers;
		uiSleep 1;
		[(_retiredLaunchers findIf {((magazinesAllTurrets [_x,TRUE]) findIf {(_x # 2) > 0}) isNotEqualTo -1}) isEqualTo -1,'battery.retired_launchers_stay_empty_after_release'] call T420_AA_fnc_assert;
		[(QS_garbageCollector findIf {!((_x # 0) isEqualType objNull)}) isEqualTo -1,'battery.cleanup_contains_objects_not_turret_records'] call T420_AA_fnc_assert;
		[(_assets findIf {private _asset = _x; (QS_garbageCollector findIf {(_x # 0) isEqualTo _asset}) isEqualTo -1}) isEqualTo -1,'battery.every_owned_asset_queued_for_cleanup'] call T420_AA_fnc_assert;
		[(missionNamespace getVariable ['QS_smSuccess',FALSE]) isEqualTo _ordinarySuccess && {(missionNamespace getVariable ['QS_smAbort',FALSE]) isEqualTo _ordinaryAbort},'battery.ordinary_lifecycle_flags_unchanged'] call T420_AA_fnc_assert;
		[_assets + _groups] call T420_AA_fnc_cleanup;
	};
	[_allOwned] call T420_AA_fnc_cleanup;
};
{
	_x params ['_name'];
	missionNamespace setVariable [_name,_x # 1];
} forEach _saved;
TRUE
