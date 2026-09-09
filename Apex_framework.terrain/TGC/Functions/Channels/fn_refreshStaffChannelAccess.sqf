/*
Function: TGC_fnc_refreshStaffChannelAccess

Description:
    Reconcile whitelist-controlled channel access. This may be called after a
    late database whitelist response, a periodic whitelist broadcast, respawn,
    or during normal player setup.

Author:
    420th

*/
if (!hasInterface) exitWith {};
if !(missionNamespace getVariable ["QS_client_channelAccessInitialized", false]) exitWith {};

private _isStaff = (getPlayerUID player) in (["ALL"] call QS_fnc_whitelist);
private _isDonator = (getPlayerUID player) in (["DONATOR"] call QS_fnc_whitelist);

// Side remains readable by everyone, but only staff may use its VON.
[1, [true, _isStaff]] call TGC_fnc_enableChannel;
[] call TGC_fnc_refreshChannels;

// The first custom radio channel is the Staff channel.
if (_isStaff) then {
    [1, 1] call QS_fnc_clientRadio;
} else {
    [0, 1] call QS_fnc_clientRadio;
};

// Donator access follows entitlement, matching the existing join behavior.
// Removing an expired entitlement also updates the desired-channel list so a
// later respawn cannot restore stale access.
if (_isDonator) then {
    [1, 9] call QS_fnc_clientRadio;
} else {
    [0, 9] call QS_fnc_clientRadio;
};
