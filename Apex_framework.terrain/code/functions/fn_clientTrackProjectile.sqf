/*/
File: fn_clientTrackProjectile.sqf

Description:

	Distribute and receive a single projectile tracking delta without sending
	the complete tracking arrays. The arrays are kept small so a long barrage
	cannot leave an ever-growing client-side workload behind.
____________________________________________________________/*/

params [
	['_projectile',objNull,[objNull]],
	['_draw2D',TRUE,[FALSE]],
	['_draw3D',TRUE,[FALSE]],
	['_broadcast',TRUE,[FALSE]]
];

if (isNull _projectile) exitWith {};

// Only accept network deltas from the machine that owns the projectile.
// Server-originated projectiles use owner 2.
if (
	isRemoteExecuted &&
	{(remoteExecutedOwner isNotEqualTo 2)} &&
	{(remoteExecutedOwner isNotEqualTo (owner _projectile))}
) exitWith {};

private _rateLimited = FALSE;
if (isRemoteExecuted) then {
	private _rateLimits = missionNamespace getVariable ['QS_projectileTracking_rateLimits',createHashMap];
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
	missionNamespace setVariable ['QS_projectileTracking_rateLimits',_rateLimits,FALSE];
	_rateLimited = (_rateState # 1) > 128;
};
if (_rateLimited) exitWith {};

// Local producers send one small delta to human-client owners only. Remote
// invocations never forward again.
if ((!isRemoteExecuted) && {_broadcast}) then {
	private _recipients = allPlayers select {
		(!(_x isKindOf 'HeadlessClient_F')) &&
		{(owner _x) isNotEqualTo clientOwner}
	};
	if (_recipients isNotEqualTo []) then {
		// Explicitly disable forwarding at the receiver. Some HC-to-client
		// deliveries do not preserve isRemoteExecuted/remoteExecutedOwner.
		[_projectile,_draw2D,_draw3D,FALSE] remoteExecCall [
			'QS_fnc_clientTrackProjectile',
			_recipients,
			FALSE
		];
	};
};

if (!hasInterface) exitWith {};

private _maxTrackedProjectiles = 128;
private _updateTrackingArray = {
	params ['_variableName','_projectile','_maxTrackedProjectiles'];
	private _trackedProjectiles = missionNamespace getVariable [_variableName,[]];
	if ((count _trackedProjectiles) > _maxTrackedProjectiles) then {
		_trackedProjectiles = _trackedProjectiles select [
			((count _trackedProjectiles) - _maxTrackedProjectiles),
			_maxTrackedProjectiles
		];
	};
	_trackedProjectiles = _trackedProjectiles select {(!isNull _x)};
	_trackedProjectiles pushBackUnique _projectile;
	if ((count _trackedProjectiles) > _maxTrackedProjectiles) then {
		_trackedProjectiles deleteAt 0;
	};
	missionNamespace setVariable [_variableName,_trackedProjectiles,FALSE];
};

if (_draw2D) then {
	['QS_draw2D_projectiles',_projectile,_maxTrackedProjectiles] call _updateTrackingArray;
};
if (_draw3D) then {
	['QS_draw3D_projectiles',_projectile,_maxTrackedProjectiles] call _updateTrackingArray;
};
