/* Returns whether a CfgVehicles class is supported by the Spawn Menu. */
params [
	['_vehicleClass','',['']],
	['_allowNonPublic',FALSE,[FALSE]]
];

if (_vehicleClass isEqualTo '') exitWith {FALSE};

private _config = configFile >> 'CfgVehicles' >> _vehicleClass;
private _scope = getNumber (_config >> 'scope');
if (
	!isClass _config ||
	{(!_allowNonPublic) && {_scope isNotEqualTo 2}}
) exitWith {FALSE};

private _isGround = _vehicleClass isKindOf 'LandVehicle';
private _isBoat = _vehicleClass isKindOf 'Ship';
private _isHelicopter = _vehicleClass isKindOf 'Helicopter';
private _isPlane = _vehicleClass isKindOf 'Plane';
private _isAI = _vehicleClass isKindOf 'CAManBase';
private _isSupplyCrate = (
	(_vehicleClass isKindOf 'ReammoBox_F') ||
	{(toLowerANSI _vehicleClass) in (['loadable_cargo_objects_1'] call QS_data_listVehicles)}
);
private _isLogisticsContainer = (
	(['Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F'] findIf {
		_vehicleClass isKindOf _x
	}) isNotEqualTo -1
);

_isGround || _isBoat || _isHelicopter || _isPlane || _isAI || _isSupplyCrate || _isLogisticsContainer
