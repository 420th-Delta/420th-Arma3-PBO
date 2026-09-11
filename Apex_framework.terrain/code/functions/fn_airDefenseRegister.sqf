/* Register mission-owned AA and combat jets; execution remains with the current AI owner. */
params [['_vehicle',objNull,[objNull]],['_register',TRUE,[TRUE]]];
if (!isServer || {isNull _vehicle}) exitWith {FALSE};
private _registry = missionNamespace getVariable ['QS_airDefense_vehicles',[]];
if (!_register) exitWith {
	_vehicle setVariable ['QS_airDefense_registered',FALSE,TRUE];
	missionNamespace setVariable ['QS_airDefense_vehicles',_registry - [_vehicle],TRUE];
	TRUE
};
private _role = '';
if (_vehicle isKindOf 'Plane') then {
	if (!unitIsUAV _vehicle) then {_role = 'jet';};
} else {
	if (_vehicle isKindOf 'O_SAM_System_04_F' || {_vehicle isKindOf 'B_SAM_System_03_F'}) then {
		_role = 'sam';
	} else {
		if ((['O_APC_Tracked_02_AA_F','O_T_APC_Tracked_02_AA_ghex_F','B_APC_Tracked_01_AA_F','I_LT_01_AA_F','StaticAAWeapon'] findIf {_vehicle isKindOf _x}) >= 0) then {
			_role = 'aa';
		};
	};
};
if (_role isEqualTo '' && {_vehicle isKindOf 'LandVehicle'}) then {
	if ((magazinesAllTurrets _vehicle findIf {
		private _ammo = configFile >> 'CfgAmmo' >> getText (configFile >> 'CfgMagazines' >> (_x # 0) >> 'ammo');
		(getNumber (_ammo >> 'airLock')) isEqualTo 2 && {(toLowerANSI getText (_ammo >> 'simulation')) isEqualTo 'shotmissile'} && {(getNumber (_ammo >> 'hit')) > 0}
	}) >= 0) then {_role = 'aa';};
};
if (_role isEqualTo '') exitWith {FALSE};
_vehicle setVariable ['QS_airDefense_role',_role,TRUE];
_vehicle setVariable ['QS_airDefense_registered',TRUE,TRUE];
if (!(_vehicle in _registry)) then {
	_registry pushBack _vehicle;
	missionNamespace setVariable ['QS_airDefense_vehicles',_registry,TRUE];
};
TRUE
