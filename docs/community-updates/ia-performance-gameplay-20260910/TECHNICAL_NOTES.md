# Invade & Annex — complete performance and gameplay reference

**Contributor-feedback update · 11 September 2026:** current source uses a 300-second normal bleed-out and keeps the proposed shared Side/staff General policy behind the startup-only `QS_missionConfig_sharedRadioChannels` gate, default `FALSE`. The detailed radio design below describes the retained opt-in path. Disabled mode allocates no extra channel and preserves the served native Side, private Staff and optional General behavior.

This document covers the **net changes from the initial supplied live mission to `IA_PerformanceGameplayUpdate`**: 55 edited files and four added files. It describes every delivered change and the current settings of the combined release. The original live code remains commented beside replacements in the edited files.

The sections are grouped around behaviors that should be tested together. File names below are relative to the mission root; unqualified function names are in `code/functions/`. The full file-by-file mapping and test scenarios are in the Files and testing section of `RELEASE_NOTES.md`. Several features share complete runtime files: the 46-file Gameplay bundle is the common dependency for sections 1–8 and the background cleanup in section 10. The seven supplied Radio files plus the corrective staff-mask GUI companion, two BLUFOR speech files, one vehicle-handler fix and three shared performance helpers have independent test boundaries, followed by combined acceptance. The original supplied inventory remains 59 files; remediation adds changed paths outside that payload.

These are source-defined rules and limits. Existing offline verification checks logic and source preservation; flight, navigation, multiplayer behavior, mod compatibility and actual performance still need dedicated-server acceptance. No new live benchmark is claimed by this documentation revision.

## Population and distance definitions

These counts serve different purposes and should not be combined during testing.

| Rule | Population or proximity used |
|---|---|
| Primary infantry strength, replacement vehicles and regular pacing | Living, conscious, non-captive WEST real players on the ground within AO radius +600 m; ground vehicle crews count, aircraft occupants do not |
| Automatic Taru preference and flight limit | Connected real humans, all sides; headless clients excluded; boundary is 20 |
| Initial Primary coordinated-artillery allowance | Connected WEST real humans, including pilots and players at base; chosen once at AO initialization |
| Primary casualty response population | Nearby ground humans including downed players; dispatch also needs more than eight conscious nearby ground players |
| Forward Observer ammunition scaling | Connected real humans, excluding headless clients, when stock is issued |
| JTAC ammunition | Equal stock per authorized slot, including vacant slots; no low-population reduction |
| Isolated Support infantry | No other living real player within 500 m horizontally; unconscious players and vehicle occupants count as company, AI and headless clients do not |
| Support fire exclusion | At least 175 m plus selected dispersion from every living human, including downed people and vehicle/aircraft occupants |
| Mortar equipment ownership | Equipment retires beyond 500 m from its owner; this is separate from stalking and fire-exclusion rules |
| Unattended logistics cleanup | Five continuous minutes without a living human ground player within 1 km of the root or linked equipment |

## 1. Primary reinforcement and objective progression

**Files together:** `fn_AI.sqf`, `fn_aoEnemy.sqf`, `fn_aoSubObjectives.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_AIFireMission.sqf`, `fn_spawnGroup.sqf`, `fn_aoEnemyReinforceVehicles.sqf`, `fn_scSpawnHeli.sqf`, plus the aircraft and insertion files in sections 4–5. The shared activity controller also starts and closes player Support stock.

The initial live mission checked infantry and vehicle reinforcements at random 20–40-second intervals through its native Classic loop. Infantry admission required fewer than 85 nearby hostiles and room in a separate surviving-replacement limit; vehicles used a 75-hostile threshold and their own limit. Radio Tower loss also advanced the old reinforcement counters. The update replaces that automatic admission path for Classic Altis with ground-population tiers, a shared personnel budget and reductions tied to every actual strategic objective. Initial enemy quantities remain unchanged.

### Reinforcement settings

Living, conscious WEST ground players within the AO plus 600 m select the tier. Aircraft occupants and headless clients do not count; ground vehicle crews do.

| Ground players | Preferred squad | Opportunity interval | Reinforcement ceiling before objectives | Inner HQ / other-objective target | Replacement vehicle limit |
|---|---:|---:|---:|---:|---:|
| 1–2 | 8 | 8–10 min | 24 | 8 / 8 | 0 |
| 3–8 | 8 | 8–10 min | 40 | 12 / 8 | 0 |
| 9–15 | 8 | 2–3 min | 64 | 20 / 12 | 1 |
| 16–30 | 10 | 30–60 s | 96 | 32 / 20 | 2 |
| 31+ | 12 | 6–10 s | 120 | 40 / 24 | 3 |

The busiest tier uses the same scheduled 6–10-second infantry refill check as the supplied Defense script. Defense checks its own infantry roster against a separate population cap; Primary still counts its combined force and reservations. Primary can therefore wait even when Defense would accept another group. One creation worker, the 24-parachutist monitor cap and normal travel time also limit actual arrival cadence. The settings target sustained busy-population pressure; matching refill intervals does not prove equal contact intensity.

- **No per-AO regular-delivery quota.** Reinforcements remain eligible while objectives remain. The interval starts from the delivery attempt; it is not a guaranteed touchdown time. A blocked objective, full cap or unhealthy FPS can delay an arrival.
- Regular deliveries contain 8–12 men in one group. Fewer than eight available places means wait. A smaller full squad retains the tier's full interval.
- Capacity counts unique hostile personnel in the AO plus 500 m, registered Primary personnel outside it, and assigned CAS crews. Infantry, armor crews, mortar gunners, UAV crew, transport pilots and inbound cargo all consume places. Empty hulls, wrecks and props do not count as additional people.
- Reserved places count before creation. Native aircraft reserve four places and release unused places after their spawner returns. The tightest force, server-local and global limit wins; the existing local limit is 140 on Altis and the hostile global ceiling is 200.
- Initial forces are not deleted or increased to meet a ceiling. Creation waits for sufficient losses. This is a reinforcement admission ceiling, not a clamp on mission setup or manual spawns.
- First regular admission waits at least the tier's minimum interval after ground contact. All tiers also require 30 seconds after initialization and FPS recovery. New reinforcement admissions pause below 18 FPS and resume only after 30 continuous seconds at 22 FPS or higher; existing units keep fighting.
- With no conscious ground players, arrivals pause and the next opportunity moves ahead by the previous tier's minimum interval. A drop into a slower tier grants that tier's minimum breathing room. There is no catch-up queue, wipe failure or AO duration cutoff.
- `waveNumber` records constructed regular squads and selects the delivery mix; it never closes the normal stream. Objective completion, live capacity and FPS determine eligibility.
- The controller supplies regular squads. Native automatic Classic Viper top-ups are bypassed while it runs; existing specialists remain.

At 22 connected players with 4–6 on the ground, including armor crews, the 3–8 tier applies: eight-man opportunities every 8–10 minutes, a 40-person ceiling before objective reductions and no new local armor replacements. Pilots elsewhere and players at base do not raise that tier. Objectives progressively reduce the room available for later squads.

Taru insertions are automatic Gameplay behavior in Primary and Defense. Connected human players, excluding headless clients, choose the method:

| Connected players | Normal infantry delivery |
|---|---|
| 1–19 | 90% Taru preference when a flight can be admitted. Wait through the flight cooldown/cap instead of filling that interval with ground spawns. |
| 20+ | At most 12.5% by admitted infantry: seven squads’ worth of ordinary arrivals fund one Taru squad. |

The high-population counter resets after each lift and whenever the population crosses 20; blocked flights cannot bank consecutive catch-up lifts. Destroyed aircraft still spend the allowance. Low-population flights already underway may finish after the server crosses 20, but they cannot fund new high-population lifts.

At low population, allow up to three concurrent flight jobs with at least 45 seconds between launches; at 20+, allow one with a four-minute cooldown. Flight jobs include approach, release, landing monitoring and departure. Capacity, terrain and FPS may reduce the actual transport share. Nearby ground turnout still controls Primary strength and pacing. Existing full squads, passengers and pilots consume the existing personnel allowances; no extra cargo is created in flight. Primary preserves its reservation and objective gates. Defense admits the selected native squad plus its pilot only when both fit its existing infantry cap.

Each Taru carries one admitted squad. Most request a moving parachute pass at 180–220 m; 10% request a 25 m rappel when terrain and the shared helper permit. Primary ground/parachute fallback and Defense’s existing scripted HQ paradrops remain. Taru arrivals draw from the normal reinforcement budget.

### Objective progress

At busy population, each completed objective removes 24 places from the 120-person ceiling: 120 → 96 → 72 → 48 → 24. The final objective sets normal admissions to zero; the separate bounded final-reserve channel is described below. A four-objective AO therefore uses 120 → 96 → 72 → 48 → 0. Intervals do not stretch as objectives fall.

Snapshot actual objectives: HQ commander, Radio Tower, optional Jammer, the spawned Datalink or Supply Depot, and the present Mortar Pit. The supplied Altis generator does not create a separate Vehicle Depot; its conditional gate applies only if that objective is supplied. Commander death or capture completes HQ's contribution. A pit is neutralized when no registered mortar has a living hostile gunner. The pit gets a search-area marker so it cannot become an unmarked required objective.

Supply loss changes future infantry classes and removes any launcher added by mapped loadout setup to those new soldiers. Existing live depot-capture effects remain. Existing aircraft and launcher rearm behavior remains; Supply loss changes future infantry equipment rather than adding a rearm cutoff. Datalink/Vehicle Depot loss also blocks future UAV/local armor replacements, respectively. Rare regional armor is a separate final-phase exception, not a reopened depot stream.

### Original objective notifications

Objective transitions and clearance retain the initial live mission's notification paths, localization and task updates. The new controller does not add objective-effect announcements, a remaining-objective chat list, an artillery-exhausted notice, a rally instruction or a replacement AO-secure message. This leaves the reinforcement, objective, artillery, rally and clearance rules above intact. Native Commander, Radio Tower, task-success and activity messages continue through their original event paths.

### Final regional reserves

The old low-enemy fallback becomes an objective-driven final phase. Normal reinforcements stop with the last strategic objective, surviving registered forces rally to HQ, and completion remains sensitive to fresh ground enemies and incoming troops.

