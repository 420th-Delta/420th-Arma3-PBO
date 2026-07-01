/*
Function: TGC_fnc_staffSideMissionGUI

Description:
    Show the force side mission GUI.
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
    _title ctrlSetPosition ([0, 0, 1, 0.05] call _scaleToGroup);
    _title ctrlSetBackgroundColor _primaryColor;
    _title ctrlSetText "Force Side Mission";
    _title ctrlEnable false;
    _title ctrlCommit 0;

    private _list = _display ctrlCreate ["RscListbox", -1, _group];
    _list ctrlSetPosition ([0.05, 0.1, 0.9, 0.7] call _scaleToGroup);
    _list ctrlCommit 0;
    TGC_staffSideMissionList = _list;

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
    {
        private _index = _list lbAdd (_x # 0);
        _list lbSetData [_index,(_x # 1)];
    } forEach _missions;
    if ((lbSize _list) > 0) then {
        _list lbSetCurSel 0;
    };

    private _force = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _force ctrlSetPosition ([0.05, 0.84, 0.35, 0.08] call _scaleToGroup);
    _force ctrlSetText "FORCE";
    _force ctrlCommit 0;
    _force ctrlAddEventHandler ["ButtonClick", {
        private _list = uiNamespace getVariable ["TGC_staffSideMissionList",controlNull];
        if (isNull _list) exitWith {};
        private _selection = lbCurSel _list;
        if (_selection isEqualTo -1) exitWith {};
        private _sideMission = _list lbData _selection;
        [_sideMission] remoteExec ["TGC_fnc_forceSideMission",2,false];
        closeDialog 1;
    }];

    private _back = _display ctrlCreate ["RscButtonMenu", -1, _group];
    _back ctrlSetPosition ([0.6, 0.84, 0.35, 0.08] call _scaleToGroup);
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

    _display displayAddEventHandler ["Unload", {
        uiNamespace setVariable ["TGC_staffSideMissionList",nil];
    }];
};
