/*
File: fn_serverEventHandler.sqf
Author:
	
	Quiksilver
	
Last Modified:
	
	5/10/2023 A3 2.14 by Quiksilver
	
Description:

	Server Event handler - Handles events from server.cfg file
	
Notes:

	users	User	List users, each user is described as an array in format [id, name]
	kick userId reason	User	Kick off given user id from the server, with an optional text
	ban userId reason	User	Add given user id into the ban list, with an optional text
	unkick userId	User	Remove a kick from the server's list
	unban userId	User	Remove a ban from the server's list
	clearKicks	User	Clear all existing kicks from the server's list
	clearBans	User	Clear all existing bans from the server's list
	numberOfFiles userId	File	number of addons files used for given player - can be used to determine suitable values for checkFile
	level checkFile [userId, fileIndex]	File	See Addon Signature for a file with given index on given user computer, level determines test depth (0 = default, 1 = deep. Note: deep can be very slow)
	level checkExe userId	File	Start the integrity check of game executable for given user. Level defines how exhaustive the test should be
	lock	Game	Lock/unlock the session
________________________________________________*/

params ['_type','_params'];
private _fn_kickSignatureUserOnce = {
	params ['_userID'];
	private _state = serverNamespace getVariable ['QS_signatureKickState',createHashMap];
	private _key = str _userID;
	private _now = diag_tickTime;
	if ((count _state) > 256) then {
		{
			if ((_state get _x) <= _now) then {
				_state deleteAt _x;
			};
		} forEach (keys _state);
	};
	private _nextAllowed = _state getOrDefault [_key,-1];
	if (_nextAllowed > _now) exitWith {FALSE};
	_state set [_key,(_now + 30)];
	serverNamespace setVariable ['QS_signatureKickState',_state];
	(call (uiNamespace getVariable 'QS_fnc_serverCommandPassword')) serverCommand (format ['#kick %1',_userID]);
	TRUE
};
if (_type isEqualTo 'regularCheck') exitWith {
	_params params ['_userID','_testIndex'];
	''
};
if (!(_type in ['onUnsignedData','onHackedData','onDifferentData'])) then {
	diag_log str _this;	// Debug
};
if (_type isEqualTo 'sendChatMessage') exitWith {
	_params params ['_userID','_message'];
	''
};
if (_type isEqualTo 'doubleIdDetected') exitWith {
	_params params ['_userID'];
	''
};
if (_type isEqualTo 'onUserConnected') exitWith {
	_params params ['_userID'];
	''
};
if (_type isEqualTo 'onUserDisconnected') exitWith {
	_params params ['_userID'];
	private _state = serverNamespace getVariable ['QS_signatureKickState',createHashMap];
	_state deleteAt (str _userID);
	serverNamespace setVariable ['QS_signatureKickState',_state];
	''
};
if (_type isEqualTo 'onUnsignedData') exitWith {
	_params params ['_userID','_fileName'];
	[_userID] call _fn_kickSignatureUserOnce;
};
if (_type isEqualTo 'onHackedData') exitWith {
	_params params ['_userID','_fileName'];
	[_userID] call _fn_kickSignatureUserOnce;
};
if (_type isEqualTo 'onDifferentData') exitWith {
	_params params ['_userID','_fileName'];
	[_userID] call _fn_kickSignatureUserOnce;
};
if (_type isEqualTo 'onUserKicked') exitWith {
	_params params ['_userID','_kickTypeID','_kickReason'];
};
if (_type isEqualTo 'onPlayerJoinAttempt') exitWith {
	_params params ['_userID','_waitTime'];
	'ACCEPT'
};
