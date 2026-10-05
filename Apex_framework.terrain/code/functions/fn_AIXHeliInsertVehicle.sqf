/*/
File: fn_AIXHeliInsertVehicle.sqf
Author:

	Quiksilver

Last modified:

	23/08/2022 A3 2.10 by Quiksilver

Description:

	Insert Vehicle via Heli drop

__________________________________________________/*/

params [
	['_position',[0,0,0]],
	['_vehicle',objNull],
	['_heliType','O_Heli_Transport_04_F'],
	['_side',EAST],
    ['_deliveryRequest',[],[[]]]
];
if (!isServer || {!canSuspend} || {isNull _vehicle} || {!alive _vehicle} || {!local _vehicle}) exitWith {};
private _requested = _deliveryRequest isNotEqualTo [];
private _requestId = _deliveryRequest param [0,'',['']];
private _requestedLZ = _deliveryRequest param [1,[],[[]]];
if (_requested && {_requestId isEqualTo '' || {count _requestedLZ isNotEqualTo 3} ||
    {(_requestedLZ findIf {!(_x isEqualType 0)}) >= 0}}) exitWith {};
missionNamespace setVariable ['QS_AI_insertHeli_helis',((missionNamespace getVariable 'QS_AI_insertHeli_helis') select {(alive _x)}),FALSE];
if (_heliType isEqualType []) then {
	_heliType = selectRandomWeighted _heliType;
};
private _loadCrew = +crew _vehicle;
private _loadGroups = [];
{_loadGroups pushBackUnique group _x;} forEach crew _vehicle;
private _loadHC = _loadGroups apply {[_x,_x getVariable ['QS_AI_GRP_HC_EXCLUDED',false]]};
private _fn_loadOwned = {
    !isNull _vehicle && {alive _vehicle} && {local _vehicle} &&
    {((crew _vehicle) findIf {isPlayer _x || {captive _x} || {!local _x} || {!isNull remoteControlled _x} || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}) < 0}
};
if (!(call _fn_loadOwned)) exitWith {};
_canSuspend = canSuspend;
_worldName = worldName;
_worldSize = worldSize + 2000;
_flyInHeight = 50;
_mapEdgePositions = [
	[-1000,-1000,_flyInHeight],
	[-1000,_worldSize,_flyInHeight],
	[_worldSize,_worldSize,_flyInHeight],
	[_worldSize,-1000,_flyInHeight],
	[-1000,(_worldSize / 2),_flyInHeight],
	[(_worldSize / 2),_worldSize,_flyInHeight],
	[_worldSize,(_worldSize / 2),_flyInHeight],
	[(_worldSize / 2),-1000,_flyInHeight]
];
private _mapEdgePosition = selectRandom _mapEdgePositions;
private _testDist = 99999;
if ((random 1) > 0) then {
	{
		if ((_x distance2D _position) < _testDist) then {
			_testDist = _x distance2D _position;
			_mapEdgePosition = _x;
		};
	} forEach _mapEdgePositions;
} else {
	_mapEdgePosition = selectRandom _mapEdgePositions;
};
private _foundHLZ = FALSE;
private _HLZ = [0,0,0];
private _allPlayers = allPlayers;
_helipadType = 'Land_HelipadEmpty_F';
if (_requested) then {
    _HLZ = +_requestedLZ;
    private _bounds = boundingBoxReal _vehicle;
    private _lo = _bounds param [0,[-5,-5,0]];
    private _hi = _bounds param [1,[5,5,0]];
    private _footprint = 5 max (abs (_lo # 0)) max (abs (_lo # 1)) max (abs (_hi # 0)) max (abs (_hi # 1));
    _foundHLZ = (_HLZ distance2D _position <= 400) && {!surfaceIsWater _HLZ} &&
        {(surfaceNormal _HLZ # 2) >= 0.9} &&
        {(_HLZ isFlatEmpty [_footprint,-1,0.5,1,0,false,objNull]) isNotEqualTo []} &&
        {(nearestObjects [_HLZ,[_helipadType],75,true]) isEqualTo []} &&
        {(nearestTerrainObjects [_HLZ,['TREE','SMALL TREE','ROCK','ROCKS','BUILDING','HOUSE'],17,false,true]) isEqualTo []} &&
        {(allPlayers inAreaArray [_HLZ,50,50,0,false]) isEqualTo []};
} else {
    for '_x' from 0 to 99 step 1 do {
    	_HLZ = [_position,0,300,17,0,0.5,0] call (missionNamespace getVariable 'QS_fnc_findSafePos');
    	if ((nearestObjects [_HLZ,[_helipadType],75,TRUE]) isEqualTo []) then {
    		if ((_allPlayers inAreaArray [_HLZ,50,50,0,FALSE]) isEqualTo []) then {
    			if ((_HLZ distance2D _position) < 300) then {
    				_foundHLZ = TRUE;
    			};
    		};
    	};
    	if (_foundHLZ) exitWith {};
    };
};
if (!(_foundHLZ)) exitWith {};
_HLZ set [2,0];
private _spawnPosition = [0,0,0];
private _foundSpawnPosition = FALSE;
for '_x' from 0 to 99 step 1 do {
	_spawnPosition = [_HLZ,1000,2500,1,0,0.5,0] call (missionNamespace getVariable 'QS_fnc_findSafePos');
	if (((_allPlayers inAreaArray [_spawnPosition,500,500,0,FALSE]) isEqualTo []) && {(_spawnPosition distance2D _position) <= 4490}) then {
		if ((((_spawnPosition select [0,2]) nearRoads 30) select {((_x isEqualType objNull) && ((roadsConnectedTo _x) isNotEqualTo []))}) isNotEqualTo []) then {
			_foundSpawnPosition = TRUE;
		};
	};
	if (_foundSpawnPosition) exitWith {};
};
if (!(_foundSpawnPosition)) exitWith {};
_spawnPosition set [2,0];
private _heli = objNull;
isNil {
    _heli = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _heliType,_heliType],_spawnPosition,[],500,'FLY'];
    _heli setVariable ['QS_heli_centerPosition',_position,false];
    _heli setVariable ['QS_Taru_requestId',_requestId,false];
};
_heli setVariable ['QS_Taru_spawnDistance',_heli distance2D _position,true];
_heli setVariable ['QS_dynSim_ignore',TRUE,TRUE];
_heli enableDynamicSimulation FALSE;
private _heliGroup = grpNull;
isNil {
    _heliGroup = createVehicleCrew _heli;
    _heli setVariable ['QS_Taru_ownedGroups',[_heliGroup]];
};
private _transportCrew = +crew _heli;
private _fn_setupOwned = {
    call _fn_loadOwned && {alive _heli} && {local _heli} &&
    {((_transportCrew + crew _heli) findIf {isPlayer _x || {captive _x} || {!local _x} || {!isNull remoteControlled _x} || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}) < 0}
};
private _fn_abortSetup = {
    {_x params ['_group','_excluded']; if (!isNull _group) then {_group setVariable ['QS_AI_GRP_HC_EXCLUDED',_excluded,true];};} forEach _loadHC;
    if (_heli getVariable ['QS_Taru_running',false]) exitWith {};
    if (!local _heli || {!local _heliGroup} ||
        {((_transportCrew + crew _heli + _loadCrew + crew _vehicle) findIf {isPlayer _x || {alive _x && {captive _x || {!local _x} || {!isNull remoteControlled _x} || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}}}) >= 0}) exitWith {
        _heli setVariable ['QS_Taru_result','CONTROL_HANDOFF',true];
        _heli setVariable ['QS_Taru_stage','CONTROL_HANDOFF',true];
    };

    ['VEHICLE',_heli,_vehicle,_HLZ,_mapEdgePosition,_position] call compile preprocessFileLineNumbers 'code\scripts\QS_TaruDelivery.sqf';
};
{_x setVariable ['QS_AI_GRP_HC_EXCLUDED',true,true];} forEach _loadGroups;

_heliGroup addVehicle _heli;
(missionNamespace getVariable 'QS_AI_insertHeli_helis') pushBack _heli;
_heliGroup deleteGroupWhenEmpty TRUE;
{
	_x setVariable ['QS_dynSim_ignore',TRUE,TRUE];
	_x enableDynamicSimulation FALSE;

} forEach (units _heliGroup);
_heli setVariable ['QS_heli_mapEdgePosition',_mapEdgePosition,FALSE];
_heli setVariable ['QS_heli_spawnPosition',_spawnPosition,FALSE];
_heli setVariable ['QS_heli_centerPosition',_position,FALSE];
_heli setVelocity [0,0,1];
_vehicle setVelocity [0,0,1];
_vehicle enableDynamicSimulation FALSE;
_vehicle setVariable ['QS_dynSim_ignore',TRUE,TRUE];
{
	(group _x) enableDynamicSimulation FALSE;
	_x setVariable ['QS_dynSim_ignore',TRUE,TRUE];
} forEach (crew _vehicle);
if (_canSuspend) then {
	sleep 3;
};
if (!(call _fn_setupOwned)) exitWith {call _fn_abortSetup;};
_heli setVelocity [0,0,1];
_vehicle setVelocity [0,0,1];
private _isSlingLoad = _heli setSlingLoad _vehicle;
if (_canSuspend) then {
	sleep 1;
};
if (!(call _fn_setupOwned)) exitWith {call _fn_abortSetup;};
if (isNull (getSlingLoad _heli)) then {
	_heli setSlingLoad _vehicle;
	if (_canSuspend) then {
		sleep 1;
	};
};
if (!(call _fn_setupOwned) || {(getSlingLoad _heli) isNotEqualTo _vehicle}) exitWith {call _fn_abortSetup;};
_heli addEventHandler ['Killed',(missionNamespace getVariable 'QS_fnc_vKilled2')];
_heli addEventHandler [
	'IncomingMissile',
	{
		params ['_vehicle','_ammo','_shooter','_instigator','_projectile'];
		if (alive (driver _vehicle)) then {
			_vehicle setVehicleAmmo 1;
			(driver _vehicle) forceWeaponFire ['CMFlareLauncher','AIBurst'];
			private _flareHandle = [driver _vehicle,_shooter,_projectile] spawn {
				params ['_pilot','_shooter','_projectile'];
				scriptName 'QS Incoming Missile Flares';
				_pilot forceWeaponFire ['CMFlareLauncher','AIBurst'];
				sleep 1;
				_pilot forceWeaponFire ['CMFlareLauncher','AIBurst'];
				sleep 1;
				_pilot forceWeaponFire ['CMFlareLauncher','AIBurst'];
				(vehicle _pilot) setVehicleAmmo 1;
				[_projectile,objNull] remoteExec ['setMissileTarget',_shooter,FALSE];
			};
			private _aux = (_vehicle getVariable ['QS_Taru_auxHandles',[]]) select {!scriptDone _x};
			_aux pushBack _flareHandle;
			_vehicle setVariable ['QS_Taru_auxHandles',_aux];
		};
	}
];
{_x params ['_group','_excluded']; if (!isNull _group) then {_group setVariable ['QS_AI_GRP_HC_EXCLUDED',_excluded,true];};} forEach _loadHC;
['VEHICLE',_heli,_vehicle,_HLZ,_mapEdgePosition,_position] call compile preprocessFileLineNumbers 'code\scripts\QS_TaruDelivery.sqf';
