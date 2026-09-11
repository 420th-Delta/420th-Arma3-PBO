/* Restore only features changed by this controller, including after crew/control changes. */
params [['_vehicle',objNull,[objNull]]];
if (isNull _vehicle) exitWith {};
private _saved = _vehicle getVariable ['QS_airDefense_savedCrew',[]];
{
	_x params ['_unit','_target','_autoTarget','_combat'];
	if (!isNull _unit && {alive _unit}) then {
		if (local _unit) then {
			_unit enableAIFeature ['TARGET',_target];
			_unit enableAIFeature ['AUTOTARGET',_autoTarget];
			_unit setUnitCombatMode _combat;
			if (!isPlayer _unit && {isNull remoteControlled _unit}) then {_unit doTarget objNull;};
			private _ack = [_vehicle,clientOwner,_target,_autoTarget,_combat];
			if (_ack isNotEqualTo (_unit getVariable ['QS_airDefense_releaseAck',[]])) then {_unit setVariable ['QS_airDefense_releaseAck',_ack,TRUE];};
		};
	};
} forEach _saved;
// Only the hull owner retires shared records. A split AI transfer retains every
// original until the whole crew arrives; otherwise a late owner could save BLUE
// or receive a stale array from the previous owner after the originals were lost.
if (local _vehicle) then {
	private _human = ((crew _vehicle) findIf {alive _x && {isPlayer _x || {!isNull remoteControlled _x}}}) >= 0;
	if (!isNil 'TGC_fnc_isPlayerControlled') then {_human = _human || {[_vehicle] call TGC_fnc_isPlayerControlled};};
	private _crewStable = _human || {((crew _vehicle) findIf {alive _x && {!local _x || {!local group _x}}}) < 0};
	if (_crewStable) then {
		private _remaining = _saved select {
			_x params ['_unit','_target','_autoTarget','_combat'];
			private _owner = if (local _unit) then {clientOwner} else {if (isServer) then {owner _unit} else {_unit getVariable ['QS_airDefense_ownerId',-1]}};
			!isNull _unit && {alive _unit} && {[_vehicle,_owner,_target,_autoTarget,_combat] isNotEqualTo (_unit getVariable ['QS_airDefense_releaseAck',[]])}
		};
		if (_remaining isNotEqualTo _saved) then {_vehicle setVariable ['QS_airDefense_savedCrew',_remaining,TRUE];};
	};
};
if (local _vehicle && {(_saved isNotEqualTo []) || {!isNull (_vehicle getVariable ['QS_airDefense_target',objNull])} || {_vehicle getVariable ['QS_airDefense_holding',FALSE]}}) then {
	_vehicle setVariable ['QS_airDefense_target',objNull,TRUE];
	_vehicle setVariable ['QS_airDefense_rank',5,TRUE];
	_vehicle setVariable ['QS_airDefense_holding',FALSE,TRUE];
};
_vehicle setVariable ['QS_airDefense_localCrew',[],FALSE];
