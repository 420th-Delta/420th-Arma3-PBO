# AI, Primary/Defense and insertion review

Reviewed contributor runtime sources against `combat_update.patch`, with unchanged callers inspected in `420th-Arma3-PBO-ia-update-20260910` (origin/main `a0a58e1`). Source line references below are the contributor package unless explicitly marked integration. This is a static source review, not an Arma engine, graphical-player or live-server acceptance test. The contributor's claimed offline assertions/verifiers were not supplied as executable fixtures and are not independently verified here.

## Actionable finding

### AI-01 ? Register final-reserve helicopters with an AO cleanup owner (P2)

- **File/lines:** `mission/code/functions/fn_AI.sqf:2062-2069` (ROTARY worker), with `_fn_track` at 687-724, `_fn_register` at 675-685, and STOP at 1467-1475.
- **Trigger:** With at least 16 nearby conscious ground players, all strategic objectives completed, at least ten remaining ground enemies, sufficient capacity and the final-reserve random/timing gates satisfied, the controller selects a ROTARY reserve. The helicopter survives until this AO ends.
- **Consequence:** The aircraft and its crew survive AO teardown, retain dynamic-simulation exemptions and CAS-provider registration, and can continue into the following activity. Successive eligible AOs can accumulate these aircraft.
- **Evidence:** ROTARY invokes `QS_fnc_scSpawnHeli` and passes its result only to `_fn_track`, which puts objects in `state.initial`. It never invokes `_fn_register`, which adds `state.entities` and the ownership epoch. STOP returns only `state.entities` and discards the entire state. The ordinary helicopter caller, by comparison, appends its result to `_QS_module_classic_patrolsHeli` (4365-4375), and deinit later deletes that array. The ROTARY worker never appends to that native cleanup array. `fn_scSpawnHeli` itself returns its units and aircraft, registers support providers and disables dynamic simulation, but does not add a garbage-collector/deinit ownership record. `QS_combatAir_groups` only maintains an owner-local scheduler list; it is not a teardown registry.
- **Suggested correction:** Put every object returned by the ROTARY spawner into the Primary controller's owned-entity registry (or hand it into the native patrol cleanup array) and preserve the normal crew/vehicle ownership exemptions. Keep census/accounting separate from lifecycle ownership.
- **Reproduction to add:** Force this exact worker branch under a valid final-reserve state, capture returned aircraft/crew, complete or cancel the AO, wait through native teardown, and assert all owned entities are retired and provider arrays no longer contain live pilots. A policy-only test of the admission probabilities cannot catch this issue.
- **Status:** Identified by source dataflow; not fixed or engine-reproduced in this review.

## Reviewed areas and useful changes

- `fn_AI`: shared BLUFOR ground-target classification; full Primary AO controller, objective tapering, contact/casualty response, artillery allowance, capacity admission, finite workers, wind calibration, and combat-air role/engagement controller.
- `fn_AIHandleGroup`, `fn_AIHandleUnit`, `fn_AIFireMission`: existing scheduler integration, tagged group movement, observation reports, artillery gating, suppression and aircraft task leasing. Managed air ground missions are spawned by the unit support-request path; the group handler's early return for pending missions is therefore not itself a deadlock.
- `fn_AIXHeliInsert`, `fn_AIXHeliInsertLanding`: new Taru creation/delivery mode, bounded native insertion lifecycle, and one EnemyDetected callback per landed group. Primary and Defense consumers reserve/admit their own infantry and launch delivery workers.
- `fn_AIXMissileCountermeasure`, `fn_AIXSuppressiveFire`: managed aircraft countermeasures and suppression handler scope/locality guard. The suppression handler's locally resolved group is a focused repair that can be separated from most gameplay.
- `fn_aoDefend`: new manual-extension hooks, flank borrowing, Taru delivery, spawn-position admission, and leader-only movement passes. Large portions of this are gameplay policy, not a measured performance improvement.
- `fn_aoEnemy`, `fn_aoSubObjectives`: placement admission, guard tagging, commander MPKilled lifecycle handling and repeatable enemy-population completion evaluation.
- `fn_enemyCAS`: one flight per group, pilot death-handler scope fix and combat-air registration.
- `AR_AdvancedRappelling_ext`, `IA_MegaDefense`: bounded rope/animation/helper cleanup, AI release rules and server-local manual Defense request lifecycle.

No additional high-confidence introduced correctness bug was established in the examined paths. This statement does not establish that the large controller is production-ready.

## Commit boundaries and dependencies

Whole-file staging cannot cleanly separate the gameplay features because `fn_AI`, `fn_AIHandleGroup`, `fn_AIHandleUnit`, `fn_aoDefend` and `fn_AIFireMission` each contain several features. A single large gameplay integration commit preserves dependencies, but loses reviewability. Safe finer commits need hunk extraction and validation after every intermediate commit. Suggested order:

