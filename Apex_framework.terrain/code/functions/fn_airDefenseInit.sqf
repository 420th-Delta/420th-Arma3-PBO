// Called after the external server parameters, also safe to call after a config edit.
if (!isServer) exitWith {};
{
    _x params ['_name','_default',['_minimum',0],['_maximum',0]];
    private _value = missionNamespace getVariable [_name,_default];
    if !(_value isEqualType _default) then {_value = _default;};
    if (_default isEqualType 0) then {
        if !(finite _value) then {_value = _default;};
        _value = (_value max _minimum) min _maximum;
    };
    if (_default isEqualType []) then {
        if ((count _value) isNotEqualTo 2 || {(_value findIf {!(_x isEqualType 0) || {!(finite _x)}}) isNotEqualTo -1}) then {
            _value = +_default;
        };
        _value = _value apply {(_x max _minimum) min _maximum};
        _value sort TRUE;
    };
    if (_name in ['QS_missionConfig_priorityAA_satelliteCount','QS_missionConfig_priorityAA_minPlayers']) then {_value = floor _value;};
    missionNamespace setVariable [_name,_value,TRUE];
} forEach (call compile preprocessFileLineNumbers 'code\config\airDefense.sqf');
