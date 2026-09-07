/* Server-only span: [operation, input object count (-1 = unknown), small metadata array].
   Keep operation names fixed; never use object IDs/classes as aggregation keys.
   Do not wrap the measured code in isNil: its original scheduling must be preserved. */
if (!isServer || {!(missionNamespace getVariable ['QS_perf_enabled',FALSE])}) exitWith {[]};
params ['_perfOperation',['_perfInput',-1],['_perfMetadata',[]]];
private _perfScheduled = canSuspend;
private _perfToken = [];
// Only profiler bookkeeping is atomic. Bound retained spans if a caller errors/exits.
isNil {
    private _perfActive = serverNamespace getVariable 'QS_perf_active';
    if ((count _perfActive) < 256) then {
        private _perfId = (serverNamespace getVariable ['QS_perf_sequence',0]) + 1;
        serverNamespace setVariable ['QS_perf_sequence',_perfId];
        _perfToken = [str _perfId,_perfOperation,diag_tickTime,diag_frameNo,_perfScheduled,_perfInput,_perfMetadata,missionNamespace getVariable ['QS_defendActive',FALSE]];
        _perfActive set [_perfToken # 0,_perfToken];
    } else {
        serverNamespace setVariable ['QS_perf_dropped',(serverNamespace getVariable ['QS_perf_dropped',0]) + 1];
    };
};
_perfToken
