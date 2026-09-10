# Invade & Annex — Performance and Gameplay Release Notes

**Full release for testing · 10 September 2026**

This is the complete set of changes from the initially supplied live mission, `Apex_framework_420th_A.Altis(1).zip`, to this release. It covers **55 modified files and four additions**. All performance, gameplay, role, radio and maintenance changes are included.

The original mission contains 2,506 files; the completed updated mission contains 2,510. The update ZIP carries the 59 changed runtime files. Original code remains commented beside its replacement in modified scripts. No external ApexCfg changes are required.

These Release Notes include the complete edited-file inventory and grouped testing scenarios. `TECHNICAL_NOTES.md` inside the ZIP contains implementation details and exact limits. **All 15 offline verifiers passed**, with 58,320 executed policy assertions, all 56 complete SQFs parsed and all 55 original files reconstructed exactly. Verification scope is recorded below; live multiplayer and performance testing remain pending.

[Performance](#performance-updates) · [Gameplay](#gameplay-updates) · [Files and testing](#files-and-testing) · [Verification](#verification-evidence)

## Performance updates

### Less repeated AI and objective work

- **Primary reinforcement counting happens when an admission is due.** Enemy, area, local-unit and group counts are deferred until an infantry or vehicle delivery can actually be considered. Creation workers still recheck capacity before spawning. Final clearance keeps its regular checks and reuses one force list.
- **Optional Primary movement updates slow down under load.** Normal refreshes are 20–30 seconds; under load they become 40–50 seconds. The owner samples load once per ten seconds. Below 18 FPS selects slower updates; normal pacing returns after 30 continuous seconds at 22 FPS or more. Existing movement, targeting and firing continue between updates.
- **Defense's normal mode-2 push iterates eligible dismounted leaders.** It retains their order and the original movement decisions while avoiding the same traversal through every rifleman. Other propulsion modes retain their traversal rules.
- **Covering fire checks inexpensive conditions first.** Cooldowns, ammunition and shooter availability are checked before searching for targets. Managed covering fire remains available at low FPS.
- **Target classification is cached by vehicle type.** Live crew, side and eligibility are rechecked. Pursuits and support requests reuse observed-target data with bounded candidate processing; they do not add a global vehicle search or reveal hidden assets.

### Cleanup that spreads its work over time

| Area | Complete change |
|---|---|
| Gear dropped near arsenals | Ground gear within 30 m gets a 30-second grace period and a private expiry notice. The notice is limited to once per 15 seconds. Transfers outside the arsenal area return to the normal field-loot rules. Inserting equipment into a crate is a separate action. |
| Logistics and deployment crates | Eligible known crates require five uninterrupted minutes without a living ground player within 1 km. The check includes registered deployment objects. A returning player resets the timer, including an incapacitated player or landed pilot; airborne flyovers do not. |
| Protected or occupied equipment | Occupants, transport attachments, vehicle cargo, ropes, motion and protection flags block retirement. A final live check precedes the existing deployment cleanup. Arbitrary Zeus objects are not adopted by a world-wide crate scan. |
| Building ruins | Destruction events queue ruins. Retirement requires at least five minutes and no living player within 500 m. Confirmed mission-object ruins can be deleted; terrain or uncertain objects are hidden with simulation disabled. Protected ruins and existing objective/buildable handling remain. |
| Background batch sizes | Low/middle/normal batches process up to 64/96/128 arsenal holders and 4/8/16 logistics crates per core pass. Ruin rotations process 4/8/16 candidates. Empty crate batches skip the ground-player scan. |
| Load recovery | Cleanup samples load every 15 seconds. Below 18 FPS uses the smallest batch; 18 to below 22 FPS limits work to the middle batch. Each upward step requires 45 continuous seconds at 24 FPS or more. Queues continue progressing under load. |
| Cleanup scheduling | The next 45-second cleanup rotation is scheduled after the previous pass finishes, preventing an overdue pass from immediately repeating. The core retains its normal three-second sleep after work. |

Deletion deadlines mark eligibility; a busy scheduler can delay actual cleanup. Hiding a terrain ruin is not a claim that its object memory has been reclaimed.

### Shared performance and vehicle fixes

- **Area detector:** applies the requested spatial area before scripted side checks. Current positions, side rules, order, duplicates and list/count results are preserved. It benefits callers across Primary, Defense, Grid and side activities.
- **Headless-client maintenance:** the next dynamic-simulation scan waits its full 30-second interval after the preceding scan completes. Entity eligibility, simulation distances and ownership rules retain their existing settings.
- **Laser display:** cosmetic owner labels are cached for 250 ms and refreshed immediately when the observer, vehicle or side changes. Sensor targets, positions and drawing remain current each frame. Strike guidance does not use this display cache.
- **Spawn Menu vehicles:** a valid damage-handler ID survives a return of locality, preventing duplicate damage callbacks during ownership handoffs. Missing handlers can still be repaired. Vehicle locks, ownership permissions, damage calculations and empty-vehicle protection retain their rules.
- **Insertion and search work:** spawn/entry searches, parachute monitoring, rappel helpers and departure cleanup have finite limits. No AI-rappel Game Logic is created, and owned temporary objects and callbacks are cleaned up.

These are reductions in redundant work and accumulated state. This release does not claim a measured FPS increase, a fix for every server freeze, or a change to database queues, AI simulation distances or the existing shared AI scheduler. The separate quick Get In Cargo action retains its 1.5-second progress bar.

## Gameplay updates

### 1. Sustained Primary AO reinforcement

The original automatic Primary reinforcement used an 85-enemy admission threshold. The update replaces that control with full squads, population-based pacing, objective reductions and shared personnel reservations. Initial enemy populations remain as supplied; survivors are not deleted when the ceiling falls.

**Nearby conscious WEST ground players** choose Primary strength. Ground vehicle crews count; aircraft occupants, headless clients and players elsewhere do not. The census covers the AO plus 600 m.

| Nearby ground players | Regular squad | Reinforcement opportunity | Initial reinforcement ceiling | Local replacement vehicle limit |
|---|---:|---:|---:|---:|
| 1–2 | 8 | 8–10 minutes | 24 personnel | 0 |
| 3–8 | 8 | 8–10 minutes | 40 personnel | 0 |
| 9–15 | 8 | 2–3 minutes | 64 personnel | 1 |
| 16–30 | 10 | 30–60 seconds | 96 personnel | 2 |
| 31+ | 12 | 6–10 seconds | 120 personnel | 3 |

- Normal reinforcement has no lifetime delivery quota while objectives remain. These intervals are admission opportunities; capacity, terrain, FPS and travel determine arrival times.
- Infantry, vehicle/aircraft crews, mortar gunners, UAV crews, pilots and reserved arrivals consume the shared personnel allowance. A hull is not counted as another person.
- Regular squads contain 8–12 soldiers. If fewer than eight places are available, the controller waits. A smaller full squad keeps the tier's full interval.
- The first regular admission waits at least the tier's minimum interval after ground contact. The opening and FPS-recovery gates also apply.
- When conscious ground turnout reaches zero, new regular admissions pause. Returning players do not trigger accumulated catch-up waves. Dropping to a slower tier grants its minimum breathing room.
- New admissions pause below 18 FPS and resume after 30 continuous seconds at 22 FPS or more. Existing local/global limits remain. This does not remove a living over-cap force.

For example, 22 connected players with only four to six fighting on the ground still use the eight-man, 8–10-minute, 40-person tier.

### 2. Objectives reduce the enemy's remaining capacity

Each completed strategic objective removes **20 percentage points** from the original reinforcement ceiling. At the busiest tier, that is 120 → 96 → 72 → 48 → 24, with normal admissions stopped when the last actual objective is completed. A four-objective AO reaches zero on its fourth completion.

| Objective/event | Released effect |
|---|---|
| Commander/HQ, Radio Tower and other actual strategic objectives | Reduce the reinforcement ceiling. Guards whose own objective falls move to another surviving objective. |
| Supply Depot | Reduces launcher threats in newly created infantry, including launchers introduced by mapped loadouts. Existing depot effects continue. |
| Datalink | Stops new UAV replacements and removes one-third of the original coordinated artillery allowance. |
| Commander and Radio Tower | Each removes one-third of that original artillery allowance. |
| Mortar Pit | Becomes complete when its registered mortars have no living hostile gunner; receives a search-area marker so it is not an unmarked required objective. |
| Jammer | Retains GPS restoration and contributes to the reinforcement reduction. |
| Final objective | Normal reinforcement streams end and eligible survivors regroup. |
| Objective and clearance notifications | Original mission notifications and task updates remain. |

The supplied Altis generator does not spawn a separate Vehicle Depot. Its conditional armor gate applies only if such an objective is present. Supply loss does not introduce a new aircraft-rearm cutoff, and Radio Tower loss does not introduce a blanket stop to every aircraft stream.

### 3. Default Taru insertions and more visible arrivals

Taru deliveries are built into Primary and Defense. **Connected human population**, excluding headless clients, selects the delivery policy; this is separate from Primary's nearby-ground-player strength tier.

| Connected players | Delivery policy | Concurrent flight jobs | Minimum launch spacing |
|---|---|---:|---:|
| Fewer than 20 | 90% Taru preference when capacity and terrain permit; waits through the flight cap/cooldown | 3 | 45 seconds |
| 20 or more | At most 12.5% of admitted regular infantry delivered by Taru | 1 | 4 minutes |

At higher population, seven squads' worth of ordinary admitted infantry funds one Taru squad. A destroyed transport still spends its allowance. The counter resets after a lift and when population crosses 20, preventing banked consecutive lifts. Flights already underway can finish after a population change.

Each Taru carries **one normal admitted squad**. Most use a moving parachute pass at 180–220 m; 10% request a 25 m rappel where terrain and the helper allow it. Passengers and pilots consume existing personnel allowances; this is not an extra force stream. The direct parachute/ground fallback and Defense's existing scripted HQ paradrops remain.

The moving rappel release works inside the drop-zone/altitude gates. AI descent increases from roughly 3.5 to a fixed 5 m/s; release attempts shorten from 1 to 0.6 seconds and use up to six rope anchors. The old precise settling wait is removed; player descent retains its existing behavior. Construction, approach, dismount, descent and departure have ownership and time limits. Late callbacks cannot reopen a finished delivery; cleanup respects active players/Zeus control. Landing-group detection handlers are attached once per group. Retiring transports depart before deferred collection instead of being destroyed near players at a waypoint or timeout.

Before AI release, the actual rope position and descent footprint must clear players, ground troops, vehicles, obstacles, water, steep terrain and overhead geometry. A blocked anchor can fall through to another of the six available anchors. Landed AI receive one bounded move-clear order when a safe nearby destination is available, helping clear space for the next soldiers. These checks run in the existing release worker.

If every available rope position is unsafe before the first release, an automatic Taru can climb normally to its parachute height and retry through the existing parachute gates. That fallback has one bounded window. After a rope release begins, the helicopter keeps the rappel mode; passengers whose release stays unsafe remain aboard for departure.

Wind calibration runs once per Primary/Defense, for up to 150 seconds, then reuses a correction capped at 100 m. It adjusts later delivery positions rather than steering parachutes in flight.

### 4. Squads respond to observed contacts

Primary mobile squads now defend separated approaches and respond to reported contacts. Initial patrols retain their routes until activated; some continue patrolling and reporting. Dedicated objective guards stay with their objective and fall back when it is secured. HVT/Medevac and unrelated groups retain their tasks.

At more than eight conscious ground players, eligible whole-squad allocation is roughly **60% contact pressure, 20% hunters/casualty response and at least 20% defense/patrol**. These are maximum allocations. Through eight players there is at most one contact-response squad, no hunters, and a reserve group remains.

- Contact destinations come from actual AI sightings. There is no scripted reveal or live player-position feed for pursuit destinations.
- A local response can use up to two advancing squads and one supporting squad. Ordinary isolated infantry can attract one hunter when turnout and reserves permit.
- Squads are borrowed intact, with at least eight regular infantry or a qualifying six-to-nine-member Viper team. Vehicles require a squad with usable ground-attack ammunition.
- Contact and casualty dispatches share a 20–40-second interval. No extra AI is created by these assignments.
- Pursuits have fixed reported sectors, up to a 300-second lifetime and a 75-second sighting timeout. Lost or returned response squads do not refund an incident's spent commitments.
- Non-snipers use standing stance and FULL movement. No animation-speed or running-speed multiplier is added.

### 5. BLUFOR asset priority and support-role isolation

Primary pursuit, Defense flanks and enemy artillery/mortar/CAS/UAV support selections prioritize eligible known ground targets in this order:

| Priority | Target |
|---|---|
| 1 | Anti-air assets |
| 2 | Artillery, excluding mortars |
| 3 | Tanks |
| 4 | Other mechanized/motorized ground assets |
| 5 | Infantry |

Human, AI and autonomous crews qualify. Empty, dead or non-BLUFOR assets do not become combat targets just from their vehicle class. Mortars are excluded from these deliberate selections. Close combat and native self-defense remain active.

AA/artillery can use the existing single Primary contact response at low turnout. Higher-priority observed contacts can take over a suitable existing response: Primary at its normal dispatch cadence, Defense after the new position passes its dwell/sighting/weapon checks. This reuses squads within the same limits. Queued aircraft support and helicopter reselection also enforce eligibility and priority.

**JTAC, Forward Observer and Mortar Gunner infantry do not attract scripted stalking when no other living real player is within 500 m horizontally.** Exactly 500 m counts as company. Living incapacitated players and vehicle occupants count; AI, headless clients and dead players do not.

Existing pursuits recheck on the normal Primary 10-second and Defense 15-second cycles. Protected targets drop out; a squad returns when no eligible target remains. A mixed contact can continue against other targets. Operating AA, artillery, a tank or another vehicle does not give that vehicle the role exemption. The exemption concerns stalking; ordinary combat, final HQ defense, casualty-area responses and enemy support requests retain their rules.

### 6. Resistance around reported casualties

Existing squads can secure the area around recently reported incapacitations, making a rescue encounter more than an unopposed revive. The original revive targeting protection remains; these squads are not ordered to shoot unconscious players.

| Ground turnout, including downed players | Maximum casualty-response squads across the AO |
|---|---:|
| 0–8 | 0 |
| 9–15 | 1 |
| 16–30 | 2 |
| 31+ | 3 |

The shared allocation also requires more than eight conscious ground players. One to two casualties can justify one squad; three to four can justify two; five or more can justify three, within the AO-wide limit and available reserves.

The response needs a recent sighting, a full nearby reserve/screen squad and another squad remaining at its objective. It uses a fixed reported point for up to 120 seconds. Revive, death, disconnect, extraction or leaving that area reduces or ends the response. Dragging or carrying the casualty does not move the AI destination. The same incapacitation is recorded once; destroying the response does not summon replacements.

### 7. Enemy artillery and Primary mortar fire

At Primary start, coordinated artillery receives a fixed budget and schedule:

| Connected WEST players at AO start | Budget selection |
|---|---|
| Below 25 | 3 fire-mission opportunities |
| 25–30 | 75% chance of 3; 25% chance of 6 |
| Above 30 | 60% chance of 3; 25% chance of 6; 15% chance of 9 |

After a 90-second opening grace, randomized windows span 15 minutes. Population changes do not reroll them. Missed windows expire. The Commander, Radio Tower and spawned Datalink each remove one-third of the original allowance; already started missions count against the reduced total. Completing all actual objectives removes all unused opportunities.

New coordinated missions require more than eight conscious nearby ground players, a valid reported target, an available physical provider, an unused scheduled allowance and healthy FPS. An already admitted salvo can finish when an objective falls.

Primary mortars now accept eligible reported ground targets inside the AO and up to 500 m beyond it, using the new priority. Reports must be at most 30 seconds old. Aim is fixed to that report for the salvo:

- **9–19 nearby ground players:** four shells; **20+:** six shells, capped after the original concentration bonus.
- Initial scatter is 45 m, tightening with the existing random behavior to a 25 m radius floor. This does not guarantee a minimum miss distance.
- Busy-population cooldowns are 75–120 seconds at 20–39 ground players and 60–90 seconds at 40+; below 20 they remain 360–720 seconds.
- Base/side-task exclusions, water, weapon range and a 75 m friendly-AI safety check still apply. Rejection spends neither a Primary opportunity nor its gunner cooldown.

Warnings, physical shells, ammunition and normal damage/revive rules remain. Defense and ordinary default salvos retain their tuning. The new ground-target priority also applies to revised enemy support-request paths outside this Primary mortar tuning.

### 8. Final Primary clearance

Completing the last objective stops normal reinforcement, new UAV replacements and coordinated artillery. Eligible garrisons and mobile survivors gather around HQ; finished inbound squads complete their insertion.

Rare regional reserves are possible only above 15 conscious ground players. They use a 15% opportunity roll after 90–150 seconds, at most three admissions, and a shared personnel ceiling of 19 at 16–30 players or 24 at 31+. At most one armor and one rotary admission are possible. Existing force, reservations, toggles and FPS limits still apply.

Once clearance begins, final reserves close for that AO. Success requires **all objectives complete, no incoming delivery and fewer than ten hostile ground personnel for 15 continuous seconds**. Aircraft are not a mandatory air-to-air cleanup objective. Primary retains no wipe failure or overall time limit.

### 9. Defense selection and flanking

Normal Defense selection rises from **33.3% to 66.6%**. The former cutoff after four Defenses above 60 players is removed. Existing eligibility gates remain.

With at least ten eligible nearby human ground players and four ordinary assault groups, Defense can borrow approximately 5% of its squads, capped at **two**, to flank reported positions outside HQ. Targets must dwell for 45 seconds within a 75 m anchor, normally 400–2,000 m from HQ. The new asset priority and isolated-role exemption apply.

Only full suitable squads are borrowed; mounted targets require ground-attack ammunition. The response uses observed positions, fixed approach bearings, native navigation and a maximum 300-second assignment. Lost reports, excessive movement, invalid ownership or activity end release the squad. A higher-priority valid position can take over the same squad on the normal 15-second pass. Low FPS stops new assignments/movement updates while release and cleanup continue.

Defense retains its **existing infantry/vehicle caps, wave sizes, vehicle cadence, artillery timing and 15–22.5-minute duration**. Taru delivery uses its normal infantry allowance. Explicit waypoint propulsion mode 5 keeps its original movement ownership and receives no new flank assignment.

**Included bonus, manual activation only:** `code/scripts/IA_MegaDefense.sqf` stays in the regular mission folders. The mission does not invoke it automatically; Zeus/Admin can call it from the Dev Console, and the owner may connect a separate scheduler later. No reset schedule is configured.

When called, the **manual 30-minute Defense** forces the current Classic Primary AO into Defense at its existing HQ, without waiting for objective completion. The controller retires the unfinished Primary activity and keeps the HQ for Defense. Unfinished tasks do not receive completion credit. If Defense is already running, the request gives that event at least 30 minutes remaining, updates its timer and sends all clients a Crossroads message and hint. A newly forced Defense gets the same announcement and a 30-minute timer from its actual start. Repeating the trigger while this mode is active does not stack more time or refill Support stock. HQ loss and administrator cancellation can still end the battle early. The normal force limits and wave behavior remain; this mode cannot enter automatic overtime. The server command and future scheduler entry point are included later in these Release Notes.

### 10. Ground spacing and covering fire

Outdoor infantry and ground-vehicle spawners use a shared **85 × 85 m** footprint with an initial 25 candidate cells and a **15 m separation target**. Squads spread across the available space. Infantry retain 15 m separation from other troops and reservations. A failed initial layout tries three staggered patterns within the same approved area, for at most 81 candidates. No cells are reused and no occupancy checks are relaxed; insufficient space rejects the complete layout before spawning. Vehicles retain distinct clear positions. Player proximity, water, routes, terrain and claimed footprints remain part of admission.

Defense must find a valid spawn center and validate every infantry slot against its existing player, HQ, blacklist and water exclusions. Sector infantry filling stops after 24 attempts if terrain cannot admit enough squads. Shared patrol/attack and AO/FOB callers safely skip rejected groups, avoiding empty-group errors or an endless retry loop.

This reaches Primary/Defense outdoor forces, Grid patrols and attacks, ambient infantry/paired vehicles, outdoor Kavala/Georgetown patrols, native ground reinforcements and mobile medical/repair supports. Deliberate compositions, building garrisons and airborne release positions retain their own placement. This is spawn spacing, not a guarantee that pathfinding preserves a formation.

Mobile building-position searches in Kavala and Georgetown stop after 40 attempts and seek 15 m separation from nearby foot units. Failed searches can exit without trapping the mission timer. The native rotary entry search is bounded to 24 candidates and can return an empty roster when no valid entry is found.

Primary and Defense squads now provide outgoing covering fire while squadmates move. Up to two shooters are selected through eight conscious ground players; above eight, a full squad can use four. MGs are preferred. Bursts/cooldowns are 4–6/60–90 seconds at small turnout and 8–12/24–36 seconds above eight, subject to the existing scheduler.

Fire requires ammunition, a recent observed conscious player on foot, a 60–500 m range and a clear friendly lane. It uses native weapons and the reported position. Managed covering fire remains eligible at low FPS; no ammunition refill, forced hit or new burst worker is added. The old suppression callback also resolves its own group correctly.

The new Primary controller bypasses separate legacy automatic Classic Viper top-ups. Remaining native Classic/sector opportunities below 25 connected humans require more than eight nearby conscious ground players, no existing team and a 1% roll; a new low-population team contains six. Existing Vipers remain. Low-population native helicopter requests substitute regular CSAT for default Viper cargo, while supplied passengers retain their units.

### 11. Enemy aircraft

- Ambient jets have independent groups. A managed flight owns its movement so ground-support orders and interception orders do not fight each other.
- Installed weapons distinguish CAP from CAS. CAP remains outside requested ground fire; original aircraft classes and loadouts remain.
- Known airborne threats use a separate **80% combat aircraft / 20% transports** preference when both are eligible. Armed transports can qualify as combat aircraft; door guns alone do not.
- Valid combat commitments are stable; transport pursuits are reconsidered every 12 seconds. Known combat aircraft and recent attackers remain eligible during routine ground-priority/egress intervals.
- Accepted ground passes own their helpers until cleanup. Helicopter, plane and UAV requests recheck eligibility; cancellation preserves newer requests and releases owned state.
- Managed countermeasures use installed launchers and actual ammunition, with a three-second throttle. Incoming missiles can withdraw a ground pass through its cleanup path.
- Rotary and fixed-wing aircraft have bounded departure/ground-request cooldowns. Native sensing, flight, firing and ammunition determine effectiveness.

### 12. Forward Observer and JTAC

**Forward Observer gains one role slot**, using the configured JTAC gear and Arsenal access. Its `0 > 8 > Artillery Order` menu provides HE, laser/IR guided shells, ICM and HE rockets. JTAC gains `Airstrike Order` with three fixed bomb profiles and one bomb per request. Both finish with **Request Fire Mission** confirmation.

| Forward Observer stock | Primary at 10 or fewer connected humans | Primary at 31+ | Defense at 31+ |
|---|---:|---:|---:|
| 155 mm HE | 8 | 16 | 32 |
| Laser/IR guided shells, shared pool | 2 | 4 | 8 |
| ICM cluster | 1 | 2 | 4 |
| 230 mm HE rockets | 2 | 4 | 8 |

From 11–30 connected humans, Forward Observer stock interpolates to the full allowance, rounded to whole rounds. Defense doubles the resulting allowance.

| JTAC stock per authorized slot, at every population | Each Primary | Each Defense |
|---|---:|---:|
| Mk82 unguided | 3 | 6 |
| GBU-12 laser guided | 2 | 4 |
| CBU-85 laser-guided cluster | 1 | 2 |

The supplied configuration has three JTAC slots. Vacancies reserve equal shares; they do not donate ammunition to occupied slots. Slot and player spending survive role swaps, respawns and reconnects. Added slot capacity waits for the next activity's issued stock. New stock is issued at Primary/Defense start, not by side tasks or Kavala. New Forward Observer/JTAC requests require an active Primary or Defense.

Each service allows one active mission: 1–8 rounds for Forward Observer, or exactly one bomb for JTAC. JTAC skips the volley/round-count menu. Red illumination has been removed from Forward Observer.

The accepted request starts a single server timeline. Broadway privately acknowledges the requester, then announces the fire mission to all clients after **10–12 seconds**: **“{role} Fire Mission requested at grid {grid}. Payload {payload}. Time to target {seconds} seconds.”** The payload includes its type and quantity.

The planned final impact/completion is **20–25 seconds after acceptance**. The public time to target estimates the first impact from the announcement; the full volley finishes on the later completion estimate. Forward Observer rounds release 0.5 seconds apart, scheduled backward from the final impact estimate so even a full eight-round volley fits the intended window. JTAC releases one bomb. Temporary blue marking and smoke precede the strike; private updates report release, completion or cancellation. Physical projectile travel, guidance and server scheduling still need live timing verification.

The provider creates attributed vanilla projectiles without spawning a battery, crew or aircraft flyby. Laser profiles need a friendly designation within 50 m of the chosen point; IR shells need a known hostile crewed vehicle within that radius. These are rechecked before each release. Applicable unguided profiles offer 0/25/50/100 m dispersion; guided and cluster profiles use zero added dispersion. The release exclusion is **175 m plus selected dispersion** from every living human, including unconscious players and vehicle occupants. Existing safe-zone/Robocop checks apply.

Role loss, death, incapacitation, remote control, activity end or timeout cancels unfired work. During the same activity, cancellation refunds only unreleased rounds. Ending or changing the activity closes its allowance; nothing carries into the next activity. Existing base/destroyer/context-menu artillery remains a separate system. Other roles gain no new Support actions.

### 13. Mortar Gunner

The Support menu adds **Request Mk6 Mortar**, **Request Mortar Resupply** and **Reset Mortar Section**. Up to three owned Mk6 mortars are allowed per gunner, each starting with eight HE rounds and no smoke/illumination. The lightweight Deploy Mortar action shares that ownership and inventory limit.

Mortar requests and resupply have separate ten-minute cooldowns. Inventory-based lightweight Deploy Mortar consumes a tube and neither request cooldown. A resupply crate parachutes to a valid location within 500 m with five tube backpacks. It does not supply general vehicle ammunition. Reset removes owned mortars/crates without resetting either cooldown.

Only Mortar Gunner roles can occupy these Support mortars. Native rearm/disassembly actions are disabled on them. Role departure, death/respawn, disconnect, destruction or exceeding 500 m retires owned equipment. Nearby incapacitation preserves equipment for a possible revive, and equipment that remains valid may persist between activities. Occupants are ejected before deletion; placement, descent and late acknowledgments are bounded.

The original two-backpack Assemble path and Zeus-placed mortars remain separate. Their ammunition and ownership do not count against these Support sections. With the supplied three Mortar Gunner slots, up to nine Support-owned mortars are possible.

### 14. Revive, Kavala and damage attribution

- Normal unattended bleed-out changes from **ten minutes to four minutes**. Existing vehicle/extraction extensions and requested medevac timing remain.
- Altis custom-mission selection permits Kavala above 36 players, and Kavala no longer exits above 45. Its existing frequency/minimum/random gates remain; Georgetown's population gate is unchanged.
- During Kavala setup, activity and evacuation, pilots use normal incapacitation. The state covers new joins, respawns and role changes, and clears when its owning mission ends or is interrupted. Already downed players are not killed when that override ends.
- Kavala evacuation has a 180-second bound and handles empty/single-player cases. Owned mission objects return through discreet cleanup; protected/occupied objects remain. Hidden-building restoration is handled per object when clear, replacing an indefinite whole-area wait. Tablet progress, troop ratios and the existing intel mission design are not new changes in this release.
- JTAC, Forward Observer and Mortar Gunner use normal incapacitation, with Support menus suspended appropriately.
- Commander death completion works once on the server for the current Commander despite Zeus ownership changes.
- Friendly-fire warnings, Robocop, damage scaling and casualty messages share a tighter physical-attacker resolver. Existing Zeus/remote-control attribution is checked against the actual firing unit and controller relationship. Friendly AI still identifies its controller for penalties; unrelated passengers and environmental damage do not gain a blanket Zeus exemption.

### 15. Radio and BLUFOR AI speech

| Channel/system | Complete released behavior |
|---|---|
| Side | A custom channel in native blue, shared across teams, subscribed by default. Players can opt out. The saved choice survives respawns, reconnects and normal server resets with the same local profile. |
| General | Mandatory membership. Public text; voice restricted to authorized admin/Zeus users, subject to existing masks. Death retains membership and respawn transfers it to the new body. |
| Staff | Existing private membership/access remains separate. |
| Native Side sending | Closed to player transmission. Scripted Crossroads announcements retain the mission's existing route. |
| Radio lifecycle | Initialization, late whitelist changes, team/group changes, respawn and High Command use one reconciler. Stable checks avoid repeated membership/permission writes. |
| BLUFOR AI speech | Automatic voice, radio text/reports and conversations are silenced for non-player BLUFOR AI, including Zeus/JIP units. Movement, orders, player VOIP and mission announcements remain available. Locality reapplication and player takeover use the existing lifecycle hooks. |

The Side channel needs the extended custom-channel capacity used by Arma 3 2.22+. Real channel selection, cross-team VOIP, JIP and saved preferences remain multiplayer test cases.

## Files and testing

Every runtime path below is relative to the mission root. The inventory covers all 55 modified files and four additions.

### Complete-file testing bundles

| Bundle | Files | What belongs together |
|---|---:|---|
| Gameplay | 46 | Controllers, spawners, fire missions, insertion, Supports, revive and shared core cleanup. The complete delivered files are a combined Gameplay candidate. |
| Radio | 7 | Allocation, subscription UI, membership, authorization and lifecycle changes. Test all seven together. |
| BLUFOR AI speech | 2 | Speech application and its existing registration/JIP/respawn coverage. Test the pair together. |
| Spawn Menu vehicle handlers | 1 | Standalone duplicate-damage-handler/locality fix. |
| Shared performance | 3 | Area detector, HC deadline and laser-owner display cache; each is independently testable. |
| **Combined release** | **59** | All runtime files for the complete activity and multiplayer test. |

Independence describes source dependencies against the supplied original mission and existing configuration. It does not mean those isolated combinations have been tested on a live server. Radio remains separate: its `fn_config.sqf` and respawn changes do not add new Support/Kavala dependencies.

### Focused Gameplay scenarios

G1–G11 are related behavior checks within the **46-file Gameplay candidate**. Their file lists overlap because a complete shared file contains multiple features. A scenario list is not a smaller independently installable patch. The exact complete-file inventory follows the scenarios.

Bare `fn_*.sqf` names in scenario lists are under `code/functions/`; paths with a directory are already relative to the mission root.

#### G1 — Primary strength, objectives and final clearance

**Related edited files:** `fn_AI.sqf`, `fn_aoEnemy.sqf`, `fn_aoSubObjectives.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_spawnGroup.sqf`, `fn_aoEnemyReinforceVehicles.sqf`, `fn_scSpawnHeli.sqf`.

1. Exercise 1–2, 3–8, 9–15, 16–30 and 31+ conscious ground players. Include many connected pilots/base players with only four to six ground players. Expected squads/intervals/ceilings are 8/8–10 min/24; 8/8–10 min/40; 8/2–3 min/64; 10/30–60 s/96; 12/6–10 s/120.
2. Kill troops to create capacity, including crews and inbound reservations. A regular delivery needs at least eight free places. Initial over-cap survivors remain; one worker and existing local/global limits prevent overlapping admissions.
3. Remove all ground players, return, and cross into a slower tier. No delayed-wave burst or partial squad appears. Hold low FPS and recover; new admissions follow the 18/22-FPS recovery rule while existing combat continues.
4. Complete objectives in different orders. Each reduces the original ceiling by 20 percentage points. Supply strips future launchers; Datalink stops new UAV replacement. Check original native objective/task/clearance notifications without the added controller chat, and the marked Mortar Pit. No extra Vehicle Depot is expected in the supplied Altis generator.
5. At the last objective, check guard fallback/HQ rally, pending insertion completion and rare final reserves only above 15 conscious ground players. Fewer than ten ground hostiles plus completed objectives/no incoming delivery must persist for 15 seconds. Clearance closes final reserves instead of reopening the fight.

#### G2 — Observed pursuits, asset priority, isolation and casualties

**Related edited files:** `fn_AI.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_AIFireMission.sqf`, `fn_aoDefend.sqf`, `fn_aoEnemy.sqf`.

1. Compare no sighting, a fresh actual sighting and expired intelligence. Response destinations must follow the reported position, with no reveal or hidden-player tracking. Dedicated guards, HVT/Medevac and unrelated groups retain their tasks.
2. Present simultaneously known AA, non-mortar artillery, tank, APC/IFV, truck and infantry; repeat with AI crews, human crews and autonomous AA. Expected order is AA → artillery → tank → other ground vehicles → infantry. Empty/dead/non-WEST assets and mortars are excluded from deliberate selection.
3. Include actual production mod vehicles, especially tracked AA/artillery sharing Tank ancestry, tracked APCs and mounted mortars. Introduce AA after many known infantry/crew records so candidate truncation cannot hide its priority.
4. For each JTAC/JTAC WL, Forward Observer and Mortar Gunner, establish an active pursuit and move the last other living real player to 499/500/501 m horizontally. Exactly 500 m counts as company. Living incapacitated companions and vehicle occupants count; AI/dead/HC companions do not. Primary rechecks at 10 seconds; Defense at 15 seconds.
5. Repeat with the isolated role operating AA/artillery/armor: the vehicle remains eligible. Mixed contact jobs may keep other targets. Ordinary combat, enemy support requests and casualty-area responses retain their eligibility.
6. At eight or fewer conscious ground players, confirm at most one Primary contact squad and no hunters; known AA/artillery may use that one response. At higher turnout verify whole-squad allocations, suitable AT ammunition and no new spawn stream. Introduce a higher-priority contact during a lower-priority response; the same suitable squad can transfer within the normal dispatch quota.
7. Down one/two, three/four and five or more players near a reported point. Check the AO-wide 0/1/2/3 casualty-squad limits, spare-defender requirement and 120-second incident. Revive/extract/move casualties: the destination must not follow them, old incapacitations must not restart, and killed response squads must not be refunded.

#### G3 — Defense selection, HQ pressure and flanks

**Related edited files:** `fn_aoDefend.sqf`, `code/scripts/IA_MegaDefense.sqf`, `fn_core.sqf`, `fn_AI.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_spawnGroup.sqf`.

1. Check eligible Defense selection and the former four-Defense/high-population cutoff. The configured roll is 0.666; it is not a guarantee that every second activity becomes Defense. Ordinary Defense retains its existing eligibility,15–22.5-minute duration, caps, wave sizes and vehicle/artillery timing. The optional manual 30-minute mode is tested separately below.
2. With ten eligible nearby ground players and at least four ordinary assault groups, leave an observed infantry/vehicle position 400–2,000 m from HQ for 45 seconds within a 75 m anchor. Expect no more than two borrowed full squads, with most assault force still pressuring HQ.
3. Exercise insufficient turnout, moving targets, no sighting, lost reports, missing AT ammunition, base/side exclusion, leash and expiry. Low FPS stops new flank decisions/moves but permits release. Test propulsion modes 1–4 and confirm mode 5 retains waypoint ownership without new flank assignments.
4. Fill the flank quota with a lower-priority target, then present a higher-priority valid camp. One suitable squad may transfer at the existing 15-second pass after dwell/freshness checks; simultaneous quota must not rise. Its replacement job has the normal 300-second lifetime.
5. Check mode-2 leader-only traversal and active covering shooters. Riflemen continue following while borrowed groups and shooters keep their appropriate task ownership.
6. Leave the bonus script uncalled through several Primary/Defense cycles: no 30-minute event or reset trigger should occur automatically. Ordinary Defense duration and selection must remain in effect.
7. Trigger during a fresh Primary grace period, with Commander/radio/sub-objectives still active, near normal clearance, and at an HQ whose normal Defense flag is disabled. The current activity must hand over to one 30-minute Defense without waiting for objectives, granting false objective/AO credit, deleting its HQ or starting another Primary. Repeat the trigger and try each native force mode; its stored setting must survive the special event.
8. Trigger during running Defense, including native overtime: the task timer must show at least 30 minutes remaining and the final-minute warning must move accordingly. One Crossroads side-chat message and one hint must reach clients after actual start/extension. Repeating the trigger cannot stack time, repeat the announcement or refill Support stock.
9. Test client execution, unsupported mode, no usable HQ, cleanup and an expired Defense. Interrupt the forced handoff and simulate missing Primary deinit acknowledgement: the bounded wait must not create overlapping controllers. Complete30 minutes, lose HQ earlier and use existing administrator cancellation; native results and cleanup must run. blockTimeout cannot append overtime to this mode.

#### G4 — Automatic Taru, parachutes, rappel and insertion cleanup

**Related edited files:** `fn_AI.sqf`, `fn_aoDefend.sqf`, `fn_AIXHeliInsert.sqf`, `fn_AIXHeliInsertLanding.sqf`, `code/scripts/AR_AdvancedRappelling_ext.sqf`, `fn_spawnGroup.sqf`.

1. Test below 20 connected humans and at/above 20, including the transition while aircraft are in flight. Low population uses 90% Taru preference, at most three flight jobs/45-second launch spacing. High population allows one job/four-minute spacing and at most 12.5% of admitted regular infantry.
2. At high population, verify seven squads’ worth of ordinary admissions before a lift. Shot-down aircraft still spend the allowance. Crossing 20 resets the counter; in-flight low-population lifts can finish without funding further busy-population lifts.
3. Count existing admitted squad plus pilot against Primary/Defense capacity. One Taru carries one squad. Saturated aircraft capacity waits appropriately; blocked terrain can prevent a lift. Existing Defense HQ paradrops and non-Taru fallback still work.
4. Exercise moving parachute passes and 25 m rappel requests; verify AI descent, real dismount, no mid-flight cargo creation and final HQ/objective orders only after delivery, with interim move-clear orders for landed rappellers. Test the first wind calibration, failed test timeout, frozen correction and next activity reset.
5. Kill the pilot, destroy/damage the aircraft, interrupt approach or rappel, finish/change the activity during construction, and take over as player/Zeus. Check server/HC logs and bounded scripts, ropes, helpers, chutes, late callbacks and group detection handlers. Departures must respect remaining occupants and nearby players.
6. Obstruct actual rope anchors with trees, buildings, vehicles, ground AI or nearby players; vary slope, water and helicopter drift. A clear alternate anchor must be used. Fully blocked first release may take one bounded normal climb to parachute height, preserving the existing altitude gates; after any rope release, no parachute-mode switch is allowed.
7. Rappel a full large squad: landed members must receive a bounded move-clear order so later soldiers can use the anchors. Exercise blocked egress, all anchors occupied and later obstruction; unsafe passengers remain aboard on timeout. Player/Zeus/locality takeovers must prevent scripted egress, and no extra egress worker persists.
8. Test native insertion callers as well as the automatic Taru route. A successful automatic lift does not cover late native landing callbacks, anchor reuse or departure cleanup.

#### G5 — Enemy aircraft and support-request ownership

**Related edited files:** `fn_AI.sqf`, `fn_enemyCAS.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_AIFireMission.sqf`, `fn_AIXMissileCountermeasure.sqf`, `fn_scSpawnHeli.sqf`.

1. Use several jets at once and mix CAP/CAS tasks. Each flight must retain its own group/orders. CAP must not accept ordinary ground-fire requests; actual installed weapons determine role.
2. Offer known combat aircraft and transports, including armed transports and door-gun-only aircraft. Check separate 80/20 class preference, valid combat commitments, transport reconsideration and recent-attacker response.
3. Queue ground support during interception, departure and activity change. Helicopter reselection must retain the ground-asset order and mortar exclusion. Change target side/occupancy/life or board a mortar after request: stale requests should release their own helpers and preserve any newer request.
4. Exercise helicopter, plane and UAV admission/cancellation. Incoming missiles withdraw managed ground passes through cleanup; actual installed countermeasure ammunition is consumed with the throttle. Known combat threats remain eligible during ordinary egress/ground cooldown.
5. Check blocked native rotary entry positions and correct empty-return handling. Compare pilot death/flight cleanup and final Primary handoff; no shared jet group or stale movement ownership should remain.

#### G6 — Enemy artillery budgets and Primary mortar salvos

**Related edited files:** `fn_AI.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIHandleUnit.sqf`, `fn_AIFireMission.sqf`.

1. At AO start use connected WEST populations below 25, 25–30 and above 30. Confirm fixed 3/6/9 opportunity selection, opening grace and windows. Later population changes must not reroll or recreate expired windows.
2. Complete Commander, Radio Tower and actual Datalink objectives before/after missions start. Each removes one-third of the original allowance. An admitted salvo can finish, but already-started missions still consume the reduced total.
3. Test eight/nine, 19/20 and 39/40 conscious ground players. Confirm no new coordinated mission through eight; four shells at 9–19, six at 20+, correct cooldowns and no concentration doubling beyond six.
4. Use fresh/stale reports, a moving target after observation, the new asset priority, a mortar candidate, unsafe friendly-AI proximity, water and base/side/range exclusion. Aim freezes to the accepted report; rejected requests spend neither a Primary opportunity nor its gunner cooldown.
5. Compare Defense/default mortar calls and helicopter/plane/UAV fire missions: their separate tuning/provider rules remain. Check actual warnings, shell impacts and reduced-damage/attribution behavior in the production modset.

#### G7 — Outdoor spawn spacing and low-population specialists

**Related edited files:** `fn_spawnGroup.sqf`, `fn_aoEnemy.sqf`, `fn_aoDefend.sqf`, `fn_spawnViperTeam.sqf`, `fn_gridEnemy.sqf`, `fn_gridSpawnPatrol.sqf`, `fn_gridSpawnAttack.sqf`, `fn_ambientHostility.sqf`, `fn_missionGeorgetown.sqf`, `fn_missionKavala.sqf`, `fn_scSpawnLandVehicle.sqf`, `fn_scEnemy.sqf`, `fn_taskPatrol.sqf`, `fn_taskAttack.sqf`, `fn_fobEnemyAssault.sqf`, `fn_aoEnemyReinforceVehicles.sqf`, `fn_spawnSupport.sqf`, `fn_AIXHeliInsert.sqf`.

1. Compare open terrain, roads, slopes, tight towns and blocked squares. The shared footprint is 85 × 85 m with a 15 m separation target; infantry must keep 15 m separation and use complete layouts. Failed first passes try three staggered patterns within the same footprint, at most 81 candidates; no exact-cell reuse or occupancy relaxation. Vehicles retain complete distinct layouts.
2. Spawn multiple groups rapidly, include wrecks/empty hulls/airborne vehicles and place players near footprint edges. Check short reservations, native route/base/player exclusions and no invalid partly created vehicle group.
3. Repeat across Primary, Defense, Grid patrols/attacks, ambient paired vehicles, native armor patrols/reinforcements and mobile medical/repair supports. Building compositions and airborne releases should keep their intended placement.
4. Exercise Kavala/Georgetown mobile building replacements with blocked positions; bounded attempts must exit without trapping activity progress. Check outdoor AA/sniper/AT replacement callers. Exhaust Defense center searches and reject blacklist/player/water failures at individual slots. Block sector infantry placement entirely: at most 24 squad-placement attempts must return without an incomplete squad or an endless loop. Also allow some full sector squads to succeed before the attempt bound: those squads remain while initialization continues, and empty patrol-route lists cause no indexing error. Rejected AO patrols, side-task patrols/attacks and FOB assault groups must exit safely without empty-roster indexing or invalid waypoints.
5. Cross eight/nine nearby ground players and 24/25 connected humans. The new Primary controller must bypass legacy automatic Classic Viper top-ups. Remaining native low-population Classic/sector admission needs no existing team, the rare opportunity and a full team; existing Vipers remain. Native low-population helicopter class requests substitute regular CSAT, while supplied passengers keep their identity.

#### G8 — Outgoing covering fire and load pacing

**Related edited files:** `fn_AI.sqf`, `fn_AIHandleUnit.sqf`, `fn_AIHandleGroup.sqf`, `fn_AIXSuppressiveFire.sqf`, `fn_aoDefend.sqf`.

1. At up to eight conscious ground players compare two shooters; above eight compare four in full squads and two in smaller squads. MGs should have first eligibility while other members continue moving.
2. Check the small/busy burst and cooldown ranges, dry/low magazines, full shooter budget, stale target, terrain obstruction, friendly lane and a player entering a vehicle. Fire must use native ammunition and observed positions.
3. Hold low FPS: managed covering fire should remain eligible, optional Primary maneuver refreshes should slow to 40–50 seconds, and normal 20–30-second pacing should return only after the recovery hold.
4. Transfer group ownership/server-HC and exercise original unmanaged suppression callbacks. No callback-scope error or competing move command should cancel a valid managed burst.

#### G9 — Player Supports, role lifecycle and mortar sections

**Related edited files:** `description.ext`, `code/config/security.hpp`, `fn_artillerySupport.sqf`, `fn_mortarSupport.sqf`, `fn_roles.sqf`, `fn_clientArsenal.sqf`, `fn_clientCore.sqf`, `fn_clientInteractMortarLite.sqf`, `fn_AI.sqf`, `fn_aoDefend.sqf`, `fn_core.sqf`, `fn_incapacitated.sqf`, `media/images/roles/arid/forward_observer.jpg`.

1. Check one Forward Observer slot, correct role image, JTAC-configured gear/Arsenal and ordinary JTAC/Mortar configured slots. New menus must follow only eligible roles, healthy bodies and permitted control state.
2. Verify Forward Observer half stock through ten connected humans, interpolation at 11–30 and full stock at 31+. Check Defense doubling. For every JTAC slot verify 3/2/1 Primary and 6/4/2 Defense regardless of population.
3. Leave slots vacant, swap roles/seats, reconnect, close/reopen capacity and add capacity mid-activity. Spending must survive; vacancies must not donate shares. Side tasks/Kavala do not refill or authorize new FO/JTAC strikes outside an active Primary/Defense.
4. Exercise all eight fixed munition profiles. Confirm Artillery Order for FO, Airstrike Order for JTAC and final Request Fire Mission. FO retains 1–8 rounds; JTAC has no volley menu and server-rejects multi-bomb requests. FO red illumination is absent. Check dispersion and blue marker/smoke. Check 50 m laser/IR target requirements and loss of designation between rounds. Time private acceptance, the one public Broadway announcement at 10–12 seconds and planned final impact/completion at 20–25 seconds, including an eight-round FO volley. Public time to target must estimate the first impact; the final round follows 3.5 seconds later for eight FO rounds. Cancel before announcement and between releases. Actual impacts, guidance and submunition attribution require Arma.
5. Place living humans, unconscious players and vehicle occupants inside/outside 175 m plus dispersion; move them into danger between rounds. Check safe-zone/Robocop denial, role loss, death, remote control and activity-end cancellation. During the same activity, only unreleased rounds refund. Ending or changing the activity closes that allowance without carryover; timeout closes its job, while eligible role menus remain.
6. Deploy three HE-only Support mortars, reject a fourth, request the five-tube crate and reset. Request and resupply cooldowns are independent ten-minute clocks; inventory Deploy Mortar consumes a tube and neither clock. Only Mortar Gunner occupants may remain.
7. Test failed/late placement acknowledgment, 500 m range, disconnect/role departure/death, incapacitation/revive, emptied versus player-filled crates and activity transitions. Valid nearby equipment can persist; occupied equipment must eject safely before retirement. Native two-backpack/Zeus mortars remain separate.

#### G10 — Revive, Kavala lifecycle and firing-side attribution

**Related edited files:** `description.ext`, `fn_incapacitated.sqf`, `fn_missionKavala.sqf`, `fn_core.sqf`, `fn_aoEnemy.sqf`, `TGC/Functions/Damage/fn_isFriendlyFire.sqf`, `fn_clientEventHit.sqf`, `fn_clientDamageModifier.sqf`.

1. Check four-minute unattended bleed-out against the original ten-minute setting. Exercise vehicle attachments, requested medevac and near-expiry extensions; extraction rules can extend the normal window.
2. Run Kavala above 36 players and continue above 45. Check pilot/fighter-pilot incapacitation from setup through evacuation, including JIP, respawn and role changes. Normal later pilot rules return afterward without killing an existing casualty.
3. Interrupt or end Kavala, including zero/one-player evacuation, and start another instance. The original script must not clear a newer revive state. Check bounded searches/180-second evacuation and safe per-object hidden-building restoration.
4. Kill/control the current Commander through Zeus and verify completion happens once. Compare hostile physical fire, friendly AI under control, actual gunners, unrelated passengers, unknown collisions and explicit self-damage. Warning, Robocop, damage scaling and casualty side attribution must agree.
5. Check Support-role incapacitation/menu suspension together with the role suite; the full delivered revive file includes both Supports and Kavala behavior.

#### G11 — Arsenal, logistics, ruins and background cleanup

**Related edited files:** `fn_core.sqf`, `fn_clientEventPut.sqf`, `fn_eventBuildingChanged.sqf`, `fn_mortarSupport.sqf`.

1. Drop ground gear inside/outside 30 m of an arsenal, trade/take it during the 30-second grace and move the holder away. Check private notice throttling and no expiry notice for inserting items into a crate.
2. For a known logistics/deployment crate, leave every linked location without living ground players within 1 km. Return at 4:59, leave again and compare incapacitated players, enemy-side humans, landed pilots and airborne flyovers. A fresh uninterrupted five-minute absence is required.
3. Repeat with occupants, cargo/attachments, ropes, motion, protection flags, another recipient and arbitrary Zeus props. The final recheck and original deployment cleanup must preserve protected/active objects and remove appropriate linked markers/zones once.
4. Destroy mission objects and terrain buildings, including a side objective and buildable. Check five-minute/500 m ruin eligibility, protected types, mission-object deletion versus terrain hiding, and intact objective/buildable handling.
5. Compare normal, sustained low and fluctuating FPS. Confirm 64/96/128 holder and 4/8/16 crate/ruin batch limits, continued low-budget progress and stepped recovery. These bounds concern the added queues, not every inherited core operation.
6. Measure comparable repeated activity cycles: entity/helper counts, scripts, frame times and cleanup bursts. Hidden terrain objects are not automatically reclaimed memory; a higher FPS reading with fewer combatants is not an equivalent-load comparison.

### Other bundles and their acceptance cases

| Group | Files to test together | Expected checks |
|---|---|---|
| R — Radio | All seven Radio files below | Two-client Side text/VOIP across teams; default-on and saved opt-out; General mandatory/public text/authorized voice; private Staff; late authorization, death/respawn, JIP, High Command and team/group changes. Confirm one usable Side entry, actual allocated channel capacity and stable no-change membership passes. |
| S — BLUFOR AI speech | Both Speech files below | Recruitment/mission/Zeus creation, JIP, respawn and server/client/HC locality. Automatic AI voice/reports stay quiet; orders, player VOIP and scripted messages remain. Player takeover restores appropriate speech state; existing damage/collision behavior is preserved. |
| V — Vehicle handlers | `TGC/Functions/Damage/fn_addSpawnMenuVehicleHandlers.sqf` | Repeated entry/exit and owner handoffs in both callback orders, reconnect/JIP and missing-handler repair. One mission damage handler remains; native empty-vehicle protection remains last. Locks, ownership access and damage results are unchanged. Measure any entry stall separately from the existing 1.5-second quick-entry bar. |
| P1 — Area detector | `code/functions/fn_serverDetector.sqf` | Compare original/current list and count modes with identical pools: empty/full areas, radius boundaries, mixed sides, duplicates and mode -1. Matching results and order; measure script work separately from overall FPS. |
| P2 — HC maintenance | `code/functions/fn_hcCore.sqf` | Observe a scan that takes longer than the interval. The next scan waits 30 seconds after completion. Existing entity eligibility, simulation distance and handoff behavior remain. Requires actual HC for engine acceptance. |
| P3 — Laser labels | `TGC/Functions/Lasers/fn_initLaserHandlers.sqf` | Toggle display/designations and change laser owner, observer, vehicle or side. Positions/drawing stay per-frame; stable owner labels can lag up to 250 ms. New context refreshes immediately. Existing AI laser-ignore and strike guidance remain separate. |

### Shared-file dependencies

| Shared file/area | Why the complete file belongs to the combined Gameplay candidate |
|---|---|
| `fn_AI.sqf`, `fn_aoDefend.sqf` | Combine reinforcement, contact priority/isolation, aircraft/insertion ownership, performance pacing and Support activity state. |
| Unit/group/fire handlers | Share controller calls, observations, target ranking, Primary mortar admission, aircraft ownership and covering fire. |
| `fn_spawnGroup.sqf` and updated callers | Callers use new infantry/vehicle placement modes; the helper and its callers must agree. |
| `fn_core.sqf` | Includes general cleanup, Kavala state recovery and Support-owned mortar maintenance. A cleanup-only copy still carries those calls. |
| `fn_incapacitated.sqf` | Combines attribution, Kavala pilots and Support role/menu lifecycle. |
| `description.ext` | Includes the 240-second timer plus both new Support registrations and communication-menu entries. The full file is not a timer-only edit. |
| Role files, `security.hpp`, two new Support functions and role image | Registration, remote-call permission, role access, gear alias, menus, stock and equipment ownership are connected. |
| Rappel/landing/insertion helpers | Share activity ownership, dismount, late-callback, rope/device and departure cleanup. |
| Friendly-fire helper and damage callers | Must resolve firing side consistently for Robocop, scaling, warnings and casualty messages. |

The callback-scope repair in `fn_AIXSuppressiveFire.sqf` can be isolated, but copying that file alone does not provide full outgoing covering fire. A separately extracted timer-only patch could also be independent; this release supplies complete files. No external ApexCfg file is changed.

### Complete edited-file inventory

Each runtime path appears once below. Scenario references indicate related checks, not additional copies of the file.

#### Gameplay — Primary and Defense controllers

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `code/functions/fn_AI.sqf` | Modified | G1, G2, G3, G4, G5, G6, G8, G9 | Primary reinforcement, objective, artillery and contact controller; observed BLUFOR ground-target priority and isolated-Support stalking exclusion; due-only spawn census and paced maneuver refreshes; aircraft task ownership; Support stock lifecycle. |
| `code/functions/fn_AIHandleGroup.sqf` | Modified | G1, G2, G3, G5, G6, G8 | Route Primary, Defense and aircraft movement without competing orders; apply mortar admission gates and ranked known ground targets for Commander requests. |
| `code/functions/fn_AIHandleUnit.sqf` | Modified | G1, G2, G3, G5, G6, G8 | Observed-contact reporting, stance, ranked known ground targets for fire-support requests, Primary mortar tuning and low-FPS covering fire with early cooldown/ammo/slot checks. |
| `code/functions/fn_aoEnemy.sqf` | Modified | G1, G2, G7, G10 | Tag objective guards, separate mobile vehicles and complete Commander death once despite Zeus ownership changes. Skip rejected patrol groups before task setup. |
| `code/functions/fn_aoSubObjectives.sqf` | Modified | G1 | Fresh population evaluation and 15-second clearance. |
| `code/functions/fn_aoDefend.sqf` | Modified | G2, G3, G4, G7, G8, G9 | More frequent selection; bounded priority flanks and isolated-Support exclusion; insertion/cover hooks; validated infantry centers and per-cell native exclusions; leader-only push and doubled Support stock. Optional 30-minute start/extension with Crossroads chat and hint, preserving native combat and cleanup. |
| `code/scripts/IA_MegaDefense.sqf` | Added | G3 | Manual bonus in the regular mission folders, never automatically invoked: force the current Classic HQ into 30-minute Defense or give a running Defense at least 30 minutes remaining, with duplicate protection and status. |

#### Gameplay — Enemy air and fire support

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `code/functions/fn_AIFireMission.sqf` | Modified | G2, G5, G6 | Explicit Primary mortar tuning; ranked ground-target selection and queued-target eligibility checks; managed helicopter/plane admission and departure hooks. |
| `code/functions/fn_enemyCAS.sqf` | Modified | G5 | Independent jet groups, flight registration and correctly scoped pilot death handler. |
| `code/functions/fn_AIXMissileCountermeasure.sqf` | Modified | G5 | Managed-flight physical countermeasures and missile-driven ground-pass withdrawal. |

#### Gameplay — Insertion and rappel

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `code/functions/fn_AIXHeliInsert.sqf` | Modified | G4, G7 | Automatic Taru population policy; bounded descent/departure and actual-rappel-clearance fallback; retain other native insertion callers and low-population Viper substitution. |
| `code/functions/fn_AIXHeliInsertLanding.sqf` | Modified | G4 | Reject late delivery callbacks; track unfinished cargo; retire departures without destroying nearby aircraft. |
| `code/scripts/AR_AdvancedRappelling_ext.sqf` | Modified | G4 | Faster bounded AI rappel; actual rope-descent clearance with alternate anchors and bounded landed-AI egress; owned rope/device/event cleanup and protected player behavior. |

#### Gameplay — Shared placement and its callers

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `code/functions/fn_spawnGroup.sqf` | Modified | G1, G3, G4, G7 | Shared 85×85m outdoor placement; strict 15m separation from troops/reservations; bounded staggered retries within the approved area; reject incomplete infantry/vehicle layouts. |
| `code/functions/fn_spawnViperTeam.sqf` | Modified | G7 | Use validated slots and extremely rare, full initial Viper teams below 25 connected humans. |
| `code/functions/fn_gridEnemy.sqf` | Modified | G7 | Spread initial Grid foot patrols and mobile vehicles; retain crew/garrison placement. |
| `code/functions/fn_gridSpawnPatrol.sqf` | Modified | G7 | Spread Grid patrol replacements. |
| `code/functions/fn_gridSpawnAttack.sqf` | Modified | G7 | Spread Grid assault squads. |
| `code/functions/fn_ambientHostility.sqf` | Modified | G7 | Spread ambient infantry; keep paired ground vehicles in distinct validated positions. |
| `code/functions/fn_missionGeorgetown.sqf` | Modified | G7 | Spaced outdoor patrol replacements and bounded mobile building-position search. |
| `code/functions/fn_scSpawnHeli.sqf` | Modified | G1, G5 | Bound native rotary entry search; return an empty roster if blocked. |
| `code/functions/fn_scSpawnLandVehicle.sqf` | Modified | G7 | Separate ground patrol vehicles; recheck player distance, route and terrain exclusions before creation. |
| `code/functions/fn_scEnemy.sqf` | Modified | G7 | Bound native sector infantry fill attempts so rejected complete layouts cannot cause an endless spawn loop. |
| `code/functions/fn_taskPatrol.sqf` | Modified | G7 | Return safely for a rejected or empty group before inspecting its first soldier; preserve native patrol behavior for valid groups. |
| `code/functions/fn_taskAttack.sqf` | Modified | G7 | Return safely for a rejected or empty group before creating its attack waypoint; preserve valid-group behavior. |
| `code/functions/fn_fobEnemyAssault.sqf` | Modified | G7 | Skip native assault waypoint setup when strict ground placement cannot admit its group. |
| `code/functions/fn_aoEnemyReinforceVehicles.sqf` | Modified | G1, G7 | Separate native ground armor reinforcements; retain base/player exclusions and skip blocked positions. |
| `code/functions/fn_spawnSupport.sqf` | Modified | G7 | Mobile enemy medical/repair vehicles use distinct clear ground cells. |

#### Gameplay — Damage, revive and Kavala

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `TGC/Functions/Damage/fn_isFriendlyFire.sqf` | Modified | G10 | Shared firing-unit resolution for normal, Zeus and custom remote control. |
| `code/functions/fn_clientEventHit.sqf` | Modified | G10 | Robocop uses the actual firing side; friendly AI fire still identifies its controller. |
| `code/functions/fn_clientDamageModifier.sqf` | Modified | G10 | Damage scaling uses the same firing side as friendly-fire classification. |
| `code/functions/fn_incapacitated.sqf` | Modified | G9, G10 | Consistent casualty attribution; Kavala pilot override; normal Support-role incapacitation and menu removal. |
| `code/functions/fn_missionKavala.sqf` | Modified | G7, G10 | Allow high-population play; retain pilot revive through evacuation; bound searches and cleanup. |

#### Gameplay — Shared cleanup and covering fire

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `code/functions/fn_core.sqf` | Modified | G3, G9, G10, G11 | Kavala state recovery, owned-mortar cleanup, arsenal drops, unattended logistics crates and ruin rotation; bounded background batches with gradual FPS recovery. Owned forced Primary-to-Defense handoff, unfinished-task retirement and HQ preservation. |
| `code/functions/fn_clientEventPut.sqf` | Modified | G11 | Private 30-second expiry notice for ground gear dropped near arsenals. |
| `code/functions/fn_eventBuildingChanged.sqf` | Modified | G11 | Queue observed ruins for safe retirement; retain native buildable-collapse and objective-completion logic. |
| `code/functions/fn_AIXSuppressiveFire.sqf` | Modified | G8 | Fix callback group scope and respect managed covering fire. |

#### Gameplay — Player Supports and role registration

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `description.ext` | Modified | G9, G10 | Four-minute bleed-out; register two Support functions and five communication-menu entries. |
| `code/config/security.hpp` | Modified | G9 | Whitelist only the two Support functions; each validates caller ownership and mode. |
| `code/functions/fn_roles.sqf` | Modified | G9 | Add one Forward Observer slot, descriptions, configured JTAC gear alias and immediate Support-menu reconciliation. |
| `code/functions/fn_clientArsenal.sqf` | Modified | G9 | Forward Observer uses the configured JTAC Arsenal list. |
| `code/functions/fn_clientCore.sqf` | Modified | G9 | Keep the Forward Observer gear-manager alias consistent. |
| `code/functions/fn_clientInteractMortarLite.sqf` | Modified | G9 | Route the mission’s lightweight Deploy Mortar action through the HE-only, three-owned-mortar limit. |
| `code/functions/fn_artillerySupport.sqf` | Added | G9 | Forward Observer/JTAC menus, equal per-slot JTAC stock, virtual ordnance, danger-close checks and cancellation. |
| `code/functions/fn_mortarSupport.sqf` | Added | G9, G11 | Three owned Mk6 mortars, separate resupply/reset actions, cooldowns and equipment cleanup. |
| `media/images/roles/arid/forward_observer.jpg` | Added | G9 | Supplied role image, 365 × 399 to match Mortar Gunner. |

#### Radio — seven files

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf` | Modified | R | Reconcile cross-team Side, admin/Zeus General voice and unchanged private Staff access. |
| `code/functions/fn_clientEventRespawn.sqf` | Modified | R | Remove old-body memberships and restore Side preference and General authorization on the new body. |
| `code/functions/fn_clientMenuRadio.sqf` | Modified | R | Optional cross-team Side checkbox; mandatory General; separate the original Staff binding. |
| `code/functions/fn_clientRadio.sqf` | Modified | R | Reject General opt-out; retain General while awaiting respawn; explicitly remove old-body memberships on respawn. |
| `code/functions/fn_config.sqf` | Modified | R | Allocate optional Side in native blue; preserve Staff; initialize public General text with voice restricted. |
| `code/functions/fn_highCommand.sqf` | Modified | R | Use shared radio authorization on entry/exit; do not reopen native Side transmission. |
| `code/functions/fn_initPlayerLocal.sqf` | Modified | R | Restore saved Side preference, force General membership, and refresh authorization through the existing radio loop. |

#### BLUFOR AI speech — two files

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `TGC/Functions/Damage/fn_addFriendlyAIHandlers.sqf` | Modified | S | Mute BLUFOR AI automatic speech and reports on each machine; reapply owner settings after locality changes. Existing damage/collision code is unchanged. |
| `TGC/Functions/Damage/fn_initFriendlyAIProtection.sqf` | Modified | S | Reuse existing creation, respawn and JIP coverage; remove temporary speech handlers copied during respawn. |

#### Spawn Menu vehicle handlers — one file

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `TGC/Functions/Damage/fn_addSpawnMenuVehicleHandlers.sqf` | Modified | V | Reuse the valid damage-handler ID after locality returns; prevent duplicate damage callbacks across ownership handoffs. |

#### Shared performance — three independent files

| Mission-relative file | Status | Related checks | Net change |
|---|---|---|---|
| `TGC/Functions/Lasers/fn_initLaserHandlers.sqf` | Modified | P3 | Cache cosmetic laser-owner attribution for 250 ms; reset on observer/vehicle/side changes; keep sensor targets and drawing current. |
| `code/functions/fn_hcCore.sqf` | Modified | P2 | Schedule the next dynamic-simulation maintenance pass from completion so slow scans cannot immediately repeat. |
| `code/functions/fn_serverDetector.sqf` | Modified | P1 | Filter the supplied area before checking sides; preserve current results and list/count modes. |

### Combined full-release check

The final combined scenario uses all 59 files through **Primary → Defense → next Primary**, plus Kavala/Georgetown, Grid/ambient activity and side-task regressions where applicable. Include real multiplayer clients, JIP, respawn/role changes and the production HC/mod configuration. Repeat after losses, ownership changes and interrupted insertions/Supports.

Performance comparison needs matched ground turnout, live AI/group/vehicle counts, HC ownership and comparable activity stages. Record server/client frame times, RPT errors, active scripts and retained helpers across repeated cycles. Actual weapon/guidance, flight/navigation, UI/VOIP, terrain collision and locality behavior remain engine checks; offline assertions are not FPS measurements.

All scenarios above remain pending dedicated-server acceptance. The offline results and their limits follow.

## Verification evidence

The 10 September 2026 full-release sweep passed all **15 offline verifiers**, with **58,320 executed policy assertions**, all 56 complete runtime SQFs parsed, all seven supplied Apex configuration SQFs parsed and all 55 original source files reconstructed exactly. The checks include the current Support order menus, single-bomb JTAC enforcement, eight allowed profiles, delayed Broadway announcements, release scheduling, cancellation/refunds, native objective notifications, strict bounded ground placement and actual rappel-descent clearance and manual 30-minute Defense lifecycle.

The checks cover Primary/Defense reinforcement, objectives, contact and casualty allocation, observed target priorities, isolated Support stalking, automatic insertions, placement, aircraft/support ownership, maintenance, radio, BLUFOR speech, Zeus attribution, player Supports, mortar equipment, vehicle handlers, shared performance and the supplied Apex configuration. The total includes 380 Apex integration assertions.

SQF-VM executes production decision logic with controlled engine facts and documented adapters. Counts include parameter combinations and overlapping regression cases. Some protected earlier boundaries reverse exact later edit spans; current-source checks cover the final integration. In particular, the isolated stalking regression and final foot/mounted target-priority checks are separate layers. These results do not represent live multiplayer sessions or measured FPS improvements.

Performance fixtures confirm equivalent area-query results with fewer scripted side checks, cached cosmetic laser attribution, completion-based HC deadlines, bounded cleanup batches, deferred reinforcement censuses and correct recovery states. Actual gains require equivalent-load server/client measurements. No specific FPS improvement is claimed.

Staging produced exactly 2,510 files from the 2,506-file initial baseline. Git patch application and reversal, both at repository root and within a nested mission folder, reproduced the exact updated/original bytes. Restoration recovered every baseline hash. Unexpected modified input was rejected without mutation. Archive validation checks the exact delivery members, hashes and CRCs, including the matching copy of these Release Notes.

Live Arma acceptance remains pending for AI navigation and flight, parachutes/rappel, Support menus and projectile guidance, radio/VOIP, revive event ordering, server/HC locality, database whitelist integration, cleanup side effects and production performance. The grouped scenarios above cover these remaining checks. Test fixtures and detailed logs are retained with the development work.

## Bonus: manual 30-minute Defense

Mega Defense is included in the regular mission folders at `mission/code/scripts/IA_MegaDefense.sqf`, together with its required controller support. **The mission does not call this script automatically.** It is available on demand to Zeus/Admin through the Dev Console, or to a server-owner scheduler added later. Installing this release does not activate the 30-minute event or schedule it before a reset.

After installing the release and restarting the mission, Zeus/Admin can run this using **Server execution** in the Dev Console:

```sqf
[] execVM "code\scripts\IA_MegaDefense.sqf";
```

During a Classic Primary AO, this forces the current HQ into a 30-minute Defense without waiting for objectives to be completed. The controller retires the unfinished Primary activity, preserves the HQ and starts Defense after its AI shutdown finishes. Unfinished objectives are not credited as completed. During an already running Defense, it gives that event **at least 30 minutes remaining** and refreshes the task timer. Repeating the trigger while the special mode is active does not stack time or repeat announcements.

Players receive a **Crossroads side-chat message and hint** once the forced Defense starts or the active timer is extended. Normal troop limits, wave timing, aircraft/artillery, Support stock, HQ capture/failure and administrator cancellation remain. A loss can end the event early. The 30-minute target is checked by the existing scheduled loop; server load can delay the final check.

`["STATUS"] execVM "code\scripts\IA_MegaDefense.sqf";` records status in the server RPT. Request acceptance/rejection is also recorded there. `["CANCEL"] execVM "code\scripts\IA_MegaDefense.sqf";` removes a request before the controller commits to the handoff; once transition is underway it returns IN_PROGRESS. It does not cancel an active Defense or restore an interrupted Primary. Client execution, an unsupported mission mode, an unready framework, no usable current HQ, or an expired/closing Defense cannot start a second event.

The server owner can connect a separate scheduler to this same entry point when ready. No reset times, timezone, scheduled invocation or ApexCfg changes are required to include the callable script in this release. The forced transition has a short controller/cleanup handoff before its 30-minute battle timer begins; its shutdown wait is bounded to 60 seconds. Integrating an exact reset schedule should account for that handoff and the native completion-check interval.

## GitHub and rollback support

| ZIP item | Purpose |
|---|---|
| `mission/` | All 59 updated or added runtime files at their mission-relative paths. |
| `combat_update.patch` | Binary-capable Git patch for the complete change; reverse application restores the exact baseline changes, including removal of added files. |
| `manifest.json` | Baseline identity, changed/added paths and source/payload hashes for verification. |
| `stage.py` | Verified staging into a new mission folder; restoration can use the existing archived baseline through its `--baseline` option. |
| `RELEASE_NOTES.md` | This complete performance/gameplay changelog, file inventory, test groups and verification scope. |
| `TECHNICAL_NOTES.md` | Full implementation reference and exact mechanics for the complete release. |
| `README.md` | Short package contents reference. |

Original code remains commented beside replacements. Separate original-source copies and a full mission archive are excluded. No external ApexCfg changes are required.
