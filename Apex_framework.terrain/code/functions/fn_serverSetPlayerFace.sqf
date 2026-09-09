/*/
File: fn_serverSetPlayerFace.sqf

Description:

	Validate a player's face update on the server, store it as canonical client
	state, and publish the entity's complete client-state snapshot.
__________________________________________________/*/

if (!isServer) exitWith {};

params [
	['_unit',objNull,[objNull]],
	['_face','',['']]
];

if (
	isNull _unit ||
	{!isPlayer _unit} ||
	{!(_unit isKindOf 'CAManBase')} ||
	{_face isEqualTo ''} ||
	{(count _face) > 128}
) exitWith {};

private _authorized = !isRemoteExecuted;
if (isRemoteExecuted) then {
	private _requestOwner = remoteExecutedOwner;
	_authorized = (
		(_requestOwner isEqualTo 2) ||
		{
			(_requestOwner > 2) &&
			{(owner _unit) isEqualTo _requestOwner}
		}
	);
};

if (!_authorized) exitWith {};

if ((_unit getVariable ['QS_client_face','']) isEqualTo _face) exitWith {};

_unit setVariable ['QS_client_face',_face,FALSE];
[_unit] call QS_fnc_serverPublishEntityState;
