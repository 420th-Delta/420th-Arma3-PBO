/*
	Joins Spawn Menu AI to the player's group after group and unit locality
	are ready on the destination group owner.
*/
params [
	['_entity',objNull,[objNull]],
	['_recruiter',objNull,[objNull]],
	['_destinationGroup',grpNull,[grpNull]]
];

if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};

[_entity,_recruiter,_destinationGroup] spawn {
	params ['_entity','_recruiter','_destinationGroup'];
	private _timeout = diag_tickTime + 10;

	waitUntil {
		uiSleep 0.05;
		isNull _entity ||
		{isNull _recruiter} ||
		{isNull _destinationGroup} ||
		{diag_tickTime >= _timeout} ||
		{local _destinationGroup}
	};

	if (
		isNull _entity ||
		{isNull _recruiter} ||
		{isNull _destinationGroup}
	) exitWith {};

	if (
		diag_tickTime >= _timeout ||
		{!local _destinationGroup} ||
		{!alive _recruiter} ||
		{(group _recruiter) isNotEqualTo _destinationGroup} ||
		{(leader _destinationGroup) isNotEqualTo _recruiter}
	) exitWith {
		if (local _entity) then {
			deleteVehicle _entity;
		};
		if (local _recruiter) then {
			['AI recruitment was cancelled because group ownership changed.'] call QS_fnc_hint;
		};
	};

	[_entity] joinSilent _destinationGroup;
	_entity setVariable ['QS_spawnMenu_aiPendingJoin',FALSE,TRUE];
	if (!isNil 'TGC_fnc_addFriendlyAIHandlers') then {
		[_entity] call TGC_fnc_addFriendlyAIHandlers;
	};
};
