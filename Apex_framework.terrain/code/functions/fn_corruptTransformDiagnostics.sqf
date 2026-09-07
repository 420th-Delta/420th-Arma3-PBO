/*
File: fn_corruptTransformDiagnostics.sqf

Description:

	Server-only, read-only diagnostics for non-finite, degenerate, out-of-range,
	or otherwise suspicious entity transforms. BombCore projectiles also receive
	server-local provenance, firing-context, ownership, lifecycle, and last-valid
	transform tracing. Newly created entities are queued for a bounded scheduled
	check. Killed entities and a bounded set of directly related objects are checked
	immediately because observed freezes have begun at an EntityKilled boundary. A
	periodic batched census catches later corruption.
__________________________________________________*/

if (!isServer) exitWith {};
if (serverNamespace getVariable ['QS_transformDiag_initialized',FALSE]) exitWith {};
serverNamespace setVariable ['QS_transformDiag_initialized',TRUE];
serverNamespace setVariable ['QS_transformDiag_createdQueue',[]];
serverNamespace setVariable ['QS_transformDiag_queueDropped',0];
serverNamespace setVariable ['QS_transformDiag_cache',createHashMap];
serverNamespace setVariable ['QS_transformDiag_cacheEvicted',0];
serverNamespace setVariable ['QS_transformDiag_bombTraceCounter',0];
serverNamespace setVariable ['QS_transformDiag_jetTraceCounter',0];
serverNamespace setVariable ['QS_transformDiag_fireMissionCounter',0];

/* Compact, stable references used by all projectile provenance records. */
serverNamespace setVariable ['QS_transformDiag_objectReference',{
	params ['_object'];
	if (isNull _object) exitWith {[]};
	[
		typeOf _object,
		netId _object,
		owner _object,
		local _object,
		str _object,
		vehicleVarName _object,
		getPosWorld _object,
		velocity _object,
		vectorDir _object,
		vectorUp _object
	]
}];

serverNamespace setVariable ['QS_transformDiag_groupReference',{
	params ['_group'];
	if (isNull _group) exitWith {[]};
	[groupId _group,groupOwner _group,side _group,str _group,count (units _group)]
}];

/* Snapshot projectile ancestry while the parent and instigator references exist. */
serverNamespace setVariable ['QS_transformDiag_projectileAncestry',{
	params ['_projectile'];
	if (isNull _projectile) exitWith {[]};
	private _objectReference = serverNamespace getVariable 'QS_transformDiag_objectReference';
	private _shotInfo = getShotInfo _projectile;
	if (!(_shotInfo isEqualType [])) then {_shotInfo = [];};
	private _shotParents = getShotParents _projectile;
	if (!(_shotParents isEqualType [])) then {_shotParents = [];};
	private _shotParent = _shotInfo param [8,objNull,[objNull]];
	private _shotInstigator = _shotInfo param [9,objNull,[objNull]];
	private _parentFromLegacy = _shotParents param [0,objNull,[objNull]];
	private _instigatorFromLegacy = _shotParents param [1,objNull,[objNull]];
	[
		_shotInfo select [0,8],
		[_shotParent] call _objectReference,
		[_shotInstigator] call _objectReference,
		[_parentFromLegacy] call _objectReference,
		[_instigatorFromLegacy] call _objectReference,
		[missileTarget _projectile] call _objectReference,
		missileTargetPos _projectile
	]
}];

serverNamespace setVariable ['QS_transformDiag_transformIsValid',{
	params ['_entity'];
	if (isNull _entity) exitWith {FALSE};
	private _finiteVector3 = {
		params ['_value'];
		(_value isEqualType []) &&
		{(count _value) isEqualTo 3} &&
		{(_value findIf {!(finite _x)}) isEqualTo -1}
	};
	private _direction = vectorDir _entity;
	private _up = vectorUp _entity;
	([getPosWorld _entity] call _finiteVector3) &&
	{[velocity _entity] call _finiteVector3} &&
	{[_direction] call _finiteVector3} &&
	{[_up] call _finiteVector3} &&
	{finite (getDir _entity)} &&
	{finite (getObjectScale _entity)} &&
	{(vectorMagnitude _direction) >= 0.0001} &&
	{(vectorMagnitude _up) >= 0.0001}
}];

serverNamespace setVariable ['QS_transformDiag_projectileSample',{
	params ['_projectile'];
	[
		diag_tickTime,
		serverTime,
		diag_frameNo,
		owner _projectile,
		local _projectile,
		getPosWorld _projectile,
		getPosASL _projectile,
		velocity _projectile,
		vectorDir _projectile,
		vectorUp _projectile,
		getDir _projectile,
		getObjectScale _projectile
	]
}];

