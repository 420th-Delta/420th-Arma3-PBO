/*
Function: TGC_fnc_staffGUI

Description:
    Show the staff menu GUI.

Author:
    thegamecracks

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
    _group ctrlSetPosition [safeZoneX + 0.3 * safeZoneW, safeZoneY + 0.3 * safeZoneH, 0.4 * safeZoneW, 0.4 * safeZoneH];
    _group ctrlCommit 0;
    ctrlPosition _group params ["_groupX", "_groupY", "_width", "_height"];

    private _frame = _display ctrlCreate ["RscText", -1, _group];
    _frame ctrlSetPosition ([0, 0, 1, 1] call _scaleToGroup);
    _frame ctrlSetBackgroundColor [0, 0, 0, 0.4];
    _frame ctrlEnable false;
    _frame ctrlCommit 0;

    private _title = _display ctrlCreate ["RscText", -1, _group];
    _title ctrlSetPosition ([0, 0, 1, 0.05] call _scaleToGroup);
    _title ctrlSetBackgroundColor _primaryColor;
    _title ctrlSetText "420th Staff Menu";
    _title ctrlEnable false;
    _title ctrlCommit 0;

    private _channels = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _channels ctrlSetPosition ([0.03, 0.1, 0.2, 0.08] call _scaleToGroup);
    _channels ctrlSetStructuredText composeText [
        parseText "<t size='0.25'>&#160;</t><br/>",
        text "Manage Channels" setAttributes [
            "align", "center",
            "font", "RobotoCondensed"
        ]
    ];
    _channels ctrlCommit 0;
    _channels ctrlAddEventHandler ["ButtonClick", {
        closeDialog 1;
        0 spawn {isNil TGC_fnc_staffChannelsGUI};
    }];

    private _forceSideMission = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _forceSideMission ctrlSetPosition ([0.03, 0.2, 0.2, 0.08] call _scaleToGroup);
    _forceSideMission ctrlSetStructuredText composeText [
        parseText "<t size='0.25'>&#160;</t><br/>",
        text "Force Side Mission" setAttributes [
            "align", "center",
            "font", "RobotoCondensed"
        ]
    ];
    _forceSideMission ctrlCommit 0;
    _forceSideMission ctrlAddEventHandler ["ButtonClick", {
        closeDialog 1;
        0 spawn {isNil TGC_fnc_staffSideMissionGUI};
    }];

    private _close = _display ctrlCreate ["RscButtonMenu", 2];
    _close ctrlSetPosition [_groupX, _groupY + _height, 0.2, 0.04];
    _close ctrlSetText toUpper localize "$str_disp_cancel";
    _close ctrlCommit 0;
};
