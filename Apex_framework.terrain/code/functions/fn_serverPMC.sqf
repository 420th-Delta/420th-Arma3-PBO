/*
File: fn_serverPMC.sqf
Description: Server-authoritative persistent Private Military Company service.
*/
if (!isServer || {!isRemoteExecuted}) exitWith {};
params [['_mode',''],['_data',[]]];

private _requestOwner = remoteExecutedOwner;
private _unitIndex = allPlayers findIf {(owner _x) isEqualTo _requestOwner};
if (_unitIndex isEqualTo -1) exitWith {};
private _unit = allPlayers # _unitIndex;
private _uid = getPlayerUID _unit;
if ((count _uid) isNotEqualTo 17) exitWith {};

private _allowedModes = ['SYNC','CHECK_CREATE','CREATE','INVITE','RESPOND','LEAVE','RENAME','SAVE_RANK','EJECT','CHANGE_RANK','GET_PURCHASED_SKINS','GET_PMC_SKINS','ADD_SKIN','REMOVE_SKIN','TRANSFER','DISBAND'];
if !(_mode in _allowedModes) exitWith {};
if ((str _data) isEqualTo '' || {(count (str _data)) > 4096}) exitWith {};
private _now = diag_tickTime;
private _limits = serverNamespace getVariable ['QS_PMC_requestLimits',createHashMap];
if ((count _limits) > 256) then {_limits = createHashMap};
private _requestState = _limits getOrDefault [_requestOwner,[_now,0]];
_requestState params ['_windowStart','_requestCount'];
if ((_now - _windowStart) > 2) then {_windowStart = _now; _requestCount = 0};
_requestCount = _requestCount + 1;
_limits set [_requestOwner,[_windowStart,_requestCount]];
serverNamespace setVariable ['QS_PMC_requestLimits',_limits];
if (_requestCount > 10) exitWith {};

