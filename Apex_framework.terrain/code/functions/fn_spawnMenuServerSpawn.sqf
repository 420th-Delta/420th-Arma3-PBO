/*
	Server-authoritative Spawn Menu request handler.
	Revalidates the caller, role, vehicle class, spawn point, cooldown, and
	clearance before creating a global vehicle.
*/
if (!isServer) exitWith {};

params [
	['_unit',objNull,[objNull]],
	['_vehicleClass','',['']],
	['_terminal',objNull,[objNull]],
	['_spawnPoint',objNull,[objNull]]
];

private _notify = {
	params ['_unit','_message'];
	['systemChat',_message] remoteExec ['QS_fnc_remoteExecCmd',_unit,FALSE];
};

private _hint = {
	params ['_unit','_message'];
	[_message] remoteExecCall ['QS_fnc_hint',_unit,FALSE];
};

if (
	isNull _unit ||
	{!isPlayer _unit} ||
	{!alive _unit} ||
	{(owner _unit) isNotEqualTo remoteExecutedOwner}
) exitWith {};

if (
	isNull _terminal ||
	{!(_terminal getVariable ['QS_spawnMenu_terminal',FALSE])} ||
	{(_unit distance _terminal) > 8}
) exitWith {
	[_unit,'Spawn Menu: invalid terminal or you moved too far away.'] call _notify;
};

if (
	isNull _spawnPoint ||
	{!(_spawnPoint getVariable ['QS_spawnMenu_spawnPoint',FALSE])}
) exitWith {
	[_unit,'Spawn Menu: invalid spawn point.'] call _notify;
};

private _terminalID = toLowerANSI (_terminal getVariable ['QS_spawnMenu_id','']);
private _spawnPointID = toLowerANSI (_spawnPoint getVariable ['QS_spawnMenu_id','']);
if (
	(_terminalID isNotEqualTo '') &&
	{_spawnPointID isNotEqualTo _terminalID}
) exitWith {
	[_unit,'Spawn Menu: the terminal and spawn point IDs do not match.'] call _notify;
};

private _allowedRoles = _terminal getVariable ['QS_spawnMenu_allowedRoles',[]];
if (_allowedRoles isEqualType '') then {
	_allowedRoles = [_allowedRoles];
};
if !(_allowedRoles isEqualType []) exitWith {
	[_unit,'Spawn Menu: the terminal role configuration is invalid.'] call _notify;
};
if ((_allowedRoles findIf {!(_x isEqualType '')}) isNotEqualTo -1) exitWith {
	[_unit,'Spawn Menu: the terminal role list must contain role ID strings.'] call _notify;
};
private _unitRole = toLowerANSI (_unit getVariable ['QS_unit_role','rifleman']);
if (
	(_unitRole isNotEqualTo 'staff') &&
	(_allowedRoles isNotEqualTo []) &&
	{!(_unitRole in (_allowedRoles apply {toLowerANSI _x}))}
) exitWith {
	[_unit,'Spawn Menu: your current role cannot use this terminal.'] call _notify;
};

private _hasVehicleWhitelist = !isNil {_terminal getVariable 'QS_spawnMenu_vehicleClasses'};
private _vehicleWhitelist = _terminal getVariable ['QS_spawnMenu_vehicleClasses',[]];
if (
	_hasVehicleWhitelist &&
	{!(_vehicleWhitelist isEqualType [])}
) exitWith {
	[_unit,'Spawn Menu: the terminal vehicle-list configuration is invalid.'] call _notify;
};
if (
	_hasVehicleWhitelist &&
	{(_vehicleWhitelist findIf {!(_x isEqualType '')}) isNotEqualTo -1}
) exitWith {
	[_unit,'Spawn Menu: the terminal vehicle list must contain class ID strings.'] call _notify;
};
if (
	_hasVehicleWhitelist &&
	{!((toLowerANSI _vehicleClass) in (_vehicleWhitelist apply {toLowerANSI _x}))}
) exitWith {
	[_unit,'Spawn Menu: that vehicle is not offered by this terminal.'] call _notify;
};

