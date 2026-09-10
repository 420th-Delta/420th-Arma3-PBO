# Second-pass review adjudication

Disposition of every finding in the standalone `IA-PerformanceGameplayUpdate-review-20260910/REVIEW-PASS-2.md`. That report reviewed `4b466b352ef30cf9eb77faf4623b5fbd015a60b2` against upstream `a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7`. This document records the subsequent source verification, corrective working tree and native results for the frozen inputs identified below. Commit and handoff finalization remain separate from those test results. The original contribution remains attributed to JollyRogerEXP.

There are **36 R2 findings**: five AI, six Defense/rappel, four spawn, seven support, six systems and eight hygiene items. The original report abbreviates `R2-SUP-06/07`; both are adjudicated separately here. Its T-0 lint observations are also covered. Duplicate findings retain both identifiers without counting the same defect twice in a remediation total.

**Confirmed** means the stated behavior or documentation problem is supported. **Qualified** means part of the finding is supported but its mechanism, scope, severity or proposed remedy needs correction. **Rejected** means the proposed defect or remedy is contradicted by source, documented engine behavior or existing evidence. A confirmed policy or cost observation does not by itself require a gameplay change.

Unless a different directory is specified, SQF filenames below are under `Apex_framework.terrain/code/functions/`. Function names and code anchors identify the behavior; line numbers in the original review refer to its frozen revision and can move in the corrective tree. Each validation paragraph distinguishes the new focused results, earlier evidence and remaining coverage gaps. The final [test report](LOCAL_TEST_REPORT.md), [ledger](REMEDIATION_LEDGER.md) and [campaign index](native-campaign.json) have been refreshed with the second-pass cells.

Seathre has confirmed that the deployed engine meets the **Arma 3 2.22+** requirement. This resolves that version prerequisite; it does not establish deployment parity, available custom-channel capacity, an FPS gain or human acceptance of the changed gameplay.

## AI controller

### R2-AI-01 — Confirmed: cancellation between creation and registration

**Evidence.** The reviewed `fn_AI.sqf` WORK branches created VEHICLE hulls/crew, HELI hull/pilot, shared infantry and PARA chutes before registering them. STOP can terminate the scheduled worker between statements. The earlier atomic ROTARY helper and its successful native evidence do not cover every WORK branch.

**Action.** The corrective tree adds short `_fn_createRegisteredVehicle` and `_fn_createRegisteredUnit` transactions using `isNil`, and keeps vehicle-crew creation/registration together. `_fn_charge` now performs accounting only, avoiding a second registration/broadcast. STOP remains bounded and retains its established exemption checks. This closes the creation/ownership gap without leaving cancelled workers running indefinitely.

**Validation.** Source ordering and lexical checks were reviewed. Final `fc9bd9ec0020-ai-spawn` passed 23/23 assertions, including rotary creation/cancellation and cleanup ownership, using the committed normalized baseline. It exercises rotary/placement cases; native cancellation during the newly covered VEHICLE, HELI, shared-infantry and PARA WORK paths remains pending. Ordinary mission initialization in `d7a27107775c-integration` does not establish that each branch ran.

### R2-AI-02 — Qualified: low-population infantry waits for transport

**Evidence.** The under-20-player branch with sufficient reserve waits for Taru availability without advancing the infantry wave. The contributor already documents the low-population transport policy in `RELEASE_NOTES.md`. The cited 150-180-second values are stage budgets, not a total upper bound: approach, positioning, release, landing and departure have sequential waits.

**Decision.** Retain the intended transport preference. Do not silently convert it to immediate ground reinforcement or describe a single stage budget as a complete delivery deadline.

**Validation.** Source and intent documentation agree. Actual low-population transport pacing, blocked flights and total delivery latency remain native/gameplay acceptance work; no new timing result is claimed.

### R2-AI-03 — Qualified: rejected artillery admission still advertised a shot

**Evidence.** The bookkeeping defect is supported: `fn_AIHandleGroup.sqf` refilled ammunition and created smoke/fire-mission exclusion before checking ARTY_START admission. The report's claim that the branch is dead is incorrect. `QS_data_artyPit.sqf` supplies ARTILLERY configuration consumed by `fn_SMpriorityARTY.sqf`; Primary context can also be determined geographically in `fn_AI.sqf`.

**Action.** Build the firing arguments once, admit the Primary request first, and perform refill/smoke/exclusion publication only on success. An outer unscheduled block keeps accepted bookkeeping ahead of the newly spawned firing worker. Non-Primary fire retains its existing provider path.

**Validation.** Reachability and ordering were checked by source. Native accepted/rejected Primary artillery cases and the non-Primary regression are pending; the earlier AI suite did not execute this branch.

### R2-AI-04 — Confirmed: unused helicopter landing-check argument

