# feat(mission): integrate and remediate JollyRogerEXP performance/gameplay update

Integrates @JollyRogerEXP's Arma 3 performance and gameplay contribution, preserves contributor attribution, and adds two separately reviewable remediation passes driven by source review and native local testing. The branch is based on upstream `a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7`; all 59 supplied payload hashes and 55 reconstructed original hashes were verified.

The contribution covers detector and laser-label work, HC maintenance scheduling, vehicle damage handlers, friendly-AI speech, shared Side/staff General radio policy, and the coupled Primary/Defense, insertion/rappel, spawn-placement, artillery/mortar, revive/city and cleanup overhaul. Existing upstream instrumentation, hostile-aircraft bomb stripping, UAV/recycler settings, donor revocation and captured-body radio semantics are retained.

The remediation commits repair authenticated support transitions and resource accounting; guided-ammunition attribution; AI cleanup ownership, atomic creation registration and artillery admission; final spawn exclusions and bounded cutoff propagation; server-bound rappel sessions/helpers with serial-aware descent cleanup; radio allocation fallback and delayed old-body retirement; city/holder cleanup; and separate pre-existing client sound-controller and mapped-House replication defects. Native test controls are checked in or hash-pinned, require explicit local tool paths, reject malformed/zero-check results, and preserve failed attempts.

## Gameplay and communication policies

- Normal unattended incapacitation uses a **240-second** bleed-out window instead of 600 seconds. Existing transport and medevac rules can extend it.
- The pilot/fighter-pilot forced-death branch is skipped for `forward_observer`, `jtac`, `jtac_WL`, `mortar_gunner`, the existing staff exception, and the active Kavala revive case. Other death conditions remain.
- Mega Defense uses a finite 30-minute timer and bypasses optional `QS_defend_blockTimeout` overtime. Early HQ loss/failure and administrator cancellation still apply. Ordinary Defense extends only when that optional flag is enabled.
- The custom Side channel grants all-player voice. Its allocation-failure fallback intentionally grants all-player voice on the native team-local Side channel. Seathre confirmed the server runs Arma 3 2.22 or later.

## Native verification

Windows Arma 3 `2.22.0.154045` final second-pass cells:

| Cell | Assertions | Result |
| --- | ---: | --- |
| `498cfe21ffd1-support` | 219 | Pass |
| `fc9bd9ec0020-ai-spawn` | 23 | Pass |
| `d151a4aeab19-radio-cleanup` | 73 | Pass |
| `921c1eee1e0c-rappel-security` | 41 | Pass |
| `d7a27107775c-integration` (0 HC) | 22 | Pass |
| `36e972349cea-integration` (1 HC) | 28 | Pass |
| `b51da40818f8-integration` (2 HC lifecycle) | 45 | Pass |

Every listed cell completed with zero failed assertions, script errors, malformed records, cleanup errors, or source/fixture/runtime integrity changes. CfgConvert cell `8c3d17da3d64-config` also passes `description.ext`, `mission.sqm` and `code/config/security.hpp`. Assertion totals include repeated observations and are not counts of independent gameplay scenarios.

The stock-content integration failure remains external issue EXT-1: an independently reproduced stock Nyx Scout MFD expression error. Integration passes use the pinned private `reviewed-scout-v1` altered-content control, which changes only that display condition in the test fixture and is not shipped by this branch.

## Merge relationship

This branch and PR #55 both derive from the same upstream base and overlap only in `fn_remoteExec.sqf`. `git merge-tree` in both orders produces the same conflict-free tree and retains #55's case-111 deployable-asset authorization plus this branch's case-65/75 rappel authorization. There is no technical order requirement. Prefer #55 first because it is already open, then rebase this branch and rerun the combined security and integration cells. The remaining changed paths are independent.

## Acceptance limits

Focused fixtures and controlled integration do not establish an FPS improvement or deployment parity. Human placement, real respawn/revive, delivered voice, player-facing accountability, moving guided targets, interrupted bulk insertion/rappel and independent-account permissions still need acceptance testing. Linux hosting, deployed mods/database, natural objective victory, uninterrupted full-duration Defense, channel-capacity exhaustion and matched-population performance comparisons remain separate work.

See [the review overview](README.md), [second-pass adjudication](REVIEW_PASS_2_ADJUDICATION.md), [local test report](LOCAL_TEST_REPORT.md), [remediation ledger](REMEDIATION_LEDGER.md), and [commit plan](remediation-commit-plan.json) for provenance, per-finding decisions, reproduction and evidence limits.
