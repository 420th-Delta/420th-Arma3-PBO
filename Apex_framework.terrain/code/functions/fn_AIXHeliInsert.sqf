/*/
File: fn_AIXHeliInsert.sqf
Author:

	Quiksilver

Last modified:

	21/10/2017 A3 1.76 by Quiksilver

Description:

	AI Behaviour - Heli Insert

Parameters:

	0 - Position
	1 - Side
	2 - Helo type
	3 - # of units ( percentage of cargo seats )
	4 - Unit Types
	5 - Use support
	6 - Support type
	7 - Manage squad after
__________________________________________________/*/

private _fn_taruShare = {
    params ['_connected','_sinceLift','_size','_ready','_roll'];
    if (!_ready || {_connected <= 0} || {_size <= 0}) exitWith {FALSE};
    if (_connected < 20) exitWith {_roll < 0.90};

    _sinceLift >= (7 * _size)
};

if ((_this param [0,[]]) isEqualTo 'TARU_POLICY') exitWith {
    (_this select [1]) call _fn_taruShare
};
if ((_this param [0,[]]) isEqualTo 'TARU_CREATE') exitWith {
    params ['','_entry','_size'];
    if (!isServer || {diag_fps < 18}) exitWith {[]};
    private _class = QS_core_vehicles_map getOrDefault ['o_heli_transport_04_covered_f','O_Heli_Transport_04_covered_F'];
    if (!isClass (configFile >> 'CfgVehicles' >> _class) ||
        {getNumber (configFile >> 'CfgVehicles' >> _class >> 'transportSoldier') < _size} ||
        {({alive _x && {!isPlayer _x} && {!captive _x}} count ((units EAST) + (units RESISTANCE))) + _size + 1 > 200}) exitWith {[]};
    private _pilots = createGroup [EAST,TRUE];
    if (isNull _pilots) exitWith {[]};
    _pilots setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
    private _heli = createVehicle [_class,_entry,[],0,'FLY'];
    if (isNull _heli) exitWith {deleteGroup _pilots; []};
    private _pilot = _pilots createUnit [QS_core_units_map getOrDefault ['o_helipilot_f','O_helipilot_F'],_entry,[],0,'NONE'];
    if (isNull _pilot) exitWith {deleteVehicle _heli; deleteGroup _pilots; []};
    _pilot moveInDriver _heli;
    if ((driver _heli) isNotEqualTo _pilot) exitWith {deleteVehicle _pilot; deleteVehicle _heli; deleteGroup _pilots; []};
    _pilot call QS_fnc_unitSetup;
    _pilots addVehicle _heli;
    _heli setPosATL _entry;
    _heli lock 3;
    _heli setVariable ['QS_dynSim_ignore',TRUE,TRUE];
    _heli enableDynamicSimulation FALSE;
    _pilot setVariable ['QS_dynSim_ignore',TRUE,TRUE];
    _pilot enableDynamicSimulation FALSE;
    clearWeaponCargoGlobal _heli;
    clearMagazineCargoGlobal _heli;
    clearItemCargoGlobal _heli;
    clearBackpackCargoGlobal _heli;
    [_heli,_pilots]
};
if ((_this param [0,[]]) isEqualTo 'TARU_DELIVER') exitWith {
    params ['','_heli','_cargo','_lz','_entry','_goal','_activity','_epoch',['_methodRequest','',['']]];
    ['TROOPS',_heli,_cargo,_lz,_entry,_goal,_activity,_epoch,true,_methodRequest] call compile preprocessFileLineNumbers 'code\scripts\QS_TaruDelivery.sqf'
};

params [
	['_position',[0,0,0]],
	['_side',EAST],
	['_heliType','O_Heli_Transport_04_covered_black_F'],
	['_nUnits',0.5],
	['_unitTypes',['O_V_Soldier_ghex_F']],
	['_useSupport',FALSE],
	['_supportType','O_Heli_Attack_02_dynamicLoadout_black_F'],
	['_useUnits',[]],
	['_manageGroup',FALSE],
    ['_deliveryRequest',[],[[]]]
];
private _requested = _deliveryRequest isNotEqualTo [];
private _requestId = _deliveryRequest param [0,'',['']];
private _requestedLZ = _deliveryRequest param [1,[],[[]]];
if (_requested && {_requestId isEqualTo '' || {count _requestedLZ isNotEqualTo 3} ||
    {(_requestedLZ findIf {!(_x isEqualType 0)}) >= 0}}) exitWith {};