/* Called by ProjectileCreated and by the jet Fired handler. */
missionNamespace setVariable ['QS_fnc_transformDiagRegisterBomb',{
	params ['_projectile',['_registrationSource','unspecified']];
	if (
		!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) ||
		{!(missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE])} ||
		{isNull _projectile} ||
		{!(_projectile isKindOf 'BombCore')}
	) exitWith {''};

	private _trace = _projectile getVariable ['QS_transformDiag_bombTrace',createHashMap];
	if ((count _trace) isNotEqualTo 0) exitWith {_trace getOrDefault ['traceId',''];};

	private _counter = (serverNamespace getVariable ['QS_transformDiag_bombTraceCounter',0]) + 1;
	serverNamespace setVariable ['QS_transformDiag_bombTraceCounter',_counter];
	private _traceId = format ['B%1',_counter];
	private _ancestry = [_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileAncestry');
	private _sample = [_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileSample');
	private _initialValid = [_projectile] call (serverNamespace getVariable 'QS_transformDiag_transformIsValid');
	_trace = createHashMapFromArray [
		['traceId',_traceId],
		['registrationSource',_registrationSource],
		['createdTick',diag_tickTime],
		['createdServerTime',serverTime],
		['createdFrame',diag_frameNo],
		['createdOwner',owner _projectile],
		['createdLocal',local _projectile],
		['lastOwner',owner _projectile],
		['lastLocal',local _projectile],
		['createdAncestry',_ancestry],
		['samples',[[],[_sample]] select _initialValid],
		['lastValid',[[],_sample] select _initialValid],
		['firedContext',[]],
		['corruptSeen',FALSE]
	];
	_projectile setVariable ['QS_transformDiag_bombTrace',_trace,FALSE];
	_projectile setVariable ['QS_transformDiag_bombTraceId',_traceId,FALSE];

	diag_log text format [
		'[QS BOMB] CREATED trace=%1 source=%2 tick=%3 serverTime=%4 frame=%5 class="%6" netId="%7" owner=%8 local=%9 positionWorld=%10 positionASL=%11 velocity=%12 vectorDir=%13 vectorUp=%14 heading=%15 objectScale=%16 ancestry=%17',
		_traceId,
		_registrationSource,
		diag_tickTime,
		serverTime,
		diag_frameNo,
		typeOf _projectile,
		netId _projectile,
		owner _projectile,
		local _projectile,
		getPosWorld _projectile,
		getPosASL _projectile,
		velocity _projectile,
		vectorDir _projectile,
		vectorUp _projectile,
		getDir _projectile,
		getObjectScale _projectile,
		_ancestry
	];

	_projectile addEventHandler [
		'Explode',
		{
			params ['_projectile','_position','_velocity'];
			if (!(missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE])) exitWith {};
			diag_log text format [
				'[QS BOMB] EXPLODE trace=%1 tick=%2 serverTime=%3 frame=%4 class="%5" netId="%6" owner=%7 local=%8 position=%9 velocity=%10 ancestry=%11',
				_projectile getVariable ['QS_transformDiag_bombTraceId',''],
				diag_tickTime,
				serverTime,
				diag_frameNo,
				typeOf _projectile,
				netId _projectile,
				owner _projectile,
				local _projectile,
				_position,
				_velocity,
				[_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileAncestry')
			];
		}
	];
	_projectile addEventHandler [
		'HitPart',
		{
			params ['_projectile','_hitEntity','_projectileOwner','_position','_velocity','_normal','_components','_radius','_surfaceType','_instigator'];
			if (!(missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE])) exitWith {};
			private _objectReference = serverNamespace getVariable 'QS_transformDiag_objectReference';
			diag_log text format [
				'[QS BOMB] HIT_PART trace=%1 tick=%2 serverTime=%3 frame=%4 class="%5" netId="%6" owner=%7 local=%8 hitEntity=%9 projectileOwner=%10 instigator=%11 position=%12 velocity=%13 normal=%14 components=%15 radius=%16 surfaceType="%17"',
				_projectile getVariable ['QS_transformDiag_bombTraceId',''],
				diag_tickTime,
				serverTime,
				diag_frameNo,
				typeOf _projectile,
				netId _projectile,
				owner _projectile,
				local _projectile,
				[_hitEntity] call _objectReference,
				[_projectileOwner] call _objectReference,
				[_instigator] call _objectReference,
				_position,
				_velocity,
				_normal,
				_components,
				_radius,
				_surfaceType
			];
		}
	];
	_projectile addEventHandler [
		'Deleted',
		{
			params ['_projectile'];
			if (!(missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE])) exitWith {};
			private _trace = _projectile getVariable ['QS_transformDiag_bombTrace',createHashMap];
			diag_log text format [
				'[QS BOMB] DELETED trace=%1 tick=%2 serverTime=%3 frame=%4 class="%5" netId="%6" owner=%7 local=%8 corruptSeen=%9 lastValid=%10 firedContext=%11',
				_trace getOrDefault ['traceId',''],
				diag_tickTime,
				serverTime,
				diag_frameNo,
				typeOf _projectile,
				netId _projectile,
				owner _projectile,
				local _projectile,
				_trace getOrDefault ['corruptSeen',FALSE],
				_trace getOrDefault ['lastValid',[]],
				_trace getOrDefault ['firedContext',[]]
			];
		}
	];

	// ProjectileCreated can run before the network ID and shot parents are fully populated.
	[_projectile] spawn {
		params ['_projectile'];
		uiSleep 0.05;
		if (isNull _projectile || {!(missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE])}) exitWith {};
		private _trace = _projectile getVariable ['QS_transformDiag_bombTrace',createHashMap];
		private _initializedSample = [_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileSample');
		private _initializedAncestry = [_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileAncestry');
		_trace set ['initializedSample',_initializedSample];
		_trace set ['initializedAncestry',_initializedAncestry];
		_projectile setVariable ['QS_transformDiag_bombTrace',_trace,FALSE];
		diag_log text format [
			'[QS BOMB] INITIALIZED trace=%1 tick=%2 serverTime=%3 frame=%4 class="%5" netId="%6" owner=%7 local=%8 positionWorld=%9 positionASL=%10 velocity=%11 vectorDir=%12 vectorUp=%13 heading=%14 objectScale=%15 ancestry=%16',
			_trace getOrDefault ['traceId',''],
			diag_tickTime,
			serverTime,
			diag_frameNo,
			typeOf _projectile,
			netId _projectile,
			owner _projectile,
			local _projectile,
			getPosWorld _projectile,
			getPosASL _projectile,
			velocity _projectile,
			vectorDir _projectile,
			vectorUp _projectile,
			getDir _projectile,
			getObjectScale _projectile,
			_initializedAncestry
		];
	};

	[_projectile] spawn {
		params ['_projectile'];
		private _endTime = diag_tickTime + (missionNamespace getVariable ['QS_transformDiag_bombTraceSeconds',180]);
		private _sampleDelay = (missionNamespace getVariable ['QS_transformDiag_bombSampleSeconds',0.1]) max 0.05;
		private _sampleLimit = (missionNamespace getVariable ['QS_transformDiag_bombSampleLimit',16]) max 2;
		while {
			!(isNull _projectile) &&
			{diag_tickTime <= _endTime} &&
			{missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE]}
		} do {
			private _trace = _projectile getVariable ['QS_transformDiag_bombTrace',createHashMap];
			private _sample = [_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileSample');
			private _currentOwner = owner _projectile;
			private _currentLocal = local _projectile;
			private _lastOwner = _trace getOrDefault ['lastOwner',_currentOwner];
			private _lastLocal = _trace getOrDefault ['lastLocal',_currentLocal];
			if ((_currentOwner isNotEqualTo _lastOwner) || {_currentLocal isNotEqualTo _lastLocal}) then {
				diag_log text format [
					'[QS BOMB] LOCALITY trace=%1 tick=%2 serverTime=%3 frame=%4 class="%5" netId="%6" previousOwner=%7 owner=%8 previousLocal=%9 local=%10 clientOwner=%11 positionWorld=%12 velocity=%13 vectorDir=%14 vectorUp=%15',
					_trace getOrDefault ['traceId',''],
					diag_tickTime,
					serverTime,
					diag_frameNo,
					typeOf _projectile,
					netId _projectile,
					_lastOwner,
					_currentOwner,
					_lastLocal,
					_currentLocal,
					clientOwner,
					getPosWorld _projectile,
					velocity _projectile,
					vectorDir _projectile,
					vectorUp _projectile
				];
			};
			_trace set ['lastOwner',_currentOwner];
			_trace set ['lastLocal',_currentLocal];
			private _valid = [_projectile] call (serverNamespace getVariable 'QS_transformDiag_transformIsValid');
			if (!_valid) exitWith {
				_trace set ['corruptSeen',TRUE];
				_trace set ['firstInvalid',_sample];
				_projectile setVariable ['QS_transformDiag_bombTrace',_trace,FALSE];
				diag_log text format [
					'[QS BOMB] CORRUPT_TRANSITION trace=%1 tick=%2 serverTime=%3 frame=%4 class="%5" netId="%6" owner=%7 local=%8 createdTick=%9 createdFrame=%10 lastValid=%11 firstInvalid=%12 samples=%13 firedContext=%14 ancestryNow=%15',
					_trace getOrDefault ['traceId',''],
					diag_tickTime,
					serverTime,
					diag_frameNo,
					typeOf _projectile,
					netId _projectile,
					owner _projectile,
					local _projectile,
					_trace getOrDefault ['createdTick',-1],
					_trace getOrDefault ['createdFrame',-1],
					_trace getOrDefault ['lastValid',[]],
					_sample,
					_trace getOrDefault ['samples',[]],
					_trace getOrDefault ['firedContext',[]],
					[_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileAncestry')
				];
				if (!isNil {serverNamespace getVariable 'QS_transformDiag_checkEntity'}) then {
					[_projectile,'projectile-transition'] call (serverNamespace getVariable 'QS_transformDiag_checkEntity');
				};
			};
			private _samples = _trace getOrDefault ['samples',[]];
			_samples pushBack _sample;
			if ((count _samples) > _sampleLimit) then {_samples deleteAt 0;};
			_trace set ['samples',_samples];
			_trace set ['lastValid',_sample];
			_projectile setVariable ['QS_transformDiag_bombTrace',_trace,FALSE];
			uiSleep _sampleDelay;
		};
	};

	_traceId
}];

