# Phased mission update rollout

The community update is split into three stacked draft pull requests so the server owner can review and merge each operational area independently. The active staging references are cumulative: Phase 2 starts at the Phase 1 tip, and Phase 3 starts at the Phase 2 tip.

| Pull request | Current staging reference | Includes | Does not include |
| --- | --- | --- | --- |
| Phase 1 | `rollout/phase-1-primary-performance` | Primary pressure and artillery, performance work, bounded cleanup, manual Mega Defense, 85×85 m outdoor spawning, Taru reinforcement delivery, and Spawn Menu vehicle locality repair | Player Support roles, radio/revive/Kavala changes, deployable AA crates, Priority AA, Combat Air, jet or AA target-control changes |
| Phase 2 | `stage/phase2-aa-turrets-20260912` | PR #55 deployable AA containers and the Priority AA battery/controller rework | Jolly Combat Air, Jolly enemy-CAS/missile-countermeasure changes, or other Jolly jet/AA target-control logic |
| Phase 3 | `stage/phase3-roles-remaining-20260912` | JTAC/Forward Observer/Mortar Gunner roles, player Support lifecycle, optional radio/staff work, revive and Kavala lifecycle, mapper/entity-state repair, and ordinary helicopter insertion follow-up | Jolly Combat Air/jet/AA targeting, Jolly enemy-CAS and missile-countermeasure changes, all of which remain outside this rollout |

Keep the pull requests as drafts until their native validation is recorded. Merge Phase 1 before Phase 2 and Phase 2 before Phase 3. Retarget the next pull request to `main` only after its parent merges.

## Phase 1 review boundary

Phase 1 owns mission pacing and server-frame work. Its `tests/phase-1/validate_scope.py` guard rejects dependencies on the deferred player Support, role, Kavala, and AA/jet systems. The native acceptance matrix in `tests/phase-1/README.md` identifies the multiplayer and load scenarios that still need engine evidence.

## Phase 2 review boundary

Keep PR #55's container/logistics commits at the bottom of the branch, then review Priority AA scheduling and registration separately. The controller must recognize the FIA HQ mobile Tigris path and dormant Independent AA path, or tests must show why a path cannot become active.

## Phase 3 review boundary

Phase 3 is the only place that adds player-facing Support roles and the role-specific stalking exemption. It contains:

- Forward Observer, JTAC, and Mortar Gunner role/menu support, with server-owned stocks and Primary/Defense lifecycle refreshes.
- A narrow exemption for those roles when they are the only player within 500 m. The Phase 1 ground-target order stays intact.
- Optional shared Side and staff General radio channels, defaulting off through `QS_missionConfig_sharedRadioChannels`, with staff authorization and old-body cleanup after role changes, respawn, and reconnect.
- Five-minute normal bleed-out, Support-role incapacitation handling, Kavala-specific revive state with bounded cleanup and completion reset, and mapped-building direction/up-vector replication.
- Generic ordinary helicopter insertion lifecycle and cleanup work. The Phase 1 `TARU_POLICY`, `TARU_CREATE`, and `TARU_DELIVER` early modes are untouched.

Phase 3 must not introduce `QS_fnc_combatAir`, `QS_combatAir_*`, Jolly's `enemyCAS` changes, or Jolly's `AIXMissileCountermeasure` changes. It must not alter the Phase 2 Priority AA controller, its target-selection rules, or PR #55's deployable-container implementation. These are hard source boundaries, not merely deployment guidance.

Run the lightweight Phase 3 checks from the repository root:

```powershell
python Apex_framework.terrain/tests/phase-3/validate_scope.py
python Apex_framework.terrain/tests/phase-3/validate_role_systems.py
git diff --check
```

The scope guard compares the worktree with `stage/phase2-aa-turrets-20260912`. It rejects forbidden Combat Air/enemy-CAS/missile-countermeasure edits, rejects changes to protected AA/container files, and exactly compares the Taru integration block with the Phase 2 base. The role-system check verifies the static wiring for Support, radio, revive/Kavala, and mapper/entity-state changes. Neither check replaces an Arma engine session.

Before removing the Phase 3 draft label, capture engine evidence for:

| Scenario | Required observation |
| --- | --- |
| Support roles | Observer/JTAC requests respect authorization, target restrictions, stock depletion, and Primary/Defense refresh; a Mortar Gunner's section is removed or reassigned safely on role loss, death, and locality changes. |
| Radio/staff | Default configuration leaves shared channels disabled. With the opt-in setting enabled, Side/staff access follows authorization and no old body remains in a channel after respawn, reconnect, or role change. |
| Revive/Kavala | Support roles enter ordinary incapacitation; Kavala enables its dedicated revive state only for the event, handles population changes, and restores the ordinary state on every completion/abort path. |
| Entity mapper | A rotated mapped house renders with its recorded direction/up vectors for a newly joining client as well as an existing client. |
| Helicopters | Exercise ordinary insertion completion, abort, deletion, and group/vehicle locality handoff. Re-run the Phase 1 Taru parachute, rope, blocked-rope fallback, and descent-drain cases to show the early modes remain intact. |