Normal replenishment, new UAVs and coordinated artillery stop with the final strategic objective. On that transition, set one deadline 90–150 seconds ahead. A later eligible check consumes a 15% roll and schedules a new deadline; there is no catch-up queue. At most three reserve admissions are spent in total, including a placement attempt that subsequently fails. Infantry is eight soldiers; at most one armor and one rotary admission. The native rotary spawner's entry search is bounded to 24 candidates.

Reserve admission requires more than 15 conscious nearby ground players, rechecked by the creation worker. At 15 or fewer, the HQ rally still occurs but no final infantry, armor or rotary reserve is admitted. The shared personnel ceiling for eligible tiers is floor(20% of the current ground-player tier): 19 at 16–30, 24 at 31+. Existing personnel and reservations count, including aircraft crew. Native infantry/vehicle toggles, local/global limits and the existing FPS recovery gate remain. Armor requires the vehicle toggle/tier; rotary also requires no living helicopter crew in the counted force. Supply loss still strips new launchers. Regional armor is the explicit exception to the completed local Vehicle Depot's replacement cutoff.

Reserve selection uses at most twelve recent reports inside the AO. Eligible survivors move toward an observed contact with an infantry/armor standoff, then fall back toward HQ when reports expire. HVT/Medevac guards remain exempt. Clearance beginning, or a fresh worker check finding fewer than ten established ground hostiles, latches `finalClosed` for the rest of that AO. Pending/failed rolls do not count as incoming troops or restart the clear timer.

### Clearance and testing boundaries

The original ENEMYPOP result could remain complete after its first low-count check. The updated `fn_aoSubObjectives.sqf` reevaluates it and uses the fresh result in the same pass. Completion requires all strategic objectives, no incoming delivery and fewer than ten eligible ground hostiles for 15 continuous seconds. A failed check resets that interval. Registered approaching ground troops and nearby hostile guards count; captive/friendly patients and aircraft do not create a mandatory air-to-air cleanup task.

Primary remains objective based, with no wipe failure or total AO time limit. Tests cover each ground tier, a wipe and return, partial capacity, objective order, Commander capture or Zeus-controlled death, Mortar Pit discovery, incoming versus outgoing flights and successive AO transitions.

## 2. Primary contacts, ground-asset priority and casualty response

**Files together:** `fn_AI.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_aoEnemy.sqf`, `fn_aoDefend.sqf` and `fn_AIFireMission.sqf`, with the shared spawn and movement dependencies. Defense uses the same asset ranking but its own response limits in section 4.

### Primary contact response and objective fallback

The player flow is an advance through defended objectives. CAS can remove the opening force; full reinforcement squads replace losses within the shared cap and population-selected interval, through the population-selected delivery method. Each objective lowers that cap, so arrivals diminish as resistance is cleared. Existing survivors are never deleted to enforce a lower cap. Objectives do not shorten or restart the opportunity interval; fewer available force slots preserve progress.

Dedicated HQ/pit/static-tower guards are tagged in the native AO spawner. Depot/datalink guards use their composition membership. Building garrisons use the existing garrison flag and are associated with an objective. A guard stays until that objective falls, then moves to another surviving objective and remains excluded from hunting. No proximity sweep recruits HVT, Medevac or unrelated mission groups. On the final objective, registered main-AO groups regroup around HQ; native mission notifications remain. HVT/Medevac tasks remain separate; their nearby hostile guards still count toward clearance.

| Rule | Setting |
|---|---|
| Eligible mobile pool | Registered current-Primary infantry groups, at most 12 living members; no dedicated guards, all-sniper teams, crew/cargo, exempt or unrelated units |
| Allocation | With more than eight conscious ground players, whole squads: roughly 60% contact pressure, 20% hunters/casualty response, at least 20% defense/patrol; 10 eligible groups give 6/2/2. At 1–8, at most one contact squad across the AO, zero hunters, and at least one eligible group stays in reserve |
| Dispatched squad | At least eight living, conscious regular infantry; Viper groups may have 6–9. No group splitting or additional creation |
| Patrol retention | Some initial native patrol groups retain their existing route, report contacts and remain unavailable for borrowing |
| First trigger | An actual registered AI report; players merely entering the AO do not activate the contact response |
| Intel | Up to three targets per leader per ten seconds; reports at most 45 seconds old at admission, knowledge at least 1.5. Reporting requires an observation within 30 seconds and position error at most 75 m |
| Clusters | At least three known targets within 120 m of a fixed reported position. At most 64 records and six candidate sectors; no chaining distant players into one cluster |
| Local commitments | Within a 350 m response sector: at most two advancing squads and one supporting squad. Ordinary isolated infantry can receive one hunter when the allocation permits; AA/artillery use ADVANCE. Casualty responses share these commitments. At eight or fewer conscious ground players, the AO permits at most one contact response and each sector permits only one cumulative contact dispatch until its existing cooldown expires |
| Dispatch spacing | One contact/casualty dispatch every 20–40 seconds, checked on ten-second passes; no catch-up burst |
| Travel | Existing squad within 1,100 m of the report; terrain/water checks, different approach angles, 150 m movement legs, 20–30 s group-order refreshes, or 40–50 s under load |
| Final contact positions | Advancing/hunting anchors 45–75 m from the report; support anchors 150–180 m away; 60 m minimum between accepted squad posts, dispersed individual slots |
| Mounted targets | Require a squad with a loaded ground-attack launcher; AA-only ammunition does not qualify |
| Activity boundary | Report within 1,800–2,200 m of AO center, depending on AO radius; outside base 1 km and side-task 600 m exclusions |
| Incident lifetime | Up to 300 seconds including travel; 75 seconds without a fresh local report ends it sooner. Destinations and original deadlines stay fixed |
| Reuse | Retain the sector record until 420 seconds after admission: at least two minutes after normal pursuit expiry. Destroyed/returned squads do not refund its spent allowance |
| Performance | Existing TICK and server/HC group handlers; no new scheduled loop. New responses require the existing FPS recovery gate and at least 18 FPS |

These percentages are maximum allocations, not compulsory assignments. The smaller-force limits override them at eight or fewer conscious ground players. Missing contacts, guard exclusions, squad losses, terrain or a full local commitment limit leave squads in defense. The shared personnel cap does not rise when a squad changes role: its home objective remains its reinforcement-accounting assignment.

Only the owning server/HC issues movement. Reports use the engine's target knowledge position; no scripted reveal or live-player position supplies pursuit goals. The controller releases old holds using doFollow, enables native targeting, and uses existing movement orders. Navigation and combat can still alter actual spacing and travel time.

### Known BLUFOR ground-target priority

Primary contact pursuits, Defense flank assignments and enemy artillery/mortar/CAS/UAV support requests use this order among eligible known BLUFOR ground targets:

| Priority | Target |
|---|---|
| 1 | Anti-air assets |
| 2 | Artillery, excluding mortars |
| 3 | Tanks |
| 4 | Other mechanized and motorized assets |
| 5 | Infantry |

Human and AI crews are eligible. Mortars are excluded from these deliberate pursuit and support-request selections. The priority is applied within existing observation, range, weapon suitability, squad, cooldown and fire-budget limits. Queued support requests recheck target eligibility before execution. The policy does not add force or fire-support allowances, reveal unknown assets, or force native gunners to obey a global target list. Ordinary native sensing, firing and close combat remain active. Air-to-air selection retains its separate combat-aircraft/transport weighting.

Primary AA/artillery contacts can use the existing `ADVANCE` allocation even at eight or fewer conscious ground players. The single-contact-response cap still applies and no hunters are added at that turnout. At the normal **20–40-second dispatch cadence**, one suitable existing lower-priority contact squad may transfer to a higher-priority incident. This reuses the same group and home-return assignment within existing quotas; previous incident commitments are not refunded and no catch-up force is created.

Defense can transfer one existing lower-priority flank squad to a higher-priority position on its normal **15-second** pass. The new position must meet the existing **45-second dwell**, fresh-sighting, full-squad and suitable anti-tank weapon checks. The old job is removed and released before the same group receives its replacement assignment, so the simultaneous-squad quota does not increase. The replacement starts its normal **300-second** lifetime; jobs that are not transferred keep their existing deadlines.

### Isolated Support roles and scripted stalking

Primary contact pursuits and Defense flank assignments exclude isolated **JTAC, Forward Observer or Mortar Gunner infantry**. This covers the mission roles `jtac`, `jtac_WL`, `forward_observer` and `mortar_gunner`. Isolation means no **other living real player within 500 m horizontal distance**, inclusive of the boundary. Incapacitated players and vehicle occupants count as company; AI, headless clients and dead players do not. The exemption applies to the infantry target, not an AA, artillery, tank or other vehicle that player operates.

Primary applies the rule to `HUNT` and to `ADVANCE`/`SUPPORT` contact jobs whose remaining targets become isolated Support players. Existing jobs recheck eligibility on the normal Primary **10-second** and Defense **15-second** passes. Protected targets drop out of those jobs; when no eligible target remains, the borrowed squad returns to its ordinary assignment. A mixed job may continue against its other eligible targets.

The exclusion changes scripted pursuit eligibility. Ordinary AI sensing, targeting and fire, enemy support requests, defensive reserve behavior, final HQ combat and casualty-area `CONTEST` responses retain their eligibility rules. Isolated Support infantry can still be selected last by the ranked enemy support-request picker.

### Casualty-area response

The existing revive script sets incapacitated players unconscious and enables Arma’s internal `captive` targeting flag. This is targeting protection, not a player-capture mechanic. This update does not change that protection or order attacks on unconscious players. It uses the revive timestamp and recent shared sightings to assign resistance around the area.

| Condition | Limit |
|---|---|
| Nearby ground population, conscious plus downed | 0–8: none; 9–15: one squad; 16–30: two; 31+: three, across the entire AO. Also require more than eight conscious ground players for the shared hunter allocation |
| Casualties in one reported area | One squad for 1–2; up to two for 3–4; up to three for 5+, subject to the AO-wide cap and available 20% hunter allocation |
| Source squad | Registered current-AO RESERVE/SCREEN; at least eight living members; on foot; no exempt or dedicated-guard members; another living assigned squad remains at its objective |
| Squad distance from the report | At least 40 m and less than 350 m |
| Eligibility | Incapacitated within 45 s; reported sighting at most 60 s old, knowledge above 1.5, and no later than 2 s after the revive timestamp |
| Report sanity check | Within 75 m of the casualty when first admitted; use the reported point as the fixed focus |
| Observation pass | At most once every 10 s in the existing TICK; no new scheduler or unit creation |
| Dispatch delay | 10–20 s after admission, checked on those passes; shared contact/casualty dispatch spacing of 20–40 s, rounded up by the ten-second pass |
| Positioning | Squad posts 60/80/100 m from the report, 60 m post separation; individual slots at least 30 m from the focus |
| Lifetime | 120 s from area admission; new casualties joining within 100 m do not extend it |