missionNamespace setVariable ['QS_fnc_transformDiagRecordBombFired',{
	params ['_vehicle','_weapon','_muzzle','_mode','_ammo','_magazine','_projectile','_gunner'];
	if (
		!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) ||
		{!(missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE])} ||
		{isNull _projectile} ||
		{!(_ammo isKindOf 'BombCore')}
	) exitWith {};
	private _traceId = [_projectile,'jet.Fired'] call (missionNamespace getVariable 'QS_fnc_transformDiagRegisterBomb');
	private _trace = _projectile getVariable ['QS_transformDiag_bombTrace',createHashMap];
	private _objectReference = serverNamespace getVariable 'QS_transformDiag_objectReference';
	private _vehicleGroup = grpNull;
	if (!isNull _gunner) then {_vehicleGroup = group _gunner;};
	private _assignedTarget = objNull;
	private _currentCommand = '';
	if (!isNull _gunner) then {
		_assignedTarget = assignedTarget _gunner;
		_currentCommand = currentCommand _gunner;
	};
	private _attackTarget = objNull;
	if (!isNull _gunner) then {_attackTarget = getAttackTarget _gunner;};
	private _missionTarget = _vehicle getVariable ['QS_transformDiag_fireMissionTarget',objNull];
	private _aimQuality = -1;
	if (!isNull _missionTarget) then {_aimQuality = _vehicle aimedAtTarget [_missionTarget];};
	private _firedContext = [
		diag_tickTime,
		serverTime,
		diag_frameNo,
		_weapon,
		_muzzle,
		_mode,
		_ammo,
		_magazine,
		[_vehicle] call _objectReference,
		[_gunner] call _objectReference,
		[_vehicleGroup] call (serverNamespace getVariable 'QS_transformDiag_groupReference'),
		_vehicle getVariable ['QS_transformDiag_jetTraceId',''],
		_vehicle getVariable ['QS_transformDiag_jetSource','unclassified'],
		_vehicle getVariable ['QS_transformDiag_fireMissionId',''],
		_vehicle getVariable ['QS_transformDiag_lastFireCommand',[]]
	];
	_trace set ['firedContext',_firedContext];
	_trace set ['firedAncestry',[_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileAncestry')];
	_projectile setVariable ['QS_transformDiag_bombTrace',_trace,FALSE];
	diag_log text format [
		'[QS BOMB] FIRED trace=%1 tick=%2 serverTime=%3 frame=%4 projectileClass="%5" projectileNetId="%6" projectileOwner=%7 projectileLocal=%8 weapon="%9" muzzle="%10" mode="%11" ammo="%12" magazine="%13" jetTrace=%14 jetSource=%15 vehicle=%16 gunner=%17 group=%18 fireMissionId=%19 fireMissionActive=%20 missionTarget=%21 missionTargetPosition=%22 assignedTarget=%23 attackTarget=%24 currentCommand="%25" aimQuality=%26 positionWorld=%27 velocity=%28 vectorDir=%29 vectorUp=%30 pylons=%31 ancestry=%32 ammoSources=%33 weaponSources=%34 magazineSources=%35',
		_traceId,
		diag_tickTime,
		serverTime,
		diag_frameNo,
		typeOf _projectile,
		netId _projectile,
		owner _projectile,
		local _projectile,
		_weapon,
		_muzzle,
		_mode,
		_ammo,
		_magazine,
		_vehicle getVariable ['QS_transformDiag_jetTraceId',''],
		_vehicle getVariable ['QS_transformDiag_jetSource','unclassified'],
		[_vehicle] call _objectReference,
		[_gunner] call _objectReference,
		[_vehicleGroup] call (serverNamespace getVariable 'QS_transformDiag_groupReference'),
		_vehicle getVariable ['QS_transformDiag_fireMissionId',''],
		_vehicle getVariable ['QS_AI_PLANE_fireMission',FALSE],
		[_missionTarget] call _objectReference,
		_vehicle getVariable ['QS_transformDiag_fireMissionTargetPosition',[]],
		[_assignedTarget] call _objectReference,
		[_attackTarget] call _objectReference,
		_currentCommand,
		_aimQuality,
		getPosWorld _vehicle,
		velocity _vehicle,
		vectorDir _vehicle,
		vectorUp _vehicle,
		getAllPylonsInfo _vehicle,
		[_projectile] call (serverNamespace getVariable 'QS_transformDiag_projectileAncestry'),
		configSourceAddonList (configFile >> 'CfgAmmo' >> _ammo),
		configSourceAddonList (configFile >> 'CfgWeapons' >> _weapon),
		configSourceAddonList (configFile >> 'CfgMagazines' >> _magazine)
	];
}];

