/*/
File: fn_serverSetEntityFeatureType.sqf

Description:

	Validate and store an entity's persistent client feature type, then publish
	the entity's complete client-state snapshot. Requests from non-server
	machines are limited to aircraft local to the requesting owner.
__________________________________________________/*/

if (!isServer) exitWith {};

params [
	['_entity',objNull,[objNull]],
	['_featureType',-1,[0]]
];

if (isNull _entity || {!(_featureType in [0,1,2])}) exitWith {};

private _authorized = !isRemoteExecuted;
if (isRemoteExecuted) then {
	private _requestOwner = remoteExecutedOwner;
	_authorized = (
		(_requestOwner isEqualTo 2) ||
		{
			(_requestOwner > 2) &&
			{_entity isKindOf 'Air'} &&
			{(owner _entity) isEqualTo _requestOwner}
		}
	);
};

if (!_authorized) exitWith {};

if ((_entity getVariable ['QS_client_featureType',-1]) isEqualTo _featureType) exitWith {};

_entity setVariable ['QS_client_featureType',_featureType,FALSE];
[_entity] call QS_fnc_serverPublishEntityState;
