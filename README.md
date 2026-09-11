# 420th Delta Classic Invade & Annex

Mission file for the 420th Delta Classic Invade & Annex server.

## Priority AA changes

This branch adds a CSAT SAM battery and independent Priority AA scheduling, based on remote main `a0a58e1`. The enhanced mission and reinforcement balance activate at **40 human players** by default; headless clients do not count.

| Change | Implemented behavior and defaults |
| --- | --- |
| SAM battery | One S-750 Rhea launcher and one Cronus radar inside the compound, with two more Rheas randomly placed outside the walls. The exterior launcher count is configurable from 0 to 2. |
| Guards | Two mobile Tigrises, one Varsuk tank, and the usual infantry count distribution: 24-48 Vipers. Vehicle crews use Viper equipment. |
| Ammunition and completion | All Rhea launchers replenish their missiles indefinitely while the objective is active, after a 15-30 second resupply delay. Destroy the radar and every Rhea to complete the mission. |
| Target priorities | Registered threats prioritize airborne WEST jets, then attack helicopters, transport helicopters, eligible surface vehicles, and finally native AI behavior. Weapon, sensor and lock requirements still apply; see the coverage gap below. |
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

## Known targeting coverage gap

The controller covers AO/static Priority AA, enemy CAS/Defend jets, normal/Defend reinforcement AA and EAST side-mission guards. This meets the requested minimum targeting coverage, but does **not** cover every ground-AA spawn path.

The FIA HQ side mission's mobile Tigris guards, created by `fn_smEnemyGuer.sqf`, bypass registration and retain standard targeting. `fn_smEnemyInd.sqf` has the same omission, although the audit found no direct production caller. These vehicles also lack the controller's base-targeting fail-safe. This gap remains in the branch.

## Validation

The combined native Arma 3 2.22 regression passed **251 assertions with zero failures and zero script errors**, including actual server/headless-client ownership transfers and radar-guided Rhea firing. Native mission-configuration validation and existing structural checks also passed. See the [native test runner and coverage](Apex_framework.terrain/tests/priority-aa/README.md).

The optional datalink surveys are separate from that regression. Their findings include bounded negative results and a preserved native Nyx MFD error, documented in the [datalink audit](docs/air-defense-datalink.md).

Graphical multiplayer acceptance with production mods, opposed air combat, player-facing task presentation and live-server load remain untested.
