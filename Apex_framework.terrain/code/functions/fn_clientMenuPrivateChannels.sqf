/*
File: fn_clientMenuPrivateChannels.sqf

Description:
	Client UI and invitation actions for private voice and text channels.
__________________________________________________________________________*/

disableSerialization;
params [['_mode',''],['_data',[]],['_extra',-1]];

private _fnRefresh = {
	private _display = uiNamespace getVariable ['QS_client_dialog_privateChannels',displayNull];
	if (isNull _display) exitWith {};
	private _channels = localNamespace getVariable ['QS_privateChannels_snapshot',[]];
	private _channelList = _display displayCtrl 4301;
	private _selectedOwner = localNamespace getVariable ['QS_privateChannels_selected',''];
	if ((lbCurSel _channelList) isNotEqualTo -1) then {
		_selectedOwner = _channelList lbData (lbCurSel _channelList);
	};
	lbClear _channelList;
	{
		_x params ['_ownerUID','_ownerName','_name','_members','_channelID'];
		private _row = _channelList lbAdd (format [
			'%1%2',
			_name,
			[' (waiting)',''] select (_channelID > 0)
		]);
		_channelList lbSetData [_row,_ownerUID];
		if (_ownerUID isEqualTo _selectedOwner) then {
			_channelList lbSetCurSel _row;
		};
	} forEach _channels;

	if ((lbCurSel _channelList) isEqualTo -1 && {(lbSize _channelList) > 0}) then {
		private _ownedIndex = _channels findIf {(_x # 0) isEqualTo (getPlayerUID player)};
		_channelList lbSetCurSel ([0,_ownedIndex] select (_ownedIndex isNotEqualTo -1));
	};
	if ((lbSize _channelList) isEqualTo 0) then {
		['SELECT_CHANNEL',_channelList,-1] call (missionNamespace getVariable 'QS_fnc_clientMenuPrivateChannels');
	};
};

if (_mode isEqualTo 'CHANNEL_ADD') exitWith {
	if (remoteExecutedOwner isNotEqualTo 2) exitWith {};
	if (_data > 0) then {
		_data radioChannelAdd [player];
	};
};

if (_mode isEqualTo 'CHANNEL_REMOVE') exitWith {
	if (remoteExecutedOwner isNotEqualTo 2) exitWith {};
	if (_data > 0) then {
		_data radioChannelRemove [player];
		if (currentChannel > 5) then {
			setCurrentChannel 5;
		};
	};
};

if (_mode isEqualTo 'SYNC') exitWith {
	localNamespace setVariable ['QS_privateChannels_snapshot',_data];
	call _fnRefresh;
};

if (_mode isEqualTo 'NOTICE') exitWith {
	[_data,TRUE] call (missionNamespace getVariable 'QS_fnc_hint');
	systemChat _data;
};

if (_mode isEqualTo 'INVITE_OFFER') exitWith {
	_data params ['_ownerUID','_ownerName','_channelName','_expiresAt'];
	private _offers = localNamespace getVariable ['QS_privateChannel_inviteActions',[]];
	private _oldIndex = _offers findIf {(_x # 0) isEqualTo _ownerUID};
	if (_oldIndex isNotEqualTo -1) then {
		{
			if (_x in (actionIDs player)) then {
				player removeAction _x;
			};
		} forEach ((_offers # _oldIndex) select [1,2]);
		_offers deleteAt _oldIndex;
	};
	private _acceptAction = player addAction [
		format ['Accept private channel: %1',_channelName],
		{
			params ['_target','_caller','','_ownerUID'];
			['RESPOND',[_ownerUID,TRUE]] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
			['CLEAR_INVITE',_ownerUID] call (missionNamespace getVariable 'QS_fnc_clientMenuPrivateChannels');
		},
		_ownerUID,
		50,
		FALSE,
		TRUE,
		'',
		'TRUE'
	];
	private _rejectAction = player addAction [
		format ['Reject private channel: %1',_channelName],
		{
			params ['_target','_caller','','_ownerUID'];
			['RESPOND',[_ownerUID,FALSE]] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
			['CLEAR_INVITE',_ownerUID] call (missionNamespace getVariable 'QS_fnc_clientMenuPrivateChannels');
		},
		_ownerUID,
		49,
		FALSE,
		TRUE,
		'',
		'TRUE'
	];
	_offers pushBack [_ownerUID,_acceptAction,_rejectAction,_expiresAt];
	localNamespace setVariable ['QS_privateChannel_inviteActions',_offers];
	private _message = format [
		'%1 invited you to private channel "%2". Use the Action menu to Accept or Reject. The invitation expires in 2 minutes.',
		_ownerName,
		_channelName
	];
	[_message,TRUE] call (missionNamespace getVariable 'QS_fnc_hint');
	systemChat _message;
	[_ownerUID,_expiresAt] spawn {
		params ['_ownerUID','_expiresAt'];
		uiSleep ((_expiresAt - serverTime) max 1);
		private _offers = localNamespace getVariable ['QS_privateChannel_inviteActions',[]];
		private _index = _offers findIf {
			((_x # 0) isEqualTo _ownerUID) && {((_x # 3) isEqualTo _expiresAt)}
		};
		if (_index isNotEqualTo -1) then {
			['CLEAR_INVITE',_ownerUID] call (missionNamespace getVariable 'QS_fnc_clientMenuPrivateChannels');
			private _message = 'A private channel invitation expired.';
			[_message,TRUE] call (missionNamespace getVariable 'QS_fnc_hint');
			systemChat _message;
		};
	};
};

if (_mode isEqualTo 'CLEAR_INVITE') exitWith {
	private _offers = localNamespace getVariable ['QS_privateChannel_inviteActions',[]];
	private _index = _offers findIf {(_x # 0) isEqualTo _data};
	if (_index isNotEqualTo -1) then {
		{
			if (_x in (actionIDs player)) then {
				player removeAction _x;
			};
		} forEach ((_offers # _index) select [1,2]);
		_offers deleteAt _index;
		localNamespace setVariable ['QS_privateChannel_inviteActions',_offers];
	};
};

if (_mode isEqualTo 'onLoad') exitWith {
	private _display = _data;
	uiNamespace setVariable ['QS_client_dialog_privateChannels',_display];
	setMousePosition (uiNamespace getVariable ['QS_ui_mousePosition',getMousePosition]);
	['SYNC',[]] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
	call _fnRefresh;
};

if (_mode isEqualTo 'onUnload') exitWith {
	uiNamespace setVariable ['QS_client_dialog_privateChannels',displayNull];
	uiNamespace setVariable ['QS_ui_mousePosition',getMousePosition];
};

if (_mode isEqualTo 'SELECT_CHANNEL') exitWith {
	private _control = _data;
	private _index = _extra;
	private _display = ctrlParent _control;
	if (isNull _display) then {
		_display = uiNamespace getVariable ['QS_client_dialog_privateChannels',displayNull];
	};
	if (isNull _display) exitWith {};
	private _channels = localNamespace getVariable ['QS_privateChannels_snapshot',[]];
	private _ownerUID = if (_index >= 0) then {_control lbData _index} else {''};
	localNamespace setVariable ['QS_privateChannels_selected',_ownerUID];
	private _channelIndex = _channels findIf {(_x # 0) isEqualTo _ownerUID};
	private _ownedIndex = _channels findIf {(_x # 0) isEqualTo (getPlayerUID player)};
	private _nameEdit = _display displayCtrl 4303;
	private _inviteButton = _display displayCtrl 4304;
	private _createButton = _display displayCtrl 4305;
	private _memberList = _display displayCtrl 4306;
	private _ejectButton = _display displayCtrl 4307;
	private _status = _display displayCtrl 4308;
	lbClear _memberList;
	_ejectButton ctrlEnable FALSE;

	if (_channelIndex isNotEqualTo -1) then {
		private _channel = _channels # _channelIndex;
		_channel params ['_selectedOwner','_ownerName','_name','_members','_channelID'];
		private _isOwner = _selectedOwner isEqualTo (getPlayerUID player);
		_nameEdit ctrlSetText _name;
		_nameEdit ctrlEnable _isOwner;
		_inviteButton ctrlEnable _isOwner;
		_createButton ctrlSetText (['Create','Delete'] select (_ownedIndex isNotEqualTo -1));
		_createButton ctrlEnable _isOwner;
		{
			_x params ['_memberUID','_memberName','_online'];
			private _row = _memberList lbAdd (format ['%1%2',_memberName,[' (Offline)',''] select _online]);
			_memberList lbSetData [_row,_memberUID];
		} forEach _members;
		private _onlineCount = {_x # 2} count _members;
		_status ctrlSetText (if (_channelID > 0) then {
			format ['Active engine channel ID: %1',_channelID]
		} else {
			[
				'Waiting for at least two members to be online',
				'Waiting for a free custom channel slot'
			] select (_onlineCount >= 2)
		});
	} else {
		_nameEdit ctrlSetText 'Private Channel';
		_nameEdit ctrlEnable (_ownedIndex isEqualTo -1);
		_inviteButton ctrlEnable FALSE;
		_createButton ctrlSetText 'Create';
		_createButton ctrlEnable (_ownedIndex isEqualTo -1);
		_status ctrlSetText (['Select your private channel to manage it.','No private channels available.'] select (_ownedIndex isEqualTo -1));
	};
};

if (_mode isEqualTo 'CREATE_DELETE') exitWith {
	private _display = ctrlParent _data;
	private _channels = localNamespace getVariable ['QS_privateChannels_snapshot',[]];
	private _ownedIndex = _channels findIf {(_x # 0) isEqualTo (getPlayerUID player)};
	if (_ownedIndex isEqualTo -1) then {
		['CREATE',ctrlText (_display displayCtrl 4303)] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
	} else {
		['DELETE',getPlayerUID player] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
	};
};

if (_mode isEqualTo 'RENAME') exitWith {
	private _display = ctrlParent _data;
	private _ownerUID = localNamespace getVariable ['QS_privateChannels_selected',''];
	if (_ownerUID isEqualTo (getPlayerUID player)) then {
		['RENAME',[_ownerUID,ctrlText (_display displayCtrl 4303)]] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
	};
};

if (_mode isEqualTo 'LEAVE') exitWith {
	private _display = ctrlParent _data;
	private _list = _display displayCtrl 4301;
	private _index = lbCurSel _list;
	if (_index isNotEqualTo -1) then {
		['LEAVE',_list lbData _index] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
	};
};

if (_mode isEqualTo 'MEMBER_SELECTED') exitWith {
	private _control = _data;
	private _index = _extra;
	private _display = ctrlParent _control;
	private _memberUID = if (_index >= 0) then {_control lbData _index} else {''};
	private _ownerUID = localNamespace getVariable ['QS_privateChannels_selected',''];
	(_display displayCtrl 4307) ctrlEnable (
		(_ownerUID isEqualTo (getPlayerUID player)) &&
		{_memberUID isNotEqualTo ''} &&
		{_memberUID isNotEqualTo _ownerUID}
	);
};

if (_mode isEqualTo 'EJECT') exitWith {
	private _display = ctrlParent _data;
	private _memberList = _display displayCtrl 4306;
	private _index = lbCurSel _memberList;
	private _ownerUID = localNamespace getVariable ['QS_privateChannels_selected',''];
	if (_index isNotEqualTo -1 && {_ownerUID isEqualTo (getPlayerUID player)}) then {
		['EJECT',[_ownerUID,_memberList lbData _index]] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
	};
};

if (_mode isEqualTo 'OPEN_INVITE') exitWith {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {!dialog};
		createDialog 'QS_RD_client_dialog_menu_privateChannelInvite';
	};
};

if (_mode isEqualTo 'INVITE_LOAD') exitWith {
	private _display = _data;
	uiNamespace setVariable ['QS_client_dialog_privateChannelInvite',_display];
	private _list = _display displayCtrl 4311;
	private _ownerUID = localNamespace getVariable ['QS_privateChannels_selected',''];
	private _channels = localNamespace getVariable ['QS_privateChannels_snapshot',[]];
	private _channelIndex = _channels findIf {(_x # 0) isEqualTo _ownerUID};
	private _memberUIDs = [];
	if (_channelIndex isNotEqualTo -1) then {
		_memberUIDs = ((_channels # _channelIndex) # 3) apply {_x # 0};
	};
	private _players = (allPlayers select {
		(isPlayer _x) &&
		{((getPlayerUID _x) select [0,2]) isNotEqualTo 'HC'} &&
		{(getPlayerUID _x) isNotEqualTo (getPlayerUID player)} &&
		{!((getPlayerUID _x) in _memberUIDs)}
	}) apply {[toLowerANSI (name _x),name _x,getPlayerUID _x]};
	_players sort TRUE;
	{
		private _row = _list lbAdd (_x # 1);
		_list lbSetData [_row,_x # 2];
	} forEach _players;
	if ((lbSize _list) > 0) then {
		_list lbSetCurSel 0;
	};
	(_display displayCtrl 4312) ctrlEnable ((lbSize _list) > 0);
};

if (_mode isEqualTo 'INVITE_SEND') exitWith {
	private _display = ctrlParent _data;
	private _list = _display displayCtrl 4311;
	private _index = lbCurSel _list;
	private _ownerUID = localNamespace getVariable ['QS_privateChannels_selected',''];
	if (_index isNotEqualTo -1 && {_ownerUID isEqualTo (getPlayerUID player)}) then {
		['INVITE',[_ownerUID,_list lbData _index]] remoteExecCall ['QS_fnc_serverPrivateChannels',2];
		closeDialog 2;
		0 spawn {
			uiSleep 0.1;
			waitUntil {!dialog};
			createDialog 'QS_RD_client_dialog_menu_privateChannels';
		};
	};
};

if (_mode isEqualTo 'INVITE_BACK') exitWith {
	closeDialog 2;
	0 spawn {
		uiSleep 0.1;
		waitUntil {!dialog};
		createDialog 'QS_RD_client_dialog_menu_privateChannels';
	};
};
