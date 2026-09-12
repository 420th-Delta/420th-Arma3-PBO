/*/
File: fn_spawnGroup.sqf
Author:

	Quiksilver
	
Last Modified:

	5/10/2018 A3 1.84 by Quiksilver
	
Description:
	
	Spawn a group of enemies from pre-defined group config
	
Example:

	_grp = [_pos,_dir,_side,_type,FALSE] call (missionNamespace getVariable 'QS_fnc_spawnGroup');
______________________________________________/*/

/* Legacy Code as of 9.9.2026 */
//|params [['_pos',[]],['_dir',-1],['_side',sideUnknown],['_type',''],['_isProne',FALSE],['_grp',grpNull],['_useRecycler',FALSE],['_deleteWhenEmpty',TRUE]];
// Updated Code

// GROUND_SPACING_POLICIES_BEGIN
private _fn_groundCell = {
	params ['_center','_column','_row','_pitch','_heading'];
	private _right = _column * _pitch; private _forward = _row * _pitch;
	[(_center # 0) + _right * cos _heading + _forward * sin _heading,
	 (_center # 1) - _right * sin _heading + _forward * cos _heading,0]
};
private _fn_groundSeparate = {
	params ['_point','_occupied'];
	(_occupied findIf {(_point distance2D _x) < 15}) < 0
};
private _fn_groundPick = {
	params ['_points','_occupied','_count','_anchor'];
	private _slots = [];
	private _remaining = +_points;
	// Farthest valid cells spread the complete squad. Existing infantry and
	// construction reservations always keep their fifteen-metre exclusion.
	for '_i' from 1 to _count do {
		private _reference = _slots + _occupied;
		private _best = -1; private _score = -1;
		{
			private _point = _x;
			private _distance = _point distance2D _anchor;
			if (_reference isNotEqualTo []) then {
				_distance = 1e10;
				{_distance = _distance min (_point distance2D _x);} forEach _reference;
			};
			if ((_reference isEqualTo [] || {_distance >= 15}) && {_distance > _score}) then {
				_best = _forEachIndex; _score = _distance;
			};
		} forEach _remaining;
		if (_best < 0) exitWith {};
		_slots pushBack (_remaining deleteAt _best);
	};
	// A partial footprint is not an admitted squad. Never duplicate a cell
	// or discard occupancy to make the requested headcount fit.
	if (count _slots isEqualTo _count) then {_slots} else {[]}
};
// GROUND_SPACING_POLICIES_END
// Shared outdoor placement, before creation. Try the original 25 cells
// first, then at most three staggered patterns inside the SAME accepted
// 85 x 85 m square (81 candidate positions total). No anchor relocation or
// relaxed separation. Aircraft cargo, paradrops and deliberate elevated
// building/composition positions keep their own paths.
if ((_this param [0,[]]) in ['SLOTS','VEHICLE_SLOTS']) exitWith {
	params ['_mode','_anchor','_count',['_heading',0],['_class','O_Soldier_F'],['_separateGroups',TRUE],['_concealed',FALSE],['_exclusion',-1],['_validPosition',{TRUE}]];
	if (_count <= 0 || {_count > 32} || {_anchor isEqualTo []}) exitWith {[]};
	// The audited callers create on the server, then hand completed groups to
	// HCs. Local claim arrays cannot arbitrate simultaneous network owners.
	if (!isServer) exitWith {diag_log '[GroundSpawn] rejected non-server admission'; []};
	private _infantry = _mode isEqualTo 'SLOTS';
	private _result = [];
	private _started = diag_tickTime;
	// Clearance, terrain, rays and greedy layout remain schedulable. Only the
	// fresh occupancy check and claim insertion below are an atomic transaction.
	call {
		private _claims = (missionNamespace getVariable ['QS_groundSpawn_claims',[]]) select {diag_tickTime < (_x # 0)};
		private _occupied = []; private _hardOccupied = [];
		{_occupied append (_x # 2); if (_x param [3,FALSE]) then {_hardOccupied append (_x # 2);};} forEach _claims;
		private _near = _anchor nearEntities ['CAManBase',110];
		{if (alive _x && {isNull (objectParent _x)}) then {_occupied pushBack (getPosATL _x);};} forEach _near;
		// Include empty vehicles and wrecks; neither may be reused by infantry
		// or another vehicle. Airborne aircraft do not occupy ground cells.
		private _vehicles = nearestObjects [_anchor,['LandVehicle','Air','Ship'],110,TRUE];
		{if (((getPosATL _x) # 2) < 5) then {_hardOccupied pushBack (getPosATL _x);};} forEach _vehicles;
		private _players = allPlayers select {alive _x && {!(_x isKindOf 'HeadlessClient_F')}};
		private _playerRadius = [30,150] select _concealed;
		if (_exclusion >= 0) then {_playerRadius = _playerRadius max _exclusion;};
		private _viewers = if (_concealed) then {_players select {((getPosATL _x) # 2) < 20 && {(_x distance2D _anchor) < 1200}}} else {[]};
		private _points = [];
		// Extra terrain work happens only after the first footprint cannot fit.
		// Half-pitch offsets find other real positions without changing the
		// caller's accepted anchor, heading, footprint or terrain/player rules.
		private _patterns = [[0,0]];
		if (_infantry) then {_patterns append [[0.5,0],[0,0.5],[0.5,0.5]];};
		private _timedOut = FALSE;
		{
			if (_timedOut) exitWith {};
			_x params ['_offsetColumn','_offsetRow'];
			for '_row' from -2 to 2 do {
				if (_timedOut) exitWith {};
				for '_column' from -2 to 2 do {
					if (!canSuspend && {(diag_tickTime - _started) > 0.004}) exitWith {_timedOut = TRUE;};
					private _columnAt = _column + _offsetColumn;
					private _rowAt = _row + _offsetRow;
					// Skip nominal cells beyond the admitted square before asking
					// the engine for clearance; all four passes total at most 81.
					if (abs _columnAt <= 2 && {abs _rowAt <= 2}) then {
						private _cell = [_anchor,_columnAt,_rowAt,20.25,_heading] call _fn_groundCell;
						private _point = _cell findEmptyPosition [0,2,_class];
						if (_point isNotEqualTo []) then {
							private _dx = (_point # 0) - (_anchor # 0); private _dy = (_point # 1) - (_anchor # 1);
							if ((_point # 0) > 50 && {(_point # 1) > 50} &&
								{(_point # 0) < worldSize - 50} && {(_point # 1) < worldSize - 50} &&
								{abs (_dx * cos _heading - _dy * sin _heading) <= 42.5} &&
								{abs (_dx * sin _heading + _dy * cos _heading) <= 42.5} &&
								{!surfaceIsWater _point} && {((surfaceNormal _point) # 2) >= 0.9} &&
								{[_point,_hardOccupied] call _fn_groundSeparate} &&
								{[_point,_occupied] call _fn_groundSeparate} &&
								{(_players inAreaArray [_point,_playerRadius,_playerRadius,0,FALSE]) isEqualTo []} &&
								{!([_anchor,_point,10] call QS_fnc_waterIntersect)} &&
								{[_point] call _validPosition}) then {
								private _eye = (ATLToASL _point) vectorAdd [0,0,1.5];
								if ((_viewers findIf {!terrainIntersectASL [eyePos _x,_eye] && {!lineIntersects [eyePos _x,_eye,_x,objNull]}}) < 0) then {_points pushBackUnique _point;};
							};
						};
					};
				};
			};
			_result = [_points,_occupied,_count,_anchor] call _fn_groundPick;
			if (_result isNotEqualTo []) exitWith {};
			if (_timedOut || {!canSuspend && {(diag_tickTime - _started) > 0.004}}) exitWith {};
		} forEach _patterns;
	};
	if (_result isNotEqualTo []) then {
		isNil {
			private _claims = (missionNamespace getVariable ['QS_groundSpawn_claims',[]]) select {diag_tickTime < (_x # 0)};
			private _occupied = [];
			{_occupied append (_x # 2);} forEach _claims;
			{if (alive _x && {isNull objectParent _x}) then {_occupied pushBack getPosATL _x;};} forEach (_anchor nearEntities ['CAManBase',110]);
			{if (((getPosATL _x) # 2) < 5) then {_occupied pushBack getPosATL _x;};} forEach (nearestObjects [_anchor,['LandVehicle','Air','Ship'],110,TRUE]);
			private _players = allPlayers select {alive _x && {!(_x isKindOf 'HeadlessClient_F')}};
			private _radius = ([30,150] select _concealed) max _exclusion;
			// Another scheduled search may have committed, or a player/vehicle
			// moved here. Reject the stale layout; never overwrite its reservation.
			if ((_result findIf {
				!([_x,_occupied] call _fn_groundSeparate) ||
				{(_players inAreaArray [_x,_radius,_radius,0,FALSE]) isNotEqualTo []}
			}) >= 0) then {_result = [];} else {
				_claims pushBack [diag_tickTime + 20,+_anchor,+_result,!_infantry];
			};
			missionNamespace setVariable ['QS_groundSpawn_claims',_claims,FALSE];
		};
	};
	_result
};

params [['_pos',[]],['_dir',-1],['_side',sideUnknown],['_type',''],['_isProne',FALSE],['_grp',grpNull],['_useRecycler',FALSE],['_deleteWhenEmpty',TRUE],['_groundValid',{TRUE}],['_groundExclusion',-1]];
// End Updated Code
if (
	(_pos isEqualTo []) ||
	{(_dir isEqualTo -1)} ||
	{(_side isEqualTo sideUnknown)} ||
	{(_type isEqualTo '')}
) exitWith {grpNull};
private _unit = objNull;
if (_type isEqualType []) then {
	if ((_type findIf {(_x isEqualType 0)}) isNotEqualTo -1) then {
		_type = selectRandomWeighted _type;
	} else {
		_type = selectRandom _type;
	};
};
if (isNil '_type' || {!(_type isEqualType '')} || {_type isEqualTo ''}) exitWith {grpNull};
if (_useRecycler) then {
	_useRecycler = isDedicated;
};
private _groupComposition = QS_core_groups_map getOrDefault [toLowerANSI _type,[]];
if (_groupComposition isEqualTo []) exitWith {
	diag_log (format ['***** DEBUG ***** Group composition is null - %1 *****',_type]);
	grpNull;
};
private _perfGroup = ['spawnGroup.total',count _groupComposition,[_type,_useRecycler]] call QS_fnc_perfBegin;
// Added Code
// Off-map staging, aircraft cargo, water and elevated building placements
// keep their existing positions. Outdoor enemy infantry use the shared grid.
private _groundSlots = [];
// A ninth argument opts into rejectable outdoor placement. Legacy objective,
// building and existing-group callers retain their compact creation contract.
private _spread = (count _this > 8) && {(WEST getFriend _side) < 0.6} && {(_pos # 0) > 0} && {(_pos # 1) > 0} &&
	{(_pos # 0) < worldSize} && {(_pos # 1) < worldSize} && {abs (_pos param [2,0]) < 2} && {!surfaceIsWater _pos};
if (_spread) then {_groundSlots = ['SLOTS',_pos,count _groupComposition,_dir,'O_Soldier_F',TRUE,FALSE,_groundExclusion,_groundValid] call QS_fnc_spawnGroup;};
if (_spread && {_groundSlots isEqualTo []}) exitWith {[_perfGroup,0] call QS_fnc_perfEnd; grpNull};
// End Updated Code
if (isNull _grp) then {
	_grp = createGroup [_side,_deleteWhenEmpty];
	_grp setFormation 'WEDGE';
	_grp setFormDir _dir;
} else {
	if (_deleteWhenEmpty && (!isGroupDeletedWhenEmpty _grp)) then {
		_grp deleteGroupWhenEmpty TRUE;
	};
};
if (isNull _grp) exitWith {[_perfGroup,0] call QS_fnc_perfEnd; grpNull};
private _unitType = '';
for '_i' from 0 to ((count _groupComposition) - 1) step 1 do {
	_unitType = (_groupComposition # _i) # 0;
	private _resolvedUnitType = QS_core_units_map getOrDefault [toLowerANSI _unitType,_unitType];
	if (_useRecycler) then {
		_unit = [2,2,_resolvedUnitType] call (missionNamespace getVariable 'QS_fnc_serverObjectsRecycler');
		if (isNull _unit) then {
			private _perfCreate = ['spawnGroup.createUnit',1,[_resolvedUnitType]] call QS_fnc_perfBegin;
			_unit = _grp createUnit [_resolvedUnitType,[-1015,-1015,0],[],15,'NONE'];
			[_perfCreate,([0,1] select (!isNull _unit))] call QS_fnc_perfEnd;
			QS_core_unittraits_map set [typeOf _unit,getAllUnitTraits _unit,TRUE];
		} else {
			// wake up unit
			missionNamespace setVariable ['QS_analytics_entities_recycled',((missionNamespace getVariable ['QS_analytics_entities_recycled',0]) + 1),FALSE];
			{
				_unit setVariable [_x,nil,TRUE];
			} forEach (allVariables _unit);
			[_unit] joinSilent _grp;
			_unit setVariable ['QS_curator_disableEditability',FALSE,FALSE];
			_unit setVariable ['QS_dynSim_ignore',FALSE,FALSE];
			_unit hideObjectGlobal FALSE;
			_unit enableSimulationGlobal TRUE;
			_unit allowDamage TRUE;
			_unit enableAIFeature ['ALL',TRUE];
			_unitTraits = QS_core_unittraits_map getOrDefault [typeOf _unit,[]];
			if (_unitTraits isNotEqualTo []) then {
				{
					_unit setUnitTrait _x;
				} forEach _unitTraits;
			};
			_loadout = QS_hashmap_unitLoadouts_AI getOrDefaultCall [
				((_groupComposition # _i) # 0),
				{
					private _fallbackLoadout = getUnitLoadout _unit;
					if ([_fallbackLoadout] call (missionNamespace getVariable 'QS_fnc_isCreatorDLCContent')) then {
						[]
					} else {
						_fallbackLoadout
					}
				},
				TRUE
			];
			_unit setUnitLoadout [_loadout,TRUE];
			if ((damage _unit) > 0) then {
				_unit setDamage [0,FALSE];
			};
		};
	} else {
		private _perfCreate = ['spawnGroup.createUnit',1,[_resolvedUnitType]] call QS_fnc_perfBegin;
		_unit = _grp createUnit [_resolvedUnitType,[-1015,-1015,0],[],15,'NONE'];
		[_perfCreate,([0,1] select (!isNull _unit))] call QS_fnc_perfEnd;
		QS_core_unittraits_map set [typeOf _unit,getAllUnitTraits _unit,TRUE];
	};
	_unit = _unit call (missionNamespace getVariable 'QS_fnc_unitSetup');
	if ((rank _unit) isNotEqualTo ((_groupComposition # _i) # 1)) then {
		_unit setRank ((_groupComposition # _i) # 1);
	};
	if (_isProne) then {
		_unit switchMove 'amovppnemstpsraswrfldnon';
	};
	if ((side (group _unit)) isNotEqualTo _side) then {
		[_unit] joinSilent _grp;
	};
	_unit setDir _dir;
/* Legacy Code as of 9.9.2026 */
//|	_unit setVehiclePosition [(AGLToASL _pos),[],5,'NONE'];
// Updated Code
	if (_spread) then {_unit setPosATL (_groundSlots # _i);} else {_unit setVehiclePosition [(AGLToASL _pos),[],5,'NONE'];};
// End Updated Code
};
[_perfGroup,count (units _grp)] call QS_fnc_perfEnd;
_grp;