/* Register a server-created enemy jet and retain its firing/locality history. */
missionNamespace setVariable ['QS_fnc_transformDiagRegisterEnemyJet',{
	params ['_jet',['_source','unclassified.enemyJet']];
	if (
		!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) ||
		{isNull _jet} ||
		{!(_jet isKindOf 'Plane')}
	) exitWith {''};
	private _jetTraceId = _jet getVariable ['QS_transformDiag_jetTraceId',''];
	if (_jetTraceId isEqualTo '') then {
		private _counter = (serverNamespace getVariable ['QS_transformDiag_jetTraceCounter',0]) + 1;
		serverNamespace setVariable ['QS_transformDiag_jetTraceCounter',_counter];
		_jetTraceId = format ['J%1',_counter];
		_jet setVariable ['QS_transformDiag_jetTraceId',_jetTraceId,FALSE];
	};
	_jet setVariable ['QS_transformDiag_jetSource',_source,FALSE];
	private _objectReference = serverNamespace getVariable 'QS_transformDiag_objectReference';
	private _crewReferences = [];
	{_crewReferences pushBack ([_x] call _objectReference);} forEach (crew _jet);
	private _jetGroup = grpNull;
	if ((crew _jet) isNotEqualTo []) then {_jetGroup = group ((crew _jet) # 0);};

	if (!(_jet getVariable ['QS_transformDiag_firedEHAdded',FALSE])) then {
		private _firedEH = _jet addEventHandler [
			'Fired',
			{
				params ['','','','','_ammo'];
				if (_ammo isKindOf 'BombCore') then {
					_this call (missionNamespace getVariable 'QS_fnc_transformDiagRecordBombFired');
				};
			}
		];
		_jet setVariable ['QS_transformDiag_firedEHAdded',TRUE,FALSE];
		_jet setVariable ['QS_transformDiag_firedEH',_firedEH,FALSE];
		private _localEH = _jet addEventHandler [
			'Local',
			{
				params ['_jet','_isLocal'];
				if (!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE])) exitWith {};
				diag_log text format [
					'[QS JET] LOCALITY jetTrace=%1 source=%2 tick=%3 serverTime=%4 frame=%5 class="%6" netId="%7" owner=%8 local=%9 eventLocal=%10 clientOwner=%11 positionWorld=%12 velocity=%13 vectorDir=%14 vectorUp=%15',
					_jet getVariable ['QS_transformDiag_jetTraceId',''],
					_jet getVariable ['QS_transformDiag_jetSource','unclassified'],
					diag_tickTime,
					serverTime,
					diag_frameNo,
					typeOf _jet,
					netId _jet,
					owner _jet,
					local _jet,
					_isLocal,
					clientOwner,
					getPosWorld _jet,
					velocity _jet,
					vectorDir _jet,
					vectorUp _jet
				];
			}
		];
		_jet setVariable ['QS_transformDiag_localEH',_localEH,FALSE];
	};

	if (!isNull _jetGroup && {!(_jetGroup getVariable ['QS_transformDiag_localEHAdded',FALSE])}) then {
		private _groupLocalEH = _jetGroup addEventHandler [
			'Local',
			{
				params ['_group','_isLocal'];
				if (!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE])) exitWith {};
				diag_log text format [
					'[QS JET] GROUP_LOCALITY groupTrace=%1 source=%2 tick=%3 serverTime=%4 frame=%5 group=%6 groupId="%7" groupOwner=%8 local=%9 eventLocal=%10 clientOwner=%11 units=%12',
					_group getVariable ['QS_transformDiag_groupTraceId',''],
					_group getVariable ['QS_transformDiag_groupSource','unclassified'],
					diag_tickTime,
					serverTime,
					diag_frameNo,
					str _group,
					groupId _group,
					groupOwner _group,
					local _group,
					_isLocal,
					clientOwner,
					count (units _group)
				];
			}
		];
		_jetGroup setVariable ['QS_transformDiag_localEHAdded',TRUE,FALSE];
		_jetGroup setVariable ['QS_transformDiag_localEH',_groupLocalEH,FALSE];
		_jetGroup setVariable ['QS_transformDiag_groupTraceId',_jetTraceId,FALSE];
		_jetGroup setVariable ['QS_transformDiag_groupSource',_source,FALSE];
	};

	diag_log text format [
		'[QS JET] REGISTERED jetTrace=%1 source=%2 tick=%3 serverTime=%4 frame=%5 class="%6" netId="%7" owner=%8 local=%9 positionWorld=%10 velocity=%11 vectorDir=%12 vectorUp=%13 group=%14 crew=%15 pylons=%16',
		_jetTraceId,
		_source,
		diag_tickTime,
		serverTime,
		diag_frameNo,
		typeOf _jet,
		netId _jet,
		owner _jet,
		local _jet,
		getPosWorld _jet,
		velocity _jet,
		vectorDir _jet,
		vectorUp _jet,
		[_jetGroup] call (serverNamespace getVariable 'QS_transformDiag_groupReference'),
		_crewReferences,
		getAllPylonsInfo _jet
	];
	_jetTraceId
}];