private _isExplicitlyWhitelisted = _hasVehicleWhitelist && {
	(toLowerANSI _vehicleClass) in (_vehicleWhitelist apply {toLowerANSI _x})
};
if (!([_vehicleClass,_isExplicitlyWhitelisted] call QS_fnc_spawnMenuVehicleAllowed)) exitWith {
	[_unit,'Spawn Menu: that class is not supported.'] call _notify;
};

private _isAI = _vehicleClass isKindOf 'CAManBase';
if (
	_isAI &&
	{(leader (group _unit)) isNotEqualTo _unit}
) exitWith {
	[_unit,'You must be a Group Leader to recruit AI'] call _hint;
};
if (
	_isAI &&
	{({!isPlayer _x} count (units (group _unit))) >= 10}
) exitWith {
	[_unit,'You cannot recruit more than 10 AI'] call _hint;
};

private _isVehicle = (
	(['LandVehicle','Air','Ship'] findIf {_vehicleClass isKindOf _x}) isNotEqualTo -1
);
private _vehicleLimit = 5;
private _unitUID = getPlayerUID _unit;
private _spawnedVehicleCount = if (_isVehicle) then {
	{
		private _spawnedEntity = _x;
		alive _spawnedEntity &&
		{(_spawnedEntity getVariable ['QS_spawnMenu_spawnedBy','']) isEqualTo _unitUID} &&
		{(['LandVehicle','Air','Ship'] findIf {_spawnedEntity isKindOf _x}) isNotEqualTo -1}
	} count (missionNamespace getVariable ['QS_spawnMenu_spawnedEntities',[]])
} else {
	0
};
if (_spawnedVehicleCount >= _vehicleLimit) exitWith {
	[
		_unit,
		format [
			'Spawn Menu: you already have %1 active vehicles. Respawn or destroy one before spawning another.',
			_vehicleLimit
		]
	] call _notify;
};

private _nextSpawn = _unit getVariable ['QS_spawnMenu_nextSpawn',0];
if (serverTime < _nextSpawn) exitWith {
	[_unit,format ['Spawn Menu: wait %1 seconds before spawning another item.',ceil (_nextSpawn - serverTime)]] call _notify;
};

