/*
File: fn_serverGetDonatorSkins.sqf
Author:

	Seathre

Description:

	Returns a player's completed Cosmetic Commissary purchases.
__________________________________________________________*/

if (!isServer || {!isRemoteExecuted}) exitWith {};

params [['_unit',objNull],['_uid','']];

if (
	(isNull _unit) ||
	{!isPlayer _unit} ||
	{(owner _unit) isNotEqualTo remoteExecutedOwner} ||
	{_uid isNotEqualTo (getPlayerUID _unit)} ||
	{(count _uid) isNotEqualTo 17}
) exitWith {};

private _requestOwner = remoteExecutedOwner;
[_unit,_uid,_requestOwner] spawn {
	params ['_unit','_uid','_requestOwner'];
	private _skins = [];
	private _fn_slugify = {
		params ['_value'];
		private _slug = '';
		private _lastWasSeparator = FALSE;
		{
			private _isAlphaNumeric = (
				((_x >= 48) && {_x <= 57}) ||
				{((_x >= 65) && {_x <= 90})} ||
				{((_x >= 97) && {_x <= 122})}
			);
			if (_isAlphaNumeric) then {
				_slug = _slug + (toString [_x]);
				_lastWasSeparator = FALSE;
			} else {
				if ((_slug isNotEqualTo '') && {!_lastWasSeparator}) then {
					_slug = _slug + '_';
					_lastWasSeparator = TRUE;
				};
			};
		} forEach (toArray _value);
		if (_lastWasSeparator) then {
			_slug = _slug select [0,(count _slug) - 1];
		};
		if (_slug isEqualTo '') then {
			_slug = 'skin';
		};
		toLowerANSI _slug
	};
	if (missionNamespace getVariable ['QS_server_isUsingDB',FALSE]) then {
		try {
			private _rows = ['getPlayerCosmeticSkins',[_uid]] call TGC_fnc_dbQuery;
			{
				_x params [['_displayName',''],['_fileName','']];
				private _normalizedFileName = toLowerANSI _fileName;
				if (
					(_displayName isNotEqualTo '') &&
					{(count _fileName) >= 4} &&
					{(_fileName find '\') isEqualTo -1} &&
					{(_fileName find '/') isEqualTo -1} &&
					{_normalizedFileName select [(count _normalizedFileName) - 4,4] isEqualTo '.paa'}
				) then {
					_skins pushBack [
						_displayName,
						[
							format ['media\commissary\%1',_fileName],
							format ['media\commissary\%1.paa',[_displayName] call _fn_slugify]
						]
					];
				};
			} forEach _rows;
		} catch {
			diag_log format ['fn_serverGetDonatorSkins.sqf: Failed to load skins for %1: %2',_uid,_exception];
		};
	};

	if (
		(isNull _unit) ||
		{!isPlayer _unit} ||
		{(owner _unit) isNotEqualTo _requestOwner} ||
		{(getPlayerUID _unit) isNotEqualTo _uid}
	) exitWith {};
	['Data',_skins] remoteExecCall ['QS_fnc_clientMenuDonatorSkins',_requestOwner];
};
