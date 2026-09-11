# Priority AA and air defense

Priority AA switches behavior at a configurable population threshold, defaulting to **40 human players**. Headless clients do not count. Below the threshold, it uses the original Tigris objective, original locations, ordinary side mission rotation/cadence and original reinforcement weights. At or above the threshold, it uses the new SAM battery and independent scheduler described below. A threshold of 0 always enables the new behavior. Target priorities and base targeting protection apply in both population modes.

At or above the threshold, Priority AA runs independently of ordinary side missions and is removed from their rotation. Its default interval is a uniformly random 10-30 minutes between successful spawns. The first timer starts once the mission is ready and has a valid Classic AO. Only one AA battery can be active: if its timer expires while it is still active, the next battery waits for completion or abort. A failed placement retries after 60 seconds without starting a new successful-spawn interval. Active missions finish normally when population crosses the threshold, and old/new AA missions cannot overlap. Returning to the higher-population mode starts a fresh timer; in new-AO mode it waits for the next AO event. Pending AO requests from the previous population mode are discarded.

Ordinary missions keep their existing cadence and can run alongside the new AA battery. That battery has its own task, map markers, completion/abort state and evacuation position, while using the familiar briefing, notifications, extraction and reward flow. Rewards are serialized to protect the existing shared reward pool when two missions finish together. Staff can force, pause, resume or abort AA through the existing side mission controls; low-population AA uses the ordinary mission channel.

## Battery and placement

The compound contains one CSAT S-750 Rhea (`O_SAM_System_04_F`) and one Cronus radar (`O_Radar_System_02_F`), with two more Rhea launchers outside the walls by default. These classes are intentional and bypass faction vehicle remapping. The radar transmits contacts and launchers receive them through native datalink. Each launcher replenishes its ammunition after depletion, with the existing approximate 15-30 second reload delay, indefinitely while the objective is active.

Guards include two mobile Tigrises and one Varsuk tank. Foot guards retain the normal patrol/sniper/garrison count distribution: 24-48 Vipers in total. Vehicle crews also receive Viper equipment. The mobile guards retain drivers and normal patrol handling. The compound has a vehicle-width entrance. Destroy the radar and every spawned Rhea to complete the objective; guard vehicles are not completion requirements.

Both AA briefings and pilot guidance recommend using terrain to hide aircraft from enemy radar. The previous warnings against air transport and flying near objectives have been replaced, including the AA briefing's Chinese translations.

Placement uses a bounded terrain search around the captured AO position rather than the old AA position list. Defaults search 1.2-3.5 km from the AO, expanding the maximum to 5 km late in the search if necessary. The minimum base distance remains a hard constraint. The compound, satellite launchers and mobile vehicle positions must all be valid before construction starts. Checks cover water, slopes, roads, occupied terrain, nearby players, the FOB and map bounds. An invalid site is deferred instead of falling back near base. The objective circle includes the exterior launchers.

The default 5 km base clearance is intended for Altis. Small terrains or coastal AOs may need adjusted distances; an overly restrictive configuration will postpone AA rather than place it in an unsafe fallback location.

## Target selection and base exclusion

Registered mission-spawned static/mobile ground AA and enemy combat jets use this order for occupied WEST vehicles:

1. Airborne fixed-wing combat jets.
2. Airborne attack helicopters, including helicopters with offensive pylons or pilot weapons.
3. Airborne transport helicopters; door guns alone do not promote a transport.
4. Surface vehicles, including aircraft on the ground, where the weapon supports them.
5. Native AI behavior when no eligible priority target remains.

The owner of the vehicle runs the controller. Registration and saved AI state follow server/headless-client ownership changes. Player or remotely controlled crews are released from the override. The controller uses current sensor/datalink contacts for SAMs and fresh known contacts for other threats. It checks available ammunition, weapon compatibility and range; native acquisition and missile-lock requirements still apply. A Rhea is not ordered to attack ground vehicles. Same-tier targets have a small retention preference to reduce switching, while a higher tier preempts the current target. Registered enemy jets also cancel conflicting scripted ground attack activity when an air target takes priority.

Targets within 2 km of `QS_marker_base_marker` are excluded by default. If only protected contacts remain, the controlled crew holds fire. An owner-local firing guard also removes newly fired offensive projectiles aimed at a protected target or conflicting with the current override. A missing base marker fails closed. This is a targeting fail-safe, not a shield: it does not remove a missile already in flight when its target later enters the area, and it does not control unregistered threats or human firing.

Hooks cover AO AA creation, the Priority AA battery, vehicle setup, normal and Defend reinforcement paths, and enemy CAS/Defend jets. Static radar vehicles provide sensors; they do not receive a weapon-targeting loop. No new remote-execution endpoint is added.

