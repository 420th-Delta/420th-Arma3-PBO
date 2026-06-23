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

if (_type isEqualTo 'onLoad') then {
	(findDisplay 2000) closeDisplay 1;
	(findDisplay 5000) closeDisplay 1;
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

if (_type isEqualTo 'Select') then {
	private _index = lbCurSel 1804;
	if (_index isNotEqualTo -1) then {
		private _texture = lbData [1804,_index];
		private _displayName = lbText [1804,_index];
		private _target = player;
		if (!((vehicle player) isEqualTo player) && {((driver (vehicle player)) isEqualTo player)}) then {
			_target = vehicle player;
		};
		_target setObjectTextureGlobal [0,_texture];
		private _targetName = ['unit','vehicle'] select (!(_target isEqualTo player));
		private _text = parseText (format ['Applied %1 texture to your %2.',_displayName,_targetName]);
		(missionNamespace getVariable 'QS_managed_hints') pushBack [5,FALSE,5,-1,_text,[],-1];
	};
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
