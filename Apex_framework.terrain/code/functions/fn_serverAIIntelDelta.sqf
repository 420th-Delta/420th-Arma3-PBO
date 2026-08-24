/*/
File: fn_serverAIIntelDelta.sqf

Description:

	Merge a single AI target-intelligence update on the server, then send a
	bounded, debounced snapshot only to machines that currently own AI.
____________________________________________________________/*/

if (!isServer) exitWith {};

params [
	['_target',objNull,[objNull]],
	['_seenAt',serverTime,[0]],
	['_position',[0,0,0],[[]],[3]],
	['_knowledge',0,[0]],
	['_reportingGroup',grpNull,[grpNull]],
	['_onGround',FALSE,[FALSE]],
	['_rating',0,[0]]
];

if ((isNull _target) || {isNull _reportingGroup}) exitWith {};

private _aiOwners = missionNamespace getVariable ['QS_system_AI_owners',[2]];
if (
	isRemoteExecuted &&
	{(remoteExecutedOwner isNotEqualTo 2)} &&
	{
		(!(_aiOwners isEqualType [])) ||
		{(!(remoteExecutedOwner in _aiOwners))} ||
		{((groupOwner _reportingGroup) isNotEqualTo remoteExecutedOwner)}
	}
) exitWith {};

private _rateLimited = FALSE;
if (isRemoteExecuted) then {
	private _rateLimits = missionNamespace getVariable ['QS_AI_targetsIntel_rateLimits',createHashMap];
	if ((count _rateLimits) > 128) then {
		_rateLimits = createHashMap;
	};
	private _senderKey = str remoteExecutedOwner;
	private _rateState = _rateLimits getOrDefault [_senderKey,[diag_tickTime,0]];
	if (diag_tickTime >= ((_rateState # 0) + 1)) then {
		_rateState = [diag_tickTime,0];
	};
	_rateState set [1,(_rateState # 1) + 1];
	_rateLimits set [_senderKey,_rateState];
	missionNamespace setVariable ['QS_AI_targetsIntel_rateLimits',_rateLimits,FALSE];
	_rateLimited = (_rateState # 1) > 64;
};
if (_rateLimited) exitWith {};

private _targetsIntel = (missionNamespace getVariable ['QS_AI_targetsIntel',[]]) select {
	(alive (_x # 0)) &&
	{serverTime < ((_x # 1) + 300)}
};
private _targetIndex = _targetsIntel findIf {(_target isEqualTo (_x # 0))};
private _targetIntel = [_target,_seenAt,_position,_knowledge,_reportingGroup,_onGround,_rating];
if (_targetIndex isEqualTo -1) then {
	_targetsIntel pushBack _targetIntel;
} else {
	_targetsIntel set [_targetIndex,_targetIntel];
};

private _maxIntelTargets = 128;
if ((count _targetsIntel) > _maxIntelTargets) then {
	_targetsIntel = _targetsIntel select [
		((count _targetsIntel) - _maxIntelTargets),
		_maxIntelTargets
	];
};
missionNamespace setVariable ['QS_AI_targetsIntel',_targetsIntel,FALSE];

if (!(missionNamespace getVariable ['QS_AI_targetsIntel_netSyncPending',FALSE])) then {
	missionNamespace setVariable ['QS_AI_targetsIntel_netSyncPending',TRUE,FALSE];
	[] spawn {
		uiSleep 1;
		private _targetsIntel = (missionNamespace getVariable ['QS_AI_targetsIntel',[]]) select {
			(alive (_x # 0)) &&
			{serverTime < ((_x # 1) + 300)}
		};
		if ((count _targetsIntel) > 128) then {
			_targetsIntel = _targetsIntel select [((count _targetsIntel) - 128),128];
		};
		missionNamespace setVariable [
			'QS_AI_targetsIntel',
			_targetsIntel,
			(missionNamespace getVariable ['QS_system_AI_owners',[2]])
		];
		missionNamespace setVariable ['QS_AI_targetsIntel_netSyncPending',FALSE,FALSE];
	};
};
