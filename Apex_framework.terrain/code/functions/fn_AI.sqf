/*/
File: fn_AI.sqf
Author:

	Quiksilver
	
Last modified:

	9/10/2023 A3 2.14 by Quiksilver
	
Description:

	AI
	
Notes:

	For headless client,
	support providers need to remain on server
	fire support scripts var needs to be public
__________________________________________________/*/

scriptName 'QS AI';
if (hasInterface && !isDedicated) exitWith {};
// Added Code

// GROUND_TARGET_PRIORITY_BEGIN
// Shared ranking for deliberate ground responses. Physical sensing and ordinary
// weapon engagement remain native. Cache static configuration, never live crew.
missionNamespace setVariable ['QS_fnc_groundTargetPriority',{
	private _target = vehicle _this;
	if (isNull _target || {!alive _target} || {captive _target}) exitWith {-1};
	if (_target isKindOf 'CAManBase') exitWith {
		[-1,4] select ((side (group _target)) isEqualTo WEST && {lifeState _target in ['HEALTHY','INJURED']})
	};
	if (!(_target isKindOf 'LandVehicle') || {_target isKindOf 'StaticMortar'}) exitWith {-1};
	if ((crew _target findIf {alive _x && {!captive _x} && {(side (group _x)) isEqualTo WEST}}) < 0) exitWith {-1};
	private _class = typeOf _target;
	private _cache = missionNamespace getVariable ['QS_groundTargetPriority_types',createHashMap];
	private _cached = _cache getOrDefault [_class,-2];
	if (_cached >= -1) exitWith {_cached};
	private _cfg = configFile >> 'CfgVehicles' >> _class;
	// Only installed vehicle/turret weapons count; transported rifles/launchers
	// and crew backpacks cannot promote a transport into an AA battery.
	private _weapons = +getArray (_cfg >> 'weapons');
	private _turrets = configProperties [_cfg >> 'Turrets','isClass _x',TRUE];
	while {_turrets isNotEqualTo []} do {
		private _turret = _turrets deleteAt 0;
		{_weapons pushBackUnique _x;} forEach getArray (_turret >> 'weapons');
		_turrets append (configProperties [_turret >> 'Turrets','isClass _x',TRUE]);
	};
	private _mortar = (_weapons findIf {
		_x isKindOf ['mortar_82mm',configFile >> 'CfgWeapons'] ||
		{toLowerANSI (getText (configFile >> 'CfgWeapons' >> _x >> 'cursor')) isEqualTo 'mortar'}
	}) >= 0;
	private _aaRoots = ['B_APC_Tracked_01_AA_F','O_APC_Tracked_02_AA_F','LT_01_AA_base_F','StaticAAWeapon',
		'SAM_System_01_base_F','SAM_System_02_base_F','SAM_System_03_base_F','SAM_System_04_base_F','AAA_System_01_base_F',
		'us85_m163','gm_ge_army_gepard1a1','gm_gc_army_zsu234v1','vn_sa2'];
	private _aa = (_aaRoots findIf {_target isKindOf _x}) >= 0;
	if (!_aa && {!_mortar}) then {
		_aa = (_weapons findIf {
			(getArray (configFile >> 'CfgWeapons' >> _x >> 'magazines') findIf {
				getNumber (configFile >> 'CfgAmmo' >> getText (configFile >> 'CfgMagazines' >> _x >> 'ammo') >> 'airLock') >= 2
			}) >= 0
		}) >= 0;
		private _threat = getArray (_cfg >> 'threat');
		if (!_aa && {count _threat >= 3}) then {
			_aa = _weapons isNotEqualTo [] && {(_threat # 2) > 0.6} && {(_threat # 2) > (_threat # 0)} && {(_threat # 2) > (_threat # 1)};
		};
	};
	private _apcRoots = ['B_APC_Tracked_01_base_F','O_APC_Tracked_02_base_F','I_APC_Tracked_03_base_F',
		'APC_Tracked_01_base_F','APC_Tracked_02_base_F','APC_Tracked_03_base_F','LT_01_base_F',
		'vn_b_armor_m113_acav_02','csla_bpzv','csla_bvp1','us85_m113','gm_gc_army_bmp1sp2','gm_ge_army_marder1a2'];
	private _apc = (_apcRoots findIf {_target isKindOf _x}) >= 0 ||
		{toLowerANSI (getText (_cfg >> 'editorSubcategory')) isEqualTo 'edsubcat_apcs'};
	private _priority = if (_mortar) then {-1} else {
		if (_aa) then {0} else {
			if (getNumber (_cfg >> 'artilleryScanner') > 0) then {1} else {
				if (_target isKindOf 'Tank' && {!_apc}) then {2} else {3}
			}
		}
	};
	_cache set [_class,_priority];
	missionNamespace setVariable ['QS_groundTargetPriority_types',_cache,FALSE];
	_priority
},FALSE];
// GROUND_TARGET_PRIORITY_END

// PRIMARY_AO_CONTROLLER_BEGIN
missionNamespace setVariable ['QS_fnc_aoPressure',{
/*
 * PRIMARY AO: SUSTAINED REINFORCEMENTS AND OBJECTIVE DEFENSE
 * Replenish surviving objectives after casualties; lower the total force ceiling as objectives fall.
 * Parachutes show where fresh defenders are entering without extra transport traffic.
 * Final objective: stop creation and regroup surviving Primary forces around HQ.
 *
 * EXECUTION
 * INIT records this AO's objectives and units. TICK and AIR reuse the existing AI loop.
 * TICK chooses a shortfall and reserves capacity; one WORK script builds the delivery.
 * WORK yields between units and rechecks capacity, objectives and players after yields.
 * AIR handles landing/timeout cleanup independently of WORK, about every three seconds.
 * GROUP issues paced orders on the machine currently controlling the group (server/HC).
 * CLEAR checks all objectives, inbound troops and the 15-second low-enemy window.
 * STOP cancels creation and hands registered entities back to normal mission cleanup.
 * No new perpetual loop or per-unit scheduled monitor is added.
 *
 * CONTROLS
 * QS_primaryPressure_enabled: enable/disable from the next AO (default TRUE).
 * QS_primaryPressure_paused: pause new arrivals now (default FALSE).
 * Enabled by default only for Classic Altis. Other activities keep their normal path.
 */
params [['_mode','TICK']];

// POLICY_BEGIN: these exact policies are executed by the offline SQF tests.
private _fn_profile = {
	params ['_players'];
	// Batch, replacement safety ceiling, total AO personnel, seconds min/max,
	// HQ infantry target, live replacement vehicles, other-objective target.
	if (_players <= 0) exitWith {[0,0,0,0,0,0,0,0]};
	// Nearby conscious ground players select this profile. Squad size and
	// interval are paired; the interval is an opportunity, subject to all caps.
	// The busiest tier matches Defense's 6-10 s refill check; one worker and
	// the shared objective/FPS ceilings still gate actual deliveries.
	if (_players <= 2) exitWith {[8,24,24,480,600,8,0,8]};
	if (_players <= 8) exitWith {[8,40,40,480,600,12,0,8]};
	if (_players <= 15) exitWith {[8,64,64,120,180,20,1,12]};
	if (_players <= 30) exitWith {[10,96,96,30,60,32,2,20]};
	[12,120,120,6,10,40,3,24]
};
// No delivery quota while objectives remain: population spaces the opportunities.
// Objectives, personnel room and FPS still gate every arrival. Initial AI is unchanged.
// REGULAR SQUADS: reserve 8-12 men as one group; wait if fewer than eight fit.
// Transport pilots consume separate capacity. Combat can reduce a completed squad.
private _fn_squadSize = {
	params ['_preferred','_room','_deficit',['_crewSeats',0]];
	private _size = floor (12 min _preferred min (_room - _crewSeats) min _deficit);
	if (_size < 8) exitWith {0};
	_size
};
// Spread individual arrival/defense slots on an 18 m by 20 m pattern.
// Terrain checks may adjust slots; the objective object is not a shared unit position.
private _fn_slotPoint = {
	params ['_anchor','_index','_count','_heading'];
	private _across = ((_index mod 4) - 1.5) * 18;
	private _along = (floor (_index / 4) - ((ceil (_count / 4)) - 1) / 2) * 20;
	[(_anchor # 0) + cos _heading * _across + sin _heading * _along,
	 (_anchor # 1) - sin _heading * _across + cos _heading * _along,0]
};
private _fn_reactionOffset = {
	params ['_role','_anchor','_contact','_flank'];
	if (_role isNotEqualTo 'RESERVE' || {_contact isEqualTo []}) exitWith {[0,0,0]};
	private _range = _anchor distance2D _contact;
	if (_range < 60 || {_range > 250}) exitWith {[0,0,0]};
	// A perpendicular unit vector gives a lateral move without a chase goal.
	private _scale = 35 * ([1,-1] select _flank) / _range;
	[((_contact # 1) - (_anchor # 1)) * _scale,-((_contact # 0) - (_anchor # 0)) * _scale,0]
};
// Each completed strategic objective subtracts 20 percentage points.
// Keep a 20% floor while objectives remain; the last objective always returns zero.
private _fn_taper = {
	params ['_total','_completed'];
	if (_total <= 0 || {_completed >= _total}) exitWith {0};
	0.2 max (1 - 0.2 * (0 max _completed))
};
// The tightest live-replacement, area, server-local or global cap wins.
// Reserved seats already count, so two creation paths cannot spend the same room.
private _fn_room = {
	params ['_requested','_live','_liveCap','_area','_areaCap','_local','_localCap','_global','_globalCap','_reserved'];
	0 max (floor (_requested min (_liveCap - _live - _reserved) min (_areaCap - _area - _reserved) min (_localCap - _local - _reserved) min (_globalCap - _global - _reserved)))
};
// Finish only after all strategic objectives and inbound deliveries clear.
// Fewer than ten eligible enemies must persist for 15 s; a failed check resets it.
private _fn_clearPolicy = {
	params ['_now','_lowSince','_enemies','_threshold','_incoming','_objectivesDone'];
	if (_enemies >= _threshold || {_incoming} || {!_objectivesDone}) exitWith {[-1,FALSE,FALSE]};
	if (_lowSince < 0) then {_lowSince = _now;};
	[_lowSince,TRUE,(_now - _lowSince) >= 15]
};
// Pause new admissions below 18 FPS; require 30 s at 22+ FPS to resume.
// Separate stop/recovery thresholds prevent rapid on/off cycling near the limit.
private _fn_performance = {
	params ['_now','_fps','_wasOK','_healthySince'];
	if (_fps < 18) exitWith {[FALSE,-1]};
	if (_wasOK) exitWith {[TRUE,_healthySince]};
	if (_fps < 22) exitWith {[FALSE,-1]};
	if (_healthySince < 0) then {_healthySince = _now;};
	[(_now - _healthySince) >= 30,_healthySince]
};
// Capacity, rather than wave intervals, falls with objective progress.
private _fn_forceCap = {params ['_base','_factor']; floor (_base * _factor + 0.001)};
// Final reserves never refill the AO: at most three admissions, each behind
// a new 15% roll after 90-150 seconds. Starting clearance closes this channel.
private _fn_finalReady = {
	params ['_now','_next','_ground','_closed','_events','_roll',['_players',1e9]];
	_players > 15 && {_now >= _next} && {_ground >= 10} && {!_closed} && {_events < 3} && {_roll < 0.15}
};
private _fn_sniper = {
	params ['_class'];
	private _name = toLower _class;
	(_name find 'sniper') >= 0 || {(_name find 'ghillie') >= 0}
};
// Calibrate once from the first actual parachute group, then freeze the AO
// offset. Bound the horizontal shift; no in-flight steering or repeat tests.
private _fn_limit2D = {
	params ['_vector','_limit'];
	private _length = _vector distance2D [0,0,0];
	private _scale = if (_length > _limit) then {_limit / _length} else {1};
	[(_vector # 0) * _scale,(_vector # 1) * _scale,0]
};
private _fn_windOffset = {
	params ['_wind','_bias','_height'];
	private _seconds = 10 max (60 min (_height / 5));
	[(_wind vectorMultiply (0.35 * _seconds)) vectorAdd (_bias vectorMultiply _seconds),100] call _fn_limit2D
};
private _fn_windCalibrate = {
	params ['_samples','_fallback'];
	if (_samples isEqualTo []) exitWith {[_fallback,100] call _fn_limit2D};
	private _mean = [0,0,0];
	{_mean = _mean vectorAdd _x;} forEach _samples;
	[_mean vectorMultiply (1 / count _samples),100] call _fn_limit2D
};
// Primary commander support has a finite allowance, unlike infantry reserves.
// TUNING: below 25 connected players, three only. At 25+: 25% medium (six);
// above 30 connected WEST players, 15% hard (nine). Fire admission needs nine
// nearby conscious ground players; missed low-turnout windows never catch up.
// Remaining outcomes are normal (three). Roll and schedule once in INIT.
// These count fire missions; each retains the native physical artillery salvo.
private _fn_fireBudget = {
	params ['_players','_roll'];
	if (_players < 25) exitWith {3};
	if (_players > 30 && {_roll < 0.15}) exitWith {9};
	if (_roll < ([0.25,0.40] select (_players > 30))) exitWith {6};
	3
};
private _fn_firePlan = {
	params ['_start','_limit','_randoms'];
	private _width = 900 / _limit;
	private _windows = [];
	for '_i' from 0 to (_limit - 1) do {
		private _open = _start + _i * _width + _width * (0.2 + 0.4 * (_randoms # _i));
		_windows pushBack [_open,_open + 0.4 * _width];
	};
	_windows
};
// Each completed command link removes one third of the ORIGINAL allowance.
// Started missions count against the reduced total. Missing links cost nothing;
// clearing every actual strategic objective always cancels all unused missions.
// Example: 9 planned - 3 for one link = 6 total; if 6 started, none remain.
private _fn_fireLimit = {
	params ['_budget','_completedKeys',['_allDone',FALSE]];
	if (_allDone) exitWith {0};
	private _links = {_x in _completedKeys} count ['HQ','RADIOTOWER','INTEL'];
	(_budget / 3) * (3 - _links)
};
// Primary mortar salvos are capped after the native concentration bonus.
private _fn_mortarRounds = {params ['_players']; [4,6] select (_players >= 20)};
private _fn_reportFresh = {params ['_now','_seen','_maxAge']; _seen >= 0 && {_seen <= _now + 1} && {(_now - _seen) <= _maxAge}};
// One response squad per pair of observed casualties (one for a lone casualty),
// capped across the AO at 1/2/3 squads for <=15 / 16-30 / 31+ ground players.
private _fn_responseLimit = {
	params ['_players','_casualties'];
	if (_players <= 8 || {_casualties <= 0}) exitWith {0};
	private _cap = if (_players <= 15) then {1} else {[2,3] select (_players > 30)};
	_cap min (ceil (_casualties / 2))
};
// Record the incident once. Recovery, extraction, distance and time only end it;
// they never move the goal or generate another wave around the same casualty.
private _fn_responseActive = {
	params ['_now','_ends','_remaining','_final'];
	!_final && {_now < _ends} && {_remaining > 0}
};
// PRIMARY_CONTACT_POLICIES_BEGIN
// Whole mobile squads only. Rounding always retains at least 20% at defense;
// unfilled pressure/hunter places stay at defense instead of creating more AI.
private _fn_contactQuota = {
	params ['_count',['_players',1e9]];
	_count = 0 max floor _count;
	// At most one responding squad for a small assault force; no hunters.
	if (_players <= 8) exitWith {
		private _pressure = [0,1] select (_players > 0 && {_count >= 2});
		[_pressure,0,_count - _pressure]
	};
	private _reserve = ceil (_count * 0.2);
	private _hunters = (round (_count * 0.2)) min (_count - _reserve);
	[_count - _reserve - _hunters,_hunters,_reserve]
};
private _fn_contactLive = {
	params ['_clock','_ends','_seen','_valid','_final'];
	!_final && {_valid} && {_clock < _ends} && {_seen <= _clock + 1} && {(_clock - _seen) <= 75}
};
private _fn_contactObserve = {
	params ['_clock','_job','_reports','_valid','_final'];
	if (_reports isNotEqualTo []) then {
		_job set ['reports',_reports];
		_job set ['seen',selectMax (_reports apply {_x # 2})];
		if (count _reports >= 3) then {_job set ['cluster',TRUE];};
	};
	private _live = [_clock,_job get 'ends',_job get 'seen',_valid,_final] call _fn_contactLive;
	// Loss ends the incident permanently. A later sighting cannot restart it
	// during its cooldown, extend the original deadline or refund spent squads.
	if (!_live) then {_job set ['ends',_clock min (_job get 'ends')];};
	_live
};
// Compact reported positions around a fixed seed, never a growing chain of
// players. Each report occurs once; three known targets constitute a cluster.
private _fn_contactAreas = {
	params ['_reports'];
	private _ranked = [];
	{_ranked pushBack [_x param [3,4],_forEachIndex,_x];} forEach _reports;
	_ranked sort TRUE;
	private _remaining = (_ranked select [0,64]) apply {_x # 2};
	private _areas = [];
	for '_pass' from 1 to 6 do {
		if (_remaining isEqualTo []) exitWith {};
		private _best = []; private _focus = []; private _bestRank = 5;
		{
			private _point = _x # 1;
			private _near = _remaining select {((_x # 1) distance2D _point) <= 120};
			private _rank = _x param [3,4];
			if (_rank < _bestRank || {_rank isEqualTo _bestRank && {(count _near) > (count _best)}}) then {
				_best = _near; _focus = +_point; _bestRank = _rank;
			};
		} forEach _remaining;
		_areas pushBack [_focus,_best];
		_remaining = _remaining - _best;
	};
	_areas
};
// Shared admission for contact and casualty responses. Spent commitments do
// not fall when a squad dies: clearing the response creates breathing room.
private _fn_contactAdmission = {
	params ['_quota','_pressure','_hunters','_near','_advance','_support','_spent','_role',['_limit',3]];
	if ((_pressure + _hunters) >= ((_quota # 0) + (_quota # 1))) exitWith {FALSE};
	if (_role in ['ADVANCE','SUPPORT']) exitWith {
		_pressure < (_quota # 0) && {_near < 3} && {_spent < 3} &&
		{if (_role isEqualTo 'ADVANCE') then {_advance < 2} else {_support < 1}}
	};
	private _areaLimit = [1,_limit min 3] select (_role isEqualTo 'CONTEST');
	_hunters < (_quota # 1) && {_near < _areaLimit} && {_spent < _areaLimit}
};
// PRIMARY_CONTACT_POLICIES_END

// Skip reinforcement censuses until an arrival can actually be considered.
// The final phase still checks every pass so its closure cannot be delayed.
private _fn_arrivalDue = {
    params ['_now','_final','_infAllowed','_waveAt','_vehAllowed','_vehicleAt','_vehicleCap','_vehicleSecured'];
    _final || {_infAllowed && {_now >= _waveAt}} ||
    {_vehAllowed && {_vehicleCap > 0} && {!_vehicleSecured} && {_now >= _vehicleAt}}
};

// POLICY_END
if (_mode isEqualTo 'PROFILE') exitWith {(_this select [1,(count _this) - 1]) call _fn_profile};
if (_mode isEqualTo 'SQUAD_SIZE') exitWith {(_this select [1,(count _this) - 1]) call _fn_squadSize};
if (_mode isEqualTo 'SLOT_POINT') exitWith {(_this select [1,(count _this) - 1]) call _fn_slotPoint};
if (_mode isEqualTo 'REACTION_OFFSET') exitWith {(_this select [1,(count _this) - 1]) call _fn_reactionOffset};
if (_mode isEqualTo 'TAPER') exitWith {(_this select [1,(count _this) - 1]) call _fn_taper};
if (_mode isEqualTo 'ROOM') exitWith {(_this select [1,(count _this) - 1]) call _fn_room};
if (_mode isEqualTo 'CLEAR_POLICY') exitWith {(_this select [1,(count _this) - 1]) call _fn_clearPolicy};
if (_mode isEqualTo 'PERFORMANCE') exitWith {(_this select [1,(count _this) - 1]) call _fn_performance};

if (_mode isEqualTo 'RESPONSE_LIMIT') exitWith {(_this select [1,(count _this) - 1]) call _fn_responseLimit};
if (_mode isEqualTo 'RESPONSE_ACTIVE') exitWith {(_this select [1,(count _this) - 1]) call _fn_responseActive};
if (_mode isEqualTo 'MORTAR_ROUNDS') exitWith {(_this select [1,(count _this) - 1]) call _fn_mortarRounds};
if (_mode isEqualTo 'REPORT_FRESH') exitWith {(_this select [1,(count _this) - 1]) call _fn_reportFresh};
if (_mode isEqualTo 'FIRE_BUDGET') exitWith {(_this select [1,(count _this) - 1]) call _fn_fireBudget};
if (_mode isEqualTo 'FIRE_PLAN') exitWith {(_this select [1,(count _this) - 1]) call _fn_firePlan};
if (_mode isEqualTo 'FIRE_LIMIT') exitWith {(_this select [1,(count _this) - 1]) call _fn_fireLimit};
if (_mode isEqualTo 'FORCE_CAP') exitWith {(_this select [1,(count _this) - 1]) call _fn_forceCap};
if (_mode isEqualTo 'SNIPER') exitWith {(_this select [1,(count _this) - 1]) call _fn_sniper};
if (_mode isEqualTo 'WIND_OFFSET') exitWith {(_this select [1,(count _this) - 1]) call _fn_windOffset};
if (_mode isEqualTo 'WIND_CALIBRATE') exitWith {(_this select [1,(count _this) - 1]) call _fn_windCalibrate};

// Context is small: publish at INIT and when the remaining allowance runs out.
// Shared AI handlers identify Primary requests on the server or HC. Execution
// rechecks live objective completion on the server before spending a slot.
private _fn_context = {
	params ['_subject'];
	if (!(missionNamespace getVariable ['QS_primaryPressure_running',FALSE]) ||
		{missionNamespace getVariable ['QS_defendActive',FALSE]}) exitWith {FALSE};
	private _context = missionNamespace getVariable ['QS_primaryPressure_context',[]];
	if ((count _context) < 8) exitWith {FALSE};
	private _point = if (_subject isEqualType objNull) then {getPosATL (vehicle _subject)} else {_subject};
	(_point distance2D (_context # 1)) < ((_context # 2) + 500) ||
	{_subject isEqualType objNull && {(((group _subject) getVariable ['QS_primaryPressure_task',[-1]]) # 0) isEqualTo (_context # 0) || {((group _subject) getVariable ['QS_primaryPressure_supportEpoch',-1]) isEqualTo (_context # 0)}}}
};
if (_mode isEqualTo 'CONTEXT') exitWith {[_this # 1] call _fn_context};
if (_mode isEqualTo 'ARTY_ALLOWED') exitWith {
	if (!([_this # 1] call _fn_context)) exitWith {TRUE};
	private _context = missionNamespace getVariable ['QS_primaryPressure_context',[]];
	_context # 7
};

// Only Primary type-0 artillery scripts are registered here. Aircraft fire
// missions own lasers/helpers and must keep their original cleanup path.
// A started mission has already spent one allowance slot and keeps its salvo.
// Only an activity transition stops its remaining commands; fired shells remain.
if (_mode isEqualTo 'ARTY_TICK') exitWith {
	if (diag_tickTime < (missionNamespace getVariable ['QS_primaryPressure_fireCheck',0])) exitWith {};
	missionNamespace setVariable ['QS_primaryPressure_fireCheck',diag_tickTime + 3,FALSE];
	private _keep = [];
	{
		private _record = _x getVariable ['QS_primaryPressure_fire',[]];
		if (_record isNotEqualTo []) then {
			_record params ['_handle','_context'];
			if (!scriptDone _handle) then {
				private _stop = !(missionNamespace getVariable ['QS_primaryPressure_running',FALSE]) ||
					{missionNamespace getVariable ['QS_defendActive',FALSE]} ||
					{(_context # 0) isNotEqualTo (missionNamespace getVariable ['QS_primaryPressure_epoch',-1])};
				if (_stop) then {
					terminate _handle;
					if (local (leader _x)) then {doStop (leader _x); (leader _x) doWatch objNull;};
				} else {_keep pushBack _x;};
			};
			if (!(_x in _keep)) then {_x setVariable ['QS_primaryPressure_fire',nil,FALSE];};
		};
	} forEach (missionNamespace getVariable ['QS_primaryPressure_fireGroups',[]]);
	missionNamespace setVariable ['QS_primaryPressure_fireGroups',_keep,FALSE];
};

// ONE WIND TEST PER AO / DEFENSE. Use the first scheduled parachute group;
// no extra test soldiers. Read that group's landings for at most 150 seconds,
// freeze one horizontal spawn offset, then stop sampling until the next activity.
// Later groups cache the offset so it cannot change halfway through their creation.
if (_mode in ['DROP_RESET','DROP_SPAWN','DROP_TRACK','DROP_TICK']) exitWith {
	if (!isServer) exitWith {if (_mode isEqualTo 'DROP_SPAWN') then {+(_this # 1)} else {FALSE}};
	if (_mode isEqualTo 'DROP_RESET') exitWith {
		missionNamespace setVariable ['QS_primaryPressure_wind',createHashMapFromArray [
			['activity',_this # 1],['offset',[0,0,0]],['group',grpNull],['phase','WAIT'],
			['records',[]],['samples',[]],['next',0],['start',0]
		],FALSE];
	};
	private _data = missionNamespace getVariable ['QS_primaryPressure_wind',createHashMap];
	if (_mode isEqualTo 'DROP_SPAWN') exitWith {
		params ['','_landing','_exclusion','_group'];
		if ((count _data) isEqualTo 0) exitWith {+_landing};
		if ((_data get 'phase') isEqualTo 'WAIT') then {
			_data set ['phase','TEST']; _data set ['group',_group]; _data set ['start',diag_tickTime];
			_data set ['offset',[wind,[0,0,0],_landing # 2] call _fn_windOffset];
		};
		if (isNil {_group getVariable 'QS_primaryPressure_dropOffset'}) then {_group setVariable ['QS_primaryPressure_dropOffset',+(_data get 'offset'),FALSE];};
		private _spawn = _landing vectorDiff (_group getVariable 'QS_primaryPressure_dropOffset');
		private _safe = (_spawn # 0) > 50 && {(_spawn # 1) > 50} &&
			{(_spawn # 0) < worldSize - 50} && {(_spawn # 1) < worldSize - 50} &&
			{!surfaceIsWater _spawn} &&
			{(allPlayers inAreaArray [_spawn,_exclusion,_exclusion,0,FALSE]) isEqualTo []};
		if (!_safe) exitWith {+_landing};
		_spawn
	};
	if ((count _data) isEqualTo 0 || {(_data get 'phase') isNotEqualTo 'TEST'}) exitWith {};
	if (_mode isEqualTo 'DROP_TRACK') exitWith {
		params ['','_unit','_landing','_spawn'];
		private _records = _data get 'records';
		if ((group _unit) isEqualTo (_data get 'group') && {(count _records) < 24}) then {
			_records pushBack [_unit,+_landing,+_spawn,diag_tickTime,FALSE];
		};
	};
	private _now = diag_tickTime;
	if (_now < (_data get 'next')) exitWith {};
	_data set ['next',_now + 3];
	private _activity = _data get 'activity';
	if ((_activity isEqualTo 'DEFENSE' && {!(missionNamespace getVariable ['QS_defendActive',FALSE])}) ||
		{_activity isEqualTo 'PRIMARY' && {!(missionNamespace getVariable ['QS_primaryPressure_running',FALSE])}}) exitWith {
		_data set ['records',[]]; _data set ['phase','DONE'];
	};
	private _keep = [];
	{
		_x params ['_unit','_landing','_spawn','_start','_seenAir'];
		if (alive _unit && {!isPlayer _unit} && {!captive _unit} && {(_now - _start) < 150}) then {
			private _height = (getPosATL _unit) # 2;
			if (_height > 10) then {_x set [4,TRUE];};
			if (isNull (objectParent _unit) && {_height < 3}) then {
				if (_seenAir && {(_now - _start) >= 8} && {(_unit distance2D _landing) < 180} &&
					{damage _unit < 0.3} && {(lifeState _unit) in ['HEALTHY','INJURED']}) then {
					// Actual landing minus actual spawn includes the offset already used.
					// This avoids applying that initial estimate a second time.
					(_data get 'samples') pushBack ((getPosATL _unit) vectorDiff _spawn);
				};
			} else {_keep pushBack _x;};
		};
	} forEach (_data get 'records');
	_data set ['records',_keep];
	if ((_now - (_data get 'start')) >= 150 ||
		{_keep isEqualTo [] && {(_now - (_data get 'start')) >= 10} && {!((_data get 'group') getVariable ['QS_primaryPressure_building',FALSE])}}) then {
		_data set ['offset',[_data get 'samples',_data get 'offset'] call _fn_windCalibrate];
		_data set ['records',[]]; _data set ['phase','DONE'];
		diag_log format ['[PrimaryAO] WIND_CALIBRATED activity=%1 samples=%2 offset=%3',_activity,count (_data get 'samples'),_data get 'offset'];
	};
};

private _fn_exempt = {
	_this getVariable ['QS_primaryAO_exempt',FALSE] ||
	{(group _this) getVariable ['QS_primaryAO_exempt',FALSE]} ||
	{_this getVariable ['QS_RD_missionObjective',FALSE]} ||
	{_this getVariable ['QS_aoTask_medevac_unit',FALSE]} ||
	{isPlayer _this} || {captive _this} ||
	{!isNull (remoteControlled _this)} ||
	{!isNull (_this getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}
};

// GROUP ORDERS: reuse the server/HC scheduler; pace optional maneuver refreshes.
// Only current-AO task groups enter this path. Native targeting still handles fire.
if (_mode isEqualTo 'GROUP') exitWith {
	params ['','_group','_now','_fps'];
	if (!local _group || {isNull _group}) exitWith {};
	private _task = _group getVariable ['QS_primaryPressure_task',[]];
	if ((count _task) < 7) exitWith {};
	_task params ['_epoch','_goal','_center','_radius','_role','_node','_slots'];
	if (_epoch isNotEqualTo (missionNamespace getVariable ['QS_primaryPressure_epoch',-1])) exitWith {};
	if (_now < (_group getVariable ['QS_primaryPressure_nextOrder',-1])) exitWith {};
	private _members = units _group;
	if ((_members findIf {_x call _fn_exempt}) >= 0) exitWith {};
	private _able = _members select {alive _x && {(lifeState _x) in ['HEALTHY','INJURED']}};
	if (_able isEqualTo []) exitWith {};
	private _leader = leader _group;
	if (!(_leader in _able)) then {_group selectLeader (_able # 0); _leader = leader _group;};
	// Keep following the current route and firing. Only maneuver refreshes
	// spread to 40-50 s under load; task changes still reset nextOrder at once.
	// Sample once per owning machine per 10 s, not once per infantryman.
	private _moveLoad = localNamespace getVariable ['QS_primaryPressure_moveLoad',[TRUE,-1,-1]];
	if (_now >= (_moveLoad # 2)) then {
		_moveLoad = [_now,diag_fps,_moveLoad # 0,_moveLoad # 1] call _fn_performance;
		_moveLoad pushBack (_now + 10);
		localNamespace setVariable ['QS_primaryPressure_moveLoad',_moveLoad];
	};
	_group setVariable ['QS_primaryPressure_nextOrder',_now + ([40,20] select (_moveLoad # 0)) + random 10,FALSE];
	private _parent = objectParent _leader;
	if (_role in ['FINAL','FINAL_ARMOR']) then {
		private _intel = missionNamespace getVariable ['QS_primaryPressure_finalIntel',[-1,[]]];
		private _reports = if ((_intel # 0) isEqualTo _epoch) then {(_intel # 1) select {
			[serverTime,_x # 1,45] call _fn_reportFresh && {((_x # 0) distance2D _center) <= _radius}
		}} else {[]};
		if (_reports isNotEqualTo []) then {
			private _ranked = _reports apply {[_leader distance2D (_x # 0),_x # 0]}; _ranked sort TRUE;
			private _focus = +((_ranked # 0) # 1);
			private _distance = [110,300] select (_role isEqualTo 'FINAL_ARMOR');
			private _candidate = _focus getPos [_distance,_focus getDir _leader];
			if (!surfaceIsWater _candidate && {((_candidate distance2D _center) <= _radius)} && {((surfaceNormal _candidate) # 2) > 0.85}) then {
				_slots = _slots apply {(_x vectorDiff _goal) vectorAdd _candidate};
				_goal = _candidate;
			};
		};
	};
	if (!isNull _parent && {_parent isKindOf 'Air'}) exitWith {};
	if (!isNull _parent && {!(_parent isKindOf 'StaticWeapon')}) exitWith {
		if (_role in ['ARMOR','FINAL_ARMOR'] && {local _parent} && {canMove _parent}) then {
			_group setBehaviour 'AWARE'; _group setSpeedMode 'FULL';
			_group setCombatMode 'YELLOW';
			if ((_parent distance2D _goal) > 40) then {_group move _goal;};
		};
	};
	// Static crews only leave their weapons during the final HQ regroup.
	if (!isNull _parent) exitWith {
		if (_role isEqualTo 'FINAL') then {
			{if (local _x) then {[_x] allowGetIn FALSE; unassignVehicle _x; moveOut _x;};} forEach _able;
		};
	};
	private _setup = [_epoch,_node,_role,clientOwner,((_task param [9,[]]) param [0,-1])];
	private _changed = (_group getVariable ['QS_primaryPressure_setupOwner',[]]) isNotEqualTo _setup;
	if (_changed) then {
		_group setVariable ['QS_primaryPressure_setupOwner',_setup,FALSE];
		_group setBehaviour 'AWARE'; _group setCombatMode 'YELLOW';
		_group setSpeedMode 'FULL'; _group setFormation 'WEDGE';
		_group enableAttack FALSE; _group allowFleeing 0;
		{
			if (_role isEqualTo 'FINAL' && {(objectParent _x) isKindOf 'StaticWeapon'} && {local _x}) then {
				[_x] allowGetIn FALSE; unassignVehicle _x; moveOut _x;
			};
			_x enableAIFeature ['PATH',TRUE]; _x enableAIFeature ['AUTOCOMBAT',FALSE];
			_x enableAIFeature ['TARGET',TRUE]; _x enableAIFeature ['AUTOTARGET',TRUE];
			_x setUnitPos (['UP','AUTO'] select (['SNIPER',typeOf _x] call QS_fnc_aoPressure));
			_x forceSpeed -1; _x doFollow _leader;
			_x setVariable ['QS_primaryPressure_hold',FALSE,FALSE];
		} forEach _able;
	};
	if (_role isEqualTo 'PATROL') exitWith {};
	// The server assigns contact response roles after a real sighting. Use
	// the same paced movement and dispersed slots on the owning server/HC.
	// Ordinary reserves retain their limited lateral reaction at their post.
	if (_role in ['ADVANCE','SUPPORT','HUNT'] && {serverTime >= ((_task # 9) # 1)}) exitWith {
		{doStop _x;} forEach _able;
	};
	private _watch = if (_role in ['ADVANCE','SUPPORT','HUNT']) then {+(_task # 7)} else {[]};
	private _recent = _group targets [TRUE,600,[WEST],45];
	private _contacts = (_leader nearTargets 600) select {
		((_x # 4) in _recent) && {alive (_x # 4)} && {!captive (_x # 4)} &&
		{((_x # 4) call QS_fnc_groundTargetPriority) >= 0}
	};
	private _rankedContacts = [];
	{_rankedContacts pushBack [(_x # 4) call QS_fnc_groundTargetPriority,(_x # 0) distance2D _goal,_forEachIndex,+(_x # 0)];} forEach _contacts;
	_rankedContacts sort TRUE;
	if (_rankedContacts isNotEqualTo []) then {_watch = +((_rankedContacts # 0) # 3);};
	private _offset = [0,0,0];
	if (_role isEqualTo 'RESERVE' && {(_leader distance2D _goal) < 90}) then {
		if (_changed || {_now >= (_group getVariable ['QS_primaryPressure_reactAfter',-1])}) then {
			_offset = [_role,_goal,_watch,(_task param [8,FALSE])] call _fn_reactionOffset;
			_group setVariable ['QS_primaryPressure_reactOffset',_offset,FALSE];
			_group setVariable ['QS_primaryPressure_reactAfter',_now + 60,FALSE];
		} else {_offset = _group getVariable ['QS_primaryPressure_reactOffset',[0,0,0]];};
	};
	if (_role in ['DEFEND','RESERVE','SCREEN','FINAL','CONTEST','ADVANCE','SUPPORT','HUNT'] && {(_leader distance2D _goal) < 120}) then {
		{
			if (serverTime >= (_x getVariable ['QS_AI_coverUntil',0])) then {
			if (_watch isEqualTo []) then {_x doWatch objNull;} else {_x doWatch _watch;};
			private _baseSlot = _slots param [_forEachIndex,getPosATL _x];
			private _slot = _baseSlot vectorAdd _offset;
			if (surfaceIsWater _slot || {((surfaceNormal _slot) # 2) < 0.85}) then {_slot = +_baseSlot;};
			private _lastOrder = _x getVariable ['QS_primaryPressure_lastSlot',getPosATL _x];
			if ((_x distance _slot) < 4) then {
				if (!(_x getVariable ['QS_primaryPressure_hold',FALSE])) then {
					doStop _x; _x setVariable ['QS_primaryPressure_hold',TRUE,FALSE];
				};
			} else {
				private _last = _x getVariable ['QS_primaryPressure_lastPosition',getPosATL _x];
				if (_changed || {(_slot distance2D _lastOrder) > 5} || {unitReady _x} || {(_x distance2D _last) < 3}) then {_x doMove _slot;};
				_x setVariable ['QS_primaryPressure_hold',FALSE,FALSE];
				_x setVariable ['QS_primaryPressure_lastPosition',getPosATL _x,FALSE];
			};
			_x setVariable ['QS_primaryPressure_lastSlot',_slot,FALSE];
			};
		} forEach _able;
	} else {
		private _last = _group getVariable ['QS_primaryPressure_lastPosition',getPosATL _leader];
		private _lastGoal = _group getVariable ['QS_primaryPressure_lastGoal',[0,0,0]];
		if (_changed || {unitReady _leader} || {(_leader distance2D _last) < 5} || {(_lastGoal distance2D _goal) > 75}) then {
			private _bound = (getPosATL _leader) getPos [150 min (_leader distance2D _goal),_leader getDir _goal];
			if (!surfaceIsWater _bound) then {
				if (serverTime < (_group getVariable ['QS_AI_coverUntil',0])) then {
					{if (serverTime >= (_x getVariable ['QS_AI_coverUntil',0])) then {_x doMove _bound;};} forEach _able;
				} else {_group move _bound;};
			};
		};
		_group setVariable ['QS_primaryPressure_lastPosition',getPosATL _leader,FALSE];
		_group setVariable ['QS_primaryPressure_lastGoal',_goal,FALSE];
	};
};

if (!isServer) exitWith {FALSE};
private _state = missionNamespace getVariable ['QS_primaryPressure_state',createHashMap];
private _now = diag_tickTime;
private _fn_humans = {
	allPlayers select {
		isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')} &&
		{alive _x} && {(lifeState _x) in ['HEALTHY','INJURED']} &&
		{(side (group _x)) isEqualTo WEST} &&
		{!((vehicle _x) isKindOf 'Air')} && {((getPosATL (vehicle _x)) # 2) < 15}
	}
};
private _fn_enemy = {
	alive _this && {!isPlayer _this} && {!captive _this} &&
	// Sleeping infantry and hidden UAV crew still occupy a force slot.
	{(WEST getFriend (side (group _this))) < 0.6}
};
// Count personnel once: infantry, armor/static crews, and UAV crew
// and inbound cargo. Vehicle hulls are not counted again on top of their crew.
// Nearby small-task guards count here, but are never added to the movement roster.
private _fn_force = {
	params ['_enemies'];
	private _force = _enemies inAreaArray [_state get 'pos',(_state get 'radius') + 500,(_state get 'radius') + 500,0,FALSE];
	private _assigned = (_state get 'initial') + (_state get 'men');
	{if (_x isKindOf 'CAManBase' && {_x call _fn_enemy}) then {_force pushBackUnique _x;};} forEach _assigned;
	_force
};
private _fn_register = {
	params ['_entity'];
	_entity setVariable ['QS_primaryPressure_entityEpoch',_state get 'epoch',FALSE];
	(_state get 'entities') pushBackUnique _entity;
	if (_entity isKindOf 'CAManBase') then {
		(_state get 'men') pushBackUnique _entity;
		_entity setVariable ['QS_primaryPressure_rosterEpoch',_state get 'epoch',TRUE];
		if (((group _entity) getVariable ['QS_primaryPressure_rosterEpoch',-1]) isNotEqualTo (_state get 'epoch')) then {
			(group _entity) setVariable ['QS_primaryPressure_rosterEpoch',_state get 'epoch',TRUE];
		};
	};
};
private _fn_track = {
	params ['_objects'];
	private _expanded = +_objects;
	{if (_x isEqualType objNull && {_x isKindOf 'AllVehicles'} && {!(_x isKindOf 'CAManBase')}) then {_expanded append (crew _x);};} forEach _objects;
	{
		if (_x isEqualType objNull && {!isNull _x}) then {
			private _seen = _x getVariable ['QS_primaryPressure_initialEpoch',-1];
			if (_seen < 0 && {!(_x in (_state get 'seen'))}) then {
				_x setVariable ['QS_primaryPressure_initialEpoch',_state get 'epoch',FALSE];
				(_state get 'initial') pushBackUnique _x;
				(_state get 'seen') pushBackUnique _x;
				if (_x isKindOf 'CAManBase') then {
					private _group = group _x;
					_x setVariable ['QS_primaryPressure_rosterEpoch',_state get 'epoch',TRUE];
					if ((_group getVariable ['QS_primaryPressure_rosterEpoch',-1]) isNotEqualTo (_state get 'epoch')) then {
						_group setVariable ['QS_primaryPressure_rosterEpoch',_state get 'epoch',TRUE];
					};
					if (_x getVariable ['QS_unitGarrisoned',FALSE]) then {_group setVariable ['QS_primaryPressure_guard',TRUE,TRUE];};
					if (_group getVariable ['QS_primaryPressure_guard',FALSE] && {(_group getVariable ['QS_primaryPressure_guardNode','']) isEqualTo ''}) then {
						private _nearestNode = ''; private _distance = 1e10;
						{
							private _range = (_x # 1) distance2D (leader _group);
							if (_range < _distance) then {_nearestNode = _x # 0; _distance = _range;};
						} forEach (_state get 'nodes');
						_group setVariable ['QS_primaryPressure_guardNode',_nearestNode,TRUE];
					};
					private _config = _group getVariable ['QS_AI_GRP_CONFIG',[]];
					if ((_config param [0,'']) isEqualTo 'SUPPORT' && {(_config param [1,'']) in ['MORTAR','ARTILLERY']}) then {
						// Physical support stays server-owned, matching the framework's
						// support-provider rule; one server gate owns the whole allowance.
						_group setVariable ['QS_primaryPressure_supportEpoch',_state get 'epoch',TRUE];
						_group setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
					};
				};
			};
		};
	} forEach _expanded;
};
private _fn_objectives = {
	// Snapshot actual objective identities. Completion is monotonic; ENEMYPOP
	// is not an objective that can reduce its own reinforcement cap.
	private _nodes = _state get 'nodes';
	private _changed = [];
	{
		if (!(_x # 5)) then {
			private _done = switch (_x # 2) do {
				case 'FLAG': {!(missionNamespace getVariable [_x # 4,FALSE])};
				case 'MORTARS': {((_x # 6) findIf {alive _x && {(gunner _x) call _fn_enemy}}) < 0};
				default {!alive (_x # 3) || {captive (_x # 3)}};
			};
			if (_done) then {_x set [5,TRUE]; _changed pushBack (_x # 0);};
		};
	} forEach _nodes;
	private _completed = {_x # 5} count _nodes;
	private _factor = [count _nodes,_completed] call _fn_taper;
	private _limit = [_state get 'fireBudget',(_nodes select {_x # 5}) apply {_x # 0},_factor <= 0] call _fn_fireLimit;
	_state set ['fireLimit',_limit];
	private _remaining = 0 max (_limit - (_state get 'fireUsed'));
	private _windows = _state get 'fireWindows';
	// Keep the earliest remaining times, cancel the tail. Never move a deadline
	// or restore an expired/cancelled slot. The original firePlan is read-only.
	_windows resize ((count _windows) min _remaining);
	private _online = _remaining > 0;
	if (_online isNotEqualTo (_state get 'supportOnline')) then {
		_state set ['supportOnline',_online];
		missionNamespace setVariable ['QS_primaryPressure_supportOnline',_online,TRUE];
		private _context = missionNamespace getVariable ['QS_primaryPressure_context',[]];
		if ((count _context) >= 8) then {_context set [7,_online]; missionNamespace setVariable ['QS_primaryPressure_context',_context,TRUE];};
	};
	_state set ['completed',_completed];
	if (_factor isNotEqualTo (_state get 'factor')) then {
		_state set ['factor',_factor];
		// Existing survivors stay alive above the reduced cap. The next admission
		// waits for enough casualties to fit a whole squad; cadence is not stretched.
		if (_factor <= 0) then {
			_state set ['phase','FINAL']; _state set ['nextMobilize',0];
			_state set ['finalNext',_now + 90 + random 60];
		};
		diag_log format ['[PrimaryAO] OBJECTIVES epoch=%1 done=%2/%3 capFactor=%4',_state get 'epoch',_completed,count _nodes,_factor];
	};
	if ('MORTAR' in _changed) then {{deleteMarker _x;} forEach (_state get 'mortarMarkers'); _state set ['mortarMarkers',[]];};
	// Original objective handlers own player notifications; this controller
	// updates reinforcement and fire-support policy without adding chat.
	_factor
};
// A missing objective does not impose a restriction. Only a present, completed
// node removes its reinforcement type for the rest of this AO.
private _fn_secured = {
	params ['_key'];
	((_state get 'nodes') findIf {(_x # 0) isEqualTo _key && {_x # 5}}) >= 0
};
// OBJECTIVE ALLOCATION: send the next squad to the largest defender shortfall.
// Already assigned ground troops, parachutists and helicopter cargo count together.
// This prevents an objective receiving repeated waves while its first wave travels.
private _fn_chooseNode = {
	params ['_profile'];
	private _choice = [];
	private _best = -1e10;
	private _men = ((_state get 'initial') + (_state get 'men')) select {
		_x isKindOf 'CAManBase' && {_x call _fn_enemy} && {!(_x call _fn_exempt)} &&
		{isNull (objectParent _x) || {(objectParent _x) isKindOf 'ParachuteBase'} || {_x getVariable ['QS_primaryPressure_cargo',FALSE]}}
	};
	private _nodes = _state get 'nodes';
	private _activeWeight = 0;
	{if (!(_x # 5)) then {_activeWeight = _activeWeight + ([1,1.5] select ((_x # 0) isEqualTo 'HQ'));};} forEach _nodes;
	{
		private _node = _x;
		if (!(_node # 5)) then {
			private _key = _node # 0;
			private _target = _profile # ([7,5] select (_key isEqualTo 'HQ'));
			// Share the current force capacity across surviving objectives. Fixed
			// inner-post targets must not strand spare capacity on small objective sets.
			_target = _target max (ceil ((([_profile # 2,_state get 'factor'] call _fn_forceCap) * ([1,1.5] select (_key isEqualTo 'HQ'))) / (1 max _activeWeight)));
			private _committed = {
				private _assigned = (group _x) getVariable ['QS_primaryPressure_node',''];
				(_assigned isEqualTo _key) || {_assigned isEqualTo '' && {(_x distance2D (_node # 1)) < 130}}
			} count _men;
			private _deficit = _target - _committed;
			if (_deficit > _best) then {_best = _deficit; _choice = [_node,_deficit];};
		};
	} forEach _nodes;
	// Local targets guide placement, not admission. Several small shortages
	// must not strand room for a complete squad under the shared force cap.
	if (_choice isNotEqualTo []) then {_choice set [1,8 max (_choice # 1)];};
	_choice
};
// DEFENSIVE POSTS: assign squads to approaches, usually 100-180 m from an
// objective, with 140 m between accepted squad posts. Final HQ posts use 80-160 m.
// Search a bounded set of terrain positions; failed searches keep current positions.
// Only one squad per objective can hold the limited lateral-reaction reserve role.
private _fn_activate = {
	params ['_group','_goal',['_role','DEFEND'],['_key',''],['_response',[]],['_approach',-1]];
	if (isNull _group) exitWith {};
	if (_group getVariable ['QS_primaryPressure_building',FALSE] || {_group getVariable ['QS_taruDelivery_busy',FALSE]}) exitWith {};
	private _members = units _group;
	if ((_members findIf {_x call _fn_exempt}) >= 0) exitWith {};
	if ((_members findIf {alive _x}) < 0) exitWith {};
	private _leader = leader _group;
	if (!alive _leader) then {_leader = _members # (_members findIf {alive _x});};
	private _parent = objectParent _leader;
	if (!isNull _parent && {_parent isKindOf 'Air'}) exitWith {};
	private _final = (_state get 'factor') <= 0;
	// Dedicated guards fall back only when their own objective is secured.
	// They defend another objective and remain outside the hunting budget.
	private _guard = _group getVariable ['QS_primaryPressure_guard',FALSE];
	private _guardKey = _group getVariable ['QS_primaryPressure_guardNode',''];
	if (!_final && {_guard} && {((_state get 'nodes') findIf {(_x # 0) isEqualTo _guardKey && {_x # 5}}) < 0}) exitWith {};
	private _moving = _role in ['ADVANCE','SUPPORT','HUNT'] && {!_final};
	private _placementOK = TRUE;
	private _contest = (_role isEqualTo 'CONTEST') && {!_final};
	private _nodes = _state get 'nodes';
	if (_key isEqualTo '') then {_key = _group getVariable ['QS_primaryPressure_node',''];};
	private _index = _nodes findIf {(_x # 0) isEqualTo _key && {!(_x # 5)}};
	if (_final) then {
		_goal = +(_state get 'hq'); _key = 'FINAL'; _role = 'FINAL';
	} else {
		if (_index < 0) then {
			private _choice = [_state get 'profile'] call _fn_chooseNode;
			if (_choice isNotEqualTo []) then {_key = (_choice # 0) # 0; _index = _nodes findIf {(_x # 0) isEqualTo _key};};
		};
		if (_index >= 0 && {!_contest} && {!_moving}) then {_goal = +((_nodes # _index) # 1);};
	};
	private _objective = +_goal;
	private _posts = (_state get 'posts') select {
		!isNull (_x # 0) && {(_x # 0) isNotEqualTo _group} &&
		{((units (_x # 0)) findIf {alive _x && {!(_x call _fn_exempt)}}) >= 0}
	};
	if (!isNull _parent && {!(_parent isKindOf 'StaticWeapon')}) then {
		if (!(_parent isKindOf 'Air')) then {
			_role = ['ARMOR','FINAL_ARMOR'] select _final;
			// Bounded terrain checks for a dispersed firing position. If none is
			// usable, retain its current ground position instead of driving into HQ.
			private _firing = getPosATL _parent;
			for '_attempt' from 0 to 11 do {
				private _point = _goal getPos [200 + random 250,random 360];
				if (_parent isKindOf 'Ship' && {surfaceIsWater _point}) exitWith {_firing = _point;};
				if (!(_parent isKindOf 'Ship') && {!surfaceIsWater _point} && {((surfaceNormal _point) # 2) > 0.90} &&
					{!([_point,_goal,25] call QS_fnc_waterIntersect)} &&
					{!terrainIntersectASL [(ATLToASL _point) vectorAdd [0,0,2],(ATLToASL _goal) vectorAdd [0,0,2]]}) exitWith {_firing = _point;};
			};
			_goal = _firing;
		};
	};
	private _slots = [];
	if (_role in ['DEFEND','RESERVE','SCREEN','FINAL','CONTEST','ADVANCE','SUPPORT','HUNT']) then {
		if (_role isEqualTo 'RESERVE' && {(_posts findIf {(_x # 1) isEqualTo _key && {(_x # 3) isEqualTo 'RESERVE'}}) >= 0}) then {_role = 'DEFEND';};
		// Once the inner defense has enough squads, use wider approaches.
		// Extra capacity must not put every squad underneath the objective.
		private _innerLimit = ceil (((_state get 'profile') # ([7,5] select (_key isEqualTo 'HQ'))) / 12);
		if (!_final && {!_contest} && {!_moving} && {({(_x # 1) isEqualTo _key && {(_x # 3) isNotEqualTo 'SCREEN'}} count _posts) >= _innerLimit}) then {_role = 'SCREEN';};
		private _bearing = _objective getDir _leader;
		if (_moving && {_approach >= 0}) then {_bearing = _approach;};
		private _anchor = getPosATL _leader;
		private _found = FALSE;
		for '_attempt' from 0 to 17 do {
			private _radius = if (_role isEqualTo 'SCREEN') then {240 + (_attempt mod 3) * 60} else {([100,80] select _final) + (_attempt mod 3) * 40};
			if (_contest) then {_radius = 60 + (_attempt mod 3) * 20;};
			// Advancing squads close to the reported area from separate approaches;
			// support stays farther out. Fixed goals do not track live players.
			if (_moving) then {_radius = ([45,150] select (_role isEqualTo 'SUPPORT')) + (_attempt mod 3) * 15;};
			private _angle = floor (_attempt / 3) * 60;
			if (_moving) then {_angle = [0,20,-20,40,-40,60] # floor (_attempt / 3);};
			private _point = _objective getPos [_radius,_bearing + _angle];
			if (!surfaceIsWater _point && {((surfaceNormal _point) # 2) > 0.85} &&
				{(_point # 0) > 50 && {(_point # 1) > 50} && {(_point # 0) < worldSize - 50} && {(_point # 1) < worldSize - 50}} &&
				{(_posts findIf {((_x # 2) distance2D _point) < ([140,60] select (_contest || _moving))}) < 0} &&
				{!([_point,_objective,25] call QS_fnc_waterIntersect)}) exitWith {_anchor = _point; _found = TRUE;};
		};
		if (_moving && {!_found}) then {_placementOK = FALSE;};
		_goal = _anchor;
		private _heading = _objective getDir _anchor;
		{
			// No safe dispersed post: retain this man's current position. Never
			// collapse all failed position searches onto the objective object.
			private _slot = getPosATL _x;
			if (_found) then {
				private _point = [_anchor,_forEachIndex,count _members,_heading] call _fn_slotPoint;
				private _empty = _point findEmptyPosition [0,8,typeOf _x];
				if (_empty isNotEqualTo [] && {!surfaceIsWater _empty} &&
					{(_empty distance2D _anchor) <= 50} && {(_empty distance2D _objective) >= (if (_contest || _moving) then {25} else {[60,40] select _final})} &&
					{(_slots findIf {(_x distance2D _empty) < 14}) < 0}) then {_slot = _empty;};
			};
			_slots pushBack _slot;
		} forEach _members;
		_posts pushBack [_group,_key,+_anchor,_role];
	};
	if (!_placementOK) exitWith {};
	if (_role isEqualTo 'PATROL') then {
		_goal = getPosATL _leader;
		_posts pushBack [_group,_key,+_goal,_role];
	};
	if (_guard) then {_group setVariable ['QS_primaryPressure_guardNode',_key,TRUE];};
	_state set ['posts',_posts];
	_group setVariable ['QS_primaryPressure_node',_key,FALSE];
	_group setVariable ['QS_primaryPressure_task',[_state get 'epoch',+_goal,_state get 'pos',_state get 'radius',_role,_key,_slots,_objective,random 1 < 0.5,_response],TRUE];
	// Preserve native vehicle/air configuration for the next AO and native
	// support handlers. Supply missing configuration only for new infantry.
	if (isNil {_group getVariable 'QS_AI_GRP_CONFIG'}) then {
		_group setVariable ['QS_AI_GRP_CONFIG',['GENERAL','INFANTRY',count _members],QS_system_AI_owners];
		_group setVariable ['QS_AI_GRP_DATA',[TRUE,serverTime],QS_system_AI_owners];
		_group setVariable ['QS_AI_GRP_TASK',['MOVE',+_goal,serverTime,-1],QS_system_AI_owners];
	};
	_group setVariable ['QS_AI_GRP',TRUE,QS_system_AI_owners];
	if (isNil {_group getVariable 'QS_AI_GRP_HC'}) then {_group setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];};
	if (isNull _parent) then {_group setVariable ['QS_AI_GRP_HC_EXCLUDED',FALSE,TRUE];};
	_group setVariable ['QS_primaryPressure_nextOrder',-1,TRUE];
	{
		_x setVariable ['QS_AI_UNIT_enabled',TRUE,QS_system_AI_owners];
		_x setVariable ['QS_AI_UNIT_regroup_disable',TRUE,TRUE];
		_x setVariable ['QS_AI_UNIT_disableStanceAdjust',!(['SNIPER',typeOf _x] call QS_fnc_aoPressure),TRUE];
	} forEach _members;
};
// PRIMARY_CONTACT_CONTROLLER_BEGIN
// Only the registered Primary mobile infantry participates. Dedicated guards,
// garrisons, snipers, crews and other missions never enter these percentages.
private _fn_contactPool = {
	private _pool = [];
	{
		private _group = _x # 0;
		private _task = _group getVariable ['QS_primaryPressure_task',[]];
		private _men = (units _group) select {alive _x};
		if (!isNull _group && {_men isNotEqualTo []} && {count _men <= 12} &&
			{(_task param [0,-1]) isEqualTo (_state get 'epoch')} &&
			{(_task # 4) in ['DEFEND','RESERVE','SCREEN','PATROL','ADVANCE','SUPPORT','HUNT','CONTEST']} &&
			{!(_group getVariable ['QS_primaryPressure_guard',FALSE])} &&
			{!(_group getVariable ['QS_primaryPressure_building',FALSE])} &&
			{(_men findIf {_x call _fn_exempt || {!isNull (objectParent _x)} ||
				{(_x getVariable ['QS_primaryPressure_rosterEpoch',-1]) isNotEqualTo (_state get 'epoch')}}) < 0} &&
			{(_men findIf {!(['SNIPER',typeOf _x] call QS_fnc_aoPressure)}) >= 0}) then {_pool pushBackUnique _group;};
	} forEach (_state get 'posts');
	_pool
};
private _fn_contactRoom = {
	params ['_focus','_role',['_limit',3],['_replacing',grpNull]];
	private _pool = call _fn_contactPool;
	private _pressure = 0; private _hunters = 0;
	private _near = 0; private _advance = 0; private _support = 0;
	{
		private _task = _x getVariable 'QS_primaryPressure_task';
		private _kind = _task # 4;
		if (_x isNotEqualTo _replacing && {_kind in ['ADVANCE','SUPPORT','HUNT','CONTEST']}) then {
			if (_kind in ['ADVANCE','SUPPORT']) then {_pressure = _pressure + 1;} else {_hunters = _hunters + 1;};
			if (((_task # 7) distance2D _focus) < 350) then {
				_near = _near + 1;
				if (_kind isEqualTo 'ADVANCE') then {_advance = _advance + 1;};
				if (_kind isEqualTo 'SUPPORT') then {_support = _support + 1;};
			};
		};
	} forEach _pool;
	private _spent = 0;
	{if (((_x get 'focus') distance2D _focus) < 350) then {_spent = _spent + (_x get 'sent');};} forEach (_state get 'contactJobs');
	{if (((_x # 0) distance2D _focus) < 350) then {_spent = _spent + (_x # 5);};} forEach (_state get 'casualtyJobs');
	private _players = missionNamespace getVariable ['QS_primaryPressure_groundCount',0];
	if (_players <= 8 && {_spent >= 1}) exitWith {FALSE};
	[[count _pool,_players] call _fn_contactQuota,_pressure,_hunters,_near,_advance,_support,_spent,_role,_limit] call _fn_contactAdmission
};
// PRIMARY_STALKING_POLICY_BEGIN
// Eligibility only: these current positions never become pursuit destinations.
// Role-specific exceptions arrive with the role rollout; Primary presently uses
// the same ground-target policy for every observed player or ground vehicle.
private _fn_stalkPlayers = {
	_this select {isPlayer _x && {alive _x} && {!(_x isKindOf 'HeadlessClient_F')}}
};
private _fn_stalkTargetAllowed = {
	params ['_target'];
	(_target call QS_fnc_groundTargetPriority) >= 0
};
// PRIMARY_STALKING_POLICY_END
private _fn_contactTick = {
	if (_now < (_state get 'nextContact')) exitWith {};
	_state set ['nextContact',_now + 10];
	private _clock = serverTime;
	private _final = (_state get 'factor') <= 0;
	private _reports = [];
	private _range = 2200 min (1800 max ((_state get 'radius') + 1000));
	// Intel comes from local AI observation through the existing server/HC
	// channel. Player coordinates never supply a pursuit destination.
	{
		_x params ['_target','_seen','_position','_knowledge','_observer','_ground'];
		_target = vehicle _target;
		private _priority = _target call QS_fnc_groundTargetPriority;
		if (_priority >= 0 && {_ground} && {_knowledge >= 1.5} && {[_clock,_seen,45] call _fn_reportFresh} &&
			{!isNull _observer} && {(_observer getVariable ['QS_primaryPressure_rosterEpoch',-1]) isEqualTo (_state get 'epoch')} &&
			{(WEST getFriend (side _observer)) < 0.6} && {alive _target} && {!captive _target} &&
			{(isPlayer _target && {lifeState _target in ['HEALTHY','INJURED']} && {isNull (objectParent _target)}) ||
				{_target isKindOf 'LandVehicle' && {_priority < 4}}} &&
			{(_position distance2D (_state get 'pos')) <= _range} &&
			{(_position distance2D (markerPos 'QS_marker_base_marker')) > 1000} &&
			{(_position distance2D (markerPos 'QS_marker_sideMarker')) > 600} && {!surfaceIsWater _position}) then {
			private _point = +_position; _point set [2,0];
			// Several observed crew members describe one asset, not a cluster.
			private _existing = _reports findIf {(_x # 0) isEqualTo _target};
			if (_existing < 0) then {_reports pushBack [_target,_point,_seen,_priority];} else {
				if (_seen > ((_reports # _existing) # 2)) then {_reports set [_existing,[_target,_point,_seen,_priority]];};
			};
		};
	} forEach (missionNamespace getVariable ['QS_AI_targetsIntel',[]]);
	private _rankedReports = [];
	{_rankedReports pushBack [_x # 3,_forEachIndex,_x];} forEach _reports;
	_rankedReports sort TRUE;
	_reports = _rankedReports apply {_x # 2};
	if (_final) then {
		private _finalReports = (_reports select {((_x # 1) distance2D (_state get 'pos')) <= (_state get 'radius')}) select [0,12];
		_state set ['finalReports',_finalReports];
		// Small, bounded observations for owner-local final movement; never GPS.
		missionNamespace setVariable ['QS_primaryPressure_finalIntel',[_state get 'epoch',_finalReports apply {[+(_x # 1),_x # 2]}],TRUE];
	};
	if (_reports isNotEqualTo [] && {!_final}) then {_state set ['engaged',TRUE];};
	// Filter scripted pursuits after preserving ordinary/final-phase intelligence.
	private _stalkPlayers = allPlayers call _fn_stalkPlayers;
	_reports = _reports select {[_x # 0,_stalkPlayers] call _fn_stalkTargetAllowed};
	private _jobs = _state get 'contactJobs';
	private _pool = call _fn_contactPool;
	private _quota = [count _pool,missionNamespace getVariable ['QS_primaryPressure_groundCount',0]] call _fn_contactQuota;
	private _left = [_quota # 0,0 max ((_quota # 1) - ({((_x getVariable 'QS_primaryPressure_task') # 4) isEqualTo 'CONTEST'} count _pool))];
	{
		private _job = _x;
		private _focus = _job get 'focus';
		// Keep the original sector and deadlines. New sightings refresh awareness
		// inside that sector, not the destination or the maximum pursuit time.
		private _nearReports = _reports select {((_x # 1) distance2D _focus) <= 180};
		// Recheck cached sightings too: isolation must release an active pursuit
		// even when no fresh report replaced the old support-player sighting.
		private _observed = (if (_nearReports isEqualTo []) then {_job get 'reports'} else {_nearReports}) select {
			[_x # 0,_stalkPlayers] call _fn_stalkTargetAllowed
		};
		private _valid = (_observed findIf {
			alive (_x # 0) && {!captive (_x # 0)} &&
			{if ((_x # 0) isKindOf 'CAManBase') then {lifeState (_x # 0) in ['HEALTHY','INJURED']} else {((_x # 0) call QS_fnc_groundTargetPriority) >= 0}}
		}) >= 0;
		_job set ['priority',if (_observed isEqualTo []) then {5} else {selectMin (_observed apply {(_x # 0) call QS_fnc_groundTargetPriority})}];
		private _live = [_clock,_job,_nearReports,_valid,_final] call _fn_contactObserve;
		private _keep = [];
		{
			_x params ['_group','_goal','_role','_key'];
			private _task = _group getVariable ['QS_primaryPressure_task',[]];
			private _owned = (_task param [0,-1]) isEqualTo (_state get 'epoch') &&
				{(_task param [4,'']) in ['ADVANCE','SUPPORT','HUNT']} && {((_task param [9,[]]) param [0,-1]) isEqualTo (_job get 'id')};
			private _bucket = [0,1] select ((_task param [4,'']) isEqualTo 'HUNT');
			if (_live && {_owned} && {_group in _pool} && {(_left # _bucket) > 0}) then {
				_keep pushBack _x; _left set [_bucket,(_left # _bucket) - 1];
			} else {
				if (_owned) then {[_group,_goal,_role,_key] call _fn_activate;};
			};
		} forEach (_job get 'groups');
		_job set ['groups',_keep];
	} forEach _jobs;
	_jobs = _jobs select {_clock < (_x get 'coolUntil') || {(_x get 'groups') isNotEqualTo []}};
	_state set ['contactJobs',_jobs];
	if (_final || {!(_state get 'perfOK')} || {diag_fps < 18} ||
		{missionNamespace getVariable ['QS_primaryPressure_paused',FALSE]}) exitWith {};
	{
		_x params ['_focus','_members'];
		private _priority = selectMin (_members apply {_x # 3});
		// A full incident table may retire a lower-priority inactive record;
		// active squads and same-sector cooldowns are never silently discarded.
		if (count _jobs >= 6 && {(_jobs findIf {((_x get 'focus') distance2D _focus) < 350}) < 0}) then {
			private _replace = _jobs findIf {(_x get 'groups') isEqualTo [] && {(_x getOrDefault ['priority',4]) > _priority}};
			if (_replace >= 0) then {_jobs deleteAt _replace;};
		};
		if (count _jobs < 6 && {(_jobs findIf {((_x get 'focus') distance2D _focus) < 350}) < 0}) then {
			private _id = 1 + (_state get 'contactSerial'); _state set ['contactSerial',_id];
			_jobs pushBack (createHashMapFromArray [
				['id',_id],['focus',+_focus],['reports',_members],['seen',selectMax (_members apply {_x # 2})],['priority',_priority],
				// Includes travel from the outer screen. Fresh contact is still
				// required throughout; neither deadline is extended by later reports.
				['cluster',(count _members) >= 3],['ready',_clock + 10 + random 10],['ends',_clock + 300],
				['coolUntil',_clock + 420],['groups',[]],['sent',0],['bearing',_focus getDir (_state get 'hq')]
			]);
		};
	} forEach ([_reports] call _fn_contactAreas);
	// One dispatch across BOTH contact and casualty reactions every 20-40 s.
	// Existing squads keep their home-node allocation; this creates no deficit
	// or extra spawn reservation in the reinforcement controller.
	if (_now < (_state get 'nextDispatch')) exitWith {};
	private _sent = FALSE;
	private _rankedJobs = [];
	{_rankedJobs pushBack [_x getOrDefault ['priority',4],_forEachIndex,_x];} forEach _jobs;
	_rankedJobs sort TRUE;
	{
		private _job = _x # 2;
		private _focus = _job get 'focus';
		private _priority = _job getOrDefault ['priority',4];
		// AA and artillery can use the existing one-squad small-pop pressure
		// allowance even without a three-contact infantry cluster.
		private _role = if (_priority <= 1 || {_job get 'cluster'}) then {['ADVANCE','SUPPORT'] select ((_job get 'sent') >= 2)} else {'HUNT'};
		if (!_sent && {_clock >= (_job get 'ready')} &&
			{[_clock,_job get 'ends',_job get 'seen',TRUE,FALSE] call _fn_contactLive}) then {
			private _best = grpNull; private _distance = 1100; private _previous = createHashMap;
			private _armored = ((_job get 'reports') findIf {(_x # 0) isKindOf 'LandVehicle'}) >= 0;
			{
				private _group = _x;
				private _task = _group getVariable 'QS_primaryPressure_task';
				private _men = (units _group) select {alive _x};
				private _viper = (_men findIf {((toLowerANSI typeOf _x) find 'viper') < 0}) < 0;
				private _minimum = [8,6] select _viper;
				private _prior = _jobs findIf {(_x getOrDefault ['priority',4]) > _priority &&
					{((_x get 'groups') findIf {(_x # 0) isEqualTo _group}) >= 0} &&
					{((_task param [9,[]]) param [0,-1]) isEqualTo (_x get 'id')}};
				private _transfer = _prior >= 0 && {(_task # 4) in ['ADVANCE','SUPPORT','HUNT']};
				if (((_task # 4) in ['DEFEND','RESERVE','SCREEN'] || {_transfer}) &&
					{[_focus,_role,3,[grpNull,_group] select _transfer] call _fn_contactRoom} && {count _men >= _minimum} &&
					{!_viper || {count _men <= 9}} &&
					{(_men findIf {!(lifeState _x in ['HEALTHY','INJURED'])}) < 0} &&
					{((_state get 'nodes') findIf {(_x # 0) isEqualTo (_task # 5) && {!(_x # 5)}}) >= 0}) then {
					private _hasAT = !_armored;
					if (_armored) then {
						// Only a usable ground-attack launcher qualifies for an armor hunt.
						_hasAT = (_men findIf {
							secondaryWeapon _x isNotEqualTo '' && {(_x ammo (secondaryWeapon _x)) > 0} && {({
								private _ammo = configFile >> 'CfgAmmo' >> getText (configFile >> 'CfgMagazines' >> _x >> 'ammo');
								_x isNotEqualTo '' && {getNumber (_ammo >> 'airLock') < 2}
							} count (secondaryWeaponMagazine _x)) > 0}
						}) >= 0;
					};
					private _rangeTo = (leader _group) distance2D _focus;
					if (_hasAT && {_rangeTo > 80} && {_rangeTo < _distance} &&
						{!([getPosATL (leader _group),_focus,50] call QS_fnc_waterIntersect)}) then {
						_best = _group; _distance = _rangeTo;
						_previous = if (_transfer) then {_jobs # _prior} else {createHashMap};
					};
				};
			} forEach (call _fn_contactPool);
			if (!isNull _best) then {
				private _task = _best getVariable 'QS_primaryPressure_task';
				private _return = [_best,+(_task # 1),_task # 4,_task # 5];
				if (count _previous > 0) then {_return = ((_previous get 'groups') select {(_x # 0) isEqualTo _best}) # 0;};
				private _bearing = ((_job get 'bearing') + 360 + ([-45,45,0] # ((_job get 'sent') min 2))) mod 360;
				[_best,_focus,_role,_task # 5,[_job get 'id',_job get 'ends'],_bearing] call _fn_activate;
				if (((_best getVariable 'QS_primaryPressure_task') # 4) isEqualTo _role &&
					{((((_best getVariable 'QS_primaryPressure_task') # 9) param [0,-1]) isEqualTo (_job get 'id'))}) then {
					if (count _previous > 0) then {
						_previous set ['groups',(_previous get 'groups') select {(_x # 0) isNotEqualTo _best}];
						if ((_previous get 'groups') isEqualTo []) then {_previous set ['ends',_clock min (_previous get 'ends')];};
					};
					(_job get 'groups') pushBack _return; _job set ['sent',1 + (_job get 'sent')];
					_state set ['nextDispatch',_now + 20 + random 20]; _sent = TRUE;
					diag_log format ['[PrimaryAO] CONTACT_RESPONSE epoch=%1 group=%2 role=%3 area=%4 expires=%5',_state get 'epoch',_best,_role,mapGridPosition _focus,_job get 'ends'];
				};
			};
		};
	} forEach _rankedJobs;
};
// PRIMARY_CONTACT_CONTROLLER_END

// CASUALTY RESPONSE: one bounded pass per ten seconds in the existing TICK.
// Recent AI reports supply positions; the server's revive state confirms the
// casualty. No player-location polling is used to update a response destination.
// Borrow only full reserve/screen squads. Keep another assigned squad defending
// their original objective, retain HVT/Medevac exemptions, and create no new AI.
private _fn_casualties = {
	params ['_humans'];
	if (_now < (_state get 'nextCasualty')) exitWith {};
	_state set ['nextCasualty',_now + 10];
	private _final = (_state get 'factor') <= 0;
	private _down = allPlayers select {
		isPlayer _x && {alive _x} && {(side (group _x)) isEqualTo WEST} &&
		{(lifeState _x) isEqualTo 'INCAPACITATED'} && {isNull (objectParent _x)} &&
		{(_x distance2D (_state get 'pos')) < ((_state get 'radius') + 500)}
	};
	private _population = (count _humans) + (count _down);
	private _pool = call _fn_contactPool;
	private _quota = [count _pool,missionNamespace getVariable ['QS_primaryPressure_groundCount',0]] call _fn_contactQuota;
	private _hunters = {((_x getVariable 'QS_primaryPressure_task') # 4) isEqualTo 'HUNT'} count _pool;
	private _room = ([_population,999] call _fn_responseLimit) min (0 max ((_quota # 1) - _hunters));
	private _jobs = [];
	private _fn_restore = {
		params ['_record'];
		_record params ['_group','_goal','_role','_key'];
		if (!isNull _group && {((_group getVariable ['QS_primaryPressure_task',[-1]]) # 0) isEqualTo (_state get 'epoch')} &&
			{((_group getVariable ['QS_primaryPressure_task',[]]) param [4,'']) isEqualTo 'CONTEST'}) then {
			[_group,_goal,_role,_key] call _fn_activate;
		};
	};
	{
		_x params ['_focus','_patients','_ready','_ends','_groups','_dispatched'];
		// Reading a moved patient's position can only CANCEL pursuit. The focus
		// remains the original report, so carrying/dragging never moves AI goals.
		_patients = _patients select {
			(_x # 0) in _down && {((_x # 0) getVariable ['QS_revive_timeDown',-1]) isEqualTo (_x # 1)} &&
			{isNull (attachedTo (_x # 0))} && {((_x # 0) distance2D _focus) <= 120}
		};
		private _keep = [];
		private _wanted = _room min ([_population,count _patients] call _fn_responseLimit);
		if (!([_now,_ends,count _patients,_final] call _fn_responseActive)) then {_wanted = 0;};
		{
			private _group = _x # 0;
			if ((count _keep) < _wanted && {!isNull _group} && {((units _group) findIf {alive _x}) >= 0} &&
				{((_group getVariable ['QS_primaryPressure_task',[-1]]) # 0) isEqualTo (_state get 'epoch')} &&
				{((_group getVariable ['QS_primaryPressure_task',[]]) param [4,'']) isEqualTo 'CONTEST'}) then {
				_keep pushBack _x;
			} else {[_x] call _fn_restore;};
		} forEach _groups;
		_room = _room - count _keep;
		if ([_now,_ends,count _patients,_final] call _fn_responseActive) then {
			_jobs pushBack [_focus,_patients,_ready,_ends,_keep,_dispatched];
		};
	} forEach (_state get 'casualtyJobs');
	_state set ['casualtyJobs',_jobs];
	private _seen = (_state get 'casualtySeen') select {
		isPlayer (_x # 0) && {alive (_x # 0)} && {(lifeState (_x # 0)) isEqualTo 'INCAPACITATED'} &&
		{((_x # 0) getVariable ['QS_revive_timeDown',-1]) isEqualTo (_x # 1)}
	};
	_state set ['casualtySeen',_seen];
	if (_final || {!(_state get 'perfOK')} || {diag_fps < 18} ||
		{missionNamespace getVariable ['QS_primaryPressure_paused',FALSE]}) exitWith {};
	private _intel = missionNamespace getVariable ['QS_AI_targetsIntel',[]];
	{
		private _patient = _x;
		private _stamp = _patient getVariable ['QS_revive_timeDown',-1];
		private _episode = [_patient,_stamp];
		if (!(_episode in _seen) && {_stamp >= 0} && {serverTime - _stamp <= 45} && {isNull (attachedTo _patient)}) then {
			private _index = _intel findIf {
				(_x # 0) isEqualTo _patient && {(_x # 3) > 1.5} &&
				{[serverTime,_x # 1,60] call _fn_reportFresh} && {(_x # 1) <= _stamp + 2} &&
				{((_x # 2) distance2D _patient) <= 75}
			};
			if (_index >= 0) then {
				_seen pushBack _episode;
				private _focus = +((_intel # _index) # 2); _focus set [2,0];
				if (!surfaceIsWater _focus && {(_focus distance2D (markerPos 'QS_marker_base_marker')) > 1000} &&
					{(_focus distance2D (markerPos 'QS_marker_sideMarker')) > 600}) then {
					private _job = _jobs findIf {((_x # 0) distance2D _focus) < 100};
					if (_job >= 0) then {((_jobs # _job) # 1) pushBack _episode;} else {
						if ((count _jobs) < 3) then {_jobs pushBack [_focus,[_episode],_now + 10 + random 10,_now + 120,[],0];};
					};
				};
			};
		};
	} forEach _down;
	// Admit at most one borrowed squad per pass, across all casualty areas.
	// The area's dispatch count never falls when a squad dies or returns:
	// clearing that resistance must not summon replacements to the same casualty.
	private _sent = FALSE;
	{
		private _job = _x;
		_job params ['_focus','_patients','_ready','_ends','_groups','_dispatched'];
		if (!_sent && {_room > 0} && {_now >= _ready} && {_now >= (_state get 'nextDispatch')} &&
			{[_focus,'CONTEST',[_population,count _patients] call _fn_responseLimit] call _fn_contactRoom} &&
			{_dispatched < ([_population,count _patients] call _fn_responseLimit)}) then {
			private _best = grpNull; private _distance = 350;
			{
				private _group = _x # 0;
				private _task = _group getVariable ['QS_primaryPressure_task',[]];
				private _members = units _group;
				if (_group in _pool && {(count _task) >= 7} && {(_task # 0) isEqualTo (_state get 'epoch')} &&
					{(_task # 4) in ['RESERVE','SCREEN']} && {({alive _x} count _members) >= 8} &&
					{(_members findIf {_x call _fn_exempt || {!isNull (objectParent _x)}}) < 0} &&
					{!(_group getVariable ['QS_primaryPressure_building',FALSE])} &&
					{((_state get 'nodes') findIf {(_x # 0) isEqualTo (_task # 5) && {!(_x # 5)}}) >= 0} &&
					{((_state get 'posts') findIf {
						(_x # 0) isNotEqualTo _group && {(_x # 1) isEqualTo (_task # 5)} && {(_x # 3) in ['DEFEND','RESERVE','SCREEN']} &&
						{((units (_x # 0)) findIf {alive _x}) >= 0}
					}) >= 0}) then {
					private _range = (leader _group) distance2D _focus;
					if (_range >= 40 && {_range < _distance}) then {_best = _group; _distance = _range;};
				};
			} forEach (_state get 'posts');
			if (!isNull _best) then {
				private _task = _best getVariable 'QS_primaryPressure_task';
				private _return = [_best,+(_task # 1),_task # 4,_task # 5];
				[_best,_focus,'CONTEST',_task # 5] call _fn_activate;
				if (((_best getVariable 'QS_primaryPressure_task') # 4) isEqualTo 'CONTEST') then {
					_groups pushBack _return; _job set [5,_dispatched + 1];
					_sent = TRUE; _room = _room - 1;
					_state set ['nextDispatch',_now + 20 + random 20];
					diag_log format ['[PrimaryAO] CASUALTY_RESPONSE epoch=%1 group=%2 area=%3 expires=%4',_state get 'epoch',_best,mapGridPosition _focus,_ends];
				};
			};
		};
	} forEach _jobs;
};
private _fn_cancelBuild = {
	params ['_group'];
	// Admission may be withdrawn while creating a squad. Administrative partial
	// squads are cancelled; combat casualties in a fully built squad are retained.
	{
		if ((_x getVariable ['QS_primaryPressure_entityEpoch',-1]) isEqualTo (_state get 'epoch') && {!(_x call _fn_exempt)}) then {
			if (!isNull (objectParent _x)) then {(objectParent _x) deleteVehicleCrew _x;} else {deleteVehicle _x;};
		};
	} forEach (units _group);
	{if ((_x # 4) isEqualTo _group) then {[_x # 1] call _fn_deleteChute;};} forEach (_state get 'air');
	_group setVariable ['QS_primaryPressure_building',FALSE,FALSE];
	diag_log format ['[PrimaryAO] BUILD_CANCEL epoch=%1',_state get 'epoch'];
};

private _fn_deleteChute = {
	params ['_chute'];
	// Dismounts are asynchronous on the network. Never delete a live passenger
	// just because a moveOut command was issued in this same scheduler slice.
	if (!isNull _chute && {((crew _chute) findIf {alive _x || {isPlayer _x}}) < 0}) then {
		deleteVehicleCrew _chute;
		deleteVehicle _chute;
	};
};

if (_mode isEqualTo 'INIT') exitWith {
	params ['','_pos','_radius','_hq','_initial','_localCap','_infAllowed','_vehAllowed'];
	private _enabled = (worldName isEqualTo 'Altis') && {missionNamespace getVariable ['QS_primaryPressure_enabled',TRUE]};
	private _epoch = 1 + (missionNamespace getVariable ['QS_primaryPressure_epoch',0]);
	missionNamespace setVariable ['QS_primaryPressure_epoch',_epoch,TRUE];
	missionNamespace setVariable ['QS_primaryPressure_running',_enabled,TRUE];
	missionNamespace setVariable ['QS_primaryPressure_forAO',_enabled,FALSE];
	if (!_enabled) exitWith {FALSE};
	private _nodes = [];
	private _commander = missionNamespace getVariable ['QS_csatCommander',objNull];
	if (!isNull _commander) then {_nodes pushBack ['HQ',+_hq,'OBJECT',_commander,'',FALSE,[]];};
	{
		_x params ['_type','','_required','_args'];
		if (_type in ['RADIOTOWER','JAMMER'] && {_required isEqualTo 1} && {_args isNotEqualTo []}) then {
			_nodes pushBack [_type,getPosATL (_args # 0),'OBJECT',_args # 0,'',FALSE,[]];
		};
	} forEach (missionNamespace getVariable ['QS_classic_subObjectiveData',[]]);
	private _compositions = [];
	{
		if ((count _x) >= 3) then {
			private _type = _x # 1;
			private _data = _x # 2;
			if (_type in ['INTEL','GEAR','VEHICLE'] && {(count _data) >= 3}) then {
				private _flag = ['QS_virtualSectors_sub_1_active','QS_virtualSectors_sub_3_active','QS_virtualSectors_sub_2_active'] # (['INTEL','GEAR','VEHICLE'] find _type);
				_nodes pushBack [_type,+(_data # 0),'FLAG',objNull,_flag,FALSE,[]];
			};
			if ((count _data) >= 3) then {
				_compositions append (_data # 2);
				if (_type in ['INTEL','GEAR','VEHICLE']) then {
					{
						if (_x isEqualType objNull) then {
							private _guards = if (_x isKindOf 'CAManBase') then {[_x]} else {crew _x};
							{(group _x) setVariable ['QS_primaryPressure_guardNode',_type,TRUE];} forEach _guards;
						};
					} forEach (_data # 2);
				};
			};
		};
	} forEach (missionNamespace getVariable ['QS_classic_subObjectives',[]]);
	// The live mortar-pit array is separate from the optional depot/datalink list.
	// Snapshot only this AO's mortars; an empty/uncrewed pit is already neutralized.
	private _mortars = (missionNamespace getVariable ['QS_virtualSectors_aoMortars',[]]) select {_x in _initial && {_x isKindOf 'StaticMortar'}};
	if (_mortars isNotEqualTo []) then {_nodes pushBack ['MORTAR',getPosATL (_mortars # 0),'MORTARS',objNull,'',FALSE,+_mortars];};
	private _radioIndex = _nodes findIf {(_x # 0) isEqualTo 'RADIOTOWER'};
	private _tower = if (_radioIndex < 0) then {objNull} else {(_nodes # _radioIndex) # 3};
	missionNamespace setVariable ['QS_primaryPressure_context',[_epoch,+_pos,_radius,_tower,_radioIndex >= 0,_commander,(_nodes findIf {(_x # 0) isEqualTo 'INTEL'}) >= 0,TRUE],TRUE];
	missionNamespace setVariable ['QS_primaryPressure_supportOnline',TRUE,TRUE];
	['DROP_RESET','PRIMARY'] call QS_fnc_aoPressure;
	// Fix the difficulty and every time window now, even if players are at base.
	// Count connected WEST players (including pilots), never headless clients.
	// A 90-second opening grace precedes 15 minutes of random, spaced windows.
	// Empty/FPS-paused windows expire normally; arrivals never restart the clock.
	private _firePlayers = {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')} && {(side (group _x)) isEqualTo WEST}} count allPlayers;
	private _fireBudget = [_firePlayers,random 1] call _fn_fireBudget;
	private _randoms = []; for '_i' from 1 to _fireBudget do {_randoms pushBack (random 1);};
	private _firePlan = [_now + 90,_fireBudget,_randoms] call _fn_firePlan;
	_state = createHashMapFromArray [
		['epoch',_epoch],['pos',+_pos],['radius',_radius],['hq',+_hq],['nodes',_nodes],
		['posts',[]],
		['engaged',FALSE],['contactJobs',[]],['contactSerial',0],['nextContact',_now],['nextDispatch',_now],
		['casualtyJobs',[]],['casualtySeen',[]],['nextCasualty',_now + 10],
		['supportOnline',TRUE],['firePlan',_firePlan],['fireWindows',+_firePlan],
		['fireBudget',_fireBudget],['fireLimit',_fireBudget],['fireUsed',0],['firePlayers',_firePlayers],['fireHandle',scriptNull],['mortarMarkers',[]],
		['commander',_commander],['tower',missionNamespace getVariable ['QS_radioTower',objNull]],
		['initial',[]],['seen',[]],['entities',[]],['men',[]],['vehicles',[]],['air',[]],['transports',[]],
		['worker',scriptNull],['reserved',0],['used',0],['vehicleUsed',0],['waveNumber',0],
		['profile',[0] call _fn_profile],['localCap',_localCap],['factor',1],['completed',0],['nativeTimers',createHashMap],
		['infAllowed',_infAllowed],['vehAllowed',_vehAllowed],
		['start',_now],['contact',-1],['nextWave',_now + 30],['nextVehicle',_now + 180],
		['nextHeli',_now],['liftSince',0],['liftBand',-1],['nextMobilize',_now + 30],['adopted',0],
		['finalNext',1e10],['finalEvents',0],['finalArmor',0],['finalClosed',FALSE],['finalReports',[]],
		['phase','CONTACT'],['perfOK',FALSE],['healthySince',-1],['ending',FALSE],['lowSince',-1]
	];
	missionNamespace setVariable ['QS_primaryPressure_state',_state,FALSE];
	if (_mortars isNotEqualTo []) then {
		private _rough = (getPosATL (_mortars # 0)) getPos [random 60,random 360];
		private _area = createMarker ['QS_primaryPressure_mortarArea',_rough];
		_area setMarkerShape 'ELLIPSE'; _area setMarkerBrush 'Border';
		_area setMarkerSize [125,125]; _area setMarkerColor 'ColorOPFOR';
		private _icon = createMarker ['QS_primaryPressure_mortarIcon',_rough];
		_icon setMarkerType 'mil_dot'; _icon setMarkerColor 'ColorOPFOR'; _icon setMarkerText 'Mortar Pit';
		_state set ['mortarMarkers',[_area,_icon]];
	};
	private _camp = (missionNamespace getVariable ['QS_enemyJungleCamp_array',[]]) select {_x isEqualType objNull && {(_x distance2D _pos) < (_radius + 200)}};
	// Depot/datalink composition infantry are dedicated guards. Keep the
	// exact composition membership; proximity alone cannot identify a guard.
	{
		if (_x isEqualType objNull) then {
			private _guards = if (_x isKindOf 'CAManBase') then {[_x]} else {crew _x};
			{(group _x) setVariable ['QS_primaryPressure_guard',TRUE,TRUE];} forEach _guards;
		};
	} forEach _compositions;
	[_initial + _compositions + _camp] call _fn_track;
	call _fn_objectives;
	// Refresh the existing tasks so the briefing matches the objective rules.
	// Each objective weakens reinforcements; internal percentages stay out of task text.
	if (['QS_IA_TASK_AO_1'] call BIS_fnc_taskExists) then {
		['QS_IA_TASK_AO_1',['Destroy the radio tower to reduce enemy artillery support and reinforcement strength. The tower is somewhere within the marked circle.',localize 'STR_QS_Task_004',localize 'STR_QS_Task_004']] call BIS_fnc_taskSetDescription;
	};
	if (['QS_IA_TASK_AO_0'] call BIS_fnc_taskExists) then {
		private _title = format ['%1 %2',localize 'STR_QS_Notif_123',missionNamespace getVariable ['QS_aoDisplayName','']];
		['QS_IA_TASK_AO_0',['Seize the enemy HQ and neutralize the marked objectives. Each objective weakens enemy reinforcements. Neutralizing the commander, Radio Tower and Datalink each reduces the enemy artillery allowance. Expect reserves to defend the remaining positions. Once all objectives are secured, clear the surviving ground force around HQ.',_title,_title]] call BIS_fnc_taskSetDescription;
	};
	diag_log format ['[PrimaryAO] FIRE_PLAN epoch=%1 allowance=%2 players=%3 windows=%4',_epoch,_fireBudget,_firePlayers,_firePlan];
	diag_log format ['[PrimaryAO] INIT epoch=%1 objectives=%2 localCap=%3',_epoch,_nodes apply {_x # 0},_localCap];
	TRUE
};
if ((count _state) isEqualTo 0) exitWith {FALSE};

if (_mode isEqualTo 'STOP') exitWith {
	missionNamespace setVariable ['QS_primaryPressure_running',FALSE,TRUE];
	missionNamespace setVariable ['QS_primaryPressure_forAO',FALSE,FALSE];
	missionNamespace setVariable ['QS_primaryPressure_context',[],TRUE];
	missionNamespace setVariable ['QS_primaryPressure_supportOnline',FALSE,TRUE];
	{deleteMarker _x;} forEach (_state get 'mortarMarkers');
	private _worker = _state get 'worker';
	if (!scriptDone _worker) then {terminate _worker;};
	// LIFECYCLE_PRIMARY_STOP_BEGIN
	// Type-0 artillery creates no helpers. Cancel before native roster cleanup;
	// aircraft fire missions retain their own laser/assistant finalizers.
	private _fireHandle = _state get 'fireHandle';
	if (!scriptDone _fireHandle) then {terminate _fireHandle;};
	missionNamespace setVariable ['QS_primaryPressure_fireCheck',0,FALSE];
	['ARTY_TICK'] call QS_fnc_aoPressure;
	private _wind = missionNamespace getVariable ['QS_primaryPressure_wind',createHashMap];
	if ((_wind getOrDefault ['activity','']) isEqualTo 'PRIMARY') then {
		missionNamespace setVariable ['QS_primaryPressure_wind',createHashMap,FALSE];
	};
	// LIFECYCLE_PRIMARY_STOP_END
	_state set ['reserved',0];
	// Return owned units/vehicles to the existing Classic cleanup exactly once.
	// Chutes are disposable delivery objects and are cleaned here immediately.
	{[_x # 1] call _fn_deleteChute;} forEach (_state get 'air');
	private _entities = (_state get 'entities') select {
		(_x getVariable ['QS_primaryPressure_entityEpoch',-1]) isEqualTo (_state get 'epoch') &&
		{!(_x call _fn_exempt)} && {!((vehicle _x) call _fn_exempt)} &&
		{((crew (vehicle _x)) findIf {_x call _fn_exempt}) < 0}
	};
	diag_log format ['[PrimaryAO] STOP epoch=%1 menCreated=%2 vehiclesCreated=%3 objects=%4',_state get 'epoch',_state get 'used',_state get 'vehicleUsed',count _entities];
	missionNamespace setVariable ['QS_primaryPressure_finalIntel',[],TRUE];
	missionNamespace setVariable ['QS_primaryPressure_status',[],FALSE];
	missionNamespace setVariable ['QS_primaryPressure_state',createHashMap,FALSE];
	_entities
};
if (!(missionNamespace getVariable ['QS_primaryPressure_running',FALSE])) exitWith {FALSE};
if (!(missionNamespace getVariable ['QS_classic_AI_active',FALSE])) exitWith {FALSE};
if (missionNamespace getVariable ['QS_defendActive',FALSE]) exitWith {FALSE};
private _pos = _state get 'pos';
private _radius = _state get 'radius';
private _epoch = _state get 'epoch';
// The framework recycler clears unit variables when reusing an object. A stale
// object handle must not claim a unit now serving another activity.
if (_mode in ['TICK','CLEAR','WORK','NATIVE']) then {
	_state set ['men',(_state get 'men') select {(_x getVariable ['QS_primaryPressure_entityEpoch',-1]) isEqualTo _epoch}];
};
if (_mode in ['TICK','CLEAR']) then {
	_state set ['seen',(_state get 'seen') select {!isNull _x}];
	_state set ['entities',(_state get 'entities') select {!isNull _x && {(_x getVariable ['QS_primaryPressure_entityEpoch',-1]) isEqualTo _epoch}}];
	_state set ['initial',(_state get 'initial') select {(_x getVariable ['QS_primaryPressure_initialEpoch',-1]) isEqualTo _epoch}];
	_state set ['vehicles',(_state get 'vehicles') select {(_x getVariable ['QS_primaryPressure_entityEpoch',-1]) isEqualTo _epoch}];
};

private _fn_fireReady = {
	if (!(missionNamespace getVariable ['QS_primaryPressure_running',FALSE]) ||
		{!(missionNamespace getVariable ['QS_classic_AI_active',FALSE])} ||
		{missionNamespace getVariable ['QS_defendActive',FALSE]} ||
		{_epoch isNotEqualTo (missionNamespace getVariable ['QS_primaryPressure_epoch',-1])}) exitWith {FALSE};
	// Completion can change between the regular three-second AI passes.
	call _fn_objectives;
	private _windows = _state get 'fireWindows';
	if (_windows isEqualTo [] || {!(_state get 'supportOnline')} || {diag_fps < 18} ||
		{!scriptDone (_state get 'fireHandle')} || {!(_state get 'perfOK')} ||
		{(missionNamespace getVariable ['QS_primaryPressure_groundCount',0]) <= 8} ||
		{!(['ARTY_ALLOWED',_state get 'hq'] call QS_fnc_aoPressure)}) exitWith {FALSE};
	private _window = _windows # 0;
	_now >= (_window # 0) && {_now <= (_window # 1)} && {(_state get 'fireUsed') < (_state get 'fireLimit')}
};
if (_mode isEqualTo 'ARTY_READY') exitWith {call _fn_fireReady};
// Validate the reporting unit's snapshot, optionally replace it with a newer
// shared report, then freeze the aim point. Never follow a player during a salvo.
// Runs only at a scheduled opportunity; the bounded AI scan is not a new loop.
private _fn_mortarAim = {
	params ['_args'];
	private _report = _args param [5,[]];
	if ((count _report) < 3) exitWith {[]};
	_report params ['_target','_point','_seen'];
	_target = vehicle _target;
	if ((_target call QS_fnc_groundTargetPriority) < 0 ||
		{_target isKindOf 'CAManBase' && {!(lifeState _target in ['HEALTHY','INJURED'])}}) exitWith {[]};
	private _intel = missionNamespace getVariable ['QS_AI_targetsIntel',[]];
	private _index = _intel findIf {(vehicle (_x # 0)) isEqualTo _target && {(_x # 1) > _seen} && {(_x # 3) > 3}};
	if (_index >= 0) then {_point = +((_intel # _index) # 2); _seen = (_intel # _index) # 1;};
	if (!([serverTime,_seen,30] call _fn_reportFresh)) exitWith {[]};
	_point = _point getPos [random 10,random 360]; _point set [2,0];
	if (surfaceIsWater _point || {(_point distance2D (_state get 'pos')) > ((_state get 'radius') + 500)} ||
		{(_point distance2D (markerPos 'QS_marker_base_marker')) <= 1000} ||
		{(_point distance2D (markerPos 'QS_marker_sideMarker')) <= 600}) exitWith {[]};
	// Protect the defending force around objectives. Keep the real artillery
	// range check and native projectile/damage/revive behavior.
	if ((((units EAST) + (units RESISTANCE)) findIf {alive _x && {(_x distance2D _point) < 75}}) >= 0) exitWith {[]};
	if (!(_point inRangeOfArtillery [[vehicle (_args # 1)],_args # 3])) exitWith {[]};
	_point
};
if (_mode isEqualTo 'ARTY_START') exitWith {
	params ['','_args'];
	private _leader = _args # 1;
	if (!local _leader || {!alive _leader}) exitWith {FALSE};
	private _started = FALSE;
	// isNil executes this short admission block without scheduled suspension.
	// Recheck objectives, then spend exactly one slot before spawning. Concurrent
	// requests cannot overspend the reduced allowance or start a second salvo.
	isNil {
		private _aimOK = TRUE;
		if ((vehicle _leader) isKindOf 'StaticMortar') then {
			private _aim = [_args] call _fn_mortarAim;
			_aimOK = _aim isNotEqualTo [];
			if (_aimOK) then {
				_args = +_args; _args set [2,_aim];
				_args set [5,[_epoch,[missionNamespace getVariable ['QS_primaryPressure_groundCount',0]] call _fn_mortarRounds]];
			};
		};
		if (_aimOK && {call _fn_fireReady}) then {
			(_state get 'fireWindows') deleteAt 0;
			_state set ['fireUsed',1 + (_state get 'fireUsed')];
			call _fn_objectives;
			private _handle = _args spawn (missionNamespace getVariable 'QS_fnc_AIFireMission');
			_state set ['fireHandle',_handle];
			private _group = group _leader;
			private _context = missionNamespace getVariable ['QS_primaryPressure_context',[]];
			_group setVariable ['QS_primaryPressure_fire',[_handle,+_context],FALSE];
			private _groups = missionNamespace getVariable ['QS_primaryPressure_fireGroups',[]];
			_groups pushBackUnique _group;
			missionNamespace setVariable ['QS_primaryPressure_fireGroups',_groups,FALSE];
			diag_log format ['[PrimaryAO] FIRE_MISSION epoch=%1 used=%2 limit=%3 original=%4',_state get 'epoch',_state get 'fireUsed',_state get 'fireLimit',_state get 'fireBudget'];
			_started = TRUE;
		};
	};
	_started
};

if (_mode isEqualTo 'CLEAR') exitWith {
	params ['','','',['_threshold',10]];
	private _done = (call _fn_objectives) <= 0;
	// Hostile guards count even though their small-task positions are protected.
	// Captives/friendly patients do not count. Aircraft remain outside ground cleanup.
	private _allEnemies = ((units EAST) + (units RESISTANCE)) select {_x call _fn_enemy};
	private _force = [_allEnemies] call _fn_force;
	private _enemies = _force select {!((vehicle _x) isKindOf 'Air')};
	// Manual Taru troops still descending also hold the final-clear timer.
	private _taruIncoming = (_force findIf {
		(_x getVariable ['QS_taruCounterattackUnit',FALSE] || {(group _x) getVariable ['QS_taruDelivery_busy',FALSE]}) &&
		{(vehicle _x) isKindOf 'Air' || {((getPosATL _x) # 2) > 3}}
	}) >= 0;
	private _incoming = _taruIncoming || {(_state get 'reserved') > 0} || {(_state get 'air') isNotEqualTo []} ||
		{((_state get 'transports') findIf {(_x # 7) in ['IN','UNLOAD','TARU']}) >= 0};
	private _decision = [_now,_state get 'lowSince',count _enemies,_threshold,_incoming,_done] call _fn_clearPolicy;
	_state set ['lowSince',_decision # 0]; 	_state set ['ending',_decision # 1];
	if (_decision # 1) then {_state set ['finalClosed',TRUE];};
	// Return the clearance decision to the native AO lifecycle. Its normal
	// DEBRIEF path supplies CompletedMain once the AO actually completes.
	_decision # 2
};

// INSERTION MONITOR: the existing AI loop checks airborne troops separately
// from the creation worker. Maximum 24 monitored parachutists and one transport.
// Confirm actual dismount before deleting a chute or assigning ground orders.
// A drop times out at 120 s or beyond 650 m drift; failed insertions are retired.
// This bounds stuck/paragliding cases instead of waiting indefinitely for a landing.
if (_mode isEqualTo 'AIR') exitWith {
	private _remaining = [];
	private _finishedGroups = [];
	{
		_x params ['_jumper','_chute','_landing','_deadline','_group','_goal','_role'];
		private _done = FALSE;
		if (isNull _jumper || {!alive _jumper}) then {
			[_chute] call _fn_deleteChute;
			_done = TRUE;
		} else {
			if (_jumper call _fn_exempt) then {
				// Relinquish player, Zeus and captive takeovers without moving them.
				_done = TRUE;
			} else {
				private _height = (getPosATL _jumper) # 2;
				if (isNull (objectParent _jumper) && {_height < 3}) then {_done = TRUE;};
				if (!_done && {local _jumper} && {isTouchingGround _jumper || {isTouchingGround _chute} || {_height < 1.8}}) then {
					unassignVehicle _jumper;
					moveOut _jumper;
					[_chute] call _fn_deleteChute;
					_done = isNull (objectParent _jumper);
				};
				if (!_done && {_now > _deadline || {isNull _chute} || {(_jumper distance2D _landing) > 650}}) then {
					// Bounded failure recovery: retire a failed insertion, never teleport
					// a stuck/paragliding AI onto players or wait indefinitely for it.
					if (!isNull (objectParent _jumper)) then {(objectParent _jumper) deleteVehicleCrew _jumper;} else {deleteVehicle _jumper;};
					[_chute] call _fn_deleteChute;
					diag_log format ['[PrimaryAO] DROP_TIMEOUT epoch=%1',_epoch];
					_done = TRUE;
				};

			};
		};
		if (_done) then {
			_finishedGroups pushBackUnique [_group,_goal,_role];
			if (isNull (objectParent _jumper)) then {[_chute] call _fn_deleteChute;};
		} else {_remaining pushBack _x;};
	} forEach (_state get 'air');
	_state set ['air',_remaining];
	{
		_x params ['_group','_goal','_role'];
		if ((_remaining findIf {(_x # 4) isEqualTo _group}) < 0) then {[_group,_goal,_role] call _fn_activate;};
	} forEach _finishedGroups;

	private _transports = [];
	{
		_x params ['_heli','_pilots','_cargo','_lz','_entry','_deadline','_goal','_phase'];
		private _keep = TRUE;
		if (_phase in ['TARU','TARU_OUT']) then {
			// The shared flight owns release, parachutes, ropes and departure.
			// Admit no landing or waypoint takeover while it is still unloading.
			if (_phase isEqualTo 'TARU' && {_heli getVariable ['QS_taruDelivery_landed',FALSE]}) then {
				[_cargo,_goal,'DEFEND'] call _fn_activate;
				_phase = 'TARU_OUT';
			};
			_keep = !scriptDone (_heli getVariable ['QS_taruDelivery_handle',scriptNull]);
		} else {
		if ((((crew _heli) + (units _pilots) + (units _cargo)) findIf {_x call _fn_exempt}) >= 0) then {
			_keep = FALSE;
		} else {
			if (_phase isEqualTo 'IN' && {scriptDone (_state get 'worker')} && {((units _cargo) findIf {alive _x}) < 0}) then {
				_phase = 'OUT'; _deadline = _now + 120;
				_heli land 'NONE'; _pilots move _entry;
			};
			if (_phase isEqualTo 'IN') then {
				if (alive _heli && {alive (driver _heli)} && {(_heli distance2D _lz) < 250}) then {_heli land 'GET OUT';};
				// Only a live flight at its assigned LZ can begin a delivery.
				// A crash or an unrelated landing follows the existing abort path.
				if (alive _heli && {canMove _heli} && {alive (driver _heli)} &&
					{_now <= _deadline} && {(_heli distance2D _lz) <= 20} &&
					{((getPosATL _heli) # 2) < 3} && {abs (speed _heli) < 5}) then {
					_phase = 'UNLOAD';
					_deadline = _now + 30;
				};
			};
			if (_phase isEqualTo 'UNLOAD') then {
					{
						if (alive _x && {(objectParent _x) isEqualTo _heli}) then {
							[_x] allowGetIn FALSE;
							unassignVehicle _x;
							moveOut _x;
						};
					} forEach (units _cargo);
				// Wait for actual dismount before releasing HC ownership or flying
				// away. A moveOut command alone is not a completed network event.
				if (((units _cargo) findIf {alive _x && {(objectParent _x) isEqualTo _heli}}) < 0) then {
					[_cargo,_goal,'DEFEND'] call _fn_activate;
					_heli land 'NONE';
					_heli flyInHeight 80;
					_pilots move _entry;
					_phase = 'OUT';
					_deadline = _now + 120;
				};
			};
			// A missed landing becomes an outbound flight with unreleased cargo.
			// Ground survivors get orders; occupied seats are never deleted here.
			if (_phase in ['IN','UNLOAD'] &&
				{_now > _deadline || {!alive _heli} || {!canMove _heli} || {!alive (driver _heli)}}) then {
				private _aboard = (units _cargo) select {!isNull _heli && {(objectParent _x) isEqualTo _heli}};
				if (!isNull _pilots) then {_aboard joinSilent _pilots;};
				[_cargo,_goal,'DEFEND'] call _fn_activate;
				_phase = 'OUT'; _deadline = _now + 120;
				if (alive _heli && {canMove _heli} && {alive (driver _heli)}) then {
					_heli land 'NONE'; _heli flyInHeight 80;
					_pilots move _entry;
				};
				diag_log format ['[PrimaryAO] HELI_ABORT epoch=%1',_epoch];
			};
			if (isNull _heli || {_phase isEqualTo 'OUT' &&
				{_now > _deadline || {!alive _heli} || {!canMove _heli} ||
					{(_heli distance2D _lz) > 1500 &&
						{(allPlayers inAreaArray [_heli,500,500,0,FALSE]) isEqualTo []}}}}) then {
				// Native deferred cleanup leaves a stuck aircraft visible and lets
				// a flyable one finish leaving. No new worker survives this record.
				{
					if (!isNull _x) then {
						(missionNamespace getVariable 'QS_garbageCollector') pushBackUnique [_x,'DELAYED_DISCREET',time + 180];
					};
				} forEach ((crew _heli) + (units _pilots) + [_heli]);
				if (!isNull _pilots && {(units _pilots) isEqualTo []}) then {deleteGroup _pilots;};
				if (!isNull _cargo && {(units _cargo) isEqualTo []}) then {deleteGroup _cargo;};
				_keep = FALSE;
			};
		};
		};
		if (_keep) then {_transports pushBack [_heli,_pilots,_cargo,_lz,_entry,_deadline,_goal,_phase];};
	} forEach (_state get 'transports');
	_state set ['transports',_transports];
};

// Existing helicopter/UAV/CAS spawners share the objective, capacity and FPS
// gates. Their original feature flags and native vehicle limits still apply.
// TARU_ADMISSION_BEGIN
// A manual Taru asks for one whole squad at a time. The normal AO ceiling,
// objective effects and performance pause remain authoritative.
if (_mode isEqualTo 'TARU_ADMIT') exitWith {
	params ['',['_quantity',8]];
	private _factor = call _fn_objectives;
	if (_factor <= 0 || {_state get 'ending'} || {!(_state get 'perfOK')} || {diag_fps < 18} ||
		{!(_state get 'infAllowed')} || {missionNamespace getVariable ['QS_primaryPressure_paused',FALSE]} ||
		{!scriptDone (_state get 'worker')} || {(_state get 'reserved') > 0}) exitWith {FALSE};
	private _humans = (call _fn_humans) inAreaArray [_pos,_radius + 600,_radius + 600,0,FALSE];
	if (_humans isEqualTo []) exitWith {FALSE};
	private _profile = [count _humans] call _fn_profile;
	private _enemies = ((units EAST) + (units RESISTANCE)) select {_x call _fn_enemy};
	private _area = [_enemies] call _fn_force;
	private _local = {local _x && {!isPlayer _x} && {alive _x} && {simulationEnabled _x} && {!isObjectHidden _x}} count allUnits;
	private _live = {_x call _fn_enemy} count (_state get 'men');
	([_quantity,_live,_profile # 1,count _area,[_profile # 2,_factor] call _fn_forceCap,_local,_state get 'localCap',count _enemies,200,0] call _fn_room) >= _quantity
};
// TARU_ADMISSION_END

if (_mode isEqualTo 'NATIVE') exitWith {
	params ['','_kind','_delay'];
	private _factor = call _fn_objectives;
	if (_kind isEqualTo 'UAV' && {['INTEL'] call _fn_secured}) exitWith {FALSE};
	if (_factor <= 0 || {!(_state get 'perfOK')} || {diag_fps < 18} ||
		{(missionNamespace getVariable ['QS_primaryPressure_paused',FALSE] || {diag_tickTime < ((missionNamespace getVariable ['QS_taruBuild',[-1,-1,0]]) # 2)})} || {!scriptDone (_state get 'worker')}) exitWith {FALSE};
	private _humans = (call _fn_humans) inAreaArray [_pos,_radius + 600,_radius + 600,0,FALSE];
	if (_humans isEqualTo []) exitWith {FALSE};
	private _profile = [count _humans] call _fn_profile;
	private _enemies = ((units EAST) + (units RESISTANCE)) select {_x call _fn_enemy};
	private _area = [_enemies] call _fn_force;
	private _local = {local _x && {!isPlayer _x} && {alive _x} && {simulationEnabled _x} && {!isObjectHidden _x}} count allUnits;
	private _live = {_x call _fn_enemy} count (_state get 'men');
	if (([4,_live,_profile # 1,count _area,[_profile # 2,_factor] call _fn_forceCap,_local,_state get 'localCap',count _enemies,200,_state get 'reserved'] call _fn_room) < 4) exitWith {FALSE};
	private _timers = _state get 'nativeTimers';
	if (_now < (_timers getOrDefault [_kind,0])) exitWith {FALSE};
	// The existing AI loop calls the native spawner immediately after this gate;
	// no Primary creation worker can start until that call returns.
	_timers set [_kind,_now + _delay];
	_state set ['reserved',4];
	TRUE
};

if (_mode isEqualTo 'NATIVE_DONE') exitWith {
	[_this param [1,[]]] call _fn_track;
	_state set ['reserved',0];
};

// REINFORCEMENT DECISION: update objectives/counts, then allocate a delivery.
// Reuses the Classic AI pass at about three-second intervals. No missed-wave backlog.
// New arrivals need ground players, healthy FPS, objective demand and free capacity.
// Retask at most two existing groups per 12 s, or four per 3 s in the final HQ phase.
if (_mode isEqualTo 'TICK') exitWith {
	params ['',['_native',[]]];
	[_native] call _fn_track;
	private _factor = call _fn_objectives;
	if (scriptDone (_state get 'worker')) then {
		_state set ['reserved',0];
		private _building = [];
		{if ((group _x) getVariable ['QS_primaryPressure_building',FALSE]) then {_building pushBackUnique (group _x);};} forEach (_state get 'men');
		{[_x] call _fn_cancelBuild;} forEach _building;
	};
	private _humans = (call _fn_humans) inAreaArray [_pos,_radius + 600,_radius + 600,0,FALSE];
	private _profile = [count _humans] call _fn_profile;
	_profile params ['_waveSize','_liveCap','_areaCap','_minInterval','_maxInterval','_hqTarget','_vehicleCap','_subTarget'];
	_areaCap = [_areaCap,_factor] call _fn_forceCap;
	// Returning after a wipe or dropping into a smaller tier grants breathing
	// room. Do not deliver an overdue wave as soon as a lone player returns.
	if (_humans isEqualTo []) then {
		_state set ['nextWave',_now + (((_state get 'profile') # 3) max 20)];
	} else {
		if (_minInterval > ((_state get 'profile') # 3)) then {
			_state set ['nextWave',(_state get 'nextWave') max (_now + _minInterval)];
		};
	};
	if ((missionNamespace getVariable ['QS_primaryPressure_groundCount',-1]) isNotEqualTo (count _humans)) then {missionNamespace setVariable ['QS_primaryPressure_groundCount',count _humans,TRUE];};
	if (_humans isNotEqualTo []) then {_state set ['profile',_profile];};
	if (_humans isNotEqualTo [] && {(_state get 'contact') < 0}) then {
		_state set ['contact',_now];
		if (_factor > 0) then {_state set ['phase','ACTIVE'];};
		_state set ['nextWave',(_state get 'nextWave') max (_now + _minInterval)];
		_state set ['nextVehicle',_now + 180];
	};
	private _windows = _state get 'fireWindows';
	// At most nine entries; discard missed opportunities without catch-up fire.
	for '_i' from 1 to 9 do {
		if (_windows isEqualTo [] || {_now <= ((_windows # 0) # 1)}) exitWith {};
		_windows deleteAt 0;
	};
	private _performance = [_now,diag_fps,_state get 'perfOK',_state get 'healthySince'] call _fn_performance;
	_state set ['perfOK',_performance # 0]; _state set ['healthySince',_performance # 1];
	// Keep the admission flag current; count fields describe the last census.
	private _status = missionNamespace getVariable ['QS_primaryPressure_status',[]];
	if ((count _status) >= 12) then {_status set [10,_state get 'perfOK'];};

	call _fn_contactTick;
	// Preserve initial patrols until observed contact. Then gradually assign
	// mobile squads. Guards fall back when their objective is secured, and
	// every surviving main-AO group joins the final HQ regroup.
	if (_now >= (_state get 'nextMobilize') && {diag_fps >= 12} && {_factor <= 0 || {_humans isNotEqualTo [] && {_state get 'engaged'}}}) then {
		private _final = _factor <= 0;
		_state set ['nextMobilize',_now + ([12,3] select _final)];
		private _roster = (_state get 'initial') + (_state get 'men');
		private _groups = [];
		{
			if (_x isKindOf 'CAManBase' && {_x call _fn_enemy}) then {_groups pushBackUnique (group _x);};
		} forEach _roster;
		private _assigned = 0;
		{
			private _group = _x;
			private _members = units _group;
			private _task = _group getVariable ['QS_primaryPressure_task',[]];
			private _key = _group getVariable ['QS_primaryPressure_node',''];
			private _parent = objectParent (leader _group);
			private _needs = (_task param [0,-1]) isNotEqualTo _epoch ||
				{_final && {(_task param [5,'']) isNotEqualTo 'FINAL'}} ||
				{!_final && {((_state get 'nodes') findIf {(_x # 0) isEqualTo _key && {!(_x # 5)}}) < 0}};
			private _guard = _group getVariable ['QS_primaryPressure_guard',FALSE];
			private _guardKey = _group getVariable ['QS_primaryPressure_guardNode',''];
			private _guardReleased = ((_state get 'nodes') findIf {(_x # 0) isEqualTo _guardKey && {_x # 5}}) >= 0;
			if (_assigned < ([2,4] select _final) && {_needs} &&
				{_final || {!_guard} || {_guardReleased}} &&
				{!(_group getVariable ['QS_primaryPressure_building',FALSE])} &&
				{(_members findIf {_x call _fn_exempt || {!(_x in _roster)} || {_x isEqualTo (_state get 'commander')}}) < 0} &&
				{(_members findIf {alive _x}) >= 0} &&
				{((_state get 'air') findIf {(_x # 4) isEqualTo _group}) < 0} &&
				{((_state get 'transports') findIf {_group isEqualTo (_x # 1) || {_group isEqualTo (_x # 2) && {(_x # 7) in ['IN','UNLOAD']}}}) < 0} &&
				{_final || {isNull _parent && {_guardReleased || {({alive _x} count _members) <= 12}}}}
			) then {
				private _role = ['DEFEND','RESERVE'] select (((_state get 'adopted') mod 4) isEqualTo 3);
				// Retain some of the native dispersed patrol routes between the
				// objectives. These patrols report contacts but are not borrowed.
				if (!_guard && {!_final} && {_role isEqualTo 'RESERVE'} &&
					{((_group getVariable ['QS_AI_GRP_TASK',[]]) param [0,'']) isEqualTo 'PATROL'}) then {_role = 'PATROL';};
				[_group,_state get 'hq',_role] call _fn_activate;
				_state set ['adopted',1 + (_state get 'adopted')]; _assigned = _assigned + 1;
			};
		} forEach _groups;
	};
	[_humans] call _fn_casualties;
	// A wipe pauses arrivals; it never completes, fails, or resets this AO.
	private _final = _factor <= 0;
	if (_humans isEqualTo [] || {!(_state get 'perfOK')} || {_state get 'ending'} ||
		{(missionNamespace getVariable ['QS_primaryPressure_paused',FALSE] || {diag_tickTime < ((missionNamespace getVariable ['QS_taruBuild',[-1,-1,0]]) # 2)})} || {!scriptDone (_state get 'worker')}) exitWith {};
	// Objectives, reported contacts, casualty expiry and regroup above always
	// run. Only the expensive spawn census waits for an actual opportunity.
	if (!([_now,_final,_state get 'infAllowed',_state get 'nextWave',_state get 'vehAllowed',
		_state get 'nextVehicle',_vehicleCap,['VEHICLE'] call _fn_secured] call _fn_arrivalDue)) exitWith {};
	private _enemies = ((units EAST) + (units RESISTANCE)) select {_x call _fn_enemy};
	private _area = [_enemies] call _fn_force;
	private _live = (_state get 'men') select {_x call _fn_enemy};
	missionNamespace setVariable ['QS_primaryPressure_status',[_epoch,_state get 'phase',count _humans,_state get 'completed',count (_state get 'nodes'),_factor,count _area,count _live,_areaCap,_state get 'reserved',_state get 'perfOK',_state get 'used'],FALSE];
	_state set ['censusAt',_now];
	if (_final) then {_areaCap = [_profile # 2,0.2] call _fn_forceCap;};
	private _localCount = {local _x && {!isPlayer _x} && {alive _x} && {simulationEnabled _x} && {!isObjectHidden _x}} count allUnits;
	private _room = [_waveSize + 1,count _live,_liveCap,count _area,_areaCap,_localCount,_state get 'localCap',count _enemies,200,_state get 'reserved'] call _fn_room;
	if (({side _x isEqualTo EAST} count allGroups) >= 220 || {_room < 4}) exitWith {};
	private _goal = [];
	private _key = '';
	private _delivery = '';
	private _quantity = 0;
	if (_final) then {
		private _ground = {!((objectParent _x) isKindOf 'Air')} count _area;
		if (_ground < 10) then {_state set ['finalClosed',TRUE];};
		if (_now >= (_state get 'finalNext')) then {
			private _ready = [_now,_state get 'finalNext',_ground,_state get 'finalClosed',_state get 'finalEvents',random 1,count _humans] call _fn_finalReady;
			_state set ['finalNext',_now + 90 + random 60];
			private _reports = (_state get 'finalReports') select {[serverTime,_x # 2,45] call _fn_reportFresh};
			if (_ready && {_reports isNotEqualTo []}) then {
				_goal = +((selectRandom _reports) # 1); _key = 'FINAL_RESERVE';
				private _roll = random 1;
				if (_roll < 0.7 && {_state get 'infAllowed'} && {_room >= 8}) then {
					_quantity = 8; _delivery = ['GROUND','PARA'] select (random 1 < 0.6 && {count (_state get 'air') <= 16});
				};
				// Regional reserve: at most one armor admission.
				// Depot loss still stops the normal local replacement stream.
				if (_roll >= 0.7 && {_roll < 0.9} && {_state get 'vehAllowed'} && {_vehicleCap > 0} && {(_state get 'finalArmor') < 1}) then {
					_delivery = 'VEHICLE'; _quantity = 4;
				};
			};
		};
	} else {
		private _choice = [_profile] call _fn_chooseNode;
		if (_choice isNotEqualTo []) then {
			_goal = +((_choice # 0) # 1); _key = (_choice # 0) # 0;
			if (_state get 'vehAllowed' && {!(['VEHICLE'] call _fn_secured)} && {_now >= (_state get 'nextVehicle')} && {_vehicleCap > 0}) then {
				private _liveVehicles = {alive _x && {((crew _x) findIf {_x call _fn_enemy}) >= 0}} count (_state get 'vehicles');
				if (_liveVehicles < _vehicleCap) then {_delivery = 'VEHICLE'; _quantity = 4;};
				_state set ['nextVehicle',_now + 180 + random 60];
			};
			if (_delivery isEqualTo '' && {_state get 'infAllowed'} && {_now >= (_state get 'nextWave')} &&
				{(_choice # 1) >= 8} && {_room >= 8}) then {
				_quantity = [_waveSize,_room,_choice # 1] call _fn_squadSize;
				_delivery = 'GROUND';
				// Three of five eligible deliveries prefer visible parachutes.
				private _paraRoom = 24 - count (_state get 'air');
				if (((_state get 'waveNumber') mod 5) in [0,2,3] && {_paraRoom >= _quantity}) then {_delivery = 'PARA';};
				// Connected humans choose the delivery method; nearby ground turnout
				// continues to choose strength, pacing and the total personnel ceiling.
				private _connected = {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}} count allPlayers;
				private _band = [0,1] select (_connected >= 20);
				if (_band isNotEqualTo (_state get 'liftBand')) then {_state set ['liftSince',0]; _state set ['liftBand',_band];};
				private _liftSize = [_waveSize,_room,_choice # 1,1] call _fn_squadSize;
				private _flightCap = [3,1] select (_connected >= 20);
				private _ready = _now >= (_state get 'nextHeli') && {count (_state get 'transports') < _flightCap} && {_room >= 9};
				if (_connected < 20 && {_room >= 9} && {!_ready}) exitWith {_delivery = ''; _quantity = 0;};
				if (['TARU_POLICY',_connected,_state get 'liftSince',_liftSize,_ready,random 1] call QS_fnc_AIXHeliInsert) then {
					_delivery = 'HELI'; _quantity = _liftSize;
				};
				// A smaller full squad does not shorten this population's interval.
				_state set ['nextWave',_now + _minInterval + random (_maxInterval - _minInterval)];
			};
		};
	};
	if (_delivery isEqualTo '' || {_quantity < 4} || {_quantity > _room}) exitWith {};
	if (_final) then {
		_state set ['finalEvents',1 + (_state get 'finalEvents')];
		if (_delivery isEqualTo 'VEHICLE') then {_state set ['finalArmor',1];};
	};
	_state set ['reserved',_quantity + ([0,1] select (_delivery isEqualTo 'HELI'))];
	_state set ['worker',['WORK',_epoch,_delivery,_quantity,_goal,_profile,_key] spawn QS_fnc_aoPressure];
};

// CREATION WORKER: one delivery at a time, with full capacity reserved first.
// Ground arrivals need concealment; all infantry spawn points exclude nearby players.
// Infantry creation yields 0.35 s per man and rechecks current conditions each pass.
// Losing admission cancels an incomplete squad; complete squads keep combat losses.
if (_mode isEqualTo 'WORK') exitWith {
	params ['','_workEpoch','_delivery','_quantity','_goal','_profile','_key'];
	if (!canSuspend || {_workEpoch isNotEqualTo _epoch}) exitWith {};
	private _finalReserve = _key isEqualTo 'FINAL_RESERVE';
	private _fn_current = {
		(missionNamespace getVariable ['QS_primaryPressure_running',FALSE]) &&
		{missionNamespace getVariable ['QS_classic_AI_active',FALSE]} &&
		{(missionNamespace getVariable ['QS_primaryPressure_epoch',-1]) isEqualTo _workEpoch}
	};
	private _fn_admit = {
		if (!(call _fn_current)) exitWith {FALSE};
		if ((missionNamespace getVariable ['QS_primaryPressure_paused',FALSE] || {diag_tickTime < ((missionNamespace getVariable ['QS_taruBuild',[-1,-1,0]]) # 2)})) exitWith {FALSE};
		if (diag_fps < 18 || {_state get 'ending'}) exitWith {FALSE};
		private _factor = call _fn_objectives;
		if (_finalReserve && {_factor > 0 || {_state get 'finalClosed'}}) exitWith {FALSE};
		if (!_finalReserve && {_factor <= 0}) exitWith {FALSE};
		if (!_finalReserve && {_delivery isEqualTo 'VEHICLE'} && {['VEHICLE'] call _fn_secured}) exitWith {FALSE};
		if (!_finalReserve && {((_state get 'nodes') findIf {(_x # 0) isEqualTo _key && {!(_x # 5)}}) < 0}) exitWith {FALSE};
		private _humans = (call _fn_humans) inAreaArray [_pos,_radius + 600,_radius + 600,0,FALSE];
		if (_humans isEqualTo []) exitWith {FALSE};
		private _currentProfile = [count _humans] call _fn_profile;
		if (_finalReserve && {count _humans <= 15}) exitWith {FALSE};
		private _enemy = ((units EAST) + (units RESISTANCE)) select {_x call _fn_enemy};
		private _area = [_enemy] call _fn_force;
		if (_finalReserve && {({!((objectParent _x) isKindOf 'Air') && {!((group _x) getVariable ['QS_primaryPressure_building',FALSE])}} count _area) < 10}) exitWith {
			_state set ['finalClosed',TRUE]; FALSE
		};
		private _local = {local _x && {!isPlayer _x} && {alive _x} && {simulationEnabled _x} && {!isObjectHidden _x}} count allUnits;
		private _live = {(_x call _fn_enemy)} count (_state get 'men');
		// Verify remaining reservations against fresh counts after every yield.
		(_live + (_state get 'reserved')) <= (_currentProfile # 1) &&
		{((count _area) + (_state get 'reserved')) <= ([_currentProfile # 2,[_state get 'factor',0.2] select _finalReserve] call _fn_forceCap)} &&
		{(_local + (_state get 'reserved')) <= (_state get 'localCap')} &&
		{((count _enemy) + (_state get 'reserved')) <= 200} &&
		{({side _x isEqualTo EAST} count allGroups) < 220}
	};
	private _fn_charge = {
		_state set ['used',1 + (_state get 'used')];
		_state set ['reserved',0 max ((_state get 'reserved') - 1)];
	};
	// STOP can terminate this scheduled worker at any suspension boundary. Keep
	// object creation and cleanup registration in one unscheduled transaction so
	// every successfully created entity is owned before cancellation can run.
	private _fn_createRegisteredVehicle = {
		params ['_args'];
		private _vehicle = objNull;
		isNil {
			_vehicle = createVehicle _args;
			if (!isNull _vehicle) then {[_vehicle] call _fn_register;};
		};
		_vehicle
	};
	private _fn_createRegisteredUnit = {
		params ['_group','_args'];
		private _unit = objNull;
		isNil {
			_unit = _group createUnit _args;
			if (!isNull _unit) then {[_unit] call _fn_register;};
		};
		_unit
	};
	private _fn_concealed = {
		params ['_point','_players'];
		private _viewers = _players inAreaArray [_point,900,900,0,FALSE];
		private _targetASL = (ATLToASL _point) vectorAdd [0,0,1.5];
		(_viewers findIf {
			!(terrainIntersectASL [eyePos _x,_targetASL]) &&
			{!lineIntersects [eyePos _x,_targetASL,_x,objNull]}
		}) < 0
	};
	// Try at most 18 insertion positions, yielding between attempts. Reject
	// water, steep slopes, base proximity and nearby players; concealed ground
	// entry also checks sight lines. If no suitable position exists, skip/fallback.
	private _fn_position = {
		params ['_anchor','_min','_max','_exclusion','_hidden',['_heli',FALSE],['_vehicle',FALSE]];
		private _chosen = [];
		private _players = allPlayers select {!(_x isKindOf 'HeadlessClient_F') && {alive _x}};
		private _base = markerPos 'QS_marker_base_marker';
		for '_attempt' from 1 to 18 do {
			if (!(call _fn_current)) exitWith {};
			private _candidate = _anchor getPos [_min + random (_max - _min),random 360];
			if (_vehicle) then {
				private _roads = _candidate nearRoads 100;
				_roads = _roads select {(roadsConnectedTo _x) isNotEqualTo []};
				if (_roads isNotEqualTo []) then {_candidate = getPosATL (_roads # 0);};
			};
			if (
				(_candidate # 0) > 50 && {(_candidate # 1) > 50} &&
				{(_candidate # 0) < (worldSize - 50)} && {(_candidate # 1) < (worldSize - 50)} &&
				{!surfaceIsWater _candidate} && {(_candidate distance2D _base) > 1200} &&
				{(_candidate distance2D _pos) < (_radius + 500)} &&
				{(_players inAreaArray [_candidate,_exclusion,_exclusion,0,FALSE]) isEqualTo []} &&
				{((surfaceNormal _candidate) # 2) > 0.90} &&
				{!([_candidate,_anchor,25] call QS_fnc_waterIntersect)}
			) then {
				private _flat = TRUE;
				if (_heli) then {
					_flat = (_candidate isFlatEmpty [15,-1,0.2,20,0,FALSE,objNull]) isNotEqualTo [];
					_flat = _flat && {(nearestTerrainObjects [_candidate,['TREE','SMALL TREE','BUILDING','HOUSE'],22,FALSE,TRUE]) isEqualTo []};
				};
				if (_flat && {!_hidden || {[_candidate,_players] call _fn_concealed}}) exitWith {_chosen = _candidate;};
			};
			if (_chosen isNotEqualTo []) exitWith {};
			uiSleep 0.02;
		};
		_chosen
	};
	private _landing = if (_delivery isEqualTo 'VEHICLE') then {
		[_goal,600,1000,400,TRUE,FALSE,TRUE] call _fn_position
	} else {
		[_goal,200,400,180,_delivery isEqualTo 'GROUND',FALSE,FALSE] call _fn_position
	};
	// Open terrain can make a concealed ground arrival impossible. A failed
	// ground/heli search must not pin the delivery pattern to that mode forever.
	if (_landing isEqualTo [] && {_delivery in ['GROUND','HELI']} &&
		{(count (_state get 'air')) + _quantity <= 24} && {call _fn_admit}) then {
		_delivery = 'PARA';
		_state set ['reserved',_quantity];
		_landing = [_goal,200,400,180,FALSE,FALSE,FALSE] call _fn_position;
	};
	if (_landing isEqualTo [] || {!(call _fn_admit)}) exitWith {
		_state set ['reserved',0];
		diag_log format ['[PrimaryAO] DELIVERY_SKIPPED epoch=%1 type=%2',_epoch,_delivery];
	};

	if (_delivery isEqualTo 'VEHICLE') exitWith {
		private _class = selectRandom ['O_MRAP_02_hmg_F','O_APC_Wheeled_02_rcws_v2_F'];
		_class = QS_core_vehicles_map getOrDefault [toLowerANSI _class,_class];
		private _slots = ['VEHICLE_SLOTS',_landing,1,(_landing getDir _goal),_class,TRUE,TRUE,400,{
			params ['_point'];
			(_point distance2D (markerPos 'QS_marker_base_marker')) > 1200 &&
			{(_point distance2D _pos) < (_radius + 500)} && {!([_point,_goal,25] call QS_fnc_waterIntersect)}
		}] call QS_fnc_spawnGroup;
		private _empty = _slots param [0,[]];
		if (_empty isNotEqualTo [] && {!surfaceIsWater _empty} && {(allPlayers inAreaArray [_empty,400,400,0,FALSE]) isEqualTo []} && {[_empty,allPlayers] call _fn_concealed} && {isClass (configFile >> 'CfgVehicles' >> _class)} && {call _fn_admit}) then {
			private _vehicle = [[_class,_empty,[],0,'NONE']] call _fn_createRegisteredVehicle;
			if (!isNull _vehicle) then {
				private _crew = grpNull;
				isNil {
					_crew = createVehicleCrew _vehicle;
					{[_x] call _fn_register;} forEach (units _crew);
				};
				private _members = units _crew;
				if (isNull _crew || {(count _members) > 4} || {_members isEqualTo []} || {(WEST getFriend (side _crew)) >= 0.6}) then {
					deleteVehicleCrew _vehicle; deleteVehicle _vehicle;
				} else {
					{[_x] call _fn_charge; _x call QS_fnc_unitSetup;} forEach _members;
					[_members,1] call QS_fnc_serverSetAISkill;
					_vehicle setVariable ['QS_dynSim_ignore',TRUE,TRUE];
					_vehicle enableDynamicSimulation FALSE;
					_vehicle lock 2;
					_vehicle allowCrewInImmobile [TRUE,TRUE];
					_vehicle limitSpeed 50;
					_vehicle addEventHandler ['Killed',QS_fnc_vKilled2];
					_vehicle addEventHandler ['GetOut',QS_fnc_AIXDismountDisabled];
					(missionNamespace getVariable ['QS_AI_vehicles',[]]) pushBack _vehicle;
					_crew setSpeedMode 'FULL';
					_crew setBehaviour 'AWARE';
					_crew setVariable ['QS_AI_GRP',TRUE,QS_system_AI_owners];
					_crew setVariable ['QS_AI_GRP_CONFIG',['GENERAL','VEHICLE',count _members,_vehicle],QS_system_AI_owners];
					_crew setVariable ['QS_AI_GRP_DATA',[TRUE,serverTime],QS_system_AI_owners];
					// A single local objective circuit keeps the vehicle in the fight;
					// it must not patrol back to its distant insertion road.
					_crew setVariable ['QS_AI_GRP_TASK',['PATROL',[_goal],serverTime,-1],QS_system_AI_owners];
					_crew setVariable ['QS_AI_GRP_PATROLINDEX',0,QS_system_AI_owners];
					_crew setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
					[_crew,_goal,'ARMOR',_key] call _fn_activate;
					(_state get 'vehicles') pushBack _vehicle;
					_state set ['vehicleUsed',1 + (_state get 'vehicleUsed')];
				};
			};
		};
		_state set ['reserved',0];
		diag_log format ['[PrimaryAO] VEHICLE epoch=%1 total=%2',_epoch,_state get 'vehicleUsed'];
	};

	private _heli = objNull;
	private _pilots = grpNull;
	private _entry = [];
	private _cargo = grpNull;
	if (_delivery isEqualTo 'HELI') then {
		private _class = QS_core_vehicles_map getOrDefault ['o_heli_transport_04_covered_f','O_Heli_Transport_04_covered_F'];
		_entry = _landing getPos [2200,random 360];
		_entry set [2,150];
		if ((_entry # 0) > 50 && {(_entry # 1) > 50} && {(_entry # 0) < worldSize - 50} && {(_entry # 1) < worldSize - 50} && {(_entry distance2D (markerPos 'QS_marker_base_marker')) > 1200} && {(allPlayers inAreaArray [_entry,600,600,0,FALSE]) isEqualTo []} && {isClass (configFile >> 'CfgVehicles' >> _class)} && {getNumber (configFile >> 'CfgVehicles' >> _class >> 'transportSoldier') >= _quantity}) then {
			_pilots = createGroup [EAST,TRUE];
			_cargo = createGroup [EAST,TRUE];
			if (!isNull _pilots && {!isNull _cargo}) then {
				_heli = [[_class,_entry,[],0,'FLY']] call _fn_createRegisteredVehicle;
				_heli setPosATL _entry;
				_heli setDir (_entry getDir _landing);
				private _pilot = [_pilots,[QS_core_units_map getOrDefault ['o_helipilot_f','O_helipilot_F'],_entry,[],0,'NONE']] call _fn_createRegisteredUnit;
				if (!isNull _pilot) then {
					[_pilot] call _fn_charge;
					_pilot moveInDriver _heli;
					_pilots addVehicle _heli;
					_pilots setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
					_cargo setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
					_pilots setBehaviour 'CARELESS';
					_pilots setCombatMode 'BLUE';
					_pilots setSpeedMode 'FULL';
					_heli setVariable ['QS_dynSim_ignore',TRUE,TRUE];
					_heli enableDynamicSimulation FALSE;
					_heli flyInHeight 200;
					_heli engineOn TRUE;
					_heli lock 2;
					(_state get 'transports') pushBack [_heli,_pilots,_cargo,_landing,_entry,_now + 180,_goal,'IN'];
					_state set ['nextHeli',_now + ([45,240] select (({isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}} count allPlayers) >= 20))];
				};
			};
		};
	};
	if (_delivery isEqualTo 'HELI' && {isNull _heli || {isNull (driver _heli)}}) exitWith {
		if (!isNull _heli) then {deleteVehicleCrew _heli; deleteVehicle _heli;};
		if (!isNull _cargo) then {deleteGroup _cargo;};
		if (!isNull _pilots) then {deleteGroup _pilots;};
		_state set ['reserved',0];
		diag_log format ['[PrimaryAO] HELI_SKIPPED epoch=%1',_epoch];
	};

	// One complete regular squad per delivery, built in a single group.
	// The reservation covers every member before this paced creation loop starts.
	private _created = 0;
	private _failed = FALSE;
	private _group = if (_delivery isEqualTo 'HELI') then {_cargo} else {createGroup [EAST,TRUE]};
	if (isNull _group) exitWith {_state set ['reserved',0];};
	_group setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
	_group setVariable ['QS_primaryPressure_node',_key,FALSE];
	_group setVariable ['QS_primaryPressure_building',TRUE,FALSE];
	private _role = ['DEFEND','RESERVE'] select (((_state get 'waveNumber') mod 4) isEqualTo 3);
	private _types = ['O_Soldier_TL_F','O_Soldier_AR_F','O_Soldier_LAT_F','O_medic_F'];
	private _heading = _landing getDir _goal;
	private _groundSlots = [];
	if (_delivery isEqualTo 'GROUND') then {
		_groundSlots = ['SLOTS',_landing,_quantity,_heading,'O_Soldier_F',TRUE,TRUE,180,{
			params ['_point'];
			(_point distance2D (markerPos 'QS_marker_base_marker')) > 1200 &&
			{(_point distance2D _pos) < (_radius + 500)} && {!([_point,_goal,25] call QS_fnc_waterIntersect)}
		}] call QS_fnc_spawnGroup;
		// Spreading the accepted center must not cross the AO/base boundary
		// or put a soldier across water from its objective. Check before creation.
		private _base = markerPos 'QS_marker_base_marker';
		if ((_groundSlots findIf {
			(_x distance2D _base) <= 1200 || {(_x distance2D _pos) > _radius + 500} ||
			{[_x,_goal,25] call QS_fnc_waterIntersect}
		}) >= 0) then {_groundSlots = [];};
	};
	if (_delivery isEqualTo 'GROUND' && {_groundSlots isEqualTo []}) exitWith {[_group] call _fn_cancelBuild; _state set ['reserved',0];};
	for '_index' from 0 to (_quantity - 1) do {
		if (!(call _fn_admit)) exitWith {};
		private _spawn = if (_delivery isEqualTo 'GROUND') then {+(_groundSlots # _index)} else {[_landing,_index,_quantity,_heading] call _fn_slotPoint;};
		private _nearPlayers = allPlayers select {alive _x && {!(_x isKindOf 'HeadlessClient_F')}};
		if ((_nearPlayers inAreaArray [_spawn,150,150,0,FALSE]) isNotEqualTo [] || {surfaceIsWater _spawn}) exitWith {};
		private _supplyLost = ['GEAR'] call _fn_secured;
		private _type = _types # (_index mod 4);
		if (_supplyLost && {_type isEqualTo 'O_Soldier_LAT_F'}) then {_type = 'O_Soldier_F';};
		_type = QS_core_units_map getOrDefault [toLowerANSI _type,_type];
		if (!isClass (configFile >> 'CfgVehicles' >> _type)) exitWith {};
		private _empty = if (_delivery isEqualTo 'GROUND') then {+_spawn} else {_spawn findEmptyPosition [0,5,_type]};
		if (_empty isEqualTo []) exitWith {};
		if (surfaceIsWater _empty || {(_nearPlayers inAreaArray [_empty,150,150,0,FALSE]) isNotEqualTo []}) exitWith {};
		if (_delivery isEqualTo 'GROUND' && {!([_empty,_nearPlayers] call _fn_concealed)}) exitWith {};
		_spawn = +_empty;
		if (_delivery isEqualTo 'HELI') then {_empty = getPosATL _heli;};
		if (_delivery isEqualTo 'PARA') then {
			_empty set [2,150 + 3 * _index];
			_empty = ['DROP_SPAWN',_empty,150,_group] call QS_fnc_aoPressure;
			if ((_empty distance2D (markerPos 'QS_marker_base_marker')) < 1200) then {_empty = _spawn vectorAdd [0,0,150 + 3 * _index];};
		};
		private _unit = [_group,[_type,_empty,[],0,'CAN_COLLIDE']] call _fn_createRegisteredUnit;
		if (isNull _unit) exitWith {};
		[_unit] call _fn_charge;
		_unit call QS_fnc_unitSetup;
		// Enforce after setup as class maps/loadouts can add a launcher. Existing
		// soldiers, vehicle ammunition and native self-rearm keep their live behavior.
		if (_supplyLost && {(secondaryWeapon _unit) isNotEqualTo ''}) then {
			private _launcher = secondaryWeapon _unit;
			private _magazines = compatibleMagazines _launcher;
			_unit removeWeapon _launcher;
			{_unit removeMagazines _x;} forEach _magazines;
		};
		_unit setVariable ['QS_AI_UNIT_enabled',FALSE,QS_system_AI_owners];
		_unit setVariable ['QS_primaryPressure_cargo',_delivery isEqualTo 'HELI',FALSE];
		_unit enableStamina FALSE; _unit enableFatigue FALSE;
		_unit setVariable ['QS_dynSim_ignore',TRUE,TRUE];
		_unit enableDynamicSimulation FALSE;
		_unit setUnitPos 'UP';
		_created = _created + 1;
		if (_delivery isEqualTo 'HELI') then {
			_unit moveInCargo _heli;
			if ((objectParent _unit) isNotEqualTo _heli) then {_failed = TRUE;};
		};
		if (_delivery isEqualTo 'PARA') then {
			private _chute = [['Steerable_Parachute_F',_empty,[],0,'FLY']] call _fn_createRegisteredVehicle;
			if (!isNull _chute) then {
				_chute setPosATL _empty;
				_unit moveInDriver _chute;
				_chute setVelocity [0,0,-5];
				_unit enableAIFeature ['TARGET',FALSE]; _unit enableAIFeature ['AUTOTARGET',FALSE];
				if ((objectParent _unit) isEqualTo _chute) then {
					(_state get 'air') pushBack [_unit,_chute,_spawn,diag_tickTime + 120,_group,_goal,_role];
					['DROP_TRACK',_unit,_spawn vectorAdd [0,0,_empty # 2],_empty] call QS_fnc_aoPressure;
				} else {_failed = TRUE; [_chute] call _fn_deleteChute;};
			} else {_failed = TRUE;};
		};
		if (_failed) exitWith {};
		uiSleep 0.35;
	};
	if (_failed || {_created < _quantity}) exitWith {
		[_group] call _fn_cancelBuild;
		_state set ['reserved',0];
	};
	_group setVariable ['QS_primaryPressure_building',FALSE,FALSE];
	[units _group,1] call QS_fnc_serverSetAISkill;
	if (_delivery isEqualTo 'GROUND') then {[_group,_goal,_role] call _fn_activate;};
	if (_delivery isEqualTo 'HELI' && {!isNull _heli}) then {
		_heli setVariable ['QS_taruDelivery_landed',FALSE];
		_cargo setVariable ['QS_taruDelivery_busy',TRUE,TRUE];
		_heli setVariable ['QS_taruDelivery_handle',['TARU_DELIVER',_heli,_cargo,_landing,_entry,_goal,'PRIMARY',_workEpoch] spawn QS_fnc_AIXHeliInsert];
		private _index = (_state get 'transports') findIf {(_x # 0) isEqualTo _heli};
		if (_index >= 0) then {((_state get 'transports') # _index) set [7,'TARU'];};
	};
	// Count admitted soldiers, including flights later destroyed by players.
	// Low-population deliveries never fund the busy-server allowance.
	if ((_state get 'liftBand') isEqualTo 1 && {!_finalReserve}) then {
		_state set ['liftSince',[(_state get 'liftSince') + _created,0] select (_delivery isEqualTo 'HELI')];
	};
	_state set ['reserved',0];
	_state set ['waveNumber',1 + (_state get 'waveNumber')];
	diag_log format ['[PrimaryAO] DELIVERY epoch=%1 type=%2 squad=%3 spent=%4',_epoch,_delivery,_created,_state get 'used'];
};
FALSE

},FALSE];
// PRIMARY_AO_CONTROLLER_END


// End Updated Code
private _isDedicated = isDedicated;
private _isHC = !isDedicated && !hasInterface;
if (_isHC) then {
	player setPosASL [
		worldSize + (random 2000),
		worldSize - (random 2000),
		10
	];
	waitUntil {(missionNamespace getVariable ['QS_mission_init',FALSE])};
};
private _QS_uiTime = diag_tickTime;
private _QS_time = time;
private _QS_serverTime = serverTime;
private _QS_dayTime = dayTime;
_worldName = worldName;
_worldSize = worldSize;
private _smallTerrains = ['Tanoa','Stratis'];
_true = TRUE;
_false = FALSE;
_endl = endl;
_isTropical = _worldName in ['Tanoa','Enoch'];
private _QS_unitCap = [140,120] select (_worldName in _smallTerrains);
private _array = [];
private _QS_unit = objNull;
private _QS_grp = grpNull;

private _QS_allAgents = [];

private _scriptEvalGrp = scriptNull;
private _scriptEvalUnit = scriptNull;
private _scriptEvalAgent = scriptNull;

private _movePos = [0,0,0];
private _basePosition = markerPos 'QS_marker_base_marker';
_east = EAST;
_west = WEST;
_civilian = CIVILIAN;
_resistance = RESISTANCE;
_sideFriendly = sideFriendly;
_enemySides = [_east,_resistance];
_friendlySides = [_west,_civilian,_sideFriendly];
//comment 'General Info';
private _QS_updateGeneralInfoDelay = 10;
private _QS_updateGeneralInfoCheckDelay = _QS_uiTime + _QS_updateGeneralInfoDelay;
private _QS_diag_fps = round diag_fps;
private _QS_allPlayers = allPlayers;
private _QS_allPlayersCount = count _QS_allPlayers;
private _QS_allGroups = allGroups;
private _QS_allGroupsCount = count _QS_allGroups;
private _QS_allUnits = allUnits;
private _QS_allUnitsCount = count _QS_allUnits;
//comment 'Dynamic skill';
private _QS_module_dynamicSkill = _false;
private _QS_module_dynamicSkill_delay = 300;
private _QS_module_dynamicSkill_checkDelay = _QS_uiTime + _QS_module_dynamicSkill_delay;
//comment 'General group behaviors';
private _QS_module_groupBehaviors = _true;
private _QS_module_groupBehaviors_delay = 15;
private _QS_module_groupBehaviors_checkDelay = _QS_uiTime + _QS_module_groupBehaviors_delay;
private _QS_module_groupBehaviors_localGroups = [];
private _QS_module_groupBehaviors_group = grpNull;
private _QS_module_groupBehaviors_groupConfig = [];
private _QS_module_groupBehaviors_groupConfig_gameType = '';
private _QS_module_groupBehaviors_groupData = [];
private _QS_module_groupBehaviors_groupTask = [];
private _QS_module_groupBehaviors_groupTask_type = '';
private _QS_module_groupBehaviors_groupTask_simple = '';
private _QS_module_groupBehaviors_groupTask_startTime = -1;
private _QS_module_groupBehaviors_groupTask_endTime = -1;
//comment 'General unit behaviors';
private _QS_module_unitBehaviors = _true;
private _QS_module_unitBehaviors_delay = 25;
private _QS_module_unitBehaviors_checkDelay = _QS_uiTime + _QS_module_unitBehaviors_delay;
private _QS_module_unitBehaviors_localUnits = [];
private _QS_module_unitBehaviors_unit = objNull;
//comment 'General agent (civ + animal) behaviors';
private _QS_module_agentBehaviors = _true;
private _QS_module_agentBehaviors_delay = 30;
private _QS_module_agentBehaviors_checkDelay = _QS_uiTime + _QS_module_agentBehaviors_delay;
private _QS_module_agentBehaviors_localAgents = [];
private _QS_module_agentBehaviors_agent = objNull;
//comment 'Virtual sectors logic';
private _QS_module_virtualSectors = _isDedicated && (missionNamespace getVariable ['QS_missionConfig_aoType','ZEUS']) isEqualTo 'SC';
private _QS_module_virtualSectors_delay = 15;	/*/this value influences difficulty substantially/*/
private _QS_module_virtualSectors_checkDelay = _QS_uiTime + _QS_module_virtualSectors_delay;
private _QS_module_virtualSectors_data = missionNamespace getVariable ['QS_virtualSectors_data',[]];
private _QS_module_virtualSectors_scoreSides = missionNamespace getVariable ['QS_virtualSectors_scoreSides',[0,0,0,0,0]];
private _QS_module_virtualSectors_scoreWin = missionNamespace getVariable ['QS_virtualSectors_scoreWin',300];
private _QS_module_virtualSectors_scoreEndClose = _QS_module_virtualSectors_scoreWin * 0.75;
private _QS_module_virtualSectors_active = _false;
private _QS_module_virtualSectors_spawnedGrp = grpNull;
private _QS_module_virtualSectors_assignedUnits = [[],[],[],[]];
private _QS_module_virtualSectors_assignedUnitsSector = [];
private _QS_module_virtualSectors_patrolFallback = _false;
private _QS_module_virtualSectors_maxAI = 0;
private _QS_module_virtualSectors_maxAISector = 0;
private _QS_module_virtualSectors_maxAIX = 0;
private _QS_module_virtualSectors_countAI = 0;
private _QS_module_virtualSectors_countAISector = 0;
private _QS_module_virtualSectors_playersInAO = [];
private _QS_module_virtualSectors_sectorData = [];
private _QS_module_virtualSectors_spawnGroupCount = 4;
private _QS_module_virtualSectors_scriptCreateEnemy = scriptNull;
private _QS_module_virtualSectors_enemy_0 = [];
private _QS_module_virtualSectors_enemy_1 = [];
private _QS_module_virtualSectors_patrolsHeli = [];
private _QS_module_virtualSectors_patrolsInf = [];
private _QS_module_virtualSectors_patrolsVeh = [];
private _QS_module_virtualSectors_patrolsGarrison = [];
private _QS_module_virtualSectors_patrolsBoat = [];
private _QS_module_virtualSectors_patrolsSniper = [];
private _QS_module_virtualSectors_patrolsHeli_thresh = 1;
private _QS_module_virtualSectors_patrolsInf_thresh = 20;
private _QS_module_virtualSectors_patrolsVeh_thresh = 1;
private _QS_module_virtualSectors_patrolsGarrison_thresh = 10;
private _QS_module_virtualSectors_patrolsBoat_thresh = 0;
private _QS_module_virtualSectors_patrolsSniper_thresh = 1;
private _QS_module_virtualSectors_countAIHeliPatrols = 0;
private _QS_module_virtualSectors_countAIInfPatrols = 0;
private _QS_module_virtualSectors_countAIVehPatrols = 0;
private _QS_module_virtualSectors_countAISnpPatrols = 0;

private _QS_module_virtualSectors_maxAI_0 = 48;
private _QS_module_virtualSectors_maxAI_1 = 64;
private _QS_module_virtualSectors_maxAI_2 = 96;
private _QS_module_virtualSectors_maxAI_3 = 108;
private _QS_module_virtualSectors_maxAI_4 = 124;
private _QS_module_virtualSectors_maxAI_5 = 136;

private _QS_module_virtualSectors_maxAISector_0 = 6;
private _QS_module_virtualSectors_maxAISector_1 = 8;
private _QS_module_virtualSectors_maxAISector_2 = 10;
private _QS_module_virtualSectors_maxAISector_3 = 14;
private _QS_module_virtualSectors_maxAISector_4 = 22;
private _QS_module_virtualSectors_maxAISector_5 = 26;

private _QS_module_virtualSectors_maxAIX_0 = 10;
private _QS_module_virtualSectors_maxAIX_1 = 12;
private _QS_module_virtualSectors_maxAIX_2 = 18;
private _QS_module_virtualSectors_maxAIX_3 = 26;
private _QS_module_virtualSectors_maxAIX_4 = 30;
private _QS_module_virtualSectors_maxAIX_5 = 38;

private _QS_module_virtualSectors_assaultEnabled = _false;
private _QS_module_virtualSectors_assaultScript = scriptNull;
private _QS_module_virtualSectors_assaultActive = _false;
private _QS_module_virtualSectors_assaultChance = selectRandom [0.333,0.666];
private _QS_module_virtualSectors_assaultReady = _false;
private _QS_module_virtualSectors_assaultCondition = {};
private _QS_module_virtualSectors_assaultVarName = 'QS_fnc_AIAssaultSector';
private _QS_module_virtualSectors_assaultDuration = 0;
private _QS_module_virtualSectors_assaultDuration_fixed = 300;
private _QS_module_virtualSectors_assaultDuration_variable = 300;
private _QS_module_virtualSectors_assaultSector = -1;
private _QS_module_virtualSectors_assaultArray = [];
private _QS_module_virtualSectors_assaultGrps = [];
private _QS_module_virtualSectors_assaultScore = random [0.5,0.666,0.75];

if (_QS_allPlayersCount < 10) then {
	_QS_module_virtualSectors_maxAI = 40;
	_QS_module_virtualSectors_maxAISector = 12;
	_QS_module_virtualSectors_maxAIX = 16;
	_QS_module_virtualSectors_patrolsInf_thresh = 20;
	_QS_module_virtualSectors_patrolsVeh_thresh = 1;
	_QS_module_virtualSectors_patrolsGarrison_thresh = 10;
	_QS_module_virtualSectors_patrolsBoat_thresh = 0;
	_QS_module_virtualSectors_patrolsSniper_thresh = 1;
};
if (_QS_allPlayersCount >= 10) then {
	_QS_module_virtualSectors_maxAI = 60;
	_QS_module_virtualSectors_maxAISector = 12;
	_QS_module_virtualSectors_maxAIX = 16;
	_QS_module_virtualSectors_patrolsInf_thresh = 20;
	_QS_module_virtualSectors_patrolsVeh_thresh = 1;
	_QS_module_virtualSectors_patrolsGarrison_thresh = 10;
	_QS_module_virtualSectors_patrolsBoat_thresh = 0;
	_QS_module_virtualSectors_patrolsSniper_thresh = 1;
};
if (_QS_allPlayersCount >= 20) then {
	_QS_module_virtualSectors_maxAI = 80;
	_QS_module_virtualSectors_maxAISector = 12;
	_QS_module_virtualSectors_maxAIX = 16;
	_QS_module_virtualSectors_patrolsInf_thresh = 20;
	_QS_module_virtualSectors_patrolsVeh_thresh = 1;
	_QS_module_virtualSectors_patrolsGarrison_thresh = 10;
	_QS_module_virtualSectors_patrolsBoat_thresh = 0;
	_QS_module_virtualSectors_patrolsSniper_thresh = 1;
};
if (_QS_allPlayersCount >= 30) then {
	_QS_module_virtualSectors_maxAI = 96;
	_QS_module_virtualSectors_maxAISector = 12;
	_QS_module_virtualSectors_maxAIX = 16;
	_QS_module_virtualSectors_patrolsInf_thresh = 20;
	_QS_module_virtualSectors_patrolsVeh_thresh = 1;
	_QS_module_virtualSectors_patrolsGarrison_thresh = 10;
	_QS_module_virtualSectors_patrolsBoat_thresh = 0;
	_QS_module_virtualSectors_patrolsSniper_thresh = 1;
};
if (_QS_allPlayersCount >= 40) then {
	_QS_module_virtualSectors_maxAI = 108;
	_QS_module_virtualSectors_maxAISector = 12;
	_QS_module_virtualSectors_maxAIX = 16;
	_QS_module_virtualSectors_patrolsInf_thresh = 20;
	_QS_module_virtualSectors_patrolsVeh_thresh = 1;
	_QS_module_virtualSectors_patrolsGarrison_thresh = 10;
	_QS_module_virtualSectors_patrolsBoat_thresh = 0;
	_QS_module_virtualSectors_patrolsSniper_thresh = 1;
};
if (_QS_allPlayersCount >= 50) then {
	_QS_module_virtualSectors_maxAI = 128;
	_QS_module_virtualSectors_maxAISector = 12;
	_QS_module_virtualSectors_maxAIX = 16;
	_QS_module_virtualSectors_patrolsInf_thresh = 20;
	_QS_module_virtualSectors_patrolsVeh_thresh = 1;
	_QS_module_virtualSectors_patrolsGarrison_thresh = 10;
	_QS_module_virtualSectors_patrolsBoat_thresh = 0;
	_QS_module_virtualSectors_patrolsSniper_thresh = 1;
};
private _QS_module_virtualSectors_patrolsHeli_delay = [360,480] select (worldName in _smallTerrains);		// 360
private _QS_module_virtualSectors_patrolsHeli_checkDelay = _QS_uiTime + _QS_module_virtualSectors_patrolsHeli_delay;
private _QS_module_virtualSectors_heliEnabled = _true;
private _QS_module_virtualSectors_patrolsVeh_delay = 300;
private _QS_module_virtualSectors_patrolsVeh_checkDelay = _QS_uiTime + _QS_module_virtualSectors_patrolsVeh_delay;
private _QS_module_virtualSectors_vehiclesEnabled = _true;
private _QS_module_virtualSectors_uavEnabled = _true;
private _QS_module_virtualSectors_uav_delay = [120,240] select (worldName in _smallTerrains);			// 30
private _QS_module_virtualSectors_uav_checkDelay = _QS_uiTime + _QS_module_virtualSectors_uav_delay;
private _QS_module_virtualSectors_uavs = [];
private _QS_module_virtualSectors_defenderDelay = 30;
private _QS_module_virtualSectors_defenderCheckDelay = _QS_uiTime + _QS_module_virtualSectors_defenderDelay;
private _QS_module_virtualSectors_attackerDelay = 30;
private _QS_module_virtualSectors_attackerCheckDelay = _QS_uiTime + _QS_module_virtualSectors_attackerDelay;

//comment 'Classic AO logic';
private _QS_module_classic = _isDedicated && (missionNamespace getVariable ['QS_missionConfig_aoType','ZEUS']) isEqualTo 'CLASSIC';
// Added Code
private _QS_module_classic_pressure = FALSE;
// End Updated Code
private _QS_module_classic_delay = 10;
private _QS_module_classic_checkDelay = _QS_uiTime + _QS_module_classic_delay;
private _QS_module_classic_spawnedGrp = [];
private _QS_module_classic_scriptAOUrbanSpawn = scriptNull;
private _QS_module_classic_aoUrbanSpawning = (missionNamespace getVariable ['QS_missionConfig_aoUrbanSpawning',1]) isEqualTo 1;
private _QS_module_classic_scriptCreateEnemy = scriptNull;
private _QS_module_classic_enemy_0 = [];
private _QS_module_classic_aoPos = [0,0,0];
private _QS_module_classic_hqPos = [0,0,0];
private _QS_module_classic_aoSize = 0;
private _QS_module_classic_aoData = [];
private _QS_module_classic_spawnedEntities = [];
private _QS_module_classic_terrainData = [];

//comment 'classic ao uavs';
private _QS_module_classic_uavEnabled = _true;
private _QS_module_classic_uav_delay = [300,480] select (worldName in _smallTerrains);
private _QS_module_classic_uav_checkDelay = _QS_uiTime + _QS_module_classic_uav_delay;
private _QS_module_classic_uavs = [];
//comment 'classic ao helis';
private _QS_module_classic_heliEnabled = _true;
private _QS_module_classic_patrolsHeli_delay = [300,480] select (worldName in _smallTerrains);		//60;		// Enemy Heli respawn delay (down below in the code an extra (random 120) is applied)
private _QS_module_classic_patrolsHeli_checkDelay = _QS_uiTime + _QS_module_classic_patrolsHeli_delay;
private _QS_module_classic_patrolsHeli = [];
//comment 'classic ao reinforcements';
private _QS_module_classic_infReinforce = _true;
private _QS_module_classic_infReinforce_enabled = _true;
private _QS_module_classic_infReinforce_delay = 20;
private _QS_module_classic_infReinforce_checkDelay = _QS_uiTime + _QS_module_classic_infReinforce_delay;
private _QS_module_classic_infReinforce_playerThreshold = 15;
private _QS_module_classic_infReinforce_cap = 0;
private _QS_module_classic_infReinforce_cap_0 = 24;
private _QS_module_classic_infReinforce_cap_1 = 34;
private _QS_module_classic_infReinforce_cap_2 = 42;
private _QS_module_classic_infReinforce_cap_3 = 50;
private _QS_module_classic_infReinforce_cap_4 = 60;
private _QS_module_classic_infReinforce_spawned = 0;
private _QS_module_classic_infReinforce_limit = 60;
private _QS_module_classic_infReinforce_limitReal = 0;
private _QS_module_classic_infReinforce_AIThreshold = 85;
private _QS_module_classic_infReinforce_array = [];
//comment 'classic ao veh reinforcements';
private _QS_module_classic_vehReinforce = _true;
private _QS_module_classic_vehReinforce_enabled = _true;
private _QS_module_classic_vehReinforce_delay = 300;
private _QS_module_classic_vehReinforce_checkDelay = _QS_uiTime + _QS_module_classic_vehReinforce_delay;
private _QS_module_classic_vehReinforce_playerThreshold = 15;
private _QS_module_classic_vehReinforce_cap = 0;
private _QS_module_classic_vehReinforce_cap_0 = 1;
private _QS_module_classic_vehReinforce_cap_1 = 1;
private _QS_module_classic_vehReinforce_cap_2 = 1;
private _QS_module_classic_vehReinforce_cap_3 = 1;
private _QS_module_classic_vehReinforce_cap_4 = 2;
private _QS_module_classic_vehReinforce_spawned = 0;
private _QS_module_classic_vehReinforce_limit = 2;
private _QS_module_classic_vehReinforce_limitReal = 0;
private _QS_module_classic_vehReinforce_AIThreshold = 75;
private _QS_module_classic_vehReinforce_array = [];
//comment 'classic ao fallback logic';
private _QS_module_classic_efb = _false;
private _QS_module_classic_efb_delay = 60;
private _QS_module_classic_efb_checkDelay = _QS_uiTime + _QS_module_classic_efb_delay;
private _QS_module_classic_efb_group = grpNull;
private _QS_module_classic_efb_threshold = 25;
//comment 'grid ao';
// Like Classic/SC, one server owns spawning and consumes the public trigger.
// HCs run the group/unit handlers after the completed groups are transferred.
private _QS_module_grid = _isDedicated && (missionNamespace getVariable ['QS_missionConfig_aoType','ZEUS']) isEqualTo 'GRID';
private _QS_module_grid_delay = 10;
private _QS_module_grid_checkDelay = _QS_uiTime + _QS_module_grid_delay;
private _QS_module_grid_aoPos = [0,0,0];
private _QS_module_grid_aoSize = -1;
private _QS_module_grid_aoData = [];
private _QS_module_grid_igPos = [0,0,0];
private _QS_module_grid_terrainData = [];
private _QS_module_grid_scriptCreateEnemy = scriptNull;
private _QS_module_grid_enemy = [];
private _QS_module_grid_enemy_X = [];
private _QS_module_grid_bldgPatrolRespawnThreshold = 0;
private _QS_module_grid_bldgPatrolUnits = [];
private _QS_module_grid_areaPatrolRespawnThreshold = 0;
private _QS_module_grid_areaPatrolUnits = [];
private _QS_module_grid_teamSize = 4;
private _QS_module_grid_spawnArray = [];
private _QS_module_grid_bldgPatrol_delay = 30;
private _QS_module_grid_bldgPatrol_checkDelay = _QS_uiTime + _QS_module_grid_bldgPatrol_delay;
private _QS_module_grid_areaPatrol_delay = 30;
private _QS_module_grid_areaPatrol_checkDelay = _QS_uiTime + _QS_module_grid_areaPatrol_delay;

private _QS_module_grid_defendUnits = [];
private _QS_module_grid_defendQty = 0;
private _QS_module_grid_defendQty_0 = 12;
private _QS_module_grid_defendQty_1 = 18;
private _QS_module_grid_defendQty_2 = 25;
private _QS_module_grid_defendQty_3 = 32;
private _QS_module_grid_defendQty_4 = 40;
private _QS_module_grid_defendQty_5 = 48;
private _QS_module_grid_defend_delay = 10;
private _QS_module_grid_defend_checkDelay = _QS_uiTime + _QS_module_grid_defend_delay;

private _QS_module_viperTeam = _true;
private _QS_module_viperTeam_delay = 15;
private _QS_module_viperTeam_checkDelay = _QS_uiTime + _QS_module_viperTeam_delay;
private _QS_module_viperTeam_respawnDelay = 300;	//300
private _QS_module_viperTeam_respawnCheckDelay = _QS_uiTime + _QS_module_viperTeam_respawnDelay;
private _QS_module_viperTeam_qty = 0;
private _QS_module_viperTeam_qty_0 = 4;
private _QS_module_viperTeam_qty_1 = 4;
private _QS_module_viperTeam_qty_2 = 6;
private _QS_module_viperTeam_qty_3 = 8;
private _QS_module_viperTeam_array = [];
private _QS_module_viperTeam_grp = grpNull;

private _QS_module_animalSpawnPosition = [0,0,0];
private _QS_module_civilian = _false;
private _QS_module_civilian_count = 0;
private _QS_module_civilian_count_0 = 0;
private _QS_module_civilian_count_1 = 4;
private _QS_module_civilian_count_2 = 7;
private _QS_module_civilian_count_3 = 10;
private _QS_module_civilian_count_4 = 13;
private _QS_module_civilian_count_5 = 16;
private _QS_module_civilian_count_6 = 20;
private _QS_module_civilian_houseCoef = 2;
private _QS_module_civilian_houseCount = 0;
//comment 'Manage ambient hostility';

private _QS_module_ambientHostility = _isDedicated && ((missionNamespace getVariable ['QS_missionConfig_aoType','ZEUS']) in ['CLASSIC','SC','GRID']);
private _QS_module_ambientHostility_delay = 30;
private _QS_module_ambientHostility_checkDelay = _QS_uiTime + _QS_module_ambientHostility_delay;
private _QS_module_ambientHostility_cooldown = -1;
private _QS_module_ambientHostility_graceTime = -1;
private _QS_module_ambientHostility_duration = 600;
private _QS_module_ambientHostility_target = objNull;
private _QS_module_ambientHostility_position = [0,0,0];
private _QS_module_ambientHostility_inProgress = _false;
private _QS_module_ambientHostility_entities = [];
private _QS_module_ambientHostility_validTargets = [];
private _QS_module_ambientHostility_nearbyCount = -1;

//Ambient non-combatants
private _QS_ambientCivilians = missionNamespace getVariable ['QS_missionConfig_AmbCiv',1] isNotEqualTo 0;
private _QS_ambientAnimals = missionNamespace getVariable ['QS_missionConfig_AmbAnim',1] isNotEqualTo 0;

//comment 'Manage enemy jets';
private _QS_module_enemyCAS = _isDedicated && (missionNamespace getVariable ['QS_missionConfig_enemyCAS',1]) isEqualTo 1;
private _QS_module_enemyCAS_delay = 15;
private _QS_module_enemyCAS_checkDelay = _QS_uiTime + _QS_module_enemyCAS_delay;
private _QS_module_enemyCAS_spawnDelay = 600;
private _QS_module_enemyCAS_spawnDelayDefault = 600;
private _QS_module_enemyCAS_checkSpawnDelay = _QS_uiTime + _QS_module_enemyCAS_spawnDelay;
private _QS_module_enemyCas_array = [];
private _QS_module_enemyCas_limit = 0;
private _QS_module_enemyCas_limitHigh = 2;
private _QS_module_enemyCas_limitLow = 1;
private _QS_module_enemyCas_plane = objNull;
private _playerJetCount = 0;
private _QS_module_enemyCas_allJetTypes = ['cas_plane'] call QS_data_listVehicles;
//comment 'Manage support providers';
private _QS_module_supportProvision = _true && _isDedicated;
private _QS_module_supportProvision_delay = 30;
private _QS_module_supportProvision_checkDelay = _QS_uiTime + _QS_module_supportProvision_delay;

//comment 'Manage custom scripts';
private _QS_module_scripts = _true && _isDedicated;
private _QS_module_scripts_delay = 15;
private _QS_module_scripts_checkDelay = _QS_uiTime + _QS_module_scripts_delay;

//===== Get list of MG weapons for AI system
private _cfgWeapons = ("(isclass _x) && ((getnumber (_x >> 'scope')) isEqualTo 2) && ((getText (_x >> 'cursor')) isEqualTo 'mg') && (((getnumber (_x >> 'type')) < 5) || ((getnumber (_x >> 'type')) isEqualTo 4096))") configClasses (configFile >> 'cfgWeapons');
_cfgWeapons = _cfgWeapons apply { toLowerANSI (configName _x) };
_cfgWeapons = _cfgWeapons arrayIntersect _cfgWeapons;
missionNamespace setVariable ['QS_AI_weapons_MG',_cfgWeapons,FALSE];
//===== Get list of GL weapons
_cfgWeapons = ("(isclass _x) && ((getnumber (_x >> 'scope')) isEqualTo 2) && (((getnumber (_x >> 'type')) < 5) || ((getnumber (_x >> 'type')) isEqualTo 4096))") configClasses (configFile >> 'cfgWeapons');
_cfgWeapons = _cfgWeapons apply { toLowerANSI (configName _x) };
_cfgWeapons = (_cfgWeapons arrayIntersect _cfgWeapons) select {['_GL_',_x,FALSE] call (missionNamespace getVariable 'QS_fnc_inString')};
missionNamespace setVariable ['QS_AI_weapons_GL',_cfgWeapons,FALSE];

//===== AI stuff
{
	missionNamespace setVariable _x;
} forEach [
	['QS_AI_managed_smoke_interval',0,FALSE],
	['QS_AI_managed_smoke_max',10,FALSE],
	['QS_AI_managed_smoke',[],FALSE],
	['QS_AI_managed_frags_interval',0,FALSE],
	['QS_AI_managed_frags_max',20,FALSE],
	['QS_AI_managed_frags',[],FALSE],
	['QS_AI_managed_suppressions',[],FALSE]
];

//comment 'Targets Knowledge script';
missionNamespace setVariable ['QS_AI_script_targetsKnowledge',([0,_east] spawn (missionNamespace getVariable 'QS_fnc_AIGetKnownEnemies')),_false];

// Headless client
private _QS_module_hc = TRUE;
private _QS_module_hc_delay = 30;
private _QS_module_hc_checkDelay = time + _QS_module_hc_delay;
private _QS_module_hc_clientID = -1;
private _QS_module_hc_active = FALSE;
private _QS_module_hc_managedSides = [EAST,WEST,RESISTANCE,CIVILIAN];
private _QS_module_hc_grp = grpNull;
private _QS_module_hc_entity = objNull;
private _QS_module_hc_maxLoad = 80;
private _QS_module_hc_maxAgents = 20;
(missionNamespace getVariable ['QS_missionConfig_hcMaxLoad',[80,60,40,25]]) params [
	'_QS_module_hc_maxLoad_1','_QS_module_hc_maxLoad_2','_QS_module_hc_maxLoad_3','_QS_module_hc_maxLoad_4'
];
(missionNamespace getVariable ['QS_missionConfig_hcMaxAgents',[20,15,10,5]]) params [
	'_QS_module_hc_maxAgents_1','_QS_module_hc_maxAgents_2','_QS_module_hc_maxAgents_3','_QS_module_hc_maxAgents_4'
];
missionNamespace setVariable ['QS_module_hc_maxLoad',_QS_module_hc_maxLoad,TRUE];
missionNamespace setVariable ['QS_module_hc_maxAgents',_QS_module_hc_maxAgents,TRUE];
private _QS_module_hc_units = [];
private _QS_module_hc_ID = 0;
private _QS_module_hc_scriptTransfer = scriptNull;
private _QS_module_hc_groups_s0 = [];
private _QS_module_hc_groups_s1 = [];
private _QS_module_hc_groups_s2 = [];
private _QS_module_hc_groups_s3 = [];
private _QS_module_hc_count = 0;

private _QS_module_hc_agents_s0 = [];
private _QS_module_hc_agents_s1 = [];
private _QS_module_hc_agents_s2 = [];
private _QS_module_hc_agents_s3 = [];

private _QS_module_hc_agents = [];
private _QS_module_hc_groupVariableWhitelist = [
	'QS_AI_GRP',
	'QS_AI_GRP_CONFIG',
	'QS_AI_GRP_DATA',
	'QS_AI_GRP_TASK',
	'QS_AI_GRP_PATROLINDEX',
	'QS_AI_GRP_fireMission',
	'QS_AI_GRP_MTR_cooldown',
	'QS_AI_GRP_disableBldgPtl',
	'QS_AI_GRP_AO_AA',
	'QS_AI_GRP_stalker',
	'QS_AI_GRP_stalker_priorPosition',
// Added Code
	'QS_primaryPressure_task',
	'QS_primaryPressure_rosterEpoch',
	'QS_primaryPressure_guard',
	'QS_primaryPressure_guardNode',
// End Updated Code
	'QS_AI_GRP_regrouping',
	'QS_AI_GRP_regroupPos',
	'QS_AI_engineer_vehicles',
	'QS_dynSim_ignore'
];
private _QS_module_hc_agentVariableWhitelist = [
	'QS_AI_ENTITY',
	'QS_AI_ENTITY_CONFIG',
	'QS_AI_ENTITY_DATA',
	'QS_AI_ENTITY_TASK',
	'QS_AI_ENTITY_CIRCUITINDEX',
	'QS_AI_ENTITY_PANIC',
	'QS_AI_ENTITY_PANIC_ACTIVE',
	'QS_AI_ENTITY_PANIC_DELAY',
	'QS_AI_ENTITY_PANIC_DISABLED',
	'QS_dynSim_ignore',
	'QS_curator_disableEditability'
];
missionNamespace setVariable ['QS_AI_HC_groupVariableWhitelist',_QS_module_hc_groupVariableWhitelist,FALSE];

private _QS_module_hc_log_delay = 60;
private _QS_module_hc_log_checkDelay = time + _QS_module_hc_delay;

private _clientOwner = clientOwner;
private _setNewOwner = FALSE;
private _exit = FALSE;

private _grp = grpNull;
private _unit = objNull;
private _grpData = [];
private _unitData = [];
private _unitsData = [];
private _unitSkills = [];
private _unitAIFeatures = [];

if (_isHC) then {
	disableRemoteSensors FALSE;
	calculatePlayerVisibilityByFriendly TRUE;
	// SYNC existing group vars to HC
	[98,clientOwner] remoteExec ['QS_fnc_remoteExec',2,FALSE];
};
_groupEventHandlerTypes = ['CombatModeChanged','CommandChanged','FormationChanged','SpeedModeChanged','EnableAttackChanged','LeaderChanged','GroupIdChanged','KnowsAboutChanged','WaypointComplete','Fleeing','EnemyDetected'];
_groupEventLocalHC = {
	params ['_grp','_isLocal'];
	if (_isLocal) then {
		_grp removeEventHandler [_thisEvent,_thisEventHandler];
		if ((_grp getVariable ['QS_AI_GRP_HC_LocalEH',-1]) isEqualTo _thisEventHandler) then {
			_grp setVariable ['QS_AI_GRP_HC_LocalEH',nil,FALSE];
		};
		_grp setVariable ['QS_AI_GRP_SETUP',FALSE,FALSE];
		_grp setVariable ['QS_AI_GRP_HC',[4,clientOwner],QS_system_AI_owners];
		private _data = [];
		private _unit = objNull;
		private _unitData = [];
		private _unitSkills = [];
		private _unitAI = [];
		{
			_data = _x;
			if (_forEachIndex isEqualTo 0) then {
				_grp setBehaviour (['CARELESS','SAFE','AWARE','COMBAT','STEALTH','AWARE'] # _data);
			};
			if (_forEachIndex isEqualTo 1) then {
				_grp setCombatMode (['BLUE','GREEN','WHITE','YELLOW','RED'] # _data);
			};
			if (_forEachIndex isEqualTo 2) then {
				_grp enableAttack (_data isEqualTo 1);
			};
			if (_forEachIndex isEqualTo 3) then {
				{
					_unitData = _x;
					_unitData params ['_unit','_unitSkill','_unitSkills','_unitAI','_unitPos','_unitAnimCoef','_unitStamina'];
					if (alive _unit) then {
						_unit setVariable ['QS_AI_UNIT',FALSE,FALSE];
						_unit setSkill _unitSkill;
						{
							_unit setSkill [QS_data_AISkills # _forEachIndex,_x];
						} forEach _unitSkills;
						{
							_unit enableAIFeature [QS_data_AIFeatures # _forEachIndex,_x isEqualTo 1];
						} forEach _unitAI;
						if (_unitPos isNotEqualTo -1) then {
							_unit setUnitPos (['Down','Up','Middle','Auto'] # _unitPos);
						};
						_unit setAnimSpeedCoef _unitAnimCoef;
						_unit enableStamina (_unitStamina isEqualTo 1);
						_unit enableFatigue (_unitStamina isEqualTo 1);
					};
				} forEach _data;
			};
		} forEach (_grp getVariable ['QS_AI_GRP_HC_data',[]]);
		_grp allowFleeing 0;
		_grp spawn {
			sleep 3;
			{
				if (alive _x) then {
					_x setUnitLoadout (getUnitLoadout _x);
				};
			} forEach (units _this);
		};
	};
};
_agentEventLocalHC = {
	params ['_agent','_isLocal'];
	if (_isLocal) then {
		_agent removeEventHandler [_thisEvent,_thisEventHandler];
		if ((_agent getVariable ['QS_AI_ENTITY_HC_LocalEH',-1]) isEqualTo _thisEventHandler) then {
			_agent setVariable ['QS_AI_ENTITY_HC_LocalEH',nil,FALSE];
		};
		_agent setVariable ['QS_AI_ENTITY_HC',[4,clientOwner],QS_system_AI_owners];
	};
};
_groupEventLocalServer = {
	params ['_grp','_isLocal'];
	if (_isLocal) then {
		_grp removeEventHandler [_thisEvent,_thisEventHandler];
		if ((_grp getVariable ['QS_AI_GRP_HC_LocalEH',-1]) isEqualTo _thisEventHandler) then {
			_grp setVariable ['QS_AI_GRP_HC_LocalEH',nil,FALSE];
		};
		{
			_x setVariable ['QS_AI_UNIT',FALSE,FALSE];
		} forEach (units _grp);
		_grp setVariable ['QS_AI_GRP_SETUP',FALSE,FALSE];
		_grp setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
	};
};
_agentEventLocalServer = {
	params ['_agent','_isLocal'];
	if (_isLocal) then {
		_agent removeEventHandler [_thisEvent,_thisEventHandler];
		if ((_agent getVariable ['QS_AI_ENTITY_HC_LocalEH',-1]) isEqualTo _thisEventHandler) then {
			_agent setVariable ['QS_AI_ENTITY_HC_LocalEH',nil,FALSE];
		};
		_agent setVariable ['QS_AI_ENTITY_HC',[0,-1],QS_system_AI_owners];
	};
};
QS_data_AISkills = [
	'general',
	'courage',
	'aimingAccuracy',
	'aimingShake',
	'aimingSpeed',
	'commanding',
	'endurance',
	'spotDistance',
	'spotTime',
	'reloadSpeed'
];
QS_data_AIFeatures = [
	//'ALL',
	'AIMINGERROR',
	'ANIM',
	'AUTOCOMBAT',
	'AUTOTARGET',
	'CHECKVISIBLE',
	'COVER',
	'FSM',
	'LIGHTS',
	'MINEDETECTION',
	'MOVE',
	'NVG',
	'PATH',
	'RADIOPROTOCOL',
	'SUPPRESSION',
	'TARGET',
	'TEAMSWITCH',
	'WEAPONAIM'
];
private _text = '';
private _QS_serverTime = serverTime;

//comment 'Preload Functions';
_fn_aoGetTerrainData = missionNamespace getVariable 'QS_fnc_aoGetTerrainData';
_fn_serverDetector = missionNamespace getVariable 'QS_fnc_serverDetector';
_fn_AIHandleGroup = missionNamespace getVariable 'QS_fnc_AIHandleGroup';
_fn_AIHandleUnit = missionNamespace getVariable 'QS_fnc_AIHandleUnit';
_fn_AIHandleAgent = missionNamespace getVariable 'QS_fnc_AIHandleAgent';
_fn_scEnemy = missionNamespace getVariable 'QS_fnc_scEnemy';
_fn_scGetNearestSector = missionNamespace getVariable 'QS_fnc_scGetNearestSector';
_fn_scSpawnGroup = missionNamespace getVariable 'QS_fnc_scSpawnGroup';
_fn_scSpawnLandVehicle = missionNamespace getVariable 'QS_fnc_scSpawnLandVehicle';
_fn_scSpawnHeli = missionNamespace getVariable 'QS_fnc_scSpawnHeli';
_fn_scSpawnUAV = missionNamespace getVariable 'QS_fnc_scSpawnUAV';
_fn_aoEnemy = missionNamespace getVariable 'QS_fnc_aoEnemy';
_fn_aoEnemyReinforce = missionNamespace getVariable 'QS_fnc_aoEnemyReinforce';
_fn_aoEnemyReinforceVehicles = missionNamespace getVariable 'QS_fnc_aoEnemyReinforceVehicles';
_fn_enemyCAS = missionNamespace getVariable 'QS_fnc_enemyCAS';
_fn_gridEnemy = missionNamespace getVariable 'QS_fnc_gridEnemy';
_fn_gridSpawnPatrol = missionNamespace getVariable 'QS_fnc_gridSpawnPatrol';
_fn_gridSpawnAttack = missionNamespace getVariable 'QS_fnc_gridSpawnAttack';
_fn_findRandomPos = missionNamespace getVariable 'QS_fnc_findRandomPos';
_fn_spawnAmbientCivilians = missionNamespace getVariable 'QS_fnc_spawnAmbientCivilians';
_fn_aoAnimals = missionNamespace getVariable 'QS_fnc_aoAnimals';
_fn_spawnViperTeam = missionNamespace getVariable 'QS_fnc_spawnViperTeam';
_fn_serverObjectsRecycler = missionNamespace getVariable 'QS_fnc_serverObjectsRecycler';
_fn_aiGetKnownEnemies = missionNamespace getVariable 'QS_fnc_AIGetKnownEnemies';
_fn_ambientHostility = missionNamespace getVariable 'QS_fnc_ambientHostility';
_fn_aiOwners = missionNamespace getVariable 'QS_fnc_AIOwners';
_fn_waterInRadius = missionNamespace getVariable 'QS_fnc_waterInRadius';
_fn_aoUrbanSpawn = missionNamespace getVariable 'QS_fnc_aoUrbanSpawn';

//comment 'Loop';
for '_x' from 0 to 1 step 0 do {
	uiSleep (random [2.5,3,3.5]);
	_QS_uiTime = diag_tickTime;
	_QS_time = time;
	_QS_serverTime = serverTime;
// Added Code
	if (_QS_module_classic && {_QS_module_classic_pressure}) then {['AIR'] call QS_fnc_aoPressure;};
	if (isServer) then {['DROP_TICK'] call QS_fnc_aoPressure;};
	['ARTY_TICK'] call QS_fnc_aoPressure;
// End Updated Code
	/*/Get general data/*/
	if (_QS_uiTime > _QS_updateGeneralInfoCheckDelay) then {
		_QS_diag_fps = round diag_fps;
		_QS_allPlayers = allPlayers;
		_QS_allPlayersCount = count _QS_allPlayers;
		_QS_allGroups = allGroups;
		_QS_allGroupsCount = count _QS_allGroups;
		_QS_allUnits = allUnits;
		_QS_allUnitsCount = count _QS_allUnits;
		_QS_allAgents = (agents apply {(agent _x)}) select {(!isNull _x)};
		_QS_allAgentsCount = count _QS_allAgents;
		_QS_module_groupBehaviors_localGroups = _QS_allGroups select {(local _x)};
		_QS_module_unitBehaviors_localUnits = _QS_allUnits select {(local _x)};
		_QS_module_agentBehaviors_localAgents = _QS_allAgents select {(local _x)};
		_QS_updateGeneralInfoCheckDelay = _QS_uiTime + _QS_updateGeneralInfoDelay;
		if (_isDedicated) then {
			// Recover entities which returned to the server after their HC owner vanished.
			private _liveHCOwners = (entities 'HeadlessClient_F') apply {owner _x};
			{
				private _hcState = _x getVariable ['QS_AI_GRP_HC',[0,-1]];
				private _hcStage = _hcState param [0,0];
				private _hcOwner = _hcState param [1,-1];
				if (
					(_hcStage isNotEqualTo 0) &&
					{(_hcOwner > 2)} &&
					{(!(_hcOwner in _liveHCOwners))}
				) then {
					private _localEH = _x getVariable ['QS_AI_GRP_HC_LocalEH',-1];
					if (
						(_localEH >= 0) &&
						{((_x getEventHandlerInfo ['Local',_localEH]) param [0,FALSE])}
					) then {
						_x removeEventHandler ['Local',_localEH];
					};
					_x setVariable ['QS_AI_GRP_HC_LocalEH',nil,FALSE];
					{
						_x setVariable ['QS_AI_UNIT',FALSE,FALSE];
					} forEach (units _x);
					_x setVariable ['QS_AI_GRP_SETUP',FALSE,FALSE];
					_x setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
				};
			} forEach _QS_module_groupBehaviors_localGroups;
			{
				private _hcState = _x getVariable ['QS_AI_ENTITY_HC',[0,-1]];
				private _hcStage = _hcState param [0,0];
				private _hcOwner = _hcState param [1,-1];
				if (
					(_hcStage isNotEqualTo 0) &&
					{(_hcOwner > 2)} &&
					{(!(_hcOwner in _liveHCOwners))}
				) then {
					private _localEH = _x getVariable ['QS_AI_ENTITY_HC_LocalEH',-1];
					if (
						(_localEH >= 0) &&
						{((_x getEventHandlerInfo ['Local',_localEH]) param [0,FALSE])}
					) then {
						_x removeEventHandler ['Local',_localEH];
					};
					_x setVariable ['QS_AI_ENTITY_HC_LocalEH',nil,FALSE];
					_x setVariable ['QS_AI_ENTITY_HC',[0,-1],QS_system_AI_owners];
				};
			} forEach _QS_module_agentBehaviors_localAgents;
		} else {
			// Discard HC-side transfer listeners after a transfer was cancelled or reassigned.
			{
				private _localEH = _x getVariable ['QS_AI_GRP_HC_LocalEH',-1];
				if (_localEH >= 0) then {
					private _handlerActive = (_x getEventHandlerInfo ['Local',_localEH]) param [0,FALSE];
					private _hcState = _x getVariable ['QS_AI_GRP_HC',[0,-1]];
					private _transferPending = (
						(!local _x) &&
						{((_hcState param [0,0]) in [2,3])} &&
						{((_hcState param [1,-1]) isEqualTo _clientOwner)}
					);
					if (_handlerActive && (!_transferPending)) then {
						_x removeEventHandler ['Local',_localEH];
					};
					if ((!_handlerActive) || {!_transferPending}) then {
						_x setVariable ['QS_AI_GRP_HC_LocalEH',nil,FALSE];
					};
				};
			} forEach _QS_allGroups;
			{
				private _localEH = _x getVariable ['QS_AI_ENTITY_HC_LocalEH',-1];
				if (_localEH >= 0) then {
					private _handlerActive = (_x getEventHandlerInfo ['Local',_localEH]) param [0,FALSE];
					private _hcState = _x getVariable ['QS_AI_ENTITY_HC',[0,-1]];
					private _transferPending = (
						(!local _x) &&
						{((_hcState param [0,0]) in [2,3])} &&
						{((_hcState param [1,-1]) isEqualTo _clientOwner)}
					);
					if (_handlerActive && (!_transferPending)) then {
						_x removeEventHandler ['Local',_localEH];
					};
					if ((!_handlerActive) || {!_transferPending}) then {
						_x setVariable ['QS_AI_ENTITY_HC_LocalEH',nil,FALSE];
					};
				};
			} forEach _QS_allAgents;
		};
		if (_isDedicated && (missionNamespace getVariable ['QS_HC_Active',_false])) then {
			missionNamespace setVariable ['QS_system_AI_owners',call _fn_aiOwners,call _fn_aiOwners];
		};
	};
	//======================= Headless Client
	
	if (
		_QS_module_hc &&
		{(missionNamespace getVariable ['QS_HC_Active',_false])}
	) then {
		if (_isDedicated) then {
			// SERVER
			_QS_headlessClients = missionNamespace getVariable ['QS_headlessClients',[]];
			if (_QS_headlessClients isNotEqualTo []) then {
				//===== Distribution re-calc
				_QS_module_hc_count = count _QS_headlessClients;
				if (_QS_module_hc_count isEqualTo 1) then {
					if (QS_module_hc_maxLoad isNotEqualTo _QS_module_hc_maxLoad_1) then {
						QS_module_hc_maxLoad = _QS_module_hc_maxLoad_1;
					};
					if (QS_module_hc_maxAgents isNotEqualTo _QS_module_hc_maxAgents_1) then {
						QS_module_hc_maxAgents = _QS_module_hc_maxAgents_1;
					};
				} else {
					if (_QS_module_hc_count isEqualTo 2) then {
						if (QS_module_hc_maxLoad isNotEqualTo _QS_module_hc_maxLoad_2) then {
							QS_module_hc_maxLoad = _QS_module_hc_maxLoad_2;
						};
						if (QS_module_hc_maxAgents isNotEqualTo _QS_module_hc_maxAgents_2) then {
							QS_module_hc_maxAgents = _QS_module_hc_maxAgents_2;
						};
					};
					if (_QS_module_hc_count isEqualTo 3) then {
						if (QS_module_hc_maxLoad isNotEqualTo _QS_module_hc_maxLoad_3) then {
							QS_module_hc_maxLoad = _QS_module_hc_maxLoad_3;
						};
						if (QS_module_hc_maxAgents isNotEqualTo _QS_module_hc_maxAgents_3) then {
							QS_module_hc_maxAgents = _QS_module_hc_maxAgents_3;
						};
					};
					if (_QS_module_hc_count >= 4) then {
						if (QS_module_hc_maxLoad isNotEqualTo _QS_module_hc_maxLoad_4) then {
							QS_module_hc_maxLoad = _QS_module_hc_maxLoad_4;
						};
						if (QS_module_hc_maxAgents isNotEqualTo _QS_module_hc_maxAgents_4) then {
							QS_module_hc_maxAgents = _QS_module_hc_maxAgents_4;
						};
					};
					//===== HC Prioritization
					_QS_headlessClients = _QS_headlessClients apply {
						_QS_module_hc_ID = _x; 
						[
							count (_QS_allUnits select {(owner _x) isEqualTo _QS_module_hc_ID}),
							_QS_module_hc_ID
						]
					};
					_QS_headlessClients sort _true;
					_QS_headlessClients = _QS_headlessClients apply { _x # 1 };
				};
				{
					_exit = _false;
					_QS_module_hc_ID = _x;
					
					// Grouped Units
					_QS_module_hc_units = _QS_allUnits select {(owner _x) isEqualTo _QS_module_hc_ID};
					if ((count _QS_module_hc_units) < QS_module_hc_maxLoad) then {
						//======================= STEP 2 - 3
						_QS_module_hc_groups_s2 = _QS_module_groupBehaviors_localGroups select {
							(((_x getVariable ['QS_AI_GRP_HC',[-1,2]]) # 0) isEqualTo 2) &&
							(((_x getVariable ['QS_AI_GRP_HC',[-1,2]]) # 1) isEqualTo _QS_module_hc_ID)
						};
						if (_QS_module_hc_groups_s2 isNotEqualTo []) then {
							_exit = _true;
							_grp = selectRandom _QS_module_hc_groups_s2;
							_grp setVariable ['QS_AI_GRP_HC',[3,_QS_module_hc_ID],[2,_QS_module_hc_ID]];
							{
								_x removeAllEventHandlers 'FiredMan';
								_x removeAllEventHandlers 'Hit';
								_x removeAllEventHandlers 'Suppressed';
							} forEach (units _grp);
							{
								if (((_grp getEventHandlerInfo [_x,0]) # 2) isNotEqualTo 0) then {
									_grp removeAllEventHandlers _x;
								};
							} forEach _groupEventHandlerTypes;
							private _existingLocalEH = _grp getVariable ['QS_AI_GRP_HC_LocalEH',-1];
							if (
								(_existingLocalEH >= 0) &&
								{((_grp getEventHandlerInfo ['Local',_existingLocalEH]) param [0,FALSE])}
							) then {
								_grp removeEventHandler ['Local',_existingLocalEH];
							};
							private _localEH = _grp addEventHandler ['Local',_groupEventLocalServer];
							_grp setVariable ['QS_AI_GRP_HC_LocalEH',_localEH,FALSE];
							private _groupOwnerBefore = groupOwner _grp;
							private _groupOwnerTransferResult = _grp setGroupOwner _QS_module_hc_ID;
							if (!isNil {missionNamespace getVariable 'QS_fnc_transformDiagGroupOwnerRequest'}) then {
								[_grp,_groupOwnerBefore,_QS_module_hc_ID,_groupOwnerTransferResult] call (missionNamespace getVariable 'QS_fnc_transformDiagGroupOwnerRequest');
							};
							if (!_groupOwnerTransferResult) then {
								//===== Ownership transfer failed, reset to beginning of process
								if (((_grp getEventHandlerInfo ['Local',_localEH]) param [0,FALSE])) then {
									_grp removeEventHandler ['Local',_localEH];
								};
								_grp setVariable ['QS_AI_GRP_HC_LocalEH',nil,FALSE];
								_grp setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
							};
						};
						if (_exit) exitWith {};

						//======================= STEP 0 - 1
						_QS_module_hc_groups_s0 = _QS_module_groupBehaviors_localGroups select {
							(((_x getVariable ['QS_AI_GRP_HC',[-1,2]]) # 0) isEqualTo 0) &&
							{!(_x getVariable ['QS_AI_GRP_HC_EXCLUDED',FALSE])}
						};
						if (_QS_module_hc_groups_s0 isNotEqualTo []) then {
							_exit = _true;
							_grp = selectRandom _QS_module_hc_groups_s0;
							// Build group/unit data for network sync, convert string to number for network traffic reduction
							_grpData = [
								(['CARELESS','SAFE','AWARE','COMBAT','STEALTH','ERROR'] find (behaviour (leader _grp))),
								['BLUE','GREEN','WHITE','YELLOW','RED'] find (combatMode _grp),
								[0,1] select (attackEnabled _grp)
							];
							_unitsData = [];
							{
								_unit = _x;
								_unitData = [];
								_unitSkills = [];
								_unitAIFeatures = [];
								_unitData pushBack _unit;
								_unitData pushBack (skill _unit);
								{
									_unitSkills pushBack (_unit skillFinal _x);
								} forEach QS_data_AISkills;
								_unitData pushBack _unitSkills;
								{
									_unitAIFeatures pushBack ([0,1] select (_unit checkAIFeature _x));
								} forEach QS_data_AIFeatures;
								_unitData pushBack _unitAIFeatures;
								_unitData pushBack (['Down','Up','Middle','Auto'] find (unitPos _unit));
								_unitData pushBack (getAnimSpeedCoef _unit);
								_unitData pushBack ([0,1] select (isStaminaEnabled _unit));
								_unitsData pushBack _unitData;
							} forEach (units _grp);
							_grpData pushBack _unitsData;
							{
								if (!isNil {_grp getVariable _x}) then {
									_grp setVariable [_x,_grp getVariable _x,[2,_QS_module_hc_ID]];
								};
							} forEach _QS_module_hc_groupVariableWhitelist;
							_grp setVariable ['QS_AI_GRP_HC_data',_grpData,[2,_QS_module_hc_ID]];
							_grp setVariable ['QS_AI_GRP_HC',[1,_QS_module_hc_ID],[2,_QS_module_hc_ID]];
						};
						if (_exit) exitWith {};
					};
					//===== Agents
					_QS_module_hc_agents = _QS_allAgents select { (owner _x) isEqualTo _QS_module_hc_ID };
					if ((count _QS_module_hc_agents) < QS_module_hc_maxAgents) then {
						//======================= STEP 2 - 3
						_QS_module_hc_agents_s2 = _QS_module_agentBehaviors_localAgents select {
							(alive _x) &&
							{(((_x getVariable ['QS_AI_ENTITY_HC',[-1,2]]) # 0) isEqualTo 2)} &&
							{(((_x getVariable ['QS_AI_ENTITY_HC',[-1,2]]) # 1) isEqualTo _QS_module_hc_ID)}
						};
						if (_QS_module_hc_agents_s2 isNotEqualTo []) then {
							_exit = _true;
							_QS_module_agentBehaviors_agent = selectRandom _QS_module_hc_agents_s2;
							_QS_module_agentBehaviors_agent setVariable ['QS_AI_ENTITY_HC',[3,_QS_module_hc_ID],[2,_QS_module_hc_ID]];
							private _existingLocalEH = _QS_module_agentBehaviors_agent getVariable ['QS_AI_ENTITY_HC_LocalEH',-1];
							if (
								(_existingLocalEH >= 0) &&
								{((_QS_module_agentBehaviors_agent getEventHandlerInfo ['Local',_existingLocalEH]) param [0,FALSE])}
							) then {
								_QS_module_agentBehaviors_agent removeEventHandler ['Local',_existingLocalEH];
							};
							private _localEH = _QS_module_agentBehaviors_agent addEventHandler ['Local',_agentEventLocalServer];
							_QS_module_agentBehaviors_agent setVariable ['QS_AI_ENTITY_HC_LocalEH',_localEH,FALSE];
							if (!(_QS_module_agentBehaviors_agent setOwner _QS_module_hc_ID)) then {
								//===== Ownership transfer failed, reset to beginning of process
								if (((_QS_module_agentBehaviors_agent getEventHandlerInfo ['Local',_localEH]) param [0,FALSE])) then {
									_QS_module_agentBehaviors_agent removeEventHandler ['Local',_localEH];
								};
								_QS_module_agentBehaviors_agent setVariable ['QS_AI_ENTITY_HC_LocalEH',nil,FALSE];
								_QS_module_agentBehaviors_agent setVariable ['QS_AI_ENTITY_HC',[0,-1],QS_system_AI_owners];
							};
						};
						if (_exit) exitWith {};

						//======================= STEP 0 - 1
						_QS_module_hc_agents_s0 = _QS_module_agentBehaviors_localAgents select {
							(((_x getVariable ['QS_AI_ENTITY_HC',[-1,2]]) # 0) isEqualTo 0)
						};
						if (_QS_module_hc_agents_s0 isNotEqualTo []) then {
							_exit = _true;
							_QS_module_agentBehaviors_agent = selectRandom _QS_module_hc_agents_s0;
							{
								if (!isNil {_QS_module_agentBehaviors_agent getVariable _x}) then {
									_QS_module_agentBehaviors_agent setVariable [_x,_QS_module_agentBehaviors_agent getVariable _x,[2,_QS_module_hc_ID]];
								};
							} forEach _QS_module_hc_agentVariableWhitelist;
							_QS_module_agentBehaviors_agent setVariable ['BIS_fnc_animalBehaviour_disable',_true,[2,_QS_module_hc_ID]];
							_QS_module_agentBehaviors_agent setVariable ['QS_AI_ENTITY_HC',[1,_QS_module_hc_ID],[2,_QS_module_hc_ID]];
						};	
					};
				} forEach _QS_headlessClients;
			};
			if (_QS_time > _QS_module_hc_log_checkDelay) then {
				diag_log (format ['HC AI Report (Server): %1Local units: %2 * %1Local groups: %3 * %1Local agents: %4',_endl,(count _QS_module_unitBehaviors_localUnits),(count _QS_module_groupBehaviors_localGroups),(count _QS_module_agentBehaviors_localAgents)]);
				{
					diag_log format ['Headless Client Info: %1',getUserInfo (getPlayerID _x)];
				} forEach (entities 'HeadlessClient_F');
				_QS_module_hc_log_checkDelay = _QS_time + _QS_module_hc_log_delay;
			};
		} else {
			// HC
			//======================= STEP 1 - 2
			_QS_module_hc_groups_s1 = _QS_allGroups select {
				(((_x getVariable ['QS_AI_GRP_HC',[-1,2]]) # 0) isEqualTo 1) &&
				{(((_x getVariable ['QS_AI_GRP_HC',[-1,-1]]) # 1) isEqualTo _clientOwner)}
			};
			if (_QS_module_hc_groups_s1 isNotEqualTo []) then {
				_grp = selectRandom _QS_module_hc_groups_s1;
				
				if (isNil {_grp getVariable 'QS_AI_GRP_HC_data'}) exitWith {
					_grp setVariable ['QS_AI_GRP_HC',[0,_clientOwner],[2,_clientOwner]];
				};
				private _existingLocalEH = _grp getVariable ['QS_AI_GRP_HC_LocalEH',-1];
				if (
					(_existingLocalEH >= 0) &&
					{((_grp getEventHandlerInfo ['Local',_existingLocalEH]) param [0,FALSE])}
				) then {
					_grp removeEventHandler ['Local',_existingLocalEH];
				};
				private _localEH = _grp addEventHandler ['Local',_groupEventLocalHC];
				_grp setVariable ['QS_AI_GRP_HC_LocalEH',_localEH,FALSE];
				_grp setVariable ['QS_AI_GRP_HC',[2,_clientOwner],[2,_clientOwner]];
			};
			
			_QS_module_hc_agents_s1 = _QS_allAgents select {
				(((_x getVariable ['QS_AI_ENTITY_HC',[-1,2]]) # 0) isEqualTo 1) &&
				{(((_x getVariable ['QS_AI_ENTITY_HC',[-1,-1]]) # 1) isEqualTo _clientOwner)}
			};
			if (_QS_module_hc_agents_s1 isNotEqualTo []) then {
				_QS_module_agentBehaviors_agent = selectRandom _QS_module_hc_agents_s1;
				private _existingLocalEH = _QS_module_agentBehaviors_agent getVariable ['QS_AI_ENTITY_HC_LocalEH',-1];
				if (
					(_existingLocalEH >= 0) &&
					{((_QS_module_agentBehaviors_agent getEventHandlerInfo ['Local',_existingLocalEH]) param [0,FALSE])}
				) then {
					_QS_module_agentBehaviors_agent removeEventHandler ['Local',_existingLocalEH];
				};
				private _localEH = _QS_module_agentBehaviors_agent addEventHandler ['Local',_agentEventLocalHC];
				_QS_module_agentBehaviors_agent setVariable ['QS_AI_ENTITY_HC_LocalEH',_localEH,FALSE];
				_QS_module_agentBehaviors_agent setVariable ['QS_AI_ENTITY_HC',[2,_clientOwner],[2,_clientOwner]];
			};
			diag_log (format ['HC AI Report (Headless Client): %1Local units: %2 * %1Local groups: %3 * %1Local agents: %4',_endl,(count _QS_module_unitBehaviors_localUnits),(count _QS_module_groupBehaviors_localGroups),(count _QS_module_agentBehaviors_localAgents)]);
		};
	};
	if (_QS_module_dynamicSkill) then {
		if (_QS_uiTime > _QS_module_dynamicSkill_checkDelay) then {
			_QS_module_dynamicSkill_checkDelay = _QS_uiTime + _QS_module_dynamicSkill_delay;
		};
	};
	if (_QS_module_groupBehaviors) then {
		if (_QS_uiTime > _QS_module_groupBehaviors_checkDelay) then {
			{
				_QS_module_groupBehaviors_group = _x;
				if (_QS_module_groupBehaviors_group getVariable ['QS_AI_GRP',_false]) then {
					_scriptEvalGrp = [_QS_module_groupBehaviors_group,_QS_serverTime,_QS_diag_fps] spawn _fn_AIHandleGroup;
					waitUntil {scriptDone _scriptEvalGrp};
				};
			} forEach _QS_module_groupBehaviors_localGroups;
			_QS_module_groupBehaviors_checkDelay = diag_tickTime + _QS_module_groupBehaviors_delay;
		};
	};
	if (_QS_module_unitBehaviors) then {
		if (_QS_uiTime > _QS_module_unitBehaviors_checkDelay) then {
			{
				_QS_module_unitBehaviors_unit = _x;
				if (_QS_module_unitBehaviors_unit getVariable ['QS_AI_UNIT_enabled',_false]) then {
					if (((random 1) > 0.333) || {(_QS_module_unitBehaviors_unit isEqualTo (leader (group _QS_module_unitBehaviors_unit)))}) then {
						_scriptEvalUnit = [_QS_module_unitBehaviors_unit,_QS_serverTime,_QS_diag_fps,_QS_allPlayersCount] spawn _fn_AIHandleUnit;
						waitUntil {scriptDone _scriptEvalUnit};
					};
				};
			} forEach _QS_module_unitBehaviors_localUnits;
			_QS_module_unitBehaviors_checkDelay = diag_tickTime + _QS_module_unitBehaviors_delay;
		};
	};
	if (_QS_module_agentBehaviors) then {
		if (_QS_uiTime > _QS_module_agentBehaviors_checkDelay) then {
			{
				_QS_module_agentBehaviors_agent = _x;
				if (_QS_module_agentBehaviors_agent getVariable ['QS_AI_ENTITY',_false]) then {
					if (((random 1) > 0.75) || {(_QS_module_agentBehaviors_agent isKindOf 'CAManBase')}) then {
						_scriptEvalAgent = [_QS_module_agentBehaviors_agent,_QS_serverTime,_QS_diag_fps] spawn _fn_AIHandleAgent;
						waitUntil {scriptDone _scriptEvalAgent};
					};
				};
			} forEach _QS_module_agentBehaviors_localAgents;
			_QS_module_agentBehaviors_checkDelay = diag_tickTime + _QS_module_agentBehaviors_delay;
		};
	};	
	/*/Module virtual sectors/*/
	if (_QS_module_virtualSectors) then {
		if (_QS_uiTime > _QS_module_virtualSectors_checkDelay) then {
			if (missionNamespace getVariable 'QS_virtualSectors_AI_triggerInit') then {
				missionNamespace setVariable ['QS_virtualSectors_AI_triggerInit',_false,_false];
				_QS_module_virtualSectors_aoPos = missionNamespace getVariable 'QS_AOpos';
				_QS_module_virtualSectors_aoSize = missionNamespace getVariable 'QS_aoSize';
				_QS_module_virtualSectors_vehiclesEnabled = _false;
				if ((count(((_QS_module_virtualSectors_aoPos select [0,2]) nearRoads _QS_module_virtualSectors_aoSize) select {((_x isEqualType objNull) && ((roadsConnectedTo _x) isNotEqualTo []))})) > 50) then {
					_QS_module_virtualSectors_vehiclesEnabled = _true;
				};
				_QS_module_virtualSectors_scriptCreateEnemy = [_QS_module_virtualSectors_vehiclesEnabled] spawn _fn_scEnemy;
				waitUntil {scriptDone _QS_module_virtualSectors_scriptCreateEnemy};
				uiSleep 0.1;
				_QS_module_virtualSectors_enemy_0 = missionNamespace getVariable 'QS_virtualSectors_enemy_0';
				_QS_module_virtualSectors_enemy_1 = missionNamespace getVariable 'QS_virtualSectors_enemy_1';
				_QS_module_virtualSectors_patrolsHeli = _QS_module_virtualSectors_enemy_1 # 0;
				_QS_module_virtualSectors_patrolsInf = _QS_module_virtualSectors_enemy_1 # 1;
				_QS_module_virtualSectors_patrolsVeh = _QS_module_virtualSectors_enemy_1 # 2;
				_QS_module_virtualSectors_patrolsGarrison = _QS_module_virtualSectors_enemy_1 # 3;
				_QS_module_virtualSectors_patrolsBoat = _QS_module_virtualSectors_enemy_1 # 4;
				_QS_module_virtualSectors_patrolsSniper = _QS_module_virtualSectors_enemy_1 # 5;
				_QS_module_virtualSectors_patrolsInf_thresh = round ((count _QS_module_virtualSectors_patrolsInf) / 2);
				_QS_module_virtualSectors_patrolsVeh_thresh = round ((count _QS_module_virtualSectors_patrolsVeh) / 2);
				_QS_module_virtualSectors_patrolsSniper_thresh = round ((count _QS_module_virtualSectors_patrolsSniper) / 2);
				missionNamespace setVariable ['QS_virtualSectors_enemy_0',[],_false];
				missionNamespace setVariable ['QS_virtualSectors_enemy_1',[],_false];
				_QS_module_tracers_checkOverride = _true;
				if (_QS_module_virtualSectors_assaultEnabled) then {
					if ((random 1) >= _QS_module_virtualSectors_assaultChance) then {
						_QS_module_virtualSectors_assaultReady = _true;
						_QS_module_virtualSectors_assaultScore = random [0.5,0.666,0.8];
						_QS_module_virtualSectors_assaultDuration = _QS_module_virtualSectors_assaultDuration_fixed + (random _QS_module_virtualSectors_assaultDuration_variable);
					};
				};
			};
			if (missionNamespace getVariable 'QS_virtualSectors_active') then {
				//comment 'General sectors info';
				if (_QS_allPlayersCount < 10) then {
					_QS_module_virtualSectors_maxAI = _QS_module_virtualSectors_maxAI_0;
					_QS_module_virtualSectors_maxAISector = _QS_module_virtualSectors_maxAISector_0;
					_QS_module_virtualSectors_maxAIX = _QS_module_virtualSectors_maxAIX_0;
					_QS_module_virtualSectors_patrolsInf_thresh = round (16 / 2);
				};
				if (_QS_allPlayersCount >= 10) then {
					_QS_module_virtualSectors_maxAI = _QS_module_virtualSectors_maxAI_1;
					_QS_module_virtualSectors_maxAISector = _QS_module_virtualSectors_maxAISector_1;
					_QS_module_virtualSectors_maxAIX = _QS_module_virtualSectors_maxAIX_1;
					_QS_module_virtualSectors_patrolsInf_thresh = round (24 / 2);
				};
				if (_QS_allPlayersCount >= 20) then {
					_QS_module_virtualSectors_maxAI = _QS_module_virtualSectors_maxAI_2;
					_QS_module_virtualSectors_maxAISector = _QS_module_virtualSectors_maxAISector_2;
					_QS_module_virtualSectors_maxAIX = _QS_module_virtualSectors_maxAIX_2;
					_QS_module_virtualSectors_patrolsInf_thresh = round (32 / 2);
				};
				if (_QS_allPlayersCount >= 30) then {
					_QS_module_virtualSectors_maxAI = _QS_module_virtualSectors_maxAI_3;
					_QS_module_virtualSectors_maxAISector = _QS_module_virtualSectors_maxAISector_3;
					_QS_module_virtualSectors_maxAIX = _QS_module_virtualSectors_maxAIX_3;
					_QS_module_virtualSectors_patrolsInf_thresh = round (40 / 2);
				};
				if (_QS_allPlayersCount >= 40) then {
					_QS_module_virtualSectors_maxAI = _QS_module_virtualSectors_maxAI_4;
					_QS_module_virtualSectors_maxAISector = _QS_module_virtualSectors_maxAISector_4;
					_QS_module_virtualSectors_maxAIX = _QS_module_virtualSectors_maxAIX_4;
					_QS_module_virtualSectors_patrolsInf_thresh = round (48 / 2);
				};
				if (_QS_allPlayersCount >= 50) then {
					_QS_module_virtualSectors_maxAI = _QS_module_virtualSectors_maxAI_5;
					_QS_module_virtualSectors_maxAISector = _QS_module_virtualSectors_maxAISector_5;
					_QS_module_virtualSectors_maxAIX = _QS_module_virtualSectors_maxAIX_5;
					_QS_module_virtualSectors_patrolsInf_thresh = round (56 / 2);
				};
				//comment 'Manage assault';
				_QS_module_virtualSectors_scoreSides = missionNamespace getVariable ['QS_virtualSectors_scoreSides',[0,0,0,0,0]];
				_QS_module_virtualSectors_resultsFactors = missionNamespace getVariable ['QS_virtualSectors_resultsFactors',[0,0,0,0,0,0]];
				if (_QS_module_virtualSectors_assaultEnabled) then {
					if (_QS_module_virtualSectors_assaultReady) then {
						if (!(_QS_module_virtualSectors_assaultActive)) then {
							//comment 'Assault not active';
							if ((_QS_module_virtualSectors_scoreSides # 1) >= _QS_module_virtualSectors_assaultScore) then {
								_QS_module_virtualSectors_assaultActive = _true;
								diag_log '***** QS AI - Sector Assault Active *****';
								
								//comment 'Select sector herePick random WEST-owned sector';
								_QS_module_virtualSectors_assaultDuration = _QS_uiTime + _QS_module_virtualSectors_assaultDuration_fixed + (random _QS_module_virtualSectors_assaultDuration_variable);
							};
						} else {
							//comment 'Assault active';
							if (_QS_diag_tickTimeNow > _QS_module_virtualSectors_assaultDuration) then {
								//comment 'Assault terminated';
							} else {
								//comment 'Assault active';
							};
						};
					};
				};
				//comment 'Manage general area patrols';
				_QS_module_virtualSectors_patrolsInf = _QS_module_virtualSectors_patrolsInf select {(alive _x)};
				if (!(_QS_module_virtualSectors_patrolFallback)) then {
					if ((_QS_module_virtualSectors_scoreSides # 1) >= _QS_module_virtualSectors_scoreEndClose) then {
						_QS_module_virtualSectors_patrolFallback = _true;
						diag_log '***** QS AI - Patrol Fall Back *****';
						if (_QS_module_virtualSectors_patrolsInf isNotEqualTo []) then {
							{
								_QS_grp = group _x;
								if (!isNull _QS_grp) then {
									{
										_QS_unit = _x;
										{
											_QS_unit forgetTarget _x;
											_QS_grp forgetTarget _x;
										} forEach (_QS_unit targets [_true,0]);
										{
											_QS_unit enableAIFeature [_x # 0,_x # 1];
										} forEach [
											//['AUTOCOMBAT',_false],
											['COVER',_false],
											['SUPPRESSION',_false],
											['PATH',_true]
										];
										_QS_unit forceSpeed 24;
										_QS_unit setAnimSpeedCoef 1.15;
										_QS_unit enableStamina _false;
										_QS_unit enableFatigue _false;
									} count (units _QS_grp);
									{
										_movePos = [_x,(getPosATL (leader _QS_grp)),(side _QS_grp)] call _fn_scGetNearestSector;
										if (_movePos isNotEqualTo []) exitWith {};
									} forEach [2,3];
									if (_movePos isNotEqualTo []) then {
										_QS_grp setVariable [
											'QS_AI_GRP_CONFIG',
											[
												'SC',
												((_QS_grp getVariable ['QS_AI_GRP_CONFIG',['','','']]) # 1),
												((_QS_grp getVariable ['QS_AI_GRP_CONFIG',['','','']]) # 2)
											],
											_false
										];
										_QS_grp setVariable ['QS_AI_GRP_TASK',['DEFEND',_movePos,_QS_serverTime,-1],_false];
									};
								};
							} forEach _QS_module_virtualSectors_patrolsInf;
						};
					};
					_QS_module_virtualSectors_countAIInfPatrols = count _QS_module_virtualSectors_patrolsInf;
					if (_QS_module_virtualSectors_countAIInfPatrols < (_QS_module_virtualSectors_patrolsInf_thresh - 4)) then {
						if ((count _QS_module_unitBehaviors_localUnits) < _QS_unitCap) then {
							//comment 'Spawn more radial inf patrols';
							_QS_module_virtualSectors_spawnedGrp = [-2,_QS_module_virtualSectors_countAIInfPatrols,_QS_module_virtualSectors_patrolsInf_thresh] call _fn_scSpawnGroup;
							if (_QS_module_virtualSectors_spawnedGrp isNotEqualTo []) then {
								{
									_QS_module_virtualSectors_patrolsInf pushBack _x;
								} forEach (units _QS_module_virtualSectors_spawnedGrp);
								_QS_module_virtualSectors_enemy_1 set [1,_QS_module_virtualSectors_patrolsInf];
							};
						};
					};
				};
				//comment 'Manage vehicle patrols';
				if (_QS_module_virtualSectors_vehiclesEnabled) then {
					if (missionNamespace getVariable 'QS_virtualSectors_sub_2_active') then {
						if (_QS_uiTime > _QS_module_virtualSectors_patrolsVeh_checkDelay) then {
							_QS_module_virtualSectors_patrolsVeh = _QS_module_virtualSectors_patrolsVeh select {(alive _x)};
							if (({((_x isKindOf 'LandVehicle') && (!(_x isKindOf 'StaticWeapon')))} count _QS_module_virtualSectors_patrolsVeh) < 2) then {
								if ((count _QS_module_unitBehaviors_localUnits) < _QS_unitCap) then {
									_QS_module_virtualSectors_spawnedGrp = [0] call _fn_scSpawnLandVehicle;
									if (_QS_module_virtualSectors_spawnedGrp isNotEqualTo []) then {
										{
											_QS_module_virtualSectors_patrolsVeh pushBack _x;
										} forEach _QS_module_virtualSectors_spawnedGrp;
										_QS_module_virtualSectors_enemy_1 set [2,_QS_module_virtualSectors_patrolsVeh];
									};
								};
							};
							_QS_module_virtualSectors_patrolsVeh_checkDelay = _QS_uiTime + _QS_module_virtualSectors_patrolsVeh_delay;
						};
					};
				};
				//comment 'Manage heli patrols';
				if (_QS_diag_fps > 10) then {
					if (_QS_module_virtualSectors_heliEnabled) then {
						if (missionNamespace getVariable 'QS_virtualSectors_sub_2_active') then {
							if (_QS_uiTime > _QS_module_virtualSectors_patrolsHeli_checkDelay) then {
								_QS_module_virtualSectors_patrolsHeli = _QS_module_virtualSectors_patrolsHeli select {(alive _x)};
								if ((_QS_module_virtualSectors_patrolsHeli findIf {(_x isKindOf 'Helicopter')}) isEqualTo -1) then {
									if ((count _QS_module_unitBehaviors_localUnits) < _QS_unitCap) then {
										_QS_module_virtualSectors_spawnedGrp = [0] call _fn_scSpawnHeli;
										if (_QS_module_virtualSectors_spawnedGrp isNotEqualTo []) then {
											{
												_QS_module_virtualSectors_patrolsHeli pushBack _x;
											} forEach _QS_module_virtualSectors_spawnedGrp;
											_QS_module_virtualSectors_enemy_1 set [0,_QS_module_virtualSectors_patrolsHeli];
										};
									};
								};
								_QS_module_virtualSectors_patrolsHeli_checkDelay = _QS_uiTime + (_QS_module_virtualSectors_patrolsHeli_delay + (random 120));
							};
						};
					};
					//comment 'Manage UAV patrol';
					if ((_QS_module_virtualSectors_uavEnabled) && {missionNamespace getVariable ['QS_enemyUAVSpawningEnabled',FALSE]}) then {
						if (missionNamespace getVariable 'QS_virtualSectors_sub_1_active') then {
							if (_QS_uiTime > _QS_module_virtualSectors_uav_checkDelay) then {
								_QS_module_virtualSectors_uavs = _QS_module_virtualSectors_uavs select {(alive _x)};
								if ((_QS_module_virtualSectors_uavs findIf {(unitIsUav _x)}) isEqualTo -1) then {
									_QS_module_virtualSectors_spawnedGrp = [] call _fn_scSpawnUAV;
									if (_QS_module_virtualSectors_spawnedGrp isNotEqualTo []) then {
										{
											_QS_module_virtualSectors_uavs pushBack _x;
										} forEach _QS_module_virtualSectors_spawnedGrp;
									};
								};
								_QS_module_virtualSectors_uav_checkDelay = _QS_uiTime + _QS_module_virtualSectors_uav_delay;
							};
						};
					};
					if (_QS_module_viperTeam) then {
						if (_QS_uiTime > _QS_module_viperTeam_checkDelay) then {
							if (_QS_uiTime > _QS_module_viperTeam_respawnCheckDelay) then {
								_QS_module_viperTeam_array = _QS_module_viperTeam_array select {(alive _x)};
								if (_QS_allPlayersCount > 10) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_1;} else {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_0;};
								if (_QS_allPlayersCount > 20) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_1;};
								if (_QS_allPlayersCount > 30) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_2;};
								if (_QS_allPlayersCount > 40) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_2;};
								if (_QS_allPlayersCount > 50) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_3;};
								if (
									(_QS_allPlayersCount > 10) &&
									{((count _QS_module_viperTeam_array) < ((round (_QS_module_viperTeam_qty / 2)) max 0))}
								) then {
									_array = ['SC',(count _QS_module_viperTeam_array),_QS_module_viperTeam_qty,_QS_module_viperTeam_grp] call _fn_spawnViperTeam;
									{
										_QS_module_viperTeam_grp = group _x;
										_QS_module_viperTeam_array pushBack _x;
									} forEach _array;
									_QS_module_viperTeam_respawnCheckDelay = _QS_uiTime + _QS_module_viperTeam_respawnDelay;
								};
							};
							_QS_module_viperTeam_checkDelay = _QS_uiTime + _QS_module_viperTeam_delay;
						};
					};
				};
				if (_QS_uiTime > _QS_module_virtualSectors_defenderCheckDelay) then {
					_QS_module_virtualSectors_countAI = 0;
					{
						if (_x isNotEqualTo []) then {
							_array = _x;
							_array = _array select {(alive _x)};
							_QS_module_virtualSectors_assignedUnits set [_forEachIndex,_array];
							_QS_module_virtualSectors_countAI = _QS_module_virtualSectors_countAI + (count _array);
						};
					} forEach _QS_module_virtualSectors_assignedUnits;
					_QS_module_virtualSectors_data = missionNamespace getVariable 'QS_virtualSectors_data';
					if (_QS_module_virtualSectors_data isNotEqualTo []) then {
						{
							_QS_module_virtualSectors_sectorData = _x;
							_QS_module_virtualSectors_sectorData params [
								'_sectorID',
								'_isActive',
								'_nextEvaluationTime',
								'_increment',
								'_minConversionTime',
								'_interruptMultiplier',
								'_areaType',
								'_centerPos',
								'_areaOrRadiusConvert',
								'_areaOrRadiusInterrupt',
								'_sidesOwnedBy',
								'_sidesCanConvert',
								'_sidesCanInterrupt',
								'_conversionValue',
								'_conversionValuePrior',
								'_conversionAlgorithm',
								'_importance',
								'_flagData',
								'_sectorAreaObjects',
								'_locationData',
								'_objectData',
								'_markerData',
								'_taskData',
								'_initFunction',
								'_manageFunction',
								'_exitFunction',
								'_conversionRate',
								'_isBeingInterrupted'
							];
							//comment 'Manage sector patrols';
							/*/ Debug lines
							if (!isNil 'QS_module_virtualSectors_maxAI') then {
								_QS_module_virtualSectors_maxAI = QS_module_virtualSectors_maxAI;
							};
							if (!isNil 'QS_module_virtualSectors_maxAISector') then {
								_QS_module_virtualSectors_maxAISector = QS_module_virtualSectors_maxAISector;
							};
							if (!isNil 'QS_module_virtualSectors_maxAIX') then {
								_QS_module_virtualSectors_maxAIX = QS_module_virtualSectors_maxAIX;
							};
							/*/
							_QS_module_virtualSectors_assignedUnitsSector = _QS_module_virtualSectors_assignedUnits # _forEachIndex;
							_QS_module_virtualSectors_countAISector = count _QS_module_virtualSectors_assignedUnitsSector;
							if (_QS_module_virtualSectors_countAISector <= (_QS_module_virtualSectors_maxAISector - _QS_module_virtualSectors_spawnGroupCount)) then {
								//comment 'Spawn more AI';
								_QS_module_virtualSectors_spawnedGrp = [_QS_module_virtualSectors_sectorData,_QS_module_virtualSectors_spawnGroupCount] call _fn_scSpawnGroup;
								{
									_QS_module_virtualSectors_assignedUnitsSector pushBack _x;
								} forEach (units _QS_module_virtualSectors_spawnedGrp);
								_QS_module_virtualSectors_assignedUnits set [_forEachIndex,_QS_module_virtualSectors_assignedUnitsSector];
							};
						} forEach _QS_module_virtualSectors_data;
						_QS_module_virtualSectors_defenderCheckDelay = _QS_uiTime + _QS_module_virtualSectors_defenderDelay;
					};
					if (_QS_uiTime > _QS_module_virtualSectors_attackerCheckDelay) then {
						//comment 'Fourth block of AI here, spawned all over zone and move between to nearest contested sector';
						_QS_module_virtualSectors_assignedUnitsSector = _QS_module_virtualSectors_assignedUnits # 3;
						_QS_module_virtualSectors_countAISector = count _QS_module_virtualSectors_assignedUnitsSector;
						if (_QS_module_virtualSectors_countAISector <= (_QS_module_virtualSectors_maxAIX - _QS_module_virtualSectors_spawnGroupCount)) then {
							_QS_module_virtualSectors_spawnedGrp = [-1,_QS_module_virtualSectors_spawnGroupCount] call _fn_scSpawnGroup;
							{
								_QS_module_virtualSectors_assignedUnitsSector pushBack _x;
							} forEach (units _QS_module_virtualSectors_spawnedGrp);
							_QS_module_virtualSectors_assignedUnits set [3,_QS_module_virtualSectors_assignedUnitsSector];
						};
						_QS_module_virtualSectors_attackerCheckDelay = _QS_uiTime + _QS_module_virtualSectors_attackerDelay;
					};
				};
			};
			_QS_module_virtualSectors_checkDelay = diag_tickTime + _QS_module_virtualSectors_delay;
		};
		if (!(missionNamespace getVariable 'QS_virtualSectors_active')) then {
			if (missionNamespace getVariable 'QS_virtualSectors_AI_triggerDeinit') then {
				missionNamespace setVariable ['QS_virtualSectors_AI_triggerDeinit',_false,_false];
				missionNamespace setVariable ['QS_AI_insertHeli_spawnedAO',0,_false];
				{
					_QS_module_virtualSectors_assignedUnitsSector = _x;
					{
						if (!isNull _x) then {
							missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
							uiSleep 0.05;
							if (!([1,0,_x] call _fn_serverObjectsRecycler)) then {
								if (_x isKindOf 'CAManBase') then {
									if (!isNull (objectParent _x)) then {
										if ((objectParent _x) isKindOf 'AllVehicles') then {
											(objectParent _x) deleteVehicleCrew _x;
										} else {
											deleteVehicle _x;
										};
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							};
						};
					} forEach _QS_module_virtualSectors_assignedUnitsSector;
				} forEach _QS_module_virtualSectors_assignedUnits;
				_QS_module_virtualSectors_assignedUnits = [[],[],[],[]];
				_QS_module_virtualSectors_assignedUnitsSector = [];
				if (_QS_module_virtualSectors_enemy_0 isNotEqualTo []) then {
					{
						if (_x isEqualType objNull) then {
							if (!isNull _x) then {
								missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
								uiSleep 0.05;
								if (!([1,0,_x] call _fn_serverObjectsRecycler)) then {
									if (_x isKindOf 'CAManBase') then {
										if (!isNull (objectParent _x)) then {
											if ((objectParent _x) isKindOf 'AllVehicles') then {
												(objectParent _x) deleteVehicleCrew _x;
											} else {
												deleteVehicle _x;
											};
										} else {
											deleteVehicle _x;
										};
									} else {
										deleteVehicle _x;
									};
								};
							};
						};
					} forEach _QS_module_virtualSectors_enemy_0;
					_QS_module_virtualSectors_enemy_0 = [];
				};
				if (_QS_module_virtualSectors_enemy_1 isNotEqualTo []) then {
					{
						_array = _x;
						if (_array isEqualType []) then {
							if (_array isNotEqualTo []) then {
								{
									if (_x isEqualType objNull) then {
										if (!isNull _x) then {
											missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
											uiSleep 0.05;
											if (!([1,0,_x] call _fn_serverObjectsRecycler)) then {
												if (_x isKindOf 'CAManBase') then {
													if (!isNull (objectParent _x)) then {
														if ((objectParent _x) isKindOf 'AllVehicles') then {
															(objectParent _x) deleteVehicleCrew _x;
														} else {
															deleteVehicle _x;
														};
													} else {
														deleteVehicle _x;
													};
												} else {
													deleteVehicle _x;
												};
											};
										};
									};
								} forEach _array;
								_array = [];
							};
						};
					} forEach _QS_module_virtualSectors_enemy_1;
					_QS_module_virtualSectors_enemy_1 = [];
				};
				if (_QS_module_virtualSectors_uavs isNotEqualTo []) then {
					{
						if (_x isEqualType objNull) then {
							if (!isNull _x) then {
								missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
								_x setDamage [1,_false];
								uiSleep 0.1;
								deleteVehicle _x;
							};
						};
					} forEach _QS_module_virtualSectors_uavs;
				};
				if (_QS_module_viperTeam_array isNotEqualTo []) then {
					{
						if (_x isEqualType objNull) then {
							if (!isNull _x) then {
								missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
								uiSleep 0.1;
								if (_x isKindOf 'CAManBase') then {
									if (!isNull (objectParent _x)) then {
										if ((objectParent _x) isKindOf 'AllVehicles') then {
											(objectParent _x) deleteVehicleCrew _x;
										} else {
											deleteVehicle _x;
										};
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							};
						};
					} forEach _QS_module_viperTeam_array;
					_QS_module_viperTeam_array = [];
					_QS_module_viperTeam_grp = grpNull;
				};
				_QS_module_virtualSectors_patrolsHeli = [];
				_QS_module_virtualSectors_patrolsInf = [];
				_QS_module_virtualSectors_patrolsVeh = [];
				_QS_module_virtualSectors_patrolsGarrison = [];
				_QS_module_virtualSectors_patrolsBoat = [];
				_QS_module_virtualSectors_patrolsSniper = [];
				_QS_module_virtualSectors_countAIInfPatrols = 0;
				_QS_module_virtualSectors_countAIVehPatrols = 0;
				_QS_module_virtualSectors_countAISnpPatrols = 0;
				_QS_module_virtualSectors_patrolFallback = _false;
				_QS_module_virtualSectors_assaultReady = _false;
				_QS_module_virtualSectors_assaultActive = _false;
				_QS_module_virtualSectors_assaultArray = [];
				_QS_module_viperTeam_array = [];
				missionNamespace setVariable ['QS_virtualSectors_AI_triggerDeinit',_false,_false];
			};
		};
	};
	
	/*/Module classic AOs/*/
	if (_QS_module_classic) then {
		if (_QS_uiTime > _QS_module_classic_checkDelay) then {
			if (missionNamespace getVariable 'QS_classic_AI_triggerInit') then {
				missionNamespace setVariable ['QS_classic_AI_triggerInit',_false,_false];
				_QS_module_classic_aoPos = missionNamespace getVariable 'QS_AOpos';
				_QS_module_classic_aoSize = missionNamespace getVariable 'QS_aoSize';
				_QS_module_classic_aoData = missionNamespace getVariable 'QS_classic_AOData';
				_QS_module_classic_hqPos = missionNamespace getVariable 'QS_hqPos';
				_QS_module_classic_terrainData = [1,_QS_module_classic_aoPos,_QS_module_classic_aoSize,_QS_module_classic_aoData,_true] spawn _fn_aoGetTerrainData;
				waitUntil {
					(scriptDone _QS_module_classic_terrainData)
				};
				_QS_module_classic_scriptCreateEnemy = [_QS_module_classic_aoPos,_false,_QS_module_classic_aoData] spawn _fn_aoEnemy;
				waitUntil {
					(scriptDone _QS_module_classic_scriptCreateEnemy)
				};
				if (
					_QS_module_classic_aoUrbanSpawning &&
					(missionNamespace getVariable ['QS_ao_urbanSpawn',_false])
				) then {
					_QS_module_classic_scriptAOUrbanSpawn = ['INIT'] spawn _fn_aoUrbanSpawn;
					waitUntil {
						(scriptDone _QS_module_classic_scriptAOUrbanSpawn)
					};
				};
				uiSleep 0.25;
				_QS_module_classic_enemy_0 = missionNamespace getVariable ['QS_classic_AI_enemy_0',[]];
				missionNamespace setVariable ['QS_classic_AI_enemy_0',[],_false];
				_QS_module_classic_infReinforce_enabled = (_QS_module_classic_aoData # 8) isEqualTo 1;
				_QS_module_classic_vehReinforce_enabled = (_QS_module_classic_aoData # 9) isEqualTo 1;
				_QS_module_classic_efb = _false;
				_QS_module_classic_infReinforce_spawned = 0;
				_QS_module_classic_vehReinforce_spawned = 0;
				_QS_module_classic_efb_checkDelay = _QS_uiTime + 600;
				_QS_module_classic_infReinforce_array = [];
				_QS_module_classic_vehReinforce_array = _QS_module_classic_enemy_0 select {((_x isKindOf 'LandVehicle') && (!(_x isKindOf 'StaticWeapon')))};
				_QS_module_classic_patrolsHeli = [];
				_QS_module_classic_uavs = [];
				_QS_module_tracers_checkOverride = _true;
// Added Code
				_QS_module_classic_pressure = ['INIT',_QS_module_classic_aoPos,_QS_module_classic_aoSize,_QS_module_classic_hqPos,_QS_module_classic_enemy_0,_QS_unitCap,(_QS_module_classic_infReinforce && _QS_module_classic_infReinforce_enabled),(_QS_module_classic_vehReinforce && _QS_module_classic_vehReinforce_enabled)] call QS_fnc_aoPressure;
// End Updated Code
			};
			if (missionNamespace getVariable 'QS_classic_AI_active') then {
				if ((missionNamespace getVariable ['QS_classic_AI_enemy_0',[]]) isNotEqualTo []) then {
					{
						_QS_module_classic_enemy_0 pushBack _x;
					} forEach (missionNamespace getVariable ['QS_classic_AI_enemy_0',[]]);
					missionNamespace setVariable ['QS_classic_AI_enemy_0',[],_false];
				};
// Added Code
				if (_QS_module_classic_pressure) then {['TICK',_QS_module_classic_enemy_0 + _QS_module_classic_patrolsHeli + _QS_module_classic_uavs] call QS_fnc_aoPressure;};
// End Updated Code
				//comment 'Enemy inf reinforcements';
/* Legacy Code as of 9.9.2026 */
//|				if (_QS_module_classic_infReinforce) then {
// Updated Code
				// PRIMARY AO: the controller replaces this automatic infantry path so
				// legacy arrivals cannot bypass its shared limits and objective taper.
				if (_QS_module_classic_infReinforce && {!_QS_module_classic_pressure}) then {
// End Updated Code
					if (_QS_module_classic_infReinforce_enabled) then {
						if (_QS_uiTime > _QS_module_classic_infReinforce_checkDelay) then {
							if ((count _QS_module_unitBehaviors_localUnits) < _QS_unitCap) then {
								if (_QS_allPlayersCount > 10) then {_QS_module_classic_infReinforce_cap = _QS_module_classic_infReinforce_cap_0;} else {_QS_module_classic_infReinforce_cap = _QS_module_classic_infReinforce_cap_0;};
								if (_QS_allPlayersCount > 20) then {_QS_module_classic_infReinforce_cap = _QS_module_classic_infReinforce_cap_1;};
								if (_QS_allPlayersCount > 30) then {_QS_module_classic_infReinforce_cap = _QS_module_classic_infReinforce_cap_2;};
								if (_QS_allPlayersCount > 40) then {_QS_module_classic_infReinforce_cap = _QS_module_classic_infReinforce_cap_3;};
								if (_QS_allPlayersCount > 50) then {_QS_module_classic_infReinforce_cap = _QS_module_classic_infReinforce_cap_4;};
								if (_QS_module_classic_infReinforce_spawned < _QS_module_classic_infReinforce_cap) then {
									if (_QS_allPlayersCount < _QS_module_classic_infReinforce_playerThreshold) then {
										_QS_module_classic_infReinforce_limitReal = (_QS_module_classic_infReinforce_limit / 2);
									} else {
										_QS_module_classic_infReinforce_limitReal = _QS_module_classic_infReinforce_limit;
									};
									_QS_module_classic_infReinforce_array = _QS_module_classic_infReinforce_array select {(alive _x)};
									if ((count _QS_module_classic_infReinforce_array) < _QS_module_classic_infReinforce_limitReal) then {
										if ((count (((units _east) + (units _resistance)) inAreaArray [_QS_module_classic_aoPos,_QS_module_classic_aoSize,_QS_module_classic_aoSize,0,FALSE,-1])) < _QS_module_classic_infReinforce_AIThreshold) then {
											_QS_module_classic_spawnedEntities = [_QS_module_classic_aoPos] call _fn_aoEnemyReinforce;
											{
												_QS_module_classic_infReinforce_array pushBack _x;
											} forEach _QS_module_classic_spawnedEntities;
											if (!alive (missionNamespace getVariable ['QS_radioTower',objNull])) then {
												_QS_module_classic_infReinforce_spawned = _QS_module_classic_infReinforce_spawned + 4;			// 4 seems to be a good fit
												//_QS_module_classic_infReinforce_spawned = _QS_module_classic_infReinforce_spawned + (count _QS_module_classic_infReinforce_array);
											};
										};
									};
								};
							};
							_QS_module_classic_infReinforce_checkDelay = _QS_uiTime + (random [20,30,40]);
						};
					};
				};
				//comment 'Enemy vic reinforcements';
/* Legacy Code as of 9.9.2026 */
//|				if (_QS_module_classic_vehReinforce) then {
// Updated Code
				// PRIMARY AO: replacement armor uses the controller's separate slow
				// interval and live-vehicle cap. Keep the original path when inactive.
				if (_QS_module_classic_vehReinforce && {!_QS_module_classic_pressure}) then {
// End Updated Code
					if (_QS_module_classic_vehReinforce_enabled) then {
						if (_QS_uiTime > _QS_module_classic_vehReinforce_checkDelay) then {
							if ((count _QS_module_unitBehaviors_localUnits) < _QS_unitCap) then {
								if (_QS_allPlayersCount > 10) then {_QS_module_classic_vehReinforce_cap = _QS_module_classic_vehReinforce_cap_0;} else {_QS_module_classic_vehReinforce_cap = _QS_module_classic_vehReinforce_cap_0;};
								if (_QS_allPlayersCount > 20) then {_QS_module_classic_vehReinforce_cap = _QS_module_classic_vehReinforce_cap_1;};
								if (_QS_allPlayersCount > 30) then {_QS_module_classic_vehReinforce_cap = _QS_module_classic_vehReinforce_cap_2;};
								if (_QS_allPlayersCount > 40) then {_QS_module_classic_vehReinforce_cap = _QS_module_classic_vehReinforce_cap_3;};
								if (_QS_allPlayersCount > 50) then {_QS_module_classic_vehReinforce_cap = _QS_module_classic_vehReinforce_cap_4;};
								if (_QS_module_classic_vehReinforce_spawned < _QS_module_classic_vehReinforce_cap) then {
									if (_QS_allPlayersCount < _QS_module_classic_vehReinforce_playerThreshold) then {
										_QS_module_classic_vehReinforce_limitReal = (_QS_module_classic_vehReinforce_limit / 2);
									} else {
										_QS_module_classic_vehReinforce_limitReal = _QS_module_classic_vehReinforce_limit;
									};
									_QS_module_classic_vehReinforce_array = _QS_module_classic_vehReinforce_array select {(alive _x)};
									if (({((_x isKindOf 'LandVehicle') && (!(_x isKindOf 'StaticWeapon')))} count _QS_module_classic_vehReinforce_array) < _QS_module_classic_vehReinforce_limitReal) then {
										if ((count (((units _east) + (units _resistance)) inAreaArray [_QS_module_classic_aoPos,_QS_module_classic_aoSize,_QS_module_classic_aoSize,0,FALSE,-1])) < _QS_module_classic_vehReinforce_AIThreshold) then {	
											_QS_module_classic_spawnedEntities = [_QS_module_classic_aoPos] call _fn_aoEnemyReinforceVehicles;
											{
												_QS_module_classic_vehReinforce_array pushBack _x;
											} forEach _QS_module_classic_spawnedEntities;
											if (!(alive (missionNamespace getVariable ['QS_radioTower',objNull]))) then {
												_QS_module_classic_vehReinforce_spawned = _QS_module_classic_vehReinforce_spawned + 1;
											};
										};
									};
								};
							};
							_QS_module_classic_vehReinforce_checkDelay = _QS_uiTime + (random [20,30,40]);
						};
					};
				};
				//comment 'Enemy helo respawning';
				if (_QS_diag_fps > 10) then {
					if (_QS_module_classic_heliEnabled) then {
/* Legacy Code as of 9.9.2026 */
//|						if (alive (missionNamespace getVariable 'QS_radioTower')) then {
// Updated Code
						if (_QS_module_classic_pressure || {alive (missionNamespace getVariable 'QS_radioTower')}) then {
// End Updated Code
							if (_QS_uiTime > _QS_module_classic_patrolsHeli_checkDelay) then {
								_QS_module_classic_patrolsHeli = _QS_module_classic_patrolsHeli select {(alive _x)};
								if ((_QS_module_classic_patrolsHeli findIf {(_x isKindOf 'Helicopter')}) isEqualTo -1) then {
									if ((count _QS_module_unitBehaviors_localUnits) < _QS_unitCap) then {
/* Legacy Code as of 9.9.2026 */
//|										_QS_module_classic_spawnedGrp = [0] call _fn_scSpawnHeli;
// Updated Code
										_QS_module_classic_spawnedGrp = [];
										if (!_QS_module_classic_pressure || {['NATIVE','HELI',_QS_module_classic_patrolsHeli_delay + 60] call QS_fnc_aoPressure}) then {
											_QS_module_classic_spawnedGrp = [0] call _fn_scSpawnHeli;
											if (_QS_module_classic_pressure) then {['NATIVE_DONE',_QS_module_classic_spawnedGrp] call QS_fnc_aoPressure;};
										};
// End Updated Code
										if (_QS_module_classic_spawnedGrp isNotEqualTo []) then {
											{
												_QS_module_classic_patrolsHeli pushBack _x;
											} forEach _QS_module_classic_spawnedGrp;
										};
									};
								};
								_QS_module_classic_patrolsHeli_checkDelay = _QS_uiTime + (_QS_module_classic_patrolsHeli_delay + (random 120));
							};
						};
					};
					//comment 'Manage UAV patrol';
					if ((_QS_module_classic_uavEnabled) && {missionNamespace getVariable ['QS_enemyUAVSpawningEnabled',FALSE]}) then {
						if (_QS_uiTime > _QS_module_classic_uav_checkDelay) then {
							_QS_module_classic_uavs = _QS_module_classic_uavs select {(alive _x)};
							if ((_QS_module_classic_uavs findIf {(unitIsUav _x)}) isEqualTo -1) then {
/* Legacy Code as of 9.9.2026 */
//|								_QS_module_classic_spawnedGrp = [] call _fn_scSpawnUAV;
// Updated Code
								_QS_module_classic_spawnedGrp = [];
								if (!_QS_module_classic_pressure || {['NATIVE','UAV',_QS_module_classic_uav_delay] call QS_fnc_aoPressure}) then {
									_QS_module_classic_spawnedGrp = [] call _fn_scSpawnUAV;
											if (_QS_module_classic_pressure) then {['NATIVE_DONE',_QS_module_classic_spawnedGrp] call QS_fnc_aoPressure;};
								};
// End Updated Code
								if (_QS_module_classic_spawnedGrp isNotEqualTo []) then {
									{
										_QS_module_classic_uavs pushBack _x;
									} forEach _QS_module_classic_spawnedGrp;
								};
							};
							_QS_module_classic_uav_checkDelay = diag_tickTime + _QS_module_classic_uav_delay;
						};
					};
/* Legacy Code as of 9.9.2026 */
//|					if (_QS_module_viperTeam) then {
// Updated Code
					// PRIMARY AO: bypass separate automatic Viper top-ups while the shared
					// controller is active. Existing Vipers remain; no specialist spawner is added.
					if (_QS_module_viperTeam && {!_QS_module_classic_pressure}) then {
// End Updated Code
						if (_QS_uiTime > _QS_module_viperTeam_checkDelay) then {
							if (_QS_uiTime > _QS_module_viperTeam_respawnCheckDelay) then {
								if ((count _QS_module_unitBehaviors_localUnits) < _QS_unitCap) then {
									_QS_module_viperTeam_array = _QS_module_viperTeam_array select {(alive _x)};
									if (_QS_allPlayersCount > 10) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_1;} else {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_0;};
									if (_QS_allPlayersCount > 20) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_1;};
									if (_QS_allPlayersCount > 30) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_2;};
									if (_QS_allPlayersCount > 40) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_2;};
									if (_QS_allPlayersCount > 50) then {_QS_module_viperTeam_qty = _QS_module_viperTeam_qty_3;};
									if (
										(_QS_allPlayersCount > 10) &&
										{((count _QS_module_viperTeam_array) < ((round (_QS_module_viperTeam_qty / 2)) max 0))}
									) then {
										if (!(_QS_module_classic_efb)) then {
											_array = ['CLASSIC',(count _QS_module_viperTeam_array),_QS_module_viperTeam_qty,_QS_module_viperTeam_grp] call _fn_spawnViperTeam;
											{
												_QS_module_viperTeam_grp = group _x;
												_QS_module_viperTeam_array pushBack _x;
											} forEach _array;
											_QS_module_viperTeam_respawnCheckDelay = _QS_uiTime + _QS_module_viperTeam_respawnDelay;
										};
									};
								};
							};
							_QS_module_viperTeam_checkDelay = _QS_uiTime + _QS_module_viperTeam_delay;
						};
					};
				};
				//comment 'Enemy fallback';
/* Legacy Code as of 9.9.2026 */
//|				if (_QS_uiTime > _QS_module_classic_efb_checkDelay) then {
// Updated Code
				if (!_QS_module_classic_pressure && {_QS_uiTime > _QS_module_classic_efb_checkDelay}) then {
// End Updated Code
					if (!(_QS_module_classic_efb)) then {
						if ((count ((units _east) inAreaArray [_QS_module_classic_aoPos,_QS_module_classic_aoSize,_QS_module_classic_aoSize,0,FALSE,-1])) < _QS_module_classic_efb_threshold) then {
							_QS_module_classic_efb = _true;
							{
								_QS_module_classic_efb_group = _x;
								if ((side _QS_module_classic_efb_group) in _enemySides) then {
									if (((units _QS_module_classic_efb_group) findIf {(alive _x)}) isNotEqualTo -1) then {
										if (((leader _QS_module_classic_efb_group) distance2D _QS_module_classic_aoPos) < (_QS_module_classic_aoSize * 1.25)) then {
											if (!((vehicle (leader _QS_module_classic_efb_group)) isKindOf 'Air')) then {
												if (isNull (objectParent (leader _QS_module_classic_efb_group))) then {
													{
														//if ((random 1) > 0.5) then {
/* Legacy Code as of 9.9.2026 */
//|														if (_unit checkAIFeature 'MINEDETECTION') then {
// Updated Code
														// The current forEach member receives the PATH check and order.
														if (_x checkAIFeature 'MINEDETECTION') then {
// End Updated Code
															_x enableAIFeature ['PATH',TRUE];
														};
													} forEach (units _QS_module_classic_efb_group);
													_QS_module_classic_efb_group setSpeedMode 'FULL';
													_QS_module_classic_efb_group setBehaviour 'AWARE';
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_CONFIG',['GENERAL','INFANTRY',(count (units _QS_module_classic_efb_group))],_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_DATA',[],_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_TASK',['PATROL',[_QS_module_classic_hqPos,(_QS_module_classic_hqPos getPos [(50 + (random 50)),(random 360)]),(_QS_module_classic_hqPos getPos [(50 + (random 50)),(random 360)]),(_QS_module_classic_hqPos getPos [(50 + (random 50)),(random 360)])],serverTime,-1],_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_PATROLINDEX',0,_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP',_true,_false];
												};
												if (((objectParent (leader _QS_module_classic_efb_group)) isKindOf 'LandVehicle') && (!((objectParent (leader _QS_module_classic_efb_group)) isKindOf 'StaticWeapon'))) then {
													_QS_module_classic_efb_group setSpeedMode 'FULL';
													_QS_module_classic_efb_group setBehaviour 'AWARE';
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_CONFIG',['GENERAL','VEHICLE',(count (units _QS_module_classic_efb_group)),(objectParent (leader _QS_module_classic_efb_group))],_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_DATA',[],_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_TASK',['PATROL',[(_QS_module_classic_hqPos getPos [(50 + (random 50)),(random 360)]),(_QS_module_classic_hqPos getPos [(50 + (random 50)),(random 360)]),(_QS_module_classic_hqPos getPos [(50 + (random 50)),(random 360)])],serverTime,-1],_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP_PATROLINDEX',0,_false];
													_QS_module_classic_efb_group setVariable ['QS_AI_GRP',_true,_false];													
												};
											};
										};
									};
								};
							} forEach _QS_module_groupBehaviors_localGroups;
						};
					};
					_QS_module_classic_efb_checkDelay = _QS_uiTime + _QS_module_classic_efb_delay;
				};
			};	
			if (!(missionNamespace getVariable 'QS_classic_AI_active')) then {
				if (missionNamespace getVariable 'QS_classic_AI_triggerDeinit') then {
// Added Code
					if (_QS_module_classic_pressure) then {
						{_QS_module_classic_enemy_0 pushBackUnique _x;} forEach (['STOP'] call QS_fnc_aoPressure);
						_QS_module_classic_pressure = FALSE;
					};
// End Updated Code
					missionNamespace setVariable ['QS_AI_insertHeli_spawnedAO',0,_false];
					if (_QS_module_classic_enemy_0 isNotEqualTo []) then {
						{
							if (_x isEqualType objNull) then {
								if (!isNull _x) then {
									if ((_x isKindOf 'Air') || {(_x isKindOf 'LandVehicle')} || {(_x isKindOf 'Ship')}) then {
										(missionNamespace getVariable ['QS_normalAO_deferredAIObjects',[]]) pushBackUnique _x;
										_x setDamage [1,_false];
									} else {
										if ((_x isKindOf 'Building') || {(_x isKindOf 'House')}) then {
											(missionNamespace getVariable ['QS_normalAO_deferredAIObjects',[]]) pushBackUnique _x;
										} else {
											missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
											uiSleep 0.05;
											if (!([1,0,_x] call _fn_serverObjectsRecycler)) then {
												if (_x isKindOf 'CAManBase') then {
													if (!isNull (objectParent _x)) then {
														if ((objectParent _x) isKindOf 'AllVehicles') then {
															(objectParent _x) deleteVehicleCrew _x;
														} else {
															deleteVehicle _x;
														};
													} else {
														deleteVehicle _x;
													};
												} else {
													deleteVehicle _x;
												};
											};
										};
									};
								};
							};
						} forEach _QS_module_classic_enemy_0;
						_QS_module_classic_enemy_0 = [];
					};
					if (_QS_module_classic_infReinforce_array isNotEqualTo []) then {
						{
							if (_x isEqualType objNull) then {
								if (!isNull _x) then {
									missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
									uiSleep 0.05;
									if (!([1,0,_x] call _fn_serverObjectsRecycler)) then {
										if (_x isKindOf 'CAManBase') then {
											if (!isNull (objectParent _x)) then {
												if ((objectParent _x) isKindOf 'AllVehicles') then {
													(objectParent _x) deleteVehicleCrew _x;
												} else {
													deleteVehicle _x;
												};
											} else {
												deleteVehicle _x;
											};
										} else {
											deleteVehicle _x;
										};
									};
								};
							};
						} forEach _QS_module_classic_infReinforce_array;
						_QS_module_classic_infReinforce_array = [];
					};
					if (_QS_module_classic_vehReinforce_array isNotEqualTo []) then {
						{
							if (_x isEqualType objNull) then {
								if (!isNull _x) then {
									missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
									uiSleep 0.1;
									if (_x isKindOf 'CAManBase') then {
										if (!isNull (objectParent _x)) then {
											if ((objectParent _x) isKindOf 'AllVehicles') then {
												(objectParent _x) deleteVehicleCrew _x;
											} else {
												deleteVehicle _x;
											};
										} else {
											deleteVehicle _x;
										};
									} else {
										deleteVehicle _x;
									};
								};
							};
						} forEach _QS_module_classic_vehReinforce_array;
						_QS_module_classic_vehReinforce_array = [];
					};					
					if (_QS_module_classic_uavs isNotEqualTo []) then {
						{
							if (_x isEqualType objNull) then {
								if (!isNull _x) then {
									missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
									uiSleep 0.1;
									if (_x isKindOf 'CAManBase') then {
										if (!isNull (objectParent _x)) then {
											if ((objectParent _x) isKindOf 'AllVehicles') then {
												(objectParent _x) deleteVehicleCrew _x;
											} else {
												deleteVehicle _x;
											};
										} else {
											deleteVehicle _x;
										};
									} else {
										deleteVehicle _x;
									};
								};
							};
						} forEach _QS_module_classic_uavs;
						_QS_module_classic_uavs = [];
					};
					if (_QS_module_viperTeam_array isNotEqualTo []) then {
						{
							if (_x isEqualType objNull) then {
								if (!isNull _x) then {
									missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
									uiSleep 0.1;
									if (_x isKindOf 'CAManBase') then {
										if (!isNull (objectParent _x)) then {
											if ((objectParent _x) isKindOf 'AllVehicles') then {
												(objectParent _x) deleteVehicleCrew _x;
											} else {
												deleteVehicle _x;
											};
										} else {
											deleteVehicle _x;
										};
									} else {
										deleteVehicle _x;
									};
								};
							};
						} forEach _QS_module_viperTeam_array;
						_QS_module_viperTeam_array = [];
						_QS_module_viperTeam_grp = grpNull;
					};
					if (_QS_module_classic_patrolsHeli isNotEqualTo []) then {
						{
							if (_x isEqualType objNull) then {
								if (!isNull _x) then {
									missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
									uiSleep 0.1;
									if (_x isKindOf 'CAManBase') then {
										if (!isNull (objectParent _x)) then {
											if ((objectParent _x) isKindOf 'AllVehicles') then {
												(objectParent _x) deleteVehicleCrew _x;
											} else {
												deleteVehicle _x;
											};
										} else {
											deleteVehicle _x;
										};
									} else {
										deleteVehicle _x;
									};
								};
							};
						} forEach _QS_module_classic_patrolsHeli;
						_QS_module_classic_patrolsHeli = [];
					};
					missionNamespace setVariable ['QS_classic_AI_triggerDeinit',_false,_false];
				};
			};
/* Legacy Code as of 9.9.2026 */
//|			_QS_module_classic_checkDelay = diag_tickTime + _QS_module_classic_delay;
// Updated Code
			_QS_module_classic_checkDelay = diag_tickTime + ([_QS_module_classic_delay,3] select _QS_module_classic_pressure);
// End Updated Code
		};
	};
	/*/Module Grid/*/
	if (_QS_module_grid) then {
		if (_QS_uiTime > _QS_module_grid_checkDelay) then {
			if (missionNamespace getVariable ['QS_grid_AI_triggerDeinit',_false]) then {
				diag_log 'QS AI GRID deinit';
				missionNamespace setVariable ['QS_grid_AI_active',_false,_false];
				if (_QS_module_grid_enemy isNotEqualTo []) then {
					{
						_QS_module_grid_enemy_X = _x;
						{
							if (_x isKindOf 'CAManBase') then {
								if (!isNull (objectParent _x)) then {
									if ((objectParent _x) isKindOf 'AllVehicles') then {
										(objectParent _x) deleteVehicleCrew _x;
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							} else {
								deleteVehicle _x;
							};
						} forEach _QS_module_grid_enemy_X;
					} forEach _QS_module_grid_enemy;
					_QS_module_grid_enemy_X = [];
					_QS_module_grid_enemy = [];
				};
				if ((missionNamespace getVariable ['QS_primaryObjective_civilians',[]]) isNotEqualTo []) then {
					{
						if (!isNull _x) then {
							if (_x isKindOf 'CAManBase') then {
								if (!isNull (objectParent _x)) then {
									if ((objectParent _x) isKindOf 'AllVehicles') then {
										(objectParent _x) deleteVehicleCrew _x;
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							} else {
								deleteVehicle _x;
							};
						};
					} forEach (missionNamespace getVariable ['QS_primaryObjective_civilians',[]]);
					missionNamespace setVariable ['QS_primaryObjective_civilians',[],_false];
				};
				if ((missionNamespace getVariable ['QS_aoAnimals',[]]) isNotEqualTo []) then {
					{
						if (!isNull _x) then {
							missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
							if (_x isKindOf 'CAManBase') then {
								if (!isNull (objectParent _x)) then {
									if ((objectParent _x) isKindOf 'AllVehicles') then {
										(objectParent _x) deleteVehicleCrew _x;
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							} else {
								deleteVehicle _x;
							};
						};
					} count (missionNamespace getVariable 'QS_aoAnimals');
					missionNamespace setVariable ['QS_aoAnimals',[],_false];
				};
				if (_QS_module_grid_defendUnits isNotEqualTo []) then {
					{
						if (alive _x) then {
							missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),_false];
							if (_x isKindOf 'CAManBase') then {
								if (!isNull (objectParent _x)) then {
									if ((objectParent _x) isKindOf 'AllVehicles') then {
										(objectParent _x) deleteVehicleCrew _x;
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							} else {
								deleteVehicle _x;
							};
						};
					} forEach _QS_module_grid_defendUnits;
					_QS_module_grid_defendUnits = [];
				};
				missionNamespace setVariable ['QS_grid_AI_triggerDeinit',_false,_true];
			};
			if (missionNamespace getVariable ['QS_grid_AI_triggerInit',_false]) then {
				diag_log 'QS AI GRID init';
				missionNamespace setVariable ['QS_grid_AI_triggerInit',_false,_true];
				_QS_module_grid_aoPos = missionNamespace getVariable 'QS_aoPos';
				_QS_module_grid_aoSize = missionNamespace getVariable 'QS_aoSize';
				_QS_module_grid_aoData = missionNamespace getVariable 'QS_grid_aoData';
				_QS_module_grid_igPos = missionNamespace getVariable 'QS_grid_IGposition';
				_QS_module_grid_terrainData = [0,_QS_module_grid_aoPos,_QS_module_grid_aoSize,_QS_module_grid_aoData] call _fn_aoGetTerrainData;
				_QS_module_grid_scriptCreateEnemy = [_QS_module_grid_aoPos,_QS_module_grid_aoSize,_QS_module_grid_igPos,_QS_module_grid_aoData,_QS_module_grid_terrainData] spawn _fn_gridEnemy;
				waitUntil {
					uiSleep 0.1;
					(scriptDone _QS_module_grid_scriptCreateEnemy)
				};
				_QS_module_grid_enemy = missionNamespace getVariable ['QS_grid_AI_enemy_1',[]];
				_QS_module_grid_bldgPatrolUnits = _QS_module_grid_enemy # 1;
				_QS_module_grid_areaPatrolUnits = _QS_module_grid_enemy # 2;
				_QS_module_grid_bldgPatrolRespawnThreshold = (round ((count _QS_module_grid_bldgPatrolUnits) / 1.5)) max 0;
				_QS_module_grid_areaPatrolRespawnThreshold = (round ((count _QS_module_grid_areaPatrolUnits) / 1.5)) max 0;
				if (!isNil {_QS_module_grid_terrainData # 4}) then {
					_QS_module_civilian_houseCount = count (_QS_module_grid_terrainData # 4);
					if (_QS_module_civilian_houseCount > 0) then {
						_QS_module_civilian_count = _QS_module_civilian_count_1;
					} else {
						_QS_module_civilian_count = _QS_module_civilian_count_0;
					};
					if (_QS_module_civilian_houseCount > 5) then {
						_QS_module_civilian_count = _QS_module_civilian_count_2;
					};
					if (_QS_module_civilian_houseCount > 10) then {
						_QS_module_civilian_count = _QS_module_civilian_count_3;
					};
					if (_QS_module_civilian_houseCount > 15) then {
						_QS_module_civilian_count = _QS_module_civilian_count_4;
					};
					if (_QS_module_civilian_houseCount > 20) then {
						_QS_module_civilian_count = _QS_module_civilian_count_5;
					};
					if (_QS_module_civilian_houseCount > 25) then {
						_QS_module_civilian_count = _QS_module_civilian_count_6;
					};
					if (_QS_module_civilian_count > 0) then {
						if (_QS_ambientCivilians) then {
							missionNamespace setVariable [
								'QS_primaryObjective_civilians',
								([_QS_module_grid_aoPos,_QS_module_grid_aoSize,'FOOT',_QS_module_civilian_count,_false,_true] call _fn_spawnAmbientCivilians),
								_false
							];
						};
					};
				};
				if (_QS_ambientAnimals) then {
					for '_x' from 0 to 2 step 1 do {
						_QS_module_animalSpawnPosition = ['RADIUS',_QS_module_grid_aoPos,(_QS_module_grid_aoSize * 1.25),'LAND',[],_false,[[0,0,0],150,'2*meadow + hills + forest + trees',30,10],[],_false] call _fn_findRandomPos;
						if (!([_QS_module_animalSpawnPosition,50,6] call _fn_waterInRadius)) then {
							if ((_QS_module_animalSpawnPosition distance2D _QS_module_grid_aoPos) < (_QS_module_grid_aoSize * 1.5)) then {
								[_QS_module_animalSpawnPosition,(selectRandomWeighted ['SHEEP',0.4,'GOAT',0.3,'HEN',0.1]),(round (3 + (random 3)))] call _fn_aoAnimals;
							};
						};
						
					};
				};
				_QS_module_tracers_checkOverride = _true;
				missionNamespace setVariable ['QS_grid_AI_active',_true,_false];
			};
			if (missionNamespace getVariable ['QS_grid_AI_active',_false]) then {
				if (((missionNamespace getVariable ['QS_grid_enemyRespawnObjects',[]]) findIf {(!isNull _x)}) isNotEqualTo -1) then {
					if (_QS_uiTime > _QS_module_grid_bldgPatrol_checkDelay) then {
						_QS_module_grid_bldgPatrolUnits = _QS_module_grid_bldgPatrolUnits select {(alive _x)};
						if ((count _QS_module_grid_bldgPatrolUnits) < _QS_module_grid_bldgPatrolRespawnThreshold) then {
							_QS_module_grid_spawnArray = [0,_QS_module_grid_teamSize,_QS_module_grid_aoPos,_QS_module_grid_aoSize,_QS_module_grid_igPos,_QS_module_grid_aoData,_QS_module_grid_terrainData,(missionNamespace getVariable ['QS_grid_enemyRespawnObjects',[]])] call _fn_gridSpawnPatrol;
							if (_QS_module_grid_spawnArray isNotEqualTo []) then {
								{
									_QS_module_grid_bldgPatrolUnits pushBack _x;
								} forEach _QS_module_grid_spawnArray;
								_QS_module_grid_enemy set [1,_QS_module_grid_bldgPatrolUnits];
								_QS_module_grid_spawnArray = [];
							};
						};
						_QS_module_grid_bldgPatrol_checkDelay = diag_tickTime + _QS_module_grid_bldgPatrol_delay;
					};
					if (_QS_uiTime > _QS_module_grid_areaPatrol_checkDelay) then {
						_QS_module_grid_areaPatrolUnits = _QS_module_grid_areaPatrolUnits select {(alive _x)};
						if ((count _QS_module_grid_areaPatrolUnits) < _QS_module_grid_areaPatrolRespawnThreshold) then {
							_QS_module_grid_spawnArray = [1,_QS_module_grid_teamSize,_QS_module_grid_aoPos,_QS_module_grid_aoSize,_QS_module_grid_igPos,_QS_module_grid_aoData,_QS_module_grid_terrainData,(missionNamespace getVariable ['QS_grid_enemyRespawnObjects',[]])] call _fn_gridSpawnPatrol;
							if (_QS_module_grid_spawnArray isNotEqualTo []) then {
								{
									_QS_module_grid_areaPatrolUnits pushBack _x;
								} forEach _QS_module_grid_spawnArray;
								_QS_module_grid_enemy set [2,_QS_module_grid_areaPatrolUnits];
								_QS_module_grid_spawnArray = [];
							};
						};
						_QS_module_grid_areaPatrol_checkDelay = diag_tickTime + _QS_module_grid_areaPatrol_delay;
					};
				};
			};
			if (missionNamespace getVariable ['QS_grid_defend_AIinit',_false]) then {
				missionNamespace setVariable ['QS_grid_defend_AIinit',_false,_true];
			};			
			if (missionNamespace getVariable ['QS_grid_defend_active',_false]) then {
				if (_QS_allPlayersCount > 5) then {_QS_module_grid_defendQty = _QS_module_grid_defendQty_1;} else {_QS_module_grid_defendQty = _QS_module_grid_defendQty_0;};
				if (_QS_allPlayersCount > 10) then {_QS_module_grid_defendQty = _QS_module_grid_defendQty_2;};
				if (_QS_allPlayersCount > 15) then {_QS_module_grid_defendQty = _QS_module_grid_defendQty_3;};
				if (_QS_allPlayersCount > 20) then {_QS_module_grid_defendQty = _QS_module_grid_defendQty_4;};
				if (_QS_allPlayersCount > 30) then {_QS_module_grid_defendQty = _QS_module_grid_defendQty_5;};
				if (_QS_allPlayersCount > 40) then {_QS_module_grid_defendQty = _QS_module_grid_defendQty_5;};
				if (_QS_uiTime > _QS_module_grid_defend_checkDelay) then {
					_QS_module_grid_defendUnits = _QS_module_grid_defendUnits select {(alive _x)};
					if ((count _QS_module_grid_defendUnits) < _QS_module_grid_defendQty) then {
						_QS_module_grid_spawnArray = [0,_QS_module_grid_aoPos,_QS_module_grid_aoSize,_QS_module_grid_igPos,_QS_module_grid_teamSize] call _fn_gridSpawnAttack;
						if (_QS_module_grid_spawnArray isNotEqualTo []) then {
							{
								_QS_module_grid_defendUnits pushBack _x;
							} forEach _QS_module_grid_spawnArray;
							_QS_module_grid_spawnArray = [];
						};
					};
					_QS_module_grid_defend_checkDelay = diag_tickTime + _QS_module_grid_defend_delay;
				};
			};
			if (missionNamespace getVariable ['QS_grid_defend_AIdeInit',_false]) then {
				missionNamespace setVariable ['QS_grid_defend_AIdeInit',_false,_true];
				if (_QS_module_grid_defendUnits isNotEqualTo []) then {
					{
						if (!isNull _x) then {
							if (_x isKindOf 'CAManBase') then {
								if (!isNull (objectParent _x)) then {
									if ((objectParent _x) isKindOf 'AllVehicles') then {
										(objectParent _x) deleteVehicleCrew _x;
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							} else {
								deleteVehicle _x;
							};
						};
					} forEach _QS_module_grid_defendUnits;
					_QS_module_grid_defendUnits = [];
				};
			};
			_QS_module_grid_checkDelay = _QS_uiTime + _QS_module_grid_delay;
		};
	};
	
	/*/Module Ambient Hostility/*/

	if (_QS_module_ambientHostility) then {
		if (_QS_uiTime > _QS_module_ambientHostility_checkDelay) then {
			if (_QS_module_ambientHostility_inProgress) then {
				_QS_module_ambientHostility_entities = _QS_module_ambientHostility_entities select {(alive _x)};
				if (_QS_module_ambientHostility_entities isEqualTo []) then {
					_QS_module_ambientHostility_inProgress = _false;
					_QS_module_ambientHostility_cooldown = _QS_uiTime + (random 360);
				} else {
					{
						([_x,'SAFE'] call QS_fnc_inZone) params ['_inSafezone','_safezoneLevel','_safezoneActive'];
						if (_inSafezone && _safezoneActive && (_safezoneLevel > 1)) then {
							_x setDamage [1,_false];
						};
					} forEach _QS_module_ambientHostility_entities;
				};
				if (_QS_uiTime > _QS_module_ambientHostility_duration) then {
					{
						if (((units _west) inAreaArray [_x,800,800,0,FALSE,-1]) isEqualTo []) then {
							if (_x isKindOf 'CAManBase') then {
								if (!isNull (objectParent _x)) then {
									if ((objectParent _x) isKindOf 'AllVehicles') then {
										(objectParent _x) deleteVehicleCrew _x;
									} else {
										deleteVehicle _x;
									};
								} else {
									deleteVehicle _x;
								};
							} else {
								deleteVehicle _x;
							};
						};
					} forEach _QS_module_ambientHostility_entities;
				};
			} else {
				if (_QS_diag_fps > 10) then {
					if (_QS_uiTime > _QS_module_ambientHostility_cooldown) then {
						_QS_module_ambientHostility_validTargets = units _west;
						if (_QS_module_ambientHostility_validTargets isNotEqualTo []) then {
							_QS_module_ambientHostility_validTargets = _QS_module_ambientHostility_validTargets select { ((_x distance2D _basePosition) > 1500) && ((_x distance2D (missionNamespace getVariable 'QS_aoPos')) > 800) && ((lifeState _x) in ['HEALTHY','INJURED']) };
							if (_QS_module_ambientHostility_validTargets isNotEqualTo []) then {
								_QS_module_ambientHostility_validTargets = _QS_module_ambientHostility_validTargets select { ((((vehicle _x) isKindOf 'LandVehicle') || {((vehicle _x) isKindOf 'CAManBase')}) && (isTouchingGround (vehicle _x))) };
								if (_QS_module_ambientHostility_validTargets isNotEqualTo []) then {
									_QS_module_ambientHostility_graceTime = _QS_uiTime + 60;
									_QS_module_ambientHostility_duration = _QS_uiTime + (random [360,480,600]);
									_QS_module_ambientHostility_target = selectRandom _QS_module_ambientHostility_validTargets;
									_QS_module_ambientHostility_position = getPosATL _QS_module_ambientHostility_target;
									_QS_module_ambientHostility_nearbyCount = count (_QS_module_ambientHostility_validTargets inAreaArray [_QS_module_ambientHostility_position,100,100,0,_false,-1]);
									if (_QS_module_ambientHostility_entities isNotEqualTo []) then {
										{
											if (alive _x) then {
												if (
													(_x isKindOf 'CAManBase') &&
													{(!isNull (objectParent _x))}
												) then {
													(objectParent _x) deleteVehicleCrew _x;
												} else {
													deleteVehicle _x;
												};
											};
										} forEach _QS_module_ambientHostility_entities;
										_QS_module_ambientHostility_entities = [];
									};
									_QS_module_ambientHostility_entities = [0,_QS_module_ambientHostility_target,_QS_module_ambientHostility_nearbyCount] call _fn_ambientHostility;
									_QS_module_ambientHostility_inProgress = _QS_module_ambientHostility_entities isNotEqualTo [];
								};
							};
						};
					};
				};
			};
			_QS_module_ambientHostility_checkDelay = _QS_uiTime + _QS_module_ambientHostility_delay;
		};
	} else {
		if (_QS_module_ambientHostility_inProgress) then {
			_QS_module_ambientHostility_inProgress = _false;
			{
				_x setDamage [1,_false];
			} forEach _QS_module_ambientHostility_entities;
		};
	};
	/*/Module Enemy CAS/*/
	if (_QS_module_enemyCAS) then {
		if (_QS_uiTime > _QS_module_enemyCAS_checkDelay) then {
			if (!(missionNamespace getVariable 'QS_casSuspend')) then {
				missionNamespace setVariable ['QS_enemyCasArray2',((missionNamespace getVariable 'QS_enemyCasArray2') select {(alive _x)}),_false];
				_QS_module_enemyCas_array = missionNamespace getVariable ['QS_enemyCasArray2',[]];
				_playerJetCount = count (_QS_allPlayers select {((toLowerANSI (typeOf (vehicle _x))) in _QS_module_enemyCas_allJetTypes)});
				if (_QS_allPlayersCount > 10) then {
					if (_QS_allPlayersCount > 25) then {
						_QS_module_enemyCas_limit = _QS_module_enemyCas_limitHigh;
					} else {
						_QS_module_enemyCas_limit = _QS_module_enemyCas_limitLow;
					};
				} else {
					_QS_module_enemyCas_limit = 1;
				};
				if (_playerJetCount > 0) then {
					if (_playerJetCount > 1) then {
						_QS_module_enemyCas_limit = _QS_module_enemyCas_limit + 1;
					};
					_QS_module_enemyCAS_spawnDelay = _QS_module_enemyCAS_spawnDelayDefault / 1.5;
				} else {
					_QS_module_enemyCAS_spawnDelay = _QS_module_enemyCAS_spawnDelayDefault;
				};
				if (_QS_diag_fps > 10) then {
					if ((_QS_uiTime > _QS_module_enemyCAS_checkSpawnDelay) || {(missionNamespace getVariable 'QS_cycleCAS')} || {((missionNamespace getVariable 'QS_defendActive') && (_QS_module_enemyCas_array isEqualTo []) && (_playerJetCount > 1))}) then {
						if (((count _QS_module_enemyCas_array) < _QS_module_enemyCas_limit) || {(missionNamespace getVariable 'QS_cycleCAS')} || {((missionNamespace getVariable 'QS_defendActive') && (_QS_module_enemyCas_array isEqualTo []) && (_playerJetCount > 1))}) then {
							if (missionNamespace getVariable 'QS_cycleCAS') then {
								missionNamespace setVariable ['QS_cycleCAS',_false,_false];
							};
							call _fn_enemyCAS;
						};
						_QS_module_enemyCAS_checkSpawnDelay = _QS_uiTime + _QS_module_enemyCAS_spawnDelay;
					};
				};
				_QS_module_enemyCas_array = missionNamespace getVariable ['QS_enemyCasArray2',[]];
				if (_QS_module_enemyCas_array isNotEqualTo []) then {
					{
						_QS_module_enemyCas_plane = _x;
						if (alive _QS_module_enemyCas_plane) then {
							if (!(_QS_module_enemyCas_plane getVariable ['QS_AI_PLANE_fireMission',_false])) then {
								if ((_QS_module_enemyCas_plane getVariable ['QS_AI_PLANE_flyInHeight',-1]) > 0) then {
									_QS_module_enemyCas_speed = _QS_module_enemyCas_plane getVariable ['QS_enemy_casJetMaxSpeed',-1];
									if (_QS_module_enemyCas_speed isEqualTo -1) then {
										_QS_module_enemyCas_plane setVariable ['QS_enemy_casJetMaxSpeed',(getNumber ((configOf _QS_module_enemyCas_plane) >> 'maxSpeed')),_false];
									};
									_QS_module_enemyCas_plane forceSpeed ((_QS_module_enemyCas_plane getVariable ['QS_enemy_casJetMaxSpeed',1000]) * (random [0.7,0.85,1]));
									if ((_QS_module_enemyCas_plane getVariable ['QS_AI_PLANE_flyInHeight',-1]) isEqualTo 1) then {
										_QS_module_enemyCas_plane flyInHeight [(500 + (random 1000)),_true];
									};
									if ((_QS_module_enemyCas_plane getVariable ['QS_AI_PLANE_flyInHeight',-1]) isEqualTo 2) then {
										_QS_module_enemyCas_plane flyInHeight [(500 + (random 2000)),_true];
									};								
									if ((_QS_module_enemyCas_plane getVariable ['QS_AI_PLANE_flyInHeight',-1]) isEqualTo 3) then {
										_QS_module_enemyCas_plane flyInHeight [(500 + (random 3000)),_true];
									};
								};
							};
							if (_QS_serverTime > (_QS_module_enemyCas_plane getVariable ['QS_enemyCAS_nextRearmTime',-1])) then {
								_QS_module_enemyCas_plane setVehicleAmmo 1;
								_QS_module_enemyCas_plane setVariable ['QS_enemyCAS_nextRearmTime',(_QS_serverTime + 300),_false];
								if (((getPosWorld _QS_module_enemyCas_plane) distance2D (_QS_module_enemyCas_plane getVariable ['QS_enemyCAS_position',[0,0,0]])) < 25) then {
									_QS_module_enemyCas_plane setDamage [1,_false];
								} else {
									_QS_module_enemyCas_plane setVariable ['QS_enemyCAS_position',(getPosWorld _QS_module_enemyCas_plane),_false];
								};
							};
							if (alive _QS_module_enemyCas_plane) then {
								if (alive (currentPilot _QS_module_enemyCas_plane)) then {
									if (_QS_allPlayers isNotEqualTo []) then {
										{
											if ((vehicle _x) isKindOf 'Plane') then {
												if (_x isEqualTo (currentPilot (vehicle _x))) then {
													(group (currentPilot _QS_module_enemyCas_plane)) reveal [(vehicle _x),4];
													(currentPilot _QS_module_enemyCas_plane) reveal [vehicle _x,4];
													if (isNull (getAttackTarget (currentPilot _QS_module_enemyCas_plane))) then {
														(currentPilot _QS_module_enemyCas_plane) doTarget (vehicle _x);
													};
												};
											};
										} forEach _QS_allPlayers;
									};
									if ((missionNamespace getVariable ['QS_AI_laserTargets',[]]) isNotEqualTo []) then {
										{
											if (!isNull _x) then {
												(group (currentPilot _QS_module_enemyCas_plane)) reveal [_x,4];
												(currentPilot _QS_module_enemyCas_plane) reveal [_x,4];
											};
										} forEach (missionNamespace getVariable ['QS_AI_laserTargets',[]]);
									};
								};
							};
						};
					} forEach _QS_module_enemyCas_array;
				};
			};
			_QS_module_enemyCAS_checkDelay = diag_tickTime + _QS_module_enemyCAS_delay;
		};
	} else {
		if ((missionNamespace getVariable ['QS_enemyCasArray2',[]]) isNotEqualTo []) then {
			{
				_x setDamage [1,TRUE];
			} forEach (missionNamespace getVariable ['QS_enemyCasArray2',[]]);
		};
	};

	/*/Module support provision/*/
	if (_QS_module_supportProvision) then {
		if (_QS_uiTime > _QS_module_supportProvision_checkDelay) then {
			{
				missionNamespace setVariable _x;
				uiSleep 0.1;
			} forEach [
				['QS_AI_insertHeli_helis',((missionNamespace getVariable 'QS_AI_insertHeli_helis') select {(!alive _x)}),QS_system_AI_owners],
				['QS_AI_vehicles',((missionNamespace getVariable 'QS_AI_vehicles') select {(alive _x)}),QS_system_AI_owners],
				['QS_AI_targetsIntel',((missionNamespace getVariable 'QS_AI_targetsIntel') select {((alive (_x # 0)) && (_QS_serverTime < ((_x # 1) + 300)))}),QS_system_AI_owners],
				['QS_AI_laserTargets',((missionNamespace getVariable 'QS_AI_laserTargets') select {(!isNull _x)}),QS_system_AI_owners],
				['QS_AI_smokeTargets',((missionNamespace getVariable 'QS_AI_smokeTargets') select {(!isNull _x)}),QS_system_AI_owners]
			];
			if ((missionNamespace getVariable 'QS_AI_supportProviders_MTR') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_supportProviders_MTR',((missionNamespace getVariable 'QS_AI_supportProviders_MTR') select {((alive _x) && ((vehicle _x) isKindOf 'StaticWeapon'))}),QS_system_AI_owners];
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_supportProviders_ARTY') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_supportProviders_ARTY',((missionNamespace getVariable 'QS_AI_supportProviders_ARTY') select {((alive _x) && ((vehicle _x) isKindOf 'LandVehicle'))}),QS_system_AI_owners];
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_supportProviders_CASHELI') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_supportProviders_CASHELI',((missionNamespace getVariable 'QS_AI_supportProviders_CASHELI') select {((alive _x) && ((vehicle _x) isKindOf 'Helicopter'))}),QS_system_AI_owners];			
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_supportProviders_CASPLANE') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_supportProviders_CASPLANE',((missionNamespace getVariable 'QS_AI_supportProviders_CASPLANE') select {((alive _x) && ((vehicle _x) isKindOf 'Plane') && (canMove (vehicle _x)))}),QS_system_AI_owners];			
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_supportProviders_CASUAV') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_supportProviders_CASUAV',((missionNamespace getVariable 'QS_AI_supportProviders_CASUAV') select {((alive _x) && (unitIsUav (vehicle _x)) && (canMove (vehicle _x)))}),QS_system_AI_owners];			
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_supportProviders_INTEL') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_supportProviders_INTEL',((missionNamespace getVariable 'QS_AI_supportProviders_INTEL') select {(alive _x)}),QS_system_AI_owners];
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable ['QS_AI_fireMissions',[]]) isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_fireMissions',((missionNamespace getVariable 'QS_AI_fireMissions') select {(_QS_serverTime < (_x # 2))}),QS_system_AI_owners];
			};
			_QS_module_supportProvision_checkDelay = diag_tickTime + _QS_module_supportProvision_delay;
		};
	};
	if (_QS_module_scripts) then {
		if (_QS_uiTime > _QS_module_scripts_checkDelay) then {
			if ((missionNamespace getVariable 'QS_AI_scripts_Assault') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_scripts_Assault',((missionNamespace getVariable 'QS_AI_scripts_Assault') select { _QS_serverTime < _x }),QS_system_AI_owners];
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_scripts_fireMissions') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_scripts_fireMissions',((missionNamespace getVariable 'QS_AI_scripts_fireMissions') select { _QS_serverTime < _x }),QS_system_AI_owners];
			};
			uiSleep 0.1;			
			if ((missionNamespace getVariable 'QS_AI_scripts_moveToBldg') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_scripts_moveToBldg',((missionNamespace getVariable 'QS_AI_scripts_moveToBldg') select { _QS_serverTime < _x }),QS_system_AI_owners];
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_scripts_support') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_scripts_support',((missionNamespace getVariable 'QS_AI_scripts_support') select { _QS_serverTime < _x }),QS_system_AI_owners];
			};
			uiSleep 0.1;
			if ((missionNamespace getVariable 'QS_AI_unitsGestureReady') isNotEqualTo []) then {
				missionNamespace setVariable ['QS_AI_unitsGestureReady',((missionNamespace getVariable 'QS_AI_unitsGestureReady') select {((alive _x) && (_x getVariable ['QS_AI_UNIT_gestureEvent',_false]))}),QS_system_AI_owners];
			};
			if (_QS_diag_fps > 10) then {
				[11,_east,_true] spawn _fn_aiGetKnownEnemies;
				uiSleep 0.1;
			};
			_QS_module_scripts_checkDelay = _QS_uiTime + _QS_module_scripts_delay;
		};
	};
};
