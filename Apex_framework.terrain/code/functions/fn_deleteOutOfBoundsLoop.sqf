// fn_deleteOutOfBoundsLoop.sqf
// (spawn on server in scheduled environment)

if (!isServer) exitWith {};
if !(isNil "QS_deleteOutOfBoundsLoopStarted") exitWith {};

QS_deleteOutOfBoundsLoopStarted = true;

// f16 probably means half-precision which has a range of +/- 65504
private _minXY = -6000;
private _maxXY = worldSize - _minXY;
private _minZ = -10;
private _maxZ = 20000;

while {true} do {
    sleep (30 + random 10);
    // ~0.7287ms for 945 entities
    private _perfCensus = ['outOfBounds.allMissionObjects'] call QS_fnc_perfBegin;
    private _props = allMissionObjects "";
    [_perfCensus,count _props] call QS_fnc_perfEnd;
    private _perfFilter = ['outOfBounds.filter',count _props] call QS_fnc_perfBegin;
    diag_log text format ["%1: scanning %2 props", _fnc_scriptName, count _props];

    _props = _props apply {[_x, getPosWorld _x]} select {
        _x params ["_object", "_position"];
        isNull (attachedTo _object) && {
            (_position # 0 < _minXY)
            || (_position # 1 < _minXY)
            || (_position # 2 < _minZ)
            || (_position # 0 > _maxXY)
            || (_position # 1 > _maxXY)
            || (_position # 2 > _maxZ)
        }
    } apply {_x # 0};
    [_perfFilter,count _props] call QS_fnc_perfEnd;
    if (_props isEqualTo []) then {continue};

    // Recheck immediately before deletion in case an object was attached after the scan.
    _props = _props select {isNull (attachedTo _x)};
    if (_props isEqualTo []) then {continue};

    diag_log text format ["%1: detected %2 props out of bounds", _fnc_scriptName, count _props];
    {diag_log text format ["%1: %2 '%3' %4", _fnc_scriptName, getPosWorld _x, typeOf _x, velocity _x]} forEach _props;

    private _perfDelete = ['outOfBounds.deleteVehicle',count _props] call QS_fnc_perfBegin;
    deleteVehicle _props;
    [_perfDelete,-1] call QS_fnc_perfEnd;
    // If any props still remain, try killing them instead
    private _perfKill = ['outOfBounds.setDamageBatch',count _props] call QS_fnc_perfBegin;
    {_x setDamage [1, false]} forEach _props;
    [_perfKill,-1] call QS_fnc_perfEnd;
};
