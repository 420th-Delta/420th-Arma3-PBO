/*/
File: fn_AIFireMission.sqf
Author:

	Quiksilver
	
Last modified:

	28/06/2022 A3 2.10 by Quiksilver
	
Description:

	AI Fire Mission
__________________________________________________/*/

params ['_type'];
if (_type isEqualTo 0) exitWith {
	scriptName 'QS AI FIRE MISSION - ARTY';
	//comment 'Artillery';
/* Legacy Code as of 9.9.2026 */
//|	params ['','_grpLeader','_firePosition','_fireShells','_fireRounds'];
// Updated Code
	params ['','_grpLeader','_firePosition','_fireShells','_fireRounds',['_primaryTuning',[]]];
	// PRIMARY MORTARS ONLY: the controller passes this token after fresh-target
	// checks and spending an AO allowance slot. Native calls omit it entirely.
	// Defense and aircraft calls retain their original settings and code paths.
	private _primaryMortar = (count _primaryTuning) >= 2 &&
		{(_primaryTuning # 0) isEqualTo (missionNamespace getVariable ['QS_primaryPressure_epoch',-1])} &&
		{missionNamespace getVariable ['QS_primaryPressure_running',FALSE]} &&
		{!(missionNamespace getVariable ['QS_defendActive',FALSE])} &&
		{(vehicle _grpLeader) isKindOf 'StaticMortar'};
// End Updated Code
	_vehicle = vehicle _grpLeader;
	_vehicle setVehicleAmmo 1;
	_grp = group _grpLeader;
	_grp setFormDir ((getPos _grpLeader) getDir _firePosition);
	_sleep_1 = [5,2] select (_vehicle isKindOf 'StaticMortar');
	_sleep_2 = [7,4] select (_vehicle isKindOf 'StaticMortar');
	_nearbyTargetsCount = count ([12,EAST,_firePosition,100] call (missionNamespace getVariable 'QS_fnc_AIGetKnownEnemies'));
	if ((_vehicle isKindOf 'StaticMortar') && (_nearbyTargetsCount > (selectRandom [5,6]))) then {
		_fireRounds = round (_fireRounds * 2);
	};
	private _radius = 90;
// Added Code
	if (_primaryMortar) then {
		// Apply AFTER the native doubling rule: four shells below 20 ground
		// players, six at 20+, with an absolute six-shell cap for this salvo.
		_fireRounds = 1 max (6 min (_primaryTuning # 1));
		_radius = 45;
	};
// End Updated Code
	private _firstShell = TRUE;
	_grpLeader doWatch [(_firePosition # 0),(_firePosition # 1),(1000 + (random 1000))];
	uiSleep (3 + (random 5));
	if (_vehicle isKindOf 'StaticMortar') then {
		for '_x' from 0 to (_fireRounds - 1) step 1 do {
			if ((!alive _vehicle) || {(!alive _grpLeader)} || {(isNull (objectParent _grpLeader))}) exitWith {};
			_grpLeader doArtilleryFire [(_firePosition getPos [(_radius * (sqrt (random 1))),(random 360)]),_fireShells,1];
			_radius = _radius * (random [0.7,0.75,1]);
// Added Code
			if (_primaryMortar) then {_radius = 25 max _radius;};
// End Updated Code
			if (_firstShell) then {
				_firstShell = FALSE;
				uiSleep (_sleep_1 + (random _sleep_1));
			};
			uiSleep (_sleep_2 + (random _sleep_1));
		};
	} else {
		_grpLeader doArtilleryFire [(_firePosition getPos [(15 * (sqrt (random 1))),(random 360)]),_fireShells,_fireRounds];
		_grp setVariable ['QS_AI_GRP_DATA',[FALSE,(serverTime + 45)],FALSE];
	};
};
// Added Code
// GROUND_SUPPORT_FLIGHT_GUARDS_BEGIN
private _fn_groundFlightEligible = {
    params ['_target'];
    !isNil 'QS_fnc_groundTargetPriority' && {(_target call QS_fnc_groundTargetPriority) >= 0}
};
private _fn_groundRequestRelease = {
    params ['_group','_target','_request','_onlyIdle'];
    if ((_request param [0,objNull]) isEqualTo _target &&
        {(_group getVariable ['QS_AI_GRP_fireMission',[]]) isEqualTo _request} &&
        {!_onlyIdle || {serverTime >= (_group getVariable ['QS_combatAir_groundUntil',0])}}) then {
        _group setVariable ['QS_AI_GRP_fireMission',nil,QS_system_AI_owners];
    };
};
// GROUND_SUPPORT_FLIGHT_GUARDS_END
// End Updated Code
if (_type isEqualTo 1) exitWith {
	scriptName 'QS AI FIRE MISSION - HELI';
	//comment 'Heli CAS';
	params ['','_supportProvider','_supportGroup','_targetObject','_targetPosition','_smokePosition','_duration'];
// Added Code
	private _groundRequest = +(_supportGroup getVariable ['QS_AI_GRP_fireMission',[]]);
	if (!([_targetObject] call _fn_groundFlightEligible)) exitWith {
		[_supportGroup,_targetObject,_groundRequest,TRUE] call _fn_groundRequestRelease;
	};
	// A delayed support request cannot take over an occupied combat flight.
	if (!isNil 'QS_fnc_combatAir' && {!(['START',_supportGroup,_targetObject,_duration] call QS_fnc_combatAir)}) exitWith {};
// End Updated Code
	_vehicle = vehicle _supportProvider;
	_targetAssistant = createSimpleObject ['A3\Structures_F_Heli\VR\Helpers\Sign_sphere10cm_F.p3d',_targetPosition,TRUE];
	[1,_targetAssistant,[_targetObject,[0,0,1]]] call QS_fnc_eventAttach;
	_targetAssistant hideObject TRUE;
	[0,_targetAssistant] call QS_fnc_eventAttach;
	_laserTarget = createVehicle ['LaserTargetE',_targetPosition,[],0,'NONE'];
	[1,_laserTarget,[_targetAssistant,[0,0,0.5]]] call QS_fnc_eventAttach;
	_laserTarget allowDamage FALSE;
	(missionNamespace getVariable 'QS_AI_laserTargets') pushBack _laserTarget;
	_laserTarget confirmSensorTarget [EAST,TRUE];
	if (((_laserTarget getEventHandlerInfo ['IncomingMissile',0]) # 2) isEqualTo 0) then {
		_laserTarget addEventHandler [
			'IncomingMissile',
			{
				params ['_target','_ammo','_vehicle','_instigator','_missile'];
				if (_ammo isKindOf 'BombCore') then {
					[103,_target,_ammo,_vehicle,_missile] remoteExec ['QS_fnc_remoteExec',-2,FALSE];
				};
			}
		];
	};
	private _unit = objNull;
	{
		_unit = _x;
		{
			_unit forgetTarget _x;
		} forEach (_unit targets [TRUE]);
	} forEach (units _supportGroup);
	private _targetPos = _targetPosition;
	_targetPosition set [2,1];
	_supportGroup reveal [_targetObject,4];
	_supportProvider moveTo _targetPosition;
	_supportProvider doMove _targetPosition;
	private _time = time;
	private _rearmDelay = _time + 15;
	private _watchDelay = _time + 5;
	private _moveDelay = _time + 10;
	private _updateTargetDelay = _time + 120;
	private _fireDelay = _time + 5;
	private _firingDuration = 15;
	private _relDir = _vehicle getRelDir _targetPosition;
	private _relPos = _vehicle getRelPos [0,0];
	private _distance2D = _vehicle distance2D _targetPosition;
// Added Code
	// GROUND_SUPPORT_OBSERVED_PICK_BEGIN
	private _fn_groundObservedPick = {
	    params ['_observer','_candidates','_origin','_radius','_now'];
	    private _best = objNull; private _bestTier = 5; private _nearest = 1e10;
	    private _seen = []; private _ranked = [];
	    if (isNil 'QS_fnc_groundTargetPriority') exitWith {_best};
	    // Classify unique assets before limiting the more expensive report reads.
	    {
	        private _asset = vehicle _x;
	        if (!(_asset in _seen)) then {
	            _seen pushBack _asset;
	            private _tier = _asset call QS_fnc_groundTargetPriority;
	            if (_tier >= 0 && {isTouchingGround _asset}) then {_ranked pushBack [_tier,_forEachIndex,_asset];};
	        };
	    } forEach _candidates;
	    _ranked sort TRUE;
	    {
	        _x params ['_tier','','_asset'];
	        private _knowledge = _observer targetKnowledge _asset;
	        private _age = _now - (_knowledge # 2);
	        private _point = _knowledge # 6;
	        if ((_knowledge # 0) && {(_knowledge # 2) >= 0} && {_age >= 0} && {_age < 30} && {_point isNotEqualTo [0,0,0]}) then {
	            private _distance = _point distance2D _origin;
	            if (_distance <= _radius && {_tier < _bestTier || {_tier isEqualTo _bestTier && {_distance < _nearest}}}) then {
	                _best = _asset; _bestTier = _tier; _nearest = _distance;
	            };
	        };
	    } forEach (_ranked select [0,64]);
	    _best
	};
	// GROUND_SUPPORT_OBSERVED_PICK_END
// End Updated Code
	private _nearTargets = _supportProvider targets [TRUE,50,[],0,_targetPos];
	private _exit = FALSE;
	private _velocity = velocity _vehicle;
	private _vectorDir = (getPosATL _vehicle) vectorFromTo (getPosATL _laserTarget);
	private _vectorUp = vectorUp _vehicle;
	private _offset = 0;
	private _fireDuration = _time + 3;
	private _selectedTarget = _laserTarget;
	for '_x' from 0 to 1 step 0 do {
		_time = time;
		if (
			(!canMove _vehicle) ||
			{(!alive _vehicle)} ||
			{(isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'})} ||
// Added Code
			{!([_targetObject] call _fn_groundFlightEligible)} ||
// End Updated Code
			{(_exit)}
		) exitWith {};
		if (_time > _moveDelay) then {
			if (((vectorMagnitude (velocity _vehicle)) * 3.6) < 10) then {
				{
					_supportGroup forgetTarget _x;
					_supportProvider forgetTarget _x;
				} forEach (_supportProvider targets []);
				_relPos = _vehicle getRelPos [(500 + (random 500)),0];
				_relPos set [2,100];
				_supportGroup move _relPos;
			};
			_moveDelay = time + 5;
		};
		if ((_time > _watchDelay) || {(isNull _selectedTarget)}) then {
/* Legacy Code as of 9.9.2026 */
//|			_nearTargets = _supportProvider targets [TRUE,75,[],0,_targetPosition];
//|			if (_nearTargets isEqualTo []) then {
//|				_selectedTarget = _laserTarget;
//|			} else {
//|				_selectedTarget = selectRandom _nearTargets;
//|			};
// Updated Code
			_nearTargets = _supportProvider targets [TRUE,75,[WEST],30,_targetPosition];
			_selectedTarget = [_supportProvider,_nearTargets,_targetPosition,75,time] call _fn_groundObservedPick;
			if (isNull _selectedTarget) then {_selectedTarget = _laserTarget;};
// End Updated Code
			if ((behaviour _supportProvider) isNotEqualTo 'COMBAT') then {
				_supportGroup setBehaviour 'COMBAT';
			};
			if (alive _selectedTarget) then {
				{
					_x reveal [_selectedTarget,3.9];
					_x doWatch (position _selectedTarget);
					_x doTarget _selectedTarget;
				} forEach (units _supportGroup);
				_supportGroup reveal [_selectedTarget,3.9];
				_supportProvider commandTarget _selectedTarget;
			};
			_watchDelay = time + 15;
		};
		if (_time > _fireDelay) then {
			if (((_vehicle aimedAtTarget [_selectedTarget]) > 0.5) && (!(terrainIntersect [(getPosATL _vehicle),(getPosATL _selectedTarget)]))) then {
				//comment 'Fire';
				_supportProvider doSuppressiveFire (aimPos _selectedTarget);
				_fireDuration = time + 5;
				_vehicle setVehicleAmmo 1;
				for '_x' from 0 to 1 step 0 do {
					if (
						(!alive _supportProvider) ||
						{(!alive _vehicle)} ||
						{(!canFire _vehicle)} ||
						{((_vehicle aimedAtTarget [_selectedTarget]) < 0.5)} ||
						{(time > _fireDuration)}
					) exitWith {};
					_vehicle fireAtTarget [_selectedTarget,(currentWeapon _vehicle)];
					sleep (0.5 - ((_vehicle aimedAtTarget [_selectedTarget]) / 2.25));
				};
			};
			_fireDelay = time + 5;
		};
		sleep 1;
	};
	if (!isNull _laserTarget) then {
		deleteVehicle _laserTarget;
		missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),FALSE];
	};
	if (!isNull _targetAssistant) then {
		deleteVehicle _targetAssistant;
		missionNamespace setVariable [
			'QS_analytics_entities_deleted',
			((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),
			FALSE
		];
	};
	if (!isNull _supportGroup) then {
/* Legacy Code as of 9.9.2026 */
//|		_supportGroup setVariable ['QS_AI_GRP_fireMission',nil,QS_system_AI_owners];
// Updated Code
		[_supportGroup,_targetObject,_groundRequest,FALSE] call _fn_groundRequestRelease;
// End Updated Code
	};
	if ((alive _vehicle) && (canMove _vehicle)) then {
/* Legacy Code as of 9.9.2026 */
//|		_relPos = _vehicle getRelPos [(500 + (random 500)),(random 360)];
//|		_relPos set [2,100];
//|		_supportGroup move _relPos;
// Updated Code
		// Managed CAS leaves the attack area before another ground request.
		// Unmanaged providers retain their native departure movement.
		if (isNil 'QS_fnc_combatAir' || {!(['EGRESS',_supportGroup,_targetPosition] call QS_fnc_combatAir)}) then {
			_relPos = _vehicle getRelPos [(500 + (random 500)),(random 360)];
			_relPos set [2,100];
			_supportGroup move _relPos;
		};
// End Updated Code
	};
};
if (_type isEqualTo 2) exitWith {
	scriptName 'QS AI FIRE MISSION - PLANE';
	//comment 'Plane CAS';
	params ['','_supportProvider','_supportGroup','_targetObject','_targetPosition','_duration'];
// Added Code
	private _groundRequest = +(_supportGroup getVariable ['QS_AI_GRP_fireMission',[]]);
	if (!([_targetObject] call _fn_groundFlightEligible)) exitWith {
		[_supportGroup,_targetObject,_groundRequest,TRUE] call _fn_groundRequestRelease;
	};
	// A delayed support request cannot take over an occupied combat flight.
	if (!isNil 'QS_fnc_combatAir' && {!(['START',_supportGroup,_targetObject,_duration] call QS_fnc_combatAir)}) exitWith {};
// End Updated Code
	_vehicle = vehicle _supportProvider;
	_vehicle flyInHeight (200 + (random 100));
	_vehicle forceSpeed -1;
	_vehicle setVariable ['QS_AI_PLANE_fireMission',TRUE,FALSE];
	_targetAssistant = createSimpleObject ['A3\Structures_F_Heli\VR\Helpers\Sign_sphere10cm_F.p3d',_targetPosition,TRUE];
	[1,_targetAssistant,[_targetObject,[0,0,1]]] call QS_fnc_eventAttach;
	_targetAssistant hideObject TRUE;
	[0,_targetAssistant] call QS_fnc_eventAttach;
	_laserTarget = createVehicle ['LaserTargetE',_targetPosition,[],0,'NONE'];
	[1,_laserTarget,[_targetAssistant,[0,0,0.5]]] call QS_fnc_eventAttach;
	_laserTarget allowDamage FALSE;
	(missionNamespace getVariable 'QS_AI_laserTargets') pushBack _laserTarget;
	_laserTarget confirmSensorTarget [EAST,TRUE];
	if (((_laserTarget getEventHandlerInfo ['IncomingMissile',0]) # 2) isEqualTo 0) then {
		_laserTarget addEventHandler [
			'IncomingMissile',
			{
				params ['_target','_ammo','_vehicle','_instigator','_missile'];
				if (_ammo isKindOf 'BombCore') then {
					[103,_target,_ammo,_vehicle,_missile] remoteExec ['QS_fnc_remoteExec',-2,FALSE];
				};
			}
		];
	};
	_supportGroup reveal [_laserTarget,3.9];
	_supportProvider doWatch _laserTarget;
	_supportProvider commandTarget _laserTarget;
	if (!isNil {missionNamespace getVariable 'QS_fnc_transformDiagAirFireMission'}) then {
		['START',_vehicle,_targetObject,_targetPosition,_laserTarget] call (missionNamespace getVariable 'QS_fnc_transformDiagAirFireMission');
	};
	private _unit = objNull;
	{
		_unit = _x;
		{
			_unit forgetTarget _x;
			_supportGroup forgetTarget _x;
		} forEach (_unit targets [TRUE]);
	} forEach (units _supportGroup);
	private _time = time;
	private _targetDelay = _time + 30;
	private _relPos = _vehicle getRelPos [0,0];
	private _exit = FALSE;
	private _fireDuration = _time + 5;
	private _fireDelay = _time + 5;
	private _firedEvent = nil;
	for '_x' from 0 to 1 step 0 do {
		_time = time;
		if (
			((vehicle _supportProvider) isNotEqualTo _vehicle) ||
			{(!canMove _vehicle)} ||
			{(!alive _vehicle)} ||
			{(isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'})} ||
// Added Code
			{!([_targetObject] call _fn_groundFlightEligible)} ||
// End Updated Code
			{(_exit)} ||
			{(serverTime > _duration)} ||
			{(isNull _laserTarget)}
		) exitWith {};
		if (_time > _targetDelay) then {
			_vehicle setVehicleAmmo 1;
			if ((behaviour _supportProvider) isNotEqualTo 'COMBAT') then {
				_supportGroup setBehaviour 'COMBAT';
			};
			{
				_unit = _x;
				{
					if (_x isNotEqualTo _laserTarget) then {
						_unit forgetTarget _x;
						_supportGroup forgetTarget _x;
					};
				} forEach (_unit targets [TRUE]);
			} forEach (units _supportGroup);
			_supportGroup reveal [_laserTarget,3.9];
			_supportProvider doWatch _laserTarget;
			_supportProvider commandTarget _laserTarget;
			_targetDelay = _time + 30;
		};
		if (_time > _fireDelay) then {
			if (((_vehicle aimedAtTarget [_laserTarget]) > 0.5) && (!(terrainIntersect [(getPosATL _vehicle),(getPosATL _laserTarget)]))) then {
				//comment 'Fire';
				_firedEvent = _vehicle addEventHandler [
					'Fired',
					{
						params ['','','','','_ammo','','_projectile',''];
						private _simulation = QS_hashmap_configfile getOrDefaultCall [
							format ['cfgammo_%1_simulation',toLowerANSI _ammo],
							{toLowerANSI (getText (configFile >> 'CfgAmmo' >> _ammo >> 'simulation'))},
							TRUE
						];
						if ((toLowerANSI _simulation) isEqualTo 'shotmissile') then {
							[_projectile,TRUE,TRUE] call (missionNamespace getVariable 'QS_fnc_clientTrackProjectile');
						};
					}
				];
				uiSleep 0.01;
				_supportProvider doSuppressiveFire (aimPos _laserTarget);
				_fireDuration = time + 5;
				for '_x' from 0 to 1 step 0 do {
					if (
						(!alive _supportProvider) ||
						{(!alive _vehicle)} ||
						{(!canFire _vehicle)} ||
						{((_vehicle aimedAtTarget [_laserTarget]) < 0.5)} ||
						{(time > _fireDuration)}
					) exitWith {};
					if (!isNil {missionNamespace getVariable 'QS_fnc_transformDiagAirFireMission'}) then {
						['COMMAND',_vehicle,_targetObject,_targetPosition,_laserTarget] call (missionNamespace getVariable 'QS_fnc_transformDiagAirFireMission');
					};
					_vehicle fireAtTarget [_laserTarget,(currentWeapon _vehicle)];
					sleep (0.5 - ((_vehicle aimedAtTarget [_laserTarget]) / 2.25));
				};
				if (!isNull _laserTarget) then {
					deleteVehicle _laserTarget;
					missionNamespace setVariable [
						'QS_analytics_entities_deleted',
						((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),
						FALSE
					];
				};
				_vehicle removeEventHandler ['Fired',_firedEvent];
			};
			_fireDelay = time + 5;
		};
		uiSleep 1;
	};
	if (!isNil {missionNamespace getVariable 'QS_fnc_transformDiagAirFireMission'}) then {
		['END',_vehicle,_targetObject,_targetPosition,_laserTarget] call (missionNamespace getVariable 'QS_fnc_transformDiagAirFireMission');
	};
	_vehicle setVariable ['QS_AI_PLANE_fireMission',FALSE,FALSE];
	if (!isNull _laserTarget) then {
		deleteVehicle _laserTarget;
		missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),FALSE];
	};
	if (!isNull _targetAssistant) then {
		deleteVehicle _targetAssistant;
		missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),FALSE];
	};
	if (!isNull _supportGroup) then {
/* Legacy Code as of 9.9.2026 */
//|		_supportGroup setVariable ['QS_AI_GRP_fireMission',nil,QS_system_AI_owners];
// Updated Code
		[_supportGroup,_targetObject,_groundRequest,FALSE] call _fn_groundRequestRelease;
// End Updated Code
	};
	_supportProvider commandWatch objNull;
	if ((alive _vehicle) && (canMove _vehicle)) then {
/* Legacy Code as of 9.9.2026 */
//|		_relPos = _vehicle getRelPos [(500 + (random 500)),(random 360)];
//|		_relPos set [2,300];
//|		_supportGroup move _relPos;
// Updated Code
		// Managed CAS leaves the attack area before another ground request.
		// Unmanaged providers retain their native departure movement.
		if (isNil 'QS_fnc_combatAir' || {!(['EGRESS',_supportGroup,_targetPosition] call QS_fnc_combatAir)}) then {
			_relPos = _vehicle getRelPos [(500 + (random 500)),(random 360)];
			_relPos set [2,300];
			_supportGroup move _relPos;
		};
// End Updated Code
	};
};
if (_type isEqualTo 3) exitWith {
	scriptName 'QS AI FIRE MISSION - UAV';
	//comment 'UAV CAS';
	params ['','_supportProvider','_supportGroup','_targetObject','_targetPosition','_duration'];
// Added Code
	private _groundRequest = +(_supportGroup getVariable ['QS_AI_GRP_fireMission',[]]);
	if (!([_targetObject] call _fn_groundFlightEligible)) exitWith {
		[_supportGroup,_targetObject,_groundRequest,TRUE] call _fn_groundRequestRelease;
	};
// End Updated Code
	_vehicle = vehicle _supportProvider;
	_targetAssistant = createSimpleObject ['A3\Structures_F_Heli\VR\Helpers\Sign_sphere10cm_F.p3d',_targetPosition,TRUE];
	[1,_targetAssistant,[_targetObject,[0,0,1]]] call QS_fnc_eventAttach;
	_targetAssistant hideObject TRUE;
	[0,_targetAssistant] call QS_fnc_eventAttach;
	_laserTarget = createVehicle ['LaserTargetE',_targetPosition,[],0,'NONE'];
	[1,_laserTarget,[_targetAssistant,[0,0,0.5]]] call QS_fnc_eventAttach;
	_laserTarget allowDamage FALSE;
	(missionNamespace getVariable 'QS_AI_laserTargets') pushBack _laserTarget;
	_laserTarget confirmSensorTarget [EAST,TRUE];
	if (((_laserTarget getEventHandlerInfo ['IncomingMissile',0]) # 2) isEqualTo 0) then {
		_laserTarget addEventHandler [
			'IncomingMissile',
			{
				params ['_target','_ammo','_vehicle','_instigator','_missile'];
				if (_ammo isKindOf 'BombCore') then {
					[103,_target,_ammo,_vehicle,_missile] remoteExec ['QS_fnc_remoteExec',-2,FALSE];
				};
			}
		];
	};
	_vehicle flyInHeight (100 + (random 100));
	_supportGroup reveal [_laserTarget,4];
	if (!isNull (gunner _vehicle)) then {
		(gunner _vehicle) doWatch _laserTarget;
		(gunner _vehicle) doTarget _laserTarget;
	};
	_supportProvider commandTarget _laserTarget;
	_attackEnabled = attackEnabled _supportGroup;
	_supportGroup enableAttack TRUE;
	_supportGroup move [((getPosATL _laserTarget) # 0),((getPosATL _laserTarget) # 1),300];
	private _unit = objNull;
	{
		_unit = _x;
		{
			_supportGroup forgetTarget _x;
			_unit forgetTarget _x;
		} forEach (_unit targets [TRUE]);
	} forEach (units _supportGroup);
	private _time = time;
	private _targetDelay = _time + 15;
	private _relPos = _vehicle getRelPos [0,0];
	private _exit = FALSE;
	_vehicle setVehicleAmmo 1;
	_supportGroup setCombatMode 'RED';
	_supportGroup setBehaviour 'COMBAT';
	for '_x' from 0 to 1 step 0 do {
		_time = time;
		if (
			(!canMove _vehicle) ||
			{(!alive _vehicle)} ||
			{(isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'})} ||
// Added Code
			{!([_targetObject] call _fn_groundFlightEligible)} ||
// End Updated Code
			{(_exit)} ||
			{(serverTime > _duration)}
		) exitWith {};
		if (_time > _targetDelay) then {
			if ((behaviour _supportProvider) isNotEqualTo 'COMBAT') then {
				_supportGroup setBehaviour 'COMBAT';
			};
			if ((combatMode _supportGroup) isNotEqualTo 'RED') then {
				_supportGroup setCombatMode 'RED';
			};
			_supportGroup reveal [_laserTarget,4];
			{
				_unit = _x;
				{
					if (_x isNotEqualTo _laserTarget) then {
						_supportGroup forgetTarget _x;
						_unit forgetTarget _x;
					};
				} forEach (_unit targets [TRUE]);
				if (_unit isEqualTo (leader _supportGroup)) then {
					_unit commandWatch _laserTarget;
					_unit commandTarget _laserTarget;
				} else {
					_unit doWatch _laserTarget;
					_unit doTarget _laserTarget;					
				};
			} forEach (units _supportGroup);
			_targetDelay = _time + 15;
		};
		uiSleep 1;
	};
	_vehicle setVehicleAmmo 1;
	if (!isNull _laserTarget) then {
		deleteVehicle _laserTarget;
		missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),FALSE];
	};
	if (!isNull _targetAssistant) then {
		deleteVehicle _targetAssistant;
		missionNamespace setVariable ['QS_analytics_entities_deleted',((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),FALSE];
	};
	if (!isNull _supportGroup) then {
		_supportGroup enableAttack _attackEnabled;
/* Legacy Code as of 9.9.2026 */
//|		_supportGroup setVariable ['QS_AI_GRP_fireMission',nil,QS_system_AI_owners];
// Updated Code
		[_supportGroup,_targetObject,_groundRequest,FALSE] call _fn_groundRequestRelease;
// End Updated Code
	};
	_vehicle flyInHeightASL [500,(300 + (random 100)),(500 + (random 500))];
	_supportProvider commandWatch objNull;
	if ((alive _vehicle) && (canMove _vehicle)) then {
		_relPos = _vehicle getRelPos [(2500 + (random 2500)),(random 360)];
		_relPos set [2,300];
		_supportGroup move _relPos;
	};
};
