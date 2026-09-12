/* Last-moment veto; only the just-created projectile is affected. */
params ['_vehicle','','','','_ammo','','_projectile',['_gunner',objNull]];
if (isNull _projectile || {!local _projectile} || {!(_vehicle getVariable ['QS_airDefense_registered',FALSE])}) exitWith {};
if (!(missionNamespace getVariable ['QS_missionConfig_airDefense_enabled',TRUE])) exitWith {};
if (!isNil 'TGC_fnc_isPlayerControlled' && {[_vehicle] call TGC_fnc_isPlayerControlled}) exitWith {};
if (isNull _gunner) then {_gunner = effectiveCommander _vehicle;};
if (isNull _gunner || {isPlayer _gunner} || {!isNull remoteControlled _gunner} || {!((side group _gunner) in [EAST,RESISTANCE])} || {((side group _gunner) getFriend WEST) >= 0.6}) exitWith {};
private _simulation = toLowerANSI getText (configFile >> 'CfgAmmo' >> _ammo >> 'simulation');
if (!(_simulation in ['shotmissile','shotrocket','shotshell','shotbullet'])) exitWith {};
private _target = missileTarget _projectile;
if (isNull _target) then {_target = getAttackTarget _gunner;};
if (isNull _target) then {_target = assignedTarget _gunner;};
private _base = markerPos 'QS_marker_base_marker';
private _radius = (missionNamespace getVariable ['QS_missionConfig_airDefense_baseExclusionRadius',2000]) max 0;
private _veto = (_base isEqualTo [0,0,0]) || {_vehicle getVariable ['QS_airDefense_holding',FALSE]};
if (!isNull _target) then {
	_veto = _veto || {(_target distance2D _base) <= _radius};
	private _priority = _vehicle getVariable ['QS_airDefense_target',objNull];
	if (alive _priority && {_priority isNotEqualTo _target}) then {
		private _rank = [_target] call QS_fnc_airDefenseClassifyTarget;
		if (_rank < 4 && {isTouchingGround _target || {((getPosATL _target) # 2) <= 5}}) then {_rank = 4;};
		_veto = _veto || {_rank > (_vehicle getVariable ['QS_airDefense_rank',5])};
	};
};
if (_veto) then {
	deleteVehicle _projectile;
	_vehicle setVariable ['QS_airDefense_vetoCount',1 + (_vehicle getVariable ['QS_airDefense_vetoCount',0]),FALSE];
};
