/* Optional candidate records [object,isCurrentSensorContact] support deterministic engine fixtures. */
params [['_vehicle',objNull,[objNull]],['_candidates',[],[[]]],['_useCandidates',FALSE,[TRUE]]];
private _none = [objNull,5,'',[],FALSE];
if (isNull _vehicle || {!alive _vehicle}) exitWith {_none};
private _operator = if (_vehicle isKindOf 'Plane') then {currentPilot _vehicle} else {gunner _vehicle};
if (isNull _operator) then {_operator = effectiveCommander _vehicle;};
if (isNull _operator) exitWith {_none};
private _base = markerPos 'QS_marker_base_marker';
if (_base isEqualTo [0,0,0]) exitWith {[objNull,5,'',[],TRUE]};
private _radius = (missionNamespace getVariable ['QS_missionConfig_airDefense_baseExclusionRadius',2000]) max 0;
private _role = _vehicle getVariable ['QS_airDefense_role','aa'];
if (!_useCandidates) then {
	_candidates = (getSensorTargets _vehicle) apply {[_x # 0,TRUE]};
	if (_role isNotEqualTo 'sam') then {
		{
			private _known = _x;
			if ((_candidates findIf {(_x # 0) isEqualTo _known}) < 0) then {
				private _knowledge = _operator targetKnowledge _known;
				if ((_knowledge # 0) && {(time - (_knowledge # 2)) <= 30}) then {_candidates pushBack [_known,FALSE];};
			};
		} forEach (_operator targets [TRUE,16000,[WEST],0]);
	};
};
private _weapons = [];
private _magazines = magazinesAllTurrets _vehicle;
{
	_x params ['_magazine','_turret','_rounds'];
	if (_rounds > 0) then {
		private _ammo = configFile >> 'CfgAmmo' >> getText (configFile >> 'CfgMagazines' >> _magazine >> 'ammo');
		private _simulation = toLowerANSI getText (_ammo >> 'simulation');
		if (_simulation in ['shotmissile','shotrocket','shotshell','shotbullet']) then {
			private _air = (_simulation isNotEqualTo 'shotmissile') || {(getNumber (_ammo >> 'airLock')) > 0};
			private _ground = (getNumber (_ammo >> 'airLock')) isNotEqualTo 2;
			if (_role isEqualTo 'sam') then {_ground = FALSE;};
			{
				private _weapon = _x;
				private _config = configFile >> 'CfgWeapons' >> _weapon;
				if (_magazine in (compatibleMagazines _weapon)) then {
					private _maxRange = getNumber (_config >> 'maxRange');
					private _minRange = if (_maxRange > 0) then {getNumber (_config >> 'minRange')} else {1e10};
					{
						private _mode = _config >> _x;
						private _modeRange = getNumber (_mode >> 'maxRange');
						if (_modeRange > 0) then {
							_maxRange = _maxRange max _modeRange;
							_minRange = _minRange min getNumber (_mode >> 'minRange');
						};
					} forEach getArray (_config >> 'modes');
					if (_minRange isEqualTo 1e10) then {_minRange = 0;};
					if (_simulation isEqualTo 'shotmissile') then {_minRange = _minRange max getNumber (_config >> 'missileLockMinDistance');};
					_maxRange = _maxRange max getNumber (_config >> 'missileLockMaxDistance');
					if (_maxRange <= 0) then {_maxRange = [2500,8000] select (_simulation isEqualTo 'shotmissile');};
					_weapons pushBackUnique [_weapon,_turret,_minRange,_maxRange,_air,_ground];
				};
			} forEach (_vehicle weaponsTurret _turret);
		};
	};
} forEach _magazines;
private _selected = objNull;
private _rank = 5;
private _distance = 1e10;
private _weapon = '';
private _turret = [];
private _protected = FALSE;
private _prior = _vehicle getVariable ['QS_airDefense_target',objNull];
{
	_x params ['_contact','_sensor'];
	private _target = vehicle _contact;
	if (alive _target && {side effectiveCommander _target isEqualTo WEST} && {((crew _target) findIf {alive _x}) >= 0}) then {
		if ((_target distance2D _base) <= _radius) then {
			_protected = TRUE;
		} else {
			private _targetRank = [_target] call QS_fnc_airDefenseClassifyTarget;
			private _targetDistance = _vehicle distance _target;
			private _airborne = (_target isKindOf 'Air') && {!isTouchingGround _target} && {((getPosATL _target) # 2) > 5};
			if (_targetRank < 4 && {!_airborne}) then {_targetRank = 4;};
			private _capability = _weapons findIf {
				(_targetDistance >= (_x # 2)) && {_targetDistance <= (_x # 3)} && {if (_airborne) then {_x # 4} else {_x # 5}}
			};
			if (_targetRank < 5 && {_capability >= 0} && {(_role isNotEqualTo 'sam') || {_sensor && {_airborne}}}) then {
				private _scoreDistance = _targetDistance * ([1,0.8] select (_target isEqualTo _prior));
				if (_targetRank < _rank || {_targetRank isEqualTo _rank && {_scoreDistance < _distance}}) then {
					_selected = _target;
					_rank = _targetRank;
					_distance = _scoreDistance;
					_weapon = (_weapons # _capability) # 0;
					_turret = (_weapons # _capability) # 1;
				};
			};
		};
	};
} forEach _candidates;
[_selected,_rank,_weapon,_turret,_protected]