Each registered Primary group leader publishes at most three recent ground sightings every ten seconds through the existing server/HC intel function. It uses target knowledge coordinates and age, never a live target position for the destination. The controller admits at most three reported areas and records each incapacitation once.

Revive, death, disconnection, carrying/dragging, loading into a vehicle, or movement more than 120 m from the original report removes a casualty from the job. Any remaining casualties determine how many squads stay. Timeout or all objectives complete ends the job. Return orders select remaining objectives, or final HQ posts if appropriate. Extraction never moves the response destination, and reloading/unloading does not reset the same incapacitation.

New dispatches obey the FPS admission gate and manual pause. HVT/Medevac guards and dedicated objective defenders are never selected. A casualty with no valid sighting or no eligible spare squad causes no dispatch. Existing squads may take losses while responding; they are not refilled by this mechanic. Each area also keeps a cumulative dispatch count: losing or returning a squad never refunds that commitment. Additional casualties may unlock a higher one-to-three-squad total within the same deadline, but clearing the responding force does not summon replacements.

Test cases pair known human- and AI-crewed AA, non-mortar artillery, tanks, APCs/MRAPs and infantry; mortars remain outside deliberate selection. The same test group covers isolated Support infantry at 499/500/501 m, a role holder operating a vehicle, loss of company during an active pursuit, target extraction, stale sightings, lost responding squads and retained HQ/side-task guards.

## 3. Enemy coordinated artillery and Primary mortars

**Files together:** `fn_AI.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf` and `fn_AIFireMission.sqf`. These complete files also implement contact ranking, aircraft support and player Support lifecycle.

### Allowance, schedule and objective reductions

Commander, Radio Tower and a spawned Datalink each subtract one-third of the **original** artillery allowance. The effective total is 3/2/1/0, 6/4/2/0 or 9/6/3/0 after zero/one/two/three command links fall. Already started missions count against that total. For example, six started out of nine plus one lost link leaves zero. A missing Datalink costs nothing; all actual strategic objectives complete always sets the total to zero.

AO initialization chooses the budget and all random windows once. Connected WEST players select the difficulty eligibility, including pilots and players at base; headless clients are excluded. Below 25: three missions only. At 25–30: 75% three missions, 25% six. Above 30: 60% three, 25% six, 15% nine. Later population changes do not reroll difficulty or move the schedule.

After a 90-second opening grace, the schedule spans 15 minutes. Divide that span into 3, 6 or 9 equal slots. Each window opens randomly 20–60% through its slot and remains open for 40% of the slot. All these times are fixed at initialization. Objective losses trim the latest unused windows to the reduced allowance; expired windows are never recreated. Admission requires more than eight conscious nearby ground players. Eight or fewer players, low FPS, no available physical provider, no target or a busy provider may cause an opportunity to be missed. These are maximum fire missions, each containing a salvo. Primary mortar salvos use the tuning below. The budget does not count individual shells or impose an AO time limit.

One server admission block rechecks objective state, reserves one opportunity and starts the existing type-0 fire-mission function. A started mission finishes its admitted salvo even if a link falls during it. Pending future missions are cancelled; fired shells are never removed. Activity cleanup stops registered Primary scripts. Ordinary CAS, aircraft fire-mission types and Defense remain outside the allowance.

Busy Primary mortar cooldowns are 75–120 seconds at 20–39 nearby ground players and 60–90 seconds at 40+; below 20 they are 360–720 seconds. Defense retains its support timing, providers and allowances while using the revised target selection. `FIRE_BUDGET`, `FIRE_PLAN` and `FIRE_LIMIT` in `fn_AI.sqf` contain the artillery policies. `fn_AIFireMission.sqf` receives an explicit epoch-and-rounds token only for admitted Primary mortar salvos; calls without that token retain their original salvo tuning.

### Primary mortar targeting

- Commander targeting accepts eligible known BLUFOR ground targets inside the AO and up to 500 m outside it; the original commander filter excluded the inner 90% of the AO radius. Ground assets use the priority order in section 2, with living, conscious, non-captive WEST infantry last. Mortars are excluded from deliberate target selection.
- At admission, validate the report or a newer shared sighting: at most 30 seconds old. Aim at the reported position with 0–10 m request error, then freeze it for the salvo. Player movement does not update the aim.
- Reject water, positions within 1,000 m of base or 600 m of the side task, targets outside the weapon range, and aim points with living EAST/RESISTANCE personnel within 75 m. Rejected requests spend neither an allowance slot nor a Primary gunner cooldown.
- At 9–19 conscious ground players: four shells. At 20+: six. Eight or fewer blocks new coordinated Primary admissions. Apply the shell count after the native concentration doubling, with a six-shell maximum. Initial scatter radius is 45 m; retain the original random tightening with a 25 m floor. Shells can still land near the center; the floor is a scatter radius, not a minimum miss distance.
- Retain native shell timing, warning effects, ammunition, physical projectiles, damage and revive rules. Default type-0 calls and Defense salvos retain their native tuning. Aircraft admission/departure changes are described below.

Testing covers low/high connected population at initialization, 8/9 and 19/20 ground-player boundaries, missing physical providers, objective losses before and during a salvo, expired windows, moving or stale targets, friendly proximity and a following Defense using its native salvo limits.

## 4. Defense and automatic insertions

**Files together:** `fn_aoDefend.sqf`, `fn_AI.sqf`, `fn_AIXHeliInsert.sqf`, `fn_AIXHeliInsertLanding.sqf`, `code/scripts/AR_AdvancedRappelling_ext.sqf`, the AI movement/covering-fire handlers and `fn_spawnGroup.sqf`. Aircraft support uses section 5. The stock reset for an admitted Defense uses section 7.

### Defense selection and flank response

The normal selection roll increases from 0.333 to 0.666. The former stop after four Defenses when over 60 players is removed; `QS_defendCount` remains a statistic. Existing force controls, 13 FPS minimum, nearby-player and 300-second uptime gates remain. No Defense wave size, artillery schedule or duration increases.

`fn_aoDefend.sqf` defines `_fn_flankTick` locally and calls it once per 15 seconds in the existing loop. No new scheduler, troops, projectiles or aircraft are created by the response.

| Setting | Value |
|---|---|
| Target band | 400–2,000 m from HQ; outside base 1,000 m and side task 600 m |
| Occupancy | 45 seconds within a fixed 75 m anchor; speed at most 15 km/h |
| Target eligibility | Conscious, non-captive WEST ground infantry and human/AI-crewed ground assets; aircraft, mortars and isolated JTAC/Forward Observer/Mortar Gunner infantry excluded |
| Battle minimum | Ten eligible human ground players within 2,500 m; four living ordinary assault groups |
| Assignment quota | `min(2, max(1, round(groups * 0.05)), groups - 3)` after battle minimum |
| Priority transfer | At most one existing lower-priority flank squad per 15-second pass; higher-priority position must meet dwell, fresh-report and squad/weapon checks; replacement uses the same squad within the same quota |
| Source squad | Existing ordinary Defense infantry roster; 8–12 alive, all local/on foot; no active scripted job or HC transfer |
| Vehicle response | At least one launcher user with carried missile/rocket ammunition capable of ground attack; AA-only ammunition does not qualify |
| Intelligence | Shared report or a local Defense observer's known position, at most 60 seconds old; observer position error at most 100 m |
| Work bound | Up to 32 observer leaders and eight mature candidate positions; one new assignment per pass; AT inventory cached for 60 seconds |
| Movement | Fixed flank bearing; up to 180 m per issued movement leg; water/base/side/leash checks |
| Stand-off | 130 m for infantry positions; 300 m for mounted targets |
| Leash / expiry | Leader remains within 2,200 m of HQ; no report for 90 seconds, target moves over 75 m, or 300-second lifetime ends assignment |
| Reuse cooldown | Ordinary release waits 120 seconds before another assignment; an admitted priority transfer replaces the same squad's job in the current pass |
| FPS | Below 18, no new assignments or movement updates; release/cleanup still runs |

Group selection borrows server-local squads and temporarily excludes them from HC transfer. The normal group handler and Defense propulsion modes 1–4 skip borrowed groups. Native explicit waypoint propulsion mode 5 receives no flank assignments, preserving its waypoint ownership. A group already in HC transfer or controlled elsewhere is not commandeered.

Reports provide destinations. Current target coordinates are used only to determine sustained occupancy, movement and eligibility; no global reveal or direct position tracking steers the squad. A fixed approach bearing avoids continually circling the target. Native navigation and combat decide whether a squad reaches a firing position.

Release clears the Defense tag, restores attack/combat/HC and regroup settings, and sends local survivors back toward HQ. Targeting stays enabled after contact, consistent with Defense's existing hit/fired-near activation. The epoch and active flag invalidate old assignments before native cleanup starts. Wave counts, duration, vehicle replacement and artillery timing, providers and allowances remain; deliberate target selection uses the revised priority. Outdoor infantry now receive the validated spread described below.

### Bonus: manual 30-minute Defense

**Files together:** `code/scripts/IA_MegaDefense.sqf`, `fn_core.sqf` and `fn_aoDefend.sqf`. All three files remain in their regular mission folders. The script is available for explicit Zeus/Admin server execution or later invocation by an owner-provided scheduler. The mission never calls the launcher automatically. Only its START operation raises `QS_megaDefense_pending`; the native controller observes that explicit request. No startup invocation, reset trigger or recurring worker activates the special event. The executable command and request/status usage are in `RELEASE_NOTES.md`.

The script requests a forced transition through the current Classic mission controller. It bypasses the Primary grace period and objective-completion requirement, and the native AO flag that normally permits or declines Defense. Core remains the owner of the Defense script handle and HQ cleanup. A forced transition retires existing Primary tasks, stops further Primary admissions/fire and closes its Support allowance. It omits normal completion statistics and the CompletedMain announcement for the unfinished AO. The radio tower is collected without triggering its destruction credit. Existing native cleanup still owns the Primary roster; the special mode does not run a second independent Defense beside it.

