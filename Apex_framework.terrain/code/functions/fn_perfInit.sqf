// CfgFunctions preInit: no entities/network calls and no measured code is made unscheduled.
if (!isServer) exitWith {};
if (serverNamespace getVariable ['QS_perf_initialized',FALSE]) exitWith {};
serverNamespace setVariable ['QS_perf_initialized',TRUE];
call compile preprocessFileLineNumbers 'code\config\serverPerformance.sqf';
serverNamespace setVariable ['QS_perf_active',createHashMap];
serverNamespace setVariable ['QS_perf_stats',createHashMap];
serverNamespace setVariable ['QS_perf_recent',[]];
serverNamespace setVariable ['QS_perf_lastFrameTick',diag_tickTime];
serverNamespace setVariable ['QS_perf_gapLogTick',-10];
serverNamespace setVariable ['QS_perf_frameEH',addMissionEventHandler ['EachFrame',{
    private _perfNow = diag_tickTime;
    private _perfPrevious = serverNamespace getVariable ['QS_perf_lastFrameTick',_perfNow];
    serverNamespace setVariable ['QS_perf_lastFrameTick',_perfNow];
    if (!(missionNamespace getVariable ['QS_perf_enabled',FALSE])) exitWith {};
    private _perfGap = (_perfNow - _perfPrevious) * 1000;
    if (_perfGap < (missionNamespace getVariable ['QS_perf_frameGapMs',1000])) exitWith {};
    // At most one gap line per five seconds, even under sustained poor performance.
    if ((_perfNow - (serverNamespace getVariable ['QS_perf_gapLogTick',-10])) < 5) exitWith {};
    serverNamespace setVariable ['QS_perf_gapLogTick',_perfNow];
    private _perfActive = serverNamespace getVariable 'QS_perf_active';
    private _perfSpans = [];
    {
        if ((count _perfSpans) < 8) then {
            _perfSpans pushBack [_y # 0,_y # 1,(_perfNow - (_y # 2)) * 1000,_y # 5,_y # 6];
        };
    } forEach _perfActive;
    diag_log format ['[QS PERF] FRAME_GAP tick=%1 gapMs=%2 frame=%3 fps=%4 defend=%5 activeCount=%6 activeSample=%7 recent=%8',
        _perfNow,_perfGap toFixed 3,diag_frameNo,diag_fps,missionNamespace getVariable ['QS_defendActive',FALSE],count _perfActive,_perfSpans,serverNamespace getVariable 'QS_perf_recent'];
}]];
[] spawn {
    private _perfWindowStart = diag_tickTime;
    while {TRUE} do {
        uiSleep ((missionNamespace getVariable ['QS_perf_summarySeconds',60]) max 10);
        private _perfSnapshot = createHashMap;
        private _perfDropped = 0;
        private _perfStale = [];
        private _perfWindowEnd = diag_tickTime;
        // Swap buffers atomically; output happens scheduled, outside EachFrame.
        isNil {
            _perfSnapshot = serverNamespace getVariable 'QS_perf_stats';
            serverNamespace setVariable ['QS_perf_stats',createHashMap];
            serverNamespace setVariable ['QS_perf_details',0];
            serverNamespace setVariable ['QS_perf_severeDetails',0];
            _perfDropped = serverNamespace getVariable ['QS_perf_dropped',0];
            serverNamespace setVariable ['QS_perf_dropped',0];
            private _perfActive = serverNamespace getVariable 'QS_perf_active';
            {
                if ((_perfWindowEnd - (_y # 2)) > 600) then {
                    _perfStale pushBack [_x,_y # 1];
                };
            } forEach _perfActive;
            {_perfActive deleteAt (_x # 0);} forEach _perfStale;
        };
        if (missionNamespace getVariable ['QS_perf_enabled',FALSE]) then {
            {
                _y params ['_calls','_total','_max','_slow','_cross','_inputs','_outputs','_knownInputs','_knownOutputs','_maxInput','_maxOutput'];
                diag_log format ['[QS PERF] SUMMARY op=%1 windowStart=%2 windowEnd=%3 calls=%4 totalMs=%5 avgMs=%6 maxMs=%7 slow=%8 crossFrame=%9 inputSum=%10 outputSum=%11 inputSamples=%12 outputSamples=%13 maxInput=%14 maxOutput=%15',
                    _x,_perfWindowStart,_perfWindowEnd,_calls,_total toFixed 3,(_total / (_calls max 1)) toFixed 3,_max toFixed 3,_slow,_cross,_inputs,_outputs,_knownInputs,_knownOutputs,_maxInput,_maxOutput];
                uiSleep 0.001;
            } forEach _perfSnapshot;
            if ((_perfDropped > 0) || {_perfStale isNotEqualTo []}) then {
                diag_log format ['[QS PERF] INCOMPLETE droppedStarts=%1 expiredSpans=%2 (error, termination, or >600s span; not proof of blocking)',_perfDropped,_perfStale];
            };
        };
        _perfWindowStart = _perfWindowEnd;
    };
};
diag_log '[QS PERF] INIT server-local profiler ready; elapsed times are wall time, not exclusive CPU time';
