if (!hasInterface) exitWith {};
private _deadline = diag_tickTime + 30;
waitUntil {uiSleep 0.1; (missionNamespace getVariable ['IA_radioReady',FALSE]) || {diag_tickTime > _deadline}};
['radio.client.serverReady',missionNamespace getVariable ['IA_radioReady',FALSE]] call IA_fnc_assert;
if (!(missionNamespace getVariable ['IA_radioReady',FALSE])) exitWith {[] call IA_fnc_finish;};
private _fnc_scriptName = 'IA radio fixture';
{
    _x params ['_name','_path'];
    missionNamespace setVariable [_name,compile preprocessFileLineNumbers _path];
} forEach [
    ['TGC_fnc_enableChannel','production\TGC\Functions\Channels\fn_enableChannel.sqf'],
    ['TGC_fnc_getChannelMask','production\TGC\Functions\Channels\fn_getChannelMask.sqf'],
    ['TGC_fnc_refreshChannels','production\TGC\Functions\Channels\fn_refreshChannels.sqf'],
    ['TGC_fnc_setChannelMasks','production\TGC\Functions\Channels\fn_setChannelMasks.sqf'],
    ['TGC_fnc_refreshStaffChannelAccess','production\TGC\Functions\Channels\fn_refreshStaffChannelAccess.sqf'],
    ['TGC_fnc_staffChannelsGUI','production\TGC\Functions\Staff\fn_staffChannelsGUI.sqf'],
    ['TGC_fnc_isStaff','production\TGC\Functions\Staff\fn_isStaff.sqf'],
    ['QS_fnc_whitelist','production\TGC\Functions\Database\fn_dbWhitelist.sqf'],
    ['QS_fnc_clientRadio','production\code\functions\fn_clientRadio.sqf']
];
private _side = missionNamespace getVariable 'IA_radioSideChannel';
private _sideUI = _side + 15;
private _uid = getPlayerUID player;
private _oldPreference = missionProfileNamespace getVariable ['QS_client_radioChannel_side',TRUE];
QS_client_channelAccessInitialized = TRUE;
QS_client_radioChannels = [];
QS_client_radioAccessState = [];
QS_whitelist_data = createHashMap;
TGC_channels_masks = [];

