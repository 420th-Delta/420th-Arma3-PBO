/*
File: fn_clientMenuDonatorSkins.sqf
Author:

	Seathre

Description:

	Cosmetic Commissary purchased skin menu.
__________________________________________________________*/

disableSerialization;
params ['_type',['_data',displayNull]];

private _isDonator = ((toLowerANSI (player getVariable ['QS_unit_role',''])) isEqualTo 'donator') || {((getPlayerUID player) in (['DONATOR'] call (missionNamespace getVariable 'QS_fnc_whitelist')))};
if (!_isDonator) exitWith {
	closeDialog 2;
};

private _fn_getTarget = {
	private _target = vehicle player;
	if (_target isEqualTo player) exitWith {[player,'uniform']};
	if ((driver _target) isEqualTo player) exitWith {[_target,'vehicle']};
	[player,'uniform']
};

private _fn_getTextureSlotCount = {
	params ['_target'];
	private _slotCount = 1;
	_slotCount = _slotCount max (count (getObjectTextures _target));
	_slotCount = _slotCount max (count (getArray ((configOf _target) >> 'hiddenSelections')));
	_slotCount = _slotCount max (count (getArray ((configOf _target) >> 'hiddenSelectionsTextures')));
	_slotCount
};

if (_type isEqualTo 'onLoad') exitWith {
	(findDisplay 2000) closeDisplay 1;
	(findDisplay 5000) closeDisplay 1;
	setMousePosition (uiNamespace getVariable ['QS_ui_mousePosition',getMousePosition]);
	lbClear 1804;
	private _loadingIndex = lbAdd [1804,'Loading purchased skins...'];
	lbSetData [1804,_loadingIndex,''];
	((findDisplay 5400) displayCtrl 1810) ctrlEnable FALSE;
	[player,getPlayerUID player] remoteExecCall ['QS_fnc_serverGetDonatorSkins',2];
};

if (_type isEqualTo 'Data') exitWith {
	if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
	private _display = findDisplay 5400;
	if (isNull _display) exitWith {};
	lbClear 1804;
	{
		_x params ['_displayName','_textures'];
		private _index = lbAdd [1804,_displayName];
		lbSetData [1804,_index,str _textures];
		private _preview = '';
		{
			if (fileExists _x) exitWith {
				_preview = _x;
			};
		} forEach _textures;
		lbSetPicture [1804,_index,_preview];
		lbSetTooltip [1804,_index,(_textures joinString ' | ')];
	} forEach _data;
	if (_data isEqualTo []) then {
		private _emptyIndex = lbAdd [1804,'No purchased skins found'];
		lbSetData [1804,_emptyIndex,''];
		(_display displayCtrl 1810) ctrlEnable FALSE;
	} else {
		lbSetCurSel [1804,0];
		(_display displayCtrl 1810) ctrlEnable TRUE;
	};
};

if (_type isEqualTo 'Apply') exitWith {
	private _index = lbCurSel 1804;
	if (_index isEqualTo -1) exitWith {};
	private _textures = parseSimpleArray (lbData [1804,_index]);
	private _texture = '';
	{
		if (fileExists _x) exitWith {
			_texture = _x;
		};
	} forEach _textures;
	if (_texture isEqualTo '') exitWith {
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,6,-1,'This purchased skin has not been installed on the game server yet.',[],-1];
	};
	(call _fn_getTarget) params ['_target','_targetName'];
	private _identity = [typeOf _target,uniform player] select (_target isEqualTo player);
	private _original = _target getVariable ['QS_commissarySkin_original',[]];
	if ((_original isEqualTo []) || {(_original # 0) isNotEqualTo _identity}) then {
		private _textures = getObjectTextures _target;
		if (_textures isEqualTo []) then {
			_textures = getArray ((configOf _target) >> 'hiddenSelectionsTextures');
		};
		_target setVariable ['QS_commissarySkin_original',[_identity,_textures],FALSE];
	};
	for '_i' from 0 to (([_target] call _fn_getTextureSlotCount) - 1) do {
		_target setObjectTextureGlobal [_i,_texture];
	};
	private _text = parseText (format ['Applied %1 to your %2.',lbText [1804,_index],_targetName]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
};

if (_type isEqualTo 'Reset') exitWith {
	(call _fn_getTarget) params ['_target','_targetName'];
	private _identity = [typeOf _target,uniform player] select (_target isEqualTo player);
	private _original = _target getVariable ['QS_commissarySkin_original',[]];
	private _textures = getArray ((configOf _target) >> 'hiddenSelectionsTextures');
	if ((_original isNotEqualTo []) && {(_original # 0) isEqualTo _identity}) then {
		_textures = _original # 1;
	};
	for '_i' from 0 to (([_target] call _fn_getTextureSlotCount) - 1) do {
		_target setObjectTextureGlobal [_i,(_textures param [_i,''])];
	};
	_target setVariable ['QS_commissarySkin_original',nil,FALSE];
	private _text = parseText (format ['Reset the skin on your %1.',_targetName]);
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
};

if (_type isEqualTo 'Close') exitWith {
	closeDialog 2;
};

if (_type isEqualTo 'onUnload') exitWith {
	uiNamespace setVariable ['QS_ui_mousePosition',getMousePosition];
};
