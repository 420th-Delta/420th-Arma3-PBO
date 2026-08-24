/*
Function: TGC_fnc_manageWeather

Description:
    Toggle the mission weather cycle from a validated staff request.
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
if (_action isNotEqualTo "TOGGLE") exitWith {};

private _enabled = missionNamespace getVariable ["QS_missionConfig_weatherDynamic", true];
private _newState = !_enabled;
missionNamespace setVariable ["QS_missionConfig_weatherDynamic", _newState, true];

private _stateText = ["disabled", "enabled"] select _newState;
["systemChat", format ["%1 (staff) %2 the weather cycle", name _requestingPlayer, _stateText]] remoteExec ["QS_fnc_remoteExecCmd", -2, false];
