/*
	Discovers Editor objects marked as Spawn Menu terminals and adds the
	action locally for each player.

	Editor terminal init:
		this setVariable ["QS_spawnMenu_terminal",true];
		this setVariable ["QS_spawnMenu_id","motor_pool"];
		this setVariable ["QS_spawnMenu_allowedRoles",["rifleman","medic"]];
		this setVariable ["QS_spawnMenu_vehicleClasses",["B_MRAP_01_F","B_Soldier_F","B_supplyCrate_F"]];

	Editor spawn-point init:
		this setVariable ["QS_spawnMenu_spawnPoint",true];
		this setVariable ["QS_spawnMenu_id","motor_pool"];

	Use a different QS_spawnMenu_id for each independent terminal/spawn area.
	QS_spawnMenu_allowedRoles contains the role IDs allowed to use that terminal.
	A single role string is also accepted.
	Leave it undefined or set it to [] to allow every role.
	The staff role always bypasses this role restriction.
	QS_spawnMenu_vehicleClasses contains the exact CfgVehicles class IDs displayed
	by that terminal. Vehicles, CAManBase AI units, ReammoBox_F supply crates, and
	Cargo_base_F/Slingload_01_Base_F/Pod_Heli_Transport_04_base_F logistics
	containers are supported. Leave it undefined to display every supported class.
	An explicit empty array displays nothing.
	AI recruitment requires the player to be the leader of their group. Recruited
	AI joins that existing player group.
	Multiple spawn points may share an ID; the terminal uses the nearest matching
	point. If no ID is supplied, the nearest spawn point is used for backwards
	compatibility.
*/
if (
	isServer &&
	{!(missionNamespace getVariable ['QS_spawnMenu_cleanupStarted',FALSE])}
) then {
	missionNamespace setVariable ['QS_spawnMenu_cleanupStarted',TRUE,FALSE];
	missionNamespace setVariable ['QS_spawnMenu_spawnedEntities',[],FALSE];

	[] spawn {
		private _baseRadius = 1000;
		private _ownerDistance = 2000;
		private _cleanupDelay = 10;
		private _deleteSpawnedEntity = {
			params ['_entity'];
			private _entityGroup = grpNull;
			if (unitIsUAV _entity) then {
				_entityGroup = group (effectiveCommander _entity);
				deleteVehicleCrew _entity;
			} else {
				if (_entity isKindOf 'CAManBase') then {
					_entityGroup = group _entity;
				};
			};
			deleteVehicle _entity;
			if (!isNull _entityGroup && {(units _entityGroup) isEqualTo []}) then {
				deleteGroup _entityGroup;
			};
		};

		while {TRUE} do {
			sleep 1;
			private _basePosition = markerPos 'QS_marker_base_marker';

			private _playersByUID = createHashMap;
			{
				private _uid = getPlayerUID _x;
				if (_uid isNotEqualTo '') then {
					_playersByUID set [_uid,_x];
				};
			} forEach allPlayers;

			private _spawnedEntities = (missionNamespace getVariable ['QS_spawnMenu_spawnedEntities',[]]) select {
				!isNull _x
			};
			{
				private _entity = _x;
				private _ownerUID = _entity getVariable ['QS_spawnMenu_spawnedBy',''];
				private _owner = _playersByUID getOrDefault [_ownerUID,objNull];
				private _isManagedVehicle = (
					(['LandVehicle','Air','Ship'] findIf {_entity isKindOf _x}) isNotEqualTo -1
				);
				if (
					(_entity isKindOf 'CAManBase') &&
					{!(_entity getVariable ['QS_spawnMenu_aiPendingJoin',FALSE])} &&
					{!isNull _owner} &&
					{(group _entity) isNotEqualTo (group _owner)}
				) then {
					[_entity] call _deleteSpawnedEntity;
				} else {
					if (
						(!_isManagedVehicle) &&
						{!isNull _owner} &&
						{(_entity distance2D _basePosition) <= _baseRadius} &&
						{(_owner distance2D _entity) > _ownerDistance}
					) then {
						private _abandonedSince = _entity getVariable ['QS_spawnMenu_baseAbandonedSince',-1];
						if (_abandonedSince < 0) then {
							_entity setVariable ['QS_spawnMenu_baseAbandonedSince',serverTime,FALSE];
						} else {
							if ((serverTime - _abandonedSince) >= _cleanupDelay) then {
								[_entity] call _deleteSpawnedEntity;
							};
						};
					} else {
						if ((_entity getVariable ['QS_spawnMenu_baseAbandonedSince',-1]) >= 0) then {
							_entity setVariable ['QS_spawnMenu_baseAbandonedSince',-1,FALSE];
						};
					};
				};
			} forEach _spawnedEntities;

			missionNamespace setVariable [
				'QS_spawnMenu_spawnedEntities',
				(missionNamespace getVariable ['QS_spawnMenu_spawnedEntities',[]]) select {!isNull _x},
				FALSE
			];
		};
	};
};

if (!hasInterface) exitWith {};

[] spawn {
	waitUntil {
		uiSleep 0.25;
		!isNull player && {time > 0}
	};

	{
		if (
			_x getVariable ['QS_spawnMenu_terminal',FALSE] &&
			{!(_x getVariable ['QS_spawnMenu_actionAdded',FALSE])}
		) then {
			_x addAction [
				'<t color="#8BE28B">Spawn Menu</t>',
				{
					params ['_target'];
					['OPEN',_target] call QS_fnc_spawnMenu;
				},
				nil,
				5,
				TRUE,
				TRUE,
				'',
				'alive _target && {alive _this} && {isNull (objectParent _this)} && {_this distance _target < 5} && {["CAN_ACCESS",_target,_this] call QS_fnc_spawnMenu}',
				5,
				FALSE,
				'',
				''
			];
			_x setVariable ['QS_spawnMenu_actionAdded',TRUE,FALSE];
		};
	} forEach (allMissionObjects 'All');
};
