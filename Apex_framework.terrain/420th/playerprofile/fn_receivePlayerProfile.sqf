/*
Function: TGC_fnc_receivePlayerProfile

Description:
    Receive a server-authenticated player profile response and display it.

Author:
    420th
*/
if (!hasInterface) exitWith {};
params [
    ["_playerName", "Unknown Player", [""]],
    ["_uid", "", [""]],
    ["_stats", [], [[]]],
    ["_success", false, [false]]
];

if (!_success) exitWith {
    systemChat format ["Unable to load %1's Player Profile. Please try again later.", _playerName];
};

[_playerName, _uid, _stats] call TGC_fnc_playerProfileGUI;
