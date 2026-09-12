/*
Isolated native sender survey: no Cronus, reveal, injected contacts or scripted
projectiles. Each sender gets a new real flying WEST target and EAST Rhea.
Current mission crew sides/explicit electronics hooks are reproduced after
logging native defaults. Optional second phases deliberately enable send/radar
and EAST crew to distinguish configuration capacity from current mission policy.
Aircraft senders remain simulated but are repositioned relative to the moving
target to control sensor coverage; this does not test their flight AI.
Negative contact/launch results are observations, not universal incapability.
*/
private _oldRegistry = +(missionNamespace getVariable ['QS_airDefense_vehicles',[]]);
private _oldEnabled = missionNamespace getVariable ['QS_missionConfig_airDefense_enabled',TRUE];
private _oldViewDistance = viewDistance;
private _oldDate = date;
private _friendships = [EAST getFriend WEST,WEST getFriend EAST,RESISTANCE getFriend WEST,WEST getFriend RESISTANCE,EAST getFriend RESISTANCE,RESISTANCE getFriend EAST];
QS_missionConfig_airDefense_enabled = TRUE;
EAST setFriend [WEST,0]; WEST setFriend [EAST,0];
RESISTANCE setFriend [WEST,0]; WEST setFriend [RESISTANCE,0];
EAST setFriend [RESISTANCE,1]; RESISTANCE setFriend [EAST,1];
setViewDistance 7000;
setDate [2035,6,24,12,0];
T420_AA_datalinkShots = [];
T420_AA_datalinkProjectiles = [];
private _results = [];
// label, class, current mission crew side (-1 means native), explicit sensor hooks
private _cases = [
	['tigris_current','O_APC_Tracked_02_AA_F',0,FALSE],
	['nyx_recon_regenerator','I_LT_01_scout_F',0,TRUE],
	['nyx_aa_initial_ao_east','I_LT_01_AA_F',0,FALSE],
	['nyx_aa_reinforcement_native','I_LT_01_AA_F',-1,FALSE],
	['shikra_classic_cas','O_Plane_Fighter_02_F',0,FALSE],
	['neophron_classic_cas','O_Plane_CAS_02_dynamicLoadout_F',0,FALSE],
	['gryphon_classic_cas_east','I_Plane_Fighter_04_F',0,FALSE],
	['buzzard_classic_cas_east','I_Plane_Fighter_03_dynamicLoadout_F',0,FALSE],
	['uav_ababil_defend','O_UAV_02_dynamicLoadout_F',-1,TRUE],
	['uav_greyhawk_defend_native','I_UAV_02_dynamicLoadout_F',-1,TRUE],
	['uav_sentinel_defend','O_T_UAV_04_CAS_F',-1,TRUE],
	['kajman_classic_escort','O_Heli_Attack_02_dynamicLoadout_F',0,FALSE]
];
private _sourceFilter = missionNamespace getVariable ['T420_AA_datalinkSourceFilter',[]];
if (_sourceFilter isNotEqualTo []) then {_cases = _cases select {(_x # 0) in _sourceFilter}};
private _targetClass = missionNamespace getVariable ['T420_AA_datalinkTargetClass','B_Plane_CAS_01_F'];
private _targetRadar = missionNamespace getVariable ['T420_AA_datalinkTargetRadar',2];
private _senderAhead = missionNamespace getVariable ['T420_AA_datalinkSenderAhead',FALSE];
diag_log format ['T420_AA_DATALINK_TARGET|class=%1|radarMode=%2|senderAhead=%3',_targetClass,_targetRadar,_senderAhead];
{
	private _cfg = configFile >> 'CfgVehicles' >> _x;
	[isClass _cfg,'datalink.config_only_class/' + _x] call T420_AA_fnc_assert;
	private _sensors = (configProperties [_cfg >> 'Components' >> 'SensorsManagerComponent' >> 'Components','isClass _x',TRUE]) apply {
		[configName _x,getText (_x >> 'componentType'),getNumber (_x >> 'AirTarget' >> 'maxRange'),getNumber (_x >> 'maxTrackableSpeed'),getNumber (_x >> 'angleRangeHorizontal'),getText (_x >> 'animDirection')]
	};
	diag_log format ['T420_AA_DATALINK_CONFIG_ONLY|class=%1|side=%2|sendReceiveOwn=%3|sensors=%4',_x,getNumber (_cfg >> 'side'),[getNumber (_cfg >> 'reportRemoteTargets'),getNumber (_cfg >> 'receiveRemoteTargets'),getNumber (_cfg >> 'reportOwnPosition')],_sensors];
} forEach (missionNamespace getVariable ['T420_AA_datalinkConfigOnly',[]]);
{
	_x params ['_label','_class','_missionSide','_explicitHooks'];
	[isClass (configFile >> 'CfgVehicles' >> _class),'datalink.class/' + _label,_class] call T420_AA_fnc_assert;
	[(vehicles findIf {(typeOf _x) isEqualTo 'O_Radar_System_02_F'}) isEqualTo -1,'datalink.no_cronus/' + _label] call T420_AA_fnc_assert;
	private _samPosition = [20000,20000,0];
	private _empty = _samPosition findEmptyPosition [0,100,'O_SAM_System_04_F'];
	if (_empty isNotEqualTo []) then {_samPosition = _empty};
	private _sourcePosition = _samPosition getPos [80,270];
	_empty = _sourcePosition findEmptyPosition [0,100,_class];
	if (_empty isNotEqualTo []) then {_sourcePosition = _empty};
	private _isAir = _class isKindOf 'Air';
	if (_isAir) then {_sourcePosition set [2,650]};
	diag_log format ['T420_AA_DATALINK_CREATE_BEGIN|%1',_class];
	private _source = createVehicle [_class,_sourcePosition,[],0,['NONE','FLY'] select _isAir];
	diag_log format ['T420_AA_DATALINK_CREATE_END|%1',_class];
	private _sourceGroup = createVehicleCrew _source;
	private _nativeGroup = _sourceGroup;
	private _cfg = configFile >> 'CfgVehicles' >> _class;
	private _sensorCfg = _cfg >> 'Components' >> 'SensorsManagerComponent' >> 'Components';
	private _sensorSummary = (listVehicleSensors _source) apply {
		private _sensor = _sensorCfg >> (_x # 0);
		[_x # 0,_x # 1,getNumber (_sensor >> 'AirTarget' >> 'maxRange'),getNumber (_sensor >> 'angleRangeHorizontal'),getNumber (_sensor >> 'angleRangeVertical'),getText (_sensor >> 'animDirection'),getNumber (_sensor >> 'minSpeedThreshold'),getNumber (_sensor >> 'maxTrackableSpeed'),getNumber (_sensor >> 'maxTrackableATL'),getNumber (_sensor >> 'maxTrackableASL')]
	};
	private _native = [side group effectiveCommander _source,vehicleReportRemoteTargets _source,vehicleReceiveRemoteTargets _source,vehicleReportOwnPosition _source,isVehicleRadarOn _source];
	diag_log format ['T420_AA_DATALINK_CONFIG|case=%1|class=%2|native=%3|cfgSendReceiveOwn=%4|sensors=%5',_label,_class,_native,[getNumber (_cfg >> 'reportRemoteTargets'),getNumber (_cfg >> 'receiveRemoteTargets'),getNumber (_cfg >> 'reportOwnPosition')],_sensorSummary];
	private _owned = [_source,_sourceGroup] + crew _source;
	if (_missionSide isEqualTo 0 && {side _sourceGroup isNotEqualTo EAST}) then {
		_sourceGroup = createGroup [EAST,TRUE];
		(crew _source) joinSilent _sourceGroup;
		_owned pushBack _sourceGroup;
	};
	if (_explicitHooks) then {
		_source setVehicleReportRemoteTargets TRUE;
		_source setVehicleReceiveRemoteTargets TRUE;
		_source setVehicleRadar 1;
	};
	private _sam = createVehicle ['O_SAM_System_04_F',_samPosition,[],0,'NONE'];
	private _samGroup = createVehicleCrew _sam;
	private _orbitCenter = _samPosition getPos [2300,90];
	private _targetPosition = _orbitCenter getPos [1000,90];
	_targetPosition set [2,500];
	private _jet = createVehicle [_targetClass,_targetPosition,[],0,'FLY'];
	private _jetGroup = createVehicleCrew _jet;
	_owned append ([_sam,_jet,_samGroup,_jetGroup] + crew _sam + crew _jet);
	{
		_x allowDamage FALSE;
		_x enableDynamicSimulation FALSE;
	} forEach [_source,_sam,_jet];
	{
		_x allowDamage FALSE;
		_x setSkill 1;
	} forEach (crew _source + crew _sam + crew _jet);
	_sourceGroup setBehaviourStrong 'AWARE';
	_sourceGroup setCombatMode 'BLUE';
	_source setVehicleAmmo 0;
	_source setDir 90;
	_source engineOn TRUE;
	if (_label isEqualTo 'nyx_recon_regenerator') then {
		deleteVehicle driver _source;
		_source engineOn FALSE;
	};
	_samGroup setBehaviourStrong 'AWARE';
	_samGroup setCombatMode 'RED';
	_sam setDir 90;
	_sam setVehicleRadar 1;
	_sam setVehicleReceiveRemoteTargets TRUE;
	_sam setVehicleAmmo 1;
	_jet setVehicleRadar _targetRadar;
	_jet setVehicleAmmo 0;
	_jet engineOn TRUE;
	{
		_x disableAI 'TARGET';
		_x disableAI 'AUTOTARGET';
		_x disableAI 'AUTOCOMBAT';
	} forEach crew _jet;
	_jetGroup setBehaviourStrong 'CARELESS';
	_jetGroup setCombatMode 'BLUE';
	_jet setPosATL _targetPosition;
	_jet setVectorDirAndUp [[0,1,0],[0,0,1]];
	_jet setVelocity [0,150,0];
	_jet flyInHeight 500;
	(driver _jet) forceSpeed 150;
	private _orbit = _jetGroup addWaypoint [_orbitCenter,0];
	_orbit setWaypointType 'LOITER';
	_orbit setWaypointLoiterRadius 1000;
	_orbit setWaypointLoiterType 'CIRCLE_L';
	private _shotEH = _sam addEventHandler ['Fired',{
		params ['_vehicle','_weapon','','','_ammo','','_projectile'];
		private _index = T420_AA_datalinkShots pushBack [diag_tickTime,_ammo,_weapon,missileTarget _projectile,_vehicle getVariable ['QS_airDefense_target',objNull]];
		T420_AA_datalinkProjectiles pushBack _projectile;
		[_projectile,_index] spawn {
			params ['_projectile','_index'];
			uiSleep 0.05;
			if (!isNull _projectile) then {
				(T420_AA_datalinkShots # _index) set [3,missileTarget _projectile];
				deleteVehicle _projectile;
			};
		};
	}];
	[_sam] call QS_fnc_airDefenseRegister;
	private _currentSucceeded = FALSE;
	for '_phase' from 0 to 1 do {
		if (_phase isEqualTo 0 || {!_currentSucceeded}) then {
			private _phaseLabel = ['current_mission','diagnostic_send_radar_east_aimed'] select _phase;
			if (_phase isEqualTo 1) then {
				_source setVehicleReportRemoteTargets TRUE;
				_source setVehicleRadar 1;
				if (side _sourceGroup isNotEqualTo EAST) then {
					_sourceGroup = createGroup [EAST,TRUE];
					(crew _source) joinSilent _sourceGroup;
					_owned pushBack _sourceGroup;
					_sourceGroup setBehaviourStrong 'AWARE';
					_sourceGroup setCombatMode 'BLUE';
				};
			};
			T420_AA_datalinkShots = [];
			private _sourceSawJet = FALSE;
			private _samSawDataLink = FALSE;
			private _selectedJet = FALSE;
			private _samples = [];
			private _began = diag_tickTime;
			private _deadline = _began + 25;
			private _tick = 0;
			waitUntil {
				if (_phase isEqualTo 1) then {
					// Camera direction only: target still must enter the native sensor suite.
					(gunner _source) doWatch (getPosATL _jet);
					(gunner _source) doTarget _jet;
				};
				if (_isAir) then {
					// Controlled airborne sensor geometry, retaining live simulation.
					private _direction = getDir _jet;
					private _controlledPosition = _jet getPos [1400,_direction + ([180,0] select _senderAhead)];
					_controlledPosition set [2,((getPosATL _jet) # 2) + 100];
					_source setPosATL _controlledPosition;
					_source setDir (_direction + ([0,180] select _senderAhead));
					_source setVectorUp [0,0,1];
					_source setVelocity ((vectorDir _source) vectorMultiply (vectorMagnitude velocity _jet));
				};
				if (_phase isEqualTo 1 && {hasPilotCamera _source}) then {
					_source setPilotCameraTarget (getPosASL _jet);
				};
				if (_phase isEqualTo 1 && {!isNull gunner _source}) then {
					private _turret = _source unitTurret gunner _source;
					if (_turret isNotEqualTo [] && {_turret isNotEqualTo [-1]}) then {
						_source lockCameraTo [getPosASL _jet,_turret,FALSE];
					};
				};
				private _sourceContacts = getSensorTargets _source;
				private _samContacts = getSensorTargets _sam;
				_sourceSawJet = _sourceSawJet || {(_sourceContacts findIf {(_x # 0) isEqualTo _jet && {((_x # 3) - ['datalink']) isNotEqualTo []}}) >= 0};
				_samSawDataLink = _samSawDataLink || {(_samContacts findIf {(_x # 0) isEqualTo _jet && {'datalink' in (_x # 3)}}) >= 0};
				private _selection = [_sam] call QS_fnc_airDefenseSelectTarget;
				_selectedJet = _selectedJet || {(_selection # 0) isEqualTo _jet};
				[_sam] call QS_fnc_airDefenseApply;
				if ((_tick mod 5) isEqualTo 0) then {
					_samples pushBack [diag_tickTime - _began,_sourceContacts,_samContacts,_selection,getPosATL _jet,getPosATL _source,isVehicleRadarOn _source,getPilotCameraTarget _source,getPilotCameraDirection _source,getSensorThreats _source,isVehicleRadarOn _jet];
				};
				_tick = _tick + 1;
				uiSleep 1;
				((T420_AA_datalinkShots findIf {(_x # 4) isEqualTo _jet}) >= 0) || {diag_tickTime >= _deadline}
			};
			uiSleep 0.1;
			private _fired = (T420_AA_datalinkShots findIf {(_x # 4) isEqualTo _jet && {(toLowerANSI getText (configFile >> 'CfgAmmo' >> (_x # 1) >> 'simulation')) isEqualTo 'shotmissile'}}) >= 0;
			private _runtime = [side group effectiveCommander _source,vehicleReportRemoteTargets _source,vehicleReceiveRemoteTargets _source,isVehicleRadarOn _source];
			private _result = [_label,_phaseLabel,_runtime,_sourceSawJet,_samSawDataLink,_selectedJet,_fired,diag_tickTime - _began,+T420_AA_datalinkShots];
			_results pushBack _result;
			diag_log format ['T420_AA_DATALINK_RESULT|%1',_result];
			diag_log format ['T420_AA_DATALINK_SAMPLES|case=%1|phase=%2|samples=%3',_label,_phaseLabel,_samples];
			[!_fired || {_sourceSawJet && {_samSawDataLink} && {_selectedJet}},'datalink.launch_has_native_sender_and_link/' + _label + '/' + _phaseLabel,_result] call T420_AA_fnc_assert;
			if (_phase isEqualTo 0) then {_currentSucceeded = _fired};
		};
	};
	[_sam] call QS_fnc_airDefenseRelease;
	[_sam,FALSE] call QS_fnc_airDefenseRegister;
	_sam removeEventHandler ['Fired',_shotEH];
	_sam setVehicleAmmo 0;
	[_owned + T420_AA_datalinkProjectiles] call T420_AA_fnc_cleanup;
	T420_AA_datalinkProjectiles = [];
} forEach _cases;
[(count _results) >= count _cases,'datalink.every_sender_surveyed',_results] call T420_AA_fnc_assert;
if (missionNamespace getVariable ['T420_AA_datalinkRequireCurrentLaunch',TRUE]) then {
	[(_results findIf {(_x # 1) isEqualTo 'current_mission' && {_x # 6}}) >= 0,'datalink.at_least_one_current_non_cronus_sender_launches',_results] call T420_AA_fnc_assert;
};
diag_log format ['T420_AA_DATALINK_SUMMARY|%1',_results];
QS_airDefense_vehicles = _oldRegistry;
QS_missionConfig_airDefense_enabled = _oldEnabled;
EAST setFriend [WEST,_friendships # 0]; WEST setFriend [EAST,_friendships # 1];
RESISTANCE setFriend [WEST,_friendships # 2]; WEST setFriend [RESISTANCE,_friendships # 3];
EAST setFriend [RESISTANCE,_friendships # 4]; RESISTANCE setFriend [EAST,_friendships # 5];
setViewDistance _oldViewDistance;
setDate _oldDate;
TRUE
