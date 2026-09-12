/* One scheduled owner tick. Never run commands against a player-controlled crew. */
params [['_vehicle',objNull,[objNull]]];
if (isNull _vehicle || {!local _vehicle}) exitWith {};
private _crew = (crew _vehicle) select {alive _x};
private _human = (_crew findIf {isPlayer _x || {!isNull remoteControlled _x}}) >= 0;
if (!isNil 'TGC_fnc_isPlayerControlled') then {_human = _human || {[_vehicle] call TGC_fnc_isPlayerControlled};};
private _enemy = (_crew isNotEqualTo []) && {((side group (_crew # 0)) in [EAST,RESISTANCE])} && {((side group (_crew # 0)) getFriend WEST) < 0.6};
if (!alive _vehicle || {_human} || {!_enemy} || {!(_vehicle getVariable ['QS_airDefense_registered',FALSE])} || {!(missionNamespace getVariable ['QS_missionConfig_airDefense_enabled',TRUE])}) exitWith {
	[_vehicle] call QS_fnc_airDefenseRelease;
};
private _localCrew = _crew select {local _x};
if (_localCrew isEqualTo []) exitWith {};
if (isNil {_vehicle getVariable 'QS_airDefense_firedEH'}) then {
	_vehicle setVariable ['QS_airDefense_firedEH',_vehicle addEventHandler ['Fired',{_this call QS_fnc_airDefenseFired;}],FALSE];
};
// Hull, driver and turret groups can arrive on different frames during a handoff.
// Keep the existing snapshot until every AI operator has finished moving here.
if ((_crew findIf {!local _x || {!local group _x}}) >= 0) exitWith {};
private _oldCrew = _vehicle getVariable ['QS_airDefense_localCrew',[]];
if (_oldCrew isNotEqualTo [] && {_oldCrew isNotEqualTo _localCrew}) then {[_vehicle] call QS_fnc_airDefenseRelease;};
private _selection = [_vehicle] call QS_fnc_airDefenseSelectTarget;
_selection params ['_target','_rank','_weapon','_turret','_protected'];
private _base = markerPos 'QS_marker_base_marker';
private _radius = (missionNamespace getVariable ['QS_missionConfig_airDefense_baseExclusionRadius',2000]) max 0;
{
	private _actual = getAttackTarget _x;
	private _assigned = assignedTarget _x;
	if ((!isNull _actual && {(_actual distance2D _base) <= _radius}) || {!isNull _assigned && {(_assigned distance2D _base) <= _radius}}) then {_protected = TRUE;};
} forEach _localCrew;
private _hold = isNull _target && {_protected};
if (isNull _target && {!_hold}) exitWith {[_vehicle] call QS_fnc_airDefenseRelease;};
private _saved = +(_vehicle getVariable ['QS_airDefense_savedCrew',[]]);
{
	private _unit = _x;
	if ((_saved findIf {(_x # 0) isEqualTo _unit}) < 0) then {
		_saved pushBack [_unit,_unit checkAIFeature 'TARGET',_unit checkAIFeature 'AUTOTARGET',unitCombatMode _unit];
	};
} forEach _localCrew;
if (_saved isNotEqualTo (_vehicle getVariable ['QS_airDefense_savedCrew',[]])) then {_vehicle setVariable ['QS_airDefense_savedCrew',_saved,TRUE];};
_vehicle setVariable ['QS_airDefense_localCrew',_localCrew,FALSE];
private _changed = (_target isNotEqualTo (_vehicle getVariable ['QS_airDefense_target',objNull])) || {_rank isNotEqualTo (_vehicle getVariable ['QS_airDefense_rank',5])} || {_hold isNotEqualTo (_vehicle getVariable ['QS_airDefense_holding',FALSE])};
if (_changed) then {
	_vehicle setVariable ['QS_airDefense_target',_target,TRUE];
	_vehicle setVariable ['QS_airDefense_rank',_rank,TRUE];
	_vehicle setVariable ['QS_airDefense_holding',_hold,TRUE];
};
if (_vehicle isKindOf 'Plane') then {
	if (_rank < 4 || {_hold}) then {_vehicle setVariable ['QS_airDefense_abortCAS',TRUE,FALSE];};
};
{
	private _unit = _x;
	if (!isNil {_unit getVariable 'QS_airDefense_releaseAck'}) then {_unit setVariable ['QS_airDefense_releaseAck',nil,TRUE];};
	_unit enableAIFeature ['AUTOTARGET',FALSE];
	if (_hold) then {
		_unit enableAIFeature ['TARGET',FALSE];
		_unit setUnitCombatMode 'BLUE';
		_unit doTarget objNull;
	} else {
		private _state = _saved # (_saved findIf {(_x # 0) isEqualTo _unit});
		_unit enableAIFeature ['TARGET',_state # 1];
		_unit setUnitCombatMode (['YELLOW','RED'] select (_vehicle isKindOf 'Plane'));
		_unit doTarget _target;
	};
} forEach _localCrew;
if (!_hold) then {
	private _operator = if (_turret isEqualTo [-1]) then {driver _vehicle} else {_vehicle turretUnit _turret};
	if (!isNull _operator && {local _operator}) then {
		_operator doTarget _target;
		_operator doFire _target;
	};
};
