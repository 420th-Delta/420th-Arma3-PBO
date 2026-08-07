/*
Function: TGC_fnc_staffSideMissionManagementGUI

Description:
    Show the Side Mission management GUI.
*/
disableSerialization;
if (dialog) exitWith {};
if (!call TGC_fnc_isStaff) exitWith {};

playSoundUI ["click"];
with uiNamespace do {
    createDialog "RscDisplayEmpty";
    private _display = findDisplay -1;

    private _primaryColor = ["GUI", "BCG_RGB"] call BIS_fnc_displayColorGet;
    private _scaleToGroup = {_this vectorMultiply [_width, _height, _width, _height]};

    private _group = _display ctrlCreate ["RscControlsGroup", -1];
    _group ctrlSetPosition [safeZoneX + 0.35 * safeZoneW, safeZoneY + 0.25 * safeZoneH, 0.3 * safeZoneW, 0.5 * safeZoneH];
    _group ctrlCommit 0;
    ctrlPosition _group params ["_groupX", "_groupY", "_width", "_height"];

    private _frame = _display ctrlCreate ["RscText", -1, _group];
    _frame ctrlSetPosition ([0, 0, 1, 1] call _scaleToGroup);
    _frame ctrlSetBackgroundColor [0, 0, 0, 0.4];
    _frame ctrlEnable false;
    _frame ctrlCommit 0;

    private _title = _display ctrlCreate ["RscText", -1, _group];
    _title ctrlSetPosition ([0, 0, 1, 0.07] call _scaleToGroup);
    _title ctrlSetBackgroundColor _primaryColor;
    _title ctrlSetText "Side Mission Management";
    _title ctrlEnable false;
    _title ctrlCommit 0;

    private _force = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _force ctrlSetPosition ([0.1, 0.14, 0.8, 0.11] call _scaleToGroup);
    _force ctrlSetText "FORCE SIDE MISSION";
    _force ctrlCommit 0;
    _force ctrlAddEventHandler ["ButtonClick", {
        closeDialog 1;
        0 spawn {isNil TGC_fnc_staffSideMissionGUI};
    }];

    private _pause = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _pause ctrlSetPosition ([0.1, 0.32, 0.8, 0.11] call _scaleToGroup);
    _pause ctrlSetText "PAUSE SIDE MISSIONS";
    _pause ctrlCommit 0;
    _pause ctrlAddEventHandler ["ButtonClick", {
        ["PAUSE"] remoteExec ["TGC_fnc_manageSideMissions", 2, false];
        closeDialog 1;
    }];

    private _cycle = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _cycle ctrlSetPosition ([0.1, 0.5, 0.8, 0.11] call _scaleToGroup);
    _cycle ctrlSetText "CYCLE SIDE MISSION";
    _cycle ctrlCommit 0;
    _cycle ctrlAddEventHandler ["ButtonClick", {
        ["CYCLE"] remoteExec ["TGC_fnc_manageSideMissions", 2, false];
        closeDialog 1;
    }];

    private _back = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _back ctrlSetPosition ([0.1, 0.76, 0.35, 0.1] call _scaleToGroup);
    _back ctrlSetText "BACK";
    _back ctrlCommit 0;
    _back ctrlAddEventHandler ["ButtonClick", {
        closeDialog 1;
        0 spawn {isNil TGC_fnc_staffGUI};
    }];

    private _close = _display ctrlCreate ["RscButtonMenu", 2];
    _close ctrlSetPosition [_groupX, _groupY + _height, 0.2, 0.04];
    _close ctrlSetText toUpper localize "$str_disp_cancel";
    _close ctrlCommit 0;
};
