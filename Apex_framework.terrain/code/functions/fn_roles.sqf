/*/
File: fn_roles.sqf
Author:

	Quiksilver
	
Last Modified:

	5/05/2019 A3 1.92 by Quiksilver
	
Description:

	Roles System
________________________________________/*/

params ['_type'];
if (_type isEqualTo 'HANDLE') exitWith {
	(uiNamespace getVariable ['QS_roles_handler',[]]) pushBack (_this # 1);
	if ((uiNamespace getVariable ['QS_roles_PFH',0]) isEqualTo 0) then {
		uiNamespace setVariable ['QS_roles_PFH',(addMissionEventHandler ['EachFrame',(missionNamespace getVariable 'QS_fnc_eventEachFrame')])];
	};
};
if (_type isEqualTo 'PROPAGATE') exitWith {
	params [
		'',
		['_force',FALSE]
	];
	private _role = 'rifleman';
	private _role_data = [];
	private _role_manifest = [];
	private _role_queue = [];
	private _role_capacity = 0;
	private _role_count = 0;
	private _role_queue_capacity = 0;
	private _role_queue_count = 0;
	private _role_index = -1;
	private _whitelist_capacity = 0;
	private _propagate = _force;
	{
		_side_roles_data = _x;
		{
			_role_data = _x # 0;
			_role_manifest = _x # 1;
			_role_queue = _x # 2;
			_role = _role_data # 0;
			_role_capacity = count _role_manifest;
			_role_count = count (_role_manifest select {((_x # 0) isNotEqualTo '')});
			_role_queue_capacity = count _role_queue;
			_role_queue_count = count (_role_queue select {((_x # 0) isNotEqualTo '')});
			_role_index = (missionNamespace getVariable 'QS_RSS_public') findIf {(_x # 0) isEqualTo _role};
			if (_role_index isNotEqualTo -1) then {
				if ( ((missionNamespace getVariable 'QS_RSS_public') # _role_index) isNotEqualTo [_role,_role_count,_role_capacity,_role_queue_count,_role_queue_capacity]) then {
					(missionNamespace getVariable 'QS_RSS_public') set [_role_index,[_role,_role_count,_role_capacity,_role_queue_count,_role_queue_capacity]];
					if (!(_propagate)) then {
						_propagate = TRUE;
					};
				};
			} else {
				(missionNamespace getVariable 'QS_RSS_public') pushBack [_role,_role_count,_role_capacity,_role_queue_count,_role_queue_capacity];
				if (!(_propagate)) then {
					_propagate = TRUE;
				};
			};
		} forEach _side_roles_data;
	} forEach (missionNamespace getVariable 'QS_unit_roles');
	if (_propagate) then {
		missionNamespace setVariable ['QS_RSS_public',(missionNamespace getVariable 'QS_RSS_public'),TRUE];
		missionNamespace setVariable ['QS_RSS_refreshUI',TRUE,-2];
	};
};
if (_type isEqualTo 'GET_ROLE_COUNT') exitWith {
	params [
		'',
		['_role',''],
		['_side',sideEmpty],
		['_returnText',FALSE]
	];
	private _data = [];
	_table_index = (missionNamespace getVariable 'QS_RSS_public') findIf {((_x # 0) isEqualTo _role)};
	_data = ((missionNamespace getVariable 'QS_RSS_public') # _table_index) select [1,4];
	_data params ['_role_count','_role_capacity','_role_queue_count','_role_queue_capacity'];
	private _return = [[_role_count,_role_capacity,_role_queue_count,_role_queue_capacity],'( 0 / 0 )'] select _returnText;
	_playerCount = count allPlayers;
	private _exit = FALSE;
	private _role2 = 'rifleman';
	private _roles_side = [];
	private _min = 0;
	private _max = 0;
	private _coef = 0;
	private _whitelist_value = 0;
	private _role_data = [];
	{
		_roles_side = _x;
		if (_roles_side isNotEqualTo []) then {
			{
				_role2 = _x # 0;
				if (_role isEqualTo _role2) then {
					_min = _x # 2;
					_max = _x # 3;
					_coef = _x # 4;
					_whitelist_value = _x # 5;
					if (_whitelist_value > 0) then {
						_min = _min + _whitelist_value;
						_max = _max + _whitelist_value;
					};
					_exit = TRUE;
				};
				if (_exit) exitWith {};
			} forEach _roles_side;
		};
		if (_exit) exitWith {};
	} forEach (missionNamespace getVariable 'QS_roles_data');
	if (_coef <= 0) then {
		_role_capacity = _min max _max;
	} else {
		_role_capacity = _min max (_min + (floor (_playerCount / _coef))) min _max;
	};
	if (_returnText) then {
		if ([_role_count,_role_capacity] isNotEqualTo [0,0]) then {
			_return = format ['( %1 / %2 )',_role_count,_role_capacity];
		};
	} else {
		_return = [_role_count,_role_capacity,_role_queue_count,_role_queue_capacity];
	};
	_return;
};
if (_type isEqualTo 'UPDATE_UI') exitWith {
	params [
		'',
		['_unit',objNull]
	];
	if (!isNull _unit) then {
		{
			_unit setVariable _x;
		} forEach [
			['QS_unit_role_icon',(['GET_ROLE_ICONMAP',(_unit getVariable ['QS_unit_role','rifleman']),_unit,TRUE] call (missionNamespace getVariable 'QS_fnc_roles')),FALSE],
			['QS_unit_role_displayName',(['GET_ROLE_DISPLAYNAME',(_unit getVariable ['QS_unit_role','rifleman']),_unit,TRUE] call (missionNamespace getVariable 'QS_fnc_roles')),FALSE],
			['QS_unit_role_netUpdate',FALSE,FALSE]
		];
	};
};
if (_type isEqualTo 'GET_ROLE_DISPLAYNAME') exitWith {
	params [
		'',
		['_role',''],
		['_unit',objNull],
		['_update',FALSE]
	];
	private _return = 'Rifleman';
	if (_role isEqualTo '') then {
		if (!isNull _unit) then {
			_role = _unit getVariable ['QS_unit_role','rifleman'];
		};
	};
	_table_index = (missionNamespace getVariable 'QS_roles_UI_info') findIf {((_x # 0) isEqualTo _role)};
	if (_table_index isNotEqualTo -1) then {
		_return = ((missionNamespace getVariable 'QS_roles_UI_info') # _table_index) # 1;
		if (!isNull _unit) then {
			if (_update || {((_unit getVariable ['QS_unit_role_displayName',-1]) isEqualTo -1)}) then {
				_unit setVariable ['QS_unit_role_displayName',_return,FALSE];
			};
		};
	};
	_return;
};
if (_type isEqualTo 'GET_ROLE_DISPLAYNAME2') exitWith {
	params [
		'',
		['_role',''],
		['_unit',objNull]
	];
	private _return = 'Rifleman';
	if (_role isEqualTo '') then {
		if (!isNull _unit) then {
			_role = _unit getVariable ['QS_unit_role','rifleman'];
		};
	};
	_table_index = (missionNamespace getVariable 'QS_roles_UI_info') findIf {((_x # 0) isEqualTo _role)};
	if (_table_index isNotEqualTo -1) then {
		_return = ((missionNamespace getVariable 'QS_roles_UI_info') # _table_index) # 1;
	};
	private _exit = FALSE;
	private _roles_side = [];
	if (['_WL',_role,FALSE] call (missionNamespace getVariable 'QS_fnc_inString')) then {
		_return = (format ['[%1] ',localize 'STR_QS_Role_028']) + _return;
	};
	_return;
};
if (_type isEqualTo 'GET_ROLE_ICON') exitWith {
	params [
		'',
		['_role',''],
		['_unit',objNull]
	];
	private _return = 'a3\ui_f\data\map\vehicleicons\iconMan_ca.paa';
	if (_role isEqualTo '') then {
		if (!isNull _unit) then {
			_role = _unit getVariable ['QS_unit_role','rifleman'];
		};
	};
	_table_index = (missionNamespace getVariable 'QS_roles_UI_info') findIf {((_x # 0) isEqualTo _role)};
	if (_table_index isNotEqualTo -1) then {
		_return = ((missionNamespace getVariable 'QS_roles_UI_info') # _table_index) # 2;
	};
	_return;
};
if (_type isEqualTo 'GET_ROLE_ICONMAP') exitWith {
	params [
		'',
		['_role',''],
		['_unit',objNull],
		['_update',FALSE]
	];
	private _return = 'a3\ui_f\data\map\vehicleicons\iconMan_ca.paa';
	if (_role isEqualTo '') then {
		if (!isNull _unit) then {
			_role = _unit getVariable ['QS_unit_role','rifleman'];
		};
	};
	_table_index = (missionNamespace getVariable 'QS_roles_UI_info') findIf {((_x # 0) isEqualTo _role)};
	if (_table_index isNotEqualTo -1) then {
		_return = ((missionNamespace getVariable 'QS_roles_UI_info') # _table_index) # 3;
		if (!isNull _unit) then {
			if (_update || {((_unit getVariable ['QS_unit_role_icon',-1]) isEqualTo -1)}) then {
				_unit setVariable ['QS_unit_role_icon',_return,FALSE];
			};
		};
	};
	_return;
};
if (_type isEqualTo 'GET_ROLE_DESCRIPTION') exitWith {
	params [
		'',
		['_role','rifleman']
	];
	([_role] call (missionNamespace getVariable 'QS_fnc_roleDescription'));	
};
if (_type isEqualTo 'COMPACT_QUEUE') exitWith {
	params ['','_queue'];
	private _capacity = count _queue;
	private _compact = _queue select {((_x # 0) isNotEqualTo '')};
	while {(count _compact) < _capacity} do {
		_compact pushBack ['',-1,0];
	};
	_compact;
};
if (_type isEqualTo 'QUEUE_NOTIFY_POSITIONS') exitWith {
	params ['','_role','_queue'];
	private _roleName = ['GET_ROLE_DISPLAYNAME',_role] call (missionNamespace getVariable 'QS_fnc_roles');
	private _position = 0;
	private _queuedUnit = objNull;
	{
		if ((_x # 0) isNotEqualTo '') then {
			_position = _position + 1;
			private _queueUID = _x # 0;
			_queuedUnit = (allPlayers select {((getPlayerUID _x) isEqualTo _queueUID)}) param [0,objNull];
			if (!isNull _queuedUnit) then {
				[121,'HINT',format ['You are now number %1 in queue for %2.',_position,_roleName]] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
			};
		};
	} forEach _queue;
};
if (_type isEqualTo 'CLIENT_QUEUE_EVENT') exitWith {
	params ['','_event',['_role',''],['_side',WEST],['_text','']];
	if (_event isEqualTo 'HINT') exitWith {
		[_text,TRUE] call (missionNamespace getVariable 'QS_fnc_hint');
	};
	if (_event in ['CLEAR','ASSIGNED']) then {
		{
			if (_x in (actionIDs player)) then {
				player removeAction _x;
			};
		} forEach (localNamespace getVariable ['QS_roleQueue_actions',[]]);
		localNamespace setVariable ['QS_roleQueue_actions',[]];
		localNamespace setVariable ['QS_roleQueue_offer',[]];
	};
	if (_event isEqualTo 'CLEAR') exitWith {};
	if (_event isEqualTo 'OFFER') exitWith {
		private _roleName = ['GET_ROLE_DISPLAYNAME',_role] call (missionNamespace getVariable 'QS_fnc_roles');
		['CLIENT_QUEUE_EVENT','CLEAR'] call (missionNamespace getVariable 'QS_fnc_roles');
		localNamespace setVariable ['QS_roleQueue_offer',[_role,_side]];
		private _acceptAction = player addAction [
			format ['Accept %1 role',_roleName],
			{
				params ['_target','_caller','','_arguments'];
				_arguments params ['_role','_side'];
				private _vehicle = vehicle _caller;
				if (
					((_vehicle isKindOf 'Air')) &&
					{((driver _vehicle) isEqualTo _caller)} &&
					{(({(isPlayer _x) && {(_x isNotEqualTo _caller)}} count (crew _vehicle)) > 0)}
				) exitWith {
					['You must drop off your passengers before accepting a role change.',TRUE] call (missionNamespace getVariable 'QS_fnc_hint');
				};
				[122,'ACCEPT',(getPlayerUID _caller),_side,_role,_caller,clientOwner] remoteExec ['QS_fnc_remoteExec',2,FALSE];
			},
			[_role,_side],
			50,
			FALSE,
			TRUE,
			'',
			'TRUE'
		];
		private _rejectAction = player addAction [
			format ['Reject %1 role',_roleName],
			{
				params ['_target','_caller','','_arguments'];
				_arguments params ['_role','_side'];
				[122,'REJECT',(getPlayerUID _caller),_side,_role,_caller,clientOwner] remoteExec ['QS_fnc_remoteExec',2,FALSE];
			},
			[_role,_side],
			49,
			FALSE,
			TRUE,
			'',
			'TRUE'
		];
		localNamespace setVariable ['QS_roleQueue_actions',[_acceptAction,_rejectAction]];
		[format ['%1 slot available! Use the Action menu to Accept or Reject the role. Offer expires in 3 minutes.',_roleName],TRUE] call (missionNamespace getVariable 'QS_fnc_hint');
	};
	if (_event isEqualTo 'ASSIGNED') exitWith {
		['INIT_ROLE',_role] call (missionNamespace getVariable 'QS_fnc_roles');
		if (!isNull (objectParent player)) then {
			moveOut player;
		};
		if (_side isEqualTo EAST) exitWith {
			player setVehiclePosition [(markerPos ['respawn_east',TRUE]),[],7,'NONE'];
		};
		if (_side isEqualTo RESISTANCE) exitWith {
			player setVehiclePosition [(markerPos ['respawn_resistance',TRUE]),[],7,'NONE'];
		};
		if (_side isEqualTo CIVILIAN) exitWith {
			player setVehiclePosition [(markerPos ['respawn_civilian',TRUE]),[],7,'NONE'];
		};
		if (_role in ['pilot_heli','pilot_heli_WL']) exitWith {
			private _deploymentIndex = (missionNamespace getVariable ['QS_system_deployments',[]]) findIf {((_x # 1) isEqualTo 'ID_HELISPAWN_01')};
			if (_deploymentIndex isEqualTo -1) then {
				player setVehiclePosition [(markerPos ['QS_marker_heli_spawn',TRUE]),[],5,'NONE'];
			} else {
				['SELECT',(missionNamespace getVariable 'QS_system_deployments') # _deploymentIndex] call (missionNamespace getVariable 'QS_fnc_deployment');
			};
		};
		if (_role isEqualTo 'uav') exitWith {
			player setVehiclePosition [(markerPos ['QS_marker_respawn_uavoperator',TRUE]),[],5,'NONE'];
		};
		if (_role in ['pilot_plane','pilot_cas']) exitWith {
			private _deploymentIndex = (missionNamespace getVariable ['QS_system_deployments',[]]) findIf {((_x # 1) isEqualTo 'ID_UAVSPAWN_01')};
			if (_deploymentIndex isEqualTo -1) then {
				player setVehiclePosition [(markerPos ['QS_marker_respawn_jetpilot',TRUE]),[],5,'NONE'];
			} else {
				['SELECT',(missionNamespace getVariable 'QS_system_deployments') # _deploymentIndex] call (missionNamespace getVariable 'QS_fnc_deployment');
			};
		};
		[-1] call (missionNamespace getVariable 'QS_fnc_clientRespawnPosition');
	};
};
if (_type isEqualTo 'QUEUE_PROCESS') exitWith {
	if (!isServer) exitWith {};
	private _roles = missionNamespace getVariable ['QS_unit_roles',[[],[],[],[]]];
	private _changed = FALSE;
	private _now = serverTime;
	private _connectedUIDs = allPlayers apply {getPlayerUID _x};
	{
		private _rolesSide = _x;
		private _sideID = _forEachIndex;
		{
			_x params ['_roleData','_roleUnits','_roleQueue'];
			private _role = _roleData # 0;
			private _oldQueue = +_roleQueue;
			_roleQueue = _roleQueue select {((_x # 0) isNotEqualTo '') && {((_x # 0) in _connectedUIDs)}};
			private _minimumCapacity = count _oldQueue;
			while {(count _roleQueue) < _minimumCapacity} do {_roleQueue pushBack ['',-1,0];};
			if (_roleQueue isNotEqualTo _oldQueue) then {
				_changed = TRUE;
				['QUEUE_NOTIFY_POSITIONS',_role,_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
			};
			private _availableIndex = _roleUnits findIf {(((_x # 0) isEqualTo '') && (((_x # 1) isEqualTo -1) || ((count allPlayers) > (_x # 1))))};
			private _firstIndex = _roleQueue findIf {((_x # 0) isNotEqualTo '')};
			if (_firstIndex isNotEqualTo -1) then {
				private _entry = _roleQueue # _firstIndex;
				_entry params ['_uid','_expires',['_warnings',0]];
				private _queuedUnit = (allPlayers select {((getPlayerUID _x) isEqualTo _uid)}) param [0,objNull];
				private _roleName = ['GET_ROLE_DISPLAYNAME',_role] call (missionNamespace getVariable 'QS_fnc_roles');
				if ((_expires > 0) && {(_availableIndex isEqualTo -1)}) then {
					if (!isNull _queuedUnit) then {
						[121,'CLEAR'] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
						[121,'HINT',format ['The %1 slot is no longer available. You remain first in queue.',_roleName]] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
					};
					_entry = [_uid,-1,0];
					_roleQueue set [_firstIndex,_entry];
					_expires = -1;
					_changed = TRUE;
				};
				if ((_expires > 0) && {(_now >= _expires)}) then {
					if (!isNull _queuedUnit) then {
						[121,'CLEAR'] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
						[121,'HINT',format ['You have been removed from the %1 queue.',_roleName]] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
					};
					_roleQueue set [_firstIndex,['',-1,0]];
					_roleQueue = ['COMPACT_QUEUE',_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
					_changed = TRUE;
					['QUEUE_NOTIFY_POSITIONS',_role,_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
					_firstIndex = _roleQueue findIf {((_x # 0) isNotEqualTo '')};
				};
				if (_firstIndex isNotEqualTo -1) then {
					_entry = _roleQueue # _firstIndex;
					_entry params ['_uid','_expires',['_warnings',0]];
					_queuedUnit = (allPlayers select {((getPlayerUID _x) isEqualTo _uid)}) param [0,objNull];
					_roleName = ['GET_ROLE_DISPLAYNAME',_role] call (missionNamespace getVariable 'QS_fnc_roles');
					if ((_availableIndex isNotEqualTo -1) && {(_expires < 0)} && {!isNull _queuedUnit}) then {
						_entry = [_uid,_now + 180,0];
						_roleQueue set [_firstIndex,_entry];
						[121,'OFFER',_role,(_roleData # 1)] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
						_changed = TRUE;
					} else {
						if ((_expires > 0) && {!isNull _queuedUnit}) then {
							private _remaining = _expires - _now;
							if ((_remaining <= 120) && {(_warnings < 1)}) then {
								[121,'HINT',format ['%1 role offer expires in 2 minutes. Use the Action menu to Accept or Reject.',_roleName]] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
								_warnings = 1;
								_changed = TRUE;
							};
							if ((_remaining <= 60) && {(_warnings < 2)}) then {
								[121,'HINT',format ['%1 role offer expires in 1 minute. Use the Action menu to Accept or Reject.',_roleName]] remoteExec ['QS_fnc_remoteExec',_queuedUnit,FALSE];
								_warnings = 2;
								_changed = TRUE;
							};
							_entry set [2,_warnings];
							_roleQueue set [_firstIndex,_entry];
						};
					};
				};
			};
			_rolesSide set [_forEachIndex,[_roleData,_roleUnits,_roleQueue]];
		} forEach _rolesSide;
		_roles set [_sideID,_rolesSide];
	} forEach _roles;
	missionNamespace setVariable ['QS_unit_roles',_roles,FALSE];
	if (_changed) then {
		['PROPAGATE'] call (missionNamespace getVariable 'QS_fnc_roles');
	};
};
if (_type isEqualTo 'QUEUE_RESPONSE') exitWith {
	if (!isServer) exitWith {};
	params ['','_response','_uid','_side','_role','_unit'];
	if (!(_response in ['ACCEPT','REJECT'])) exitWith {};
	if (isNull _unit) exitWith {};
	if ((getPlayerUID _unit) isNotEqualTo _uid) exitWith {};
	private _roles = missionNamespace getVariable ['QS_unit_roles',[[],[],[],[]]];
	private _sideID = _side call (missionNamespace getVariable 'QS_fnc_sideID');
	private _rolesSide = _roles # _sideID;
	private _roleIndex = _rolesSide findIf {((((_x # 0) # 0) isEqualTo _role))};
	if (_roleIndex isEqualTo -1) exitWith {};
	(_rolesSide # _roleIndex) params ['_roleData','_roleUnits','_roleQueue'];
	_roleQueue = ['COMPACT_QUEUE',_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
	private _queueIndex = _roleQueue findIf {((_x # 0) isNotEqualTo '')};
	if (_queueIndex isEqualTo -1) exitWith {};
	private _entry = _roleQueue # _queueIndex;
	if (((_entry # 0) isNotEqualTo _uid) || {((_entry # 1) <= serverTime)}) exitWith {};
	private _roleName = ['GET_ROLE_DISPLAYNAME',_role] call (missionNamespace getVariable 'QS_fnc_roles');
	private _acceptBlocked = FALSE;
	if (_response isEqualTo 'ACCEPT') then {
		private _vehicle = vehicle _unit;
		if (
			((_vehicle isKindOf 'Air')) &&
			{((driver _vehicle) isEqualTo _unit)} &&
			{(({(isPlayer _x) && {(_x isNotEqualTo _unit)}} count (crew _vehicle)) > 0)}
		) then {
			[121,'HINT','You must drop off your passengers before accepting a role change.'] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
			_acceptBlocked = TRUE;
		};
		private _availableIndex = _roleUnits findIf {(((_x # 0) isEqualTo '') && (((_x # 1) isEqualTo -1) || ((count allPlayers) > (_x # 1))))};
		if ((!(_acceptBlocked)) && {(_availableIndex isEqualTo -1)}) then {
			[121,'HINT',format ['The %1 slot is no longer available. Your queue offer remains active.',_roleName]] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
			_acceptBlocked = TRUE;
		};
	};
	if (_acceptBlocked) exitWith {};
	_roleQueue set [_queueIndex,['',-1,0]];
	_roleQueue = ['COMPACT_QUEUE',_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
	_rolesSide set [_roleIndex,[_roleData,_roleUnits,_roleQueue]];
	_roles set [_sideID,_rolesSide];
	missionNamespace setVariable ['QS_unit_roles',_roles,FALSE];
	[121,'CLEAR'] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
	if (_response isEqualTo 'REJECT') then {
		[121,'HINT',format ['You have been removed from the %1 queue.',_roleName]] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
	};
	if (_response isEqualTo 'ACCEPT') then {
		['HANDLE_REQUEST_ROLE',_uid,_side,_role,_unit,TRUE] call (missionNamespace getVariable 'QS_fnc_roles');
	};
	['QUEUE_NOTIFY_POSITIONS',_role,_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
	['PROPAGATE'] call (missionNamespace getVariable 'QS_fnc_roles');
	['QUEUE_PROCESS'] call (missionNamespace getVariable 'QS_fnc_roles');
};
if (_type isEqualTo 'HANDLE_CONNECT') exitWith {
	params ['','_data'];
	_data params ['_unit','_jip','_cid','_uid','_profileName'];
	(uiNamespace getVariable ['QS_roles_handler',[]]) pushBack ['HANDLE_REQUEST_ROLE',_uid,(missionNamespace getVariable ['QS_roles_defaultSide',WEST]),(missionNamespace getVariable ['QS_roles_defaultRole','rifleman']),_unit,FALSE,TRUE];
};
if (_type isEqualTo 'HANDLE_DISCONNECT') exitWith {
	params ['','_data'];
	_data params ['','','_uid',''];
	private _roles = missionNamespace getVariable 'QS_unit_roles';
	private _changed = FALSE;
	{
		private _rolesSide = _x;
		private _rolesSideID = _forEachIndex;
		if (_rolesSide isNotEqualTo []) then {
			{
				_x params ['_roleData','_roleManifest','_roleQueue'];
				private _priorRoleIndex = _roleManifest findIf {((_x # 0) isEqualTo _uid)};
				if (_priorRoleIndex isNotEqualTo -1) then {
					_roleManifest set [_priorRoleIndex,['',((_roleManifest # _priorRoleIndex) # 1)]];
					_changed = TRUE;
				};
				private _priorQueueIndex = _roleQueue findIf {((_x # 0) isEqualTo _uid)};
				if (_priorQueueIndex isNotEqualTo -1) then {
					_roleQueue set [_priorQueueIndex,['',-1,0]];
					_roleQueue = ['COMPACT_QUEUE',_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
					['QUEUE_NOTIFY_POSITIONS',(_roleData # 0),_roleQueue] call (missionNamespace getVariable 'QS_fnc_roles');
					_changed = TRUE;
				};
				_rolesSide set [_forEachIndex,[_roleData,_roleManifest,_roleQueue]];
			} forEach _rolesSide;
		};
		_roles set [_rolesSideID,_rolesSide];
	} forEach _roles;
	missionNamespace setVariable ['QS_unit_roles',_roles,FALSE];
	if (_changed) then {
		['PROPAGATE'] call (missionNamespace getVariable 'QS_fnc_roles');
		['QUEUE_PROCESS'] call (missionNamespace getVariable 'QS_fnc_roles');
	};
};
if (_type isEqualTo 'REQUEST_ROLE') exitWith {
	params [
		'',
		'_uid',
		'_side',
		'_role',
		'_unit',
		'_clientOwner'
	];
	private _isCAS = FALSE;
	private _exit = FALSE;
	private _roles_side = [];
	private _role_data = [];
	private _roleLower = toLowerANSI _role;
	private _whitelisted = _uid in (['S3'] call (missionNamespace getVariable 'QS_fnc_whitelist'));
	private _staffWhitelisted = _uid in (['ALL'] call (missionNamespace getVariable 'QS_fnc_whitelist'));
	if (!(_whitelisted)) then {
		if (_roleLower isEqualTo 'pilot_heli_wl') then {
			_whitelisted = _uid in (call (missionNamespace getVariable ['QS_pilot_whitelist',{[]}]));	
		};
		if (_roleLower isEqualTo 'sniper_wl') then {
			_whitelisted = _uid in (call (missionNamespace getVariable ['QS_sniper_whitelist',{[]}]));
		};
		if (_roleLower isEqualTo 'medic_wl') then {
			_whitelisted = _uid in (call (missionNamespace getVariable ['QS_cls_whitelist',{[]}]));
		};
	};
	private _roleCount = [0,0];
	if (diag_tickTime >= (uiNamespace getVariable ['QS_RSS_requestCooldown',-1])) then {
		uiNamespace setVariable ['QS_RSS_requestCooldown',(diag_tickTime + 3)];
		private _allowRequest = TRUE;
		
		if (uiNamespace getVariable ['QS_client_roles_menu_canSelectRole',FALSE]) then {
			_roleCount = ['GET_ROLE_COUNT',_role,_side,FALSE] call (missionNamespace getVariable 'QS_fnc_roles');
		} else {
			if ((_side isNotEqualTo (player getVariable ['QS_unit_side',WEST])) && (!(missionNamespace getVariable ['QS_RSS_client_canSideSwitch',FALSE]))) then {
				_allowRequest = FALSE;
				(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,localize 'STR_QS_Role_004',[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
			} else {
				_allowRequest = FALSE;
				(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,localize 'STR_QS_Role_005',[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
			};
		};
		if (_role in ['pilot_plane','pilot_cas']) then {
			_isCAS = TRUE;
			if ((missionNamespace getVariable ['QS_missionConfig_CAS',2]) isEqualTo 0) then {
				_allowRequest = FALSE;
				(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,localize 'STR_QS_Role_006',[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
			};
			if ((missionNamespace getVariable ['QS_missionConfig_CAS',2]) in [1,3]) then {
				if (!(_uid in (['CAS'] call (missionNamespace getVariable 'QS_fnc_whitelist')))) then {
					(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,localize 'STR_QS_Role_007',[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
					_allowRequest = FALSE;
				};
			};
			if ((missionNamespace getVariable ['QS_missionConfig_CAS',2]) isEqualTo 3) then {
				if ((player getVariable ['QS_client_casAllowance',0]) >= (missionNamespace getVariable ['QS_CAS_jetAllowance_value',3])) then {
					(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,(format ['%2 ( %1 )',(missionNamespace getVariable ['QS_CAS_jetAllowance_value',3]),localize 'STR_QS_Role_008']),[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
					_allowRequest = FALSE;
				};
			};
			if ((player getVariable ['QS_tto',0]) >= 3) then {
				_allowRequest = FALSE;
				(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,'Too much reported friendly fire',[],-1,TRUE,'ROBOCOP',FALSE];
			};
		};
		if (!(_isCAS)) then {
			// Whitelisting
			if ((['_WL',_role,FALSE] call (missionNamespace getVariable 'QS_fnc_inString')) && (!(_whitelisted))) then {
				_allowRequest = FALSE;
				(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,10,-1,format ['%1<br/><br/>(%2)',localize 'STR_QS_Role_009',localize 'STR_QS_Role_010'],[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
			};
			if ((_roleLower isEqualTo 'staff') && (!(_staffWhitelisted))) then {
				_allowRequest = FALSE;
				(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,10,-1,format ['%1<br/><br/>(%2)',localize 'STR_QS_Role_009',localize 'STR_QS_Role_010'],[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
			};
		};
		
		if (_role in ['engineer','engineer_wl']) then {
			if ((getPlayerUID player) in (missionNamespace getVariable ['QS_blacklist_logistics',[]])) then {
				_allowRequest = FALSE;
				(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,localize 'STR_QS_Text_388',[],-1,TRUE,'ROBOCOP',FALSE];
			};
		};
		
		if (_allowRequest) then {
			[15,_uid,_side,_role,_unit,_clientOwner] remoteExec ['QS_fnc_remoteExec',2,FALSE];
		};
	};
};
if (_type isEqualTo 'HANDLE_REQUEST_ROLE') exitWith {
	params [
		'',
		['_uid',''],
		['_side',WEST],
		['_role','rifleman'],
		['_unit',objNull],
		['_fromQueue',FALSE],
		['_bypassQueue',FALSE]
	];
	if (!isServer || {isNull _unit}) exitWith {};
	if (_uid isEqualTo '') then {
		_uid = getPlayerUID _unit;
	};
	private _pCnt = count allPlayers;
	private _roles = missionNamespace getVariable 'QS_unit_roles';
	private _side_ID = _side call (missionNamespace getVariable 'QS_fnc_sideID');
	private _roleName = ['GET_ROLE_DISPLAYNAME',_role] call (missionNamespace getVariable 'QS_fnc_roles');
	private _sameQueuePosition = -1;
	private _queuedRole = '';
	private _queuedRoleName = '';
	private _queueChanged = FALSE;
	// Locate an existing queue entry before changing any state.
	{
		private _rolesSideSearch = _x;
		if (_rolesSideSearch isNotEqualTo []) then {
			{
				_x params ['_searchData','','_searchQueue'];
				private _searchIndex = _searchQueue findIf {((_x # 0) isEqualTo _uid)};
				if (_searchIndex isNotEqualTo -1) then {
					_queuedRole = _searchData # 0;
					_queuedRoleName = ['GET_ROLE_DISPLAYNAME',_queuedRole] call (missionNamespace getVariable 'QS_fnc_roles');
					if (((_searchData # 0) isEqualTo _role) && {((_searchData # 1) isEqualTo _side)}) then {
						_sameQueuePosition = 1 + ({((_x # 0) isNotEqualTo '')} count (_searchQueue select [0,_searchIndex]));
					};
				};
			} forEach _rolesSideSearch;
		};
	} forEach _roles;
	if ((!(_fromQueue)) && {(_sameQueuePosition isNotEqualTo -1)}) exitWith {
		[121,'HINT',format ['You are already in queue for this role. You are number %1 in the queue.',_sameQueuePosition]] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
	};
	private _requestedCurrentRole = ((_unit getVariable ['QS_unit_role','rifleman']) isEqualTo _role) && {((_unit getVariable ['QS_unit_side',WEST]) isEqualTo _side)};
	if ((!(_fromQueue)) && {!(_bypassQueue)} && {_requestedCurrentRole} && {(_queuedRole isEqualTo '')}) exitWith {
		[121,'HINT','You already have this role.'] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
	};
	// Selecting a different role cancels the player's previous queue entry.
	if ((!(_fromQueue)) && {(_queuedRole isNotEqualTo '')}) then {
		{
			private _rolesSideRemove = _x;
			private _removeSideID = _forEachIndex;
			{
				_x params ['_removeData','_removeUnits','_removeQueue'];
				private _removeIndex = _removeQueue findIf {((_x # 0) isEqualTo _uid)};
				if (_removeIndex isNotEqualTo -1) then {
					_removeQueue set [_removeIndex,['',-1,0]];
					_removeQueue = ['COMPACT_QUEUE',_removeQueue] call (missionNamespace getVariable 'QS_fnc_roles');
					_rolesSideRemove set [_forEachIndex,[_removeData,_removeUnits,_removeQueue]];
					['QUEUE_NOTIFY_POSITIONS',(_removeData # 0),_removeQueue] call (missionNamespace getVariable 'QS_fnc_roles');
					_queueChanged = TRUE;
				};
			} forEach _rolesSideRemove;
			_roles set [_removeSideID,_rolesSideRemove];
		} forEach _roles;
		[121,'CLEAR'] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
		[121,'HINT',format ['You have been removed from the queue for %1.',_queuedRoleName]] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
	};
	if ((!(_fromQueue)) && {!(_bypassQueue)} && {_requestedCurrentRole}) exitWith {
		missionNamespace setVariable ['QS_unit_roles',_roles,FALSE];
		['PROPAGATE'] call (missionNamespace getVariable 'QS_fnc_roles');
		['QUEUE_PROCESS'] call (missionNamespace getVariable 'QS_fnc_roles');
	};
	private _roles_side = _roles # _side_ID;
	private _role_data_index = _roles_side findIf {(((_x # 0) # 0) isEqualTo _role)};
	if (_role_data_index isEqualTo -1) exitWith {};
	(_roles_side # _role_data_index) params [
		'_role_data',
		'_role_units',
		'_role_queue'
	];
	private _available_role_index = _role_units findIf {(((_x # 0) isEqualTo '') && (((_x # 1) isEqualTo -1) || (_pCnt > (_x # 1))))};
	_role_data params [
		'',	//'_role_data_role',
		'_role_data_side',
		'',	//'_role_data_min',
		'',	//'_role_data_max',
		'',	//'_role_data_availabilityCoef',
		'',	//'_whitelist_value',
		''	//'_queue_capacity'
	];
	if (_role_data_side isNotEqualTo _side) exitWith {};
	private _occupiedQueue = _role_queue select {((_x # 0) isNotEqualTo '')};
	if ((!(_fromQueue)) && {!(_bypassQueue)} && {((_available_role_index isEqualTo -1) || {_occupiedQueue isNotEqualTo []})}) exitWith {
		private _emptyQueueIndex = _role_queue findIf {((_x # 0) isEqualTo '')};
		if (_emptyQueueIndex isEqualTo -1) then {
			_emptyQueueIndex = _role_queue pushBack [_uid,-1,0];
		} else {
			_role_queue set [_emptyQueueIndex,[_uid,-1,0]];
		};
		_roles_side set [_role_data_index,[_role_data,_role_units,_role_queue]];
		_roles set [_side_ID,_roles_side];
		missionNamespace setVariable ['QS_unit_roles',_roles,FALSE];
		private _position = 1 + ({((_x # 0) isNotEqualTo '')} count (_role_queue select [0,_emptyQueueIndex]));
		[121,'HINT',format ['You have been added to the queue for %1. You are number %2 in queue.',_roleName,_position]] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
		['PROPAGATE'] call (missionNamespace getVariable 'QS_fnc_roles');
		['QUEUE_PROCESS'] call (missionNamespace getVariable 'QS_fnc_roles');
	};
	if (_available_role_index isEqualTo -1) exitWith {};
	// Only release the current role once the new role can actually be assigned.
	{
		private _rolesSideAssign = _x;
		private _assignSideID = _forEachIndex;
		{
			_x params ['_assignData','_assignManifest','_assignQueue'];
			private _priorRoleIndex = _assignManifest findIf {((_x # 0) isEqualTo _uid)};
			if (_priorRoleIndex isNotEqualTo -1) then {
				_assignManifest set [_priorRoleIndex,['',((_assignManifest # _priorRoleIndex) # 1)]];
				_rolesSideAssign set [_forEachIndex,[_assignData,_assignManifest,_assignQueue]];
			};
		} forEach _rolesSideAssign;
		_roles set [_assignSideID,_rolesSideAssign];
	} forEach _roles;
	_roles_side = _roles # _side_ID;
	(_roles_side # _role_data_index) params ['_role_data','_role_units','_role_queue'];
	private _available_role = _role_units # _available_role_index;
	_available_role set [0,_uid];
	_role_units set [_available_role_index,_available_role];
	_roles_side set [_role_data_index,[_role_data,_role_units,_role_queue]];
	_roles set [_side_ID,_roles_side];
	missionNamespace setVariable ['QS_unit_roles',_roles,FALSE];
	['PROPAGATE'] call (missionNamespace getVariable 'QS_fnc_roles');
	missionNamespace setVariable ['QS_RSS_refreshUI',TRUE,-2];
	if ((side (group _unit)) isNotEqualTo _side) then {
		if ((count (groups _side)) >= 100) then {
			{
				if (
					(local _x) &&
					{(((units _x) findIf {(alive _x)}) isEqualTo -1)}
				) then {
					deleteGroup _x;
				};
			} forEach (groups _side);
		};
		[_unit] joinSilent (createGroup [_side,TRUE]);
		if (_side isNotEqualTo (_unit getVariable ['QS_unit_side',WEST])) then {
			_txt = format ['%1 %4 %2 %5 %3',(name _unit),(_unit getVariable ['QS_unit_side',WEST]),_side,localize 'STR_QS_Chat_151',localize 'STR_QS_Chat_152'];
			_txt remoteExec ['systemChat',-2,FALSE];
			remoteExec ['QS_fnc_clientEventRespawn',_unit,FALSE];
		};
		_unit setVariable ['QS_unit_side',_side,TRUE];
	};
	_unit setVariable ['QS_unit_role',_role,TRUE];
	_unit setVariable ['QS_unit_role_netUpdate',TRUE,TRUE];
	if (_fromQueue) then {
		[121,'ASSIGNED',_role,_side] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
	} else {
		[16,_role] remoteExec ['QS_fnc_remoteExec',_unit,FALSE];
	};
	if (_role isEqualTo 'pilot_plane') then {
		if ((missionNamespace getVariable ['QS_missionConfig_CAS',2]) isNotEqualTo 0) then {
			missionNamespace setVariable ['QS_fighterPilot',_unit,TRUE];
		};
	};
};
if (_type isEqualTo 'INIT_ROLE') exitWith {
	params ['','_role'];
	playSoundUI ['OMLightSwitch',0.5,1.5,FALSE];
	player setVariable ['QS_unit_role',_role,FALSE];
	private _medic = (getMissionConfigValue ['ReviveRequiredTrait',1]) isEqualTo 0;
	private _traitsData = [
		[['medic',_medic,FALSE]],
		[['uavhacker',FALSE,FALSE]],
		[['engineer',FALSE,FALSE]],
		[['explosiveSpecialist',FALSE,FALSE]],
		[['audibleCoef',1,FALSE]],
		[['camouflageCoef',1,FALSE]],
		[['loadCoef',1,FALSE]],
		[['QS_trait_rifleman',TRUE,TRUE]],
		[['QS_trait_leader',FALSE,TRUE]],
		[['QS_trait_pilot',FALSE,TRUE]],
		[['QS_trait_AT',FALSE,TRUE]],
		[['QS_trait_gunner',FALSE,TRUE]],
		[['QS_trait_HQ',FALSE,TRUE]],
		[['QS_trait_fighterPilot',FALSE,TRUE]],
		[['QS_trait_cas',FALSE,TRUE]],
		[['QS_trait_JTAC',FALSE,TRUE]],
		[['QS_trait_LMG',FALSE,TRUE]],
		[['QS_trait_MMG',FALSE,TRUE]],
		[['QS_trait_Sniper',FALSE,TRUE]]
	];
	if (_role in ['autorifleman','o_autorifleman','autorifleman_WL']) then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',1.5,FALSE]],
			[['camouflageCoef',1.5,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',TRUE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role in ['machine_gunner','machine_gunner_WL']) then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',2,FALSE]],
			[['camouflageCoef',2,FALSE]],
			[['loadCoef',1.25,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',TRUE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role in ['rifleman_lat','rifleman_hat','rifleman_aa','rifleman_missile','rifleman_hat_WL']) then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',TRUE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role in ['medic','medic_WL']) then {
		_traitsData = [
			[['medic',TRUE,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role isEqualTo 'engineer') then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',TRUE,FALSE]],
			[['explosiveSpecialist',TRUE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role in ['sniper','sniper_WL']) then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',0.5,FALSE]],
			[['camouflageCoef',0.5,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',TRUE,TRUE]]
		];
	};
	if (_role in ['jtac','jtac_WL']) then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',0.75,FALSE]],
			[['camouflageCoef',0.75,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',TRUE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role isEqualTo 'mortar_gunner') then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',TRUE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',TRUE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role isEqualTo 'uav') then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',TRUE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',FALSE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role in ['pilot_heli','pilot_heli_WL']) then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',TRUE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',TRUE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role isEqualTo 'pilot_plane') then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',TRUE,TRUE]],
			[['QS_trait_cas',TRUE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role isEqualTo 'commander') then {
		_traitsData = [
			[['medic',_medic,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',1,FALSE]],
			[['camouflageCoef',1,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',FALSE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',TRUE,TRUE]],
			[['QS_trait_fighterPilot',FALSE,TRUE]],
			[['QS_trait_cas',TRUE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	if (_role isEqualTo 'staff') then {
		_traitsData = [
			[['medic',TRUE,FALSE]],
			[['uavhacker',FALSE,FALSE]],
			[['engineer',FALSE,FALSE]],
			[['explosiveSpecialist',FALSE,FALSE]],
			[['audibleCoef',0.5,FALSE]],
			[['camouflageCoef',0.5,FALSE]],
			[['loadCoef',1,FALSE]],
			[['QS_trait_rifleman',FALSE,TRUE]],
			[['QS_trait_leader',FALSE,TRUE]],
			[['QS_trait_pilot',TRUE,TRUE]],
			[['QS_trait_AT',FALSE,TRUE]],
			[['QS_trait_gunner',FALSE,TRUE]],
			[['QS_trait_HQ',FALSE,TRUE]],
			[['QS_trait_fighterPilot',TRUE,TRUE]],
			[['QS_trait_cas',TRUE,TRUE]],
			[['QS_trait_JTAC',FALSE,TRUE]],
			[['QS_trait_LMG',FALSE,TRUE]],
			[['QS_trait_MMG',FALSE,TRUE]],
			[['QS_trait_Sniper',FALSE,TRUE]]
		];
	};
	private _trait = '';
	private _traitValue = nil;
	private _isCustom = FALSE;
	private _traitData = [];
	_fn_initTrait = missionNamespace getVariable 'QS_fnc_initTrait';
	{
		_traitData = _x;
		_traitData params ['_traitParams'];
		_traitParams params ['_trait','_traitValue','_isCustom'];
		if (_traitValue isEqualType 0) then {
			if ((player getUnitTrait _trait) isNotEqualTo _traitValue) then {
				player setUnitTrait _traitParams;
				[_role,_traitParams] call _fn_initTrait;
			};
		} else {
			if (_traitValue isEqualType TRUE) then {
				if (_traitValue) then {
					if (!(player getUnitTrait _trait)) then {
						player setUnitTrait _traitParams;
						[_role,_traitParams] call _fn_initTrait;
					};
				} else {
					if (player getUnitTrait _trait) then {
						player setUnitTrait _traitParams;
						[_role,_traitParams] call _fn_initTrait;
					};
				};
			};
		};
	} forEach _traitsData;
	_role spawn {
		uiSleep 0.1;
		[player] call (missionNamespace getVariable 'QS_fnc_clientArsenal');
		uiSleep 0.1;
		missionNamespace setVariable ['QS_client_arsenalData',([(player getVariable ['QS_unit_side',WEST]),_this] call (missionNamespace getVariable 'QS_data_arsenal')),FALSE];
	};
	['SET_SAVED_LOADOUT',_role] call (missionNamespace getVariable 'QS_fnc_roles');
	uiNamespace setVariable ['QS_client_respawnCooldown',diag_tickTime + 30];
	(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,(format ['%2 %1',(['GET_ROLE_DISPLAYNAME',_role] call (missionNamespace getVariable 'QS_fnc_roles')),localize 'STR_QS_Role_011']),[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
};
if (_type isEqualTo 'SET_DEFAULT_LOADOUT') exitWith {
	params ['','_role',['_save',FALSE]];
	uiNamespace setVariable ['QS_RSS_requestCooldown',(diag_tickTime + 3)];
	_loadout_index = (missionNamespace getVariable 'QS_roles_defaultLoadouts') findIf {(_role isEqualTo (_x # 0))};
	if (_loadout_index isEqualTo -1) then {
		if ((getUnitLoadout player) isNotEqualTo (((missionNamespace getVariable 'QS_roles_defaultLoadouts') # 0) # 1)) then {
			player setUnitLoadout [(((missionNamespace getVariable 'QS_roles_defaultLoadouts') # 0) # 1),TRUE];
		} else {
			(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,localize 'STR_QS_Role_012',[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
		};
	} else {
		if ((getUnitLoadout player) isNotEqualTo (((missionNamespace getVariable 'QS_roles_defaultLoadouts') # _loadout_index) # 1)) then {
			player setUnitLoadout [(((missionNamespace getVariable 'QS_roles_defaultLoadouts') # _loadout_index) # 1),TRUE];
		} else {
			(missionNamespace getVariable 'QS_managed_hints') pushBack [5,TRUE,5,-1,localize 'STR_QS_Role_012',[],-1,TRUE,localize 'STR_QS_Role_001',FALSE];
		};
	};
	if (_save) then {
		_QS_playerRole = player getVariable ['QS_unit_role','rifleman'];
		missionNamespace setVariable ['QS_revive_arsenalInventory',(getUnitLoadout player),FALSE];
		private _QS_savedLoadouts = missionProfileNamespace getVariable [(format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))]),[]];
		_QS_loadoutIndex = (_QS_savedLoadouts findIf {((_x # 0) isEqualTo _QS_playerRole)});
		_a = [_QS_playerRole,(getUnitLoadout player)];
		if (_QS_loadoutIndex isEqualTo -1) then {
			_QS_savedLoadouts pushBack _a;
		} else {
			_QS_savedLoadouts set [_QS_loadoutIndex,_a];
		};
		missionProfileNamespace setVariable [(format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))]),_QS_savedLoadouts];
		saveMissionProfileNamespace;
	};
};
if (_type isEqualTo 'SET_SAVED_LOADOUT') exitWith {
	params ['',['_role','rifleman']];
	private _customLoadout = FALSE;
	if ((((missionNamespace getVariable ['QS_missionConfig_aoType','CLASSIC']) in ['CLASSIC','SC','GRID']) && ((player getVariable ['QS_unit_side',WEST]) isEqualTo WEST)) || {(!((missionNamespace getVariable ['QS_missionConfig_aoType','CLASSIC']) in ['CLASSIC','SC','GRID']))}) then {
		if (!isNil {missionProfileNamespace getVariable (format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))])}) then {
			if ((missionProfileNamespace getVariable (format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))])) isEqualType []) then {
				if ((missionProfileNamespace getVariable (format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))])) isNotEqualTo []) then {
					_QS_loadoutIndex = (missionProfileNamespace getVariable (format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))])) findIf {((_x # 0) isEqualTo _role)};
					if (_QS_loadoutIndex isNotEqualTo -1) then {
						player setUnitLoadout [(((missionProfileNamespace getVariable (format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))])) # _QS_loadoutIndex) # 1),TRUE];
						_customLoadout = TRUE;
					};
				};
			} else {
				missionProfileNamespace setVariable [(format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))]),[]];
				saveMissionProfileNamespace;
			};
		} else {
			missionProfileNamespace setVariable [(format ['QS_RSS_loadouts_%1',(['arid','tropic'] select (worldName in ['Tanoa','Enoch']))]),[]];
			saveMissionProfileNamespace;
		};
	};
	if (!(_customLoadout)) then {
		['SET_DEFAULT_LOADOUT',_role] call (missionNamespace getVariable 'QS_fnc_roles');
	};
};
if (_type isEqualTo 'INIT_SYSTEM') exitWith {

	{
		missionNamespace setVariable _x;
	} forEach [
		['QS_roles_data',(missionNamespace getVariable 'QS_roles_data'),TRUE],
		['QS_roles_UI_info',(missionNamespace getVariable 'QS_roles_UI_info'),TRUE],
		['QS_roles_defaultLoadouts',(missionNamespace getVariable 'QS_roles_defaultLoadouts'),TRUE],
		['QS_fnc_roleDescription',(missionNamespace getVariable 'QS_fnc_roleDescription'),TRUE],
		['QS_unit_roles',[[],[],[],[]],FALSE],
		['QS_RSS_public',[]]
	];
	private _data_roles = missionNamespace getVariable ['QS_roles_data',[]];
	private _data_roles_side = [];
	private _role_to_add = [];
	private _sideID = 0;
	private _data_role = [];
	private _role = '';
	private _min_slots = 0;
	private _max_slots = 0;
	private _slots = [];
	private _slot_unlocked = 0;
	private _side_roles = [];
	private _role_side = sideEmpty;
	private _slot_availability_coef = 0;
	private _slot_availability_at = 0;
	private _i = 0;
	private _queue = [];
	{
		_sideID = _forEachIndex;
		_data_roles_side = _data_roles # _forEachIndex;
		if (_data_roles_side isNotEqualTo []) then {
			{
				_data_role = _x;
				_data_role params [
					'_role',
					'_role_side',
					'_min_slots',
					'_max_slots',
					'_slot_availability_coef',
					'_whitelist_value',
					'_queue_capacity'
				];
				_slots = [];
				_i = 0;
				_slot_availability_at = -1;
				for '_i' from 0 to (_max_slots - 1) step 1 do {
					if (_slot_availability_coef isNotEqualTo -1) then {
						if (_i >= _min_slots) then {
							_slot_availability_at = _slot_availability_at + _slot_availability_coef;
						};
					};
					_slots pushBack ['',([_slot_availability_at,-1] select (_i < _min_slots))];
				};
				if (_whitelist_value > 0) then {
					_i = 0;
					for '_i' from 0 to (_whitelist_value - 1) step 1 do {
						_slots pushBack ['',-1];
					};
				};
				_queue = [];
				_i = 0;
				for '_i' from 0 to (_queue_capacity - 1) step 1 do {
					_queue pushBack ['',-1,0];
				};
				_role_to_add = [];
				_role_to_add pushBack (_data_role select [0,8]);
				_role_to_add pushBack _slots;
				_role_to_add pushBack _queue;
				_side_roles = (missionNamespace getVariable 'QS_unit_roles') # _sideID;
				_side_roles pushBack _role_to_add;
				(missionNamespace getVariable 'QS_unit_roles') set [_sideID,_side_roles];
				if (((missionNamespace getVariable 'QS_RSS_public') findIf {((_x # 0) isEqualTo _role)}) isEqualTo -1) then {
					(missionNamespace getVariable 'QS_RSS_public') pushBack [_role,0,(count _slots),0,(count _queue)];
				};
			} forEach _data_roles_side;
		};
	} forEach _data_roles;
	if (isServer && {!(missionNamespace getVariable ['QS_roleQueue_processorStarted',FALSE])}) then {
		missionNamespace setVariable ['QS_roleQueue_processorStarted',TRUE,FALSE];
		0 spawn {
			while {TRUE} do {
				uiSleep 1;
				['QUEUE_PROCESS'] call (missionNamespace getVariable 'QS_fnc_roles');
			};
		};
	};
};
