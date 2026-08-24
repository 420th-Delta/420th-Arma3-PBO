/*
File: fn_clientMenuPMC.sqf
Description: Client dialogs and invitation actions for Private Military Companies.
*/
disableSerialization;
params [['_mode',''],['_data',displayNull],['_extra',-1]];

private _fnHint = {
	params ['_text'];
	[_text,TRUE] call (missionNamespace getVariable 'QS_fnc_hint');
};
private _fnOpen = {
	params ['_dialog'];
	closeDialog 2;
	[_dialog] spawn {
		params ['_dialog'];
		uiSleep 0.1;
		waitUntil {!dialog};
		createDialog _dialog;
	};
};
private _fnState = {localNamespace getVariable ['QS_PMC_snapshot',[]]};

if (_mode isEqualTo 'NOTICE') exitWith {
	if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
	[_data] call _fnHint;
};
if (_mode isEqualTo 'SYNC') exitWith {
	if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
	localNamespace setVariable ['QS_PMC_snapshot',_data];
	private _display = uiNamespace getVariable ['QS_PMC_display',displayNull];
	if (!isNull _display) then {['REFRESH',_display] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC')};
	private _manageDisplay = findDisplay 55300;
	if (!isNull _manageDisplay) then {['MANAGE_LOAD',_manageDisplay] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC')};
	private _ranksDisplay = findDisplay 55500;
	if (!isNull _ranksDisplay) then {['RANKS_LOAD',_ranksDisplay] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC')};
	private _membersDisplay = findDisplay 55600;
	if (!isNull _membersDisplay) then {['MEMBERS_LOAD',_membersDisplay] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC')};
	private _skinsDisplay = findDisplay 55800;
	if (!isNull _skinsDisplay) then {['SKINS_LOAD',_skinsDisplay] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC')};
};
if (_mode isEqualTo 'INVITE_OFFER') exitWith {
	if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
	_data params ['_pmcID','_pmcName','_inviterUID','_expiresAt'];
	private _offers = localNamespace getVariable ['QS_PMC_inviteActions',[]];
	private _old = _offers findIf {(_x # 0) isEqualTo _pmcID};
	if (_old isNotEqualTo -1) then {
		{player removeAction _x} forEach ((_offers # _old) select [1,2]);
		_offers deleteAt _old;
	};
	private _accept = player addAction [
		'Accept PMC Invite',
		{params ['','','','_pmcID']; ['RESPOND',[_pmcID,TRUE]] remoteExecCall ['QS_fnc_serverPMC',2]; ['CLEAR_INVITE',_pmcID] call QS_fnc_clientMenuPMC},
		_pmcID,50,FALSE,TRUE,'','TRUE'
	];
	private _reject = player addAction [
		'Reject PMC Invite',
		{params ['','','','_pmcID']; ['RESPOND',[_pmcID,FALSE]] remoteExecCall ['QS_fnc_serverPMC',2]; ['CLEAR_INVITE',_pmcID] call QS_fnc_clientMenuPMC},
		_pmcID,49,FALSE,TRUE,'','TRUE'
	];
	_offers pushBack [_pmcID,_accept,_reject,_expiresAt];
	localNamespace setVariable ['QS_PMC_inviteActions',_offers];
	[format ['You have been invited to join "%1". Use the Action menu to Accept or Reject. The invitation expires in 60 seconds.',_pmcName]] call _fnHint;
	[_pmcID,_expiresAt] spawn {
		params ['_pmcID','_expiresAt'];
		uiSleep ((_expiresAt - serverTime) max 1);
		private _offers = localNamespace getVariable ['QS_PMC_inviteActions',[]];
		private _index = _offers findIf {((_x # 0) isEqualTo _pmcID) && {(_x # 3) isEqualTo _expiresAt}};
		if (_index isNotEqualTo -1) then {['CLEAR_INVITE',_pmcID] call QS_fnc_clientMenuPMC};
	};
};
if (_mode isEqualTo 'CLEAR_INVITE') exitWith {
	private _offers = localNamespace getVariable ['QS_PMC_inviteActions',[]];
	private _index = _offers findIf {(_x # 0) isEqualTo _data};
	if (_index isNotEqualTo -1) then {
		{player removeAction _x} forEach ((_offers # _index) select [1,2]);
		_offers deleteAt _index;
		localNamespace setVariable ['QS_PMC_inviteActions',_offers];
	};
};

if (_mode isEqualTo 'OPEN') exitWith {[_data] call _fnOpen};
if (_mode isEqualTo 'onLoad') exitWith {
	uiNamespace setVariable ['QS_PMC_display',_data];
	setMousePosition (uiNamespace getVariable ['QS_ui_mousePosition',getMousePosition]);
	['SYNC',[]] remoteExecCall ['QS_fnc_serverPMC',2];
	['REFRESH',_data] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC');
};
if (_mode isEqualTo 'onUnload') exitWith {
	uiNamespace setVariable ['QS_PMC_display',displayNull];
	uiNamespace setVariable ['QS_ui_mousePosition',getMousePosition];
};
if (_mode isEqualTo 'REFRESH') exitWith {
	private _display = _data;
	private _state = call _fnState;
	private _title = _display displayCtrl 5501;
	private _list = _display displayCtrl 5502;
	private _invite = _display displayCtrl 5503;
	private _leave = _display displayCtrl 5504;
	private _manage = _display displayCtrl 5505;
	private _create = _display displayCtrl 5506;
	lnbClear _list;
	if (_state isEqualTo []) then {
		_title ctrlSetText 'Create a PMC';
		{_x ctrlShow FALSE} forEach [_list,_invite,_leave,_manage];
		_create ctrlShow TRUE;
	} else {
		_state params ['_pmcID','_pmcName','_ownerUID','_founderUID','_members','_ranks','_skins','_permissions'];
		_title ctrlSetText _pmcName;
		_create ctrlShow FALSE;
		{_x ctrlShow TRUE} forEach [_list,_invite,_leave,_manage];
		{_list lnbAddRow [_x # 1,_x # 3]} forEach _members;
		_invite ctrlEnable (_permissions # 0);
		_manage ctrlEnable ((_permissions findIf {_x}) isNotEqualTo -1);
	};
};
if (_mode isEqualTo 'CREATE_OPEN') exitWith {
	['CHECK_CREATE',[]] remoteExecCall ['QS_fnc_serverPMC',2];
};
if (_mode isEqualTo 'CREATE_ALLOWED') exitWith {
	if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
	['QS_RD_client_dialog_pmc_create'] call _fnOpen;
};
if (_mode isEqualTo 'CREATE_SUBMIT') exitWith {
	private _name = ctrlText ((ctrlParent _data) displayCtrl 5510);
	if ((trim _name) isEqualTo '') exitWith {['Please enter a PMC name before creating.'] call _fnHint};
	['CREATE',_name] remoteExecCall ['QS_fnc_serverPMC',2];
	['QS_RD_client_dialog_pmc'] call _fnOpen;
};
if (_mode isEqualTo 'LEAVE_OPEN') exitWith {
	private _state = call _fnState;
	if ((_state isNotEqualTo []) && {(getPlayerUID player) isEqualTo (_state # 2)}) exitWith {
		['PMC owners cannot leave their PMC. Disband the PMC or transfer ownership.'] call _fnHint
	};
	['CONFIRM',['LEAVE',0]] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC');
};

if (_mode isEqualTo 'INVITE_LOAD') exitWith {
	private _list = _data displayCtrl 5520;
	lbClear _list;
	private _players = (allPlayers select {isPlayer _x && {(getPlayerUID _x) isNotEqualTo (getPlayerUID player)} && {((getPlayerUID _x) select [0,2]) isNotEqualTo 'HC'}}) apply {[toLowerANSI name _x,name _x,getPlayerUID _x]};
	_players sort TRUE;
	{private _row = _list lbAdd (_x # 1); _list lbSetData [_row,_x # 2]} forEach _players;
};
if (_mode isEqualTo 'INVITE_SEND') exitWith {
	private _list = (ctrlParent _data) displayCtrl 5520;
	private _index = lbCurSel _list;
	if (_index isEqualTo -1) exitWith {['Select a player.'] call _fnHint};
	['INVITE',_list lbData _index] remoteExecCall ['QS_fnc_serverPMC',2];
	['QS_RD_client_dialog_pmc'] call _fnOpen;
};

if (_mode isEqualTo 'CONFIRM') exitWith {
	localNamespace setVariable ['QS_PMC_confirmAction',_data];
	['QS_RD_client_dialog_pmc_confirm'] call _fnOpen;
};
if (_mode isEqualTo 'CONFIRM_LOAD') exitWith {
	private _action = localNamespace getVariable ['QS_PMC_confirmAction',[]];
	private _title = switch (_action param [0,'']) do {
		case 'EJECT': {'Are You Sure'};
		default {'Are You Sure?'};
	};
	((_data displayCtrl 5601)) ctrlSetText _title;
};
if (_mode isEqualTo 'CONFIRM_YES') exitWith {
	private _action = localNamespace getVariable ['QS_PMC_confirmAction',[]];
	_action params [['_actionMode',''],['_value',0]];
	switch (_actionMode) do {
		case 'LEAVE': {['LEAVE',[]] remoteExecCall ['QS_fnc_serverPMC',2]};
		case 'EJECT': {['EJECT',_value] remoteExecCall ['QS_fnc_serverPMC',2]};
		case 'REMOVE_SKIN': {['REMOVE_SKIN',_value] remoteExecCall ['QS_fnc_serverPMC',2]};
		case 'DISBAND': {['DISBAND',[]] remoteExecCall ['QS_fnc_serverPMC',2]};
	};
	localNamespace setVariable ['QS_PMC_confirmAction',[]];
	['QS_RD_client_dialog_pmc'] call _fnOpen;
};

if (_mode isEqualTo 'MANAGE_LOAD') exitWith {
	private _state = call _fnState;
	if (_state isEqualTo []) exitWith {};
	private _permissions = _state # 7;
	(_data displayCtrl 5530) ctrlEnable (_permissions # 4);
	(_data displayCtrl 5531) ctrlEnable (_permissions # 2);
	(_data displayCtrl 5532) ctrlEnable (_permissions # 1);
	(_data displayCtrl 5533) ctrlEnable (_permissions # 3);
	(_data displayCtrl 5534) ctrlEnable (_permissions # 4);
	(_data displayCtrl 5535) ctrlEnable (_permissions # 4);
};
if (_mode isEqualTo 'RENAME_LOAD') exitWith {
	private _state = call _fnState;
	if (_state isNotEqualTo []) then {(_data displayCtrl 5540) ctrlSetText (_state # 1)};
};
if (_mode isEqualTo 'RENAME_SAVE') exitWith {
	['RENAME',ctrlText ((ctrlParent _data) displayCtrl 5540)] remoteExecCall ['QS_fnc_serverPMC',2];
	['QS_RD_client_dialog_pmc_manage'] call _fnOpen;
};

if (_mode isEqualTo 'RANKS_LOAD') exitWith {
	private _state = call _fnState;
	if (_state isEqualTo []) exitWith {};
	private _combo = _data displayCtrl 5550;
	lbClear _combo;
	{private _row = _combo lbAdd (_x # 1); _combo lbSetData [_row,str (_x # 0)]} forEach (_state # 5);
	if ((lbSize _combo) > 0) then {_combo lbSetCurSel 0};
	['RANK_SELECT',_combo,0] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC');
};
if (_mode isEqualTo 'RANK_SELECT') exitWith {
	private _display = ctrlParent _data;
	private _ranks = (call _fnState) param [5,[]];
	private _rankID = parseNumber (_data lbData _extra);
	private _rankIndex = _ranks findIf {(_x # 0) isEqualTo _rankID};
	if (_rankIndex isEqualTo -1) exitWith {};
	private _rank = _ranks # _rankIndex;
	localNamespace setVariable ['QS_PMC_editRankID',_rankID];
	(_display displayCtrl 5552) ctrlSetText (_rank # 1);
	private _hierarchy = _display displayCtrl 5553;
	lbClear _hierarchy;
	for '_i' from 0 to 10 do {private _row = _hierarchy lbAdd str _i; _hierarchy lbSetValue [_row,_i]};
	_hierarchy lbSetCurSel (_rank # 2);
	{(_display displayCtrl (5554 + _forEachIndex)) cbSetChecked _x} forEach (_rank select [3,4]);
	private _ownerRank = _rank # 7;
	_hierarchy ctrlEnable !(_ownerRank || {_rank # 8});
	{(_display displayCtrl _x) ctrlEnable !_ownerRank} forEach [5554,5555,5556,5557];
};
if (_mode isEqualTo 'RANK_NEW') exitWith {
	private _display = ctrlParent _data;
	localNamespace setVariable ['QS_PMC_editRankID',0];
	(_display displayCtrl 5552) ctrlSetText 'Rank Name';
	private _hierarchy = _display displayCtrl 5553;
	lbClear _hierarchy;
	for '_i' from 0 to 10 do {private _row = _hierarchy lbAdd str _i; _hierarchy lbSetValue [_row,_i]};
	_hierarchy lbSetCurSel 0;
	_hierarchy ctrlEnable TRUE;
	{private _control = _display displayCtrl _x; _control cbSetChecked FALSE; _control ctrlEnable TRUE} forEach [5554,5555,5556,5557];
};
if (_mode isEqualTo 'RANK_SAVE') exitWith {
	private _display = ctrlParent _data;
	private _hierarchy = _display displayCtrl 5553;
	private _hIndex = lbCurSel _hierarchy;
	private _hierarchyValue = if (_hIndex isEqualTo -1) then {0} else {_hierarchy lbValue _hIndex};
	private _payload = [
		localNamespace getVariable ['QS_PMC_editRankID',0],ctrlText (_display displayCtrl 5552),_hierarchyValue,
		cbChecked (_display displayCtrl 5554),cbChecked (_display displayCtrl 5555),cbChecked (_display displayCtrl 5556),cbChecked (_display displayCtrl 5557)
	];
	['SAVE_RANK',_payload] remoteExecCall ['QS_fnc_serverPMC',2];
};

if (_mode isEqualTo 'MEMBERS_LOAD') exitWith {
	private _list = _data displayCtrl 5560;
	lnbClear _list;
	{private _row = _list lnbAddRow [_x # 1,_x # 3]; _list lnbSetData [[_row,0],_x # 0]} forEach ((call _fnState) param [4,[]]);
};
if (_mode in ['MEMBER_EJECT','MEMBER_RANK']) exitWith {
	private _list = (ctrlParent _data) displayCtrl 5560;
	private _row = lnbCurSelRow _list;
	if (_row isEqualTo -1) exitWith {['Select a player.'] call _fnHint};
	private _targetUID = _list lnbData [_row,0];
	if (_mode isEqualTo 'MEMBER_EJECT') then {
		['CONFIRM',['EJECT',_targetUID]] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC');
	} else {
		localNamespace setVariable ['QS_PMC_selectedMember',[_targetUID,_list lnbText [_row,0]]];
		['QS_RD_client_dialog_pmc_changeRank'] call _fnOpen;
	};
};
if (_mode isEqualTo 'CHANGE_RANK_LOAD') exitWith {
	private _selected = localNamespace getVariable ['QS_PMC_selectedMember',['','Member']];
	(_data displayCtrl 5571) ctrlSetText format ["Change %1's Rank",_selected # 1];
	private _list = _data displayCtrl 5570;
	lbClear _list;
	{private _row = _list lbAdd format ['%1 (Hierarchy %2)',_x # 1,_x # 2]; _list lbSetData [_row,str (_x # 0)]} forEach ((call _fnState) param [5,[]]);
};
if (_mode isEqualTo 'CHANGE_RANK_SAVE') exitWith {
	private _list = (ctrlParent _data) displayCtrl 5570;
	private _index = lbCurSel _list;
	if (_index isEqualTo -1) exitWith {['Please select a rank.'] call _fnHint};
	private _selected = localNamespace getVariable ['QS_PMC_selectedMember',['','']];
	['CHANGE_RANK',[_selected # 0,parseNumber (_list lbData _index)]] remoteExecCall ['QS_fnc_serverPMC',2];
	['QS_RD_client_dialog_pmc_members'] call _fnOpen;
};

if (_mode isEqualTo 'SKINS_LOAD') exitWith {
	private _list = _data displayCtrl 5580;
	lbClear _list;
	{private _row = _list lbAdd (_x # 1); _list lbSetData [_row,str (_x # 0)]} forEach ((call _fnState) param [6,[]]);
};
if (_mode isEqualTo 'SKIN_REMOVE') exitWith {
	private _list = (ctrlParent _data) displayCtrl 5580;
	private _index = lbCurSel _list;
	if (_index isEqualTo -1) exitWith {['Please select a skin to remove.'] call _fnHint};
	['CONFIRM',['REMOVE_SKIN',parseNumber (_list lbData _index)]] call (missionNamespace getVariable 'QS_fnc_clientMenuPMC');
};
if (_mode isEqualTo 'ADD_SKIN_LOAD') exitWith {
	private _list = _data displayCtrl 5590;
	lbClear _list;
	private _row = _list lbAdd 'Loading purchased skins...'; _list lbSetData [_row,''];
	['GET_PURCHASED_SKINS',[]] remoteExecCall ['QS_fnc_serverPMC',2];
};
if (_mode isEqualTo 'PURCHASED_SKINS') exitWith {
	if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
	private _display = findDisplay 55900;
	if (isNull _display) exitWith {};
	private _list = _display displayCtrl 5590;
	lbClear _list;
	{private _row = _list lbAdd (_x # 0); _list lbSetData [_row,_x # 0]} forEach _data;
};
if (_mode isEqualTo 'ADD_SKIN_SAVE') exitWith {
	private _list = (ctrlParent _data) displayCtrl 5590;
	private _index = lbCurSel _list;
	if (_index isEqualTo -1 || {(_list lbData _index) isEqualTo ''}) exitWith {['Please select a skin to add.'] call _fnHint};
	['ADD_SKIN',_list lbData _index] remoteExecCall ['QS_fnc_serverPMC',2];
	['QS_RD_client_dialog_pmc_skins'] call _fnOpen;
};

if (_mode isEqualTo 'PMC_SKINS_LOAD') exitWith {
	private _list = _data displayCtrl 5620;
	lbClear _list;
	private _row = _list lbAdd 'Loading PMC skins...';
	_list lbSetData [_row,''];
	(_data displayCtrl 5621) ctrlEnable FALSE;
	['GET_PMC_SKINS',[]] remoteExecCall ['QS_fnc_serverPMC',2];
};
if (_mode isEqualTo 'PMC_SKINS_DATA') exitWith {
	if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
	private _display = findDisplay 56200;
	if (isNull _display) exitWith {};
	private _list = _display displayCtrl 5620;
	lbClear _list;
	{
		_x params [['_displayName',''],['_textureSlots',[]],['_vehicleName',''],['_vehicleClasses',[]]];
		private _row = _list lbAdd _displayName;
		_list lbSetData [_row,str [_textureSlots,_vehicleClasses,_vehicleName]];
		private _preview = '';
		{
			{if (fileExists _x) exitWith {_preview = _x}} forEach _x;
			if (_preview isNotEqualTo '') exitWith {};
		} forEach _textureSlots;
		_list lbSetPicture [_row,_preview];
		_list lbSetTooltip [_row,_vehicleName];
	} forEach _data;
	if (_data isEqualTo []) then {
		private _row = _list lbAdd 'No PMC skins available';
		_list lbSetData [_row,''];
		(_display displayCtrl 5621) ctrlEnable FALSE;
	} else {
		_list lbSetCurSel 0;
		(_display displayCtrl 5621) ctrlEnable TRUE;
	};
};
if (_mode isEqualTo 'PMC_SKIN_APPLY') exitWith {
	private _display = ctrlParent _data;
	private _list = _display displayCtrl 5620;
	private _index = lbCurSel _list;
	if (_index isEqualTo -1 || {(_list lbData _index) isEqualTo ''}) exitWith {};
	(parseSimpleArray (_list lbData _index)) params [['_textureSlots',[]],['_vehicleClasses',[]],['_vehicleName','']];
	private _resolvedTextures = [];
	private _missingTexture = FALSE;
	{
		private _texture = '';
		{if (fileExists _x) exitWith {_texture = _x}} forEach _x;
		if (_texture isEqualTo '') exitWith {_missingTexture = TRUE};
		_resolvedTextures pushBack _texture;
	} forEach _textureSlots;
	if (_missingTexture || {_resolvedTextures isEqualTo []}) exitWith {
		['This PMC skin has not been installed on the game server yet.'] call _fnHint
	};
	private _target = vehicle player;
	private _targetName = 'vehicle';
	if (_target isEqualTo player) then {
		_target = player;
		_targetName = 'uniform';
	} else {
		if ((driver _target) isNotEqualTo player) then {_target = player; _targetName = 'uniform'};
	};
	if (_vehicleClasses isEqualTo []) exitWith {['This PMC skin does not specify a compatible vehicle class.'] call _fnHint};
	private _targetClass = toLowerANSI (typeOf _target);
	if ((_vehicleClasses findIf {(toLowerANSI _x) isEqualTo _targetClass}) isEqualTo -1) exitWith {
		private _compatibleVehicle = ['the configured vehicle',_vehicleName] select (_vehicleName isNotEqualTo '');
		[format ['This skin can only be applied to %1.',_compatibleVehicle]] call _fnHint
	};
	private _identity = [typeOf _target,uniform player] select (_target isEqualTo player);
	private _original = _target getVariable ['QS_commissarySkin_original',[]];
	if ((_original isEqualTo []) || {(_original # 0) isNotEqualTo _identity}) then {
		private _textures = getObjectTextures _target;
		if (_textures isEqualTo []) then {_textures = getArray ((configOf _target) >> 'hiddenSelectionsTextures')};
		_target setVariable ['QS_commissarySkin_original',[_identity,_textures],FALSE];
	};
	{_target setObjectTextureGlobal [_forEachIndex,_x]} forEach _resolvedTextures;
	[format ['Applied %1 to your %2.',_list lbText _index,_targetName]] call _fnHint;
};

if (_mode isEqualTo 'TRANSFER_LOAD') exitWith {
	private _list = _data displayCtrl 5610;
	lbClear _list;
	{if ((_x # 0) isNotEqualTo (getPlayerUID player)) then {private _row = _list lbAdd (_x # 1); _list lbSetData [_row,_x # 0]}} forEach ((call _fnState) param [4,[]]);
};
if (_mode isEqualTo 'TRANSFER_SAVE') exitWith {
	private _list = (ctrlParent _data) displayCtrl 5610;
	private _index = lbCurSel _list;
	if (_index isEqualTo -1) exitWith {['Select a player.'] call _fnHint};
	['TRANSFER',_list lbData _index] remoteExecCall ['QS_fnc_serverPMC',2];
	['QS_RD_client_dialog_pmc'] call _fnOpen;
};