Core publishes `QS_megaDefense_core` as phase, activity epoch and HQ position. The trigger pins `QS_megaDefense_targetEpoch` to that prepared activity. The pending request intentionally survives the shutdown of that same Primary so its Defense can consume it, but it cannot carry across an AO change. Requests during intermission or an unprepared HQ are rejected. An already committed transition cannot be cancelled by the pending-request command.

The forced Defense starts after the current Primary AI deinitialization acknowledges completion. Its owned handoff waits at most 60 seconds; failure to finish that shutdown aborts the request instead of starting overlapping controllers. HQ cleanup waits on the same owned Defense handle, including when the AO would normally decline Defense. A current, usable Classic HQ is required; the script does not generate a standalone HQ in an empty or unrelated mission mode.

On actual Defense admission, a local effective force mode selects the requested event without changing the real `QS_forceDefend` setting. For ordinary Defense, `QS_forceDefend = 1` forces one eligible event and resets to `0`; `2` forces every eligible event and remains `2`. Negative modes skip once (`-1`) or persistently (`-2`). Mega Defense's separate pending flag is why Jolly's one-event use of mode `1` needs no change. Manual admission bypasses the ordinary initial-five-minute, random, FPS, nearby-unit and negative-force gates. Ordinary Defense retains its existing gates and force-setting consumption. The new timer uses start +1,800 seconds, while an ordinary event retains 900 + random 450 seconds.

During an already running Defense, the existing loop consumes the request before spawning, warning and completion checks. Its deadline becomes `max(current deadline, serverTime +1800)`: at least 30 minutes remaining, with no shortening of an existing longer deadline. It refreshes the native task timer and recalculates the final-minute warning. Repeated requests in this mode cannot extend the deadline again. Expired or closing events reject extension. A dedicated RUNNING/CLOSING state distinguishes the battle from cleanup, when `QS_defendActive` is still true.

The special mode bypasses the native `QS_defend_blockTimeout` overtime branch at its final deadline. It does not enable `_extended` or introduce force/speed escalation. If an event was already in native overtime when extended, its existing combat state remains. Unit caps, spawn intervals, aircraft/artillery providers, Taru policy, Support stock, HQ capture, failure, administrator cancellation, rewards and cleanup retain their existing behavior. Extending an active event does not restart or rearm Support stock. Ordinary Defense outside this mode retains its native overtime control.

Each actual manual start or accepted timer extension sends one Crossroads side-chat message using `[WEST,'HQ']` and one hint to all clients. Repeated requests do not repeat those announcements. Existing Defense start/result notifications remain. The state changes to CLOSING immediately after the battle loop and clears at normal cleanup completion. Request/status results go to the server RPT. No new remote-execution permission or external ApexCfg change is required.

A future server scheduler can execute the same entry point. The callable feature is included; scheduling is left to the server owner. The normal controller pass and Primary deinitialization introduce a handoff delay, and the 1,800-second deadline is evaluated by the native scheduled Defense loop. Its 1.5-second sleeps and other work can delay final resolution under load. Live testing must time both the forced transition and the actual Defense interval.

### Squad positioning, parachutes and wind

Normal squad posts are 100–180 m from the objective with 140 m between accepted posts. Additional squads use 240–360 m approaches. Individual slots begin on an 18 m by 20 m pattern and are checked against terrain and separation. Failed searches retain current positions. AI pathfinding and combat can still reduce actual separation.

Initial patrols keep their routes until an observed contact activates the response. Eligible mobile groups are then assigned gradually; every fourth eligible native patrol assignment retains its dispersed route and reports contacts without being borrowed. Other squads defend separated approaches or answer contact reports. Non-snipers use standing stance and FULL movement with native targeting enabled. Dedicated guards stay at their own objective, then fall back to another surviving objective. HVT/Medevac groups retain their tasks.

For ordinary deliveries outside an admitted Taru flight, the existing five-step delivery pattern prefers direct parachutes on three steps, subject to capacity and terrain. The low-population Taru preference and high-population transport allowance take precedence over that fallback pattern. Maximum 24 direct-drop Primary parachutists, three low-population Taru flight jobs or one at 20+, and one creation worker. Each Taru flight separately monitors only its own admitted squad. Ground arrivals require concealment. Spawn searches exclude nearby players and have bounded attempts. Failed parachute/transport insertions have cleanup timeouts; actual dismount is checked before deleting a transport or assigning ground orders.

Wind is tested once, using the first scheduled parachute group of each Primary/Defense. Up to 24 test records are observed at three-second intervals, for no more than 150 seconds. Successful, uninjured landings provide mean horizontal drift from actual spawn positions. The correction is capped at 100 m, frozen after that test, and cached for each later group. Failed tests retain the initial wind estimate. Shifted positions undergo safety checks. The calibration does not steer chutes or change Defense wave sizes/timing. The new Taru delivery uses the same cached drift correction for its approach; unrelated native helicopter exits and vehicle parachutes retain their existing paths.

Final objective: stop normal creation, let completed inbound squads finish insertion, and release registered garrisons. Infantry receive HQ posts 80–160 m out; vehicles seek firing positions 200–450 m out. HVT/Medevac groups are not retasked. Hostile guards count toward the final ground count; friendly/captive patients do not. Aircraft are not a mandatory air-to-air cleanup objective. Rare final reserves require more than 15 conscious nearby ground players. Success requires all objectives, no incoming delivery, and fewer than ten hostile ground personnel continuously for 15 seconds.

### Insertion lifetime and cleanup

| Path | Ownership and exit |
|---|---|
| Primary controller | Stop its owned construction and type-0 artillery handles, clear that activity's wind record, and return its roster to native cleanup. Aircraft fire missions keep their own helper finalizers. |
| Primary Taru | One admitted squad and one pilot. AIR waits for the shared flight’s landing signal before assigning an objective task; incoming Tarus hold the AO-clear timer. |
| Native landing insert | One 900-second maximum lifetime captures activity state and an insertion serial. Close its waypoint callback, unfinished cargo and helipad on cancellation; completed ground troops belong to the existing native roster. Its short settlement worker checks activity and unit ownership before acting. |
| AI rappel | Existing pilot, no temporary Logic leader. A 15-second final-approach bound and at most 45 seconds total; callers may pass a shorter remaining budget. Horizontal distance ≤20 m and ASL height error ≤8 m authorize each release. Movement is allowed. |
| Rappel descent | Six existing anchors, new AI releases every 0.6 seconds, AI descent 5 m/s. Player descent controls remain native. Each use owns its serial, rope, anchor/device and event-handler IDs; stale cleanup cannot release a reused anchor. AI descents have a 180-second emergency bound. |
| Built-in Taru flight | One already-seated squad. Approach ≤180 s, final positioning ≤20 s, release ≤45 s, landing monitor ≤150 s and departure ≤180 s. One scheduled job owns each flight; the shared rappel helper owns its own ropes and finalizer. |
| Kavala | Activity closes before a maximum 180-second evacuation wait. Forty attempts bound replacement-position searches. The existing collector retires exact mission objects and restores each hidden terrain object when clear. No whole-area unhide waiter remains. |

Built-in Taru approach switches to a slow final leg inside 60 m. Parachute release needs ≤20 m horizontal distance and 120–350 m ATL; the requested height is 180–220 m. Rappel requests 25 m with at most 8 m height error over a clear site. A 9 km/h release limit permits motion; individual parachute exits are 0.35 seconds apart. The release circle does not constrain eventual wind drift. The shared wind estimate adjusts the approach without steering occupied parachutes.

AI bulk release additionally validates the **actual rope anchor** transformed to world coordinates. Its terrain-relative height must be 8–45 m. The descent radius is `4 + min(horizontal speed, 5) × (1 + (height + 3) / 5)` metres, allowing for descent, initial displacement and drift. Players block a radius of 50 m plus that footprint. One nearby-terrain query rejects trees, rocks, buildings, walls, fences and power lines within footprint plus 10 m. One nearby-object query rejects ground vehicles, static objects and ammunition containers there, and living dismounted infantry below 3 m within footprint plus 1 m. Nine center/perimeter terrain samples reject water, positions within 50 m of the map edge, surface-normal Z ≤0.96 and terrain differences above 3 m. One vertical geometry/roadway ray checks the actual anchor to the landing surface, ignoring the helicopter itself.

Each 0.6-second release attempt tries at most six free anchors and stops at the first clear anchor. Thus the clear common case needs one terrain/object query pair and one ray; the worst blocked attempt permits six pairs, 54 terrain samples and six rays. This is release-time work, with no new per-flight-frame world scan. A completely blocked first release closes the bulk worker immediately. An automatic Taru can then climb normally to 180–220 m and use the unchanged parachute distance/altitude gates, with one 45-second positioning window still bounded by the original 180-second approach deadline. There is no low-altitude parachute ejection or repeated mode switching. Once any rope release succeeds, later blockage leaves unsafe pending passengers aboard; the worker does not switch to parachutes around active ropes.

The same bulk worker checks landed members every 0.6 seconds. Each eligible local AI, after its rope state clears and it is below 3 m, gets at most one egress search of six dry, flat and unoccupied destinations outside the current descent footprint, followed by one native movement order if a destination exists. No separate egress worker is created. Players, captives, remote-controlled units and ownership takeovers are excluded. Landed squadmates continue to block unsafe rope footprints until they actually move clear; a failed egress search does not relax that collision guard. Native navigation and terrain geometry still require live validation.

No cargo is created during flight. The already-admitted soldiers retain their loadouts and squad; Supply loss is enforced by the existing Primary creation path. An unsuccessful release departs with its remaining passengers. Landed Defense troops resume the HQ push, while Primary troops return to their objective controller. Cargo ownership remains on the server until descent finishes. Player, captive, Zeus and locality takeovers are excluded from scripted movement/deletion. One bounded monitor per flight checks descents; there is no scheduled monitor per soldier.

The helper records the Primary or Defense epoch, cancels release when the activity changes, issues departure orders before collection, and does not generate replacement squads for aircraft shot down. Outbound aircraft no longer hold Primary clearance, while incoming troops do. Existing native insertion callers outside the new explicit modes keep their previous behavior.

