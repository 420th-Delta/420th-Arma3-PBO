# 420th Delta Classic Invade & Annex

Mission file for the 420th Delta Classic Invade & Annex server.

This checkout is the cumulative **Phase 3** staging branch. It is intended to be reviewed as three stacked pull requests, with each later phase based on the preceding one. The review boundaries, merge order, and engine acceptance cases are in [the rollout plan](docs/rollouts/PHASED_UPDATE_ROLLOUT.md).

| Phase | Review focus |
| --- | --- |
| 1 | Primary pacing, server-frame work, bounded cleanup, outdoor spawning, Taru reinforcement delivery, and Spawn Menu vehicle-locality repair |
| 2 | PR #55 deployable AA containers and the Priority AA battery/controller rework |
| 3 | Player Support roles, optional shared radio/staff channels, revive and Kavala lifecycle, entity-state repair, and ordinary helicopter insertion follow-up |

## Phase 1: Primary performance and delivery

Phase 1 changes the Classic AO and Defense pace while keeping its work bounded under server load.

| Area | Implemented behavior |
| --- | --- |
| Primary reinforcements | Population counting occurs only when a delivery is due and uses nearby, conscious ground players. Aircraft occupants do not count. Squad size is 8–12 and the live personnel ceiling is 24–120; there is no lifetime spawn quota. |
| Frame-rate protection | Movement refresh slows below 18 FPS. Arsenal gear, logistics crates, and building ruins are collected in batches across ticks, with smaller batches at low FPS. Area filtering precedes side checks, laser labels are cached, and HC dynamic-simulation scans wait for their complete interval. |
| Objective effects | Each strategic objective reduces the enemy reinforcement ceiling by 20%. Datalink, Commander, and Radio Tower each remove one third of the enemy artillery allowance. |
| Taru delivery | Tarus are the Primary default below 20 players (90% preference); at 20 or more players they remain within 12.5% of delivered infantry. They paradrop at 180–220 m, with a 10% fast-rope route when the landing area is safe. |
| AI pressure | Squads react to actual AI sightings, casualty response, and contact pressure rather than a player-position feed. Ground target order is AA, artillery, tanks, other vehicles, then infantry. |
| Artillery and clearance | Enemy artillery has a fixed 3/6/9-fire-mission Primary budget by population. Primary mortars use 4–6 shells with a faster high-population cooldown. Final clearance requires completed objectives, no inbound delivery, and fewer than ten hostile ground troops for 15 seconds. |
| Defense and spawns | Defense probability is 33–66%; the former four-Defense high-population cutoff is removed and up to two flank squads can appear at 10+ ground players. Outdoor spawns use an 85 by 85 m footprint with 15 m spacing and moving squads provide covering fire. |
| Admin event | Zeus/Admin can manually request a 30-minute Mega Defense from the dev console before restart. It never starts automatically. |

## Phase 2: Priority AA changes

Phase 2 adds a CSAT SAM battery and independent Priority AA scheduling, based on remote main `a0a58e1`. The enhanced mission and reinforcement balance activate at **40 human players** by default; headless clients do not count.

| Change | Implemented behavior and defaults |
| --- | --- |
| SAM battery | One S-750 Rhea launcher and one Cronus radar inside the compound, with two more Rheas randomly placed outside the walls. The exterior launcher count is configurable from 0 to 2. |
| Guards | Two mobile Tigrises, one Varsuk tank, and the usual infantry count distribution: 24-48 Vipers. Vehicle crews use Viper equipment. |
| Ammunition and completion | All Rhea launchers replenish their missiles indefinitely while the objective is active, after a 15-30 second resupply delay. Destroy the radar and every Rhea to complete the mission. |
| Target priorities | Registered threats prioritize airborne WEST jets, then attack helicopters, transport helicopters, eligible surface vehicles, and finally native AI behavior. Weapon, sensor and lock requirements still apply; see controller coverage below. |
| Base protection | Configurable target exclusion around the spawn base, defaulting to 2 km, with an owner-local firing fail-safe. It does not remove missiles already in flight when their targets enter the area. |
| Mobile AA reinforcements | At or above the population threshold, Tigris and Nyx AA selection weights default to twice their original values. Wave timing and unit caps stay unchanged. |
| Placement | Enhanced batteries use a terrain search around the current AO, initially 1.2-3.5 km away, with a hard minimum base clearance defaulting to 5 km. Placement is deferred if no valid site is found. |
| Independent scheduler | Enhanced Priority AA is removed from ordinary side-mission rotation and runs on a configurable, random 10-30 minute interval between successful spawns. Ordinary side missions can run alongside it. |
| New-AO option | A configurable request on each new Classic AO is implemented and defaults off. An unfinished AA mission remains active; only the latest pending AO is retained. |
| Population guard | Below 40 humans, Priority AA retains the original Tigris objective, locations, ordinary rotation/cadence and reinforcement weights. At 40 or more, the enhanced behavior applies. Active missions finish normally when population crosses the threshold. Targeting and base protection apply in both modes to registered threats. |
| Mission wording | AA briefings and pilot guidance now advise aircraft to use terrain to hide from enemy radar, replacing warnings against air transport or flying near objectives. |
| Radar-sharing audit | Native tests confirmed actual Rhea launches using Tigris and Nyx Recon contacts without a Cronus. Tested jets can supply contacts with reporting enabled; UAV/Kajman fast-jet trials did not establish usable sharing. Ordinary CAS reporting settings remain unchanged. |

