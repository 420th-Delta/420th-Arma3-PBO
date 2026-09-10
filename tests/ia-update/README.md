# Native review regression cells

These tests exercise the community update against the installed Windows Arma 3 engine. They require the sibling `420th-Arma3-Server-Lab` checkout, its existing runtime seed, Python 3.12+, Arma 3 and an available Steam session for graphical clients. They are local development tools, not a portable CI replacement.

Run from the mission repository, one cell at a time:

```powershell
python tests/ia-update/run.py support --players 1 --timeout 300
python tests/ia-update/run.py damage --players 0 --timeout 180
python tests/ia-update/run.py ai-spawn --players 1 --timeout 240
python tests/ia-update/run.py radio-cleanup --players 1 --timeout 240
python tests/ia-update/run.py hq-delete --players 1 --timeout 240
python tests/ia-update/run.py hq-delete --players 2 --client-start-gap 75 --timeout 300
python tests/ia-update/run.py integration --players 1 --headless 0 --observe 120 --timeout 420
python tests/ia-update/run.py integration --cycle --players 1 --headless 0 --timeout 1200
```

Integration also accepts one or two headless clients. `--lab`, `--arma` and `--port` select explicit local paths/ports. Graphical clients run hidden and may require the existing sandbox escalation to access Steam. Never change global Git trust to run these tests; the baseline extractor scopes its read-only trust setting to the exact selected checkout.

The stock Windows build can fail its Scout display expression before mission assertions run. Preserve that failed result. For a separate altered-content control, append `--mfd-control reviewed-scout-v1` to an integration command. The adapter validates the lab's fixed source/build/tool/Tank asset pins, copies its one-file addon into the private fixture, declares its dependency there and loads it in every owned role. Native assertions verify the activated patch, effective typed display conditions, inheritance, source addons and engine build. This changes only the Scout READY TO/FIRE display condition in that test; it is not a stock-content pass, game repair or deployment recommendation. The default is `off`, and strict error rejection remains enabled. See the [stock investigation](../../docs/community-updates/ia-performance-gameplay-20260910/stock-mfd-investigation.md).

`integration --cycle` replaces the short observation period with the bounded native lifecycle driver: actual Primary initialization, production Mega Defense request, up to 90 seconds observing Defense, native cancellation, next Primary and deferred HQ cleanup. It requires at least one graphical player and `--timeout >=1000`; use 1200 seconds to allow boot/connection waits plus the driver's 660-second budget. It accepts `--headless 0`, `1` or `2`. `--observe` applies to ordinary integration only. Failed connection prerequisites prevent the cycle from starting. Cycle mode is recorded in `spec.json` and `result.json`; ordinary integration remains unchanged.

The cycle creates no test soldiers and does not alter the census, AI caps or clock. It checks the forced-Defense/cancellation lifecycle and support epochs; it does not establish natural objective victory, a full 30-minute Defense, high-population load or combat contact behavior. The first integration boot logged a real Primary INIT and roster even though `players_connected` failed; a completion marker cannot substitute for cycle readiness. Both integration modes now check actual human/HC objects and matching HC registry owners at connection and completion, and an active Primary pressure or Defense controller at completion. Ordinary heartbeats use `QS_classic_AI_active`; the earlier `QS_ao_active` telemetry read an undeclared variable. Per-owner AI-unit/group counts are diagnostics, so HC registration is not presented as proof of native offload. Cycle snapshots also record the actual Primary pressure and core lifecycle state.

HQ cleanup uses direct native evidence. Non-House objects must become null. A retained House reference is accepted only after capture proved its network identity, world/nearest membership and collision geometry, and cleanup produced a Deleted event, owner 0, null lookup of the original network ID, and fresh world/nearest/geometry absence. An owner value or cleanup log alone cannot pass. The original all-null failures remain recorded as TEST-19; the observed retained handles do not establish a physical object leak.

`hq-delete` isolates building placement and deletion with an already connected client. Its hashed mapper contrast preserves the original creation path and the precise land-House correction, with native geometry, transform, network and deletion observations. It also exercises the production building-position helper and separate direct/crate/simple controls. Two players with `--client-start-gap 75` add a genuine later client: assertions prove that publication preceded that client's admission and that the latest entity snapshot arrived through native JIP replay. Both clients verify callback/later orientation updates and forged-remote-update rejection. A fixture observer calls the exact production receiver and records authenticated feature payload; native vectors and geometry are checked directly. The first probes exposed SYS-09 client placement and remain failed evidence. See the [HQ investigation](../../docs/community-updates/ia-performance-gameplay-20260910/hq-native-investigation.md) for exact variant results.

Generated integration launchers and fallback cleanup include the same `HC1`/`HC2` mod links selected from `server_mods`. The launcher records each link for normal teardown; fallback cleanup checks its exact intended target before detaching it. PowerShell AST and role/mod-selection checks cover zero, one and two HCs without launching the engine (TEST-18).

Each invocation freezes production and fixture files with SHA-256 manifests in the lab's ignored `artifacts/ia-update/<token>-<suite>/`. The runner derives an isolated launcher from the lab's engine cell runner, copies executables and DLLs, uses junctions to installed game content, and records PID/start/executable identities. The lab execution lock and Windows process job enforce serial execution and bounded cleanup. The fallback cleanup validates exact artifact and junction identities. Installed game files and seed configuration are not edited.

Focused cells register actual production functions and explicitly documented fixture dependencies. Extracted blocks are hashed and preprocessed by the engine. Integration runs the full mission with private Apex seed copies, CLASSIC mode, automatic restart disabled and no database addon, plus the documented diagnostic initialization, role-entry automation and optional display control. The larger profile bound includes Arma's full-mission PBO cache; RPT evidence remains capped at 64 MiB. Twenty-five script errors abort a cell. Source, fixture and launched mission copies are checked after execution.

`result.json` reports completion, assertions, script errors, malformed/truncated records and cleanup/hash failures. `records.json`, source/fixture manifests, launcher identities, process samples and private RPTs retain the detailed evidence. `summarize.py <cell-directory>` prints a compact report without player identities. A successful completion marker alone is not a passing test.

After the final native cells finish, export the reviewable campaign index:

```powershell
python tests/ia-update/campaign.py
```

This writes `docs/community-updates/ia-performance-gameplay-20260910/native-campaign.json`; `--lab` and `--output` override the defaults. It includes failed attempts, marks configuration-only checks separately from native passes, and explicitly marks staging/launch attempts without results. The allowlisted fields retain suite/cycle, requested and observed client counts, assertion failure labels, error/integrity counts and SHA-256 hashes of the source manifest, fixture manifest and result. Raw logs, paths, Steam identities, assertion payloads and private error strings are excluded. Missing fields in older results stay null. For older integration cells without a headless count in `spec.json`, only the generated launcher's unique literal HC-loop count supplies the requested count. Exporting does not launch engines or alter the original evidence.

The dedicated damage probe records AI victims and callers; it does not prove player-facing Robocop UI behavior. Synthetic support placement uses a controlled native attachment helper and actual menu functions, not the full mission placement UI. Integration automates initial role entry by setting `skipLobby=1` and `joinUnassigned=0` in the private mission copy, as the lab's existing mission runner does; original mission settings and playable/HC slots are preserved in source. Multiple local clients share the existing Steam account, so they do not establish independent-UID permissions. Headless initialization, short local observation and isolated regression results do not establish live-server performance or sustained multiplayer acceptance. See the review's remediation report for the exact completed coverage and remaining checks.