Retirement uses the existing `QS_garbageCollector`, with `DELAYED_DISCREET` and a further 180-second grace for aircraft and occupied seats. That collector checks a 150 m player-clear radius; normal departure also checks distance from the AO and 500 m player clearance. A stuck or damaged aircraft can outlast the grace while players remain nearby. This removes immediate timeout deletion and deliberate departure explosions; it is not a guarantee that aircraft will never despawn within long-range optics. Global framework collectors intentionally remain running. No global Logic/group sweep or forced stop of shared schedulers is used.

The Taru population table in section 1 governs automatic normal infantry deliveries in both Primary and Defense. Low population prioritizes the transport method; higher population limits it to 12.5% of admitted ordinary infantry. Each flight carries one admitted squad and uses the existing personnel allowance.

Tests cover the 19/20-player boundary, flight quotas and cooldowns, failed terrain admission, shot-down aircraft, airborne cargo at an activity transition, parachute and rappel landings, wind calibration across activities, stuck departure, nearby players, occupied seats and ownership takeover. Defense acceptance also verifies its original spawn quantities, caps, artillery timing and 15–22.5-minute duration alongside the new selection and flank behavior.

## 5. Combat aircraft and outgoing infantry covering fire

**Files together:** `fn_AI.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_enemyCAS.sqf`, `fn_AIFireMission.sqf`, `fn_AIXMissileCountermeasure.sqf`, `fn_AIXSuppressiveFire.sqf`, `fn_scSpawnHeli.sqf` and Defense movement hooks.

### Combat aircraft roles and targeting

Ambient jets originally shared a group. Each updated flight receives its own group so one aircraft’s orders cannot overwrite another’s interception or ground pass. The pilot-death callback now resolves the unit passed to the event, rather than a spawner-local pilot variable. Native vehicle classes, loadouts and spawn limits remain.

`QS_fnc_combatAir` remains embedded in `fn_AI.sqf`. Registered flights use the existing roughly three-second AI loop, with dead/nonlocal groups pruned from a small roster. The ordinary group handler respects that ownership. No per-aircraft scheduled worker is added.

One group owns each ambient jet. Installed missile/bomb mounts select CAP when air mounts are present and at least equal ground mounts; other aircraft use CAS. Native classes/loadouts remain. CAP is not registered for requested ground fire. Pilot magazines provide a fixed-loadout fallback; door guns alone do not turn a transport into a combat target.

Select from the pilot's known airborne WEST aircraft within 5 km, knowledge up to 45 seconds old, within 6 km of the activity center and outside base 1 km. When both classes are eligible, choose combat 80% / transport 20%, then the nearest eligible aircraft, retaining the current target when it is still in the chosen class. Recent airborne attackers may override the weighting. Transport pursuits are reconsidered every 12 seconds; valid combat commitments are stable for up to 45 seconds and can renew without a forced ground break. Engine sensing, firing solutions and maneuvering decide the result.

Managed crews keep automatic combat and targeting enabled outside accepted passes. The legacy all-player jet targeting loop cannot override these flights. A 90-second CAS ground-priority interval after a routine interception does not exclude known combat aircraft or recent attackers. Only new targeting decisions pause below 18 FPS; the native pilot continues its current flight/combat behavior.

Ground-provider admission is atomic on the owner. An accepted pass owns its laser and movement until native cleanup. An incoming missile withdraws that request; the existing finalizer releases helpers before interception resumes. Managed missile response uses installed flare launchers, their actual ammunition and a three-second throttle. It does not clear missile guidance or force hits. Other vehicle countermeasure paths retain their original code.

Ground-pass departure retains 650–1,000 m / 15–25 seconds for rotary and 1,600–2,400 m / 60–100 seconds for planes. The ground-request cooldown is independent of air targeting: combat threats can interrupt departure. Ground requests still wait out their cooldown. Final Primary HQ/contact positioning is the fallback after active flight tasks release control.

### Outgoing infantry covering fire

This changes AI firing onto players in Primary/Defense. Incoming AI suppression settings and player HUD effects are not altered.

The existing owner-local unit scheduler (nominally 25 seconds, plus its normal work/yields) allows two covering shooters per group through eight conscious nearby ground players. Above eight, squads with at least eight living foot soldiers allow four; smaller squads allow two. Non-leader MGs are selected first, with eligible riflemen filling spare slots. Each shooter still needs ammunition, valid intelligence and a clear lane. These are selection/concurrency limits, not forced simultaneous fire.

Through eight ground players, bursts remain 4–6 seconds with 60–90-second individual cooldowns. Above eight, they remain 8–12 seconds and 24–36 seconds. The handler reads the existing Primary census or Defense's existing 15-second pass; there is no extra population scan or squad loop. Actual cadence also includes scheduler timing.

Covering fire has no FPS cutoff. Admission needs at least eight rounds in the primary weapon, 60–500 m range, an observed conscious player on foot, known position age at most 20 seconds and uncertainty at most 30 m. Terrain and a five-meter friendly-fire lane are checked. Fire goes to the observed ASL position, not a hidden player's current coordinates. `doSuppressiveFire` and `suppressFor` request the population-appropriate burst using native weapons/ammunition. Arma may refuse an impossible shot. Cooldown and ammunition checks precede shooter selection; a full shooter budget is rejected before target searches. The original unmanaged suppression path retains its own FPS guard.

Primary positioning and all native Defense propulsion variants avoid overwriting an active covering shooter's command. Other squad members keep their movement orders. The old fired callback resolves its own group, and an obsolete callback on a managed covering unit exits without replacing its command. Protected objective units, vehicle crew and player/Zeus-controlled soldiers are excluded from the new infantry path.

Testing covers multiple simultaneous aircraft, human and AI crews in observed target aircraft, armed transport classification, a ground pass interrupted by a missile, countermeasure exhaustion, interception during departure and owner-local flight control. Infantry tests cover two/four shooter limits, low ground turnout, ammunition exhaustion, blocked friendly lanes, stale reports and movement continuing around active covering shooters.

## 6. Ground placement and city activities

**Files together:** `fn_spawnGroup.sqf`, `fn_aoEnemy.sqf`, `fn_aoDefend.sqf`, `fn_spawnViperTeam.sqf`, `fn_gridEnemy.sqf`, `fn_gridSpawnPatrol.sqf`, `fn_gridSpawnAttack.sqf`, `fn_ambientHostility.sqf`, `fn_missionGeorgetown.sqf`, `fn_missionKavala.sqf`, `fn_scSpawnLandVehicle.sqf`, `fn_scEnemy.sqf`, `fn_taskPatrol.sqf`, `fn_taskAttack.sqf`, `fn_fobEnemyAssault.sqf`, `fn_aoEnemyReinforceVehicles.sqf` and `fn_spawnSupport.sqf`. Kavala’s access, revive state and lifetime also require `fn_core.sqf` and `fn_incapacitated.sqf`.

### Ground spawn placement

`fn_spawnGroup.sqf` provides `SLOTS` for infantry and `VEHICLE_SLOTS` for ground vehicles. Each request stays inside a rotated **85 × 85 m** square centered on the caller's accepted anchor. The first pattern checks **25 candidate cells**, with up to two metres of terrain adjustment, then repeatedly chooses the most isolated valid point. Infantry whose initial layout is incomplete can add three staggered half-pitch patterns of 20, 20 and 16 candidates: **81 candidates maximum**. Extra patterns run only when needed and remain inside the same approved footprint; the helper does not relocate the anchor.

Infantry preserve **15 m** from all other chosen slots, nearby dismounted infantry and construction claims throughout every pass. They do not relax occupancy or reuse coordinates to fill a squad. An incomplete final layout returns no slots before creation. Vehicles retain their initial candidate pattern and require a complete set of distinct positions at least 15 m apart; empty vehicles and wrecks block cells. Airborne vehicles do not occupy ground cells. These are spawn positions, not a formation-spacing controller.

Unlike the original common-center outdoor placement, the placement request reserves its footprint atomically on the spawning machine. Claims last 20 seconds and are pruned on the next request; there is no new cleanup worker. Consecutive squads can use available space within the same square only while preserving separation. Ordinary callers retain their initial search rules and add 30 m player exclusion. Primary infantry opt into 150 m exclusion/concealment and validate final slots against AO/base/route boundaries before creation. Vehicle callers retain their stronger exclusions: Defense and Primary reserves 400 m, native armor 250 m, and native ground patrols 500 m. Route and terrain restrictions remain; an unsafe adjusted position skips that creation attempt.

`SLOTS` and ordinary infantry creation accept an optional synchronous position validator, defaulting to true. Defense uses it to preserve the native HQ radius, player exclusion, blacklist and water-crossing checks at each admitted slot. Its native 50-attempt center search now records success explicitly; an exhausted search cannot use the last failed candidate. A rejected or empty group exits before shared group setup and explicit waypoints.

The sector radial infantry-fill loop in `fn_scEnemy.sqf` now makes at most **24 squad-placement requests**, yielding 0.02 seconds between attempts when scheduled. It stops as soon as the existing personnel target is reached. Failed placement skips group setup; empty patrol-position lists are not indexed. Its target, native candidate searches and separate off-map assault path remain. AO patrol setup, shared `fn_taskPatrol`/`fn_taskAttack` and FOB assault waypoint setup now exit safely for null/empty groups, preserving valid-group behavior while preventing rejection from causing empty-roster errors or invalid waypoint calls.

Initial AO vehicles, Defense ground armor/transports, Grid patrols, paired ambient vehicles, native ground patrol/reinforcement vehicles and mobile medical/repair support use `VEHICLE_SLOTS`. No post-spawn world scan teleports entities. Air insertions, paradrops, deliberately placed buildings/compositions, cargo and Zeus editor placement retain their own positions. City building patrols retain their native building-point checks.

The helper accompanies every updated caller listed in the Files and testing section of `RELEASE_NOTES.md`. Terrain, collision dimensions, concealment, network replication and actual navigation require engine acceptance. Offline tests execute the selection/reservation/rejection logic with explicit engine-fact adapters.

### Low-population specialist guard

Below 25 connected human players, the native Classic/sector Viper opportunity requires more than eight conscious WEST ground players near that AO, no existing Viper team being topped up, and a 1% roll. The native retry interval remains; this is not a per-frame roll. An admitted initial low-population team contains six. Existing Vipers are not deleted.

The native EAST helicopter helper substitutes regular CSAT cargo for a requested Viper class pool below 25 connected humans; existing supplied passengers retain their units. At 25+ connected, native specialist selection retains its normal behavior. These gates cover the updated automatic paths, not arbitrary Zeus placements or external scripts. While the new Primary controller runs, its separate legacy automatic Viper top-up path is bypassed entirely.

