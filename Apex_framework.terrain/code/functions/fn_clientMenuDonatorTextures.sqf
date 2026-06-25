/*
File: fn_clientMenuDonatorTextures.sqf
Author:

	Seathre

Description:

	Donator object texture menu
__________________________________________________________*/

disableSerialization;
params ['_type',['_display',displayNull]];

private _isDonator = ((toLowerANSI (player getVariable ['QS_unit_role',''])) isEqualTo 'donator') || {((getPlayerUID player) in (['DONATOR'] call (missionNamespace getVariable 'QS_fnc_whitelist')))};
if (!_isDonator) exitWith {
	closeDialog 2;
};

private _list = call compile preprocessFileLineNumbers 'code\config\donator_textures.sqf';

private _fn_getTarget = {
	private _vehicle = vehicle player;
	if (!(_vehicle isEqualTo player)) exitWith {
		if ((driver _vehicle) isEqualTo player) then {
			[_vehicle,'vehicle']
		} else {
			[player,'uniform']
		};
	};
	private _targetType = uiNamespace getVariable ['QS_client_donatorTexture_target','Uniform'];
	switch _targetType do {
		case 'Vest': {
			[vestContainer player,'vest']
		};
		case 'Backpack': {
			[backpackContainer player,'backpack']
		};
		case 'Helmet': {
			if ((headgear player) isEqualTo '') then {
				[objNull,'helmet']
			} else {
				[player,'helmet']
			};
		};
		default {
			[player,'uniform']
		};
	};
};

private _fn_getTextureSlotCount = {
	params ['_target'];
	private _slotCount = 1;
	if (!(_target isEqualTo player) && {!(isNull _target)}) then {
		_slotCount = _slotCount max (count (getObjectTextures _target));
		_slotCount = _slotCount max (count (getArray ((configOf _target) >> 'hiddenSelections')));
		_slotCount = _slotCount max (count (getArray ((configOf _target) >> 'hiddenSelectionsTextures')));
	};
	_slotCount
};

if (_type isEqualTo 'onLoad') then {
	(findDisplay 2000) closeDisplay 1;
	(findDisplay 5000) closeDisplay 1;
	if (isNil {uiNamespace getVariable 'QS_client_donatorTexture_target'}) then {
		uiNamespace setVariable ['QS_client_donatorTexture_target','Uniform'];
	};
	setMousePosition (uiNamespace getVariable ['QS_ui_mousePosition',getMousePosition]);
	{
		_x params ['_displayName','_texture','_source'];
		private _index = lbAdd [1804,_displayName];
		lbSetData [1804,_index,_texture];
		lbSetPicture [1804,_index,_texture];
		lbSetTooltip [1804,_index,(format ['%1 - %2',_source,_texture])];
	} forEach _list;
	if (_list isNotEqualTo []) then {
		lbSetCurSel [1804,0];
	};
};

if (_type in ['Uniform','Vest','Backpack','Helmet']) then {
	if (!((vehicle player) isEqualTo player)) exitWith {
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,3,-1,'Exit the vehicle to select a uniform, vest, backpack, or helmet texture target.',[],-1];
	};
	uiNamespace setVariable ['QS_client_donatorTexture_target',_type];
	private _text = parseText (format ['Texture target set to %1.',toLower _type]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,3,-1,_text,[],-1];
};

if (_type isEqualTo 'Select') then {
	private _index = lbCurSel 1804;
	if (_index isNotEqualTo -1) then {
		private _texture = lbData [1804,_index];
		private _displayName = lbText [1804,_index];
		(call _fn_getTarget) params ['_target','_targetName'];
		if (isNull _target) exitWith {
			private _text = parseText (format ['You are not wearing a %1.',_targetName]);
			(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
		};
		for '_i' from 0 to (([_target] call _fn_getTextureSlotCount) - 1) do {
			_target setObjectTextureGlobal [_i,_texture];
		};
		private _text = parseText (format ['Applied %1 texture to your %2.',_displayName,_targetName]);
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
	};
};

if (_type isEqualTo 'Reset') then {
	(call _fn_getTarget) params ['_target','_targetName'];
	if (isNull _target) exitWith {
		private _text = parseText (format ['You are not wearing a %1.',_targetName]);
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
	};
	private _defaultTextures = [''];
	if (!(_target isEqualTo player)) then {
		_defaultTextures = getArray ((configOf _target) >> 'hiddenSelectionsTextures');
	};
	for '_i' from 0 to (([_target] call _fn_getTextureSlotCount) - 1) do {
		_target setObjectTextureGlobal [_i,(_defaultTextures param [_i,''])];
	};
	private _text = parseText (format ['Reset texture on your %1.',_targetName]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
};

if (_type isEqualTo 'Back') then {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {
			closeDialog 2;
			(!dialog)
		};
		createDialog 'QS_RD_client_dialog_menu_donators';
	};
};

if (_type isEqualTo 'onUnload') then {
	uiNamespace setVariable ['QS_ui_mousePosition',getMousePosition];
};