[_mode,_data,_unit,_uid,_requestOwner] spawn {
	params ['_mode','_data','_unit','_uid','_requestOwner'];
	private _fnNotice = {
		params ['_target','_text'];
		['NOTICE',_text] remoteExecCall ['QS_fnc_clientMenuPMC',_target];
	};
	private _fnCleanText = {
		params [['_value',''],['_maxLength',64]];
		private _clean = trim _value;
		private _allowed = toArray "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_.'";
		_clean = toString ((toArray _clean) select {_x in _allowed});
		if ((count _clean) > _maxLength) then {_clean = _clean select [0,_maxLength]};
		_clean
	};
	private _fnLoadPMC = {
		params ['_memberUID'];
		private _rows = ['getPMCForMember',[_memberUID]] call TGC_fnc_dbQuery;
		if (_rows isEqualTo []) exitWith {[]};
		private _pmc = _rows # 0;
		private _pmcID = _pmc # 0;
		private _members = ['getPMCMembers',[_pmcID]] call TGC_fnc_dbQuery;
		private _ranks = ['getPMCRanks',[_pmcID]] call TGC_fnc_dbQuery;
		private _skins = ['getPMCSkins',[_pmcID]] call TGC_fnc_dbQuery;
		[_pmc,_members,_ranks,_skins]
	};
	private _fnPermissions = {
		params ['_state','_memberUID'];
		if (_state isEqualTo []) exitWith {[FALSE,FALSE,FALSE,FALSE,FALSE,FALSE]};
		_state params ['_pmc','_members','_ranks'];
		private _memberIndex = _members findIf {(_x # 0) isEqualTo _memberUID};
		if (_memberIndex isEqualTo -1) exitWith {[FALSE,FALSE,FALSE,FALSE,FALSE,FALSE]};
		private _rankID = (_members # _memberIndex) # 2;
		private _rankIndex = _ranks findIf {(_x # 0) isEqualTo _rankID};
		if (_rankIndex isEqualTo -1) exitWith {[FALSE,FALSE,FALSE,FALSE,FALSE,FALSE]};
		private _rank = _ranks # _rankIndex;
		private _isOwner = _memberUID isEqualTo (_pmc # 2);
		private _isFounder = _memberUID isEqualTo (_pmc # 3);
		[_rank # 3,(_rank # 4) || {_isFounder},_rank # 5,_rank # 6,_isOwner,_isFounder]
	};
	private _fnHasDonatorStatus = {
		params ['_playerUID'];
		private _rows = ['getPlayerWhitelist',[_playerUID]] call TGC_fnc_dbQuery;
		(_rows isNotEqualTo []) && {(_rows # 0) param [12,FALSE]}
	};
	private _fnSendSnapshot = {
		params ['_target'];
		private _targetUID = getPlayerUID _target;
		private _state = [_targetUID] call _fnLoadPMC;
		private _snapshot = [];
		if (_state isNotEqualTo []) then {
			_state params ['_pmc','_members','_ranks','_skins'];
			_snapshot = [_pmc # 0,_pmc # 1,_pmc # 2,_pmc # 3,_members,_ranks,_skins,[_state,_targetUID] call _fnPermissions];
		};
		['SYNC',_snapshot] remoteExecCall ['QS_fnc_clientMenuPMC',_target];
	};
	private _fnPublishPMC = {
		params ['_pmcID'];
		{
			private _target = _x;
			private _rows = ['getPMCForMember',[getPlayerUID _target]] call TGC_fnc_dbQuery;
			if ((_rows isNotEqualTo []) && {((_rows # 0) # 0) isEqualTo _pmcID}) then {
				[_target] call _fnSendSnapshot;
			};
		} forEach allPlayers;
	};

	if !(missionNamespace getVariable ['QS_server_isUsingDB',FALSE]) exitWith {
		[_unit,'PMC data is currently unavailable.'] call _fnNotice;
	};

	try {
		if (_mode isEqualTo 'SYNC') exitWith {
			['updatePMCMemberName',[name _unit,_uid],FALSE] call TGC_fnc_dbQuery;
			[_unit] call _fnSendSnapshot;
			{
				_x params ['_pmcID','_pmcName','_inviterUID','_secondsRemaining'];
				['INVITE_OFFER',[_pmcID,_pmcName,_inviterUID,serverTime + _secondsRemaining]] remoteExecCall ['QS_fnc_clientMenuPMC',_unit];
			} forEach (['getPMCInvites',[_uid]] call TGC_fnc_dbQuery);
		};
		if (_mode isEqualTo 'CHECK_CREATE') exitWith {
			private _active = [_uid] call _fnHasDonatorStatus;
			if (_active) then {
				['CREATE_ALLOWED',[]] remoteExecCall ['QS_fnc_clientMenuPMC',_unit];
			} else {
				[_unit,'You must have an active Donator Status subscription to create a PMC.'] call _fnNotice;
			};
		};

		private _state = [_uid] call _fnLoadPMC;
		if (_mode isEqualTo 'CREATE') exitWith {
			if (_state isNotEqualTo []) exitWith {[_unit,'You are already a member of a PMC.'] call _fnNotice};
			private _name = [_data,64] call _fnCleanText;
			if (_name isEqualTo '') exitWith {[_unit,'Please enter a PMC name before creating.'] call _fnNotice};
			private _active = [_uid] call _fnHasDonatorStatus;
			if (!_active) exitWith {[_unit,'You must have an active Donator Status subscription to create a PMC.'] call _fnNotice};
			['createPMC',[_name,_uid,_uid]] call TGC_fnc_dbQuery;
			['updatePMCMemberName',[name _unit,_uid],FALSE] call TGC_fnc_dbQuery;
			[_unit] call _fnSendSnapshot;
			[_unit,format ['PMC "%1" created.',_name]] call _fnNotice;
		};

		if (_mode isEqualTo 'RESPOND') exitWith {
			_data params [['_pmcID',0],['_accepted',FALSE]];
			private _invites = ['getPMCInvites',[_uid]] call TGC_fnc_dbQuery;
			private _inviteIndex = _invites findIf {(_x # 0) isEqualTo _pmcID};
			if (_inviteIndex isEqualTo -1) exitWith {[_unit,'That PMC invitation is no longer valid.'] call _fnNotice};
			if (_accepted && {_state isNotEqualTo []}) exitWith {
				['deletePMCInvite',[_pmcID,_uid],FALSE] call TGC_fnc_dbQuery;
				[_unit,'You are already a member of a PMC. Please leave your current PMC before joining a new one.'] call _fnNotice;
			};
			['deletePMCInvite',[_pmcID,_uid],FALSE] call TGC_fnc_dbQuery;
			if (_accepted) then {
				['addPMCMember',[_pmcID,_uid,name _unit,_pmcID]] call TGC_fnc_dbQuery;
				[_pmcID] call _fnPublishPMC;
				[_unit,'PMC invitation accepted.'] call _fnNotice;
			} else {
				[_unit,'PMC invitation rejected.'] call _fnNotice;
			};
		};

		if (_state isEqualTo []) exitWith {
			if (_mode isEqualTo 'GET_PMC_SKINS') then {['PMC_SKINS_DATA',[]] remoteExecCall ['QS_fnc_clientMenuPMC',_unit]};
			[_unit,'You are not a member of a PMC.'] call _fnNotice
		};
		_state params ['_pmc','_members','_ranks','_skins'];
		_pmc params ['_pmcID','_pmcName','_ownerUID','_founderUID'];
		private _permissions = [_state,_uid] call _fnPermissions;
		_permissions params ['_canInvite','_canMembers','_canRanks','_canSkins','_isOwner','_isFounder'];
		private _actorIndex = _members findIf {(_x # 0) isEqualTo _uid};
		private _actorHierarchy = if (_actorIndex isEqualTo -1) then {-1} else {(_members # _actorIndex) # 4};

		if (_mode isEqualTo 'GET_PMC_SKINS') exitWith {
			private _resolvedSkins = [];
			private _fnSlugify = {
				params ['_value'];
				private _slug = '';
				private _lastWasSeparator = FALSE;
				{
					private _isAlphaNumeric = (((_x >= 48) && {_x <= 57}) || {((_x >= 65) && {_x <= 90})} || {((_x >= 97) && {_x <= 122})});
					if (_isAlphaNumeric) then {
						_slug = _slug + (toString [_x]);
						_lastWasSeparator = FALSE;
					} else {
						if ((_slug isNotEqualTo '') && {!_lastWasSeparator}) then {_slug = _slug + '_'; _lastWasSeparator = TRUE};
					};
				} forEach (toArray _value);
				if (_lastWasSeparator) then {_slug = _slug select [0,(count _slug) - 1]};
				if (_slug isEqualTo '') then {_slug = 'skin'};
				toLowerANSI _slug
			};
			private _fnIsPaa = {
				params ['_fileName'];
				private _normalized = toLowerANSI _fileName;
				((count _fileName) >= 4) && {_normalized select [(count _normalized) - 4,4] isEqualTo '.paa'}
			};
			{
				_x params ['_skinID','_displayName','_fileName','_vehicleName','_vehicleClassIDs','_texturePathList'];
				private _fileNames = [];
				{if ([_x] call _fnIsPaa) then {_fileNames pushBackUnique _x}} forEach (_texturePathList splitString (toString [9,10,13,32,34,44,47,91,92,93]));
				if ((_fileNames isEqualTo []) && {[_fileName] call _fnIsPaa}) then {_fileNames pushBack _fileName};
				if ((_displayName isNotEqualTo '') && {_fileNames isNotEqualTo []}) then {
					private _textureSlots = _fileNames apply {[format ['media\commissary\%1',_x]]};
					if ((count _textureSlots) isEqualTo 1) then {(_textureSlots # 0) pushBackUnique format ['media\commissary\%1.paa',[_displayName] call _fnSlugify]};
					_resolvedSkins pushBack [_displayName,_textureSlots,_vehicleName,(_vehicleClassIDs splitString ', ') select {_x isNotEqualTo ''}];
				};
			} forEach _skins;
			['PMC_SKINS_DATA',_resolvedSkins] remoteExecCall ['QS_fnc_clientMenuPMC',_unit];
		};

		if (_mode isEqualTo 'INVITE') exitWith {
			if (!_canInvite) exitWith {[_unit,'Your PMC rank cannot invite players.'] call _fnNotice};
			private _targetUID = _data;
			private _targetIndex = allPlayers findIf {(getPlayerUID _x) isEqualTo _targetUID};
			if (_targetIndex isEqualTo -1) exitWith {[_unit,'That player is no longer online.'] call _fnNotice};
			if (([_targetUID] call _fnLoadPMC) isNotEqualTo []) exitWith {[_unit,'That player is already a member of a PMC.'] call _fnNotice};
			['createPMCInvite',[_pmcID,_targetUID,_uid]] call TGC_fnc_dbQuery;
			private _target = allPlayers # _targetIndex;
			['INVITE_OFFER',[_pmcID,_pmcName,_uid,serverTime + 60]] remoteExecCall ['QS_fnc_clientMenuPMC',_target];
			[_unit,format ['Invitation sent to %1.',name _target]] call _fnNotice;
		};
		if (_mode isEqualTo 'LEAVE') exitWith {
			if (_isOwner) exitWith {[_unit,'PMC owners cannot leave their PMC. Disband the PMC or transfer ownership.'] call _fnNotice};
			['leavePMC',[_pmcID,_uid]] call TGC_fnc_dbQuery;
			[_unit] call _fnSendSnapshot;
			[_pmcID] call _fnPublishPMC;
		};
		if (_mode isEqualTo 'RENAME') exitWith {
			if (!_isOwner) exitWith {[_unit,'Only the PMC owner can change its name.'] call _fnNotice};
			private _name = [_data,64] call _fnCleanText;
			if (_name isEqualTo '') exitWith {[_unit,'Please enter a PMC name before saving.'] call _fnNotice};
			['renamePMC',[_name,_pmcID]] call TGC_fnc_dbQuery;
			[_pmcID] call _fnPublishPMC;
		};
		if (_mode isEqualTo 'SAVE_RANK') exitWith {
			if (!_canRanks) exitWith {[_unit,'Your PMC rank cannot manage ranks.'] call _fnNotice};
			_data params [['_rankID',0],['_rankName',''],['_hierarchy',0],['_invite',FALSE],['_membersPermission',FALSE],['_ranksPermission',FALSE],['_skinsPermission',FALSE]];
			_rankName = [_rankName,40] call _fnCleanText;
			_hierarchy = (round _hierarchy) max 0 min 10;
			if (_rankName isEqualTo '') exitWith {[_unit,'Please enter a rank name.'] call _fnNotice};
			if (_rankID isEqualTo 0) then {
				if (!_isOwner && {!_isFounder} && {_hierarchy >= _actorHierarchy}) exitWith {[_unit,'You cannot create a rank equal to or above your own hierarchy.'] call _fnNotice};
				['createPMCRank',[_pmcID,_rankName,_hierarchy,_invite,_membersPermission,_ranksPermission,_skinsPermission]] call TGC_fnc_dbQuery;
			} else {
				private _rankIndex = _ranks findIf {(_x # 0) isEqualTo _rankID};
				if (_rankIndex isEqualTo -1) exitWith {};
				private _rank = _ranks # _rankIndex;
				if (!_isOwner && {!_isFounder} && {(_rank # 2) >= _actorHierarchy}) exitWith {[_unit,'You cannot modify a rank equal to or above your own hierarchy.'] call _fnNotice};
				['updatePMCRank',[_rankName,_hierarchy,_invite,_membersPermission,_ranksPermission,_skinsPermission,_rankID,_pmcID]] call TGC_fnc_dbQuery;
			};
			[_pmcID] call _fnPublishPMC;
		};
		if (_mode in ['EJECT','CHANGE_RANK']) exitWith {
			if (!_canMembers) exitWith {[_unit,'Your PMC rank cannot manage members.'] call _fnNotice};
			private _targetUID = if (_mode isEqualTo 'EJECT') then {_data} else {_data param [0,'']};
			private _targetIndex = _members findIf {(_x # 0) isEqualTo _targetUID};
			if (_targetIndex isEqualTo -1) exitWith {};
			private _targetMember = _members # _targetIndex;
			if (_targetUID isEqualTo _founderUID && {!_isFounder}) exitWith {[_unit,'The PMC founder cannot be modified by another member.'] call _fnNotice};
			if ((_mode isEqualTo 'CHANGE_RANK') && {_targetUID isEqualTo _ownerUID}) exitWith {[_unit,'Transfer ownership instead of changing the owner rank.'] call _fnNotice};
			if (!_isOwner && {!_isFounder} && {(_targetMember # 4) >= _actorHierarchy}) exitWith {[_unit,'You cannot manage a member with an equal or higher rank.'] call _fnNotice};
			if (_mode isEqualTo 'EJECT') then {
				if (_targetUID isEqualTo _ownerUID) exitWith {[_unit,'The PMC owner cannot be ejected.'] call _fnNotice};
				['ejectPMCMember',[_pmcID,_targetUID]] call TGC_fnc_dbQuery;
				private _onlineIndex = allPlayers findIf {(getPlayerUID _x) isEqualTo _targetUID};
				if (_onlineIndex isNotEqualTo -1) then {[allPlayers # _onlineIndex] call _fnSendSnapshot};
			} else {
				private _newRankID = _data param [1,0];
				private _rankIndex = _ranks findIf {(_x # 0) isEqualTo _newRankID};
				if (_rankIndex isEqualTo -1) exitWith {};
				private _newRank = _ranks # _rankIndex;
				if ((_newRank # 7) && {!_isOwner}) exitWith {[_unit,'Only the Owner rank can promote a member to Owner.'] call _fnNotice};
				if (!_isOwner && {!_isFounder} && {(_newRank # 2) >= _actorHierarchy}) exitWith {[_unit,'You cannot assign a rank equal to or above your own hierarchy.'] call _fnNotice};
				['changePMCMemberRank',[_newRankID,_pmcID,_targetUID]] call TGC_fnc_dbQuery;
			};
			[_pmcID] call _fnPublishPMC;
		};
		if (_mode isEqualTo 'GET_PURCHASED_SKINS') exitWith {
			if (!_canSkins) exitWith {[_unit,'Your PMC rank cannot manage skins.'] call _fnNotice};
			private _rows = ['getPlayerCosmeticSkins',[_uid]] call TGC_fnc_dbQuery;
			['PURCHASED_SKINS',_rows] remoteExecCall ['QS_fnc_clientMenuPMC',_unit];
		};
		if (_mode isEqualTo 'ADD_SKIN') exitWith {
			if (!_canSkins) exitWith {[_unit,'Your PMC rank cannot manage skins.'] call _fnNotice};
			private _skinName = _data;
			private _rows = ['getPlayerCosmeticSkins',[_uid]] call TGC_fnc_dbQuery;
			private _skinIndex = _rows findIf {(_x # 0) isEqualTo _skinName};
			if (_skinIndex isEqualTo -1) exitWith {[_unit,'That skin is not available on your account.'] call _fnNotice};
			private _skin = _rows # _skinIndex;
			['addPMCSkin',[_pmcID,_skin # 0,_skin # 1,_skin # 2,_skin # 3,_skin # 4,_uid]] call TGC_fnc_dbQuery;
			[_pmcID] call _fnPublishPMC;
		};
		if (_mode isEqualTo 'REMOVE_SKIN') exitWith {
			if (!_canSkins) exitWith {[_unit,'Your PMC rank cannot manage skins.'] call _fnNotice};
			['removePMCSkin',[_data,_pmcID]] call TGC_fnc_dbQuery;
			[_pmcID] call _fnPublishPMC;
		};
		if (_mode isEqualTo 'TRANSFER') exitWith {
			if (!_isOwner) exitWith {[_unit,'Only the PMC owner can transfer ownership.'] call _fnNotice};
			private _targetUID = _data;
			if ((_members findIf {(_x # 0) isEqualTo _targetUID}) isEqualTo -1 || {_targetUID isEqualTo _uid}) exitWith {};
			['transferPMCOwnership',[_pmcID,_uid,_targetUID]] call TGC_fnc_dbQuery;
			[_pmcID] call _fnPublishPMC;
		};
		if (_mode isEqualTo 'DISBAND') exitWith {
			if (!_isOwner) exitWith {[_unit,'Only the PMC owner can disband it.'] call _fnNotice};
			private _affected = +_members;
			['disbandPMC',[_pmcID,_uid]] call TGC_fnc_dbQuery;
			{
				private _memberUID = _x # 0;
				private _targetIndex = allPlayers findIf {(getPlayerUID _x) isEqualTo _memberUID};
				if (_targetIndex isNotEqualTo -1) then {[allPlayers # _targetIndex] call _fnSendSnapshot};
			} forEach _affected;
		};
	} catch {
		diag_log format ['fn_serverPMC.sqf: %1 failed for %2: %3',_mode,_uid,_exception];
		private _errorMessage = switch (_mode) do {
			case 'CHECK_CREATE': {'The server could not verify your Donator Status. Please try again.'};
			case 'CREATE': {'The PMC could not be created. The name may already be in use.'};
			default {'The PMC request could not be completed.'};
		};
		[_unit,_errorMessage] call _fnNotice;
	};
};
