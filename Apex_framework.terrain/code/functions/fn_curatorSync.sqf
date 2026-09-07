/*/
File: fn_curatorSync.sqf
Author: 

	Quiksilver

Last Modified:

	28/10/2023 A3 2.14 by Quiksilver

Description:

	Curator Sync
_______________________________________/*/

params ['_module'];
if (!isNull _module) then {
	private _perfSync = ['curatorSync.total',1] call QS_fnc_perfBegin;
	private _perfCensus = ['curatorSync.allMissionObjects'] call QS_fnc_perfBegin;
	private _perfObjects = allMissionObjects 'All';
	[_perfCensus,count _perfObjects] call QS_fnc_perfEnd;
	private _arrayToAdd = [];
	private _entity = objNull;
	{
		_entity = _x;
		if (
			(([
				'Man','WeaponHolder','GroundWeaponHolder','WeaponHolderSimulated','Air',
				'LandVehicle','Reammobox_F','Ship','StaticWeapon','CraterLong','Cargo_base_F'
			] findIf {_entity isKindOf _x}) isNotEqualTo -1) ||
			{((_entity isKindOf 'FlagCarrier') && (!(_entity isKindOf 'ShipFlag_US_F')) && (_entity getVariable ['QS_zeus',false]))}
		) then {
			if (!(_entity getVariable ['QS_curator_disableEditability',FALSE])) then {
				if (!(_entity getVariable ['QS_dead_prop',FALSE])) then {
					_arrayToAdd pushBackUnique _entity;
				};
			};
		} else {
			if (!isNil {_entity getVariable 'QS_curator_spawnedObj'}) then {
				_arrayToAdd pushBackUnique _entity;
			};
		};
	} forEach _perfObjects;
	{
		private _perfEditable = ['curatorSync.addEditable',count (_x # 0)] call QS_fnc_perfBegin;
		_module addCuratorEditableObjects _x;
		[_perfEditable,count (_x # 0)] call QS_fnc_perfEnd;
		sleep 0.2;
	} forEach [	
		[(allPlayers select {(!(_x getVariable ['QS_curator_disableEditability',FALSE]))}),FALSE],
		[(allUnits select {(!(_x getVariable ['QS_curator_disableEditability',FALSE]))}),TRUE],
		[(allDead select {(!(_x getVariable ['QS_dead_prop',FALSE]))}),TRUE],
		[_arrayToAdd,TRUE]
	];
	[_perfSync,count _arrayToAdd] call QS_fnc_perfEnd;
};
