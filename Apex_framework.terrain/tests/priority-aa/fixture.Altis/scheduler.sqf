/* Native-engine lifecycle checks. Only the battery worker is replaced; scheduler code is real. */
private _missionKeys = [
	'QS_fnc_SMpriorityAA','QS_fnc_smDebrief','QS_AOpos','QS_missionConfig_priorityAA_enabled',
	'QS_missionConfig_priorityAA_onNewAO','QS_missionConfig_priorityAA_interval','QS_missionConfig_sideMissions',
	'QS_customAO_blockSideMissions','QS_priorityAA_active','QS_priorityAA_position','QS_priorityAA_evacPosition',
	'QS_priorityAA_paused','QS_priorityAA_force','QS_priorityAA_abort','QS_priorityAA_success',
	'QS_priorityAA_instanceId','QS_priorityAA_spawnedInstance','QS_smAbort','QS_smSuccess','QS_smSuspend',
	'QS_sideMissionActive','QS_evacPosition_2','QS_missionConfig_priorityAA_minPlayers','QS_priorityAA_legacyActive'
];
private _savedMission = _missionKeys apply {[_x,!isNil {missionNamespace getVariable _x},missionNamespace getVariable [_x,[]]]};
private _serverKeys = ['QS_priorityAA_scheduler','QS_smDebrief_queue','QS_smDebrief_running'];
private _savedServer = _serverKeys apply {[_x,!isNil {serverNamespace getVariable _x},serverNamespace getVariable [_x,[]]]};
private _realDebrief = missionNamespace getVariable 'QS_fnc_smDebrief';
private _ownedScripts = [];
private _wait = {
	params ['_condition','_label'];
	private _deadline = diag_tickTime + 5;
	waitUntil {uiSleep 0.01; (call _condition) || {diag_tickTime > _deadline}};
	[call _condition,_label,if (call _condition) then {''} else {[
		serverNamespace getVariable ['QS_priorityAA_scheduler',createHashMap],
		serverNamespace getVariable ['T420_AA_schedulerAttempts',[]],
		missionNamespace getVariable ['QS_priorityAA_spawnedInstance',-1],
		missionNamespace getVariable ['QS_missionConfig_priorityAA_minPlayers',-1],
		missionNamespace getVariable ['QS_priorityAA_legacyActive',FALSE]
	]}] call T420_AA_fnc_assert;
};
private _tick = {
	params ['_now',['_ai',0],['_cap',100],['_players',30]];
	['TICK',[_now,_ai,_cap,_players]] call QS_fnc_priorityAAScheduler;
	private _handle = (serverNamespace getVariable 'QS_priorityAA_scheduler') get 'script';
	if (!isNull _handle) then {_ownedScripts pushBackUnique _handle;};
};
private _reset = {
	{if (!scriptDone _x) then {terminate _x;};} forEach _ownedScripts;
	_ownedScripts = [];
	serverNamespace setVariable ['QS_priorityAA_scheduler',nil];
	serverNamespace setVariable ['T420_AA_schedulerAttempts',[]];
	serverNamespace setVariable ['T420_AA_schedulerReleases',[]];
	serverNamespace setVariable ['T420_AA_schedulerFail',FALSE];
	{
		missionNamespace setVariable _x;
	} forEach [
		['QS_AOpos',[22000,21000,0]],['QS_missionConfig_priorityAA_enabled',TRUE],
		['QS_missionConfig_priorityAA_minPlayers',10],['QS_priorityAA_legacyActive',FALSE],
		['QS_missionConfig_priorityAA_onNewAO',FALSE],['QS_missionConfig_priorityAA_interval',[600,1800]],
		['QS_missionConfig_sideMissions',0],['QS_customAO_blockSideMissions',FALSE],
		['QS_priorityAA_paused',FALSE],['QS_priorityAA_force',FALSE],['QS_priorityAA_abort',FALSE],
		['QS_priorityAA_active',FALSE],
		['QS_smAbort',TRUE],['QS_smSuccess',TRUE],['QS_smSuspend',TRUE],['QS_sideMissionActive',TRUE]
	];
};
missionNamespace setVariable ['QS_fnc_SMpriorityAA',{
	params ['_instance','_position'];
	(serverNamespace getVariable 'T420_AA_schedulerAttempts') pushBack [_instance,+_position];
	if (serverNamespace getVariable ['T420_AA_schedulerFail',FALSE]) exitWith {};
	missionNamespace setVariable ['QS_priorityAA_spawnedInstance',_instance];
	waitUntil {uiSleep 0.01; _instance in (serverNamespace getVariable 'T420_AA_schedulerReleases')};
}];

