// Added Code
/*
File: IA_MegaDefense.sqf
Server-local request control for the native 30-minute Defense option.
*/
params [['_operation','START',['']]];
if (!isServer) exitWith {
	diag_log '[Mega Defense] REJECTED: server execution required.';
	['REJECTED',FALSE,[]]
};
private _result = [];
isNil {
	private _pending = missionNamespace getVariable ['QS_megaDefense_pending',FALSE];
	private _state = missionNamespace getVariable ['QS_megaDefense_state',[]];
	private _core = missionNamespace getVariable ['QS_megaDefense_core',[]];
	private _status = 'REJECTED';
	private _reason = '';
	private _validState = _state isEqualType [] && {count _state isEqualTo 5} && {(_state # 0) in ['RUNNING','CLOSING']} && {(_state # 1) isEqualType 0} && {(_state # 2) isEqualType 0} && {(_state # 3) isEqualType TRUE} && {(_state # 4) isEqualType TRUE};
	private _validCore = _core isEqualType [] && {count _core isEqualTo 3} && {(_core # 0) in ['PRIMARY','TRANSITION','DEFENSE','IDLE']} && {(_core # 1) isEqualType 0} && {(_core # 2) isEqualType []};
	switch (toUpper _operation) do {
		case 'STATUS': {
			_status = if (_validState) then {_state # 0} else {if (_validCore && {(_core # 0) isEqualTo 'TRANSITION'}) then {'TRANSITION'} else {'IDLE'}};
			if (_pending && {_status isNotEqualTo 'TRANSITION'}) then {_status = 'FORCE_REQUESTED';};
		};
		case 'CANCEL': {
			if (!_pending) exitWith {_status = 'NOT_PENDING';};
			if (_validCore && {(_core # 0) isEqualTo 'TRANSITION' || {(_core # 0) isEqualTo 'DEFENSE' && {!_validState}}}) exitWith {_status = 'IN_PROGRESS'; _reason = 'Defense handoff already committed';};
			_status = 'CANCELLED';
			missionNamespace setVariable ['QS_megaDefense_pending',FALSE,FALSE];
		};
		case 'START': {
			if (isNil 'QS_fnc_aoDefend' || {isNil 'QS_forceDefend'} || {isNil 'QS_defendActive'} || {isNil 'QS_mission_aoType'}) exitWith {_reason = 'mission not initialized';};
			if ((missionNamespace getVariable 'QS_mission_aoType') isNotEqualTo 'CLASSIC') exitWith {_reason = 'CLASSIC mode required';};
			if (_pending) exitWith {_status = 'ALREADY_REQUESTED';};
			if (_validState && {(_state # 0) isEqualTo 'CLOSING'}) exitWith {_reason = 'Defense is closing';};
			if (missionNamespace getVariable 'QS_defendActive') then {
				if (!_validState) exitWith {_reason = 'Defense timing is unavailable';};
				if ((serverTime >= (_state # 2)) || {missionNamespace getVariable ['QS_defend_terminate',FALSE]}) exitWith {_reason = 'Defense is ending';};
				if (_state # 3) exitWith {_status = 'ALREADY_ACTIVE';};
				_status = 'FORCE_REQUESTED';
			} else {
				if (!_validCore || {(_core # 0) isNotEqualTo 'PRIMARY'}) exitWith {_reason = 'current Primary HQ is not ready for Defense';};
				private _hq = missionNamespace getVariable ['QS_HQpos',[]];
				private _validHQ = {
					params ['_position'];
					_position isEqualType [] && {count _position >= 2} && {(_position # 0) isEqualType 0} && {(_position # 1) isEqualType 0} && {_position distance2D [0,0,0] > 100}
				};
				if (!([_hq] call _validHQ) || {!([_core # 2] call _validHQ)} || {_hq distance2D (_core # 2) > 1}) exitWith {_reason = 'current HQ does not match the prepared Primary';};
				missionNamespace setVariable ['QS_megaDefense_targetEpoch',_core # 1,FALSE];
				_status = 'FORCE_REQUESTED';
			};
			if (_status isEqualTo 'FORCE_REQUESTED') then {missionNamespace setVariable ['QS_megaDefense_pending',TRUE,FALSE];};
		};
		default {_reason = 'unknown operation';};
	};
	_result = [_status,missionNamespace getVariable ['QS_megaDefense_pending',FALSE],if (_state isEqualType []) then {+_state} else {[]}];
	diag_log format ['[Mega Defense] %1: %2; pending=%3; state=%4; core=%5',_status,_reason,_result # 1,_state,_core];
};
_result
// End Updated Code
