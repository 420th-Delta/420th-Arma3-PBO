/* Priority AA has its own guard preset; ordinary side missions retain their defaults. */
params [['_anchor',objNull],['_vehiclePositions',[]]];
if (isNull _anchor || {(count _vehiclePositions) isNotEqualTo 3}) exitWith {[]};
private _position = getPosATL _anchor;
private _assets = [];
private _groups = [];
private _viperRoles = ['O_V_Soldier_TL_hex_F','O_V_Soldier_M_hex_F','O_V_Soldier_LAT_hex_F','O_V_Soldier_Medic_hex_F','O_V_Soldier_Exp_hex_F','O_V_Soldier_JTAC_hex_F','O_V_Soldier_hex_F','O_V_Soldier_M_hex_F'];
private _spawnInfantry = {
	params ['_count','_spawnPosition','_mode'];
	private _group = createGroup [EAST,TRUE];
	for '_index' from 0 to (_count - 1) do {
		private _type = _viperRoles # (_index mod (count _viperRoles));
		if (_mode isEqualTo 'OVERWATCH') then {_type = 'O_V_Soldier_M_hex_F'};
		private _unit = _group createUnit [_type,_spawnPosition,[],5,'NONE'];
		_unit call QS_fnc_unitSetup;
		[_unit] call QS_fnc_setCollectible;
		_assets pushBack _unit;
	};
	[(units _group),([1,4] select (_mode isEqualTo 'OVERWATCH'))] call QS_fnc_serverSetAISkill;
	if (_mode isEqualTo 'PATROL') then {
		[_group,_position,100,TRUE] call QS_fnc_taskPatrol;
		_group setVariable ['QS_AI_GRP',TRUE,QS_system_AI_owners];
		_group setVariable ['QS_AI_GRP_CONFIG',['GENERAL','INFANTRY',count units _group],QS_system_AI_owners];
		_group setVariable ['QS_AI_GRP_DATA',[TRUE,serverTime],QS_system_AI_owners];
	};
	if (_mode isEqualTo 'OVERWATCH') then {
		_group setBehaviourStrong 'COMBAT';
		_group setCombatMode 'RED';
		{_x setUnitPos 'DOWN'} forEach units _group;
	};
	if (_mode isEqualTo 'GARRISON') then {
		[_position,150,units _group,['House','Building'],[],FALSE] spawn QS_fnc_garrisonUnits;
	};
	_group setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
	_groups pushBack _group;
};
private _patrolCount = 1 + round (1 + random 2);
for '_patrol' from 1 to _patrolCount do {
	private _spawnPosition = _position getPos [40 + random 100,random 360];
	if (surfaceIsWater _spawnPosition) then {_spawnPosition = _position};
	[selectRandomWeighted [4,9,8,5],_spawnPosition,'PATROL'] call _spawnInfantry;
};
for '_pair' from 1 to 2 do {
	private _spawnPosition = _position getPos [80 + random 80,random 360];
	if (surfaceIsWater _spawnPosition) then {_spawnPosition = _position};
	[2,_spawnPosition,'OVERWATCH'] call _spawnInfantry;
};
[12,_position getPos [14,90],'GARRISON'] call _spawnInfantry;
{
	private _vehicle = createVehicle [_x,_vehiclePositions # _forEachIndex,[],0,'NONE'];
	_vehicle setDir (random 360);
	_vehicle allowCrewInImmobile [TRUE,TRUE];
	_vehicle lock 3;
	_vehicle enableVehicleCargo FALSE;
	_vehicle enableRopeAttach FALSE;
	_vehicle limitSpeed 40;
	_vehicle addEventHandler ['GetOut',QS_fnc_AIXDismountDisabled];
	_vehicle addEventHandler ['Killed',QS_fnc_vKilled2];
	[0,_vehicle,EAST,1] call QS_fnc_vSetup2;
	QS_AI_vehicles pushBackUnique _vehicle;
	private _group = createVehicleCrew _vehicle;
	{
		_x setUnitLoadout (selectRandom _viperRoles);
		_x call QS_fnc_unitSetup;
		[_x] call QS_fnc_setCollectible;
		_assets pushBack _x;
	} forEach crew _vehicle;
	[units _group,4] call QS_fnc_serverSetAISkill;
	[_group,_position,250,[],TRUE] call QS_fnc_taskPatrolVehicle;
	_group setVariable ['QS_AI_GRP',TRUE,QS_system_AI_owners];
	_group setVariable ['QS_AI_GRP_CONFIG',['GENERAL','VEHICLE',count units _group,_vehicle],QS_system_AI_owners];
	_group setVariable ['QS_AI_GRP_DATA',[TRUE,serverTime],QS_system_AI_owners];
	_group setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
	_assets pushBack _vehicle;
	_groups pushBack _group;
	if (_forEachIndex < 2) then {[_vehicle] call QS_fnc_airDefenseRegister};
} forEach ['O_APC_Tracked_02_AA_F','O_APC_Tracked_02_AA_F','O_MBT_02_cannon_F'];
_anchor setVariable ['QS_priorityAA_guardGroups',_groups,FALSE];
_assets