missionNamespace setVariable ['QS_fnc_transformDiagAirFireMission',{
	params ['_event','_vehicle',['_target',objNull],['_targetPosition',[]],['_laserTarget',objNull]];
	if (
		!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) ||
		{!(missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE])} ||
		{isNull _vehicle}
	) exitWith {};
	private _objectReference = serverNamespace getVariable 'QS_transformDiag_objectReference';
	if (_event isEqualTo 'START') then {
		private _counter = (serverNamespace getVariable ['QS_transformDiag_fireMissionCounter',0]) + 1;
		serverNamespace setVariable ['QS_transformDiag_fireMissionCounter',_counter];
		private _missionId = format ['FM%1',_counter];
		_vehicle setVariable ['QS_transformDiag_fireMissionId',_missionId,FALSE];
		_vehicle setVariable ['QS_transformDiag_fireMissionTarget',_target,FALSE];
		_vehicle setVariable ['QS_transformDiag_fireMissionTargetPosition',_targetPosition,FALSE];
		_vehicle setVariable ['QS_transformDiag_fireMissionLaserTarget',_laserTarget,FALSE];
		private _fireGroupOwner = -1;
		if (!isNull (driver _vehicle)) then {_fireGroupOwner = groupOwner (group (driver _vehicle));};
		diag_log text format [
			'[QS BOMB] FIRE_MISSION event=START missionId=%1 jetTrace=%2 jetSource=%3 tick=%4 serverTime=%5 frame=%6 vehicle=%7 target=%8 targetPosition=%9 laserTarget=%10 owner=%11 local=%12 groupOwner=%13',
			_missionId,
			_vehicle getVariable ['QS_transformDiag_jetTraceId',''],
			_vehicle getVariable ['QS_transformDiag_jetSource','unclassified'],
			diag_tickTime,
			serverTime,
			diag_frameNo,
			[_vehicle] call _objectReference,
			[_target] call _objectReference,
			_targetPosition,
			[_laserTarget] call _objectReference,
			owner _vehicle,
			local _vehicle,
			_fireGroupOwner
		];
	};
	if (_event isEqualTo 'COMMAND') then {
		_vehicle setVariable [
			'QS_transformDiag_lastFireCommand',
			[diag_tickTime,serverTime,diag_frameNo,[_target] call _objectReference,_targetPosition,[_laserTarget] call _objectReference,_vehicle aimedAtTarget [_laserTarget],currentWeapon _vehicle],
			FALSE
		];
	};
	if (_event isEqualTo 'END') then {
		diag_log text format [
			'[QS BOMB] FIRE_MISSION event=END missionId=%1 jetTrace=%2 jetSource=%3 tick=%4 serverTime=%5 frame=%6 vehicle=%7 target=%8 targetPosition=%9 laserTarget=%10 lastFireCommand=%11',
			_vehicle getVariable ['QS_transformDiag_fireMissionId',''],
			_vehicle getVariable ['QS_transformDiag_jetTraceId',''],
			_vehicle getVariable ['QS_transformDiag_jetSource','unclassified'],
			diag_tickTime,
			serverTime,
			diag_frameNo,
			[_vehicle] call _objectReference,
			[_target] call _objectReference,
			_targetPosition,
			[_laserTarget] call _objectReference,
			_vehicle getVariable ['QS_transformDiag_lastFireCommand',[]]
		];
	};
}];

missionNamespace setVariable ['QS_fnc_transformDiagGroupOwnerRequest',{
	params ['_group','_ownerBefore','_requestedOwner','_result'];
	if (!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) || {isNull _group}) exitWith {};
	private _jetIndex = (units _group) findIf {
		private _vehicle = vehicle _x;
		(_vehicle isKindOf 'Plane') && {(_vehicle getVariable ['QS_transformDiag_jetTraceId','']) isNotEqualTo ''}
	};
	if (_jetIndex isEqualTo -1) exitWith {};
	diag_log text format [
		'[QS JET] GROUP_OWNER_REQUEST tick=%1 serverTime=%2 frame=%3 group=%4 groupId="%5" ownerBefore=%6 requestedOwner=%7 result=%8 ownerAfter=%9 localAfter=%10 clientOwner=%11 groupTrace=%12 source=%13',
		diag_tickTime,
		serverTime,
		diag_frameNo,
		str _group,
		groupId _group,
		_ownerBefore,
		_requestedOwner,
		_result,
		groupOwner _group,
		local _group,
		clientOwner,
		_group getVariable ['QS_transformDiag_groupTraceId',''],
		_group getVariable ['QS_transformDiag_groupSource','unclassified']
	];
}];

/* Returns [state, emitted], where state is 0=valid, 1=corrupt, 2=suspicious.
   The function does not mutate the inspected entity. */
