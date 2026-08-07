/*
File: fn_serverPrivateChannels.sqf

Description:
	Server-authoritative private voice and text channel management.
	Engine channels are allocated only while at least two members are online.
__________________________________________________________________________*/

if (!isServer) exitWith {};
if !(missionNamespace getVariable ['QS_privateChannels_enabled',FALSE]) exitWith {};
params [['_mode',''],['_data',[]]];

private _channels = missionNamespace getVariable ['QS_privateChannels_server',[]];
private _invites = missionNamespace getVariable ['QS_privateChannelInvites_server',[]];
private _channelPool = missionNamespace getVariable ['QS_privateChannelPool_server',[]];
_invites = _invites select {(_x # 2) >= serverTime};
private _requestOwner = remoteExecutedOwner;
private _requestUnit = objNull;
private _requestUID = '';
private _ignoredUID = if (_mode isEqualTo 'DISCONNECT') then {_data} else {''};

private _requestIndex = allPlayers findIf {(owner _x) isEqualTo _requestOwner};
if (_requestIndex isNotEqualTo -1) then {
	_requestUnit = allPlayers # _requestIndex;
	_requestUID = getPlayerUID _requestUnit;
};

private _fnSanitizeName = {
	params [['_name','Private Channel']];
	if !(_name isEqualType '') then {
		_name = 'Private Channel';
	};
	private _characters = (toArray _name) select {(_x >= 32) && (_x <= 126)};
	if ((count _characters) > 32) then {
		_characters resize 32;
	};
	_name = trim (toString _characters);
	if (_name isEqualTo '') then {
		_name = 'Private Channel';
	};
	_name
};

private _fnNotice = {
	params ['_target','_message'];
	['NOTICE',_message] remoteExecCall ['QS_fnc_clientMenuPrivateChannels',_target];
};

private _fnOnlineUnits = {
	params ['_members'];
	private _onlineUnits = [];
	{
		private _memberUID = _x # 0;
		if (_memberUID isNotEqualTo _ignoredUID) then {
			private _onlineIndex = allPlayers findIf {(getPlayerUID _x) isEqualTo _memberUID};
			if (_onlineIndex isNotEqualTo -1) then {
				_onlineUnits pushBack (allPlayers # _onlineIndex);
			};
		};
	} forEach _members;
	_onlineUnits
};

private _fnAddUnitsToChannel = {
	params [['_channelID',0],['_units',[]]];
	if (_channelID <= 0) exitWith {};
	{
		['CHANNEL_ADD',_channelID] remoteExecCall ['QS_fnc_clientMenuPrivateChannels',_x];
	} forEach _units;
};

private _fnRemoveUnitsFromChannel = {
	params [['_channelID',0],['_units',[]]];
	if (_channelID <= 0) exitWith {};
	{
		['CHANNEL_REMOVE',_channelID] remoteExecCall ['QS_fnc_clientMenuPrivateChannels',_x];
	} forEach _units;
};

private _fnReleaseChannel = {
	params [['_channelID',0]];
	if (_channelID <= 0) exitWith {};

	[_channelID,allPlayers] call _fnRemoveUnitsFromChannel;
	_channelID radioChannelSetLabel 'Private Channel (Available)';
	_channelPool pushBackUnique _channelID;
};

private _fnReconcile = {
	// Release channels first so their slots are immediately available to other channels.
	{
		_x params ['_ownerUID','_ownerName','_name','_members','_channelID','_color'];
		private _onlineUnits = [_members] call _fnOnlineUnits;
		if (((count _onlineUnits) < 2) && {_channelID > 0}) then {
			[_channelID] call _fnReleaseChannel;
			_x set [4,0];
		};
	} forEach _channels;

	{
		_x params ['_ownerUID','_ownerName','_name','_members','_channelID','_color'];
		private _onlineUnits = [_members] call _fnOnlineUnits;
		if ((count _onlineUnits) >= 2) then {
			if (_channelID isEqualTo 0) then {
				if (_channelPool isNotEqualTo []) then {
					_channelID = _channelPool deleteAt ((count _channelPool) - 1);
					_channelID radioChannelSetLabel _name;
				} else {
					_channelID = radioChannelCreate [_color,_name,'%UNIT_NAME',[],TRUE];
					if (_channelID isEqualTo 0) then {
						if !(missionNamespace getVariable ['QS_privateChannels_capacityLogged',FALSE]) then {
							missionNamespace setVariable ['QS_privateChannels_capacityLogged',TRUE,FALSE];
							private _allChannelInfo = radioChannelInfo FALSE;
							private _usedChannelInfo = radioChannelInfo TRUE;
							diag_log format [
								'***** PRIVATE CHANNELS ***** Allocation failed for "%1" (%2 online members). Engine version: %3. Reported custom-channel capacity: %4. Channels in use: %5. Used labels: %6.',
								_name,
								count _onlineUnits,
								productVersion,
								count _allChannelInfo,
								count _usedChannelInfo,
								_usedChannelInfo apply {_x param [1,'']}
							];
						};
					};
				};
				_x set [4,_channelID];
			};
			[_channelID,_onlineUnits] call _fnAddUnitsToChannel;
		};
	} forEach _channels;
};

private _fnPublish = {
	missionNamespace setVariable ['QS_privateChannels_server',_channels,FALSE];
	missionNamespace setVariable ['QS_privateChannelInvites_server',_invites,FALSE];
	missionNamespace setVariable ['QS_privateChannelPool_server',_channelPool,FALSE];
	{
		private _targetUnit = _x;
		private _targetUID = getPlayerUID _targetUnit;
		private _snapshot = [];
		{
			_x params ['_ownerUID','_ownerName','_name','_members','_channelID','_color'];
			if ((_members findIf {(_x # 0) isEqualTo _targetUID}) isNotEqualTo -1) then {
				private _memberSnapshot = _members apply {
					private _memberUID = _x # 0;
					[
						_memberUID,
						_x # 1,
						((allPlayers findIf {(getPlayerUID _x) isEqualTo _memberUID}) isNotEqualTo -1)
					]
				};
				_snapshot pushBack [_ownerUID,_ownerName,_name,_memberSnapshot,_channelID];
			};
		} forEach _channels;
		['SYNC',_snapshot] remoteExecCall ['QS_fnc_clientMenuPrivateChannels',_targetUnit];
	} forEach allPlayers;
};

if (_mode isEqualTo 'SERVER_SYNC') exitWith {
	if (!isNull _data && {isPlayer _data}) then {
		private _syncUID = getPlayerUID _data;
		{
			if ((_x # 0) isEqualTo _syncUID) then {
				_x set [1,name _data];
			};
			private _members = _x # 3;
			private _memberIndex = _members findIf {(_x # 0) isEqualTo _syncUID};
			if (_memberIndex isNotEqualTo -1) then {
				(_members # _memberIndex) set [1,name _data];
			};
		} forEach _channels;
		call _fnReconcile;
		call _fnPublish;
	};
};

if (_mode isEqualTo 'DISCONNECT') exitWith {
	call _fnReconcile;
	call _fnPublish;
};

if (isNull _requestUnit || {_requestUID isEqualTo ''}) exitWith {
	diag_log format [
		'***** PRIVATE CHANNELS ***** Rejected %1 request from network owner %2: no matching player unit.',
		_mode,
		_requestOwner
	];
};

if (_mode isEqualTo 'SYNC') exitWith {
	call _fnReconcile;
	call _fnPublish;
	{
		_x params ['_ownerUID','_targetUID','_expiresAt'];
		if ((_targetUID isEqualTo _requestUID) && {_expiresAt >= serverTime}) then {
			private _channelIndex = _channels findIf {(_x # 0) isEqualTo _ownerUID};
			if (_channelIndex isNotEqualTo -1) then {
				private _channel = _channels # _channelIndex;
				['INVITE_OFFER',[_ownerUID,_channel # 1,_channel # 2,_expiresAt]] remoteExecCall ['QS_fnc_clientMenuPrivateChannels',_requestUnit];
			};
		};
	} forEach _invites;
};

if (_mode isEqualTo 'CREATE') exitWith {
	if ((_channels findIf {(_x # 0) isEqualTo _requestUID}) isNotEqualTo -1) exitWith {
		[_requestUnit,'You may create only one private channel.'] call _fnNotice;
	};
	private _name = [_data] call _fnSanitizeName;
	private _color = [0.2,0.2,0.2,1];
	_channels pushBack [_requestUID,name _requestUnit,_name,[[_requestUID,name _requestUnit]],0,_color];
	call _fnReconcile;
	call _fnPublish;
	[_requestUnit,format ['Private channel "%1" created. It will activate when a second member is online.',_name]] call _fnNotice;
};

if (_mode in ['DELETE','LEAVE']) exitWith {
	private _channelIndex = _channels findIf {(_x # 0) isEqualTo _data};
	if (_channelIndex isEqualTo -1) exitWith {};
	private _channel = _channels # _channelIndex;
	_channel params ['_ownerUID','_ownerName','_name','_members','_channelID'];
	if ((_members findIf {(_x # 0) isEqualTo _requestUID}) isEqualTo -1) exitWith {};

	if ((_mode isEqualTo 'DELETE') || {_requestUID isEqualTo _ownerUID}) then {
		if (_requestUID isNotEqualTo _ownerUID) exitWith {};
		if (_channelID > 0) then {
			[_channelID] call _fnReleaseChannel;
		};
		_channels deleteAt _channelIndex;
		_invites = _invites select {(_x # 0) isNotEqualTo _ownerUID};
		[_requestUnit,format ['Private channel "%1" deleted.',_name]] call _fnNotice;
	} else {
		if (_channelID > 0) then {
			[_channelID,[_requestUnit]] call _fnRemoveUnitsFromChannel;
		};
		_members deleteAt (_members findIf {(_x # 0) isEqualTo _requestUID});
		_channel set [3,_members];
		[_requestUnit,format ['You left private channel "%1".',_name]] call _fnNotice;
	};
	call _fnReconcile;
	call _fnPublish;
};

if (_mode isEqualTo 'RENAME') exitWith {
	_data params [['_ownerUID',''],['_requestedName','']];
	private _channelIndex = _channels findIf {(_x # 0) isEqualTo _ownerUID};
	if ((_channelIndex isEqualTo -1) || {_requestUID isNotEqualTo _ownerUID}) exitWith {};
	private _name = [_requestedName] call _fnSanitizeName;
	private _channel = _channels # _channelIndex;
	_channel set [2,_name];
	if ((_channel # 4) > 0) then {
		(_channel # 4) radioChannelSetLabel _name;
	};
	call _fnPublish;
	[_requestUnit,format ['Private channel renamed to "%1".',_name]] call _fnNotice;
};

if (_mode isEqualTo 'INVITE') exitWith {
	_data params [['_ownerUID',''],['_targetUID','']];
	private _channelIndex = _channels findIf {(_x # 0) isEqualTo _ownerUID};
	if ((_channelIndex isEqualTo -1) || {_requestUID isNotEqualTo _ownerUID}) exitWith {};
	private _channel = _channels # _channelIndex;
	private _members = _channel # 3;
	if ((_members findIf {(_x # 0) isEqualTo _targetUID}) isNotEqualTo -1) exitWith {
		[_requestUnit,'That player already has access to the channel.'] call _fnNotice;
	};
	private _targetIndex = allPlayers findIf {
		((getPlayerUID _x) isEqualTo _targetUID) &&
		{(_targetUID select [0,2]) isNotEqualTo 'HC'}
	};
	if (_targetIndex isEqualTo -1) exitWith {
		[_requestUnit,'That player is no longer online.'] call _fnNotice;
	};
	private _target = allPlayers # _targetIndex;
	_invites = _invites select {!(((_x # 0) isEqualTo _ownerUID) && {(_x # 1) isEqualTo _targetUID})};
	private _expiresAt = serverTime + 120;
	_invites pushBack [_ownerUID,_targetUID,_expiresAt];
	missionNamespace setVariable ['QS_privateChannelInvites_server',_invites,FALSE];
	['INVITE_OFFER',[_ownerUID,name _requestUnit,_channel # 2,_expiresAt]] remoteExecCall ['QS_fnc_clientMenuPrivateChannels',_target];
	[_requestUnit,format ['Invitation sent to %1.',name _target]] call _fnNotice;
};

if (_mode isEqualTo 'RESPOND') exitWith {
	_data params [['_ownerUID',''],['_accepted',FALSE]];
	private _inviteIndex = _invites findIf {
		((_x # 0) isEqualTo _ownerUID) &&
		{((_x # 1) isEqualTo _requestUID)} &&
		{((_x # 2) >= serverTime)}
	};
	if (_inviteIndex isEqualTo -1) exitWith {
		[_requestUnit,'That private channel invitation is no longer valid.'] call _fnNotice;
	};
	_invites deleteAt _inviteIndex;
	private _channelIndex = _channels findIf {(_x # 0) isEqualTo _ownerUID};
	if (_channelIndex isEqualTo -1) exitWith {
		missionNamespace setVariable ['QS_privateChannelInvites_server',_invites,FALSE];
		[_requestUnit,'That private channel no longer exists.'] call _fnNotice;
	};
	private _channel = _channels # _channelIndex;
	if (_accepted) then {
		private _members = _channel # 3;
		if ((_members findIf {(_x # 0) isEqualTo _requestUID}) isEqualTo -1) then {
			_members pushBack [_requestUID,name _requestUnit];
			_channel set [3,_members];
		};
		[_requestUnit,format ['You joined private channel "%1".',_channel # 2]] call _fnNotice;
		private _ownerIndex = allPlayers findIf {(getPlayerUID _x) isEqualTo _ownerUID};
		if (_ownerIndex isNotEqualTo -1) then {
			[allPlayers # _ownerIndex,format ['%1 accepted your invitation.',name _requestUnit]] call _fnNotice;
		};
	} else {
		[_requestUnit,format ['You rejected the invitation to "%1".',_channel # 2]] call _fnNotice;
		private _ownerIndex = allPlayers findIf {(getPlayerUID _x) isEqualTo _ownerUID};
		if (_ownerIndex isNotEqualTo -1) then {
			[allPlayers # _ownerIndex,format ['%1 rejected your invitation.',name _requestUnit]] call _fnNotice;
		};
	};
	call _fnReconcile;
	call _fnPublish;
};

if (_mode isEqualTo 'EJECT') exitWith {
	_data params [['_ownerUID',''],['_targetUID','']];
	private _channelIndex = _channels findIf {(_x # 0) isEqualTo _ownerUID};
	if ((_channelIndex isEqualTo -1) || {_requestUID isNotEqualTo _ownerUID} || {_targetUID isEqualTo _ownerUID}) exitWith {};
	private _channel = _channels # _channelIndex;
	private _members = _channel # 3;
	private _memberIndex = _members findIf {(_x # 0) isEqualTo _targetUID};
	if (_memberIndex isEqualTo -1) exitWith {};
	private _memberName = (_members # _memberIndex) # 1;
	private _targetIndex = allPlayers findIf {(getPlayerUID _x) isEqualTo _targetUID};
	if ((_channel # 4) > 0 && {_targetIndex isNotEqualTo -1}) then {
		[_channel # 4,[allPlayers # _targetIndex]] call _fnRemoveUnitsFromChannel;
	};
	_members deleteAt _memberIndex;
	_channel set [3,_members];
	call _fnReconcile;
	call _fnPublish;
	[_requestUnit,format ['%1 was ejected from "%2".',_memberName,_channel # 2]] call _fnNotice;
	if (_targetIndex isNotEqualTo -1) then {
		[allPlayers # _targetIndex,format ['You were ejected from private channel "%1".',_channel # 2]] call _fnNotice;
	};
};
