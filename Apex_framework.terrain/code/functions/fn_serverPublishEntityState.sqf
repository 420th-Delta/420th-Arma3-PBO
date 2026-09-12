/*/
File: fn_serverPublishEntityState.sqf

Description:

	Publish one complete, object-bound client-state snapshot. Reusing the entity
	as the JIP ID replaces its previous snapshot and removes it when the entity is
	deleted.
__________________________________________________/*/

if (!isServer) exitWith {};

params [['_entity',objNull,[objNull]]];

private '_publication';
// Keep the read and enqueue together so an older scheduled snapshot cannot replace a newer one.
isNil {
	if (isNull _entity) exitWith {};

	private _featureType = _entity getVariable ['QS_client_featureType',-1];
	private _face = _entity getVariable ['QS_client_face',''];
	private _spawnMenuHandlers = _entity getVariable ['QS_client_spawnMenuHandlers',FALSE];
	private _houseVectors = _entity getVariable ['QS_client_houseVectors',[]];

	if (!(_featureType isEqualType 0)) then {_featureType = -1;};
	if (!(_face isEqualType '')) then {_face = '';};
	if (!(_spawnMenuHandlers isEqualType FALSE)) then {_spawnMenuHandlers = FALSE;};
	private _validHouseVectors =
		(_entity isKindOf 'House') &&
		{!isSimpleObject _entity} &&
		{_houseVectors isEqualType []} &&
		{(count _houseVectors) isEqualTo 2} &&
		{(_houseVectors findIf {
			!(_x isEqualType []) ||
			{(count _x) isNotEqualTo 3} ||
			{(_x findIf {!(_x isEqualType 0) || {!finite _x}}) isNotEqualTo -1}
		}) isEqualTo -1};
	if (!_validHouseVectors) then {_houseVectors = [];};

	if (
		(!(_featureType in [0,1,2])) &&
		{_face isEqualTo ''} &&
		{!_spawnMenuHandlers} &&
		{_houseVectors isEqualTo []}
	) exitWith {};

	_publication = [
		_entity,
		_featureType,
		_face,
		_spawnMenuHandlers,
		_houseVectors
	] remoteExecCall ['QS_fnc_clientApplyEntityState',-2,_entity];
};
if (isNil '_publication') exitWith {};
_publication;