call _reset;
[50] call _tick;
private _state = serverNamespace getVariable 'QS_priorityAA_scheduler';
[(_state get 'due') isEqualTo -1,'AA timer remains unarmed before readiness'] call T420_AA_fnc_assert;
['AO',[22000,21000,0],30] call QS_fnc_priorityAAScheduler;
[(_state get 'pending') isEqualTo [],'AO event does not schedule AA while AO mode is disabled'] call T420_AA_fnc_assert;
[100] call _tick;
private _firstDue = _state get 'due';
[(_firstDue >= 700) && {_firstDue <= 1900},'Initial AA delay is 10–30 minutes after readiness',_firstDue] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_interval',[600,600]];
[_firstDue - 1] call _tick;
[!(_state get 'active'),'AA does not start before its independent timer is due'] call T420_AA_fnc_assert;
[_firstDue,100,100,30] call _tick;
[!(_state get 'active'),'Automatic AA respects the AI cap'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_customAO_blockSideMissions',TRUE];
[_firstDue] call _tick;
[!(_state get 'active'),'AA respects custom mission blocking'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_customAO_blockSideMissions',FALSE];
missionNamespace setVariable ['QS_priorityAA_paused',TRUE];
[_firstDue] call _tick;
[!(_state get 'active'),'AA pause defers a due timer'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_priorityAA_paused',FALSE];
missionNamespace setVariable ['QS_missionConfig_priorityAA_enabled',FALSE];
[_firstDue] call _tick;
[!(_state get 'active'),'AA master switch prevents future starts'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_enabled',TRUE];
[_firstDue] call _tick;
[{(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 1},'AA starts with ordinary side missions disabled'] call _wait;
[_firstDue + 1] call _tick;
private _secondDue = _state get 'due';
[_secondDue isEqualTo (_firstDue + 601),'Successful spawn starts the next timer before completion',_secondDue] call T420_AA_fnc_assert;
[_secondDue] call _tick;
[(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 1,'A due timer cannot overlap an unfinished AA battery'] call T420_AA_fnc_assert;
[(missionNamespace getVariable 'QS_smAbort') && {missionNamespace getVariable 'QS_smSuccess'} && {missionNamespace getVariable 'QS_smSuspend'} && {missionNamespace getVariable 'QS_sideMissionActive'},'Dedicated scheduling leaves ordinary side state intact'] call T420_AA_fnc_assert;
(serverNamespace getVariable 'T420_AA_schedulerReleases') pushBack (_state get 'instance');
[{scriptDone (_state get 'script')},'Controlled first battery finishes'] call _wait;
[_secondDue] call _tick;
[{(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 2},'Overdue AA starts after the previous battery ends without a second full delay'] call _wait;

call _reset;
serverNamespace setVariable ['T420_AA_schedulerFail',TRUE];
missionNamespace setVariable ['QS_priorityAA_force',TRUE];
[100] call _tick;
_state = serverNamespace getVariable 'QS_priorityAA_scheduler';
[{scriptDone (_state get 'script')},'Failed battery setup returns'] call _wait;
[101] call _tick;
[(_state get 'retryAt') isEqualTo 161,'Failed placement has a bounded 60-second retry delay'] call T420_AA_fnc_assert;
[160] call _tick;
[(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 1,'Failed placement does not busy-loop'] call T420_AA_fnc_assert;
serverNamespace setVariable ['T420_AA_schedulerFail',FALSE];
[161] call _tick;
[{(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 2},'Failed request can retry after its cooldown'] call _wait;

call _reset;
missionNamespace setVariable ['QS_missionConfig_priorityAA_onNewAO',TRUE];
[100] call _tick;
_state = serverNamespace getVariable 'QS_priorityAA_scheduler';
[!(_state get 'active'),'AO mode does not invent a request on enable'] call T420_AA_fnc_assert;
['AO',[22000,21000,0],30] call QS_fnc_priorityAAScheduler;
[101] call _tick;
[{(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 1},'New AO starts one AA request'] call _wait;
[102] call _tick;
['AO',[23000,21000,0],30] call QS_fnc_priorityAAScheduler;
['AO',[24000,21000,0],30] call QS_fnc_priorityAAScheduler;
[10000] call _tick;
[(_state get 'pending') isEqualTo [3,[24000,21000,0]],'Only the latest waiting AO is retained'] call T420_AA_fnc_assert;
[(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 1,'AO generation requests cannot stack active batteries'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_enabled',FALSE];
[10001] call _tick;
[(_state get 'active') && {!(missionNamespace getVariable 'QS_priorityAA_abort')},'Disabling future AA starts leaves the existing objective intact'] call T420_AA_fnc_assert;
(serverNamespace getVariable 'T420_AA_schedulerReleases') pushBack (_state get 'instance');
[{scriptDone (_state get 'script')},'First AO-linked battery finishes'] call _wait;
[10002] call _tick;
[!(_state get 'active') && {(_state get 'pending') isNotEqualTo []},'Disabled channel retains the waiting AO'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_enabled',TRUE];
missionNamespace setVariable ['QS_priorityAA_paused',TRUE];
[10003] call _tick;
[!(_state get 'active') && {(_state get 'pending') isNotEqualTo []},'Paused channel retains the waiting AO'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_priorityAA_paused',FALSE];
[10004] call _tick;
[{(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 2},'Resuming starts the latest waiting AO'] call _wait;
private _attempts = serverNamespace getVariable 'T420_AA_schedulerAttempts';
[((_attempts # 1) # 1) isEqualTo [24000,21000,0],'New battery uses its requested AO position snapshot'] call T420_AA_fnc_assert;
[10005] call _tick;
(serverNamespace getVariable 'T420_AA_schedulerReleases') pushBack (_state get 'instance');
[{scriptDone (_state get 'script')},'Latest AO-linked battery finishes'] call _wait;
[20000] call _tick;
[20001] call _tick;
[(count _attempts) isEqualTo 2,'Ordinary ticks and Defend without a new AO event do not duplicate AA'] call T420_AA_fnc_assert;
['AO',[25000,21000,0],30] call QS_fnc_priorityAAScheduler;
missionNamespace setVariable ['QS_missionConfig_priorityAA_onNewAO',FALSE];
[30000] call _tick;
[!(_state get 'active') && {(_state get 'pending') isEqualTo []},'Changing to timer mode discards stale AO requests and starts a fresh timer'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_onNewAO',TRUE];
[30001] call _tick;
[!(_state get 'active'),'Re-enabling AO mode does not replay the discarded request'] call T420_AA_fnc_assert;
['AO',[26000,21000,0],30] call QS_fnc_priorityAAScheduler;
[30002] call _tick;
[{(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 3},'The next genuine AO event works after a mode switch'] call _wait;

// Population changes route the same AA request into exactly one mission channel.
call _reset;
missionNamespace setVariable ['QS_missionConfig_priorityAA_interval',[600,600]];
private _ordinaryPool = ['QS_fnc_SMRescuePOW',0.2,'QS_fnc_SMPriorityAA',0.4,'QS_fnc_SMPriorityARTY',0.4];
private _withoutAA = ['QS_fnc_SMRescuePOW',0.2,'QS_fnc_SMPriorityARTY',0.4];
private _withLegacy = _withoutAA + ['QS_fnc_SMpriorityAALegacy',0.4];
[(([_ordinaryPool,9] call QS_fnc_priorityAASidePool) isEqualTo _withLegacy),'Below threshold restores the stock AA weight in the ordinary pool'] call T420_AA_fnc_assert;
[(([_ordinaryPool,10] call QS_fnc_priorityAASidePool) isEqualTo _withoutAA),'At threshold removes AA from the ordinary pool'] call T420_AA_fnc_assert;
[(([_ordinaryPool,11] call QS_fnc_priorityAASidePool) isEqualTo _withoutAA),'Above threshold keeps ordinary non-AA weights unchanged'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_enabled',FALSE];
[(([_ordinaryPool,9] call QS_fnc_priorityAASidePool) isEqualTo _withoutAA),'AA master switch also disables future legacy starts'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_enabled',TRUE];
missionNamespace setVariable ['QS_priorityAA_paused',TRUE];
[(([_ordinaryPool,9] call QS_fnc_priorityAASidePool) isEqualTo _withoutAA),'AA pause also removes legacy from ordinary selection'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_priorityAA_paused',FALSE];
[100,0,100,9] call _tick;
_state = serverNamespace getVariable 'QS_priorityAA_scheduler';
[(_state get 'due') isEqualTo -1 && {!(_state get 'active')},'Low population leaves the enhanced timer unarmed'] call T420_AA_fnc_assert;
[200,0,100,10] call _tick;
[(_state get 'due') isEqualTo 800,'Reaching the threshold begins a fresh independent interval'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_priorityAA_legacyActive',TRUE];
[800,0,100,11] call _tick;
[!(_state get 'active'),'An unfinished legacy AA blocks enhanced starts after population rises'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_priorityAA_legacyActive',FALSE];
[801,0,100,10] call _tick;
[{(count (serverNamespace getVariable 'T420_AA_schedulerAttempts')) isEqualTo 1},'Enhanced AA starts after the older legacy mission releases its lane'] call _wait;
[802,0,100,10] call _tick;
[803,0,100,9] call _tick;
[(_state get 'active') && {!(missionNamespace getVariable 'QS_priorityAA_abort')} && {(_state get 'due') isEqualTo -1},'Dropping below threshold preserves an active battery and discards its future timer'] call T420_AA_fnc_assert;
[(([_ordinaryPool,9] call QS_fnc_priorityAASidePool) isEqualTo _withoutAA),'An unfinished enhanced battery blocks legacy AA after population drops'] call T420_AA_fnc_assert;
(serverNamespace getVariable 'T420_AA_schedulerReleases') pushBack (_state get 'instance');
[{scriptDone (_state get 'script')},'Population-transition battery finishes normally'] call _wait;
[804,0,100,9] call _tick;
[(([_ordinaryPool,9] call QS_fnc_priorityAASidePool) isEqualTo _withLegacy),'Legacy returns to the ordinary pool after the enhanced battery finishes'] call T420_AA_fnc_assert;
[900,0,100,11] call _tick;
[(_state get 'due') isEqualTo 1500,'Returning above threshold does not replay an overdue pre-transition timer'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_missionConfig_priorityAA_onNewAO',TRUE];
['AO',[25000,21000,0],11] call QS_fnc_priorityAAScheduler;
[(_state get 'pending') isNotEqualTo [],'An enhanced AO event can wait for its own channel'] call T420_AA_fnc_assert;
[901,0,100,9] call _tick;
['AO',[26000,21000,0],9] call QS_fnc_priorityAAScheduler;
[(_state get 'pending') isEqualTo [],'Entering low population discards old AO requests and does not queue low-population AOs'] call T420_AA_fnc_assert;
[902,0,100,10] call _tick;
[!(_state get 'active') && {(_state get 'pending') isEqualTo []},'Returning above threshold in AO mode waits for the next actual AO'] call T420_AA_fnc_assert;

// Position parity and reward serialization use real helpers, with reward execution stubbed.
missionNamespace setVariable ['QS_priorityAA_position',[22100,21100,0]];
missionNamespace setVariable ['QS_priorityAA_evacPosition',[22200,21200,0]];
missionNamespace setVariable ['QS_evacPosition_2',[17100,18100,0]];
private _ordinaryPosition = markerPos 'QS_marker_sideMarker';
private _positions = [FALSE] call QS_fnc_sideMissionPositions;
[_ordinaryPosition in _positions && {[22100,21100,0] in _positions} && {!([22200,21200,0] in _positions)},'Mission proximity includes both active lanes without evac when disabled'] call T420_AA_fnc_assert;
_positions = [TRUE] call QS_fnc_sideMissionPositions;
[[22200,21200,0] in _positions && {[17100,18100,0] in _positions},'Evac proximity retains both channels'] call T420_AA_fnc_assert;
missionNamespace setVariable ['QS_priorityAA_position',[]];
[((([FALSE] call QS_fnc_sideMissionPositions) findIf {_x isEqualTo []}) isEqualTo -1),'Inactive AA does not expose an invalid map origin'] call T420_AA_fnc_assert;

serverNamespace setVariable ['QS_smDebrief_queue',[]];
serverNamespace setVariable ['QS_smDebrief_running',FALSE];
serverNamespace setVariable ['T420_AA_rewardActive',0];
serverNamespace setVariable ['T420_AA_rewardPeak',0];
serverNamespace setVariable ['T420_AA_rewardRequests',[]];
serverNamespace setVariable ['T420_AA_realDebrief',_realDebrief];
missionNamespace setVariable ['QS_fnc_smDebrief',{
	if !(_this param [4,FALSE]) exitWith {_this call (serverNamespace getVariable 'T420_AA_realDebrief')};
	private _active = (serverNamespace getVariable 'T420_AA_rewardActive') + 1;
	serverNamespace setVariable ['T420_AA_rewardActive',_active];
	serverNamespace setVariable ['T420_AA_rewardPeak',_active max (serverNamespace getVariable 'T420_AA_rewardPeak')];
	uiSleep 0.05;
	(serverNamespace getVariable 'T420_AA_rewardRequests') pushBack +_this;
	serverNamespace setVariable ['T420_AA_rewardActive',(serverNamespace getVariable 'T420_AA_rewardActive') - 1];
}];
missionNamespace setVariable ['QS_priorityAA_instanceId',77];
[0,[1,2,0],-1,['T420_AA_old_task','Old AA','QS_priorityAA_evacPosition',TRUE,76]] call _realDebrief;
[(missionNamespace getVariable 'QS_priorityAA_evacPosition') isEqualTo [22200,21200,0],'Stale debrief cannot replace a successor evacuation position'] call T420_AA_fnc_assert;
[1,[3,4,0],-1,['T420_AA_current_task','Current AA','QS_priorityAA_evacPosition',TRUE,77]] call _realDebrief;
[{(count (serverNamespace getVariable 'T420_AA_rewardRequests')) isEqualTo 2 && {!(serverNamespace getVariable 'QS_smDebrief_running')}},'Both queued debriefs finish'] call _wait;
[(serverNamespace getVariable 'T420_AA_rewardPeak') isEqualTo 1,'Simultaneous completion cannot overlap shared reward allocation'] call T420_AA_fnc_assert;
[(missionNamespace getVariable 'QS_priorityAA_evacPosition') isEqualTo [3,4,0] && {(missionNamespace getVariable 'QS_evacPosition_2') isEqualTo [17100,18100,0]},'AA debrief updates only its own current evacuation position'] call T420_AA_fnc_assert;

// Native deleteTask resolves TRUE owners through isPlayer units. This dedicated fixture
// has no players, so provide a real local owner for both tasks to exercise removal.
private _taskObserverGroup = createGroup [WEST,TRUE];
private _taskObserver = _taskObserverGroup createUnit ['B_Soldier_F',[17000,18000,0],[],0,'NONE'];
_taskObserver enableSimulationGlobal FALSE;
private _createdOrdinaryTask = !(['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists);
if (_createdOrdinaryTask) then {
	['QS_IA_TASK_SM_0',_taskObserver,['Keep ordinary task','Ordinary task',''],_ordinaryPosition,'CREATED',5,FALSE,TRUE,'destroy',TRUE] call BIS_fnc_setTask;
};
['T420_AA_scoped_task',_taskObserver,['Scoped AA task','AA task',''],[22000,21000,0],'CREATED',5,FALSE,TRUE,'destroy',TRUE] call BIS_fnc_setTask;
[['T420_AA_scoped_task'] call BIS_fnc_taskExists && {['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists},'Both owner-backed tasks exist before scoped removal'] call T420_AA_fnc_assert;
createMarker ['T420_AA_scoped_marker',[22000,21000,0]];
'T420_AA_scoped_marker' setMarkerText 'Scoped AA marker';
createMarker ['T420_AA_scoped_circle',[22000,21000,0]];
[0,[22000,21000,0],['T420_AA_scoped_task','T420_AA_scoped_marker','T420_AA_scoped_circle',77]] call QS_fnc_priorityAADebrief;
// Multiplayer deletion is dispatched through BIS_fnc_mp; observe its completed effect.
[{!(['T420_AA_scoped_task'] call BIS_fnc_taskExists)},'AA debrief deletes its own unique task'] call _wait;
[['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists,'AA debrief preserves the concurrent ordinary task'] call T420_AA_fnc_assert;
[(markerPos 'QS_marker_sideMarker') isEqualTo _ordinaryPosition && {!('T420_AA_scoped_marker' in allMapMarkers)} && {!('T420_AA_scoped_circle' in allMapMarkers)},'AA debrief deletes only its own markers'] call T420_AA_fnc_assert;
[{(count (serverNamespace getVariable 'T420_AA_rewardRequests')) isEqualTo 3 && {!(serverNamespace getVariable 'QS_smDebrief_running')}},'Scoped helper debrief drains through the shared reward queue'] call _wait;
private _scopedRequest = (serverNamespace getVariable 'T420_AA_rewardRequests') # 2;
[((_scopedRequest # 3) # 1) isEqualTo 'Scoped AA marker','AA marker text is captured before unique marker deletion'] call T420_AA_fnc_assert;
if (_createdOrdinaryTask) then {
	['QS_IA_TASK_SM_0',[],TRUE] call BIS_fnc_deleteTask;
	[{!(['QS_IA_TASK_SM_0'] call BIS_fnc_taskExists)},'Fixture ordinary task can independently be deleted'] call _wait;
};
['T420_AA_scoped_task',[],TRUE] call BIS_fnc_deleteTask;
deleteMarker 'T420_AA_scoped_marker';
deleteMarker 'T420_AA_scoped_circle';
[[_taskObserver,_taskObserverGroup]] call T420_AA_fnc_cleanup;

{if (!scriptDone _x) then {terminate _x;};} forEach _ownedScripts;
{
	_x params ['_key','_present','_value'];
	missionNamespace setVariable [_key,if (_present) then {_value} else {nil}];
} forEach _savedMission;
{
	_x params ['_key','_present','_value'];
	serverNamespace setVariable [_key,if (_present) then {_value} else {nil}];
} forEach _savedServer;
{
	serverNamespace setVariable [_x,nil];
} forEach ['T420_AA_schedulerAttempts','T420_AA_schedulerReleases','T420_AA_schedulerFail','T420_AA_rewardActive','T420_AA_rewardPeak','T420_AA_rewardRequests','T420_AA_realDebrief'];