**Evidence.** `_fn_position` contains a helicopter landing-zone branch, but current callers supply FALSE for that argument. This is dormant helper behavior, not evidence that a currently used validation path fails.

**Decision.** Retain it. Enabling that branch would impose a new landing predicate on moving transport behavior and would require a separately justified gameplay change. Removing it offers no demonstrated correctness benefit in this pass.

**Validation.** Callsite inspection establishes the current non-use. No new native test is required for a retained dormant branch; future callers must validate its contract before using TRUE.

### R2-AI-05 — Qualified: public state traffic during activation

**Evidence.** `_fn_activate` and INIT publish multiple per-member variables. The report's two activations per 12 seconds or four per three seconds describe a mobilization path; they do not cap every initialization or activation broadcast.

**Decision.** Retain the state transitions and measure their network/scheduler cost under representative populations. Do not replace fresh state publication or assert a global traffic bound based on one caller's cadence.

**Validation.** Publication sites were inspected. No comparative network/FPS result exists for this finding; representative load measurement remains pending acceptance work.

## Defense, insertion and rappel

### R2-DEF-01 — Confirmed: client-controlled fast-rope RPC surface

**Evidence.** The reviewed generic case 75 whitelist in `fn_remoteExec.sqf` allowed client-origin requests to server-side rappel functions without function-specific sender/object authorization. A blanket ban on every helper request would also break legitimate player helper/animation traffic and trusted HC-owned insertion.

**Action.** The corrective implementation binds ordinary client requests to the actual sender, permitted same-group AI and the existing action predicate, then rechecks admission in the server endpoint. The server issues the rappel serial and stores a per-unit session in `serverNamespace`. Helper relays are bound to the session, object class, owner, unit, serial and helicopter, with one animation relay. Ordinary clients cannot request bulk AI transport control. Case 65 collision synchronization becomes server-originated; clients reject direct non-server delivery of cases 65/75. The ordinary-client gate applies to remote owner IDs above two. HC-origin calls report remoteExecutedOwner zero and retain their pre-existing trusted-peer path; that command cannot authenticate a particular HC. The stock Taru path is server-local.

