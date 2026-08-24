// fn_deleteOutOfBoundsLoop.sqf
// (spawn on server in scheduled environment)

if (!isServer) exitWith {};
if !(isNil "QS_deleteOutOfBoundsLoopStarted") exitWith {};

QS_deleteOutOfBoundsLoopStarted = true;

// f16 probably means half-precision which has a range of +/- 65504
private _minXY = -10000;
private _maxXY = worldSize - _minXY;
private _minZ = -1000;
private _maxZ = 50000;

while {true} do {
    sleep (25 + random 10);
    // ~0.7287ms for 945 entities
    private _props = entities "";
    diag_log text format ["%1: scanning %2 props", _fnc_scriptName, count _props];

    _props = _props apply {[_x, getPosWorld _x]} select {
        _x # 1 # 0 < _minXY
        || {_x # 1 # 1 < _minXY
        || {_x # 1 # 2 < _minZ
        || {_x # 1 # 0 > _maxXY
        || {_x # 1 # 1 > _maxXY
        || {_x # 1 # 2 > _maxZ}}}}}
    } apply {_x # 0};
    if (_props isEqualTo []) then {continue};

    diag_log text format ["%1: detected %2 props out of bounds", _fnc_scriptName, count _props];
    {diag_log text format ["%1: %2 '%3' %4", _fnc_scriptName, getPosWorld _x, typeOf _x, velocity _x]} forEach _props;

    deleteVehicle _props;
    // If any props still remain, try killing them instead
    {_x setDamage [1, false]} forEach _props;
};