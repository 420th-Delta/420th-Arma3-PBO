/*/
File: fn_serverPublishEntityState.sqf

Description:

	Publish one complete, object-bound client-state snapshot. Reusing the entity
	as the JIP ID replaces its previous snapshot and removes it when the entity is
	deleted.
__________________________________________________/*/

if (!isServer) exitWith {};

params [['_entity',objNull,[objNull]]];

if (isNull _entity) exitWith {};

private _featureType = _entity getVariable ['QS_client_featureType',-1];
private _face = _entity getVariable ['QS_client_face',''];
private _spawnMenuHandlers = _entity getVariable ['QS_client_spawnMenuHandlers',FALSE];

if (!(_featureType isEqualType 0)) then {_featureType = -1;};
if (!(_face isEqualType '')) then {_face = '';};
if (!(_spawnMenuHandlers isEqualType FALSE)) then {_spawnMenuHandlers = FALSE;};

if (
	(!(_featureType in [0,1,2])) &&
	{_face isEqualTo ''} &&
	{!_spawnMenuHandlers}
) exitWith {};

[
	_entity,
	_featureType,
	_face,
	_spawnMenuHandlers
] remoteExecCall ['QS_fnc_clientApplyEntityState',-2,_entity];
