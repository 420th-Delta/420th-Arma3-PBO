/*
Function: TGC_fnc_playerProfileGUI

Description:
    Display a compact, readable all-time player statistics dialog.

Stat array order:
    deaths, incaps, kills, kills_air, kills_cars, kills_ships, kills_tanks,
    playtime, revives, transports, score

Author:
    420th
*/
disableSerialization;
params [
    ["_playerName", "Unknown Player", [""]],
    ["_uid", "", [""]],
    ["_stats", [], [[]]]
];

if (dialog) exitWith {
    systemChat "Close the current menu before opening a Player Profile.";
};
if !(createDialog "RscDisplayEmpty") exitWith {};

private _display = findDisplay -1;
if (isNull _display) exitWith {};

private _values = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
for "_i" from 0 to 10 do {
    private _value = _stats param [_i, 0];
    if (_value isEqualType 0) then {
        _values set [_i, _value];
    };
};
_values params [
    "_deaths", "_incaps", "_kills", "_killsAir", "_killsCars", "_killsShips",
    "_killsTanks", "_playtime", "_revives", "_transports", "_score"
];

private _formatNumber = {
    params ["_number"];
    [_number] call BIS_fnc_numberText
};
private _formatPlaytime = {
    params ["_minutes", "_formatNumber"];
    private _hours = floor (_minutes / 60);
    private _remainingMinutes = floor (_minutes mod 60);
    if (_hours <= 0) exitWith {format ["%1 min", [_remainingMinutes] call _formatNumber]};
    format ["%1h %2m", [_hours] call _formatNumber, _remainingMinutes]
};

private _width = 0.40 * safeZoneW;
private _height = 0.56 * safeZoneH;
private _dialogX = safeZoneX + (safeZoneW - _width) / 2;
private _dialogY = safeZoneY + (safeZoneH - _height) / 2;
private _padding = 0.025 * _width;
private _gap = 0.018 * _width;
private _columnWidth = (_width - (2 * _padding) - _gap) / 2;
private _primaryColor = ["GUI", "BCG_RGB"] call BIS_fnc_displayColorGet;

private _background = _display ctrlCreate ["RscText", -1];
_background ctrlSetPosition [_dialogX, _dialogY, _width, _height];
_background ctrlSetBackgroundColor [0.015, 0.02, 0.025, 0.97];
_background ctrlEnable false;
_background ctrlCommit 0;

private _title = _display ctrlCreate ["RscText", -1];
_title ctrlSetPosition [_dialogX, _dialogY, _width, 0.10 * _height];
_title ctrlSetBackgroundColor _primaryColor;
_title ctrlSetText "PLAYER PROFILE";
_title ctrlSetFont "RobotoCondensedBold";
_title ctrlSetFontHeight (0.030 * safeZoneH);
_title ctrlEnable false;
_title ctrlCommit 0;

private _name = _display ctrlCreate ["RscText", -1];
_name ctrlSetPosition [_dialogX + _padding, _dialogY + 0.115 * _height, _width - (2 * _padding), 0.075 * _height];
_name ctrlSetText _playerName;
_name ctrlSetFont "RobotoCondensedBold";
_name ctrlSetFontHeight (0.026 * safeZoneH);
_name ctrlEnable false;
_name ctrlCommit 0;

private _period = _display ctrlCreate ["RscText", -1];
_period ctrlSetPosition [_dialogX + _padding, _dialogY + 0.178 * _height, _width - (2 * _padding), 0.05 * _height];
_period ctrlSetText "ALL-TIME STATISTICS";
_period ctrlSetTextColor [0.72, 0.75, 0.78, 1];
_period ctrlSetFont "RobotoCondensed";
_period ctrlSetFontHeight (0.017 * safeZoneH);
_period ctrlEnable false;
_period ctrlCommit 0;

private _scoreBackground = _display ctrlCreate ["RscText", -1];
_scoreBackground ctrlSetPosition [_dialogX + _padding, _dialogY + 0.235 * _height, _width - (2 * _padding), 0.12 * _height];
_scoreBackground ctrlSetBackgroundColor [0.08, 0.10, 0.12, 1];
_scoreBackground ctrlEnable false;
_scoreBackground ctrlCommit 0;

