# JollyRogerEXP performance and gameplay update review

**Status: draft review; gameplay has unresolved findings.** Reviewed on 2026-09-10 against upstream `a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7`. Contributor: [JollyRogerEXP](https://github.com/JollyRogerEXP). The code commits preserve the supplied changes, with documented integration repairs and whitespace cleanup. Review findings have not been silently fixed or omitted.

## Reading order

1. Read the findings and commit table below.
2. Read the affected subsystem report: [AI and insertion](review-ai.md), [player support and damage](review-support.md), or [systems](review-systems.md).
3. Use the contributor's [release notes](RELEASE_NOTES.md) and [technical reference](TECHNICAL_NOTES.md) for intended behavior and acceptance scenarios. These two files are supplied documentation; only one trailing space in the technical reference was removed for Git whitespace validation. Their test counts are contributor claims: the referenced 15 verifiers, 58,320 assertions, SQF-VM adapters and detailed logs were not included or independently rerun.

## Findings that need resolution

Line references in the subsystem reports identify the incoming package, before upstream merge shifts. Severity describes code impact; conditional issues remain explicitly conditional.

| ID | Assessment | Required action before acceptance |
| --- | --- | --- |
| SUP-1 | P1, confirmed initialization mismatch | Map the CfgFunctions `postInit` argument to the initializer. The current code accepts `INIT` only, so the role-support lifecycle observer never starts. Verify join, revive, respawn and role/control changes. |
| SUP-2 | P1, source integration concern; event payload needs engine confirmation | New virtual ordnance supplies a null firing source while player damage/Robocop handlers reject or treat null sources differently. Capture HE, rocket, bomb and submunition events and repair attribution without changing firing-side policy. |
| SUP-3 | P2, confirmed missing server resource check | Mortar deployment accepts the client's success acknowledgment without verifying that the required tube was spent. Track the reservation and server-observed inventory state. |
| AI-01 | P2, confirmed cleanup ownership gap | Register final-reserve rotary aircraft and crew with an AO teardown owner. Census tracking alone does not retire surviving helicopters at AO end. |
| SYS-02 | P2, confirmed placement-boundary gap | Revalidate each caller's player/base exclusions at the actual displaced slots. A valid FOB anchor can produce a unit about 296 m from a player despite its 350 m admission rule. |
| SYS-01 | Compatibility prerequisite | The eleventh custom radio channel needs Arma 3 2.22. Local validation used 2.22; the deployed server/client versions still need confirmation. This is not evidence that deployment currently uses an older version. |

Additional acceptance concerns are documented in the subsystem reports: remote-control locality, scheduled RPC interleaving, failed spawn propagation, terrain-search frame cost, city cleanup overlap and radio policy. No FPS gain is established by this review.

## Commit classification

| Order | Commit | Runtime files | Scope and dependency |
| --- | --- | ---: | --- |
| 1 | `perf(ai): filter detector areas before checking sides` | 1 | Area filtering; no gameplay balance change intended. |
| 2 | `perf(lasers): cache cosmetic laser-owner attribution` | 1 | 250 ms label cache; target positions remain current. |
| 3 | `perf(hc): schedule dynamic simulation scans from completion` | 1 | Avoid immediately overdue maintenance after a slow scan. |
| 4 | `fix(vehicles): reuse damage handlers after locality returns` | 1 | Retain valid HandleDamage registration across ownership handoffs. |
| 5 | `fix(ai): resolve suppression callback group and locality` | 1 | Resolve FiredMan callback group locally; managed-cover flag defaults false. |
| 6 | `feat(ai): suppress automatic friendly AI radio speech` | 2 | Speech policy with JIP, respawn and locality hooks. |
| 7 | `feat(radio): add shared Side and staff General broadcasts` | 7 | Seven-file radio policy; preserve upstream body identity and donor revocation; requires Arma 3 2.22. |
| 8 | `feat(gameplay): integrate community combat and support overhaul` | 45 | Coupled Primary/Defense, air/Taru/rappel, spawn placement, artillery/mortar roles, revive/Kavala, housekeeping and manual Mega Defense. Open review findings; apply as a unit. |

The first seven groups are independent from the large gameplay activation. Group 5's managed-cover exclusion is inert until the gameplay controller sets it. Group 7 keeps the unrelated newer upstream UAV/recycler configuration values. Group 8 contains 45 files because Primary, Taru, combat-air, role services, core cleanup and registration form dependency cycles across shared files. Arbitrary file splitting would produce calls to absent functions or incompatible state. A finer split requires semantic hunk extraction and validation of every intermediate revision; the subfeature split proposals are retained in the reviewer reports. Group 8 must not be cherry-picked by individual files.

A final documentation commit records this review and the contributor's reference material. Existing PR #55 is separate from this branch; its pending air-defense additions were not used as the base.

## Baseline and integration

- Verified all 59 delivered payload hashes (55 modified runtime files and four additions).
- Reversed the supplied binary-capable patch in an isolated copy, reconstructing all 55 changed originals to their exact manifest SHA-256 values. The original Downloads package remained unchanged.
- Compared against freshly fetched upstream main. Twelve edited files had substantive upstream drift; five merged without conflicts and seven required resolutions.
- Preserved upstream diagnostics/performance instrumentation, aircraft bomb stripping, enabled hostile UAV setting, disabled recycler setting, disabled out-of-bounds loop registration, donor revocation and captured-body radio lifecycle handling.
- The radio old-body parameter moved to fourth position so upstream's existing third target-body parameter remains valid. Donor entitlement is included in the radio cache key. Spawn/cleanup instrumentation follows the changed admission/deletion paths. See [merge details](merge-systems.md) and the AI report.
- Normalized 50 changed lines with whitespace errors, including embedded SQF code literals. Nested string contents were preserved; the non-whitespace character stream is unchanged. Original patch/payload hashes remain available in [provenance](provenance.json).

## Validation actually performed

| Check | Result and scope |
| --- | --- |
| Payload and reconstruction hashes | 59/59 updated files and 55/55 originals verified. |
| Static SQF string/comment/bracket checks | 56/56 complete supplied SQF files pass. |
| Windows native SQF compilation | 56/56 compile; zero script errors and zero captured engine-error lines; Arma dedicated 2.22.0.154045, 15.3 seconds. |
| CfgConvert | `description.ext`, `code/config/security.hpp` and unchanged `mission.sqm` pass. |
| Git whitespace check | Pass after recorded whitespace normalization. |
| Source scope and upstream preservation | All 59 input paths accounted for; diagnostics/helpers and protected upstream settings retained; no unresolved conflict markers or detected credential additions. |

The native test used a synthetic, unmodded Stratis dedicated fixture that preprocesses/compiles the 56 supplied SQFs with the merged config include closure. It did not execute their gameplay code or compile nested `compileFinal` string bodies. It did not boot the complete Altis mission, connect graphical players/HCs, load the production mods/database, test Linux or measure FPS. Only the recorded whitespace changes followed the frozen engine snapshot; their non-whitespace character stream is unchanged.

The inner compile harness finished successfully and removed its test mission. The outer evidence coordinator did not produce its final summary after cleanup; its task-owned process was stopped after sustained CPU. Inner JSON/RPT results were retained, snapshot hashes and cleanup were checked independently, and the additional `mission.sqm` check was rerun directly with a captured successful exit code. This is a successful compile result with a coordinator limitation, not a successful outer-wrapper run. [Machine-readable results](validation.json).

Local raw evidence is held in the sibling `IA-PerformanceGameplayUpdate-review-20260910/` directory, outside this repository: input verification, reconstructed originals, three-way merge inputs, normalization records, native fixture/RPT/config logs and review scripts. Game binaries, extracted game assets, private inputs and raw operational logs are excluded from the commits.

## Next acceptance steps

Resolve the findings in separate corrective commits so the contributor's original behavior and subsequent corrections remain reviewable. Obtain the referenced offline fixtures. Then run Primary to Defense to next Primary with real players and the intended HC/mod configuration; exercise role lifecycle, released-shot attribution, mortar cancellation/resource accounting, final-reserve cleanup, spawn exclusions, interrupted insertion/rappel and city cleanup. Compare performance with matched populations, AI/vehicle counts and activity stages before making performance claims.

## Complete runtime inventory

| Mission-relative path | Commit group | Status |
| --- | ---: | --- |
| `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf` | 7 | Modified |
| `TGC/Functions/Damage/fn_addFriendlyAIHandlers.sqf` | 6 | Modified |
| `TGC/Functions/Damage/fn_addSpawnMenuVehicleHandlers.sqf` | 4 | Modified |
| `TGC/Functions/Damage/fn_initFriendlyAIProtection.sqf` | 6 | Modified |
| `TGC/Functions/Damage/fn_isFriendlyFire.sqf` | 8 | Modified |
| `TGC/Functions/Lasers/fn_initLaserHandlers.sqf` | 2 | Modified |
| `code/config/security.hpp` | 8 | Modified |
| `code/functions/fn_AI.sqf` | 8 | Modified |
| `code/functions/fn_AIFireMission.sqf` | 8 | Modified |
| `code/functions/fn_AIHandleGroup.sqf` | 8 | Modified |
| `code/functions/fn_AIHandleUnit.sqf` | 8 | Modified |
| `code/functions/fn_AIXHeliInsert.sqf` | 8 | Modified |
| `code/functions/fn_AIXHeliInsertLanding.sqf` | 8 | Modified |
| `code/functions/fn_AIXMissileCountermeasure.sqf` | 8 | Modified |
| `code/functions/fn_AIXSuppressiveFire.sqf` | 5 | Modified |
| `code/functions/fn_ambientHostility.sqf` | 8 | Modified |
| `code/functions/fn_aoDefend.sqf` | 8 | Modified |
| `code/functions/fn_aoEnemy.sqf` | 8 | Modified |
| `code/functions/fn_aoEnemyReinforceVehicles.sqf` | 8 | Modified |
| `code/functions/fn_aoSubObjectives.sqf` | 8 | Modified |
| `code/functions/fn_artillerySupport.sqf` | 8 | Added |
| `code/functions/fn_clientArsenal.sqf` | 8 | Modified |
| `code/functions/fn_clientCore.sqf` | 8 | Modified |
| `code/functions/fn_clientDamageModifier.sqf` | 8 | Modified |
| `code/functions/fn_clientEventHit.sqf` | 8 | Modified |
| `code/functions/fn_clientEventPut.sqf` | 8 | Modified |
| `code/functions/fn_clientEventRespawn.sqf` | 7 | Modified |
| `code/functions/fn_clientInteractMortarLite.sqf` | 8 | Modified |
| `code/functions/fn_clientMenuRadio.sqf` | 7 | Modified |
| `code/functions/fn_clientRadio.sqf` | 7 | Modified |
| `code/functions/fn_config.sqf` | 7 | Modified |
| `code/functions/fn_core.sqf` | 8 | Modified |
| `code/functions/fn_enemyCAS.sqf` | 8 | Modified |
| `code/functions/fn_eventBuildingChanged.sqf` | 8 | Modified |
| `code/functions/fn_fobEnemyAssault.sqf` | 8 | Modified |
| `code/functions/fn_gridEnemy.sqf` | 8 | Modified |
| `code/functions/fn_gridSpawnAttack.sqf` | 8 | Modified |
| `code/functions/fn_gridSpawnPatrol.sqf` | 8 | Modified |
| `code/functions/fn_hcCore.sqf` | 3 | Modified |
| `code/functions/fn_highCommand.sqf` | 7 | Modified |
| `code/functions/fn_incapacitated.sqf` | 8 | Modified |
| `code/functions/fn_initPlayerLocal.sqf` | 7 | Modified |
| `code/functions/fn_missionGeorgetown.sqf` | 8 | Modified |
| `code/functions/fn_missionKavala.sqf` | 8 | Modified |
| `code/functions/fn_mortarSupport.sqf` | 8 | Added |
| `code/functions/fn_roles.sqf` | 8 | Modified |
| `code/functions/fn_scEnemy.sqf` | 8 | Modified |
| `code/functions/fn_scSpawnHeli.sqf` | 8 | Modified |
| `code/functions/fn_scSpawnLandVehicle.sqf` | 8 | Modified |
| `code/functions/fn_serverDetector.sqf` | 1 | Modified |
| `code/functions/fn_spawnGroup.sqf` | 8 | Modified |
| `code/functions/fn_spawnSupport.sqf` | 8 | Modified |
| `code/functions/fn_spawnViperTeam.sqf` | 8 | Modified |
| `code/functions/fn_taskAttack.sqf` | 8 | Modified |
| `code/functions/fn_taskPatrol.sqf` | 8 | Modified |
| `code/scripts/AR_AdvancedRappelling_ext.sqf` | 8 | Modified |
| `code/scripts/IA_MegaDefense.sqf` | 8 | Added |
| `description.ext` | 8 | Modified |
| `media/images/roles/arid/forward_observer.jpg` | 8 | Added |
