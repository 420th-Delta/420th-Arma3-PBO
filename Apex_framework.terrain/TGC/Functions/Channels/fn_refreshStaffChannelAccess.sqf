/*
Function: TGC_fnc_refreshStaffChannelAccess

Description:
    Reconcile whitelist-controlled channel access. This may be called after a
    late database whitelist response, a periodic whitelist broadcast, respawn,
    or during normal player setup.

Author:
    420th

*/
/* Legacy Code as of 9.9.2026 */
//|if (!hasInterface) exitWith {};
//|if !(missionNamespace getVariable ["QS_client_channelAccessInitialized", false]) exitWith {};
// Updated Code
params [['_force',FALSE]];
if (!hasInterface || {isNull player}) exitWith {};
if !(missionNamespace getVariable ['QS_client_channelAccessInitialized',FALSE]) exitWith {};
// End Updated Code

/* Legacy Code as of 9.9.2026 */
//|private _isStaff = (getPlayerUID player) in (["ALL"] call QS_fnc_whitelist);
// Updated Code
private _uid = getPlayerUID player;
// Preserve the existing private Staff channel's ALL eligibility.
private _isStaff = _uid in (['ALL'] call QS_fnc_whitelist);
private _isDonator = _uid in (['DONATOR'] call QS_fnc_whitelist);
private _sharedRadioChannelsEnabled = missionNamespace getVariable ['QS_radio_sharedBroadcastsEnabled',FALSE];
if (!_sharedRadioChannelsEnabled) exitWith {
    // Preserve the served mission's channel policy while the shared radio
    // design is tabled: native Side text for everyone and VON for staff.
    [1,[TRUE,_isStaff]] call TGC_fnc_enableChannel;
    [] call TGC_fnc_refreshChannels;
    [([0,1] select _isStaff),1] call QS_fnc_clientRadio;
    [([0,1] select _isDonator),9] call QS_fnc_clientRadio;
};

// Experimental shared Side/staff General policy. The server publishes the
// startup-only feature gate and does not allocate its channel while disabled.
private _generalVoice = (_uid in (['ADMIN'] call QS_fnc_whitelist)) ||
    {_uid in (['CURATOR'] call QS_fnc_whitelist)} ||
    {serverCommandAvailable '#logout'} || {!isNull (getAssignedCuratorLogic player)};
private _sideChannel = missionNamespace getVariable ['QS_radioChannel_side',0];
private _sideRequested = missionProfileNamespace getVariable ['QS_client_radioChannel_side',TRUE];
// Custom Side is shared across all teams. Watch the actual group/side, since
// group switching does not always replace the player body or run respawn code.
private _group = group player;
private _state = [player,_isStaff,_generalVoice,_sideChannel,_sideRequested,_group,side _group,_isDonator];
private _previous = missionNamespace getVariable ['QS_client_radioAccessState',[]];
if (!_force && {_state isEqualTo _previous}) exitWith {};
private _groupChanged = (_previous param [5,grpNull]) isNotEqualTo _group ||
    {(_previous param [6,sideUnknown]) isNotEqualTo (side _group)};
// End Updated Code

/* Legacy Code as of 9.9.2026 */
//|// Side remains readable by everyone, but only staff may use its VON.
//|[1, [true, _isStaff]] call TGC_fnc_enableChannel;
//|[] call TGC_fnc_refreshChannels;
//|
//|// The first custom radio channel is the Staff channel.
//|if (_isStaff) then {
//|    [1, 1] call QS_fnc_clientRadio;
//|} else {
//|    [0, 1] call QS_fnc_clientRadio;
// Updated Code
// This runs in the existing one-second radio loop. Only state changes touch
// channel permissions or membership; there is no new worker or network poll.
isNil {
    missionNamespace setVariable ['QS_client_radioAccessState',_state];
    // Allocation can fail on older engines or when all custom slots are used.
    // Native Side then preserves team-local communication; it cannot provide
    // the optional cross-team receive membership of a custom channel.
    [1,[_sideChannel <= 0,_sideChannel <= 0]] call TGC_fnc_enableChannel;
    if (_sideChannel > 0) then {
		// Arma 2.22+: custom 1-10 -> UI 6-15; custom 11-50 -> UI 26-65.
        private _sideUI = _sideChannel + ([5,15] select (_sideChannel > 10));
        [_sideUI,[TRUE,TRUE]] call TGC_fnc_enableChannel;
    };
    [13,[TRUE,_generalVoice]] call TGC_fnc_enableChannel;
    [] call TGC_fnc_refreshChannels;
    // A returning client may still have native Side selected from the old setup.
    if (_sideChannel > 0 && {currentChannel isEqualTo 1}) then {setCurrentChannel 5;};
    [1,8] call QS_fnc_clientRadio;
    if (_sideChannel > 0) then {
        [([0,1] select _sideRequested),_sideChannel] call QS_fnc_clientRadio;
        if (_sideRequested && {_groupChanged} && {alive player}) then {
            // Reapply actual receive membership even if the saved local roster
            // still lists Side. No team filter and no per-tick membership writes.
            _sideChannel radioChannelAdd [player];
        };
    };
    // The private Staff/Admin channel keeps its original access rule.
    [([0,1] select _isStaff),1] call QS_fnc_clientRadio;
// End Updated Code
};

// Donator access follows entitlement, matching the existing join behavior.
// Removing an expired entitlement also updates the desired-channel list so a
// later respawn cannot restore stale access.
if (_isDonator) then {
    [1, 9] call QS_fnc_clientRadio;
} else {
    [0, 9] call QS_fnc_clientRadio;
};