**Limit.** The first helper of each allowed class can still be selected by the owning client, but it must satisfy the bounded owner/session association. This is not an unrestricted arbitrary-object hide endpoint. HC trust is a deployment assumption, not a new sender-bound authorization guarantee; no identity supplied inside a request is treated as proof that it came from a registered HC. Bohemia documents the zero value for HC-origin execution in [remoteExecutedOwner](https://community.bistudio.com/wiki/remoteExecutedOwner).

**Validation.** `921c1eee1e0c-rappel-security` passed 41/41 assertions using the actual player request and production dispatcher/worker bodies. It verifies server-issued serial/session binding, actual dismount, helper synchronization, rejection of forged published state and a second helper, rejection of an unsafe direct request, and exactly one animation relay despite a duplicate request. Captured helper objects and rope were deleted, the client record and server session cleared, and the anchor released. The fixture counts animation entries through a delegate that preserves the actual production body; its exact definition substitution is asserted. Group-AI/trusted-HC success, cross-owner/reconnect cases and broader replay coverage remain pending. The existing HC qualification applies to the trusted HC-to-server path, not permission for direct HC delivery to client-only relays.

### R2-DEF-02 — Confirmed: stopping admission could abort existing descents

**Evidence.** The bulk worker cleared `AR_Is_Rappelling` on units still associated with the aircraft after a budget/activity exit. TARU_DELIVER also stopped the bulk worker at its release deadline. A healthy unit already descending could lose its ropes rather than finish landing.

**Action.** Stop new rope admissions, preserve existing descents on ordinary exits, and hold a still-owned operable transport for up to 30 seconds while captured serial-matched descents finish. Fatal conditions or expiry retain a bounded forced clear and up to two seconds for helper cleanup. Ownership/player/Zeus takeover exits prevent continued control of the transport. The per-unit expiry remains a backstop; the change does not promise unlimited hovering.

**Validation.** Source guards and worker ownership were inspected. The 41-check rappel cell exercises a player descent through the actual worker and verifies descent-state completion, damage restoration and removal of previously captured helpers/rope. Its completion assertion checks the cleared rappel flag, not an alive-and-grounded landing condition. It does not invoke the bulk worker or TARU_DELIVER interruption path. Interrupted releases, successful bulk landing, stuck descent, fatal transport/pilot conditions and takeover behavior therefore remain pending.

### R2-DEF-03 — Confirmed: old workers skipped removal of their own handlers

**Evidence.** When serial N+1 replaced serial N, the serial guard could prevent worker N from removing its own Deleted/Killed handlers. Animation cleanup had the same ordering concern. These registrations belong to the worker that received their IDs, even when shared unit state belongs to a newer serial.

**Action.** Remove the worker-owned Deleted, Killed and AnimChanged handlers before testing whether the worker still owns shared serial state. Keep serial guards around shared helper/state mutation so old work cannot clear a newer descent.

**Validation.** Cleanup ordering was checked by source. The 41-check rappel cell proves ordinary session/anchor/helper/rope cleanup and one animation relay in the presence of a duplicate request. It does not replace serial N with N+1 or count worker event handlers; native overlapping-serial and repeated-worker handler checks remain pending.

### R2-DEF-04 — Confirmed: revive policies need explicit disclosure

**Evidence.** `description.ext` changes `ReviveBleedOutDelay` from 600 to 240 seconds. `fn_incapacitated.sqf` skips the pilot/fighter-pilot forced-death branch for `forward_observer`, `jtac`, `jtac_WL`, `mortar_gunner` and the existing staff exception, or when the captured Kavala revive flag is active. Other death conditions remain. Transport and medevac rules can extend the normal timer.

**Decision.** Retain the contribution's gameplay policies and state them explicitly in the current review overview and PR body. They must not be represented as consequences of the damage-attribution repair. A history rewrite is unnecessary to achieve disclosure; the earlier recommendation to separate the timer remains a reviewability alternative.

**Validation.** Configuration and branch conditions were verified, and the current overview and prepared PR body now carry the disclosure. Actual unattended expiry, transport/medevac extensions, role changes and Kavala revive acceptance remain separate from the native damage matrix.

### R2-DEF-05 — Qualified: Mega Defense bypasses optional overtime

**Evidence.** The deadline branch in `fn_aoDefend.sqf` succeeds when `_megaDefense` is true even if `QS_defend_blockTimeout` is set. Ordinary Defense adds 600-1200 seconds only when that flag is enabled. Production source initializes/resets it FALSE and contains no automatic TRUE setter. The report's implication that ordinary Defense automatically extends based on HQ occupancy is unsupported. Early HQ capture/failure and administrator termination still apply.

**Decision.** Retain the finite Mega Defense timer and disclose the optional-overtime exception accurately. Do not describe the mode as immune to early failure or invent a new HQ-occupancy gate.

**Validation.** All flag references and the timer branch were inspected, and the current overview and prepared PR body now carry the disclosure. Full-duration native/gameplay acceptance remains pending; a forced-cancellation cycle does not prove a 30-minute victory.

### R2-DEF-06 — Qualified: pending request survives a missed Primary handoff

**Evidence.** A START accepted during Primary can remain pending if the core reaches natural completion before consuming that request. A later Defense can consume the pending request; status can temporarily report FORCE_REQUESTED while the core is idle. The report records this as consistent with the request's intent, not a demonstrated duplicate controller.

**Decision.** Retain pending-request semantics rather than silently discarding an accepted request on that transition. Do not infer that an accepted START has already entered Defense. Existing activity ownership and deinitialization gates remain authoritative.

**Validation.** State transitions were inspected. Deliberately racing START with natural objective completion remains an acceptance case; the historical forced/cancelled cycle did not establish this exact timing.

## Spawn placement

### R2-SPAWN-01 — Qualified: compact placement remains opt-in compatible

**Evidence.** Seven relevant eight-argument calls retain the compact legacy path: `fn_aoEnemyReinforce.sqf`, `fn_scSpawnGroup.sqf` and `fn_smEnemyEast.sqf`. The report's count of nine overstates the outdoor ground cases: one listed scSpawnGroup call supplies cargo and another uses an off-map position. A ninth argument explicitly opts into the expanded validation contract.

**Decision.** Preserve mandatory/legacy call behavior. Correct the current interpretation of contributor `RELEASE_NOTES.md` around lines 205/209 and `TECHNICAL_NOTES.md` around 349/351: expanded placement is opt-in, server-authoritative, and Primary infantry retain their explicit player-exclusion contract. Preserve supplied historical documents or clearly label any errata instead of silently changing their provenance.

**Validation.** Callsite inspection establishes the distinction. Final `fc9bd9ec0020-ai-spawn` passes the legacy-objective regression and checked-in historical negative control within its 23/23 result. The refreshed audit records all 72 calls, including seven eight-argument calls and two cargo/off-map cases; the regression does not exercise every caller.

### R2-SPAWN-02 — Qualified: propagate the unscheduled search cutoff

**Evidence.** The innermost loop's unscheduled timeout did not immediately stop every enclosing loop. The outer pattern loop already had an expiry exit, so the claim that the function usually returns no positions is not established. Scheduled production callers can yield; the four-millisecond condition is a soft candidate-loop cutoff, not a hard engine frame guarantee.

**Action.** A `_timedOut` flag propagates across the nested pattern/row/column loops while retaining already selected positions. Scheduled callers preserve their yielding behavior and validation contract.

**Validation.** Loop exits were checked statically. The new 23-check AI/spawn cell passes scheduled terrain search, placement boundaries, rejection and reservation cases on the changed source. It does not explicitly force the unscheduled timeout or assert retention of a partial selection at that cutoff; those targeted cases remain pending. No performance guarantee follows from delimiter checks or the existing placement assertions.

### R2-SPAWN-03 — Confirmed: visibility is a sampled predicate

**Evidence.** The atomic claim/commit path rechecks occupancy and player radius but does not repeat every arbitrary caller validator or concealment query. Those checks can become stale between candidate evaluation and commit. Spatial rechecks do not prove fresh line-of-sight concealment.

**Decision.** Retain the short atomic occupancy contract already explained in `ai-spawn-remediation.md`. Re-running arbitrary callbacks inside it would enlarge the unscheduled critical section and may violate callback assumptions. The function is not a transaction spanning arbitrary delayed callers or unrelated mod spawning.

**Validation.** Source contract and prior claim concurrency/expiry coverage were reviewed. Moving-player/visibility behavior remains gameplay acceptance; no stronger concealment guarantee is claimed.

### R2-SPAWN-04 — Qualified: additional validation has unmeasured cost

**Evidence.** City, AO and side-task paths can perform extra final-position visibility/blacklist checks. The specific two-to-three-times multiplier is unsupported: conditions short-circuit, a first pattern has fewer candidates, and pre-searches differ across callers. Worst-case candidate counts alone do not measure typical scheduler cost.

**Decision.** Retain the correctness checks and avoid quantitative performance claims. Measure elapsed search time, rejected candidates and scheduler delay with representative density before choosing an optimization.

**Validation.** Callers and loop bounds were inspected. No matched-load timing/FPS comparison has been recorded for this finding.

## Player support

### R2-SUP-01 — Qualified: failed free placement consumed request cooldown

**Evidence.** The reviewed free MORTAR request charged its ten-minute cooldown at admission; failed transfer, false ACK, reset or timeout did not undo it. This matched the documented request-time policy but was undesirable when nothing was granted. Moving the charge without controlling rapid failed attempts would permit repeated object construction.

**Action.** Charge the free-MORTAR cooldown at successful settlement. Preserve it when an already armed section is reset. Add a server-owned two-second attempt interval shared by construction requests and retained through RESET/empty-row cleanup. The long gameplay cooldown and short attempt throttle serve different purposes.

**Validation.** `498cfe21ffd1-support` passed 219/219 assertions, including pending/no-cooldown, reset-before-arm, successful-arm charging, preservation of the armed cooldown through RESET, and reset-resistant attempt spacing. Remaining cooldown is computed on the server before being returned to the client fixture. Earlier `afd70f250ef9-support` passed 220/220 with the previous fixture; `4756821c0e46-support` completed 222 checks with one failed reset-resistant throttle assertion. Preserve that failure and the subsequent fixture revisions as history; the original 207-check result describes the earlier production policy.

### R2-SUP-02 — Qualified: locality observation does not prove persistent invulnerability

**Evidence.** Creation disables damage on the server and ARM enables it where the turret is local. The report assumes ARM necessarily runs on the player and that the old server setting persists on return. Historical `b11ac9b1b0a4-support` instead observed hull owner 4 and turret owner 2. Bohemia documents that `allowDamage` must run at object locality and its effect does not persist through a locality change. `isDamageAllowed` on a non-local object is not a reliable proof of its owner's damage state. [allowDamage](https://community.bistudio.com/wiki/allowDamage?useskin=vector), [isDamageAllowed](https://community.bistudio.com/wiki/isDamageAllowed)

**Decision.** Do not add a speculative server-side toggle or declare the mortar permanently invulnerable. Preserve the current behavior while obtaining direct owner/locality and physical-damage evidence.

**Validation.** A targeted placement/arming/locality-return probe with local `isDamageAllowed` and actual projectile damage remains pending. Scripted `setDamage` alone would not verify `allowDamage` protection.

### R2-SUP-03 — Qualified: Forward Observer selector and initial queue policy

**Evidence.** The added role used initial queue capacity 4 and an unconditional side selector, unlike other WEST roles. The report understates the selector as UI-only: the role-selection flow can lead to actual WEST assignment. The artillery service's separate authorization is still valuable. Conversely, zero initial queue slots do not disable the later dynamic queue logic in `fn_roles.sqf` around lines 797-802.

**Action.** Set the initial queue field to zero and use the standard WEST/allowed-side-switch predicate. Retain one Forward Observer role slot and the server's role-holder checks.

**Validation.** Role field consumers and the standard predicate were verified by source. Native role selection, allowed/denied side switching and dynamic queue behavior are pending; the focused support fixture stubs the full role system.

### R2-SUP-04 — Confirmed: fresh authorization performs repeated scans

**Evidence.** Active support readiness repeatedly resolves the role holder and remote-control state, including `allUnits` scans, at the job's polling cadence. Cost scales with active jobs and unit counts. The report's illustrative operation estimate is not a measurement.

**Decision.** Retain fresh authorization. A shared cache might reduce scans but would need explicit invalidation for control, role, life-state and locality changes; no measured regression currently justifies that complexity.

**Validation.** Call frequency and dependencies were inspected. Representative scheduler profiling remains pending; no optimization or FPS benefit is claimed.

### R2-SUP-05 — Confirmed: focused fixtures stub integration dependencies

**Evidence.** The support fixture supplies controlled implementations for `QS_fnc_inZone`, `QS_fnc_roles`, `QS_fnc_eventAttach`, `QS_data_listItems` and placement interaction. This means its passes do not execute the full bare-position safe-zone path, GET_ROLE_COUNT implementation or interactive placement UI. Source inspection supports the current argument contracts, but does not turn those stubs into native coverage.

**Decision.** Preserve the focused fixtures and disclose their scope. Complete dependency and human UI checks belong to integration/acceptance rather than relabeling synthetic results.

**Validation.** Source contracts reviewed; full dependency/placement/independent-account validation remains pending. Existing fixture assertions remain valid within their stated scope.

### R2-SUP-06 — Confirmed: incapacitated caller may reset their own section

**Evidence.** RESET accepts an incapacitated requester but resolves only that authenticated caller's server row. It does not grant equipment or reset another player's section.

**Decision.** Retain this intentional cleanup permission. It lets the owner release equipment while incapacitated without relaxing admission or resource authorization. The successful-placement cooldown and new attempt throttle remain server-owned.

**Validation.** Authorization scope was checked by source. Do not claim a new incapacitated-RESET native test unless its recorded fixture actually exercises that state.

### R2-SUP-07 — Qualified: boarding handler is not the only ejection path

**Evidence.** One server GetIn handler initiates an ejection per boarding event. TICK and retirement can also issue EJECT, so the report's wording must not imply a global one-RPC maximum for the object's entire lifecycle.

**Decision.** Retain the idempotent owner-local ejection behavior and revive-aware extraction. Duplicate legitimate cleanup paths do not justify removing one without a demonstrated defect.

**Validation.** Event registration and other EJECT callers inspected. No new duplicate-ejection or incapacitated boarding result is claimed.

## Radio, cleanup and entity state

### R2-SYS-01 — Confirmed: corrupted mapping comment

This is the same comment-only issue as R2-HYG-01. Four separators in `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf` were corrupted after the clean incoming/merged artifact. The corrective tree uses ASCII separators. Byte inspection and updated merge-note wording were checked; no runtime behavior changes and no native test is required for the comment itself.

### R2-SYS-02 — Qualified: old-body retirement had a short finite retry window

**Evidence.** `fn_clientRadio.sqf` stopped its observer after three seconds; the one-second add retry in `fn_clientEventRespawn.sqf` omits the captured old body. A living replacement that remains absent until after the observer ends can leave old membership. The fixture's five-second observation waits do not establish that actual replication normally takes five seconds.

**Action.** Extend the existing single observer to ten seconds, retaining null/dead replacement, revoked-subscription and current-live-body guards. Do not add unbounded workers or claim that any finite timeout covers unlimited network delay.

**Validation.** `d151a4aeab19-radio-cleanup` passed 73/73 assertions. The delayed-membership case atomically invokes the actual add path and withdraws replacement membership, asserts setup, deliberately holds it beyond the old three-second bound, then verifies replacement presence and old-body retirement. It demonstrates the extended retry rather than measuring ordinary replication latency. Real death/respawn and delivered voice remain acceptance checks.

### R2-SYS-03 — Qualified: fallback voice is an intentional new policy

**Evidence.** Upstream native Side permitted staff voice only; allocation failure now enables team-local text and voice for everyone. This is explicitly the fallback described in `radio-cleanup-remediation.md` and matches the new custom Side's general voice permission. Seathre's engine confirmation resolves the old-version concern; slot exhaustion remains possible.

**Decision.** Retain the all-player native Side fallback, explicitly disclose its team-local scope, and update stale version-prerequisite wording. A staff-only fallback would be a separate policy choice, not a necessary compatibility fix.

**Validation.** Historical 2.22 native zero-allocation permissions were exercised, and the new 73-check radio/cleanup cell passes its allocation-failure and permission cases. Actual delivered voice and deployment channel capacity remain acceptance checks.

### R2-SYS-04 — Rejected: `jip=0` does not block the server publisher

**Evidence.** `security.hpp` restricts client-origin JIP requests. `fn_serverPublishEntityState.sqf` runs only on the server; `fn_clientApplyEntityState.sqf` rejects remote callers other than server owner 2. Bohemia explicitly exempts the server from CfgRemoteExec restrictions. Historical `efdcf250f5be-hq-delete` verified native JIP replay on a genuinely late client with this same `jip=0` declaration. [CfgRemoteExec](https://community.bistudio.com/wiki/CfgRemoteExec?useskin=darkvector)

**Decision.** Keep `jip=0` in production and the fixture. Setting it to one would broaden client-origin permission without helping the authenticated server publisher. Correct the review explanation rather than weakening configuration.

**Validation.** Official semantics, source guards and existing late-JIP/forged-client assertions agree. No new source change or native test is needed for this rejected remedy.

### R2-SYS-05 — Confirmed: House snapshots add per-live-object JIP cost

**Evidence.** The mapper publishes each eligible non-simple land House after callback changes. The entity object is the JIP key, so later publications replace its prior snapshot and deletion removes that queued entry. Cost scales with eligible live objects; there is no fixed numerical global cap. [remoteExec](https://community.bistudio.com/wiki/remoteExec)

**Decision.** Retain the correctness repair. Aggregating snapshots would add deletion and ordering complexity to an already verified current/late-client protocol. Measure join payload and delay before changing it.

**Validation.** Existing mapper/state native tests verify replacement and late replay. No representative JIP bandwidth or large-composition latency benchmark is claimed.

### R2-SYS-06 — Qualified: first cargo observation renews the deadline

**Evidence.** Holder enqueue entries omit cargo history. The first tick compares the default empty history with the five-part cargo snapshot and grants thirty seconds from observation. Normal core sleeps three seconds, but work duration, queue batching and fallback discovery can add delay. The claimed 30-36-second effective lifetime is not a hard upper bound.

**Decision.** Retain conservative inventory-based expiry. Recording a snapshot at creation would change that policy and add work to the creation path. Describe thirty seconds after the observed state/change, followed by an eligible cleanup pass, rather than exact creation-time expiry.

**Validation.** The new 73-check radio/cleanup cell repeats the actual helper checks for changed cargo survival, unchanged expiry and attachment protection. These do not prove a scheduler-independent wall-clock maximum; the lifetime remains qualified as above.

## Test, documentation and commit hygiene

### R2-HYG-01 — Confirmed: encoding defect and inaccurate merge explanation

**Evidence.** Both preserved incoming and merged radio files contain clean UTF-8 en dashes. Commit `aab162f` introduced the corrupted separators, retained at the reviewed HEAD. Both `merge-systems.md` copies incorrectly blamed the artifact and claimed ASCII was committed.

**Action.** Correct the source comment in a follow-up and amend the explanation without rewriting published contributor history. The in-repository explanation is corrected; standalone synchronization remains part of handoff finalization.

**Validation.** Byte comparisons and comment-only diff inspection passed. The runtime mapping arithmetic is unchanged. See duplicate R2-SYS-01.

### R2-HYG-02 — Qualified: the runner depended on an available historical object

**Evidence.** `run.py` invoked `ai_spawn_extract.py --revision dec9787` unconditionally. Fresh shallow or rewritten-history checkouts without that object fail; rebasing does not immediately delete an object still present locally. Existing full-history execution was valid.

**Action.** Check in the exact historical spawnGroup file and documented runnable STOP selector/exemption adapters with source revision and SHA-256 provenance. The ordinary runner uses no historical Git lookup for these negative controls and verifies the frozen staged baseline. Deliberate historical extraction remains optional tooling. The adapters are identified as equivalent predicates, not complete executions of the original STOP lifecycle.

**Validation.** Baseline file/source hashes matched; the exemption predicate matched the historical body after comment/whitespace normalization. Review caught and corrected a missing `_fn_exempt` binding and a hash check against mutable rather than staged files. Python parsing and SQF balance pass. `fa23572d16ae-ai-spawn` passed before the historical file's trailing blank-line tabs were normalized for Git; final `fc9bd9ec0020-ai-spawn` passed 23/23 with the committed manifest, including both negative controls. The manifest retains the original source hash and the LF/trailing-whitespace-normalized fixture hash. This is native execution of the portable baseline path, not a separate shallow-clone end-to-end experiment.

### R2-HYG-03 — Confirmed: campaign scope wording is broader than its index

**Evidence.** At the reviewed HEAD, `campaign.py` recognized eight named suite types. The corrective version recognizes nine after adding `rappel-security`. The eight-check `acc4e4306e5e-mfd-stage-check` uses `stage-check.json`, not the normal result schema. `134b087007e8` belongs to an earlier owner campaign under a different artifact root/schema. Both are cited in `stock-mfd-investigation.md` but absent from the previously exported 40-cell index.

**Action.** Qualify the index/report/ledger as covering the indexed suite types and explicitly identify auxiliary evidence outside it. Extending the filename regex alone would not correctly parse either auxiliary record. Preserve the original evidence and avoid counting staging checks as native passes.

**Validation.** Artifact schemas and the original 40 indexed entries were inspected. The new suite is recognized by the exporter, and the refreshed index preserves 58 attempts, including failed and incomplete cells. Neither auxiliary evidence record is relabeled as a normal suite result.

### R2-HYG-04 — Rejected: diagnostics are not unused everywhere

**Evidence.** Five mortar diagnostic blocks default FALSE in production. `tests/ia-update/support-dependencies.sqf` explicitly enables them, and `support-remediation.md` explains their purpose. The UID-related output is a presence Boolean, not the UID itself. No material production overhead is demonstrated while disabled.

**Decision.** Retain these opt-in diagnostics. Removing them would discard useful locality/admission evidence without repairing a known defect. Correct the report's never-enabled premise.

**Validation.** All gates, enabling fixture and payload fields were reviewed. No new native result is needed to establish that the fixture uses them.

### R2-HYG-05 — Confirmed: nine follow-up commits have no bodies

**Evidence.** `git log dec9787..4b466b3` contains nine subject-only commits. The ledger supplies the detailed rationale and evidence.

**Decision.** Preserve published history. New follow-up commit bodies should state the applicable R2 identifiers, rationale and validation. Rewriting old SHAs merely to add prose would create patch/provenance churn without changing behavior.

**Validation.** Earlier commit contents were inspected. New commits use explanatory bodies and the handoff inventory is refreshed after their hashes exist; no runtime test applies.

### R2-HYG-06 — Confirmed: installation-specific defaults hinder reproduction

**Evidence.** The runner and configuration validator had overridable Steam-library defaults but insufficient setup guidance. These were generic paths, not private credentials.

**Action.** Require explicit `--arma`/`ARMA3_ROOT` and `--tool`/`ARMA3_CFGCONVERT`, check executable availability before staging, and document setup. This keeps local development tools explicit rather than pretending to be a portable CI environment.

**Validation.** Python AST checks pass. Missing configuration and invalid paths were exercised in child processes: all four cases exit with code 2 and actionable messages before engine/staging work. The new native cells below execute the configured runner successfully. `8c3d17da3d64-config` passes conversion of `description.ext`, `mission.sqm` and `code/config/security.hpp` through the explicitly configured tool. This establishes execution on the available Windows installation, not OS/deployment portability.

### R2-HYG-07 — Qualified: image is valid and follows an existing support format

**Evidence.** The Forward Observer JPEG is valid, 365 by 399 pixels and 50,523 bytes. The upstream mortar-gunner image has exactly the same dimensions; machine-gunner and sniper images are also comparatively wide. `fn_roles.sqf` deliberately uses the existing support-role image convention. A uniform portrait requirement is not supported.

**Decision.** Retain the asset. Do not resize or replace it without a demonstrated role-card rendering problem.

**Validation.** The JPEG and comparison image were opened and dimensions verified against upstream. Actual role-card layout at representative UI scales remains a visual acceptance check.

### R2-HYG-08 — Confirmed: PR summary omitted concrete gameplay policies

**Evidence.** The standalone PR body named revive/Defense work broadly, while the contributor notes carried the timer and exemption details. It did not explicitly state the four-minute normal bleed-out window, support-role/Kavala pilot-branch exemptions, or Mega Defense's optional-overtime bypass.

**Action.** Add these disclosures to the PR body and current overview, with the qualifications in R2-DEF-04 and R2-DEF-05. Retain early failure/cancellation and transport/medevac behavior in that explanation. Do not present attribution fixes as authorization for unrelated balance changes.

**Validation.** Source-to-description comparison completed. The current overview and prepared PR body contain the explicit policies; gameplay acceptance remains separate.

## T-0 static-lint observations

| Observation from the reviewed HEAD | Verdict and evidence | Decision and validation status |
| --- | --- | --- |
| 26 baselined violations disappeared | **Qualified.** Removed lint findings are not automatically 26 separately repaired gameplay defects. | The final source was rerun against the exact upstream base with extDB coverage: 26 identities remain removed. The same comparison reports 40 new identities: the one manual entry point, 38 converted rappel-body bindings and one string-form `private` false positive. See [static validation](second-pass-static-validation.json). |
| New orphan: `code/scripts/IA_MegaDefense.sqf` | **Rejected as a defect.** The file is an intentional manual `execVM` entry point documented by the contributor and exercised through the integration driver. It need not have a CfgFunctions registration or automatic caller. | Retain manual activation. Do not introduce automatic Mega Defense solely to silence an orphan warning. Current-source `b51da40818f8-integration` passes the forced Mega Defense/cancellation cycle; natural activation and full-duration completion remain separate. |
| 38 undeclared-local findings in converted rappel bodies | **Qualified.** The first pass exposed existing assignments by converting formerly opaque strings to Code. The relevant worker bodies run in spawned script scopes; the count alone does not prove a new global variable leak. New edits must still preserve worker-local ownership and avoid relying on accidental outer bindings. | Do not perform a broad mechanical privatization from the count alone. Preserve the historical lint finding, inspect any concrete binding defect, and rerun syntax/lint checks on final code. The 41-check rappel cell verifies the tested player RPC/session and cleanup path; overlapping-serial handler checks remain pending. |
| One undeclared-local finding for `private '_publication'` | **Rejected as a defect.** `fn_serverPublishEntityState.sqf` declares `_publication` using SQF's string-form `private`; the variable is then used outside the inner unscheduled block as intended. | Retain the valid declaration and record the linter limitation. Existing native publication/JIP evidence remains applicable to the unchanged function. Do not invent a source repair to satisfy the false positive. |

## Validation and finalization boundary

The prior completed evidence remains preserved: support 207 assertions, damage 98, AI/spawn 23, radio/cleanup 70 and mapper/state 282, plus the recorded controlled integration cells. These remain results for their frozen inputs; the following cells supply the new second-pass evidence.

| Final cell for this pass | Result | Coverage and limit |
| --- | --- | --- |
| `498cfe21ffd1-support` | 219/219 | Focused support protocol, revised cooldown and attempt throttle; controlled dependency/UI substitutes remain. |
| `d151a4aeab19-radio-cleanup` | 73/73 | Native channel and cleanup helpers, including replacement membership deliberately withheld beyond three seconds; no delivered-voice claim. |
| `fc9bd9ec0020-ai-spawn` | 23/23 | Rotary/placement regressions and committed normalized negative controls; not every newly corrected WORK/ARTY branch or the forced unscheduled cutoff. |
| `921c1eee1e0c-rappel-security` | 41/41 | Player request/session authorization, duplicate animation relay, and actual captured helper/rope/session/anchor cleanup; not bulk insertion interruption or overlapping worker serials. |
| `8c3d17da3d64-config` | Three conversions passed | `description.ext`, `mission.sqm` and `code/config/security.hpp`; configuration conversion is separate from native assertions. |
| `d7a27107775c-integration` | 22/22 | Ordinary full-mission startup/player admission and continued controller operation with `reviewed-scout-v1`; `cycle=false`, so no new forced Defense cycle or natural victory result. |
| `36e972349cea-integration` | 28/28 | Ordinary full-mission startup with one graphical player and one real HC object/registry match; continued controller operation and all strict gates pass. |
| `b51da40818f8-integration` | 45/45 | One player/two HCs complete Primary, forced Mega Defense, cancellation and next Primary with deferred HQ retirement; no natural victory, uninterrupted 30-minute result or interrupted Taru descent claim. |

Every native cell in this table completed with zero failed assertions, script errors, malformed records, harness cleanup errors, and source/fixture/runtime integrity differences. Configuration conversion returned zero for all three inputs. Those gates describe each frozen execution; they do not establish coverage of unexecuted branches or deployment parity.

The test harness also required corrections. RPT timestamps can have leading whitespace; the record parser now accepts that prefix instead of losing valid assertion records. `diag_tickTime` belongs to each process, so the support fixture now receives remaining cooldown computed on the server rather than comparing a server deadline with the client's clock. The rappel fixture first captures and asserts the existence of actual helpers and rope before asserting their deletion, and checks the bound session and anchor before their removal. Its animation delegate counts the initial, duplicate and final entries while preserving the actual production body. These changes prevent absent objects or an unchanged latch from serving as sufficient cleanup/duplicate-relay evidence. The portable-baseline binding/staged-hash corrections are recorded under R2-HYG-02; the deliberately delayed radio case asserts its setup before exercising the extended retry.

Preserve the earlier failed iterations, including `4756821c0e46-support` and the rappel cells `c647f1280078`, `3931b983794f`, `7c86e8b9ff96`, `6f2c75abd98a` and `5bd7ddec8231`, alongside the later passing runs. A zero-check cell is not a pass. Intermediate `afd70f250ef9-support` (220/220) and `953abd770815-rappel-security` (28/28) retain their recorded outcomes for the earlier fixtures; the final cells correct the cooldown-clock evidence and strengthen the cleanup/relay evidence without rewriting those records.

The changed-path and fixture inventory, refreshed 72-callsite spawn audit and 58-attempt campaign export are complete. Commit/patch/hash handoff metadata is refreshed after the final commits. Original import provenance, historical native manifests/results and contributor attribution remain preserved. Confirmed fixes, rejected findings, retained policies and pending human checks remain distinguishable.

The external stock Scout MFD problem remains EXT-1. A controlled test using the private reviewed display-condition addon is not a stock-content pass or a shipped game-asset fix. Independent Steam identities, voice audibility, full interactive placement and revive, interrupted real insertion, natural objective victory, full-duration Defense, deployment mods/database/Linux parity and comparative population-matched performance remain acceptance limits unless new evidence explicitly addresses them.
