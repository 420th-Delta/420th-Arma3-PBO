+# 420th Delta Classic Invade & Annex

This is the source for 420th Delta's Altis-focused **Invade & Annex: Apex Edition** mission. It began as a fork of Quiksilver's Apex Framework 1.5.6 and now contains 420th-specific mission layout, gameplay, administration, database, visual, and review work.

The packable mission is [Apex_framework.terrain/](Apex_framework.terrain/). The root <code>docs/</code> and <code>tests/</code> trees are maintainer material and must not be placed in a mission PBO.

> **Review status:** the checked-out review snapshot has controlled native verification, but it has not completed human or live-server acceptance. This README is documentation only; it is not a release or deployment approval.

## Snapshot, provenance, and comparison method

This document records the mission tree at <code>98a5481b3174794073f6155e5f508677055fc74c</code> (<code>review/ia-performance-gameplay-20260910</code>) before this README edit. That branch is local here and is not being pushed or committed by this documentation change.

| Item | Value |
| --- | --- |
| Original public source | [auQuiksilver/Apex-Framework](https://github.com/auQuiksilver/Apex-Framework) |
| Comparison baseline | [<code>ee7481a51b0f927e39e96aa3b277ea4c44a93c22</code>](https://github.com/auQuiksilver/Apex-Framework/tree/ee7481a51b0f927e39e96aa3b277ea4c44a93c22), Quiksilver's **1.5.6 Stable 1** commit of 2023-11-14 |
| Baseline path | <code>Apex_framework.terrain/</code> in the Quiksilver repository |
| Local first import | <code>0eac884c121dbdd4ce298d83c2886dda64e61c4d</code>, “Initial Push (Apex 156),” 2024-05-19 |
| Documented branch tip | <code>98a5481</code>, 2026-09-11 |
| Recorded 420th integration base | <code>a0a58e1</code>; this is a 420th reconciliation commit, **not** Quiksilver's public baseline |

The local repository and Quiksilver's repository do not share Git ancestry, so a range from <code>0eac</code> to <code>HEAD</code> is not a valid upstream comparison. The baseline was selected by matching the first local import against Quiksilver history: 1,005 of its 1,006 retained mission files were byte-identical to <code>ee7481</code>; its only source difference was <code>mission.sqm</code>.

For a fresh review, use a disposable checkout of Quiksilver's repository detached at <code>ee7481</code>, then compare its <code>Apex_framework.terrain/</code> directory with this branch at <code>98a5481</code>. Use <code>git diff --no-index --find-renames</code> for the raw file view and <code>--ignore-space-at-eol</code> when assessing source behavior. Do not compare against a moving <code>master</code> branch.

## Repository layout and runtime requirements

<pre>
Apex_framework.terrain/       Mission source; package this directory as the mission PBO
├── 420th/                    Player profiles and user-input-menu integration
├── TGC/                      Gameplay, staff, damage, radio, database, drone, and laser helpers
├── code/                     Quiksilver-derived configuration, functions, dialogs, and scripts
├── media/                    Mission images, skins, flags, emotes, and commissary assets
├── tests/                    Checked-in structural performance validation
├── description.ext           Mission configuration, registrations, and remote-execution policy
└── mission.sqm               The 420th Altis editor layout
@extDB3/                      Separate server extension payload and SQL definitions
docs/community-updates/       Jolly review, remediation, release notes, and evidence
tests/ia-update/              Local Windows/Arma review harnesses; not mission content
</pre>

The mission checks for a dedicated 64-bit server, <code>-filePatching</code>, an active <code>@Apex</code> server mod, and matching <code>@Apex_cfg</code> files. <code>@Apex_cfg</code> supplies parameters, roles, whitelist, chat, arsenal, and optional terrain overrides; it is intentionally separate from this mission source. The mission declares content from Orange, Apex, Helicopters, Contact/Enoch, Tanks, Karts, and Malden/Argo.

<code>extDB3</code> is optional at runtime. The mission detects whether the extension is available and retains a non-database whitelist path when it is not. Treat database credentials, private UIDs, operational whitelists, and live configuration as private server inputs; this README deliberately does not reproduce them.

There is no checked-in HEMTT project or authoritative build/release script. Before any staging deployment, preserve the prior PBO and server configuration, pack only the mission directory, retain the existing <code>CfgRemoteExec</code> and debug-console policy, validate the intended configuration with CfgConvert, inspect the dedicated-server RPT, and exercise the intended mod/configuration set. Do not copy review fixtures or altered-content controls into a live server.

## Complete divergence from Quiksilver 1.5.6

The effective source comparison contains **552** changed paths: 320 added, 171 content-modified, and 61 absent upstream paths. Quiksilver's baseline tree has 1,062 paths and this mission has 1,321. Of the remaining files, 830 are content-identical.

A raw Git-tree comparison reports 302 changed common blobs. Of those, 131 SQF files normalize byte-for-byte under the repository's <code>text=auto</code>/<code>core.autocrlf</code> checkout policy; they are CRLF/LF-only representation differences, not functional changes. Every raw difference belongs to exactly one row in this ledger.

| Path family | Added | Content modified | Line-ending only | Absent from this mission | Covered change |
| --- | ---: | ---: | ---: | ---: | --- |
| <code>420th/</code><br><code>playerprofile/**</code> | 5 | 0 | 0 | 0 | Optional database-backed profile request, queue, receive, UI, and initialization flow. |
| <code>420th/</code><br><code>userinputmenus/**</code> | 20 | 0 | 0 | 0 | Color picker, messages, list boxes, sliders, text/progress controls, includes, and retained license. |
| <code>code/</code><br><code>config/**</code> | 4 | 11 | 131 | 0 | Donator flags/textures, emotes, performance settings, security, and current mission-data catalogs. |
| <code>code/</code><br><code>dialogs/**</code> | 2 | 0 | 0 | 0 | PMC and Spawn Menu dialogs. |
| <code>code/</code><br><code>functions/**</code> | 46 | 156 | 0 | 0 | Player, AI, objectives, support, logistics, vehicle, cleanup, security, staff, and synchronization behavior. |
| <code>code/</code><br><code>scripts/**</code> | 1 | 1 | 0 | 0 | Manual Mega Defense plus reviewed Advanced Rappelling integration. |
| <code>description.ext</code><br><code>mission.sqm</code><br><code>stringtable.xml</code> | 0 | 3 | 0 | 0 | Mission configuration, Altis layout, function/security registration, and localized text. |
| <code>TGC/Functions/</code><br><code>Channels/**</code> | 5 | 0 | 0 | 0 | Channel masks, membership, staff access, and refresh logic. |
| <code>TGC/Functions/</code><br><code>Curators/**</code> | 1 | 0 | 0 | 0 | Curator addon registration. |
| <code>TGC/Functions/</code><br><code>Damage/**</code> | 10 | 0 | 0 | 0 | Friendly-AI, player, empty-vehicle, and spawn-menu vehicle damage handling. |
| <code>TGC/Functions/</code><br><code>Database/**</code> | 5 | 0 | 0 | 0 | extDB3 query/strip/whitelist setup and refresh paths. |
| <code>TGC/Functions/</code><br><code>Drones/**</code> | 2 | 0 | 0 | 0 | UID-bound drone ownership and initialization. |
| <code>TGC/Functions/</code><br><code>Lasers/**</code> | 2 | 0 | 0 | 0 | Laser-instigator attribution and display handling. |
| <code>TGC/Functions/</code><br><code>Setting/**</code> | 1 | 0 | 0 | 0 | CBA-aware setting helper with a non-CBA fallback. |
| <code>TGC/Functions/</code><br><code>Staff/**</code> | 12 | 0 | 0 | 0 | Staff identity, keybinds, weather, AO/side-mission controls, and interfaces. |
| <code>media/</code><br><code>commissary/**</code> | 69 | 0 | 0 | 0 | Custom commissary texture catalog and local asset note. |
| <code>media/images/</code><br><code>{billboards,emotes,flags,general,roles,</code><br><code>spawnMenus,uskins,vskins}/**</code> | 133 | 0 | 0 | 4 | 420th identity art, flags, emotes, role/spawn-menu images, and uniform/vehicle skins; four upstream general flags are not retained. |
| <code>media/images/</code><br><code>insignia/**</code> | 0 | 0 | 0 | 1 | One upstream insignia is not retained. |
| <code>SERVER_PERFORMANCE_</code><br><code>LOGGING.md</code> and <code>tests/**</code> | 2 | 0 | 0 | 0 | Server-performance guide and structural validation script. |
| <code>documentation/**</code> | 0 | 0 | 0 | 30 | Quiksilver setup/admin/reference text not copied into this mission tree. |
| <code>SQM/**</code> | 0 | 0 | 0 | 26 | Quiksilver alternate-terrain and backup <code>mission.sqm</code> variants omitted from this Altis-focused tree. |
| **Mission-tree total** | **320** | **171** | **131** | **61** | **All source-path differences at the documented revision.** |

<code>@extDB3/</code> contributes eight additional server-support paths outside the mission tree: extension binaries, extension configuration, and custom SQL definitions. They are not part of the Quiksilver mission-directory comparison and must be reviewed separately for platform compatibility and secrets.

### Inherited 420th baseline changes

The first 420th import already had a customized <code>mission.sqm</code>; it is not a JollyRogerEXP-era change. It is an Altis layout with 118 editor entities rather than Quiksilver's 119. It relocates the base, carrier, and destroyer placement, preserves 25 named QS markers, four headless-client slots, three registered vehicles, and three registered units, and converts placed tropical <code>B_T_*</code> role classes to <code>B_*</code> counterparts. It also removes Quiksilver's <code>#adminLogged</code> curator module. The initial import was otherwise runtime-source-identical to Quiksilver 1.5.6.

The 30 upstream <code>documentation/</code> files and 26 alternate/backup <code>SQM/</code> files were already absent at the first import. They are inherited packaging omissions, not deletions made by the Jolly review branch. The five additional absent image assets at the documented revision are four general flags and one insignia.

### 420th mission and operator changes

The 420th fork changes much more than a title or layout. This is the behavioral map for the complete source ledger.

| Area | Changes from the Quiksilver baseline |
| --- | --- |
| Mission identity and lifecycle | 420th identity; up to 112 mission players; joining unassigned; no player sending on built-in Side; shorter corpse/wreck retention; pylon/loadout and curator controls; five-minute configured normal bleed-out. |
| Content and balance data | Revised AI/civilian/vehicle tables, arsenal and restricted gear, loadouts, pylon options, AOs, fortifications, sites, composition/layout data, buildables, deployables, radio, weather, textures, and terrain-specific material. The configuration tree is authoritative for these values. |
| Player and community systems | Player profile handling, donator flags/skins/colors, emotes, private channels, PMC menu/dialog, vehicle access, player-team/map/intelligence helpers, client-mod validation, face/team customization, and staff controls. |
| Security and authority | Remote-execution validation, whitelist/database paths, client-mod checks, drone ownership locks, authenticated feature/state publication, and server-side support/vehicle request handling. Preserve <code>security.hpp</code>; do not relax it as a troubleshooting shortcut. |
| AI, objectives, and HC work | Customized Primary/Side/Defense controllers, AI spawning, reinforcement, objective, garrison, High Command, headless-client, UAV, aircraft, artillery, mortar, and side-mission behavior, including population/difficulty tuning and recruitable AI changes. |
| Logistics and vehicles | Spawn Menu, cargo/deployment, vehicle registration, service, towing, respawn, access, damage, empty-vehicle protection, and aircraft loadout behavior. Some helpers are configurable or disabled by current policy; source presence does not mean enabled on every server. |
| Damage, revive, and roles | Friendly-AI and vehicle protection, player damage attribution, revive/role behavior, pilot exceptions, medic/recruit handling, curator integration, earplugs, and role-specific equipment/UI. |
| Radio and staff tooling | Staff masks, private channels, group-leader/radio management, staff AO/side-mission/weather controls, and the reviewed optional shared-radio implementation below. |
| Performance and diagnostics | Server-performance settings/logging, core performance helpers, diagnostics, and bounded/observed cleanup work. These are observability and work-scheduling changes, not evidence of a guaranteed FPS improvement. |
| Visual content | 202 binary art assets: commissary imagery, 420th identity art, flags, emotes, role/spawn-menu images, and uniform/vehicle skins. Five upstream image assets are not retained. |

New function entry points cover artillery/mortar support; donator, emote, PMC, private-channel, vehicle-access, projectile-map, and team-display menus; player-mod validation; Spawn Menu/cargo/deployment/managed-vehicle handling; entity-state publication/application; database/profile support; aircraft/UAV and transform diagnostics; and performance helpers. Existing functions carry the complementary changes to configuration, remote calls, handlers, AI controllers, cleanup, and persistence.

## JollyRogerEXP performance and gameplay update

The 30-commit review branch starts from 420th's <code>a0a58e1</code> reconciliation commit. Its first eight commits are JollyRogerEXP's contribution; the remaining 22 commits record integration, corrections, test tooling, an independent review, and contributor-feedback decisions. The full branch changes 135 paths against <code>a0a58e1</code> (73 added, 62 modified; 20,048 insertions and 1,094 deletions). Those figures describe the review branch only, not the whole Quiksilver-to-420th fork delta above.

| Commit | Contribution | Current status |
| --- | --- | --- |
| <code>e647c13</code> | Filters detector areas before side checks. | Retained. |
| <code>2b9dc80</code> | Caches cosmetic laser-owner attribution briefly. | Retained; target/display state remains current. |
| <code>950a11c</code> | Starts HC dynamic-simulation maintenance after the prior scan completes. | Retained. |
| <code>696c0fa</code> | Reuses valid vehicle damage handlers after locality returns. | Retained with review coverage. |
| <code>508874a</code> | Resolves suppression callback group/locality. | Retained. |
| <code>dbca80c</code> | Suppresses automatic friendly-AI speech while retaining player voice and scripted announcements. | Retained. |
| <code>aab162f</code> | Adds a shared Side/staff General radio design. | Retained behind a startup-only, default-off gate. |
| <code>4a4ccde</code> | Coupled combat/support overhaul. | Retained as an integrated set with later corrective commits; do not cherry-pick it file by file. |

The gameplay contribution covers Primary reinforcement and objective progress; observed contact response; ground-asset priority and casualty reactions; enemy artillery and Primary mortars; Defense selection/flanking; Taru insertion, parachutes, and rappel; enemy aircraft and covering fire; ground placement and city activity cleanup; Forward Observer/JTAC/Mortar roles; revive and firing-side attribution; radio and AI speech; vehicle locality; and background cleanup. The definitive intent, exact Jolly file list, and acceptance scenarios are in the [release notes](docs/community-updates/ia-performance-gameplay-20260910/RELEASE_NOTES.md) and [technical reference](docs/community-updates/ia-performance-gameplay-20260910/TECHNICAL_NOTES.md).

The final review snapshot changes 65 runtime paths against its recorded 420th integration base: the 59 imported payload paths plus six corrective companions for staff-channel UI, random-position selection, remote execution, mapper/JIP entity state, and state application. It deliberately preserves prior 420th diagnostics and policy fixes rather than overwriting them with the submitted patch.

### Operator-visible policies retained after review

| Policy | Current documented behavior |
| --- | --- |
| Normal incapacitation | <code>ReviveBleedOutDelay</code> is 300 seconds (five minutes), reduced from Quiksilver's 600 seconds. Existing transport and requested-medevac extensions can still extend an extraction. |
| Role and Kavala exceptions | Forward Observer, JTAC, Mortar Gunner, staff, and the active Kavala case avoid the pilot-specific forced-death path; other conditions remain in force. |
| Mega Defense | A server-invoked, finite 30-minute Defense event is retained. It can fail early or be cancelled and does not start automatically. |
| Support while incapacitated | Support menus disappear while a player is incapacitated. The UI reset and a crafted direct server reset both require a live, eligible role holder. |
| Low-population insertion | The covered Taru preference and visible reinforcement cue remain intended behavior; latency and blocked-flight effects still need acceptance testing. |
| Shared radio | <code>QS_missionConfig_sharedRadioChannels</code> is startup-only and defaults to <code>FALSE</code>. With it off, no extra Side channel is allocated and the served native-Side/optional-General policy remains. Enabling it is a future redesign/test path, not a deployment recommendation. |

## Validation and limits

The review bundle records content hashes, source reconstruction, static SQF checks, whitespace checks, CfgConvert checks, and controlled Windows native compilation with Arma 3 <code>2.22.0.154045</code>. The imported 56-SQF compilation fixture completed with no captured script errors, but it did not boot the complete Altis mission, load the intended production mods/database, test Linux, measure FPS, or establish live-server behavior.

<code>tests/ia-update/</code> contains focused and integration cells for support, damage, AI spawning, rappel security, radio cleanup, HQ deletion, and bounded lifecycle observation. They require the sibling Server Lab, Python 3.12, a local Windows Arma installation, and an available Steam session. They run in isolated local fixtures and are not portable CI or evidence of production readiness. Read the [native test instructions](tests/ia-update/README.md) before executing a cell.

The following remain acceptance work:

- full placement UI, actual respawn/revive, and role lifecycle with the intended mods and database;
- independent-account permission, voice, profile, JIP, and channel behavior;
- moving guided targets, interrupted insertion/rappel, restarted city activities, natural victory, and full-duration Defense;
- Linux/server parity and a staging RPT review with the final packed PBO; and
- population-matched performance comparison with equivalent AI, vehicle, activity, headless-client, and mod conditions.

The known Scout MFD issue is an external stock-content limitation. The private altered-content test control is not shipped mission content, is not a stock-game repair, and is not a deployment recommendation.

## Documentation map

- [Jolly update review and provenance](docs/community-updates/ia-performance-gameplay-20260910/README.md)
- [Release notes and complete Jolly-runtime inventory](docs/community-updates/ia-performance-gameplay-20260910/RELEASE_NOTES.md)
- [Detailed gameplay and performance reference](docs/community-updates/ia-performance-gameplay-20260910/TECHNICAL_NOTES.md)
- [Remediation ledger](docs/community-updates/ia-performance-gameplay-20260910/REMEDIATION_LEDGER.md)
- [Independent second-pass adjudication](docs/community-updates/ia-performance-gameplay-20260910/REVIEW_PASS_2_ADJUDICATION.md)
- [Controlled native-test report](docs/community-updates/ia-performance-gameplay-20260910/LOCAL_TEST_REPORT.md)
- [Native test runner instructions](tests/ia-update/README.md)
- [Server-performance logging guide](Apex_framework.terrain/SERVER_PERFORMANCE_LOGGING.md)

## Attribution and licensing status

Quiksilver's Apex Framework is the upstream baseline. The inherited 420th mission layout and wider fork history come from 420th Delta contributors, including Seathre; JollyRogerEXP authored the eight reviewed contribution commits; later review/remediation commits are separately identified in the review bundle.

This revision has no repository-wide <code>LICENSE</code> or <code>NOTICE</code>, so do not assume a blanket license for all 420th additions or bundled media. Preserve and review embedded notices before redistribution:

- [420th user-input-menu license](Apex_framework.terrain/420th/userinputmenus/LICENSE) covers ConnorAU's user-input-menu material and requires its attribution/source-disclosure/same-terms conditions.
- [Advanced Rappelling integration](Apex_framework.terrain/code/scripts/AR_AdvancedRappelling_ext.sqf) retains Seth Duda's MIT notice.
- Media and insignia folders contain their own author notices; Bohemia Interactive game content remains subject to its original terms.

## Maintaining this README

For each future source change, update the appropriate row in the upstream ledger, preserve the exact comparison revision, state whether a difference is behavior, content, asset, documentation, or line-ending-only, and link the evidence used to validate it. Keep the Quiksilver comparison separate from internal 420th integration bases, retain third-party notices, and never place private server configuration or credentials in this repository.