### Kavala access and pilot revive

Altis custom-mission selection accepts populations above 36; Kavala no longer exits above 45. The existing random module eligibility, selection delay, minimum population and mission frequency remain. Tanoa's Georgetown population gate is unchanged.

Kavala publishes `QS_kavalaRevive_active` before setup and retains it until evacuation and cleanup handoff finish. `fn_incapacitated.sqf` reads that mission state for each casualty and bypasses only the pilot/fighter-pilot forced-death branch. Respawns, new joins and role changes need no per-unit trait patch. Normal incapacitation and the five-minute timer apply; existing drowning, non-WEST and extraction rules remain.

The flag is public so new clients receive the current mission state through the framework's normal public-variable synchronization. An already incapacitated player is not killed when Kavala ends; later casualties use the restored normal role rule. Multiplayer event order and join-in-progress still require engine acceptance.

`fn_core.sqf` initializes the state and checks the owning script in its existing custom-mission pass, even when random custom missions are disabled. If the Kavala script ends or is terminated, the flag clears. Normal cleanup checks script ownership so an old mission cannot clear a newer one's state. The core also finishes a manually triggered custom mission after its trigger is consumed. No new perpetual worker or persistent role mutation is added.

These Kavala files share the Gameplay dependency bundle in the Files and testing section of `RELEASE_NOTES.md`.

### City replacement searches and activity cleanup

Kavala’s original replacement searches could retry indefinitely when every building position failed the visibility or player-distance checks. Replacement searches now stop after 40 attempts or the mission deadline, then skip only that unsuccessful replacement. Mobile building positions preserve the original height/visibility rules and target 15 m separation from living infantry. Georgetown’s mobile building replacements receive the same 40-attempt bound and separation check. Outdoor AA, sniper and AT patrol replacements in both cities use the shared validated slots.

Kavala closes its insertion activity before a maximum 180-second evacuation wait. Zero/one-player and headless-client cases can finish. Its exact mission objects enter the existing discreet collector, retaining protected player/captive/occupied/attached objects. Hidden terrain is restored per object when players are clear; an indefinite whole-city unhide worker is no longer retained. These changes do not introduce new tablet-progress ratios, mobile enemy counts or mission-duration settings.

Test open terrain, crowded streets, slopes, roads, simultaneous requests and vehicle wrecks; then Grid/ambient patrols, medical/repair vehicles and the two city replacement paths. Kavala tests include more than 36 and more than 45 players, JIP/respawn during the pilot-revive override, evacuation, abnormal termination and nearby-player terrain restoration.

## 7. Forward Observer, JTAC and Mortar Gunner

**Files together:** added `fn_artillerySupport.sqf`, added `fn_mortarSupport.sqf`, added `media/images/roles/arid/forward_observer.jpg`; edited `description.ext`, `code/config/security.hpp`, `fn_roles.sqf`, `fn_clientArsenal.sqf`, `fn_clientCore.sqf`, `fn_clientInteractMortarLite.sqf`, `fn_incapacitated.sqf`, `fn_AI.sqf`, `fn_aoDefend.sqf` and `fn_core.sqf`. Both new functions participate in the shared client menu observer and must be present.

The initial live mission already had JTAC/Mortar Gunner roles, native artillery providers and a lightweight one-mortar deployment action. This release adds the Forward Observer role and virtual fire menus, and extends the lightweight mortar path into a server-owned three-mortar section. Native two-backpack assembly and existing base/destroyer/context-menu artillery remain separate.

### Forward Observer and JTAC stock

Forward Observer has exactly one WEST role slot at every population. JTAC and Mortar Gunner retain their configured role limits. Other roles receive no new Support actions. The Forward Observer uses the configured JTAC gear list and the supplied 365 × 399 role image, matching Mortar Gunner. No external role-config edit is needed.

| Service and ammunition | Primary allowance | Defense allowance | Vanilla magazine / ammunition class |
|---|---:|---:|---|
| Forward Observer (31+) — 155 mm HE | 16 | 32 | `32Rnd_155mm_Mo_shells` |
| Forward Observer (31+) — laser / IR guided, shared | 4 | 8 | `2Rnd_155mm_Mo_LG` / `4Rnd_155mm_Mo_guided` |
| Forward Observer (31+) — ICM cluster | 2 | 4 | `2Rnd_155mm_Mo_Cluster` |
| Forward Observer (31+) — 230 mm HE rocket | 4 | 8 | `12Rnd_230mm_rockets` |
| JTAC — Mk82 unguided | 3 per slot | 6 per slot | `2Rnd_Mk82` → `Bo_Mk82` |
| JTAC — GBU-12 laser guided | 2 per slot | 4 per slot | `2Rnd_GBU12_LGB` → `Bo_GBU12_LGB` |
| JTAC — CBU-85 laser-guided cluster | 1 per slot | 2 per slot | `4Rnd_BombCluster_01_F` → `BombCluster_01_Ammo_F` |

Forward Observer stock at low and full connected population is:

| Ammunition pool | ≤10 humans, Primary / Defense | 31+ humans, Primary / Defense |
|---|---:|---:|
| HE | 8 / 16 | 16 / 32 |
| Laser / IR guided, shared | 2 / 4 | 4 / 8 |
| ICM | 1 / 2 | 2 / 4 |
| HE rockets | 2 / 4 | 4 / 8 |

For 11–30 humans, each Primary pool is rounded from `base × (0.5 + 0.5 × clamp((population − 10) / 21, 0, 1))`; Defense doubles that rounded result. The full base is the 31+ Primary column above.

Amounts count individual projectiles, independent of the magazine name's capacity. Mk82 and GBU-12 are both 500 lb; guidance distinguishes them. Only these eight menu profiles are permitted. There are no smoke, AP/AT mine, SDB, demining or cluster-rocket options. Forward Observer has no red illumination profile or ammunition pool. Missing configured ammunition is omitted with an RPT entry; clients cannot provide arbitrary class names.

Stock is issued once at each Primary start or actual Defense start. Forward Observer receives half its full Primary allowance at ten or fewer connected humans; from 11–30 it interpolates to full stock at 31, rounding to whole rounds. JTAC receives 3/2/1 per authorized slot at every population. Defense doubles each service’s resulting allowance. Joining, role changes and respawns do not refill stocks. Side tasks and Kavala do not issue extra refills. New requests require a live Primary or Defense; ending that activity cancels queued work.

### JTAC shares

Stock uses the allowed JTAC capacity from the existing role system, including empty slots and configured whitelist capacity. This is separate from Primary's nearby-ground-player census. Each service has its own stock and one active mission; another JTAC waits while a JTAC strike completes, while Forward Observer may operate independently.

The supplied Apex `roles.sqf` allows three JTAC slots at every population. Primary therefore issues 9 Mk82, 6 GBU-12 and 3 CBU-85 in total, reserved as three identical 3/2/1 shares. Defense issues 18/12/6, reserved as three identical 6/4/2 shares. No remainder rotation is needed for these equal allotments.

A single occupant can use only one share. Vacancies do not donate stock. Slot and player-UID spending persist through swaps/reconnects; a replacement inherits the slot’s remaining stock. The number of issued shares is fixed at activity start. Closing slots cannot transfer their rounds to remaining slots; reopening an issued slot retains its spending. Capacity added beyond the issued slots waits for the next activity’s refill. Already accepted reservations count as spent until cancelled or released.

### Request and cancellation

`0 > 8 > Artillery Order` / `Airstrike Order` selects the map/cursor target and munition, followed by applicable dispersion and explicit **Request Fire Mission** confirmation. Forward Observer retains its 1–8-round selection. JTAC skips round selection and requests exactly one bomb, also enforced by server validation. Unguided HE shells, HE rockets and Mk82 offer 0/25/50/100 m dispersion; guided munitions and clusters use zero added dispersion. Native submunition spread still applies.

A successful server admission records the request's authoritative timestamp and reserves the ammunition. Broadway privately acknowledges the requester. At 10–12 seconds after acceptance, one announcement is sent to all clients through the existing Broadway radio identity:

> {role} Fire Mission requested at grid {grid}. Payload {quantity and munition}. Time to target {remaining seconds} seconds.

The schedule targets the final impact/completion at 20–25 seconds after acceptance. The release schedule works backward from that deadline using a downward-flight estimate from spawn height, initial speed and gravity. FO rounds are 0.5 seconds apart; JTAC has one release. Public time to target is the remaining estimate to the first impact at announcement time. For eight FO rounds, the first impact is planned 3.5 seconds before the last; the final impact/completion still targets 20–25 seconds after acceptance. The provider creates attributed native ammunition above the target without spawning a battery, crew or aircraft. Guidance, drag, terrain and scheduler delays can change actual impact time; this is a planned timing window requiring live Arma verification.

Acceptance creates a temporary blue ground marker for WEST clients, retained through the planned completion. It is a custom 3D Support marker. Blue smoke precedes release, and private Broadway updates report release, completion or cancellation. An invalidated job cannot later announce or release its remaining ammunition. Service ownership remains busy through planned completion; the watchdog expires five seconds after planned completion. An announcement more than one second behind its chosen time, or beyond 12.25 seconds after acceptance, cancels unreleased work. A release more than 0.5 seconds late also cancels remaining rounds instead of delivering an overdue burst.

A friendly laser must exist within 50 m of the chosen target for laser profiles; the nearest is selected again before every round. IR shells require a known hostile crewed vehicle within the same radius. Lost designations cancel unfired rounds. The ordnance receives the current designation through `setMissileTarget`; moving-target accuracy must be verified in Arma.

The server requires at least **175 m plus the selected dispersion radius** from every living human player, including unconscious players and vehicle/aircraft occupants. The server checks again before each release, together with the mission safe-zone rules and Robocop's existing penalty threshold. This rule counts humans rather than every friendly AI. It is a release-time exclusion, not a guarantee against players moving into an impact or submunition area afterward. Danger-close denial is private to the requester:

- `Requested Artillery fire mission is danger close to friendlies, request denied.`
- `Requested airstrike is danger close to friendlies, request denied.`

