# Server-freeze diagnostics

Enabled by default in `code/config/serverPerformance.sqf`. Repack/deploy the mission and restart it to load the probes. No server configuration or database debug switch is required. Look for `[QS PERF] INIT` in the server RPT.

All diagnostic state is server-local. The probes do not broadcast, create JIP entries, enumerate extra world entities for the heartbeat, or change existing spawning/cleanup rules. They add some CPU/logging overhead; they are temporary diagnostics, not a performance fix.

## Output

- `[QS PERF] SUMMARY`: approximately every 60 seconds, one line per operation that completed. Includes call count, total/average/maximum elapsed milliseconds, slow/cross-frame call counts, sums and maxima of input/output object counts. All completed, admitted samples contribute, including fast calls. Empty operations are omitted.
- `[QS PERF] SLOW`: individual operations taking at least 250 ms, with start/end `diag_tickTime`, elapsed milliseconds, elapsed frames, original `canSuspend`, counts, Defend state, and operation-specific metadata. Default limit: 20 detail lines per summary window, with up to 10 additional severe (5+ second) samples. Summaries still include rate-limited details.
- `[QS PERF] FRAME_GAP`: at least 1,000 ms between server EachFrame callbacks. Includes current Defend state, up to 8 active spans, and the last 16 completed spans. Gap lines are limited to one per 5 seconds.
- `[QS PERF] INCOMPLETE`: starts dropped at the 256-active-span limit, or spans expired after 600 seconds. These can indicate script errors/termination or unusually long waits, not necessarily a blocking operation.

`frames=0` means both timing samples were taken in the same frame; `frames>0` means wall time includes other frames and possibly scheduler delays. Even a native-call probe can straddle a scheduling boundary. Total/batch spans include their original sleeps and nested work. Do **not** add nested timings together or interpret `totalMs` as exclusive CPU time. A completed sample belongs to its completion window even if it began in a previous window.

The frame-gap callback can only report a stall after processing resumes. Active spans are candidates that overlapped the gap, not proof of causation; a stalled operation may already be in `recent` instead. Recent records are `[endTick, operation, elapsedMs, frames, input, output]`; active samples are `[id, operation, ageMs, input, metadata]`. Startup/loading can also produce gaps. A gap can result from engine work, extensions, OS scheduling, or I/O outside these mission probes.

## Instrumented operations and count meanings

| Operation family | Input/output meaning and extra metadata |
| --- | --- |
| `dbQuery.callExtension.*` | Objects are 0/0. Separately times submission, response polling, multipart reads. Metadata is prepared-statement name; completion metadata is response character count (plus active query count for submission). No SQL arguments, response contents, or player identifiers are logged. |
| `outOfBounds.*` | Census output is all objects found; filter input/output is scanned/out-of-bounds objects. Deletion and damage inputs are requested target counts. Output -1 means deletion success is not synchronously verified. |
| `core.periodicCleanup` | Input is starting garbage-collector entry count; output is instrumented deletion requests, including crew deletion. Completion metadata: dead snapshot, mine snapshot, filtered entity census, ending garbage-collector entry count. Entries can overlap; these are not unique population totals. |
| `core.allDead`, `core.cleanupEntities` | Output is the existing census result count. No additional census is run. |
| `core.cleanup.deleteVehicle*` | Input 1 per requested target; output -1 (not a confirmed removal). |
| `core.endAOCleanup` | Input is the initial captured cleanup list; output is main-entity deletion requests. Completion metadata: final target-list size, attached-object deletion requests, terrain objects unhidden. Starts **after** the existing 30-second wait. Separate entity/attachment timings surround destructive calls. |
| `spawnGroup.total` | Input is requested composition size; output is final group size, including pre-existing members/recycled units. Not a count of newly allocated objects. Metadata: group type, recycler enabled. |
| `spawnGroup.createUnit`, `aoDefend.create*`, `aoEnemy.create*`, `serverObjectsMapper.create*` | Unit/vehicle input 1; output 0/1 for null/non-null result. Crew input 1 vehicle; output is its crew count after creation. The AO join probe also includes its original join operation. |
| `unitSetup.total` | One unit per invocation. Includes all return paths. |
| `serverObjectsMapper.total` | Input composition entries; output returned objects, potentially recycled or expanded by composition callbacks. Includes original yielding delays. |
| `aoDefend.rearmBatch`, `aoDefend.setVehicleAmmo` | Batch input tracked entries; output non-null targets rearmed. Per-target 1/1; batch includes original sleeps. |
| `eventEntityKilled.*` | Handler input/output 1 killed entity. Explosion, wreck conversion, and attachment destruction have separate timings; output -1 where no result count is verified. Deferred workers are timed separately from the handler. |
| `customInventory.*` | One cargo container per operation, not item quantity. Total completion metadata counts cargo mutation commands; per-command summaries show how many clear/add operations were issued. |
| `aoGetTerrainData.*` | Total output eligible houses; completion metadata: nearby simple objects and building-position count. Separate house-search/filter and whole-world simple-object census timings. The latter uses the existing scan result. |
| `findRandomPos.*` | Object counts 0/0 (these are position searches). Total completion metadata: loop iterations, timeout reached. `selectBestPlaces` completion metadata: returned candidate count. Other placement/terrain queries are covered by the total span, not separately. |
| `curatorSync.*` | Census output objects found; addEditable input/output target entries per batch; total output filtered additional-object list. Counts can overlap between batches. |

In summaries, `inputSamples`/`outputSamples` count samples with known counts. A value of -1 is unknown/not applicable and is excluded from sums; 0 is a known zero. Object counts are observations of each operation, not necessarily unique objects or net population changes. Metadata is present on SLOW records, not per-call fast records.

## Configuration and disabling

Change defaults in `code/config/serverPerformance.sqf`, or run on the **server** debug console:

```sqf
missionNamespace setVariable ['QS_perf_enabled',FALSE];
```

Use TRUE to resume. This disables new recording and output (except the startup INIT line), while leaving tiny no-op checks and the idle summary worker in place. Thresholds can likewise be changed locally without a broadcast:

```sqf
missionNamespace setVariable ['QS_perf_slowMs',500];
missionNamespace setVariable ['QS_perf_frameGapMs',2000];
missionNamespace setVariable ['QS_perf_summarySeconds',60];
```

There is no new remote-execution allowlist entry. Keep existing UAV/projectile settings unchanged during this capture so comparisons remain useful.

## Validation and first capture

Offline structural checks: `node tests/validate-server-performance.cjs` from this mission directory. These are **not** an Arma compiler/runtime test.

On a test server, verify INIT, a SUMMARY after an out-of-bounds scan, and no new SQF errors. Exercise Normal AO creation, a Defend wave, rearming, Supply Depot cargo initialization, and end-of-AO cleanup; then disable/re-enable logging to verify the switch. Do not deliberately block a production server to test FRAME_GAP.

For the next real freeze, retain the complete RPT, the approximate observed freeze time, and the mission phase. Compare FRAME_GAP with same-frame SLOW samples and the adjacent SUMMARY windows. Long scheduled totals without a corresponding gap primarily indicate script latency, not a proven simulation block.

Reference: [Bohemia's scheduler documentation](https://community.bohemia.net/wiki/Scheduler) explains the scheduled/unscheduled distinction; [EachFrame documentation](https://community.bohemia.net/wiki/Arma_3:_Mission_Event_Handlers#EachFrame) describes the independent frame callback.