The dedicated mission retains the familiar tasks, map markers, notifications, extraction and rewards, with separate state and staff controls. Only one Priority AA mission can be active across both population modes. An elapsed timer waits while an existing AA mission remains active.

Server settings can be overridden in `@Apex_cfg\parameters.sqf`. See [Priority AA and air-defense configuration](docs/priority-aa.md) for every setting and [Rhea contact-sharing findings](docs/air-defense-datalink.md) for sensor conditions and evidence.

## Targeting coverage

The controller covers AO/static Priority AA, enemy CAS/Defend jets, normal/Defend reinforcement AA, EAST side-mission guards, FIA HQ mobile Tigrises and the legacy Independent side-mission mobile Tigrises.

`fn_smEnemyGuer.sqf` and `fn_smEnemyInd.sqf` now register each mobile Tigris immediately after its AI crew is created, so both receive owner-local targeting and the base-targeting fail-safe. The Independent route has no direct production caller today, but remains covered against future reactivation by the focused static registration check.

## Phase 3: Roles and remaining systems

Phase 3 adds the remaining player-facing systems without changing Phase 2 AA ownership or Phase 1's Taru delivery modes.

| Area | Implemented behavior |
| --- | --- |
| Support roles | Forward Observer, JTAC, and Mortar Gunner receive role-aware support menus. Forward Observers and JTACs request bounded virtual fire from separate server-side stocks; Mortar Gunners manage a role-owned mortar section. Support stock refreshes for each Primary and Defense. |
| Solo support protection | The existing ground-target priority remains in force. A JTAC, Forward Observer, or Mortar Gunner is exempt from stalking only while no other player is within 500 m. |
| Radio and staff | Shared Side and staff General channels are optional and default off through `QS_missionConfig_sharedRadioChannels`. When enabled, access is recalculated for staff and stale membership is removed across role changes, respawns, reconnects, and old bodies. |
| Revive and Kavala | Normal bleed-out is five minutes. Support roles use ordinary incapacitation even if an old pilot trait remains. Kavala keeps its dedicated revive state for the duration of the custom mission, restores normal state when it stops, and uses bounded cleanup rather than a stranded worker. |
| Entity state | Building mapper snapshots include valid direction/up vectors and clients restore them, so rotated mapped houses retain their intended orientation. |
| Ordinary helicopter inserts | The ordinary helicopter path receives lifecycle and cleanup follow-up. The dedicated Phase 1 Taru modes remain a separate early path and continue to own Primary/Defense Taru delivery. |

### Deliberate Phase 3 exclusions

This phase does **not** import `QS_fnc_combatAir`, any `QS_combatAir_*` behavior, Jolly's enemy-CAS changes, or Jolly's `AIXMissileCountermeasure` changes. It adds no AA or jet target-selection logic. Phase 2 remains the owner of Priority AA, its air-defense controller, and PR #55's deployable AA containers; the Phase 3 scope guard verifies those source boundaries.

## Validation

Run the Phase 3 static boundary guard from the repository root:

```powershell
python Apex_framework.terrain/tests/phase-3/validate_scope.py
```

It compares the current worktree with `stage/phase2-aa-turrets-20260912`, rejects forbidden Combat Air/enemy-CAS/missile-countermeasure changes, protects the Phase 2 AA controller and deployable-container files, and exactly compares the Phase 1 Taru integration block. It requires only Python's standard library and Git.

The Phase 2 rebase native Arma 3 2.22 regression passed **285 assertions with zero failures and zero script errors**, including actual server/headless-client ownership transfers and radar-guided Rhea firing. Evidence is in `artifacts/20260912-181551-575/`. Native mission-configuration validation and existing structural checks also passed. See the [native test runner and coverage](Apex_framework.terrain/tests/priority-aa/README.md).

The optional datalink surveys are separate from that regression. Their findings include bounded negative results and a preserved native Nyx MFD error, documented in the [datalink audit](docs/air-defense-datalink.md).

The Phase 2 regression is retained as evidence for the unchanged AA controller. Before Phase 3 merges, capture engine evidence for Support-role requests and stock refresh, radio membership across respawn/reconnect, Kavala start/stop/revive cleanup, rotated mapped buildings, and both ordinary and Taru helicopter delivery paths. Graphical multiplayer acceptance with production mods, opposed air combat, player-facing task presentation, and live-server load remain untested.