Coverage does not include every ground-AA spawn path. The FIA HQ side mission calls `fn_smEnemyGuer.sqf`, whose mobile Tigris guards bypass registration and retain standard targeting without the controller's base protection. `fn_smEnemyInd.sqf` has the same omission, although the audit found no direct production caller. The requested minimum of AO/static Priority AA and enemy jets is covered; these mobile guard gaps remain.

The Rhea can also use other vehicles' contacts. The [native datalink audit](air-defense-datalink.md) covers working transmitters, reporting settings, crew sides and sensor limits.

At or above the population threshold, mobile Tigris and Nyx AA weights in reinforcement selection default to twice their former values. Below it, the original pool is used unchanged. Other weights, wave timing and unit caps stay as configured. Doubling a weight increases its share of a weighted draw; it does not guarantee twice as many vehicles per hour. A class with an original zero weight remains disabled.

## Server settings

Set these mission variables in the server's existing `@Apex_cfg\parameters.sqf`. Defaults live in `Apex_framework.terrain/code/config/airDefense.sqf` and are validated and broadcast after the external parameters load. Distances are metres and intervals are seconds.

| Variable | Default | Purpose |
| --- | --- | --- |
| `QS_missionConfig_priorityAA_enabled` | `TRUE` | Enable future AA spawns in both population modes. |
| `QS_missionConfig_priorityAA_minPlayers` | `40` | Human-player threshold for the new mission, scheduler and increased reinforcement weights; 0 always uses the new behavior. |
| `QS_missionConfig_priorityAA_onNewAO` | `FALSE` | Replace the timer policy with a request on each new Classic AO. |
| `QS_missionConfig_priorityAA_interval` | `[600,1800]` | Minimum/maximum random time between successful spawns. |
| `QS_missionConfig_priorityAA_aoDistance` | `[1200,3500]` | Initial search ring around the AO. Late fallback expands the maximum to at least 5000. |
| `QS_missionConfig_priorityAA_baseDistance` | `5000` | Minimum placement clearance from base; footprint checks add clearance. |
| `QS_missionConfig_priorityAA_satelliteCount` | `2` | Number of exterior launchers, from 0 to 2. |
| `QS_missionConfig_priorityAA_satelliteDistance` | `[50,200]` | Exterior launcher search distance from the compound. |
| `QS_missionConfig_airDefense_enabled` | `TRUE` | Enable targeting override and its firing fail-safe. |
| `QS_missionConfig_airDefense_baseExclusionRadius` | `2000` | Base target exclusion radius; 0 disables the area around a valid marker. |
| `QS_missionConfig_airDefense_interval` | `3` | Controller tick interval, constrained to 1-30 seconds. |
| `QS_missionConfig_airDefense_reinforcementWeight` | `2` | Tigris/Nyx reinforcement weight multiplier, from 0 to 10. |

Example: enable one request per new AO instead of the default timer:

```sqf
QS_missionConfig_priorityAA_onNewAO = TRUE;
```

In that mode, an unfinished AA mission remains active. The scheduler retains only the most recent pending AO, then spawns for it when the channel is free. Rapid AO changes do not accumulate batteries. Changing scheduling modes clears pending requests from the previous mode. Disabling or pausing the channel stops future spawns and lets an active battery finish. Existing custom-AO side-mission blocking and AI-cap gates also postpone AA creation.

For live edits, change the variables on the server and run `[] call QS_fnc_airDefenseInit` there to validate and broadcast them. Invalid types fall back to defaults; numeric values are constrained to supported bounds. Existing batteries retain their composition and placement. Controller settings apply on subsequent ticks, and interval edits affect the next interval draw.

## Validation

The native test fixture and runner are documented in [tests/priority-aa/README.md](../Apex_framework.terrain/tests/priority-aa/README.md). They stage exact source into an isolated vanilla Altis mission, retain source hashes and RPT evidence, and remove the temporary installed mission afterward. The fixture covers configuration, target ordering/capability, base exclusion, independent scheduling and tasks, battery construction/guards/reloads/cleanup, real radar-guided firing and optional actual headless-client ownership transfer.

The live sensor case uses an invulnerable WEST jet flying a controlled AI loiter orbit, with real Cronus detection, native data link and actual Rhea missile launches. It does not inject contacts or simulate the firing event. The battery refill case drains only the actual SAM magazine while leaving the UAV's `FakeWeapon` magazine loaded, and checks another depletion/refill cycle.

Final combined native validation on 2026-09-11: **251 assertions passed, zero failures and zero script errors**, including an actual headless client. Evidence: `tests/priority-aa/artifacts/20260911-160324-900/`. All 42 changed production SQF files match that run's SHA-256 manifest. Native `CfgConvert -test` accepted `description.ext`; the existing structural checks passed and localization XML parsed with unique keys.

These checks do not replace a graphical multiplayer acceptance session with the production mod set. In particular, moving jet-versus-jet combat, player/Zeus takeover, player-facing task presentation, terrain variety and production server load still require that environment.
