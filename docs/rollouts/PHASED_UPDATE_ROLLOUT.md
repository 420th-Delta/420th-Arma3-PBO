# Phased mission update rollout

The community update is split into three stacked draft pull requests so a server owner can review and merge each operational area independently.

| Pull request | Branch | Includes | Does not include |
| --- | --- | --- | --- |
| Phase 1 | `rollout/phase-1-primary-performance` | Primary pressure and artillery, performance work, bounded cleanup, manual Mega Defense, 85×85 m outdoor spawning, Taru reinforcement delivery, and Spawn Menu vehicle locality repair | Player Support roles, radio/revive/Kavala changes, deployable AA crates, Priority AA, Combat Air, jet or AA target-control changes |
| Phase 2 | `rollout/phase-2-priority-aa-and-turrets` | PR #55 deployable AA containers and the Priority AA battery/controller rework | Jolly Combat Air or other Jolly jet/AA target-control logic |
| Phase 3 | `rollout/phase-3-roles-and-remaining-systems` | JTAC/FO/Mortar Gunner roles, player Support lifecycle, radio/staff work, revive and Kavala lifecycle, and ordinary helicopter insertion follow-up | Jolly Combat Air/jet/AA targeting, which Phase 2 supersedes |

Each branch is based on the preceding phase. Keep the pull requests as drafts until their native validation is recorded, merge Phase 1 before Phase 2, and merge Phase 2 before Phase 3. Retarget the next pull request to `main` only after its parent merges.

## Phase 1 review boundary

Phase 1 owns mission pacing and server-frame work. Its `tests/phase-1/validate_scope.py` guard rejects dependencies on the deferred player Support, role, Kavala, and AA/jet systems. The native acceptance matrix in `tests/phase-1/README.md` identifies the multiplayer and load scenarios that still need engine evidence.

## Phase 2 review boundary

Keep PR #55's container/logistics commits at the bottom of the branch, then review Priority AA scheduling and registration separately. The controller must recognize the FIA HQ mobile Tigris path and dormant Independent AA path, or tests must show why a path cannot become active.

## Phase 3 review boundary

Phase 3 is the only place that may add player-facing Support roles and the role-specific targeting exemption. If Phase 3 needs to touch a Phase 1 controller, retain Phase 1's Primary, Taru, and ground-only target behavior and add only the explicit Support lifecycle hook.