A role change, death, incapacitation, remote control, activity end or timeout cancels queued work. Role, life or control changes remove the caller's menu; activity end leaves the role action present but makes new requests unavailable, while timeout closes the job. During the same activity, cancellation refunds only unreleased rounds. Ending or changing the activity closes its allowance; nothing carries into the next activity. Release and debit are atomic, so cancellation cannot refund an already-created projectile. Fired ordnance is not deleted. `setShotParents` attributes it to the caller for existing damage/Robocop handling; submunition attribution needs multiplayer acceptance.

One client observer reconciles all three Support services every two seconds, with immediate role/incapacitation/death/respawn hooks. The existing three-second AI pass checks outstanding fire jobs. Jobs have schedule-based deadlines and own their worker, blue smoke and temporary marker; activity changes close them. No per-role battery AI or persistent JIP request queue is added.

The supplied Apex configuration also enables the mission’s existing context-menu fire support, base artillery and destroyer artillery. Those providers have their own rules and are outside these new role ammunition pools. No new Support-menu action is granted to other roles.

### Mortar Gunner equipment

`0 > 8` provides **Request Mk6 Mortar**, **Request Mortar Resupply** and **Reset Mortar Section**. A requested Mk6 enters the existing carry/placement flow with eight HE rounds, no smoke or illumination. It uses the vanilla `B_Mortar_01_F` class. Up to three owned mortars may exist; the mission’s lightweight **Deploy Mortar** action uses the same admission and HE-only path. A pending placement holds a slot before locality transfer. Failed or late placement acknowledgments cannot reopen it.

Mortar and resupply have independent ten-minute request cooldowns, retained by UID for the server session. Lightweight Deploy Mortar consumes owned inventory rather than either Support cooldown. A resupply crate parachutes to a clear chosen position within 500 m, containing five mortar-tube backpacks. The final placement must also remain within 500 m, at least 10 m from living players and outside blocked safe zones, water, steep slopes and overhead obstructions. It supplies no general vehicle-ammo cargo. Once the crate is emptied and the resupply cooldown expires, another may be requested. Deposited player equipment prevents an apparently used box from being deleted as empty. Reset is available only while the owner remains conscious and otherwise eligible; incapacitation removes the menus and the server rejects direct RESET requests while keeping nearby equipment for revive.

At three mortars, privately show **Mortars fully deployed!** and `Three mortar section fully deployed.` Reset removes that gunner's section and crates without changing either cooldown. Mortar Gunner roles alone may man Support mortars; other occupants are ejected through the existing revive-aware path. Native rearm/disassembly actions are disabled on these owned mortars.

The existing server core checks assets every three seconds throughout mission activities. Role departure, death/respawn, disconnect, destruction or exceeding 500 m retires owned equipment. Incapacitation temporarily removes menus but keeps nearby equipment for a possible revive. Retirement first ejects occupants and waits before deleting the empty object. Placement handoff waits at most eight seconds, its reservation expires after fifteen seconds, and the supply descent has a 120-second deadline. Spent/failed cargo and parachutes are cleared; equipment that remains valid near its gunner may persist across activity changes. Server restart clears this session's cooldown/ownership state.

The original native **two-backpack Assemble** path and Zeus-placed mortars retain their own rules. They are not registered as Support-owned equipment and do not inherit its HE-only inventory, shared three-mortar count or 500 m cleanup. The supplied config has three Mortar Gunner slots, allowing up to nine Support-owned mortars across those players.

Test the role/gear/menu definitions and each munition with the same activity stock lifecycle: Primary → Defense → next Primary, all JTAC slots including vacancies and replacements, simultaneous FO/JTAC services, reconnects, role changes and cancellation during a volley. Mortar tests add placement races, the fourth-mortar rejection, tube deployment versus request cooldowns, resupply, Reset, occupied retirement, incapacitation/revive and distance beyond 500 m.

## 8. Incapacitation and firing-side attribution

**Files together:** `description.ext`, `fn_incapacitated.sqf`, `fn_missionKavala.sqf`, `fn_core.sqf`, `TGC/Functions/Damage/fn_isFriendlyFire.sqf`, `fn_clientEventHit.sqf`, `fn_clientDamageModifier.sqf` and `fn_aoEnemy.sqf`, including Support dependencies called by incapacitation.

### Five-minute incapacitated window

`description.ext` sets `ReviveBleedOutDelay = 300`. The supplied original was 600, and the imported contribution initially proposed 240. `fn_incapacitated.sqf` reads this mission setting, derives its local deadline and published bleed-out time, displays the remaining time, and forces respawn on expiry. The existing timeout loop remains.

The existing code grants 60-second extensions near expiry while a casualty is aboard/attached to a living crewed vehicle. Requested AI medevac can replace the deadline with its extraction timeout. These paths remain; five minutes is the normal unattended window, not an absolute maximum during an extraction. The mission source contains no second assignment overriding `ReviveBleedOutDelay`. Verify with the deployed revive/mod setup.

Forward Observer, JTAC/JTAC whitelist and Mortar Gunner roles bypass the pilot-trait forced-death branch, including a stale pilot trait after a role change. They use normal incapacitation and immediately lose active Support menus while unconscious. Other roles retain their ordinary rule except during the Kavala activity override in section 6.

### Zeus attribution and Commander completion

`fn_aoEnemy.sqf` registers `MPKilled` for the Commander. The event acts only on the server, only for the current `QS_csatCommander`, and only while `QS_commanderAlive` remains true. It updates state before deleting the task, moving the HQ markers and sending the existing notification. It creates no poller or persistent worker; the object owns the handler.

The existing `TGC_fnc_isFriendlyFire` also accepts `['ATTACKER', source, instigator, victim]`. The optional victim is supplied by all updated damage callers. When the source is that victim, keep the supplied instigator, including `objNull` for unattributed collision damage. This preserves the original self-source exclusion; explicit self-inflicted damage still uses the ordinary side comparison. A known gunner in the firing vehicle takes precedence; a physical infantry source supplies its own side. For controller-body instigators, the engine remote-control link or replicated BIS owner marker must match both the instigator and firing vehicle. An unrelated controlled passenger cannot override an identified gunner. Unknown environmental sources do not create a remote-control exemption. Missing attackers skip controller-object lookups.

The initial live helper already checked the BIS owner marker, but selected the first marked source/crew member without checking whether its owner matched the reported instigator. This update narrows that selection and shares it with the hit-warning, damage-scaling and incapacitation handlers. Its `_getSide` lookup, explosive/missile fallback block and final side comparison retain their original code.

Robocop retains the controller identity when friendly AI fires. Damage scaling and incapacitation chat use the same resolved combat side. No curator-wide immunity, new runtime function registration, extra loop or global event handler is introduced.

Test unattended bleed-out against vehicle and medevac extensions, pilots before/during/after Kavala, Support roles after a pilot-role change, hostile/friendly remotely controlled infantry and vehicles, an actual gunner with an unrelated controlled passenger, collision damage and Commander death under Zeus ownership.

## 9. Radio and BLUFOR AI speech

**Independent radio bundle:** `fn_config.sqf`, `fn_initPlayerLocal.sqf`, `fn_clientEventRespawn.sqf`, `fn_clientRadio.sqf`, `fn_clientMenuRadio.sqf`, `fn_highCommand.sqf`, `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf` and the corrective `TGC/Functions/Staff/fn_staffChannelsGUI.sqf` companion.

**Independent speech pair:** `TGC/Functions/Damage/fn_addFriendlyAIHandlers.sqf` and `TGC/Functions/Damage/fn_initFriendlyAIProtection.sqf`.

### Tabled public-radio design

The original live mission used native faction Side transmission and an optional General subscription. That remains the default live policy. At server startup, `fn_config.sqf` resolves `QS_missionConfig_sharedRadioChannels` once, publishes the Boolean as `QS_radio_sharedBroadcastsEnabled`, and defaults it to false. With the gate off, it allocates no additional channel, restores the original native Side permissions, leaves General optional, keeps private Staff separate, and does not run the added one-second radio reconciler. The remainder of this subsection describes the retained explicit-opt-in design for future revision.

| Channel | Membership | Player text | Player VOIP |
|---|---|---|---|
| Optional Side, blue | Default on; saved opt-out | Subscribers | Subscribers |
| General, existing custom ID 8 / UI 13 | Required | Everyone, subject to existing staff masks | ADMIN or CURATOR whitelist, logged-in server admin, or assigned Zeus; existing masks still apply |
| Staff, existing custom ID 1 / UI 6 | Original ALL whitelist rule | Original settings | Original settings |
| Built-in Side, UI 1 | Native mission delivery | Player sending disabled | Player sending disabled |

All ten existing custom channel definitions are preserved. When the gate is enabled, the optional Side colour is read from `CfgInGameUI >> Chat >> colorSideChannel`, matching the game's native Side colour. A malformed/missing colour array falls back to the existing blue so channel allocation remains valid. A separate custom channel is created once in `fn_config.sqf` and published as `QS_radioChannel_side`. The Radio Management first row uses that ID instead of the private Staff channel. The engine needs capacity beyond the original ten slots (Arma 3 2.22+). Custom IDs 1–10 map to UI IDs 6–15; IDs 11–50 map to 26–65. The allocated ID is used rather than assuming it is 11. If allocation fails in opt-in mode, the Side checkbox is unavailable; native Side provides the documented fallback. Check allocation during any future enabled-path acceptance.

`QS_client_radioChannel_side` is a new boolean in the client's `missionProfileNamespace`, default true, used only by the opt-in path. Disabled mode ignores it and continues to use the existing General preference at profile index 7. A future redesign should use a new versioned preference key if its semantics change. The existing `missionGroup = "ApexFramework"` keeps the profile namespace compatible across mission updates.

`fn_refreshStaffChannelAccess.sqf` retains the original private Staff rule separately from General voice eligibility. In opt-in mode, the existing one-second radio loop, initialization, respawn, High Command entry/exit and late whitelist response call the same reconciler. It caches player identity, actual group/team, authorization, allocated Side ID and Side preference; unchanged checks do not rewrite channel membership or permissions. Disabled mode keeps only the original initialization, delayed respawn and whitelist-driven refresh points. No extra scheduler, remote-execution endpoint or whitelist privilege is introduced. Existing TGC channel masks continue to combine with desired text/voice permissions and cannot grant non-admin/non-Zeus General voice.

