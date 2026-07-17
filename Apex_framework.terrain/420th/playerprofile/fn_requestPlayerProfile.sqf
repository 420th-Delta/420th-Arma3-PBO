/*
Function: TGC_fnc_requestPlayerProfile

Description:
    Validate a client profile request and enqueue it for the server database worker.

Author:
    420th
*/
if (!isServer) exitWith {};
params [
    ["_target", objNull, [objNull]],
    ["_requestOwner", -1, [0]]
];

if (_requestOwner < 2) exitWith {};
private _requesterIndex = allPlayers findIf {owner _x isEqualTo _requestOwner};
if (_requesterIndex < 0) exitWith {};

private _requester = allPlayers # _requesterIndex;
if (isNull _target || {!isPlayer _target}) exitWith {};
if (_target isNotEqualTo _requester && {_requester distance _target > 6}) exitWith {};

// Keep repeated action-menu clicks from creating unnecessary database work.
private _requestTimes = localNamespace getVariable ["TGC_playerProfile_requestTimes", createHashMap];
localNamespace setVariable ["TGC_playerProfile_requestTimes", _requestTimes];
private _lastRequest = _requestTimes getOrDefault [_requestOwner, -10];
if (diag_tickTime - _lastRequest < 1.5) exitWith {};
_requestTimes set [_requestOwner, diag_tickTime];

private _uid = getPlayerUID _target;
if (_uid isEqualTo "") exitWith {};
private _playerName = name _target;

// Database functions reject RemoteExec-derived calls. Hand the validated request
// to the server-owned worker created during postInit instead.
private _queue = missionNamespace getVariable ["TGC_playerProfile_queryQueue", []];
_queue pushBack [_requestOwner, _uid, _playerName];
missionNamespace setVariable ["TGC_playerProfile_queryQueue", _queue];
