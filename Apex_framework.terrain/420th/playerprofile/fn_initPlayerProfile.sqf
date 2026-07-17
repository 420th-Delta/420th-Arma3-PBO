/*
Function: TGC_fnc_initPlayerProfile

Description:
    Add local action-menu entries for viewing player profiles.

Author:
    420th
*/
params [["_init", ""]];

if (!hasInterface) exitWith {};
if (_init in ["preInit", "postInit"]) exitWith {
    [""] spawn TGC_fnc_initPlayerProfile;
};

waitUntil {
    uiSleep 0.1;
    !isNull player
};

private _selfActionUnit = objNull;
private _selfActionID = -1;
private _targetActions = [];

while {hasInterface} do {
    // The player's object changes on respawn, so move the self action to the new unit.
    if (player isNotEqualTo _selfActionUnit) then {
        if (!isNull _selfActionUnit && {_selfActionID >= 0}) then {
            _selfActionUnit removeAction _selfActionID;
        };

        _selfActionUnit = player;
        _selfActionID = player addAction [
            "My Profile",
            {
                params ["", "_caller"];
                systemChat "Loading Player Profile...";
                [123, _caller] remoteExecCall ["QS_fnc_remoteExec", 2, false];
            },
            nil,
            1.5,
            false,
            true,
            "",
            "alive _this",
            -1,
            false,
            "",
            ""
        ];
    };

    private _players = allPlayers - entities "HeadlessClient_F";

    // Remove actions for disconnected players, corpses, and the local player's old object.
    for "_i" from ((count _targetActions) - 1) to 0 step -1 do {
        (_targetActions # _i) params ["_unit", "_actionID"];
        if (isNull _unit || {!(_unit in _players)} || {_unit isEqualTo player}) then {
            if (!isNull _unit) then {
                _unit removeAction _actionID;
            };
            _targetActions deleteAt _i;
        };
    };

    {
        private _unit = _x;
        if (_unit isEqualTo player) then {continue};
        if (_targetActions findIf {(_x # 0) isEqualTo _unit} >= 0) then {continue};

        private _actionID = _unit addAction [
            format ["%1's Profile", name _unit],
            {
                params ["_target"];
                systemChat format ["Loading %1's Player Profile...", name _target];
                [123, _target] remoteExecCall ["QS_fnc_remoteExec", 2, false];
            },
            nil,
            1.4,
            false,
            true,
            "",
            "alive _this && {alive _target} && {_target isNotEqualTo _this} && {isPlayer _target} && {_this distance _target <= 4.5} && {cursorObject isEqualTo _target}",
            4.5,
            false,
            "",
            ""
        ];
        _targetActions pushBack [_unit, _actionID];
    } forEach _players;

    uiSleep 2;
};