missionNamespace setVariable ['QS_AI_insertHeli_helis',((missionNamespace getVariable 'QS_AI_insertHeli_helis') select {(alive _x)}),FALSE];
if (_heliType isEqualType []) then {
	_heliType = selectRandomWeighted _heliType;
};
if (_supportType isEqualType []) then {
	_supportType = selectRandomWeighted _supportType;
};
_worldName = worldName;
_worldSize = worldSize + 2000;
if (_unitTypes isEqualTo []) then {
	if (_side isEqualTo EAST) then {
		_unitTypes = ['o_soldier_f'];
	};
	if (_side isEqualTo WEST) then {
		_unitTypes = ['b_soldier_f'];
	};
	if (_side isEqualTo RESISTANCE) then {
		_unitTypes = ['i_soldier_f'];
	};
};
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
if ((random 1) > 0.333) then {
	{
		if ((_x distance2D _position) < _testDist) then {
			_testDist = _x distance2D _position;
			_mapEdgePosition = _x;
		};
	} forEach _mapEdgePositions;
} else {
	_mapEdgePosition = selectRandom _mapEdgePositions;
};

if ((_mapEdgePosition distance2D _position) > 4490) then {
    _mapEdgePosition = _position getPos [4490,_position getDir _mapEdgePosition];
    _mapEdgePosition set [2,_flyInHeight];
};
private _foundHLZ = FALSE;
private _HLZ = [0,0,0];
_helipadType = 'Land_HelipadEmpty_F';
if (_requested) then {
    _HLZ = +_requestedLZ;
    _foundHLZ = (_HLZ distance2D _position <= 400) && {!surfaceIsWater _HLZ} &&
        {(surfaceNormal _HLZ # 2) >= 0.9} &&
        {(_HLZ isFlatEmpty [17,-1,0.5,1,0,false,objNull]) isNotEqualTo []} &&
        {(nearestObjects [_HLZ,[_helipadType],75,true]) isEqualTo []} &&
        {(nearestTerrainObjects [_HLZ,['TREE','SMALL TREE','ROCK','ROCKS','BUILDING','HOUSE'],17,false,true]) isEqualTo []} &&
        {(allPlayers inAreaArray [_HLZ,50,50,0,false]) isEqualTo []};
} else {
    for '_x' from 0 to 99 step 1 do {
    	_HLZ = [_position,0,300,17,0,0.5,0] call (missionNamespace getVariable 'QS_fnc_findSafePos');
    	if (
    		((nearestObjects [_HLZ,[_helipadType],75,TRUE]) isEqualTo []) &&
    		{((nearestTerrainObjects [_HLZ,['TREE','SMALL TREE'],15,FALSE,TRUE]) isEqualTo [])} &&
    		{((allPlayers findIf {((_x distance2D _HLZ) < 50)}) isEqualTo -1)} &&
    		{((_HLZ distance2D _position) < 300)}
    	) exitWith {_foundHLZ = TRUE;};
    };
};
if (!(_foundHLZ)) exitWith {};
_HLZ set [2,0];
private _array = [];
private _heli = objNull;
isNil {
    _heli = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _heliType,_heliType],_mapEdgePosition,[],500,'FLY'];
    _heli setVariable ['QS_heli_centerPosition',_position,false];
    _heli setVariable ['QS_Taru_requestId',_requestId,false];
};
_heli setVariable ['QS_Taru_spawnDistance',_heli distance2D _position,true];
_heli setVariable ['QS_dynSim_ignore',TRUE,TRUE];
_heli enableDynamicSimulation FALSE;
private _heliGroup = grpNull;
isNil {
    _heliGroup = createGroup [EAST,TRUE];
    _heli setVariable ['QS_Taru_ownedGroups',[_heliGroup]];
};
_heliPilot = _heliGroup createUnit [(QS_core_units_map getOrDefault ['o_helipilot_f','o_helipilot_f']),(getPosWorld _heli),[],0,'NONE'];
_heliGroup addVehicle _heli;
_heliPilot assignAsDriver _heli;
_heliPilot moveInDriver _heli;

