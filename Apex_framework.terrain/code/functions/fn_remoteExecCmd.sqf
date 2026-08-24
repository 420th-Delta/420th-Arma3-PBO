/*/
File: fn_remoteExecCmd.sqf
Author:

	Quiksilver
	
Last modified:

	17/02/2023 A3 2.12 by Quiksilver

Description:

	Remote Execution Commands
_______________________________________________________/*/

private _isRx = isRemoteExecuted;
private _isRxJ = isRemoteExecutedJIP;
private _rxID = remoteExecutedOwner;
if ((!_isRx) || {_isRxJ}) exitWith {diag_log format ['Remote Exec Cmd Failed with: %1 - %2 to %3 (%4 %5)',_this,_rxID,clientOwner,_isRx,_isRxJ];};
if (!(_this isEqualType [])) exitWith {};

private _clientToServer = isServer && {_rxID > 2};
private _rejectRequest = FALSE;
private _rejectReason = '';
if (_clientToServer) then {
	private _pending = [[_this,0]];
	private _nodes = 0;
	private _stringCharacters = 0;
	private _hashMapType = createHashMap;
	private _codeType = {};
	while {(!_rejectRequest) && {_pending isNotEqualTo []}} do {
		private _entry = _pending deleteAt ((count _pending) - 1);
		private _value = _entry # 0;
		private _depth = _entry # 1;
		if (_value isEqualType []) then {
			if ((_depth > 8) || {(count _value) > 64}) then {
				_rejectRequest = TRUE;
				_rejectReason = 'payload shape';
			} else {
				_nodes = _nodes + (count _value);
				if (_nodes > 256) then {
					_rejectRequest = TRUE;
					_rejectReason = 'payload nodes';
				} else {
					{
						if (_x isEqualType []) then {
							_pending pushBack [_x,_depth + 1];
						} else {
							if ((_x isEqualType _hashMapType) || {_x isEqualType _codeType}) exitWith {
								_rejectRequest = TRUE;
								_rejectReason = 'payload type';
							};
							if (_x isEqualType '') then {
								_stringCharacters = _stringCharacters + (count _x);
								if (((count _x) > 8192) || {_stringCharacters > 16384}) exitWith {
									_rejectRequest = TRUE;
									_rejectReason = 'string length';
								};
							};
						};
					} forEach _value;
				};
			};
		};
	};

	private _typeForRate = _this param [0,''];
	private _rateMap = missionNamespace getVariable ['QS_remoteExecCmd_rateMap',createHashMap];
	if ((count _rateMap) > 128) then {
		_rateMap = createHashMap;
	};
	private _rateKey = str _rxID;
	private _now = diag_tickTime;
	private _rateState = _rateMap getOrDefault [_rateKey,[_now,0,-10,0]];
	if ((_now - (_rateState # 0)) >= 1) then {
		_rateState set [0,_now];
		_rateState set [1,0];
		_rateState set [3,0];
	};
	_rateState set [1,(_rateState # 1) + 1];
	private _isHeavyRequest = (_typeForRate isEqualType '') && {_typeForRate in ['setOwner','setGroupOwner','hideObjectGlobal','setMass','setCenterOfMass','setVelocity','setVelocityModelSpace','setTowParent','setVehicleCargo','ropeDestroy','ropeDetach','addForce','addTorque']};
	if (_isHeavyRequest) then {
		_rateState set [3,(_rateState param [3,0,[0]]) + 1];
	};
	if (((_rateState # 1) > 160) || {_isHeavyRequest && {(_rateState # 3) > 30}}) then {
		_rejectRequest = TRUE;
		_rejectReason = 'rate limit';
	};
	_rateMap set [_rateKey,_rateState];
	missionNamespace setVariable ['QS_remoteExecCmd_rateMap',_rateMap,FALSE];
};

private _type = _this param [0,''];
if (_clientToServer && {!_rejectRequest} && {_type isEqualType []}) then {
	if ((count _this) > 16) then {
		_rejectRequest = TRUE;
		_rejectReason = 'batch length';
	} else {
		if ((_this findIf {
			(!(_x isEqualType [])) ||
			{(count _x) < 2} ||
			{(count _x) > 3} ||
			{!((_x # 0) isEqualType '')}
		}) isNotEqualTo -1) then {
			_rejectRequest = TRUE;
			_rejectReason = 'batch depth';
		};
	};
};

if (_rejectRequest) exitWith {
	if (_clientToServer) then {
		private _rateMap = missionNamespace getVariable ['QS_remoteExecCmd_rateMap',createHashMap];
		private _rateKey = str _rxID;
		private _rateState = _rateMap getOrDefault [_rateKey,[diag_tickTime,0,-10]];
		if ((diag_tickTime - (_rateState # 2)) >= 10) then {
			_rateState set [2,diag_tickTime];
			_rateMap set [_rateKey,_rateState];
			missionNamespace setVariable ['QS_remoteExecCmd_rateMap',_rateMap,FALSE];
			diag_log format ['***** REMOTE EXEC COMMAND REJECTED ***** owner %1 type %2 (%3)',_rxID,_type,_rejectReason];
		};
	};
};

if (_type isEqualType []) exitWith {
	{
		_x call (missionNamespace getVariable 'QS_fnc_remoteExecCmd');
	} forEach _this;
};
if (((count _this) < 2) || {!(_type isEqualType '')}) exitWith {};
params ['_type','_1','_2'];

/* Validate the client-to-server commands that can transfer locality globally. */
if (_clientToServer && {_type in ['setOwner','setGroupOwner','hideObjectGlobal']}) then {
	private _sender = (allPlayers select {((owner _x) isEqualTo _rxID) && {!(_x isKindOf 'HeadlessClient_F')}}) param [0,objNull];
	if (isNull _sender) then {
		_rejectRequest = TRUE;
		_rejectReason = 'sender';
	} else {
		if (_type isEqualTo 'setOwner') then {
			if (
				(!(_1 isEqualType objNull)) ||
				{isNull _1} ||
				{!(_2 isEqualType 0)} ||
				{(_2 isNotEqualTo _rxID)} ||
				{((_sender distance2D _1) > 500)}
			) then {
				_rejectRequest = TRUE;
				_rejectReason = 'setOwner ownership';
			};
		};
		if (_type isEqualTo 'setGroupOwner') then {
			if (
				(!(_1 isEqualType grpNull)) ||
				{isNull _1} ||
				{!(_2 isEqualType 0)} ||
				{(_2 isNotEqualTo _rxID)}
			) then {
				_rejectRequest = TRUE;
				_rejectReason = 'setGroupOwner ownership';
			};
		};
		if (_type isEqualTo 'hideObjectGlobal') then {
			if (
				(!(_1 isEqualType objNull)) ||
				{isNull _1} ||
				{!(_2 isEqualType FALSE)} ||
				{_2 && {((_sender distance2D _1) > 500)}}
			) then {
				_rejectRequest = TRUE;
				_rejectReason = 'hideObjectGlobal ownership';
			};
		};
	};
};
if (_rejectRequest) exitWith {
	private _rateMap = missionNamespace getVariable ['QS_remoteExecCmd_rateMap',createHashMap];
	private _rateKey = str _rxID;
	private _rateState = _rateMap getOrDefault [_rateKey,[diag_tickTime,0,-10,0]];
	if ((diag_tickTime - (_rateState # 2)) >= 10) then {
		_rateState set [2,diag_tickTime];
		_rateMap set [_rateKey,_rateState];
		missionNamespace setVariable ['QS_remoteExecCmd_rateMap',_rateMap,FALSE];
		diag_log format ['***** REMOTE EXEC COMMAND REJECTED ***** owner %1 type %2 (%3)',_rxID,_type,_rejectReason];
	};
};
if (_type isEqualTo 'switchMove') exitWith {
	_1 switchMove _2;
};
if (_type isEqualTo 'sideChat') exitWith {
	_1 sideChat _2;
};
if (_type isEqualTo 'commandChat') exitWith {
	_1 commandChat _2;
};
if (_type isEqualTo 'customChat') exitWith {
	_1 customChat _2;
};
if (_type isEqualTo 'globalChat') exitWith {
	_1 globalChat _2;
};
if (_type isEqualTo 'groupChat') exitWith {
	_1 groupChat _2;
};		
if (_type isEqualTo 'hint') exitWith {
	if (!isStreamFriendlyUIEnabled) then {
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,7.5,-1,_1,[],-1];
	};
};
if (_type isEqualTo 'hintSilent') exitWith {
	if (!isStreamFriendlyUIEnabled) then {
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,7.5,-1,_1,[],-1];
	};
};
if (_type isEqualTo 'setAmmoCargo') exitWith {
	_1 setAmmoCargo _2;
};
if (_type isEqualTo 'setRepairCargo') exitWith {
	_1 setRepairCargo _2;
};
if (_type isEqualTo 'setFuelCargo') exitWith {
	_1 setFuelCargo _2;
};
if (_type isEqualTo 'setDir') exitWith {
	if ((getDir _1) isNotEqualTo _2) then {
		_1 setDir _2;
	};
};
if (_type isEqualTo 'setFuel') exitWith {
	_1 setFuel _2;
};
if (_type isEqualTo 'setGroupOwner') exitWith {
	if (isDedicated) then {
		_1 setGroupOwner _2;
	};
};
if (_type isEqualTo 'setOwner') exitWith {
	if (isDedicated) then {
		_1 setOwner _2;
	};
};
if (_type isEqualTo 'setSpeaker') exitWith {
	_1 setSpeaker _2;
};
if (_type isEqualTo 'setVehicleAmmo') exitWith {
	_1 setVehicleAmmo _2;
};
if (_type isEqualTo 'systemChat') exitWith {
	systemChat _1;
};
if (_type isEqualTo 'vehicleChat') exitWith {
	_1 vehicleChat _2;
};
if (_type isEqualTo 'setFeatureType') exitWith {
	_1 setFeatureType _2;
};
if (_type isEqualTo 'engineOn') exitWith {
	_1 engineOn _2;
};
if (_type isEqualTo 'playSound') exitWith {
	playSound _1;
};
if (_type isEqualTo 'playMusic') exitWith {
	playMusic _1;
};
if (_type isEqualTo 'removeWeapon') exitWith {
	_1 removeWeapon _2;
};
if (_type isEqualTo 'setMass') exitWith {
	_1 setMass _2;
	_1 awake TRUE;
};
if (_type isEqualTo 'setCenterOfMass') exitWith {
	_1 setCenterOfMass _2;
	_1 awake TRUE;
};
if (_type isEqualTo 'disableAI') exitWith {
	_1 enableAIFeature [_2,FALSE];
};
if (_type isEqualto 'enableAI') exitWith {
	_1 enableAIFeature [_2,TRUE];
};
if (_type isEqualto 'enableAIFeature') exitWith {
	if (_1 isEqualType objNull) then {
		_1 enableAIFeature _2;
	};
	if (_1 isEqualType []) then {
		{
			_x enableAIFeature _2;
		} forEach _1;
	};
};
if (_type isEqualTo 'setVelocity') exitWith {
	_1 setVelocity _2;
};
if (_type isEqualTo 'setVelocityModelSpace') exitWith {
	_1 setVelocityModelSpace _2;
};
if (_type isEqualTo 'playMoveNow') exitWith {
	_1 playMoveNow _2;
};
if (_type isEqualTo 'enableVehicleCargo') exitWith {
	_1 enableVehicleCargo _2;
};
if (_type isEqualTo 'addWaypoint') exitWith {
	_1 addWaypoint _2;
};
if (_type isEqualTo 'deleteWaypoint') exitWith {
	deleteWaypoint _1;
};
if (_type isEqualTo 'setWaypointType') exitWith {
	_1 setWaypointType _2;
};
if (_type isEqualTo 'setFormDir') exitWith {
	_1 setFormDir _2;
};
if (_type isEqualTo 'ropeUnwind') exitWith {
	if (_1 isEqualType []) then {
		{
			ropeUnwind _x;
		} forEach _1;
	} else {
		ropeUnwind _1;
	};
};
if (_type isEqualTo 'ropeDestroy') exitWith {
	if (_1 isEqualType []) then {
		{
			ropeDestroy _x;
		} forEach _1;
	} else {
		ropeDestroy _1;
	};
};
if (_type isEqualTo 'ropeDetach') exitWith {
	if (_2 isEqualType []) then {
		{
			_1 ropeDetach _x;
		} forEach _2;
	} else {
		_1 ropeDetach _2;
	};
};
if (_type isEqualTo 'reportRemoteTarget') exitWith {
	_1 reportRemoteTarget _2;
};
if (_type isEqualTo 'confirmSensorTarget') exitWith {
	_1 confirmSensorTarget _2;
};
if (_type isEqualTo 'doSuppressiveFire') exitWith {
	if (_1 isEqualType []) then {
		{
			_x doSuppressiveFire _2;
		} forEach _1;
	} else {
		_1 doSuppressiveFire _2;
	};
};
if (_type isEqualTo 'commandSuppressiveFire') exitWith {
	if (_1 isEqualType []) then {
		{
			_x commandSuppressiveFire _2;
		} forEach _1;
	} else {
		_1 commandSuppressiveFire _2;
	};
};
if (_type isEqualTo 'deleteVehicleCrew') exitWith {
	if (_1 isEqualTo _2) then {
		deleteVehicleCrew _1;
	} else {
		_1 deleteVehicleCrew _2;
	};
};
if (_type isEqualTo 'setMissileTarget') exitWith {
	if (_1 isEqualType []) then {
		{
			_x setMissileTarget _2;
		} forEach _1;
	} else {
		_1 setMissileTarget _2;
	};
};
if (_type isEqualTo 'setMissileTargetPos') exitWith {
	if (_1 isEqualType []) then {
		{
			_x setMissileTargetPos _2;
		} forEach _1;
	} else {
		_1 setMissileTargetPos _2;
	};
};
if (_type isEqualTo 'triggerAmmo') exitWith {
	triggerAmmo _1;
};
if (_type isEqualTo 'awake') exitWith {
	if (_1 isEqualType objNull) then {
		_1 awake _2;
	} else {
		if (_1 isEqualType []) then {
			{
				if (_x isEqualType objNull) then {
					_x awake _2;
				};
			} forEach _1;
		};
	};
};
if (_type isEqualTo 'action') exitWith {
	if (_rxID <= 2) then {
		_1 action _2;
	};
};
if (_type isEqualTo 'forceWeaponFire') exitWith {
	if (_rxID <= 2) then {
		_1 forceWeaponFire _2;
	};
};
if (_type isEqualTo 'disableBrakes') exitWith {
	_1 disableBrakes _2;
};
if (_type isEqualTo 'setTowParent') exitWith {
	if ((getTowParent _1) isNotEqualTo _2) then {
		_1 setTowParent _2;
	};
};
if (_type isEqualTo 'hideObjectGlobal') exitWith {
	if (isDedicated) then {
		diag_log format ['***** Remote Execution of hideObjectGlobal on %1 by %2 to target %3',(typeOf _1),remoteExecutedOwner,clientOwner];
	};
	_1 hideObjectGlobal _2;
};
if (_type isEqualTo 'setCustomSoundController') exitWith {
	setCustomSoundController _1;
};
if (_type isEqualTo 'setVehicleCargo') exitWith {
	_1 setVehicleCargo _2;
};
if (_type isEqualTo 'lock') exitWith {
	_1 lock _2;
};
if (_type isEqualTo 'lockTurret') exitWith {
	_1 lockTurret _2;
};
if (_type isEqualTo 'lockCargo') exitWith {
	if (_2 isEqualType TRUE) then {
		_1 lockCargo _2;
	} else {
		if (_2 isEqualType []) then {
			if ((_2 # 0) isEqualType []) then {
				{
					_1 lockCargo [_x,(_2 # 1)];
				} forEach (_2 # 0);
			} else {
				if ((_2 # 0) isEqualType 0) then {
					_1 lockCargo _2;
				};
			};
		};
	};
};
if (_type isEqualTo 'lockInventory') exitWith {
	_1 lockInventory _2;
};
if (_type isEqualTo 'lockDriver') exitWith {
	_1 lockDriver _2;
};
if (_type isEqualTo 'moveOut') exitWith {
	_1 moveOut _2;
};
if (_type isEqualTo 'switchLight') exitWith {
	if (local _1) then {
		if (!simulationEnabled _1) then {
			if (isDedicated) then {
				_1 enableSimulationGlobal TRUE;
			} else {
				_1 enableSimulation TRUE;
			};
		};
	};
	_1 switchLight _2;
};
if (_type isEqualTo 'setPilotLight') exitWith {
	_1 setPilotLight _2;
};
if (_type isEqualTo 'forgetTarget') exitWith {
	_1 forgetTarget _2;
	if (_1 isEqualType grpNull) then {
		{
			_x forgetTarget _2;
		} forEach (units _1);
	} else {
		(group _1) forgetTarget _2;
	};
};
if (_type isEqualTo 'disableCollisionWith') exitWith {
	_1 disableCollisionWith _2;
};
if (_type isEqualTo 'enableCollisionWith') exitWith {
	_1 enableCollisionWith _2;
};
if (_type isEqualTo 'addVehicle') exitWith {
	if (
		(!isNull _1) &&
		{(!(_2 in (assignedVehicles _1)))} &&
		{((assignedGroup _2) isNotEqualTo _1)}
	) then {
		_1 addVehicle _2;
	};
};
if (_type isEqualTo 'leaveVehicle') exitWith {
	if (
		(!isNull _1) &&
		{(_2 in (assignedVehicles _1))}
	) then {
		_1 leaveVehicle _2;
	};
};
if (_type isEqualTo 'allowService') exitWith {
	_1 allowService _2;
};
if (_type isEqualTo 'setVectorDirAndUp') exitWith {
	_1 setVectorDirAndUp _2;
};
if (_type isEqualTo 'setPlateNumber') exitWith {
	if ((getPlateNumber _1) isNotEqualTo _2) then {
		_1 setPlateNumber _2;
	};
};
if (_type isEqualTo 'setFace') exitWith {
	_1 setFace _2;
};
if (_type isEqualTo 'setFlagAnimationPhase') exitWith {
	if ((flagAnimationPhase _1) isNotEqualTo _2) then {
		_1 setFlagAnimationPhase _2;
	};
};
if (_type isEqualTo 'setEffectiveCommander') exitWith {
	_1 setEffectiveCommander _2;
};
if (_type isEqualTo 'setUnitPos') exitWith {
	_1 setUnitPos _2;
};
if (_type isEqualTo 'addForce') exitWith {
	diag_log format ['***** DEBUG ***** addForce executed: %1 (%4) %2 by %3',_1,_2,remoteExecutedOwner,typeOf _1];
	_1 awake TRUE;
	_1 addForce _2;
};
if (_type isEqualTo 'addTorque') exitWith {
	diag_log format ['***** DEBUG ***** addTorque executed: %1 (%4) %2 by %3',_1,_2,remoteExecutedOwner,typeOf _1];
	_1 awake TRUE;
	_1 addTorque _2;
};
