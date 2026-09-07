/* [token, output object count (-1 = unknown), small completion metadata array].
   Elapsed wall time includes scheduling delays/sleeps; frames identifies cross-frame spans.
   Metadata must not contain SQL arguments, player data, or large arrays. */
private _perfEnded = diag_tickTime;
private _perfEndFrame = diag_frameNo;
params ['_perfToken',['_perfOutput',-1],['_perfEndMetadata',[]]];
if (_perfToken isEqualTo []) exitWith {};
isNil {
    _perfToken params ['_perfId','_perfOperation','_perfStarted','_perfStartFrame','_perfScheduled','_perfInput','_perfMetadata','_perfDefend'];
    (serverNamespace getVariable 'QS_perf_active') deleteAt _perfId;
    if (missionNamespace getVariable ['QS_perf_enabled',FALSE]) then {
        private _perfMs = ((_perfEnded - _perfStarted) * 1000) max 0;
        private _perfFrames = _perfEndFrame - _perfStartFrame;
        private _perfSlow = _perfMs >= (missionNamespace getVariable ['QS_perf_slowMs',250]);
        private _perfStats = serverNamespace getVariable 'QS_perf_stats';
        // calls, totalMs, maxMs, slow, crossFrame, inputSum, outputSum,
        // knownInputSamples, knownOutputSamples, maxInput, maxOutput
        private _perfRow = _perfStats getOrDefault [_perfOperation,[0,0,0,0,0,0,0,0,0,-1,-1]];
        _perfRow set [0,(_perfRow # 0) + 1];
        _perfRow set [1,(_perfRow # 1) + _perfMs];
        _perfRow set [2,(_perfRow # 2) max _perfMs];
        if (_perfSlow) then {_perfRow set [3,(_perfRow # 3) + 1];};
        if (_perfFrames > 0) then {_perfRow set [4,(_perfRow # 4) + 1];};
        if (_perfInput >= 0) then {
            _perfRow set [5,(_perfRow # 5) + _perfInput];
            _perfRow set [7,(_perfRow # 7) + 1];
            _perfRow set [9,(_perfRow # 9) max _perfInput];
        };
        if (_perfOutput >= 0) then {
            _perfRow set [6,(_perfRow # 6) + _perfOutput];
            _perfRow set [8,(_perfRow # 8) + 1];
            _perfRow set [10,(_perfRow # 10) max _perfOutput];
        };
        _perfStats set [_perfOperation,_perfRow];
        // Bounded recent history lets FRAME_GAP report spans that finished before its handler ran.
        private _perfRecent = serverNamespace getVariable 'QS_perf_recent';
        _perfRecent pushBack [_perfEnded,_perfOperation,_perfMs,_perfFrames,_perfInput,_perfOutput];
        if ((count _perfRecent) > 16) then {_perfRecent deleteAt 0;};
        private _perfDetails = serverNamespace getVariable ['QS_perf_details',0];
        private _perfSevere = serverNamespace getVariable ['QS_perf_severeDetails',0];
        private _perfEmergency = (_perfMs >= 5000) && {_perfSevere < 10};
        if (_perfSlow && {(_perfDetails < (missionNamespace getVariable ['QS_perf_detailLimit',20])) || {_perfEmergency}}) then {
            serverNamespace setVariable ['QS_perf_details',_perfDetails + 1];
            if (_perfEmergency) then {serverNamespace setVariable ['QS_perf_severeDetails',_perfSevere + 1];};
            diag_log format ['[QS PERF] SLOW op=%1 id=%2 startTick=%3 endTick=%4 elapsedMs=%5 frames=%6 scheduled=%7 input=%8 output=%9 defendStart=%10 defendEnd=%11 meta=%12 endMeta=%13',
                _perfOperation,_perfId,_perfStarted,_perfEnded,_perfMs toFixed 3,_perfFrames,_perfScheduled,_perfInput,_perfOutput,_perfDefend,missionNamespace getVariable ['QS_defendActive',FALSE],_perfMetadata,_perfEndMetadata];
        };
    };
};
nil
