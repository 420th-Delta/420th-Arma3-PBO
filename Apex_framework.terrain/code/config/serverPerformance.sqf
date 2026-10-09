// Temporary server-freeze diagnostics. All state/logging stays on the server.
// These can also be changed in the SERVER debug console while running.
missionNamespace setVariable ['QS_perf_enabled',FALSE];
missionNamespace setVariable ['QS_perf_slowMs',250];
missionNamespace setVariable ['QS_perf_frameGapMs',1000];
missionNamespace setVariable ['QS_perf_summarySeconds',60];
missionNamespace setVariable ['QS_perf_detailLimit',20]; // SLOW lines per summary window

// Corrupt-transform diagnostics. Server-local and read-only.
missionNamespace setVariable ['QS_transformDiag_enabled',FALSE];
missionNamespace setVariable ['QS_transformDiag_scanSeconds',10];
missionNamespace setVariable ['QS_transformDiag_batchSize',100];
missionNamespace setVariable ['QS_transformDiag_queueLimit',8192];
missionNamespace setVariable ['QS_transformDiag_cacheLimit',8192];
missionNamespace setVariable ['QS_transformDiag_relogSeconds',60];
missionNamespace setVariable ['QS_transformDiag_cacheExpireSeconds',600];
missionNamespace setVariable ['QS_transformDiag_f16Limit',65000];
missionNamespace setVariable ['QS_transformDiag_worldMargin',6000];
missionNamespace setVariable ['QS_transformDiag_minWorldZ',-1000];
missionNamespace setVariable ['QS_transformDiag_maxWorldZ',20000];
missionNamespace setVariable ['QS_transformDiag_orthogonalTolerance',0.05];
missionNamespace setVariable ['QS_transformDiag_bombTraceEnabled',FALSE];
missionNamespace setVariable ['QS_transformDiag_bombSampleSeconds',0.1];
missionNamespace setVariable ['QS_transformDiag_bombSampleLimit',16];
missionNamespace setVariable ['QS_transformDiag_bombTraceSeconds',180];
