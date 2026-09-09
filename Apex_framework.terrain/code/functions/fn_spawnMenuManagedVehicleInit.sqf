/* Registers a newly spawned vehicle with Spawn Menu ownership and protection. */
if (!isServer) exitWith {};

params [
	['_vehicle',objNull,[objNull]],
	['_ownerUID','',['']],
	['_vehicleSide',sideUnknown,[sideUnknown]]
];

if (
	isNull _vehicle ||
	{_ownerUID isEqualTo ''} ||
	{((['LandVehicle','Air','Ship'] findIf {_vehicle isKindOf _x}) isEqualTo -1)}
) exitWith {};

_vehicle setVariable ['QS_spawnMenu_spawnedBy',_ownerUID,TRUE];
_vehicle setVariable ['QS_RD_vehicleRespawnable',TRUE,TRUE];
_vehicle setVariable ['TGC_vehicle_side',_vehicleSide,TRUE];
(missionNamespace getVariable ['QS_spawnMenu_spawnedEntities',[]]) pushBackUnique _vehicle;

if (!isNil 'TGC_fnc_addSpawnMenuVehicleHandlers') then {
	_vehicle setVariable ['QS_client_spawnMenuHandlers',TRUE,FALSE];
	[_vehicle] call TGC_fnc_addSpawnMenuVehicleHandlers;
	[_vehicle] call QS_fnc_serverPublishEntityState;
};

if (unitIsUAV _vehicle) then {
	_vehicle setVariable ['QS_uav_protected',TRUE,TRUE];
	if ((crew _vehicle) isEqualTo []) then {
		private _uavGroup = createVehicleCrew _vehicle;
		if (!isNull _uavGroup) then {
			_uavGroup setVariable ['QS_HComm_grp',FALSE,TRUE];
		};
	};
	{
		_x setVariable ['QS_spawnMenu_spawnedBy',_ownerUID,TRUE];
	} forEach (crew _vehicle);
	[_vehicle,_ownerUID] remoteExec ['TGC_fnc_lockDroneByUID',0,FALSE];
};
