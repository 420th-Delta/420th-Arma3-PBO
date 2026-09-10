# feat(mission): integrate and remediate JollyRogerEXP performance/gameplay update

Integrates @JollyRogerEXP's Arma 3 performance and gameplay contribution, preserves contributor attribution, and adds two separately reviewable remediation passes driven by source review and native local testing. The branch is based on upstream `a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7`; all 59 supplied payload hashes and 55 reconstructed original hashes were verified.

The contribution covers detector and laser-label work, HC maintenance scheduling, vehicle damage handlers, friendly-AI speech, a proposed shared Side/staff General radio policy, and the coupled Primary/Defense, insertion/rappel, spawn-placement, artillery/mortar, revive/city and cleanup overhaul. Existing upstream instrumentation, hostile-aircraft bomb stripping, UAV/recycler settings, donor revocation and captured-body radio semantics are retained. After contributor feedback, the shared-channel policy is retained for redesign behind a startup-only gate that defaults off.

The remediation commits repair authenticated support transitions and resource accounting; deny support reset while incapacitated at both UI and server boundaries; repair guided-ammunition attribution; close AI cleanup ownership, atomic creation registration and artillery admission gaps; enforce final spawn exclusions and bounded cutoff propagation; bind rappel sessions/helpers to the server with serial-aware descent cleanup; retain the tabled radio implementation behind a default-off gate; repair delayed old-body retirement and city/holder cleanup; and correct separate pre-existing client sound-controller and mapped-House replication defects. Native test controls are checked in or hash-pinned, require explicit local tool paths, reject malformed/zero-check results, and preserve failed attempts.

## Gameplay and communication policies

- Normal unattended incapacitation uses a **300-second (five-minute)** bleed-out window instead of 600 seconds. The imported contribution's earlier 240-second proposal is retained only in historical review evidence. Existing transport and medevac rules can extend the final window.
- The pilot/fighter-pilot forced-death branch is skipped for `forward_observer`, `jtac`, `jtac_WL`, `mortar_gunner`, the existing staff exception, and the active Kavala revive case. Kavala's higher-population eligibility and these exceptions were confirmed as intended. Other death conditions remain.
- Mega Defense uses a finite 30-minute timer and bypasses optional `QS_defend_blockTimeout` overtime. Early HQ loss/failure and administrator cancellation still apply. Ordinary Defense extends only when that optional flag is enabled.
- Mega Defense remains a server-invoked pre-restart script. A queued request is tied to the same Primary through its shutdown and cannot carry into a new AO. This request state is independent of `QS_forceDefend` mode `1` (one eligible Defense, then reset) and mode `2` (persistent).
- The shared custom Side/staff General policy is tabled. `QS_missionConfig_sharedRadioChannels` defaults to `FALSE`, allocates no extra channel while disabled, and preserves the served native Side/optional General behavior. The reviewed implementation remains available only through explicit startup opt-in for redesign/testing.
- Low-population covered-Taru delivery and the reviewed server-bound rappel method are retained as intended.
- Support menus disappear while a player is incapacitated. The local reset action and authenticated raw server `RESET` endpoint both deny a downed caller; eligible menus return after recovery.

## Native verification

Windows Arma 3 `2.22.0.154045` final-source cells, combining feedback reruns with still-applicable second-pass coverage:

| Cell | Assertions | Result |
| --- | ---: | --- |
| `797261a69cf2-support` | 229 | Pass |
| `fc9bd9ec0020-ai-spawn` | 23 | Pass |
| `b521c68495e5-radio-cleanup` | 86 | Pass |
| `921c1eee1e0c-rappel-security` | 41 | Pass |
| `24b88b35d2ec-integration` (0 HC) | 23 | Pass |
| `08bb81557d38-integration` (1 HC) | 29 | Pass |
| `29200aabcb98-integration` (2 HC) | 35 | Pass |

Every listed cell completed with zero failed assertions, script errors, malformed records, cleanup errors, or source/fixture/runtime integrity changes. The support, radio and integration cells froze the same 916-file source manifest (`8330fc18f0b7e8ff594187ed92c6e4ce2861ad9ec9ef10ea5a538220fac09745`). CfgConvert cell `5f6467570bb5-config` passes `description.ext`, `mission.sqm` and `code/config/security.hpp`. Assertion totals include repeated observations and are not counts of independent gameplay scenarios. The earlier `b51da40818f8-integration` 45/45 two-HC lifecycle result remains applicable to unchanged Defense code.

The stock-content integration failure remains external issue EXT-1: an independently reproduced stock Nyx Scout MFD expression error. Integration passes use the pinned private `reviewed-scout-v1` altered-content control, which changes only that display condition in the test fixture and is not shipped by this branch.

## Merge relationship

This branch and PR #55 both derive from the same upstream base and overlap only in `fn_remoteExec.sqf`. `git merge-tree` in both orders produces the same conflict-free tree and retains #55's case-111 deployable-asset authorization plus this branch's case-65/75 rappel authorization. There is no technical order requirement. Prefer #55 first because it is already open, then rebase this branch and rerun the combined security and integration cells. The remaining changed paths are independent.

## Acceptance limits

Focused fixtures and controlled integration do not establish an FPS improvement or deployment parity. Human placement, real respawn/revive, player-facing accountability, moving guided targets, interrupted bulk insertion/rappel and independent-account permissions still need acceptance testing. The redesigned radio policy will need its own delivered-voice and channel-capacity acceptance when it is selected. Linux hosting, deployed mods/database, natural objective victory, uninterrupted full-duration Defense and matched-population performance comparisons remain separate work.

See [the review overview](README.md), [second-pass adjudication](REVIEW_PASS_2_ADJUDICATION.md), [local test report](LOCAL_TEST_REPORT.md), [remediation ledger](REMEDIATION_LEDGER.md), and [commit plan](remediation-commit-plan.json) for provenance, per-finding decisions, reproduction and evidence limits.