_array pushBack _heli;
{
	removeAllWeapons _x;
	_x setVariable ['QS_dynSim_ignore',TRUE,TRUE];
	_x enableDynamicSimulation FALSE;
} forEach (units _heliGroup);
_heli setVariable ['QS_heli_spawnPosition',_mapEdgePosition,FALSE];
_heli setVariable ['QS_heli_centerPosition',_position,FALSE];
_heli setVariable ['QS_Taru_stage','APPROACH_LAND',true];
_heli setVariable ['QS_Taru_result','RUNNING',true];
clearWeaponCargoGlobal _heli;
clearMagazineCargoGlobal _heli;
clearItemCargoGlobal _heli;
clearBackpackCargoGlobal _heli;
[_heli,TRUE] remoteExec ['lockInventory',0,FALSE];
[_heli,1,[]] call (missionNamespace getVariable 'QS_fnc_vehicleLoadouts');
_heli engineOn TRUE;
if (!(_heli isKindOf 'Heli_Transport_04_base_F')) then {
_heli addEventHandler [
	'HandleDamage',
	{
		params ['_vehicle','_selectionName','_damage','','','','',''];
		private _scale = 0.2;
		_oldDamage = [(_vehicle getHit _selectionName),(damage _vehicle)] select (_selectionName isEqualTo '');
		if (_selectionName isEqualTo '?') then {
			_scale = 0.2;
		};
		if ((_vehicle getHit 'tail_rotor_hit') > 0) then {
			_vehicle setHit ['tail_rotor_hit',0,TRUE];
		};
		_damage = ((_damage - _oldDamage) * _scale) + _oldDamage;
		_damage;
	}
];
};
_heli addEventHandler [
	'Deleted',
	{
		params ['_entity'];
		deleteVehicleCrew _entity;
		_helipad = _entity getVariable ['QS_assignedHelipad',objNull];
		if (!isNull _helipad) then {
			deleteVehicle _helipad;
		};
	}
];
_heli addEventHandler [
	'Killed',
	{
		params ['_killed','','',''];
		deleteVehicleCrew _killed;
		_killed removeAllEventHandlers 'Hit';
		_killed removeAllEventHandlers 'HandleDamage';
		_helipad = _killed getVariable ['QS_assignedHelipad',objNull];
		if (!isNull _helipad) then {
			deleteVehicle _helipad;
		};
	}
];
_heli addEventHandler ['Killed',(missionNamespace getVariable 'QS_fnc_vKilled2')];
_heli addEventHandler [
	'GetOut',
	{
		(_this # 2) setDamage [1,TRUE];
	}
];
_heli addEventHandler [
	'IncomingMissile',
	{
		params ['_vehicle','_ammo','_shooter','_instigator','_projectile'];
		if (alive (driver _vehicle)) then {
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
[_heli,2] remoteExecCall ['QS_fnc_serverSetEntityFeatureType',2,FALSE];
_heliGroup enableAttack FALSE;
{
	if (!(_heli isKindOf 'Heli_Transport_04_base_F')) then {_x allowDamage FALSE;};
	_x addEventHandler [
		'GetOutMan',
		{
			(_this # 0) setDamage [1,TRUE];
		}
	];
	_x enableAIFeature ['AUTOCOMBAT',FALSE];
	_x enableAIFeature ['COVER',FALSE];
	_x enableAIFeature ['TARGET',FALSE];
	_x enableAIFeature ['AUTOTARGET',FALSE];
	_x enableAIFeature ['SUPPRESSION',FALSE];
	_x enableStamina FALSE;
	_x enableFatigue FALSE;
	_x setSkill 0;
	_x allowFleeing 0;
	removeAllWeapons _x;
	_array pushBack _x;
} forEach (units _heliGroup);
_heli setUnloadInCombat [FALSE,FALSE];
_heli allowCrewInImmobile [TRUE,TRUE];
_heli flyInHeight (25 + (random 30));
_heli lock 3;
_direction = _mapEdgePosition getDir _HLZ;
_heli setDir _direction;
_heli setVehiclePosition [(getPosWorld _heli),[],0,'FLY'];
(missionNamespace getVariable 'QS_AI_insertHeli_helis') pushBack _heli;
private _spawnUnits = FALSE;
private _helipad = objNull;
isNil {
    _helipad = createVehicleLocal [_helipadType,_HLZ];
    _helipad setVariable ['QS_Taru_requestId',_requestId,false];
    _array pushBack _helipad;
    _heli setVariable ['QS_assignedHelipad',_helipad,FALSE];
};
_heliGroup setSpeedMode 'NORMAL';
_wp = _heliGroup addWaypoint [_HLZ,0];
_wp setWaypointType 'MOVE';
_wp setWaypointSpeed 'NORMAL';
_wp setWaypointBehaviour 'CARELESS';
_wp setWaypointCombatMode 'BLUE';
isNil {
    private _landingHandle = [_heli,_heliPilot,_heliGroup,_HLZ] spawn {
        params ['_transport','_originalPilot','_pilots','_lz'];
        private _arrivalBy = diag_tickTime + ((120 + (_transport distance2D _lz) / 25) min 900);
        private _owned = {
            local _transport && {local _pilots} &&
            {((crew _transport) findIf {isPlayer _x || {captive _x} || {!local _x} || {!isNull remoteControlled _x} || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}) < 0} &&
            {(driver _transport) isEqualTo _originalPilot}
        };
        waitUntil {
            uiSleep 0.5;
            isNull _transport || {!alive _transport} || {!alive _originalPilot} || {!(call _owned)} ||
            {_transport distance2D _lz < 200} || {diag_tickTime >= _arrivalBy}
        };
        if (isNull _transport) exitWith {};
        if (!(call _owned)) exitWith {_transport setVariable ['QS_Taru_result','CONTROL_HANDOFF',true];};
        if (alive _transport && {alive _originalPilot} && {canMove _transport} && {_transport distance2D _lz < 200}) then {
            [_originalPilot] call (missionNamespace getVariable 'QS_fnc_AIXHeliInsertLanding');
        } else {
            ['RETURN',_transport,objNull,getPosATL _transport,_transport getVariable ['QS_heli_spawnPosition',[0,0,150]],_lz,'',-1,false] call compile preprocessFileLineNumbers 'code\scripts\QS_TaruDelivery.sqf';
        };
    };
    _heli setVariable ['QS_Taru_landingHandle',_landingHandle];
    _heli setVariable ['QS_Taru_handles',[_landingHandle]];
};
private _supportGroup = grpNull;
if (_useSupport) then {
	if ((count allPlayers) > 10) then {
		_supportSpawnPosition = _heli getRelPos [100,90];
        if ((_supportSpawnPosition distance2D _position) > 4990) then {
            _supportSpawnPosition = _position getPos [4990,_position getDir _supportSpawnPosition];
        };
		_supportSpawnPosition set [2,50];
		_supportHeli = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _supportType,_supportType],_supportSpawnPosition,[],0,'FLY'];
		_supportHeli setVariable ['QS_dynSim_ignore',TRUE,TRUE];
		_supportHeli enableDynamicSimulation FALSE;
		_supportGroup = createVehicleCrew _supportHeli;
		_array pushBack _supportHeli;
		{
			_x setSkill 1;
			_x setVariable ['QS_dynSim_ignore',TRUE,TRUE];
			_x enableDynamicSimulation FALSE;
			removeAllWeapons _x;
			_array pushBack _x;
		} forEach (units _supportGroup);
		_supportHeli setDir _direction;
		[_supportHeli,1,[]] call (missionNamespace getVariable 'QS_fnc_vehicleLoadouts');
		(missionNamespace getVariable 'QS_AI_insertHeli_helis') pushBack _supportHeli;
		if ((random 1) > 0.333) then {
			_supportHeli flyInHeight (random [150,200,300]);
		};
		_supportGroup addVehicle _supportHeli;
		_supportHeli setUnloadInCombat [FALSE,FALSE];
		_supportHeli allowCrewInImmobile [TRUE,TRUE];
		_supportHeli lock 3;
		clearWeaponCargoGlobal _supportHeli;
		clearMagazineCargoGlobal _supportHeli;
		clearItemCargoGlobal _supportHeli;
		clearBackpackCargoGlobal _supportHeli;
		[_supportHeli,TRUE] remoteExec ['lockInventory',0,FALSE];
		[_supportHeli,2] remoteExecCall ['QS_fnc_serverSetEntityFeatureType',2,FALSE];

		_wp = _supportGroup addWaypoint [_HLZ,0];
		_wp setWaypointType 'LOITER';
		_wp setWaypointLoiterType 'CIRCLE_L';
		_wp setWaypointLoiterRadius (random [150,200,300]);

		_wp setWaypointBehaviour 'AWARE';
		_wp setWaypointCombatMode 'RED';
		_wp setWaypointForceBehaviour TRUE;
		_supportGroup setBehaviour 'COMBAT';
		_supportGroup lockWP TRUE;
		_supportGroup enableAttack TRUE;
		_supportGroup setBehaviour 'COMBAT';
		_supportGroup setCombatMode 'RED';
		_supportGroup setSpeedMode 'FULL';
		_supportHeli addEventHandler [
			'Deleted',
			{
				params ['_entity'];
				deleteVehicleCrew _entity;
			}
		];
		_supportHeli addEventHandler [
			'Killed',
			{
				params ['_killed','','',''];
				deleteVehicleCrew _killed;
			}
		];
		_supportHeli addEventHandler ['Killed',(missionNamespace getVariable 'QS_fnc_vKilled2')];
		_supportHeli addEventHandler [
			'GetOut',
			{
				(_this # 2) setDamage [1,FALSE];
			}
		];
		_heli addEventHandler [
			'Hit',
			{
				params ['_vehicle','_causedBy','_damage','_instigator'];
				_supportGroup = _vehicle getVariable ['QS_heliInsert_supportGroup',grpNull];
				if (!isNull _supportGroup) then {
					_supportGroup reveal [_instigator,4];
				};
			}
		];
		_supportHeli addEventHandler [
			'IncomingMissile',
			{
				params ['_vehicle','_ammo','_shooter','_instigator','_projectile'];
				if (alive (driver _vehicle)) then {
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
						if ((vehicle _shooter) isKindOf 'Air') then {
							[_projectile,objNull] remoteExec ['setMissileTarget',_shooter,FALSE];
						};
					};
					private _aux = (_vehicle getVariable ['QS_Taru_auxHandles',[]]) select {!scriptDone _x};
					_aux pushBack _flareHandle;
					_vehicle setVariable ['QS_Taru_auxHandles',_aux];
				};
			}
		];
		_heli setVariable ['QS_heliInsert_supportHeli',_supportHeli,FALSE];
		_heli setVariable ['QS_heliInsert_supportGroup',_supportGroup,FALSE];
		_timeDelete = time + 900;
		{
			if (_x isEqualType objNull) then {
				(missionNamespace getVariable 'QS_garbageCollector') pushBack [_x,'DELAYED_DISCREET',_timeDelete];
			};
		} forEach _array;
	};
};
if ((_manageGroup) && (_spawnUnits)) then {

	_timeout = time + 900;
	for '_x' from 0 to 1 step 0 do {
		if (((units _infantryGroup) findIf {(alive _x)}) isNotEqualTo -1) then {
			{
				if (isNull (objectParent _x)) then {
					doStop _x;
					_x doMove [((_position # 0) + (10 - (random 20))),((_position # 1) + (10 - (random 20))),(_position # 2)];
				};
				sleep 0.1;
			} forEach (units _infantryGroup);
		};
		if (!isNull _supportGroup) then {
			if (((units _supportGroup) findIf {(alive _x)}) isNotEqualTo -1) then {
				{
					if (!((behaviour _x) in ['COMBAT','AWARE'])) then {
						_x setBehaviour 'COMBAT';
					};
				} forEach (units _supportGroup);
				if (!((combatMode _supportGroup) in ['RED','YELLOW'])) then {
					_supportGroup setCombatMode 'RED';
				};
			};
		};
		if (time > _timeout) exitWith {};
		sleep 10;
	};
};