serverNamespace setVariable ['QS_transformDiag_checkEntity',{
	params ['_entity',['_source','unspecified']];
	if (
		!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) ||
		{isNull _entity}
	) exitWith {[0,FALSE]};

	private _position = getPosWorld _entity;
	private _velocity = velocity _entity;
	private _vectorDir = vectorDir _entity;
	private _vectorUp = vectorUp _entity;
	private _heading = getDir _entity;
	private _objectScale = getObjectScale _entity;
	private _corruptReasons = [];
	private _suspiciousReasons = [];

	private _validateVector = {
		params ['_value'];
		if (!(_value isEqualType []) || {(count _value) isNotEqualTo 3}) exitWith {[FALSE,FALSE]};
		[TRUE,(_value findIf {!(finite _x)}) isEqualTo -1]
	};
	private _positionStatus = [_position] call _validateVector;
	private _velocityStatus = [_velocity] call _validateVector;
	private _dirStatus = [_vectorDir] call _validateVector;
	private _upStatus = [_vectorUp] call _validateVector;

	if (!(_positionStatus # 0)) then {
		_corruptReasons pushBack 'position.malformed';
	} else {
		if (!(_positionStatus # 1)) then {_corruptReasons pushBack 'position.nonFinite';};
	};
	if (!(_velocityStatus # 0)) then {
		_corruptReasons pushBack 'velocity.malformed';
	} else {
		if (!(_velocityStatus # 1)) then {_corruptReasons pushBack 'velocity.nonFinite';};
	};
	if (!(_dirStatus # 0)) then {
		_corruptReasons pushBack 'vectorDir.malformed';
	} else {
		if (!(_dirStatus # 1)) then {_corruptReasons pushBack 'vectorDir.nonFinite';};
	};
	if (!(_upStatus # 0)) then {
		_corruptReasons pushBack 'vectorUp.malformed';
	} else {
		if (!(_upStatus # 1)) then {_corruptReasons pushBack 'vectorUp.nonFinite';};
	};
	if (!(finite _heading)) then {_corruptReasons pushBack 'heading.nonFinite';};
	if (!(finite _objectScale)) then {
		_corruptReasons pushBack 'objectScale.nonFinite';
	} else {
		if ((abs _objectScale) < 0.0001) then {_corruptReasons pushBack 'objectScale.degenerate';};
	};

	private _dirMagnitude = -1;
	private _upMagnitude = -1;
	private _dirUpCos = -2;
	if ((_dirStatus # 0) && {_dirStatus # 1}) then {
		_dirMagnitude = vectorMagnitude _vectorDir;
		if (_dirMagnitude < 0.0001) then {_corruptReasons pushBack 'vectorDir.degenerate';};
	};
	if ((_upStatus # 0) && {_upStatus # 1}) then {
		_upMagnitude = vectorMagnitude _vectorUp;
		if (_upMagnitude < 0.0001) then {_corruptReasons pushBack 'vectorUp.degenerate';};
	};
	if ((_dirMagnitude >= 0.0001) && {_upMagnitude >= 0.0001}) then {
		_dirUpCos = abs (_vectorDir vectorCos _vectorUp);
		if (_dirUpCos > (missionNamespace getVariable ['QS_transformDiag_orthogonalTolerance',0.05])) then {
			_suspiciousReasons pushBack 'orientation.nonOrthogonal';
		};
	};

	private _f16Limit = missionNamespace getVariable ['QS_transformDiag_f16Limit',65000];
	if ((_positionStatus # 0) && {_positionStatus # 1} && {(_position findIf {abs _x >= _f16Limit}) isNotEqualTo -1}) then {
		_suspiciousReasons pushBack 'position.f16Range';
	};
	if ((_velocityStatus # 0) && {_velocityStatus # 1} && {(_velocity findIf {abs _x >= _f16Limit}) isNotEqualTo -1}) then {
		_suspiciousReasons pushBack 'velocity.f16Range';
	};
	if ((_dirStatus # 0) && {_dirStatus # 1} && {(_vectorDir findIf {abs _x >= _f16Limit}) isNotEqualTo -1}) then {
		_suspiciousReasons pushBack 'vectorDir.f16Range';
	};
	if ((_upStatus # 0) && {_upStatus # 1} && {(_vectorUp findIf {abs _x >= _f16Limit}) isNotEqualTo -1}) then {
		_suspiciousReasons pushBack 'vectorUp.f16Range';
	};
	if ((finite _objectScale) && {abs _objectScale >= _f16Limit}) then {
		_suspiciousReasons pushBack 'objectScale.f16Range';
	};

	if ((_positionStatus # 0) && {_positionStatus # 1}) then {
		private _worldMargin = missionNamespace getVariable ['QS_transformDiag_worldMargin',6000];
		private _worldMaximum = worldSize + _worldMargin;
		if (
			((_position # 0) < -_worldMargin) ||
			{((_position # 1) < -_worldMargin)} ||
			{((_position # 0) > _worldMaximum)} ||
			{((_position # 1) > _worldMaximum)} ||
			{((_position # 2) < (missionNamespace getVariable ['QS_transformDiag_minWorldZ',-1000]))} ||
			{((_position # 2) > (missionNamespace getVariable ['QS_transformDiag_maxWorldZ',20000]))}
		) then {
			_suspiciousReasons pushBack 'position.outsideWorldEnvelope';
		};
	};

	private _state = 0;
	private _severity = '';
	private _reasons = [];
	if (_corruptReasons isNotEqualTo []) then {
		_state = 1;
		_severity = 'CORRUPT';
		_reasons = _corruptReasons + _suspiciousReasons;
	} else {
		if (_suspiciousReasons isNotEqualTo []) then {
			_state = 2;
			_severity = 'SUSPECT';
			_reasons = _suspiciousReasons;
		};
	};

	private _cache = serverNamespace getVariable 'QS_transformDiag_cache';
	private _cacheKey = str _entity;
	private _cached = _cache getOrDefault [_cacheKey,[]];
	private _now = diag_tickTime;
	if (_state isEqualTo 0) exitWith {
		if (_cached isNotEqualTo []) then {
			diag_log text format [
				'[QS XFORM] RECOVERED tick=%1 frame=%2 source=%3 class="%4" netId="%5" owner=%6 object=%7 previous=%8',
				_now,diag_frameNo,_source,typeOf _entity,netId _entity,owner _entity,_cacheKey,_cached # 0
			];
			_cache deleteAt _cacheKey;
			[0,TRUE]
		} else {
			[0,FALSE]
		};
	};

	private _networkId = netId _entity;
	private _entityOwner = owner _entity;
	private _signature = str [_severity,_reasons,_entityOwner];
	private _emit = (
		(_cached isEqualTo []) ||
		{(_cached # 0) isNotEqualTo _signature} ||
		{((_now - (_cached # 1)) >= (missionNamespace getVariable ['QS_transformDiag_relogSeconds',60]))}
	);
	private _lastLogged = _now;
	if (!_emit && {_cached isNotEqualTo []}) then {_lastLogged = _cached # 1;};
	if (
		(_cached isEqualTo []) &&
		{(count _cache) >= (missionNamespace getVariable ['QS_transformDiag_cacheLimit',8192])}
	) then {
		private _oldestKey = '';
		private _oldestSeen = 1e12;
		{
			if ((_y # 2) < _oldestSeen) then {
				_oldestSeen = _y # 2;
				_oldestKey = _x;
			};
		} forEach _cache;
		if (_oldestKey isNotEqualTo '') then {
			_cache deleteAt _oldestKey;
			serverNamespace setVariable [
				'QS_transformDiag_cacheEvicted',
				(serverNamespace getVariable ['QS_transformDiag_cacheEvicted',0]) + 1
			];
		};
	};
	_cache set [_cacheKey,[_signature,_lastLogged,_now]];

	if (_emit) then {
		private _objectReference = {
			params ['_object'];
			if (isNull _object) exitWith {[]};
			[typeOf _object,netId _object,owner _object,str _object]
		};
		private _attachedParent = attachedTo _entity;
		private _parentObject = objectParent _entity;
		private _vehicleObject = vehicle _entity;
		if (_vehicleObject isEqualTo _entity) then {_vehicleObject = objNull;};
		private _entityGroupOwner = -1;
		if (_entity isKindOf 'CAManBase') then {
			private _entityGroup = group _entity;
			if (!isNull _entityGroup) then {_entityGroupOwner = groupOwner _entityGroup;};
		};
		private _speed = -1;
		if ((_velocityStatus # 0) && {_velocityStatus # 1}) then {_speed = vectorMagnitude _velocity;};
		diag_log text format [
			'[QS XFORM] %1 source=%2 reasons=%3 tick=%4 serverTime=%5 frame=%6 fps=%7 defend=%8 class="%9" netId="%10" owner=%11 local=%12 object=%13 varName="%14" positionWorld=%15 positionASL=%16 velocity=%17 speed=%18 heading=%19 vectorDir=%20 vectorUp=%21 dirMagnitude=%22 upMagnitude=%23 dirUpCos=%24 objectScale=%25 alive=%26 damage=%27 simulationEnabled=%28 simpleObject=%29 side=%30 groupOwner=%31 attachedTo=%32 objectParent=%33 vehicle=%34 attachedCount=%35 configSimulation="%36"',
			_severity,
			_source,
			_reasons,
			_now,
			serverTime,
			diag_frameNo,
			diag_fps,
			missionNamespace getVariable ['QS_defendActive',FALSE],
			typeOf _entity,
			_networkId,
			_entityOwner,
			local _entity,
			_cacheKey,
			vehicleVarName _entity,
			_position,
			getPosASL _entity,
			_velocity,
			_speed,
			_heading,
			_vectorDir,
			_vectorUp,
			_dirMagnitude,
			_upMagnitude,
			_dirUpCos,
			_objectScale,
			alive _entity,
			damage _entity,
			simulationEnabled _entity,
			isSimpleObject _entity,
			side _entity,
			_entityGroupOwner,
			[_attachedParent] call _objectReference,
			[_parentObject] call _objectReference,
			[_vehicleObject] call _objectReference,
			count (attachedObjects _entity),
			getText ((configOf _entity) >> 'simulation')
		];
		if (_entity isKindOf 'BombCore') then {
			private _trace = _entity getVariable ['QS_transformDiag_bombTrace',createHashMap];
			diag_log text format [
				'[QS BOMB] CORRUPT_CONTEXT trace=%1 source=%2 tick=%3 serverTime=%4 frame=%5 class="%6" netId="%7" owner=%8 local=%9 registrationSource=%10 createdTick=%11 createdServerTime=%12 createdFrame=%13 createdOwner=%14 createdLocal=%15 createdAncestry=%16 firedContext=%17 firedAncestry=%18 lastValid=%19 firstInvalid=%20 samples=%21 ancestryNow=%22 target=%23 targetPosition=%24 shotInfo=%25 initializedSample=%26 initializedAncestry=%27',
				_trace getOrDefault ['traceId',''],
				_source,
				diag_tickTime,
				serverTime,
				diag_frameNo,
				typeOf _entity,
				netId _entity,
				owner _entity,
				local _entity,
				_trace getOrDefault ['registrationSource',''],
				_trace getOrDefault ['createdTick',-1],
				_trace getOrDefault ['createdServerTime',-1],
				_trace getOrDefault ['createdFrame',-1],
				_trace getOrDefault ['createdOwner',-1],
				_trace getOrDefault ['createdLocal',FALSE],
				_trace getOrDefault ['createdAncestry',[]],
				_trace getOrDefault ['firedContext',[]],
				_trace getOrDefault ['firedAncestry',[]],
				_trace getOrDefault ['lastValid',[]],
				_trace getOrDefault ['firstInvalid',[]],
				_trace getOrDefault ['samples',[]],
				[_entity] call (serverNamespace getVariable 'QS_transformDiag_projectileAncestry'),
				[missileTarget _entity] call (serverNamespace getVariable 'QS_transformDiag_objectReference'),
				missileTargetPos _entity,
				getShotInfo _entity,
				_trace getOrDefault ['initializedSample',[]],
				_trace getOrDefault ['initializedAncestry',[]]
			];
		};
	};
	[_state,_emit]
}];

QS_transformDiag_entityCreatedEH = addMissionEventHandler [
	'EntityCreated',
	{
		params ['_entity'];
		if (
			!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) ||
			{isNull _entity}
		) exitWith {};
		private _queue = serverNamespace getVariable 'QS_transformDiag_createdQueue';
		if ((count _queue) < (missionNamespace getVariable ['QS_transformDiag_queueLimit',8192])) then {
			_queue pushBack _entity;
		} else {
			serverNamespace setVariable [
				'QS_transformDiag_queueDropped',
				(serverNamespace getVariable ['QS_transformDiag_queueDropped',0]) + 1
			];
		};
	}
];

QS_transformDiag_projectileCreatedEH = addMissionEventHandler [
	'ProjectileCreated',
	{
		params ['_projectile'];
		if (
			(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) &&
			{missionNamespace getVariable ['QS_transformDiag_bombTraceEnabled',FALSE]} &&
			{!isNull _projectile} &&
			{_projectile isKindOf 'BombCore'}
		) then {
			[_projectile,'ProjectileCreated'] call (missionNamespace getVariable 'QS_fnc_transformDiagRegisterBomb');
		};
	}
];

QS_transformDiag_entityKilledEH = addMissionEventHandler [
	'EntityKilled',
	{
		params ['_killed'];
		if (
			!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) ||
			{isNull _killed}
		) exitWith {};
		private _checkEntity = serverNamespace getVariable 'QS_transformDiag_checkEntity';
		[_killed,'killed'] call _checkEntity;
		private _related = [];
		private _killedVehicle = vehicle _killed;
		if (!isNull _killedVehicle && {_killedVehicle isNotEqualTo _killed}) then {_related pushBackUnique _killedVehicle;};
		private _attachedParent = attachedTo _killed;
		if (!isNull _attachedParent) then {_related pushBackUnique _attachedParent;};
		{_related pushBackUnique _x;} forEach (attachedObjects _killed);
		// Keep this unscheduled event handler bounded; the periodic scan covers any remainder.
		if ((count _related) > 16) then {_related resize 16;};
		{[_x,'killed-related'] call _checkEntity;} forEach _related;
	}
];

// Drain newly created entities outside the EntityCreated event handler.
[] spawn {
	while {TRUE} do {
		uiSleep 0.1;
		if (!(missionNamespace getVariable ['QS_transformDiag_enabled',FALSE])) then {
			serverNamespace setVariable ['QS_transformDiag_createdQueue',[]];
		} else {
			private _queue = serverNamespace getVariable 'QS_transformDiag_createdQueue';
			if (_queue isNotEqualTo []) then {
				private _batchSize = (missionNamespace getVariable ['QS_transformDiag_batchSize',100]) max 1;
				private _take = _batchSize min (count _queue);
				private _batch = _queue select [0,_take];
				_queue deleteRange [0,_take];
				private _perfBatch = ['transformDiag.createdBatch',count _batch] call QS_fnc_perfBegin;
				private _checkEntity = serverNamespace getVariable 'QS_transformDiag_checkEntity';
				{if (!isNull _x) then {[_x,'created'] call _checkEntity;};} forEach _batch;
				[_perfBatch,count _batch] call QS_fnc_perfEnd;
			};
		};
	};
};

// Periodically reconcile every currently present mission object in scheduled batches.
[] spawn {
	uiSleep 5;
	private _nextSummary = 0;
	while {TRUE} do {
		if (missionNamespace getVariable ['QS_transformDiag_enabled',FALSE]) then {
			private _scanStarted = diag_tickTime;
			private _censusStarted = diag_tickTime;
			private _perfCensus = ['transformDiag.allMissionObjects'] call QS_fnc_perfBegin;
			private _entities = allMissionObjects '';
			[_perfCensus,count _entities] call QS_fnc_perfEnd;
			private _censusMs = (diag_tickTime - _censusStarted) * 1000;
			private _batchSize = (missionNamespace getVariable ['QS_transformDiag_batchSize',100]) max 1;
			private _checkEntity = serverNamespace getVariable 'QS_transformDiag_checkEntity';
			private _corruptCount = 0;
			private _suspiciousCount = 0;
			private _emittedCount = 0;
			for '_offset' from 0 to ((count _entities) - 1) step _batchSize do {
				private _batch = _entities select [_offset,_batchSize];
				private _perfBatch = ['transformDiag.periodicBatch',count _batch] call QS_fnc_perfBegin;
				{
					if (!isNull _x) then {
						private _result = [_x,'periodic'] call _checkEntity;
						if ((_result # 0) isEqualTo 1) then {_corruptCount = _corruptCount + 1;};
						if ((_result # 0) isEqualTo 2) then {_suspiciousCount = _suspiciousCount + 1;};
						if (_result # 1) then {_emittedCount = _emittedCount + 1;};
					};
				} forEach _batch;
				[_perfBatch,count _batch] call QS_fnc_perfEnd;
				uiSleep 0.001;
			};

			private _cache = serverNamespace getVariable 'QS_transformDiag_cache';
			private _expireBefore = diag_tickTime - (missionNamespace getVariable ['QS_transformDiag_cacheExpireSeconds',600]);
			private _expiredKeys = [];
			{if ((_y # 2) < _expireBefore) then {_expiredKeys pushBack _x;};} forEach _cache;
			{_cache deleteAt _x;} forEach _expiredKeys;
			private _scanMs = (diag_tickTime - _scanStarted) * 1000;

			if (diag_tickTime >= _nextSummary) then {
				_nextSummary = diag_tickTime + 60;
				diag_log text format [
					'[QS XFORM] SUMMARY tick=%1 frame=%2 objects=%3 censusMs=%4 scanMs=%5 corrupt=%6 suspect=%7 emitted=%8 tracked=%9 createdQueue=%10 queueDropped=%11 cacheEvicted=%12 defend=%13 bombsSeen=%14 jetsRegistered=%15',
					diag_tickTime,
					diag_frameNo,
					count _entities,
					_censusMs toFixed 3,
					_scanMs toFixed 3,
					_corruptCount,
					_suspiciousCount,
					_emittedCount,
					count _cache,
					count (serverNamespace getVariable 'QS_transformDiag_createdQueue'),
					serverNamespace getVariable ['QS_transformDiag_queueDropped',0],
					serverNamespace getVariable ['QS_transformDiag_cacheEvicted',0],
					missionNamespace getVariable ['QS_defendActive',FALSE],
					serverNamespace getVariable ['QS_transformDiag_bombTraceCounter',0],
					serverNamespace getVariable ['QS_transformDiag_jetTraceCounter',0]
				];
			};
		};
		uiSleep ((missionNamespace getVariable ['QS_transformDiag_scanSeconds',10]) max 5);
	};
};

private _bombConfig = configFile >> 'CfgAmmo' >> 'Bomb_03_F';
diag_log text format [
	'[QS BOMB] CONFIG class="Bomb_03_F" sourceAddons=%1 simulation="%2" model="%3" proxyShape="%4" timeToLive=%5 simulationStep=%6 maxSpeed=%7 initTime=%8 thrust=%9 thrustTime=%10 airFriction=%11',
	configSourceAddonList _bombConfig,
	getText (_bombConfig >> 'simulation'),
	getText (_bombConfig >> 'model'),
	getText (_bombConfig >> 'proxyShape'),
	getNumber (_bombConfig >> 'timeToLive'),
	getNumber (_bombConfig >> 'simulationStep'),
	getNumber (_bombConfig >> 'maxSpeed'),
	getNumber (_bombConfig >> 'initTime'),
	getNumber (_bombConfig >> 'thrust'),
	getNumber (_bombConfig >> 'thrustTime'),
	getNumber (_bombConfig >> 'airFriction')
];
diag_log '[QS XFORM] INIT server-only corrupt-transform and bomb provenance diagnostics ready';