In opt-in mode, General cannot be removed through the subscription helper or a stale checkbox event. Death retains its subscription; respawn explicitly removes memberships from the old body, restores the new body and reapplies authorization. Side opt-out does not remove Staff, General or other custom channels. With the gate off, General remains an ordinary optional profile subscription and killed-body cleanup uses the served behavior.

The native `enableChannel` control governs player sending. Genuine per-player receive opt-out therefore uses custom-channel membership, leaving scripted Crossroads radio messages on their existing path. The expected player selector contains one usable Side channel. Cross-team reception and voice require two clients; selector/death-screen behavior requires a real player lifecycle; profile disk persistence requires save plus reconnect or restart.

When explicitly enabled, the custom Side channel shares player text and voice across BLUFOR, OPFOR, Independent and Civilian. Membership follows the saved subscription, not faction. The one-second access check includes actual group identity and group side; a switch reapplies receive membership even if the local subscription roster still lists Side. Stable checks perform no membership or permission writes. Native Side remains closed to player sending; scripted Crossroads traffic retains its existing mission routing. General permissions and private Staff eligibility are unchanged. Disabled mode does none of this custom allocation or mandatory-General work.

### BLUFOR AI speech

`TGC_fnc_initFriendlyAIProtection` already runs after initialization on servers, clients, HCs and joining clients. Its existing entity creation, one-frame recheck, respawn and initial-unit scan also apply the speech settings through `TGC_fnc_addFriendlyAIHandlers`. No additional mission worker or repeated all-unit scan is added.

For non-player BLUFOR infantry, each machine applies `setSpeaker "NoVoice"` and disables automatic conversation. The local owner disables only `RADIOPROTOCOL`, suppressing automatic voice/text reporting while retaining movement, targeting and orders. One validated `Local` handler reapplies the settings after ownership changes. Existing respawn cleanup also removes temporary copies of that handler. A later player takeover restores the saved speaker/radio state. The added branch does not explicitly restore automatic conversation settings. The original friendly-AI damage and collision handler bodies are unchanged.

This affects automatic AI speech, including mission and Zeus-created BLUFOR units. It does not globally disable radio or sentences, intercept player VOIP, or remove scripted mission announcements. Verify recruitment, Zeus creation, two-client/JIP audio and HC ownership changes in Arma.

Radio acceptance should first confirm default-off native Side/private Staff/optional General behavior and zero extra allocation, then separately exercise explicit opt-in cross-team Side reception, saved opt-out, native-blue channel selection, mandatory General text and admin/Zeus voice, death/respawn, late whitelist responses and High Command transitions. Speech testing covers recruited and Zeus-created BLUFOR AI, JIP, HC/server/client locality, respawn and player takeover while orders, player VOIP and mission announcements remain available.

## 10. Performance, cleanup and vehicle ownership

**Shared Gameplay files:** `fn_AI.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_aoDefend.sqf`, `fn_core.sqf`, `fn_clientEventPut.sqf` and `fn_eventBuildingChanged.sqf`, with the complete Gameplay dependencies above. The core also services Mortar Gunner equipment and Kavala state.

**Independent helpers:** `fn_serverDetector.sqf`, `fn_hcCore.sqf`, `TGC/Functions/Lasers/fn_initLaserHandlers.sqf` and `TGC/Functions/Damage/fn_addSpawnMenuVehicleHandlers.sqf` can each be tested against the original baseline; all are included in final combined acceptance.

### Background work and performance

| System | Released behavior |
|---|---|
| Primary admission census | Skip enemy/area/local-unit/group counts until an infantry or vehicle delivery is due and the existing admission checks permit it. Final-phase checks still run each pass; workers recheck live capacity before creating units. The clearance path reuses one force list instead of building it twice. |
| Primary maneuver refresh | Existing owner-local group handler, 20–30 s normally and 40–50 s under load. One load sample per owning machine per 10 s. Below 18 FPS selects slower refreshes; restoring normal pacing requires 30 s continuously at 22+. No queued maneuvers are replayed. Existing movement and weapon AI continue; assigning a new task resets its order deadline. |
| Defense normal push | Mode 2 traverses only dismounted infantry leaders, in their original order. The order body, random decisions, paratrooper handling and all spawn/timer/cap code remain. Modes 1/3/4/5 retain their native traversal. |
| Covering fire | Remains eligible even below 13 FPS. Same two/four shooters, burst/cooldown, ammo, observed-target and friendly-lane constraints. No new loop, forced ammunition or forced hits. |
| Cleanup load sampling | Once per 15 s in the existing core. Below 18 FPS selects the smallest batch; 18 to below 22 limits it to the middle batch. Recovery requires 45 s continuously at 24+ per upward step. Samples in between recovery thresholds reset the recovery hold. |
| Per core pass | Low / middle / normal: at most 64 / 96 / 128 arsenal holders and 4 / 8 / 16 logistics crates. No ground-player scan when the crate batch is empty. The normal core sleeps three seconds after its work. |
| Ruin rotation | At most 4 / 8 / 16 queued ruins on each existing cleanup rotation. The next 45-second cleanup delay starts after the current pass completes, so a slow pass does not immediately trigger another. |

Arsenal ground holders within 30 m of an active visible arsenal receive one 30-second expiry, including when players remain nearby. This replaces their prior immediate/quota-based native cleanup treatment near an arsenal. The arsenal queue uses one owned server `EntityCreated` handler and the existing class-limited census as a fallback. A holder gets one 30-second deadline; queue entries are removed in a bounded batch before processing so concurrent creation events survive. Ground-holder transfers outside the arsenal area return to native field-loot rules. `fn_clientEventPut.sqf` privately warns at most once per 15 seconds. Inserting items into a crate is not a ground-drop notice.

Known logistics crates retire after five continuous minutes with no living human ground player within 1 km of the root or its linked equipment. This replaces the original distance-only cleanup of undeployed Spawn Menu roots and also covers deployed roots. Crate candidates come only from the mission’s known spawn-menu and deployment rosters, checked every 30 seconds. No global crate census adopts arbitrary Zeus objects or mission props. A living ground player of any side, including an incapacitated player or a landed pilot, resets the five-minute absence clock. Flying aircraft occupants do not. Radius checks cover the root and its registered deployment objects. Occupants, transport attachments, vehicle cargo, ropes, motion and protection flags prevent retirement. A fresh final check precedes the native deployment finalizer and root deletion; that native finalizer owns its linked objects, marker and deployment-zone cleanup. Standalone buildables and their rules are unchanged.

`BuildingChanged` supplies destruction records without scanning all terrain buildings. Ruins wait at least five minutes and require no living player within 500 m. Only recorded mission-object destruction with a mission-object ruin authorizes deletion. Terrain/uncertain objects are hidden globally with simulation disabled; protected ruin classes and objects remain. Original buildable-collapse handling and side-objective completion remain in the event function. Hidden terrain objects are not claimed as reclaimed object memory.

Queue deadlines are eligibility times, not guaranteed wall-clock deletion under scheduler load. No FPS threshold suspends the mission’s objective completion, Defense timer, Support cancellation or these cleanup queues. The existing Primary reinforcement admission safeguard remains separate; it does not despawn an over-cap living force or guarantee a minimum FPS.

The audit covered shared core/AI passes, Primary reinforcement/count/response paths, Defense spawns and movement, outgoing suppression, Support watchdogs, insertion lifetime and dynamic simulation. It found no basis to replace the full AI dispatcher or change active-unit simulation distances without an engine profile. Existing server RPT reports already expose FPS, active scripts, AI counts and HC presence. Compare those reports and frame-time spikes during comparable Primary/Defense populations and repeated cycles; offline policy counts are not a performance benchmark.

### Vehicle entry and locality

`fn_addSpawnMenuVehicleHandlers.sqf` retains the damage-handler ID when vehicle locality returns. The existing validity check then reuses the registered handler or repairs a missing one. Previously, the TGC Local callback erased that ID even if the QS Local callback had just restored the handler, which could leave two copies. Loss of locality still removes the tracked callback; native empty-vehicle protection remains last. No lock, ownership permission or damage calculation changes.

The reviewed vehicle-access check has no sleep, server reply wait or whole-mission scan. Its non-owner check examines that vehicle's crew. The separate quick Get In Cargo action intentionally shows a 1.5-second progress bar. These source findings do not identify the reported rendering/network stall. This fix prevents handler accumulation; a client/server timing comparison is needed to establish its effect on entry latency.

The existing AI scheduler caches player/unit/group rosters every ten seconds and serializes group/unit/agent workers. Those shared scheduling rules remain. The performance changes reduce due-counting, redundant Defense iteration, optional maneuver refreshes and cleanup bursts; they cannot establish a 20–30 FPS average without measuring the deployed AI/HC/mod workload.

### Shared query and display work

`fn_serverDetector.sqf` applies the same circular area to its supplied pool before SQF side tests. List mode preserves matching input order and duplicates; count modes avoid building a result list. Mode -1 retains the original fresh EAST census. There is no position cache or change to side/radius/height rules. This shared helper serves Primary, Defense, Grid, side tasks and proximity checks.

`fn_hcCore.sqf` starts its next 30-second dynamic-simulation maintenance interval at completion of the scan. A pass that takes longer than that interval cannot immediately start an overdue repeat. Existing entity eligibility, simulation distances, group ownership and the per-entity yield remain. This applies only where a headless client is running.

`fn_initLaserHandlers.sqf` keeps one local owner-attribution cache for 250 ms. It refreshes immediately if the observer, vehicle or side changes. Sensor queries, target selection, positions and drawing remain per-frame; newly seen lasers without a cached owner receive empty labels until refresh. The existing AI laser-ignore setting and event handler are unchanged. No gameplay targeting or strike-guidance function uses this cosmetic cache.

### Performance test boundaries

Comparable Primary/Defense populations, HC ownership and mod sets are required to assess performance. Logic checks cannot establish an FPS floor or the cause of a client vehicle-entry stall. Objective completion, Defense timers, Support cancellation and cleanup eligibility continue while optional work reduces its batch or refresh rate. The bounded holder/crate/ruin queues do not impose a new hard limit on every part of the original global cleanup census.

Tests pair sustained low FPS and recovery with repeated activity transitions, arsenal drops and notices, abandoned and deployed logistics, occupants or attached cargo, aircraft flyovers, incapacitated players, mission-object versus terrain ruins, repeated vehicle locality handoffs and moving laser labels. Existing lock/damage rules, side/count query results, HC simulation distances and native field-loot/buildable behavior remain part of the regression cases.
