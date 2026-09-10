// Synthetic-fixture endpoint only; never register this in the product mission.
params [['_mode',''],['_unit',objNull],['_sequence',0]];
if (!isServer || {!isRemoteExecuted} || {isRemoteExecutedJIP} ||
    {isNull _unit} || {!isPlayer _unit} || {owner _unit isNotEqualTo remoteExecutedOwner}) exitWith {};
if ((_mode find 'ART_') isEqualTo 0) exitWith {
    // Queue trusted fixture lifecycle commands for the independently started
    // server script; production correctly rejects lifecycle calls in RPC scope.
    private _queue = serverNamespace getVariable ['IA_support_artilleryQueue',[]];
    _queue pushBack [_mode,_unit,_sequence];
    serverNamespace setVariable ['IA_support_artilleryQueue',_queue];
};
if (_mode isEqualTo 'SETUP') then {
    _unit setVariable ['QS_unit_role','mortar_gunner',TRUE];
    _unit setVariable ['QS_unit_side',WEST,TRUE];
    missionNamespace setVariable ['QS_unit_roles',[[],[[['mortar_gunner'],[[getPlayerUID _unit]]]],[],[]]];
    missionNamespace setVariable ['QS_robocop',createHashMap];
    ['fixture_support_setup',[local _unit,owner _unit isNotEqualTo 2]] call IA_fnc_log;
};
if (_mode isEqualTo 'CAPTURE_TUBE') then {_unit setVariable ['IA_support_capturedTube',backpackContainer _unit];};
if (_mode isEqualTo 'DEBIT_CAPTURED_TUBE') then {
    ['DEBIT',_unit,_unit getVariable ['IA_support_capturedTube',objNull]] remoteExecCall ['QS_fnc_mortarSupport',_unit,FALSE];
};
if (_mode isEqualTo 'SLOW_TICK') then {
    serverNamespace setVariable ['IA_support_mortarTickInterval',3];
    serverNamespace setVariable ['IA_support_mortarTickAfter',diag_tickTime + 3];
    ['support_core_cadence_seconds',3] call IA_fnc_log;
};
private _row = ((serverNamespace getVariable ['QS_mortarSupport_state',createHashMap]) getOrDefault ['rows',createHashMap]) getOrDefault [getPlayerUID _unit,createHashMap];
if (_mode isEqualTo 'EXPIRE' && {count _row > 0}) then {
    {if (_x # 2) then {_x set [3,diag_tickTime - 1];};} forEach (_row get 'mortars');
};
private _entries = (_row getOrDefault ['mortars',[]]) apply {
    private _mortar = _x # 0;
    private _rounds = 0;
    {_rounds = _rounds + (_x # 2);} forEach (magazinesAllTurrets [_mortar,TRUE]);
    [_mortar,_x # 1,_x # 2,_x # 4,_x # 6,_x # 7,_rounds,_x # 8,owner _mortar,_mortar turretOwner [0]]
};
private _snapshotNow = diag_tickTime;
private _cooldownRemaining = (+(_row getOrDefault ['cooldowns',[0,0]])) apply {(_x - _snapshotNow) max 0};
_unit setVariable ['IA_support_snapshot',[_sequence,_entries,backpack _unit,backpackContainer _unit,
	[stance _unit,lifeState _unit,str side group _unit,_unit getVariable ['QS_unit_role',''],
		surfaceIsWater getPosATL _unit,_unit getVariable ['QS_client_remoteControlling',FALSE],
		(allUnits findIf {(_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull]) isEqualTo _unit}) >= 0],
	_unit getVariable ['IA_support_capturedTube',objNull],_cooldownRemaining],owner _unit];