| Commit group | Content | Dependencies / split caveat |
| --- | --- | --- |
| Shared spawn admission | New `spawnGroup` placement/group policy API plus all existing callers that rely on it | Parent/system review owns this component; add before Primary/Defense consumers. Full-group size changes are gameplay and should be stated explicitly. |
| Focused AI lifecycle repairs | Commander MPKilled migration; pilot Killed handler scope; resolved suppression-handler group; moved landed-group EnemyDetected handler; native insertion lifetime/rope cleanup | These are hunk-level changes. Keep paired insertion/landing lifecycle contracts together. Standalone cleanup can omit later Taru consumers. |
| Ground-target classification | `QS_fnc_groundTargetPriority` and support-selection replacements | Classification must be defined before any unguarded consumers. Safe shared foundation for later pursuit and air groups. |
| Primary AO controller | `QS_fnc_aoPressure`, objective/guard integration, handlers, completion, artillery allowance, and its native-loop hooks | Requires spawn API and target priority. As submitted, also calls Taru policy/delivery and combatAir; either include their contracts first or defer those exact caller hunks. Primary pressure itself has a next-AO enable switch. |
| Combat-air behavior | `QS_fnc_combatAir`, one group per flight, aircraft registration, countermeasures, ground-request lease/finalizer changes | Target priority first. `AIFireMission` eligibility checks require it. Existing Primary FINAL_AIR coordination must land with whichever component introduces the relevant hook. |
| Defense behavior | Flank borrowing, target filtering, covering-fire-compatible movement, leader-only iteration, spawn admission | Target priority and spawn API first. Keep the suppression movement coordination with its unit-handler change. Taru and Mega Defense hooks can be deferred as separate hunks. |
| Taru delivery | TARU_* API, Primary/Defense call sites, wind/drop integration, rope release/fallback | Requires Primary DROP_* helper definition and paired rappelling implementation. Legacy native insertion cleanup need not share the same commit if extracted carefully. |
| Manual Mega Defense | `IA_MegaDefense.sqf`, exact `fn_core` request/handoff hunks and `fn_aoDefend` duration/state hooks | Keep request producer/consumer state schema atomic. No automatic scheduler or Zeus UI is introduced by this script alone. |

The Primary/Taru/air coupling creates an ordering cycle at the file level. One option is a shared inactive controller/API commit, then separate activation/caller commits. Otherwise retain a combined Primary/air/Taru integration commit and split the genuinely independent repairs, Defense changes and manual Mega Defense around it. Do not create intermediate commits that call missing modes/functions merely to achieve smaller commit counts.

## Validation still needed

1. Dedicated-server Primary lifecycle: each objective combination, decreasing/zero player counts, FPS pause/recovery, exact final-clearance window, all delivery types, AO cancellation during each worker phase, and the AI-01 final helicopter teardown.
2. Locality handoff: server-to-HC movement and intel, HC disconnect, Zeus control while airborne/suppressing/rappelling, commander death after ownership transfer, and support admission with server-local providers.
3. Air/task coordination: CAP versus CAS loadouts after upstream bomb removal, interception-to-CAS transitions, missile-triggered cancellation, active laser/assistant cleanup and the next AO/Defense transition.
4. Real terrain and player view: slot placement around towns/rocks/water; eight-to-twelve-man groups; Taru approach/parachute/rappel on sloped terrain; player rappel controls and animation restoration; no lost rope/helper objects.
5. Matched-load performance evidence using the upstream telemetry, including low-FPS group/unit cadence and long Defense cleanup. Larger populations and more sustained reinforcements can offset reduced scripted overhead.

Verified uncertain command contracts against official Bohemia documentation: [`doSuppressiveFire`](https://community.bistudio.com/wiki/doSuppressiveFire) accepts PositionASL, so the new targetKnowledge-derived suppression point is not an ATL/ASL conversion bug; [`targets`](https://community.bistudio.com/wiki/targets) accepts Group as well as Object (Group support since 2.12). These checks do not substitute for engine execution.

## Integration merge performed

At the parent's request, resolved only `fn_aoDefend.sqf` and `fn_aoEnemy.sqf` in the new integration worktree using the provided three-way artifacts. No gameplay correction was applied.

- `fn_aoDefend`: resolved three conflicts. Armor and truck placement guards run before the existing perfBegin/create/perfEnd measurement. The new combatAir registration coexists with upstream enemy-jet transform registration.
- `fn_aoEnemy`: resolved one conflict. Vehicle-slot admission runs before upstream createVehicle timing.
- Retained all 19 perfBegin/perfEnd pairs in Defense and all nine pairs in AO enemy generation. Counter comparison against `upstream` artifacts verifies every existing telemetry, aircraft-bomb-removal and transform-diagnostic statement remains.
- `git diff --check -- <the two paths>` passed. No SQF runtime or engine test was run. Git's expected LF-to-CRLF worktree warning is unrelated to SQF correctness.
