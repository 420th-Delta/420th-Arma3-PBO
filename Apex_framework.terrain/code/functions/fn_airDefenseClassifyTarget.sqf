/* 1 jets, 2 attack helicopters, 3 transports (including door guns), 4 surface vehicles, 5 vanilla. */
params [['_target',objNull,[objNull]]];
if (isNull _target) exitWith {5};
private _vehicle = vehicle _target;
private _config = configOf _vehicle;
if (_vehicle isKindOf 'Plane') exitWith {
	private _jetTypes = if (isNil 'QS_data_listVehicles' || {isNil 'QS_hashmap_classLists'}) then {[]} else {['cas_plane'] call QS_data_listVehicles};
	if ((toLowerANSI typeOf _vehicle) in _jetTypes || {((getNumber (_config >> 'vtol')) isEqualTo 0) && {(getNumber (_config >> 'maxSpeed')) >= 500}}) then {1} else {5}
};
if (_vehicle isKindOf 'Helicopter') exitWith {
	private _attack = (['Heli_Attack_01_base_F','Heli_Attack_02_base_F'] findIf {_vehicle isKindOf _x}) >= 0;
	if (!_attack) then {
		_attack = ((getPylonMagazines _vehicle) findIf {
			private _ammo = configFile >> 'CfgAmmo' >> getText (configFile >> 'CfgMagazines' >> _x >> 'ammo');
			(toLowerANSI getText (_ammo >> 'simulation')) in ['shotmissile','shotrocket','shotshell','shotbullet','shotbomb']
		}) >= 0;
	};
	if (!_attack) then {
		_attack = ((magazinesAllTurrets _vehicle) findIf {
			private _ammo = configFile >> 'CfgAmmo' >> getText (configFile >> 'CfgMagazines' >> (_x # 0) >> 'ammo');
			((_x # 1) isEqualTo [-1]) && {(toLowerANSI getText (_ammo >> 'simulation')) in ['shotmissile','shotrocket','shotshell','shotbullet']}
		}) >= 0;
	};
	if (_attack) then {2} else {3}
};
if (_vehicle isKindOf 'LandVehicle' || {_vehicle isKindOf 'Ship'}) exitWith {4};
5
