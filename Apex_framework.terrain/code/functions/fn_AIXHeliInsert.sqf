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

// Added Code
// TARU_INTEGRATION_BEGIN
// These modes deliver one already-admitted squad. They never create extra cargo.
// TARU_SHARE_POLICY_BEGIN
private _fn_taruShare = {
    params ['_connected','_sinceLift','_size','_ready','_roll'];
    if (!_ready || {_connected <= 0} || {_size <= 0}) exitWith {FALSE};
    if (_connected < 20) exitWith {_roll < 0.90};
    // Seven squads' worth of ordinary arrivals buy one lift: <=12.5% by men.
    // Reset after a lift, so blocked flights cannot accumulate a catch-up burst.
    _sinceLift >= (7 * _size)
};
// TARU_SHARE_POLICY_END
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
    params ['','_heli','_cargo','_lz','_entry','_goal','_activity','_epoch'];
    if (!isServer || {!canSuspend} || {isNull _heli}) exitWith {};
    private _pilot = driver _heli;
    private _pilots = group _pilot;
    private _members = units _cargo;
    private _releaseComplete = FALSE;
    private _fn_exempt = {
        !isNull _this && {isPlayer _this || {captive _this} || {!local _this} ||
        {!isNull (remoteControlled _this)} || {!isNull (_this getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}
    };
    private _fn_owned = {(isNull _heli || {local _heli}) &&
        {_releaseComplete || {isNull _cargo} || {local _cargo}} && {isNull _pilots || {local _pilots}} &&
        {((([_members,[]] select _releaseComplete) + (units _pilots) + (crew _heli)) findIf {_x call _fn_exempt}) < 0}};
    private _fn_current = {
        call _fn_owned && {
            if (_activity isEqualTo 'PRIMARY') then {
                missionNamespace getVariable ['QS_primaryPressure_running',FALSE] &&
                {!(missionNamespace getVariable ['QS_defendActive',FALSE])} &&
                {(missionNamespace getVariable ['QS_primaryPressure_epoch',-1]) isEqualTo _epoch}
            } else {
                missionNamespace getVariable ['QS_defendControl_active',FALSE] &&
                {missionNamespace getVariable ['QS_defendActive',FALSE]} &&
                {(missionNamespace getVariable ['QS_defendControl_epoch',-1]) isEqualTo _epoch}
            }
        }
    };
    private _fn_flying = {call _fn_current && {alive _heli} && {canMove _heli} && {alive _pilot}};
    _cargo setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
    _cargo setVariable ['QS_taruDelivery_busy',TRUE,TRUE];
    _pilots setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
    _pilots setBehaviour 'CARELESS'; _pilots setCombatMode 'BLUE';
    _pilots setSpeedMode 'FULL'; _pilots allowFleeing 0;
    _pilot disableAI 'AUTOCOMBAT'; _pilot disableAI 'TARGET'; _pilot disableAI 'AUTOTARGET';
    _heli setDir (_heli getDir _lz);
    _heli land 'NONE'; _heli engineOn TRUE;
    private _rappel = random 1 < 0.10 && {!isNil 'AR_Rappel_All_Cargo'} &&
        {(missionNamespace getVariable ['AR_QS_CLEANUP_VERSION',0]) >= 1} &&
        {((surfaceNormal _lz) # 2) > 0.96} &&
        {(nearestTerrainObjects [_lz,['TREE','SMALL TREE','ROCK','ROCKS','BUILDING','HOUSE','POWER LINES'],22,FALSE,TRUE]) isEqualTo []} &&
        {(nearestObjects [_lz,['LandVehicle'],20,TRUE]) isEqualTo []};
    private _height = [180 + random 40,25] select _rappel;
    private _fn_paraAim = {
        private _aim = +_lz;
        if (!isNil 'QS_fnc_aoPressure') then {
            private _drop = _lz vectorAdd [0,0,_height];
            _aim = ['DROP_SPAWN',_drop,_height,_cargo] call QS_fnc_aoPressure;
            _aim set [2,0];
            // Do not turn calibration into a water/edge/player insertion.
            if (surfaceIsWater _aim || {(_aim # 0) < 50} || {(_aim # 1) < 50} ||
                {(_aim # 0) > worldSize - 50} || {(_aim # 1) > worldSize - 50} ||
                {(allPlayers inAreaArray [_aim,50,50,0,FALSE]) isNotEqualTo []}) then {_aim = +_lz;};
        };
        _aim
    };
    private _aim = if (_rappel) then {+_lz} else {call _fn_paraAim};
    _heli flyInHeight [_height,TRUE];
    _pilots move _aim; _pilot doMove _aim;
    private _arrivalBy = diag_tickTime + 180;
    waitUntil {uiSleep 0.5; !(call _fn_flying) || {(_heli distance2D _aim) <= 60} || {diag_tickTime >= _arrivalBy}};
    private _fn_inPosition = {
        (_heli distance2D _aim) <= 20 && {
            if (_rappel) then {abs (((getPosASL _heli) # 2) - ((AGLToASL _aim) # 2) - 25) <= 8}
            else {((getPosATL _heli) # 2) >= 120 && {((getPosATL _heli) # 2) <= 350}}
        } && {(allPlayers inAreaArray [_aim,50,50,0,FALSE]) isEqualTo []}
    };
    _heli limitSpeed 18;
    private _positionBy = diag_tickTime + 20;
    waitUntil {uiSleep 0.25; !(call _fn_flying) || {call _fn_inPosition} || {diag_tickTime >= _positionBy}};
    private _air = [];
    private _dropBy = diag_tickTime + 45;
    if (call _fn_flying && {call _fn_inPosition} && {diag_tickTime < _arrivalBy}) then {
        _heli limitSpeed 9;
		if (_rappel) then {
			private _handle = [_heli,25,AGLToASL _aim,45] call AR_Rappel_All_Cargo;
			if (isNil '_handle') then {_handle = scriptNull;};
			waitUntil {uiSleep 0.25; !(call _fn_flying) || {scriptDone _handle} || {diag_tickTime >= _dropBy}};
			// Stop admitting new ropes, then hold this still-operable transport for
			// the units already descending. At 25 m their normal descent fits well
			// inside this separate bound; a stalled worker still cannot pin the Taru.
			_heli setVariable ['AR_Units_Rappelling',FALSE];
			private _finishBy = diag_tickTime + 5;
			waitUntil {uiSleep 0.1; scriptDone _handle || {diag_tickTime >= _finishBy}};
			private _descents = (_members select {
				alive _x && {!(_x call _fn_exempt)} &&
				{_x getVariable ['AR_Is_Rappelling',FALSE]} &&
				{(_x getVariable ['AR_Rappelling_Vehicle',objNull]) isEqualTo _heli}
			}) apply {[_x,_x getVariable ['QS_AR_serial',-1]]};
			private _fn_activeDescent = {
				params ['_unit','_serial'];
				alive _unit && {!(_unit call _fn_exempt)} &&
				{_unit getVariable ['AR_Is_Rappelling',FALSE]} &&
				{(_unit getVariable ['AR_Rappelling_Vehicle',objNull]) isEqualTo _heli} &&
				{(_unit getVariable ['QS_AR_serial',-1]) isEqualTo _serial}
			};
			private _fn_descentClean = {
				params ['_unit','_serial'];
				private _record = _unit getVariable ['QS_AR_helpers',[]];
				_record isEqualTo [] || {(_record # 0) isNotEqualTo _serial}
			};
			if (_descents isNotEqualTo []) then {
				private _holdOwned = FALSE;
				// Do not mutate a transport after a player/Zeus/locality takeover. Keep
				// this ownership recheck and the initial hold orders unscheduled.
				isNil {
					_holdOwned = call _fn_owned;
					if (_holdOwned) then {
						_heli limitSpeed 5;
						_pilots move _aim;
						_pilot doMove _aim;
					};
				};
				if (_holdOwned) then {
					private _descentBy = diag_tickTime + 30;
					waitUntil {
						uiSleep 0.1;
						((_descents findIf {_x call _fn_activeDescent}) < 0) ||
						{!(call _fn_owned)} || {!alive _heli} || {!canMove _heli} ||
						{!alive _pilot} || {diag_tickTime >= _descentBy}
					};
					if ((call _fn_owned) &&
						{!alive _heli || {!canMove _heli} || {!alive _pilot} || {diag_tickTime >= _descentBy}}) then {
						{
							_x params ['_unit','_serial'];
							if (_x call _fn_activeDescent) then {
								_unit setVariable ['AR_Is_Rappelling',FALSE,TRUE];
							};
						} forEach _descents;
						private _cancelBy = diag_tickTime + 2;
						waitUntil {uiSleep 0.05; (_descents findIf {!(_x call _fn_descentClean)}) < 0 ||
							{!(call _fn_owned)} || {diag_tickTime >= _cancelBy}};
					};
				};
			};
		};
        // TARU_CLEARANCE_FALLBACK_BEGIN
        // A late blocked footprint can use the existing parachute route only
        // before any rope release. Climb normally; never eject cargo at 25 m.
        if (_rappel && {(_heli getVariable ['QS_AR_releaseState','']) isEqualTo 'BLOCKED'} &&
            {scriptDone (_heli getVariable ['QS_AR_bulkHandle',scriptNull])} &&
            {((_members findIf {_x getVariable ['AR_Is_Rappelling',FALSE]}) < 0)} &&
            {call _fn_flying} && {diag_tickTime < _arrivalBy}) then {
            _rappel = FALSE;
            _height = 180 + random 40;
            _aim = call _fn_paraAim;
            _heli limitSpeed 18;
            _heli flyInHeight [_height,TRUE];
            _pilots move _aim; _pilot doMove _aim;
            _positionBy = _arrivalBy min (diag_tickTime + 45);
            waitUntil {uiSleep 0.25; !(call _fn_flying) || {call _fn_inPosition} || {diag_tickTime >= _positionBy}};
            _heli limitSpeed 9;
            _dropBy = diag_tickTime + 45;
        };
        // TARU_CLEARANCE_FALLBACK_END
        if (!_rappel && {call _fn_flying} && {call _fn_inPosition} && {diag_tickTime < _arrivalBy}) then {
            {
                private _unit = _x;
                private _releaseBy = _dropBy min (diag_tickTime + 3);
                waitUntil {uiSleep 0.05; !(call _fn_flying) || {call _fn_inPosition} || {diag_tickTime >= _releaseBy}};
                if (!(call _fn_flying) || {!(call _fn_inPosition)} || {diag_tickTime >= _dropBy}) exitWith {};
                if (alive _unit && {(objectParent _unit) isEqualTo _heli}) then {
                    [_unit] allowGetIn FALSE;
                    unassignVehicle _unit; moveOut _unit;
                    private _exitBy = diag_tickTime + 1;
                    waitUntil {uiSleep 0.01; isNull (objectParent _unit) || {!alive _unit} || {!(call _fn_current)} || {diag_tickTime >= _exitBy}};
                    if (alive _unit && {isNull (objectParent _unit)} && {call _fn_current}) then {
                        private _drop = _heli modelToWorld [selectRandom [-3,3],-5,-7];
                        private _chute = createVehicle ['Steerable_Parachute_F',_drop,[],0,'FLY'];
                        if (!isNull _chute) then {
                            _chute setPosATL _drop;
                            _unit setPosATL _drop;
                            _unit moveInDriver _chute;
                            _chute setVelocity [0,0,-5];
                            _air pushBack [_unit,_chute,diag_tickTime + 150];
                            if (!isNil 'QS_fnc_aoPressure') then {['DROP_TRACK',_unit,_lz vectorAdd [0,0,_drop # 2],_drop] call QS_fnc_aoPressure;};
                        };
                    };
                    uiSleep 0.35;
                };
            } forEach _members;
        };
    };
    // Failed releases stay aboard. Depart before deferred collection, even on
    // activity cancellation; never replenish aircraft losses with new soldiers.
    if (call _fn_owned) then {
        (_members select {(objectParent _x) isEqualTo _heli}) joinSilent _pilots;
        _heli setVariable ['AR_Units_Rappelling',FALSE];
        if (alive _heli && {canMove _heli} && {alive _pilot}) then {
            _heli land 'NONE'; _heli limitSpeed 1000; _heli flyInHeight [120,TRUE];
            _pilot enableAI 'PATH'; _pilots move _entry; _pilot doMove _entry;
        };
    };
    // One bounded landing monitor per flight; no scheduled worker per soldier.
    private _landBy = diag_tickTime + 150;
    waitUntil {
        uiSleep 0.5;
        private _remaining = [];
        {
            _x params ['_unit','_chute','_deadline'];
            if (!isNull _unit && {!(_unit call _fn_exempt)}) then {
                private _height = (getPosATL _unit) # 2;
                if (alive _unit && {(objectParent _unit) isEqualTo _chute} &&
                    {isTouchingGround _chute || {_height < 1.8}}) then {unassignVehicle _unit; moveOut _unit;};
                if (alive _unit && {_height >= 3 || {!isNull (objectParent _unit)}}) then {
                    if (diag_tickTime < _deadline && {(_unit distance2D _lz) <= 650}) then {_remaining pushBack _x;} else {
                        if ((objectParent _unit) isEqualTo _chute) then {_chute deleteVehicleCrew _unit;} else {if (isNull (objectParent _unit)) then {deleteVehicle _unit;};};
                    };
                };
            };
            if (!isNull _chute && {((crew _chute) findIf {alive _x || {isPlayer _x}}) < 0}) then {deleteVehicleCrew _chute; deleteVehicle _chute;};
        } forEach _air;
        _air = _remaining;
        (_air isEqualTo [] && {((units _cargo) findIf {alive _x && {(_x getVariable ['AR_Is_Rappelling',FALSE]) || {((getPosATL _x) # 2) > 3}}}) < 0}) ||
        {diag_tickTime >= _landBy} || {!(call _fn_owned)}
    };
    // Drop the task-ownership marker even after a Zeus/locality takeover.
    // This changes no orders and cannot leave the group permanently suspended.
    if (!isNull _cargo) then {_cargo setVariable ['QS_taruDelivery_busy',FALSE,TRUE];};
    if (call _fn_owned) then {
        // Primary's controller assigns its objective role after this signal.
        if (_activity isEqualTo 'DEFENSE' && {call _fn_current}) then {
            _cargo setVariable ['QS_AI_GRP_HC_EXCLUDED',FALSE,TRUE];
            _cargo setSpeedMode 'FULL'; _cargo setBehaviour 'AWARE';
            {
                _x enableAIFeature ['TARGET',TRUE]; _x enableAIFeature ['AUTOTARGET',TRUE];
                _x setUnitPos 'UP'; _x doFollow (leader _cargo);
            } forEach (units _cargo);
            _cargo move _goal;
        };
        _heli setVariable ['QS_taruDelivery_landed',TRUE];
    };
    _releaseComplete = TRUE;
    private _outBy = diag_tickTime + 180;
    waitUntil {uiSleep 2; !(call _fn_owned) || {!alive _heli} || {!canMove _heli} || {!alive _pilot} ||
        {(_heli distance2D _lz) > 1400 && {(allPlayers inAreaArray [_heli,500,500,0,FALSE]) isEqualTo []}} || {diag_tickTime >= _outBy}};
    if (call _fn_owned) then {
        {if (!isNull _x && {!(_x call _fn_exempt)}) then {QS_garbageCollector pushBackUnique [_x,'DELAYED_DISCREET',time + 180];};} forEach ((units _pilots) + [_heli]);
    };
};
// TARU_INTEGRATION_END

params [
	['_position',[0,0,0]],
	['_side',EAST],
	['_heliType','O_Heli_Transport_04_covered_black_F'],
	['_nUnits',0.5],
	['_unitTypes',['O_V_Soldier_ghex_F']],
	['_useSupport',FALSE],
	['_supportType','O_Heli_Attack_02_dynamicLoadout_black_F'],
	['_useUnits',[]],
	['_manageGroup',FALSE]
];
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
private _foundHLZ = FALSE;
private _HLZ = [0,0,0];
_helipadType = 'Land_HelipadEmpty_F';
for '_x' from 0 to 99 step 1 do {
	_HLZ = [_position,0,300,17,0,0.5,0] call (missionNamespace getVariable 'QS_fnc_findSafePos');
	if (
		((nearestObjects [_HLZ,[_helipadType],75,TRUE]) isEqualTo []) &&
		{((nearestTerrainObjects [_HLZ,['TREE','SMALL TREE'],15,FALSE,TRUE]) isEqualTo [])} &&
		{((allPlayers findIf {((_x distance2D _HLZ) < 50)}) isEqualTo -1)} &&
		{((_HLZ distance2D _position) < 300)}
	) exitWith {_foundHLZ = TRUE;};
};
if (!(_foundHLZ)) exitWith {};
_HLZ set [2,0];
private _array = [];
_heli = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _heliType,_heliType],_mapEdgePosition,[],500,'FLY'];
_heli setVariable ['QS_dynSim_ignore',TRUE,TRUE];
_heli enableDynamicSimulation FALSE;
_heliGroup = createGroup [EAST,TRUE];
_heliPilot = _heliGroup createUnit [(QS_core_units_map getOrDefault ['o_helipilot_f','o_helipilot_f']),(getPosWorld _heli),[],0,'NONE'];
_heliGroup addVehicle _heli;
_heliPilot assignAsDriver _heli;
_heliPilot moveInDriver _heli;
//_heliGroup = createVehicleCrew _heli;
_array pushBack _heli;
{
	removeAllWeapons _x;
	_x setVariable ['QS_dynSim_ignore',TRUE,TRUE];
	_x enableDynamicSimulation FALSE;
} forEach (units _heliGroup);
_heli setVariable ['QS_heli_spawnPosition',_mapEdgePosition,FALSE];
_heli setVariable ['QS_heli_centerPosition',_position,FALSE];
clearWeaponCargoGlobal _heli;
clearMagazineCargoGlobal _heli;
clearItemCargoGlobal _heli;
clearBackpackCargoGlobal _heli;
[_heli,TRUE] remoteExec ['lockInventory',0,FALSE];
[_heli,1,[]] call (missionNamespace getVariable 'QS_fnc_vehicleLoadouts');
_heli engineOn TRUE;
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
			[driver _vehicle,_shooter,_projectile] spawn {
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
		};
	}
];
[_heli,2] remoteExecCall ['QS_fnc_serverSetEntityFeatureType',2,FALSE];
_heliGroup enableAttack FALSE;
{
	_x allowDamage FALSE;
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
_helipad = createVehicleLocal [_helipadType,_HLZ];
_array pushBack _helipad;
_heli setVariable ['QS_assignedHelipad',_helipad,FALSE];
_heliGroup setSpeedMode 'NORMAL';
_wp = _heliGroup addWaypoint [_HLZ,0];
_wp setWaypointType 'MOVE';		/*/ 'TR UNLOAD' /*/
_wp setWaypointSpeed 'NORMAL';
_wp setWaypointBehaviour 'CARELESS';
_wp setWaypointCombatMode 'BLUE';
_heliGroup addEventHandler [
	'WaypointComplete',
	{
		params ['_group','_waypointIndex'];
		_group removeEventHandler [_thisEvent,_thisEventHandler];
		[leader _group] spawn (missionNamespace getVariable 'QS_fnc_AIXHeliInsertLanding');
	}
];
private _supportGroup = grpNull;
if (_useSupport) then {
	if ((count allPlayers) > 10) then {
		_supportSpawnPosition = _heli getRelPos [100,90];
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
		//[_supportHeli,1,[]] call (missionNamespace getVariable 'QS_fnc_vehicleLoadouts');
		_wp = _supportGroup addWaypoint [_HLZ,0];
		_wp setWaypointType 'LOITER';
		_wp setWaypointLoiterType 'CIRCLE_L';
		_wp setWaypointLoiterRadius (random [150,200,300]);
		//comment "_wp setWaypointType 'SAD';";
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
					[driver _vehicle,_shooter,_projectile] spawn {
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
				};
			}
		];
		_heli setVariable ['QS_heliInsert_supportHeli',_supportHeli,FALSE];
		_heli setVariable ['QS_heliInsert_supportGroup',_supportGroup,FALSE];
		_timeDelete = time + 900;
		{
			if (_x isEqualType objNull) then {
				0 = (missionNamespace getVariable 'QS_garbageCollector') pushBack [_x,'DELAYED_DISCREET',_timeDelete];
			};
		} forEach _array;
	};
};
if ((_manageGroup) && (_spawnUnits)) then {
	//comment 'Monitor';
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
