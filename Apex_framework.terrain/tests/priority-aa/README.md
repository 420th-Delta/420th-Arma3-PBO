# Native Priority AA validation

From the repository root on a Windows machine with Arma 3 installed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apex_framework.terrain\tests\priority-aa\run.ps1 -Headless
```

The default game location is `D:\SteamLibrary\steamapps\common\Arma 3`; override it with `-ArmaRoot`. The default port is 24760 and timeout is 360 seconds. The runner requires permission to write a uniquely named mission to the game's `MPMissions` directory. It refuses an existing target or occupied port, starts only its own hidden server/client processes, and removes only that temporary installed mission. Omit `-Headless` to explicitly skip the ownership-transfer case. For focused investigation use `-Cases live` or another case name; the manifest records the selected cases, and a focused pass does not replace a full run.

Evidence stays in ignored `artifacts/<timestamp>/`: a staged source copy, SHA-256 manifest, engine version, server/client RPTs and `assertions.log`. Success requires the completion marker, zero failed assertions and zero fixture script errors. The manifest records the remote-main baseline used for this change, `a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7`.

Cases use the native engine and real vehicle configurations:

- `targeting.sqf`: target classification/order, compatible weapons, empty ammunition, protected-base behavior, native state restoration, firing veto and scripted CAS preemption. Candidate contacts are injected to make ordering deterministic.
- `scheduler.sqf`: injected-clock timer bounds, new-AO mode, queuing, retry and pause/force behavior, independent task deletion and simultaneous reward queuing. Mission workers and reward effects are controlled fixtures.
- `battery.sqf`: actual site search, compound, radar/launchers, Viper counts, mobile guards, reload cycles, objective success/abort and cleanup. Unrelated framework patrol/cosmetic helpers are stubbed; this does not test guard combat effectiveness.
- `legacy.sqf`: low-population Tigris composition, original location search, ordinary mission interface and abort cleanup. The unchanged ordinary guard generator is stubbed.
- `live.sqf`: native Cronus contacts and Rhea datalink, actual AI missile firing at an invulnerable WEST jet flying a controlled loiter orbit, and a subsequent base-exclusion hold. No injected sensor contacts. The unarmed target does not fight back, so this is not evidence of dogfight or countermeasure effectiveness.
- `locality.sqf`: actual server-to-headless-client-to-server group transfer, owner-local controller state, protected-base hold, unregister restoration and departed-crew restoration. Candidate contacts are injected for stable transfer assertions.
- `datalink.sqf` (optional, `-Cases datalink -TimeoutSeconds 600`): isolated Tigris, Nyx, jet, UAV and Kajman sender survey without Cronus. Logs native sensor/electronics defaults, reproduces audited mission crew sides and explicit reporting hooks, and records real contacts, Rhea selection and missile launches. Aircraft senders are repositioned behind a moving jet to control sensor geometry. Unsuccessful current settings get a separately labeled diagnostic phase with reporting/radar enabled, EAST crew and camera aiming. A bounded failure to acquire is an observation, not proof a sensor cannot ever acquire; negative survey rows do not fail the harness.
- `datalink_camera.sqf` (optional, `-Cases datalink_camera -TimeoutSeconds 320`): focuses that survey on Neophron, UAV and Kajman sensors. The diagnostic phase explicitly aims native pilot/turret cameras at the target's position, without creating sensor contacts or requiring a positive finding. Native configuration errors remain visible to the harness in both survey cases.
- `datalink_emitter.sqf` (optional, `-Cases datalink_emitter -TimeoutSeconds 320`): the same five sources against a real flying NATO F/A-181 with radar emitting. Sources are positioned ahead of the emitting jet and face it, inside both forward sensor cones. Logs radar-warning threats separately from target contacts and Rhea launches; also records Cheetah/Xian native configuration without engagement trials.

The fixture also compiles all changed production SQF files. Run the static checks separately:

```powershell
node Apex_framework.terrain/tests/priority-aa/validate-registration.cjs
node Apex_framework.terrain/tests/validate-server-performance.cjs
git diff --check
```

`validate-registration.cjs` verifies that FIA HQ and legacy Independent side-mission Tigrises register after their crews are created, that the Tigris remains an eligible controller class, and that the registration function remains compiled. It is a focused source-level regression guard; historical side-mission execution still needs an engine run when those routes change.

Graphical UI, opposed air combat, production mods and live-server performance are outside this isolated fixture's coverage.

Final combined run on 2026-09-11: **251 passed, zero failures, zero script errors**, with an actual headless client; artifact `artifacts/20260911-160324-900/`.

Optional datalink surveys record negative observations as findings, not failed assertions of universal capability. The broad survey also preserves a native Nyx Recon MFD error. See the [datalink findings](../../../docs/air-defense-datalink.md) for conditions and evidence.
