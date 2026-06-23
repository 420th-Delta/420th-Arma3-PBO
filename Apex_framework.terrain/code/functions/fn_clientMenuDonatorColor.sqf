/*
File: fn_clientMenuDonatorColor.sqf
Author:

	Seathre

Description:

	Donator color picker
__________________________________________________________*/

disableSerialization;
params ['_type',['_data',[]]];

private _isDonator = ((toLowerANSI (player getVariable ['QS_unit_role',''])) isEqualTo 'donator') || {((getPlayerUID player) in (['DONATOR'] call (missionNamespace getVariable 'QS_fnc_whitelist')))};
if (!_isDonator) exitWith {
	closeDialog 2;
};

if (_type isEqualTo 'Open') exitWith {
	private _startColor = uiNamespace getVariable ['QS_client_donatorColorPicker_lastColor',[1,1,1,1]];
	[
		[_startColor],
		'Color Picker',
		[
			{
				params ['_confirmed','_colorRGBA1'];
				if (_confirmed) then {
					['Apply',_colorRGBA1] call (missionNamespace getVariable 'QS_fnc_clientMenuDonatorColor');
				};
			},
			[]
		],
		'Apply',
		0,
		(findDisplay 46)
	] call (missionNamespace getVariable 'CAU_UserInputMenus_fnc_colorPicker');
};

if (_type isEqualTo 'Apply') exitWith {
	private _color = _data;
	if (!(_color isEqualType []) || {((count _color) < 4)}) exitWith {};

	uiNamespace setVariable ['QS_client_donatorColorPicker_lastColor',_color];

	private _target = player;
	private _targetName = 'character';
	private _vehicle = vehicle player;
	if ((!(_vehicle isEqualTo player)) && {((driver _vehicle) isEqualTo player)}) then {
		_target = _vehicle;
		_targetName = 'vehicle';
	};

	private _texture = format [
		'#(rgb,8,8,3)color(%1,%2,%3,%4)',
		_color # 0,
		_color # 1,
		_color # 2,
		_color # 3
	];
	private _selectionCount = if (_target isEqualTo player) then {
		1
	} else {
		(count (getArray ((configOf _target) >> 'hiddenSelections'))) max 1
	};

	for '_i' from 0 to (_selectionCount - 1) do {
		_target setObjectTextureGlobal [_i,_texture];
	};

	private _text = parseText (format ['Applied selected color to your %1.',_targetName]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
};
