// Compile the production dispatcher and rappel implementation on every role.
// The focused mission supplies only the one attachment dependency used by the
// local descent helper; helicopters do not invoke the land/ship COM callback.
QS_fnc_updateCenterOfMass = {TRUE};
QS_fnc_eventAttach = compileFinal preprocessFileLineNumbers 'production\code\functions\fn_eventAttach.sqf';
QS_fnc_remoteExec = compileFinal preprocessFileLineNumbers 'production\code\functions\fn_remoteExec.sqf';
missionNamespace setVariable ['QS_headlessClients',[],FALSE];
private _rappelSource = preprocessFileLineNumbers 'production\code\scripts\AR_AdvancedRappelling_ext.sqf';
if (isServer) then {
    // Final code cannot be overwritten. Rename only the entry's definition in
    // this fixture, preserving its complete production body for the delegate.
    private _entry = 'AR_Enable_Rappelling_Animation = compileFinal ';
    private _at = _rappelSource find _entry;
    private _unique = _at >= 0 && {((_rappelSource select [_at + count _entry]) find _entry) < 0};
    ['rappel.animationInstrumentationExactMatch',_unique] call IA_fnc_assert;
    if (_unique) then {
        _rappelSource = (_rappelSource select [0,_at]) +
            'IA_fnc_rappelProductionAnimation = compileFinal ' +
            (_rappelSource select [_at + count _entry]);
    };
    serverNamespace setVariable ['IA_rappel_animationInstrumented',_unique];
    serverNamespace setVariable ['IA_rappel_animationCalls',0];
};
call compile _rappelSource;
if (isServer && {serverNamespace getVariable ['IA_rappel_animationInstrumented',FALSE]}) then {
    AR_Enable_Rappelling_Animation = compileFinal {
        isNil {
            serverNamespace setVariable ['IA_rappel_animationCalls',
                (serverNamespace getVariable ['IA_rappel_animationCalls',0]) + 1];
        };
        _this call IA_fnc_rappelProductionAnimation
    };
};
missionNamespace setVariable ['AP_CUSTOM_RAPPEL_POINTS',[
    ['B_Heli_Light_01_F',[[0,-1,-1]]]
],FALSE];
