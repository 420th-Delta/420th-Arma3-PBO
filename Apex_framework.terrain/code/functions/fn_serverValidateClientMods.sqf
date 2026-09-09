/*
File: fn_serverValidateClientMods.sqf

Description:

	Kick clients that report a non-official mod whose Workshop ID is not
	approved and whose full hash is not approved in @Apex_cfg\parameters.sqf.
__________________________________________________*/

if ((!isServer) || {!isRemoteExecuted}) exitWith {};

private _clientOwner = remoteExecutedOwner;
if (_clientOwner <= 2) exitWith {};

params [['_clientWorkshopMods',[],[[]]]];
private _allowedWorkshopIDs = missionNamespace getVariable ['QS_missionConfig_allowedClientWorkshopIds',[]];
private _allowedModHashes = missionNamespace getVariable ['QS_missionConfig_allowedClientModHashes',[]];

private _disallowedMods = [];
{
	if ((_x isEqualType []) && {(count _x) >= 2}) then {
		private _workshopID = _x param [0,'',['']];
		private _modName = _x param [1,'',['']];
		private _modHash = _x param [2,'',['']];
		private _workshopAllowed = (_workshopID isNotEqualTo '') && {_workshopID isNotEqualTo '0'} && {_workshopID in _allowedWorkshopIDs};
		private _hashAllowed = (_modHash isNotEqualTo '') && {_modHash in _allowedModHashes};
		if ((!_workshopAllowed) && {!_hashAllowed}) then {
			_disallowedMods pushBack [_workshopID,_modName,_modHash];
		};
	};
} forEach _clientWorkshopMods;

if (_disallowedMods isEqualTo []) exitWith {};

private _disallowedLabels = [];
{
	_x params ['_workshopID','_modName'];

	// Only put printable ASCII in a server command and bound each mod name.
	private _safeModName = toString ((toArray _modName) select {
		(_x >= 32) && {_x <= 126} && {_x isNotEqualTo 34} && {_x isNotEqualTo 35}
	});
	_safeModName = _safeModName select [0,80];
	private _fallbackID = [_workshopID,'0'] select (_workshopID isEqualTo '');
	_disallowedLabels pushBack ([_fallbackID,_safeModName] select (_safeModName isNotEqualTo ''));
} forEach _disallowedMods;

diag_log format [
	'***** CLIENT MODS REJECTED ***** owner %1 * mods %2 *****',
	_clientOwner,
	_disallowedMods
];

private _kickReason = format ['Kicked : Mods not allowed: %1',_disallowedLabels joinString ', '];
[_kickReason] remoteExecCall ['QS_fnc_clientModKickWarning',_clientOwner,FALSE];

[_clientOwner,_kickReason] spawn {
	params ['_clientOwner','_kickReason'];
	uiSleep 5;
	(call (uiNamespace getVariable 'QS_fnc_serverCommandPassword')) serverCommand format [
		'#kick "%1" "%2"',
		_clientOwner,
		_kickReason
	];
};
