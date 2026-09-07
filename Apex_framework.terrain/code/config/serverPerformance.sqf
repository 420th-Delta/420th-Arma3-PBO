// Temporary server-freeze diagnostics. All state/logging stays on the server.
// These can also be changed in the SERVER debug console while running.
missionNamespace setVariable ['QS_perf_enabled',TRUE];
missionNamespace setVariable ['QS_perf_slowMs',250];
missionNamespace setVariable ['QS_perf_frameGapMs',1000];
missionNamespace setVariable ['QS_perf_summarySeconds',60];
missionNamespace setVariable ['QS_perf_detailLimit',20]; // SLOW lines per summary window
