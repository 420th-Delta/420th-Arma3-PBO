/*
Function: TGC_fnc_forceSideMission

Description:
    Queue a specific side mission from the staff menu.
*/
params [["_sideMission","",[""]]];
if (!isServer) exitWith {};

private _owner = remoteExecutedOwner;
private _requestingPlayer = objNull;
{
    if ((owner _x) isEqualTo _owner) exitWith {
        _requestingPlayer = _x;
    };
} forEach allPlayers;

if ((isNull _requestingPlayer) || {!((getPlayerUID _requestingPlayer) in (['ALL'] call QS_fnc_whitelist))}) exitWith {};

private _missions = missionNamespace getVariable ["QS_sideMission_staffForceList",[
    ["Rescue POW","QS_fnc_SMRescuePOW"],
    ["Secure Urban Site","QS_fnc_SMsecureUrban"],
    ["Escort Vehicle","QS_fnc_SMEscortVehicle"],
    ["Priority AA","QS_fnc_SMPriorityAA"],
    ["Priority Artillery","QS_fnc_SMPriorityARTY"],
    ["Secure Intel UAV","QS_fnc_SMsecureIntelUAV"],
    ["Secure Intel Unit","QS_fnc_SMsecureIntelUnit"],
    ["Secure Intel Vehicle","QS_fnc_SMsecureIntelVehicle"],
    ["IDAP Recovery","QS_fnc_SMidapRecover"],
    ["Regenerator","QS_fnc_SMregenerator"],
    ["Secure Radar","QS_fnc_SMsecureRadar"]
]];
private _missionIndex = _missions findIf {(_x # 1) isEqualTo _sideMission};
if (_missionIndex isEqualTo -1) exitWith {};

if (_sideMission isEqualTo 'QS_fnc_SMPriorityAA') exitWith {
    if !(missionNamespace getVariable ['QS_missionConfig_priorityAA_enabled',true]) exitWith {
        ['systemChat','Priority AA is disabled by the server configuration.'] remoteExec ['QS_fnc_remoteExecCmd',_owner,false];
    };
    private _enhanced = [] call QS_fnc_airDefenseUseEnhanced;
    if (!_enhanced && {(missionNamespace getVariable ['QS_missionConfig_sideMissions',1]) isNotEqualTo 1}) exitWith {
        ['systemChat','The current population uses ordinary Priority AA; Side Missions are disabled by the server configuration.'] remoteExec ['QS_fnc_remoteExecCmd',_owner,false];
    };
    missionNamespace setVariable ['QS_priorityAA_force',true,false];
    if (missionNamespace getVariable ['QS_priorityAA_active',false]) then {
        missionNamespace setVariable ['QS_priorityAA_abort',true,false];
    };
    if ((missionNamespace getVariable ['QS_priorityAA_legacyActive',false]) || {!_enhanced && {missionNamespace getVariable ['QS_sideMissionActive',false]}}) then {
        missionNamespace setVariable ['QS_smAbort',true,true];
    };
    ['systemChat',format ['%1 queued Priority AA. It will start when its channel is available and spawning is permitted.',name _requestingPlayer]] remoteExec ['QS_fnc_remoteExecCmd',-2,false];
};

missionNamespace setVariable ["QS_smSuspend",true,true];
missionNamespace setVariable ["QS_smAbort",true,true];
missionNamespace setVariable ["QS_forcedSideMission",_sideMission,false];
missionNamespace setVariable ["QS_forceSideMission",true,false];

private _displayName = (_missions # _missionIndex) # 0;
["systemChat",format ["%1 forced side mission: %2",name _requestingPlayer,_displayName]] remoteExec ["QS_fnc_remoteExecCmd",-2,false];