private _scoreLabel = _display ctrlCreate ["RscText", -1];
_scoreLabel ctrlSetPosition [_dialogX + (2 * _padding), _dialogY + 0.235 * _height, 0.45 * _width, 0.12 * _height];
_scoreLabel ctrlSetText "SCORE";
_scoreLabel ctrlSetFont "RobotoCondensedBold";
_scoreLabel ctrlSetFontHeight (0.023 * safeZoneH);
_scoreLabel ctrlEnable false;
_scoreLabel ctrlCommit 0;

private _scoreValue = _display ctrlCreate ["RscText", -1];
_scoreValue ctrlSetPosition [_dialogX + 0.52 * _width, _dialogY + 0.235 * _height, 0.42 * _width, 0.12 * _height];
_scoreValue ctrlSetText ([_score] call _formatNumber);
_scoreValue ctrlSetTextColor _primaryColor;
_scoreValue ctrlSetFont "RobotoCondensedBold";
_scoreValue ctrlSetFontHeight (0.034 * safeZoneH);
_scoreValue ctrlEnable false;
_scoreValue ctrlCommit 0;

private _leftStats = [
    ["Infantry Kills", [_kills] call _formatNumber],
    ["Air Kills", [_killsAir] call _formatNumber],
    ["Car Kills", [_killsCars] call _formatNumber],
    ["Ship Kills", [_killsShips] call _formatNumber],
    ["Tank Kills", [_killsTanks] call _formatNumber]
];
private _rightStats = [
    ["Deaths", [_deaths] call _formatNumber],
    ["Incapacitations", [_incaps] call _formatNumber],
    ["Revives", [_revives] call _formatNumber],
    ["Transports", [_transports] call _formatNumber],
    ["Playtime", [_playtime, _formatNumber] call _formatPlaytime]
];

private _rowStartY = _dialogY + 0.375 * _height;
private _rowHeight = 0.086 * _height;
private _rowGap = 0.008 * _height;
{
    private _columnIndex = _forEachIndex;
    private _columnX = _dialogX + _padding + (_columnIndex * (_columnWidth + _gap));
    {
        _x params ["_labelText", "_valueText"];
        private _rowY = _rowStartY + (_forEachIndex * (_rowHeight + _rowGap));

        private _rowBackground = _display ctrlCreate ["RscText", -1];
        _rowBackground ctrlSetPosition [_columnX, _rowY, _columnWidth, _rowHeight];
        _rowBackground ctrlSetBackgroundColor [0.055, 0.065, 0.075, 0.96];
        _rowBackground ctrlEnable false;
        _rowBackground ctrlCommit 0;

        private _label = _display ctrlCreate ["RscText", -1];
        _label ctrlSetPosition [_columnX + (0.04 * _columnWidth), _rowY, 0.65 * _columnWidth, _rowHeight];
        _label ctrlSetText _labelText;
        _label ctrlSetFont "RobotoCondensed";
        _label ctrlSetFontHeight (0.019 * safeZoneH);
        _label ctrlEnable false;
        _label ctrlCommit 0;

        private _value = _display ctrlCreate ["RscText", -1];
        _value ctrlSetPosition [_columnX + (0.69 * _columnWidth), _rowY, 0.28 * _columnWidth, _rowHeight];
        _value ctrlSetText _valueText;
        _value ctrlSetFont "RobotoCondensedBold";
        _value ctrlSetFontHeight (0.021 * safeZoneH);
        _value ctrlEnable false;
        _value ctrlCommit 0;
    } forEach _x;
} forEach [_leftStats, _rightStats];

private _steamID = _display ctrlCreate ["RscText", -1];
_steamID ctrlSetPosition [_dialogX + _padding, _dialogY + 0.865 * _height, 0.65 * _width, 0.055 * _height];
_steamID ctrlSetText format ["Steam ID: %1", _uid];
_steamID ctrlSetTextColor [0.62, 0.65, 0.68, 1];
_steamID ctrlSetFont "RobotoCondensed";
_steamID ctrlSetFontHeight (0.016 * safeZoneH);
_steamID ctrlEnable false;
_steamID ctrlCommit 0;

private _close = _display ctrlCreate ["RscButtonMenu", 2];
_close ctrlSetPosition [_dialogX + 0.74 * _width, _dialogY + 0.865 * _height, 0.235 * _width, 0.075 * _height];
_close ctrlSetText "CLOSE";
_close ctrlSetFont "RobotoCondensedBold";
_close ctrlSetFontHeight (0.019 * safeZoneH);
_close ctrlCommit 0;
_close ctrlAddEventHandler ["ButtonClick", {closeDialog 2}];
