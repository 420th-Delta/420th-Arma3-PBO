/*
Function: TGC_fnc_staffChannelsGUI

Description:
    Show the staff channel management GUI.

Author:
    thegamecracks

*/
disableSerialization;
if (dialog) exitWith {};
if (!call TGC_fnc_isStaff) exitWith {};

with uiNamespace do {
    createDialog "RscDisplayEmpty";
    private _display = findDisplay -1;

    TGC_fnc_getChannelMasks = {
        // Rather than operate on all channel IDs, we'll only show ones
        // useful for staff. As a side effect, this GUI will reset masks
        // for other channel IDs.
        private _masks = [
            [2, localize "str_channel_command"],
            [3, localize "str_channel_group"],
            [7, radioChannelInfo 2 # 1],
            [13, radioChannelInfo 8 # 1]
        ];
        if (missionNamespace getVariable ['QS_radio_sharedBroadcastsEnabled',FALSE]) then {
            private _sideChannel = missionNamespace getVariable ['QS_radioChannel_side',0];
            private _sideUI = if (_sideChannel > 0) then {_sideChannel + ([5,15] select (_sideChannel > 10))} else {1};
            _masks pushBack [_sideUI,if (_sideChannel > 0) then {'Side channel'} else {'Side (native)'}];
        };

        {
            _x params ["_channel"];
            isNil {with missionNamespace do {
                private _mask = [_channel] call TGC_fnc_getChannelMask;
                _x pushBack _mask;
            }};
        } forEach _masks;

        _masks
    };

    TGC_fnc_refreshChannels = {
        if (TGC_staffChannelsGUI_changeRequested) then {
            TGC_staffChannelsGUI_changeRequested = false;
            call TGC_fnc_setChannelMasks;
        };

        private _masks = call TGC_fnc_getChannelMasks;
        {
            _x # 2 params ["_textEnabled", "_vonEnabled"];
            TGC_staffChannelsGUI_controls # _forEachIndex params ["", "_text", "_von"];
            _text cbSetChecked _textEnabled;
            _von cbSetChecked _vonEnabled;
        } forEach _masks;
    };

    TGC_fnc_setChannelMasks = {
        private _masks = [];
        {
            _x params ["_id"];
            TGC_staffChannelsGUI_controls # _forEachIndex params ["", "_text", "_von"];
            _masks pushBack [_id, [cbChecked _text, cbChecked _von]];
        } forEach call TGC_fnc_getChannelMasks;

        private _jipID = "TGC_fnc_setChannelMasks";
        [_masks] remoteExec ["TGC_fnc_setChannelMasks", 0, _jipID];

        // Since remote execution takes time to broadcast, even to our own client,
        // let's call the function so we see our changes immediately.
        isNil {with missionNamespace do {[_masks] call TGC_fnc_setChannelMasks}};
    };

    private _primaryColor = ["GUI", "BCG_RGB"] call BIS_fnc_displayColorGet;
    private _scaleToGroup = {_this vectorMultiply [_width, _height, _width, _height]};

    private _group = _display ctrlCreate ["RscControlsGroup", -1];
    _group ctrlSetPosition [safeZoneX + 0.4 * safeZoneW, safeZoneY + 0.3 * safeZoneH, 0.2 * safeZoneW, 0.4 * safeZoneH];
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
    _title ctrlSetText "Channel Management";
    _title ctrlEnable false;
    _title ctrlCommit 0;

    private _textHeader = _display ctrlCreate ["RscText", -1, _group];
    _textHeader ctrlSetPosition ([0.58, 0.11, 0.15, 0.05] call _scaleToGroup);
    _textHeader ctrlSetText "Text?";
    _textHeader ctrlEnable false;
    _textHeader ctrlCommit 0;

    private _vonHeader = _display ctrlCreate ["RscText", -1, _group];
    _vonHeader ctrlSetPosition ([0.78, 0.11, 0.15, 0.05] call _scaleToGroup);
    _vonHeader ctrlSetText "Voice?";
    _vonHeader ctrlEnable false;
    _vonHeader ctrlCommit 0;

    TGC_staffChannelsGUI_controls = [];
    TGC_staffChannelsGUI_changeRequested = false;
    {
        _x params ["", "_name"];

        private _posY = 0.18 + _forEachIndex * 0.08;

        private _label = _display ctrlCreate ["RscText", -1, _group];
        _label ctrlSetPosition ([0.1, _posY, 0.4, 0.05] call _scaleToGroup);
        _label ctrlSetText _name;
        _label ctrlEnable false;
        _label ctrlCommit 0;

        private _text = _display ctrlCreate ["RscCheckbox", -1, _group];
        _text ctrlSetPosition ([0.625, _posY, 0.05, 0.05] call _scaleToGroup);
        _text ctrlSetTooltip "Toggle Text";
        _text ctrlCommit 0;
        _text ctrlAddEventHandler ["CheckedChanged", {with uiNamespace do {
            playSoundUI ["click"];
            TGC_staffChannelsGUI_changeRequested = true;
        }}];

        private _von = _display ctrlCreate ["RscCheckbox", -1, _group];
        _von ctrlSetPosition ([0.825, _posY, 0.05, 0.05] call _scaleToGroup);
        _von ctrlSetTooltip "Toggle Voice";
        _von ctrlCommit 0;
        _von ctrlAddEventHandler ["CheckedChanged", {with uiNamespace do {
            playSoundUI ["click"];
            TGC_staffChannelsGUI_changeRequested = true;
        }}];

        TGC_staffChannelsGUI_controls pushBack [_label, _text, _von];
    } forEach call TGC_fnc_getChannelMasks;

    private _close = _display ctrlCreate ["RscButtonMenu", 2];
    _close ctrlSetPosition [_groupX, _groupY + _height, 0.2, 0.04];
    _close ctrlSetText toUpper localize "$str_disp_cancel";
    _close ctrlCommit 0;

    _display displayAddEventHandler ["Unload", {with uiNamespace do {
        call TGC_fnc_refreshChannels;
    }}];

    call TGC_fnc_refreshChannels;
    _display spawn {
        disableSerialization;
        while {uiSleep 1; !isNull _this} do {
            call TGC_fnc_refreshChannels;
        };
    };
};
