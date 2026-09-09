/*/
File: fn_clientApplyEntityState.sqf

Description:

	Apply the latest server-authored, entity-bound client state. All persistent
	client state for an entity shares one JIP entry so updates cannot overwrite
	each other accidentally.
__________________________________________________/*/

if (isRemoteExecuted && {(remoteExecutedOwner isNotEqualTo 2)}) exitWith {};

params [
	['_entity',objNull,[objNull]],
	['_featureType',-1,[0]],
	['_face','',['']],
	['_spawnMenuHandlers',FALSE,[FALSE]]
];

if (isNull _entity) exitWith {};

if (_featureType in [0,1,2]) then {
	_entity setFeatureType _featureType;
};

if ((_face isNotEqualTo '') && {(_entity isKindOf 'CAManBase')}) then {
	_entity setFace _face;
};

if (
	_spawnMenuHandlers &&
	{!(_entity getVariable ['QS_client_spawnMenuHandlersApplied',FALSE])} &&
	{!isNil 'TGC_fnc_addSpawnMenuVehicleHandlers'}
) then {
	_entity setVariable ['QS_client_spawnMenuHandlersApplied',TRUE,FALSE];
	[_entity] call TGC_fnc_addSpawnMenuVehicleHandlers;
};
