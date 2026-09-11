/*
Function: TGC_fnc_manageSideMissions

Description:
    Cycle or pause Side Missions from a validated staff request.
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
if (!(_action in ["CYCLE", "PAUSE", "AA_PAUSE", "AA_RESUME", "AA_ABORT"])) exitWith {};

if (_action in ['AA_PAUSE','AA_RESUME','AA_ABORT']) exitWith {
    switch _action do {
        case 'AA_PAUSE': {
            missionNamespace setVariable ['QS_priorityAA_paused',true,true];
            ['systemChat',format ['%1 (staff) paused Priority AA spawning. The current objective and pending request are retained.',name _requestingPlayer]] remoteExec ['QS_fnc_remoteExecCmd',-2,false];
        };
        case 'AA_RESUME': {
            missionNamespace setVariable ['QS_priorityAA_paused',false,true];
            ['systemChat',format ['%1 (staff) resumed Priority AA spawning.',name _requestingPlayer]] remoteExec ['QS_fnc_remoteExecCmd',-2,false];
        };
        case 'AA_ABORT': {
            if (!(missionNamespace getVariable ['QS_priorityAA_active',false]) && {!(missionNamespace getVariable ['QS_priorityAA_legacyActive',false])}) exitWith {
                ['systemChat','There is no active Priority AA mission.'] remoteExec ['QS_fnc_remoteExecCmd',_owner,false];
            };
            if (missionNamespace getVariable ['QS_priorityAA_legacyActive',false]) then {
                missionNamespace setVariable ['QS_smAbort',true,true];
            } else {
                missionNamespace setVariable ['QS_priorityAA_abort',true,false];
            };
            ['systemChat',format ['%1 (staff) ended the current Priority AA mission.',name _requestingPlayer]] remoteExec ['QS_fnc_remoteExecCmd',-2,false];
        };
    };
};

if ((missionNamespace getVariable ["QS_missionConfig_sideMissions", 1]) isNotEqualTo 1) exitWith {
    ["systemChat", "Side Missions are disabled by the server configuration."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
};

switch _action do {
    case "CYCLE": {
        if (missionNamespace getVariable ["QS_smStaffPaused", false]) exitWith {
            ["systemChat", "Side Mission spawning is paused."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
        };
        if (!(missionNamespace getVariable ["QS_sideMissionActive", false])) exitWith {
            ["systemChat", "There is no active Side Mission to cycle."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
        };

        missionNamespace setVariable ["QS_smAbort", true, true];
        ["systemChat", format ["%1 (staff) cycled the Side Mission", name _requestingPlayer]] remoteExec ["QS_fnc_remoteExecCmd", -2, false];
    };
    case "PAUSE": {
        if (missionNamespace getVariable ["QS_smStaffPaused", false]) exitWith {
            ["systemChat", "Side Mission spawning is already paused."] remoteExec ["QS_fnc_remoteExecCmd", _owner, false];
        };

        missionNamespace setVariable ["QS_smSuspend", true, true];
        missionNamespace setVariable ["QS_smStaffPaused", true, false];
        missionNamespace setVariable ["QS_forcedSideMission", "", false];
        missionNamespace setVariable ["QS_forceSideMission", false, false];
        if (missionNamespace getVariable ["QS_sideMissionActive", false]) then {
            missionNamespace setVariable ["QS_smAbort", true, true];
        };
        ["systemChat", format ["%1 (staff) paused Side Mission spawning", name _requestingPlayer]] remoteExec ["QS_fnc_remoteExecCmd", -2, false];
    };
};
