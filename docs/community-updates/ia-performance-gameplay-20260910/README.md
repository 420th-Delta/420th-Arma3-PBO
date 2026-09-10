# JollyRogerEXP performance and gameplay update review

**Status: two review and remediation passes plus controlled native verification are complete; human/deployment acceptance remains.** Start with the [second-pass adjudication](REVIEW_PASS_2_ADJUDICATION.md), [local test report](LOCAL_TEST_REPORT.md), [static result](second-pass-static-validation.json) and [remediation ledger](REMEDIATION_LEDGER.md) for current decisions, fixes and evidence. The original review below describes the imported contribution before corrective work. Reviewed on 2026-09-10 against upstream `a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7`; the independent second pass was adjudicated on 2026-09-11. Contributor: [JollyRogerEXP](https://github.com/JollyRogerEXP). The initial code commits preserve the supplied changes with documented integration repairs and whitespace cleanup; subsequent corrections remain separately reviewable.

## Reading order

1. Read the [second-pass adjudication](REVIEW_PASS_2_ADJUDICATION.md) for every independent-review finding and the retained decisions.
2. Read the findings and commit table below.
3. Read the affected subsystem report: [AI and insertion](review-ai.md), [player support and damage](review-support.md), or [systems](review-systems.md).
4. Use the contributor's [release notes](RELEASE_NOTES.md) and [technical reference](TECHNICAL_NOTES.md) for intended behavior and acceptance scenarios. These two files are supplied documentation; only one trailing space in the technical reference was removed for Git whitespace validation. Their test counts are contributor claims: the referenced 15 verifiers, 58,320 assertions, SQF-VM adapters and detailed logs were not included or independently rerun.

## Findings recorded at import

Line references in the subsystem reports identify the incoming package, before upstream merge shifts. Severity describes code impact; conditional issues remain explicitly conditional.

| ID | Assessment | Required action before acceptance |
| --- | --- | --- |
| SUP-1 | P1, confirmed initialization mismatch | Map the CfgFunctions `postInit` argument to the initializer. The current code accepts `INIT` only, so the role-support lifecycle observer never starts. Verify join, revive, respawn and role/control changes. |
| SUP-2 | P1, source integration concern; event payload needs engine confirmation | New virtual ordnance supplies a null firing source while player damage/Robocop handlers reject or treat null sources differently. Capture HE, rocket, bomb and submunition events and repair attribution without changing firing-side policy. |
| SUP-3 | P2, confirmed missing server resource check | Mortar deployment accepts the client's success acknowledgment without verifying that the required tube was spent. Track the reservation and server-observed inventory state. |
| AI-01 | P2, confirmed cleanup ownership gap | Register final-reserve rotary aircraft and crew with an AO teardown owner. Census tracking alone does not retire surviving helicopters at AO end. |
| SYS-02 | P2, confirmed placement-boundary gap | Revalidate each caller's player/base exclusions at the actual displaced slots. A valid FOB anchor can produce a unit about 296 m from a player despite its 350 m admission rule. |
| SYS-01 | Compatibility prerequisite, resolved | The eleventh custom radio channel needs Arma 3 2.22. Local validation used 2.22, and Seathre confirmed the deployed server is on 2.22 or later. Client-version and channel-capacity checks remain deployment concerns. |

Additional acceptance concerns are documented in the subsystem reports: remote-control locality, scheduled RPC interleaving, failed spawn propagation, terrain-search frame cost, city cleanup overlap and radio policy. No FPS gain is established by this review.

## Gameplay policy disclosures

- Normal unattended incapacitation now uses a **240-second** bleed-out window instead of 600 seconds. Existing transport and medevac rules can extend it.
- The pilot/fighter-pilot forced-death branch is skipped for `forward_observer`, `jtac`, `jtac_WL`, `mortar_gunner`, the existing staff exception, and the active Kavala revive case. Other incapacitation death conditions still apply.
- Mega Defense uses a finite 30-minute timer and bypasses the optional `QS_defend_blockTimeout` overtime extension. Early HQ loss/failure and administrator cancellation still end it. Ordinary Defense gains 600–1200 seconds only when that optional flag is enabled; no production automatic TRUE setter was found.
- The custom Side channel grants all-player Side voice. If custom allocation fails, the native team-local Side fallback intentionally grants the same all-player voice policy; it does not make Side cross-team.

These are deliberate retained gameplay and communication policies. The second review's alternatives and the evidence supporting each decision are in the [adjudication](REVIEW_PASS_2_ADJUDICATION.md).

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

A final documentation commit records this review and the contributor's reference material. Existing PR #55 is separate from this branch; its pending air-defense additions were not used as the base. The branches share only `fn_remoteExec.sqf`. A final `git merge-tree` simulation in both orders produced the same conflict-free tree and retained #55's case-111 deployable-asset guard plus this branch's case-65/75 rappel guards. There is no technical order requirement; prefer #55 first because it is already open, then rebase this branch and rerun the combined security/integration cells.

### Corrective commit classification

The original nine commits remain intact. The first remediation pass added nine commits, producing the 18-commit reviewed snapshot. They are separated by the behavior they repair:

| Group | Scope |
| --- | --- |
| Role support and virtual fire | Atomic authenticated service transitions; menus, resource accounting, mortar transfer and debit; status publication; guided release and damage attribution. |
| AI ownership and placement | Rotary cleanup ownership/exemptions; server-only GRID dispatch; audited final-position rules and bounded searches. |
| Rappel initialization | Compile the five deferred helper bodies as preprocessed code. |
| Radio lifecycle and access | Side fallback, staff masks and asynchronous old-body retirement. |
| Deferred cleanup | Activity generations, current object protection and inventory-based holder deadlines; Kavala final spawn exclusions use the preceding AI placement correction. |
| Baseline client audio | Avoid vehicle-only sound queries on on-foot players; separate from the supplied contribution. |
| Baseline mapper synchronization | Final birth position for fresh land Houses; post-callback orientation in the existing authenticated JIP snapshot; atomic snapshot publication. Separate from the supplied contribution. |
| Native regression tooling | Frozen focused/integrated fixtures, owned-process containment, strict result gates and optional pinned stock-MFD test control. |
| Verification documentation | Issue ledger, preserved failure history, sanitized campaign results and remaining human/deployment acceptance. |

The [exact corrective path groups](remediation-commit-plan.json) map all 35 modified production files once: support 4, AI/spawn 17, rappel 1, radio 5, cleanup 3, baseline client audio 2 and baseline mapper/snapshot synchronization 3. Apply AI/spawn before cleanup because Kavala also adopts its final-position validator. Test tooling and verification documents follow as separate groups.

The second pass uses six semantic groups plus a final path-accounting correction, adding seven commits and bringing the stack to 25: AI creation/artillery/cutoff ordering; bound rappel RPC and active-descent cleanup; radio retirement/mapping cleanup; support cooldown and role policy; portable focused fixtures; adjudication/evidence documentation; and the accounting correction. Its ten production paths are grouped separately in the same commit plan. New commits carry explanatory bodies; the earlier nine follow-up commits remain unchanged as historical review artifacts.

The pinned MFD control is a local test option, not a mission content change or repair to the stock game asset. No game binaries, private configuration or raw operational logs belong in these commits.

## Baseline and integration

- Verified all 59 delivered payload hashes (55 modified runtime files and four additions).
- Reversed the supplied binary-capable patch in an isolated copy, reconstructing all 55 changed originals to their exact manifest SHA-256 values. The original Downloads package remained unchanged.
- Compared against freshly fetched upstream main. Twelve edited files had substantive upstream drift; five merged without conflicts and seven required resolutions.
- Preserved upstream diagnostics/performance instrumentation, aircraft bomb stripping, enabled hostile UAV setting, disabled recycler setting, disabled out-of-bounds loop registration, donor revocation and captured-body radio lifecycle handling.
- The radio old-body parameter moved to fourth position so upstream's existing third target-body parameter remains valid. Donor entitlement is included in the radio cache key. Spawn/cleanup instrumentation follows the changed admission/deletion paths. See [merge details](merge-systems.md) and the AI report.
- Normalized 50 changed lines with whitespace errors, including embedded SQF code literals. Nested string contents were preserved; the non-whitespace character stream is unchanged. Original patch/payload hashes remain available in [provenance](provenance.json).

## Validation recorded at import

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

The corrective changes and local native evidence are recorded above and in the linked ledger. Human and deployment acceptance should exercise the complete interactive placement UI, actual respawn/revive, independent-account permissions, voice delivery, player-facing accountability, moving guided targets, interrupted insertion/rappel, restarted city activities, natural victory and full-duration Defense with the intended mods/database. Obtain the contributor's referenced offline fixtures if that claimed coverage is needed. Compare performance with matched populations, AI/vehicle counts and activity stages before making performance claims. The stock Scout MFD limitation remains open as external content issue EXT-1.

## Original imported runtime inventory

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

The final branch changes 65 runtime paths against the recorded upstream base. Beyond the 59 imported paths above, corrections add `TGC/Functions/Staff/fn_staffChannelsGUI.sqf`, `code/functions/fn_findRandomPos.sqf`, `code/functions/fn_remoteExec.sqf`, `code/functions/fn_serverObjectsMapper.sqf`, `code/functions/fn_serverPublishEntityState.sqf` and `code/functions/fn_clientApplyEntityState.sqf`. These are corrections to existing repository files, not six new runtime files.
