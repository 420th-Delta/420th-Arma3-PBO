/*
Function: TGC_fnc_manageMainAO

Description:
    Cycle or pause the Main AO from a validated staff request.
*/
params [["_action", "", [""]]];
if (!isServer) exitWith {};

private _owner = remoteExecutedOwner;
private _requestingPlayer = objNull;
{
    if ((owner _x) isEqualTo _owner) exitWith {
        _requestingPlayer = _x;
    };
} forEach allPlayers;

if ((isNull _requestingPlayer) || {!((getPlayerUID _requestingPlayer) in (["ALL"] call QS_fnc_whitelist))}) exitWith {};
if (!(_action in ["CYCLE", "PAUSE"])) exitWith {};

if (!((missionNamespace getVariable ["QS_missionConfig_aoType", "ZEUS"]) in ["CLASSIC", "SC", "GRID"])) exitWith {
    ["systemChat", "Main AOs are disabled by the server configuration."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
};
if (missionNamespace getVariable ["QS_customAO_active", false]) exitWith {
    ["systemChat", "The Main AO cannot be managed while a custom AO is active."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
};

switch _action do {
    case "CYCLE": {
        if (missionNamespace getVariable ["QS_aoSuspended", false]) exitWith {
            ["systemChat", "Main AO spawning is paused."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
        };

        missionNamespace setVariable ["QS_aoCycleVar", true, true];
        ["systemChat", format ["%1 (staff) cycled the Main AO", name _requestingPlayer]] remoteExec ["QS_fnc_remoteExecCmd", -2, false];
    };
    case "PAUSE": {
        if (missionNamespace getVariable ["QS_aoSuspended", false]) exitWith {
            ["systemChat", "Main AO spawning is already paused."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
        };

        missionNamespace setVariable ["QS_aoSuspended", true, true];
        missionNamespace setVariable ["QS_aoCycleVar", true, true];
        missionNamespace setVariable ["QS_forceDefend", -1, true];
        ["systemChat", format ["%1 (staff) paused Main AO spawning", name _requestingPlayer]] remoteExec ["QS_fnc_remoteExecCmd", -2, false];
    };
};
