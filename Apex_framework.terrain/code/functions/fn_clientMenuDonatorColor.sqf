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

private _getTarget = {
	private _vehicle = vehicle player;
	if (!(_vehicle isEqualTo player)) exitWith {
		if ((driver _vehicle) isEqualTo player) then {
			[_vehicle,'vehicle',-1]
		} else {
			[objNull,'',-1]
		};
	};

	private _targetType = uiNamespace getVariable ['QS_client_donatorColorPicker_target','Uniform'];
	switch _targetType do {
		case 'Vest': {
			[vestContainer player,'vest',0]
		};
		case 'Backpack': {
			[backpackContainer player,'backpack',0]
		};
		case 'Helmet': {
			if ((headgear player) isEqualTo '') then {
				[objNull,'helmet',1]
			} else {
				[player,'helmet',1]
			};
		};
		default {
			[player,'uniform',0]
		};
	};
};

if (_type isEqualTo 'Open') exitWith {
	uiNamespace setVariable ['QS_client_donatorColorPicker_target','Uniform'];
	private _startColor = uiNamespace getVariable ['QS_client_donatorColorPicker_lastColor',[1,1,1,1]];
	[
		[_startColor],
		'Color Picker',
		[
			{
				params ['_confirmed','_colorRGBA1'];
				if (_confirmed isEqualTo true) then {
					['Apply',_colorRGBA1] call (missionNamespace getVariable 'QS_fnc_clientMenuDonatorColor');
				};
				if (_confirmed isEqualTo 'Reset') then {
					['Reset'] call (missionNamespace getVariable 'QS_fnc_clientMenuDonatorColor');
				};
				if (_confirmed in ['Uniform','Vest','Backpack','Helmet']) then {
					[_confirmed] call (missionNamespace getVariable 'QS_fnc_clientMenuDonatorColor');
				};
			},
			[]
		],
		'Apply',
		'Close',
		(findDisplay 46)
	] call (missionNamespace getVariable 'CAU_UserInputMenus_fnc_colorPicker');
};

if (_type in ['Uniform','Vest','Backpack','Helmet']) exitWith {
	if (!((vehicle player) isEqualTo player)) exitWith {};
	uiNamespace setVariable ['QS_client_donatorColorPicker_target',_type];
	private _text = parseText (format ['Color target set to %1.',toLower _type]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,3,-1,_text,[],-1];
};

if (_type isEqualTo 'Apply') exitWith {
	private _color = _data;
	if (!(_color isEqualType []) || {((count _color) < 4)}) exitWith {};

	uiNamespace setVariable ['QS_client_donatorColorPicker_lastColor',_color];

	(call _getTarget) params ['_target','_targetName','_selectionIndex'];
	if (isNull _target) exitWith {
		private _message = if ((vehicle player) isEqualTo player) then {
			format ['You are not wearing a %1.',toLower (uiNamespace getVariable ['QS_client_donatorColorPicker_target','Uniform'])]
		} else {
			'Exit the vehicle, or take the driver seat to color the vehicle.'
		};
		private _text = parseText _message;
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
	};

	if ((_target getVariable ['QS_donatorColorPicker_originalTextures',[]]) isEqualTo []) then {
		private _originalTextures = getObjectTextures _target;
		if (_selectionIndex >= 0) then {
			for '_i' from (count _originalTextures) to _selectionIndex do {
				_originalTextures pushBack '';
			};
		} else {
			if (_originalTextures isEqualTo []) then {
				_originalTextures = getArray ((configOf _target) >> 'hiddenSelectionsTextures');
			};
		};
		_target setVariable ['QS_donatorColorPicker_originalTextures',_originalTextures,FALSE];
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

	if (_selectionIndex >= 0) then {
		_target setObjectTextureGlobal [_selectionIndex,_texture];
	} else {
		for '_i' from 0 to (_selectionCount - 1) do {
			_target setObjectTextureGlobal [_i,_texture];
		};
	};

	private _text = parseText (format ['Applied selected color to your %1.',_targetName]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
};

if (_type isEqualTo 'Reset') exitWith {
	(call _getTarget) params ['_target','_targetName','_selectionIndex'];
	if (isNull _target) exitWith {
		private _message = if ((vehicle player) isEqualTo player) then {
			format ['You are not wearing a %1.',toLower (uiNamespace getVariable ['QS_client_donatorColorPicker_target','Uniform'])]
		} else {
			'Exit the vehicle, or take the driver seat to reset the vehicle color.'
		};
		private _text = parseText _message;
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
	};

	private _textures = _target getVariable ['QS_donatorColorPicker_originalTextures',[]];
	if (_textures isEqualTo []) then {
		_textures = if (_selectionIndex >= 0) then {
			private _playerTextures = getObjectTextures _target;
			for '_i' from (count _playerTextures) to _selectionIndex do {
				_playerTextures pushBack '';
			};
			_playerTextures
		} else {
			getArray ((configOf _target) >> 'hiddenSelectionsTextures')
		};
	};

	private _selectionCount = ((count _textures) max 1);
	if (!(_target isEqualTo player)) then {
		_selectionCount = _selectionCount max (count (getArray ((configOf _target) >> 'hiddenSelections')));
	};

	if (_selectionIndex >= 0) then {
		_target setObjectTextureGlobal [_selectionIndex,(_textures param [_selectionIndex,''])];
	} else {
		for '_i' from 0 to (_selectionCount - 1) do {
			_target setObjectTextureGlobal [_i,(_textures param [_i,''])];
		};
	};
	_target setVariable ['QS_donatorColorPicker_originalTextures',[],FALSE];

	private _text = parseText (format ['Reset color changes on your %1.',_targetName]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
};