// The tabled policy is disabled when the server has not explicitly published
// an opt-in. Exercise that production default before enabling the dormant path.
['radio.gate.defaultsOff',!(missionNamespace getVariable ['QS_radio_sharedBroadcastsEnabled',FALSE])] call IA_fnc_assert;
QS_radio_sharedBroadcastsEnabled = FALSE;
QS_radioChannel_side = 0;
_side radioChannelRemove [player];
8 radioChannelRemove [player];
[TRUE] call TGC_fnc_refreshStaffChannelAccess;
uiSleep 0.2;
['radio.legacy.nativeSidePolicy',(channelEnabled 1 select [0,2]) isEqualTo [TRUE,FALSE]] call IA_fnc_assert;
['radio.legacy.noCustomSideMembership',!(player in (radioChannelInfo _side # 3)) && {!(_side in QS_client_radioChannels)}] call IA_fnc_assert;
['radio.legacy.generalNotForced',!(8 in QS_client_radioChannels)] call IA_fnc_assert;
[1,8] call QS_fnc_clientRadio;
['radio.legacy.generalCanSubscribe',8 in QS_client_radioChannels] call IA_fnc_assert;
[0,8] call QS_fnc_clientRadio;
['radio.legacy.generalCanUnsubscribe',!(8 in QS_client_radioChannels)] call IA_fnc_assert;

QS_whitelist_data set ['ALL',createHashMapFromArray [[_uid,TRUE]]];
[TRUE] call TGC_fnc_refreshStaffChannelAccess;
['radio.legacy.staffSideVoice',(channelEnabled 1 select [0,2]) isEqualTo [TRUE,TRUE]] call IA_fnc_assert;
['radio.legacy.privateStaffMembership',1 in QS_client_radioChannels] call IA_fnc_assert;
isNil {[] call TGC_fnc_staffChannelsGUI;};
uiSleep 0.2;
private _legacyGuiMasks = [];
isNil {with uiNamespace do {_legacyGuiMasks = call TGC_fnc_getChannelMasks;};};
['radio.legacy.staffGUIOmitsTabledSide',(count _legacyGuiMasks) isEqualTo 4 && {(_legacyGuiMasks findIf {_x # 0 isEqualTo _sideUI}) isEqualTo -1},_legacyGuiMasks] call IA_fnc_assert;
closeDialog 2;
[[]] call TGC_fnc_setChannelMasks;

private _legacyGroup = createGroup [WEST,TRUE];
private _legacyBody = _legacyGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [2,0,0],[],0,'CAN_COLLIDE'];
QS_client_radioChannels = [8];
8 radioChannelAdd [_legacyBody];
private _legacyUntil = diag_tickTime + 5;
waitUntil {uiSleep 0.1; _legacyBody in (radioChannelInfo 8 # 3) || {diag_tickTime >= _legacyUntil}};
['radio.legacy.killedBodyRegistered',_legacyBody in (radioChannelInfo 8 # 3)] call IA_fnc_assert;
[3,0,_legacyBody] call QS_fnc_clientRadio;
_legacyUntil = diag_tickTime + 5;
waitUntil {uiSleep 0.1; !(_legacyBody in (radioChannelInfo 8 # 3)) || {diag_tickTime >= _legacyUntil}};
['radio.legacy.killedRemovesGeneral',!(_legacyBody in (radioChannelInfo 8 # 3))] call IA_fnc_assert;
deleteVehicle _legacyBody;
deleteGroup _legacyGroup;

// Explicit opt-in preserves the reviewed shared Side/mandatory General logic.
1 radioChannelRemove [player];
9 radioChannelRemove [player];
8 radioChannelRemove [player];
_side radioChannelRemove [player];
QS_radio_sharedBroadcastsEnabled = TRUE;
QS_client_radioChannels = [];
QS_client_radioAccessState = [];
QS_radioChannel_side = _side;
QS_whitelist_data = createHashMap;
missionProfileNamespace setVariable ['QS_client_radioChannel_side',TRUE];
[TRUE] call TGC_fnc_refreshStaffChannelAccess;
uiSleep 0.2;
['radio.custom.nativeSideClosed',(channelEnabled 1 select [0,2]) isEqualTo [FALSE,FALSE]] call IA_fnc_assert;
['radio.custom.sideEnabled',(channelEnabled _sideUI select [0,2]) isEqualTo [TRUE,TRUE]] call IA_fnc_assert;
['radio.custom.playerMember',player in (radioChannelInfo _side # 3)] call IA_fnc_assert;
['radio.general.requiredMember',player in (radioChannelInfo 8 # 3)] call IA_fnc_assert;
['radio.staff.privateForOrdinaryPlayer',!(player in (radioChannelInfo 1 # 3))] call IA_fnc_assert;

missionProfileNamespace setVariable ['QS_client_radioChannel_side',FALSE];
[] call TGC_fnc_refreshStaffChannelAccess;
uiSleep 0.2;
['radio.custom.optOutRemovesReceive',!(player in (radioChannelInfo _side # 3))] call IA_fnc_assert;
[0,8] call QS_fnc_clientRadio;
['radio.general.staleOptOutIgnored',8 in QS_client_radioChannels] call IA_fnc_assert;

QS_radioChannel_side = 0;
[] call TGC_fnc_refreshStaffChannelAccess;
['radio.fallback.nativeSideEnabled',(channelEnabled 1 select [0,2]) isEqualTo [TRUE,TRUE]] call IA_fnc_assert;
setCurrentChannel 1;
[TRUE] call TGC_fnc_refreshStaffChannelAccess;
['radio.fallback.selectionRetained',currentChannel isEqualTo 1] call IA_fnc_assert;
QS_radioChannel_side = _side;
missionProfileNamespace setVariable ['QS_client_radioChannel_side',TRUE];
[TRUE] call TGC_fnc_refreshStaffChannelAccess;

QS_whitelist_data set ['DONATOR',createHashMapFromArray [[_uid,TRUE]]];
[] call TGC_fnc_refreshStaffChannelAccess;
['radio.donor.entitlementAdded',9 in QS_client_radioChannels] call IA_fnc_assert;
QS_whitelist_data deleteAt 'DONATOR';
[] call TGC_fnc_refreshStaffChannelAccess;
['radio.donor.expiryInvalidatesCache',!(9 in QS_client_radioChannels)] call IA_fnc_assert;
QS_whitelist_data set ['ALL',createHashMapFromArray [[_uid,TRUE]]];
QS_whitelist_data set ['ADMIN',createHashMapFromArray [[_uid,TRUE]]];
[] call TGC_fnc_refreshStaffChannelAccess;
['radio.general.adminVoiceEnabled',(channelEnabled 13 select [0,2]) isEqualTo [TRUE,TRUE]] call IA_fnc_assert;
['radio.staff.eligibleMember',1 in QS_client_radioChannels] call IA_fnc_assert;

// This is the actual production GUI and its mask enumeration closure.
isNil {[] call TGC_fnc_staffChannelsGUI;};
uiSleep 0.2;
private _guiMasks = [];
isNil {with uiNamespace do {_guiMasks = call TGC_fnc_getChannelMasks;};};
['radio.staffGUI.includesSide',(_guiMasks findIf {_x # 0 isEqualTo _sideUI}) >= 0,_guiMasks] call IA_fnc_assert;
['radio.staffGUI.allControlsCreated',count (uiNamespace getVariable ['TGC_staffChannelsGUI_controls',[]]) isEqualTo count _guiMasks] call IA_fnc_assert;
closeDialog 2;
[[[_sideUI,[TRUE,FALSE]]]] call TGC_fnc_setChannelMasks;
['radio.staffMask.sideVoiceDisabled',(channelEnabled _sideUI select [0,2]) isEqualTo [TRUE,FALSE]] call IA_fnc_assert;
[TRUE] call TGC_fnc_refreshStaffChannelAccess;
['radio.staffMask.accessRefreshPreservesMask',(channelEnabled _sideUI select [0,2]) isEqualTo [TRUE,FALSE]] call IA_fnc_assert;
[[]] call TGC_fnc_setChannelMasks;

private _oldGroup = createGroup [WEST,TRUE];
private _oldBody = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [3,0,0],[],0,'CAN_COLLIDE'];
_side radioChannelAdd [_oldBody];
8 radioChannelAdd [_oldBody];
private _replicationUntil = diag_tickTime + 5;
waitUntil {uiSleep 0.1; (_oldBody in (radioChannelInfo 8 # 3) && {_oldBody in (radioChannelInfo _side # 3)}) || {diag_tickTime >= _replicationUntil}};
['radio.lifecycle.oldBodyRegistered',_oldBody in (radioChannelInfo 8 # 3) && {_oldBody in (radioChannelInfo _side # 3)},[local _oldBody,_oldBody in (radioChannelInfo 8 # 3),_oldBody in (radioChannelInfo _side # 3),QS_client_radioChannels]] call IA_fnc_assert;
[3,0,_oldBody] call QS_fnc_clientRadio;
uiSleep 0.2;
['radio.lifecycle.delayedKilledKeepsCurrentPlayer',player in (radioChannelInfo _side # 3)] call IA_fnc_assert;
['radio.lifecycle.killedRemovesExactOldBody',!(_oldBody in (radioChannelInfo _side # 3))] call IA_fnc_assert;
['radio.lifecycle.killedKeepsOldGeneralUntilRespawn',_oldBody in (radioChannelInfo 8 # 3)] call IA_fnc_assert;
[2,0,player,_oldBody] call QS_fnc_clientRadio;
_replicationUntil = diag_tickTime + 5;
waitUntil {uiSleep 0.1; !(_oldBody in (radioChannelInfo 8 # 3)) || {diag_tickTime >= _replicationUntil}};
['radio.lifecycle.respawnRemovesOldGeneral',!(_oldBody in (radioChannelInfo 8 # 3)),[QS_client_radioChannels,str _oldBody,(radioChannelInfo 8 # 3) apply {str _x}]] call IA_fnc_assert;
['radio.lifecycle.respawnKeepsNewGeneral',player in (radioChannelInfo 8 # 3)] call IA_fnc_assert;
if (_oldBody in (radioChannelInfo 8 # 3)) then {
    8 radioChannelRemove [_oldBody];
    uiSleep 0.5;
    ['radio_lifecycle_diagnostic',['isolated native remove after production remove/add',str _oldBody,(radioChannelInfo 8 # 3) apply {str _x}]] call IA_fnc_log;
};
deleteVehicle _oldBody;
// Also cover a genuinely absent replacement object: reversing same-frame
// operations must not discard a newly added unit while removing the old one.
// Each case owns a fresh old object; a previous retirement worker may still run.
private _freshOldBody = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [3,0,0],[],0,'CAN_COLLIDE'];
private _newBody = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [5,0,0],[],0,'CAN_COLLIDE'];
8 radioChannelAdd [_freshOldBody];
_replicationUntil = diag_tickTime + 5;
waitUntil {uiSleep 0.1; _freshOldBody in (radioChannelInfo 8 # 3) || {diag_tickTime >= _replicationUntil}};
['radio.lifecycle.freshReplacementAbsent',!(_newBody in (radioChannelInfo 8 # 3)) && {_freshOldBody in (radioChannelInfo 8 # 3)},
    [_freshOldBody in (radioChannelInfo 8 # 3),_newBody in (radioChannelInfo 8 # 3),local _freshOldBody,local _newBody]] call IA_fnc_assert;
[2,-1,_newBody,_freshOldBody] call QS_fnc_clientRadio;
_replicationUntil = diag_tickTime + 5;
waitUntil {uiSleep 0.1; (_newBody in (radioChannelInfo 8 # 3) && {!(_freshOldBody in (radioChannelInfo 8 # 3))}) || {diag_tickTime >= _replicationUntil}};
['radio.lifecycle.freshReplacementAndOldRemoval',_newBody in (radioChannelInfo 8 # 3) && {!(_freshOldBody in (radioChannelInfo 8 # 3))},
    [(radioChannelInfo 8 # 3) apply {str _x}]] call IA_fnc_assert;
['radio.lifecycle.otherMemberUnchanged',player in (radioChannelInfo 8 # 3)] call IA_fnc_assert;
deleteVehicle _newBody;
deleteVehicle _freshOldBody;
// Hold replacement membership beyond the old three-second observer bound. The
// old body must remain until the new body joins, then retire within the new
// bounded window.
private _slowOldBody = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [3,0,0],[],0,'CAN_COLLIDE'];
private _slowNewBody = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [5,0,0],[],0,'CAN_COLLIDE'];
8 radioChannelAdd [_slowOldBody];
_replicationUntil = diag_tickTime + 5;
waitUntil {uiSleep 0.1; _slowOldBody in (radioChannelInfo 8 # 3) || {diag_tickTime >= _replicationUntil}};
isNil {
	[2,-1,_slowNewBody,_slowOldBody] call QS_fnc_clientRadio;
	8 radioChannelRemove [_slowNewBody];
};
['radio.lifecycle.slowReplacementSetup',_slowOldBody in (radioChannelInfo 8 # 3) && {!(_slowNewBody in (radioChannelInfo 8 # 3))}] call IA_fnc_assert;
uiSleep 4;
['radio.lifecycle.slowReplacementKeepsOldPending',_slowOldBody in (radioChannelInfo 8 # 3) && {!(_slowNewBody in (radioChannelInfo 8 # 3))}] call IA_fnc_assert;
8 radioChannelAdd [_slowNewBody];
_replicationUntil = diag_tickTime + 4;
waitUntil {uiSleep 0.1; (!(_slowOldBody in (radioChannelInfo 8 # 3)) && {_slowNewBody in (radioChannelInfo 8 # 3)}) || {diag_tickTime >= _replicationUntil}};
['radio.lifecycle.slowReplacementRetiresOld',!(_slowOldBody in (radioChannelInfo 8 # 3)) && {_slowNewBody in (radioChannelInfo 8 # 3)}] call IA_fnc_assert;
deleteVehicle _slowNewBody;
deleteVehicle _slowOldBody;
{
    private _mode = _x;
    private _raceOldBody = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [3,0,0],[],0,'CAN_COLLIDE'];
    private _replacement = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [7,0,0],[],0,'CAN_COLLIDE'];
    8 radioChannelAdd [_raceOldBody];
    _side radioChannelAdd [_raceOldBody];
    _replicationUntil = diag_tickTime + 5;
    waitUntil {uiSleep 0.1; (_raceOldBody in (radioChannelInfo 8 # 3) && {_raceOldBody in (radioChannelInfo _side # 3)}) || {diag_tickTime >= _replicationUntil}};
    ['radio.lifecycle.raceOldBodyRegistered',_raceOldBody in (radioChannelInfo 8 # 3) && {_raceOldBody in (radioChannelInfo _side # 3)},
        [_mode,_raceOldBody in (radioChannelInfo 8 # 3),_raceOldBody in (radioChannelInfo _side # 3),_replacement in (radioChannelInfo 8 # 3),_replacement in (radioChannelInfo _side # 3),local _raceOldBody]] call IA_fnc_assert;
    [2,-1,_replacement,_raceOldBody] call QS_fnc_clientRadio;
    if (_mode isEqualTo 'DELETED') then {deleteVehicle _replacement;};
    if (_mode isEqualTo 'DEAD') then {
        _replacement setDamage 1;
        8 radioChannelRemove [_replacement];
        _side radioChannelRemove [_replacement];
    };
    if (_mode isEqualTo 'REVOKED') then {[0,_side,_replacement] call QS_fnc_clientRadio;};
    _replicationUntil = diag_tickTime + 5;
    waitUntil {uiSleep 0.1; (!(_raceOldBody in (radioChannelInfo 8 # 3)) && {!(_raceOldBody in (radioChannelInfo _side # 3))}) || {diag_tickTime >= _replicationUntil}};
    ['radio.lifecycle.raceRetiresOldBody',!(_raceOldBody in (radioChannelInfo 8 # 3)) && {!(_raceOldBody in (radioChannelInfo _side # 3))},[_mode]] call IA_fnc_assert;
    if (_mode isEqualTo 'REVOKED') then {[1,_side] call QS_fnc_clientRadio;};
    if (!isNull _replacement) then {deleteVehicle _replacement;};
    deleteVehicle _raceOldBody;
} forEach ['DELETED','DEAD','REVOKED'];
private _guardReplacement = _oldGroup createUnit ['B_Soldier_F',(getPosATL player) vectorAdd [9,0,0],[],0,'CAN_COLLIDE'];
[2,-1,_guardReplacement,player] call QS_fnc_clientRadio;
uiSleep 0.3;
['radio.lifecycle.currentLiveBodyNotRetired',player in (radioChannelInfo 8 # 3) && {_guardReplacement in (radioChannelInfo 8 # 3)}] call IA_fnc_assert;
deleteVehicle _guardReplacement;
deleteGroup _oldGroup;
QS_radio_sharedBroadcastsEnabled = FALSE;
missionProfileNamespace setVariable ['QS_client_radioChannel_side',_oldPreference];
['NOTE',['Radio tests use genuine client engine permissions/membership and actual staff GUI. Voice/audio delivery, second Steam identity and a real death/respawn remain integration acceptance checks.']] call IA_fnc_log;
[] call IA_fnc_finish;