private _isSupplyCrate = (
	(_vehicleClass isKindOf 'ReammoBox_F') ||
	{(toLowerANSI _vehicleClass) in (['loadable_cargo_objects_1'] call QS_data_listVehicles)}
);
private _isLogisticsContainer = (
	(['Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F'] findIf {
		_vehicleClass isKindOf _x
	}) isNotEqualTo -1
);
private _isSupplyCategory = _isSupplyCrate || {_isLogisticsContainer};
private _hasDragCarryOverride = _isSupplyCrate || {
	(toLowerANSI _vehicleClass) in [
		'land_cargo10_military_green_f',
		'land_cargo10_grey_f',
		'land_cargo10_light_green_f',
		'land_cargo10_white_f',
		'land_cargo10_sand_f',
		'land_cargo10_yellow_f',
		'land_cargo10_blue_f',
		'land_cargo10_cyan_f',
		'land_cargo20_light_blue_f',
		'land_cargo20_cyan_f',
		'land_cargo20_blue_f'
	]
};
private _isBoat = _vehicleClass isKindOf 'Ship';
private _position = getPosATL _spawnPoint;
private _positionASL = getPosASL _spawnPoint;
private _supplyPositionBlocked = FALSE;
if (_isSupplyCategory) then {
	private _emptyPosition = _position findEmptyPosition [0,6,_vehicleClass];
	if (_emptyPosition isEqualTo []) then {
		_supplyPositionBlocked = TRUE;
	} else {
		_position = _emptyPosition;
	};
};
if (_supplyPositionBlocked) exitWith {
	[_unit,'No suitable spawn position is available within 6 meters.'] call _hint;
};
private _clearance = if (_isAI) then {
	[['CAManBase','ReammoBox_F','Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F','LandVehicle','Air','Ship'],0]
} else {
	if (_isSupplyCategory) then {
		[['ReammoBox_F','Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F','CAManBase','LandVehicle','Air','Ship'],0]
	} else {
		[['LandVehicle','Air','Ship','CAManBase','ReammoBox_F','Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F'],5]
	}
};
private _blockingObjects = if ((_clearance # 1) <= 0) then {
	[]
} else {
	nearestObjects [_position,(_clearance # 0),(_clearance # 1),TRUE] select {
		alive _x && {!(_x isEqualTo _spawnPoint)}
	}
};
if (_blockingObjects isNotEqualTo []) exitWith {
	[_unit,'Spawn Menu: the spawn area is blocked.'] call _notify;
};

_unit setVariable ['QS_spawnMenu_nextSpawn',serverTime + 10,FALSE];

private _entity = objNull;
private _spawnGroup = grpNull;
private _destinationGroup = grpNull;
private _destinationOwner = 2;
if (_isAI) then {
	_destinationGroup = group _unit;
	_destinationOwner = owner _unit;
	if (_destinationOwner <= 0) then {
		_destinationOwner = groupOwner _destinationGroup;
	};
	_spawnGroup = createGroup [side _destinationGroup,TRUE];
	if (!isNull _spawnGroup) then {
		_spawnGroup deleteGroupWhenEmpty TRUE;
		_entity = _spawnGroup createUnit [_vehicleClass,_position,[],0,'CAN_COLLIDE'];
	};
} else {
	_entity = createVehicle [_vehicleClass,_position,[],0,'CAN_COLLIDE'];
};

if (isNull _entity) exitWith {
	if (!isNull _spawnGroup) then {
		deleteGroup _spawnGroup;
	};
	[_unit,'Spawn Menu: the selected entity could not be created.'] call _notify;
};

_entity setVectorDirAndUp [vectorDir _spawnPoint,vectorUp _spawnPoint];
if (_isBoat) then {
	_entity setPosASL _positionASL;
} else {
	_entity setPosATL _position;
};
_entity setVariable ['QS_spawnMenu_spawnedBy',getPlayerUID _unit,TRUE];
(missionNamespace getVariable ['QS_spawnMenu_spawnedEntities',[]]) pushBackUnique _entity;
if (_isVehicle) then {
	[_entity,_unitUID,side (group _unit)] call QS_fnc_spawnMenuManagedVehicleInit;
};

if (_isAI) then {
	_entity setVariable ['QS_RD_dismissable',TRUE,TRUE];
	_entity setVariable ['QS_spawnMenu_aiPendingJoin',TRUE,TRUE];
	if (_destinationOwner > 2) then {
		// Man units inherit locality from their group. Transfer the temporary
		// group instead of calling setOwner on the unit.
		_spawnGroup setGroupOwner _destinationOwner;
	};
	if (_destinationOwner isEqualTo 2) then {
		[_entity,_unit,_destinationGroup] call QS_fnc_spawnMenuJoinAI;
	} else {
		[_entity,_unit,_destinationGroup] remoteExecCall ['QS_fnc_spawnMenuJoinAI',_destinationOwner,FALSE];
	};
} else {
	_entity setVariable ['QS_RD_vehicleRespawnable',TRUE,TRUE];
	_entity setVariable ['TGC_vehicle_side',side (group _unit),TRUE];
};

if (!_isAI && {!_isSupplyCrate} && {!isNil 'QS_fnc_vSetup'}) then {
	[_entity] call QS_fnc_vSetup;
};
if ((typeOf _entity) isEqualTo 'B_Heli_Light_01_F') then {
	_entity addWeaponTurret ['CMFlareLauncher',[-1]];
	_entity addMagazineTurret ['300Rnd_CMFlare_Chaff_Magazine',[-1]];
};
if (
	_isLogisticsContainer &&
	{!(_entity getVariable ['QS_logistics',FALSE])} &&
	{!isNil 'QS_fnc_vSetupContainer'}
) then {
	[_entity] call QS_fnc_vSetupContainer;
};
if (_hasDragCarryOverride) then {
	{
		_entity setVariable _x;
	} forEach [
		['QS_spawnMenu_dragCarryOverride',TRUE,TRUE],
		['QS_logistics',TRUE,TRUE],
		['QS_RD_draggable',TRUE,TRUE],
		['QS_logistics_draggable',TRUE,TRUE],
		['QS_logistics_dragDisabled',FALSE,TRUE],
		['QS_logistics_immovable',FALSE,TRUE]
	];
};

if (_vehicleClass isEqualTo 'O_Heli_Light_02_dynamicLoadout_F') then {
	{
		_entity setObjectTextureGlobal [_forEachIndex,_x];
	} forEach [
		'a3\air_f_heli\heli_light_02\data\heli_light_02_ext_opfor_v2_co.paa',
		'a3\air_f_heli\heli_light_02\data\rockets_co.paa'
	];
};

if (_vehicleClass isEqualTo 'O_Heli_Transport_04_F') then {
	{
		_entity setObjectTextureGlobal [_forEachIndex,_x];
	} forEach [
		'A3\Air_F_Heli\Heli_Transport_04\Data\heli_transport_04_base_01_Black_co.paa',
		'A3\Air_F_Heli\Heli_Transport_04\Data\heli_transport_04_base_02_Black_co.paa'
	];
};

if (_vehicleClass isEqualTo 'O_Heli_Attack_02_dynamicLoadout_F') then {
	{
		_entity setObjectTextureGlobal [_forEachIndex,_x];
	} forEach [
		'A3\Air_F_Beta\Heli_Attack_02\Data\Heli_Attack_02_body1_black_CO.paa',
		'A3\Air_F_Beta\Heli_Attack_02\Data\Heli_Attack_02_body2_black_CO.paa'
	];
};

private _podTextures = switch (_vehicleClass) do {
	case 'Land_Pod_Heli_Transport_04_ammo_F';
	case 'Land_Pod_Heli_Transport_04_box_F';
	case 'Land_Pod_Heli_Transport_04_repair_F';
	case 'Land_Pod_Heli_Transport_04_covered_F': {
		[
			'A3\Air_F_Heli\Heli_Transport_04\Data\Heli_Transport_04_Pod_Ext01_Black_CO.paa',
			'A3\Air_F_Heli\Heli_Transport_04\Data\Heli_Transport_04_Pod_Ext02_Black_CO.paa'
		]
	};
	case 'Land_Pod_Heli_Transport_04_fuel_F': {
		['A3\Air_F_Heli\Heli_Transport_04\Data\Heli_Transport_04_fuel_black_CO.paa']
	};
	case 'Land_Pod_Heli_Transport_04_bench_F': {
		['A3\Air_F_Heli\Heli_Transport_04\Data\Heli_Transport_04_bench_Black_CO.paa']
	};
	default {[]};
};
{
	_entity setObjectTextureGlobal [_forEachIndex,_x];
} forEach _podTextures;

if (_vehicleClass in ['O_T_VTOL_02_infantry_dynamicLoadout_F','O_T_VTOL_02_vehicle_dynamicLoadout_F']) then {
	{
		_entity setObjectTextureGlobal [_forEachIndex,_x];
	} forEach [
		'a3\air_f_exp\vtol_02\data\vtol_02_ext01_co.paa',
		'a3\air_f_exp\vtol_02\data\vtol_02_ext02_co.paa',
		'a3\air_f_exp\vtol_02\data\vtol_02_ext03_l_co.paa',
		'a3\air_f_exp\vtol_02\data\vtol_02_ext03_r_co.paa'
	];
};

if (_isVehicle) then {
	if (isNil {serverNamespace getVariable 'QS_v_Monitor'}) then {
		serverNamespace setVariable ['QS_v_Monitor',[]];
	};
	private _managedSpawnPosition = ASLToAGL (getPosASL _entity);
	(serverNamespace getVariable 'QS_v_Monitor') pushBack [
		_entity,
		30,
		FALSE,
		{},
		_vehicleClass,
		_managedSpawnPosition,
		[vectorDir _entity,vectorUp _entity],
		FALSE,
		0,
		-1,
		50,
		2000,
		-1,
		4,
		FALSE,
		0,
		{TRUE},
		FALSE,
		FALSE,
		[],
		[],
		0,
		{TRUE},
		_unitUID,
		side (group _unit)
	];
};

private _displayName = getText (configFile >> 'CfgVehicles' >> _vehicleClass >> 'displayName');
[_unit,format ['Spawn Menu: %1 spawned at grid %2.',_displayName,mapGridPosition _spawnPoint]] call _notify;
