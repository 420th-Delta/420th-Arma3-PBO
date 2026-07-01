/*
File: fn_clientMenuDonators.sqf
Author:

	Quiksilver

Description:

	Donators Menu
__________________________________________________________*/

disableSerialization;
params ['_type',['_display',displayNull]];

private _isDonator = ((toLowerANSI (player getVariable ['QS_unit_role',''])) isEqualTo 'donator') || {((getPlayerUID player) in (['DONATOR'] call (missionNamespace getVariable 'QS_fnc_whitelist')))};
if (!_isDonator) exitWith {
	closeDialog 2;
};

if (_type isEqualTo 'onLoad') exitWith {
	(findDisplay 2000) closeDisplay 1;
	setMousePosition (uiNamespace getVariable ['QS_ui_mousePosition',getMousePosition]);
};

if (_type isEqualTo 'onUnload') exitWith {
	uiNamespace setVariable ['QS_ui_mousePosition',getMousePosition];
};

if (_type isEqualTo 'Flags') exitWith {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {
			closeDialog 2;
			(!dialog)
		};
		createDialog 'QS_RD_client_dialog_menu_donatorFlags';
	};
};

if (_type isEqualTo 'Textures') exitWith {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {
			closeDialog 2;
			(!dialog)
		};
		createDialog 'QS_RD_client_dialog_menu_donatorTextures';
	};
};

if (_type isEqualTo 'Skins') exitWith {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {
			closeDialog 2;
			(!dialog)
		};
		createDialog 'QS_RD_client_dialog_menu_donatorSkins';
	};
};

if (_type isEqualTo 'ColorPicker') exitWith {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {
			closeDialog 2;
			(!dialog)
		};
		['Open'] call (missionNamespace getVariable 'QS_fnc_clientMenuDonatorColor');
	};
};

if (_type isEqualTo 'Back') exitWith {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {
			closeDialog 2;
			(!dialog)
		};
		createDialog 'QS_RD_client_dialog_menu_main';
	};
};
