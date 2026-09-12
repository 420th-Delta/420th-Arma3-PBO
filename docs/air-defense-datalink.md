# Rhea contact sharing audit

Checked on 2026-09-11 against the mission based on remote main `a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7`, with the new AA changes, using vanilla Arma 3 2.22.

**The Rhea can fire without a Cronus.** Native tests produced actual missile launches at a flying NATO jet using a Tigris or the regenerator mission's Nyx Recon. No Cronus, scripted reveal, `confirmSensorTarget` call or injected datalink report was provided.

The launcher receives its side's datalink network rather than being bound to one radar. A sender must acquire a usable contact and transmit it. EAST and Independent being allies does not merge their contact networks. See Bohemia's [sensor mechanics](https://community.bistudio.com/wiki/Arma_3%3A_Sensors) and [contact reporting command](https://community.bistudio.com/wiki/setVehicleReportRemoteTargets).

## Results and mission policy

Tests retain current mission/default reporting first, then run separately labelled diagnostic phases with reporting or crew side changed. Those changes are confined to the test mission.

| Sender | Current mission policy | Native result |
| --- | --- | --- |
| Tigris | Native radar/transmission enabled; battery guards are EAST. | Acquired and shared the jet, supporting an actual Rhea launch. |
| Nyx Recon | Regenerator enables radar/transmission/reception and joins the crew to its EAST group. | Acquired and shared the jet, supporting an actual Rhea launch. |
| Nyx AA | Receives datalink; has no independent radar/IR/visual acquisition sensor. Transmission defaults off. | Did not originate a contact even with sending enabled. Distinct from Recon. |
| Shikra | Ordinary CAS transmission defaults off; Defend explicitly enables reporting/radar. | Detected the jet. Actual Rhea launch after reporting was enabled. |
| Gryphon / Buzzard | Ordinary CAS uses EAST crews with transmission off. Defend can retain native Independent crews. | Both detected the jet and supported actual Rhea launches with reporting enabled and EAST crews. |
| Neophron | Ordinary CAS transmission off; no active radar, with optical and passive-radar sensors. | No optical acquisition of the fast jet. An emitting NATO fighter produced a passive-radar track and an actual Rhea launch after reporting was enabled. |
| UAV-02, CSAT / Independent | Native transmission on; Defend also enables reception. Native crew side retained. | No optical acquisition of the fast test jet. Detected the emitting fighter through passive radar, but supplied no usable Rhea track or launch, including the diagnostic with EAST crews. |
| CSAT Fenghuang UCAV (`O_T_UAV_04_CAS_F`) | Native transmission on; Defend enables reception. | No optical acquisition of the fast test jet. Passive detection of the emitting fighter supplied no usable Rhea track or launch, including explicit diagnostic settings. |
| Kajman | Classic escort retains native transmission off. Active radar has a lower target-speed ceiling than dedicated radars. | No radar/optical acquisition of the fast test jet. Passive detection of the emitting fighter supplied no Rhea track or launch, even with reporting enabled. |

Destroying the Cronus therefore does not guarantee that the Rhea launchers become blind. Other surviving EAST transmitters can supply contacts. The objective requires destruction of every Rhea and the Cronus.

Two additional candidates were inspected in native configuration, without engagement trials: Cheetah has transmission/reception enabled and a 9 km active radar; Xian has transmission/reception enabled and a 5 km active radar. A Cheetah must have the appropriate enemy crew side to feed an EAST Rhea. These are configuration findings, not additional verified missile launches.

## Native limits

The test jet travelled at roughly 150 m/s (540 km/h). Actual engine configuration limits explain several negative results:

| Sensor | Maximum target speed |
| --- | --- |
| Neophron IR / visual | 100 m/s (360 km/h) |
| UAV-02 / Fenghuang IR / visual | 50 m/s (180 km/h) |
| Kajman IR / visual | 70 m/s (252 km/h) |
| Kajman active radar | 125 m/s (450 km/h) |

Explicit camera aiming did not overcome these limits. They constrain those sensor channels, not every possible target or sensor mode. Slower targets, radar emissions, terrain and field of view can change the outcome. Bohemia defines these speed limits in metres per second and distinguishes detection from missile locking in its [sensor configuration reference](https://community.bistudio.com/wiki/Arma_3%3A_Sensors_Config_Reference).

The emitting-fighter follow-up separated native sensor awareness from usable shared targets. All five investigated sources detected the emitter through passive radar; only the Neophron supplied a Rhea contact and actual launch after reporting was enabled. The UAV/Kajman result is consistent with the documented distinction between radar warnings and targetable tracks, but that explanation is an inference: their `allowsMarking` values were not captured. These bounded trials do not establish that they can never support a Rhea against slower targets or under other conditions.

## Source and evidence

Relevant mission functions are `fn_SMregenerator.sqf` (Recon setup), `fn_aoEnemy.sqf` (initial crews joined to EAST), `fn_aoEnemyReinforceVehicles.sqf` (native EAST/Independent reinforcement crews retained), `fn_enemyCAS.sqf` (normal CAS and virtual-sector overrides), `fn_aoDefend.sqf` (explicit jet/UAV reporting), and `fn_SMpriorityAA.sqf` (Rhea reception). All are under `Apex_framework.terrain/code/functions/`.

Each survey profile isolates one sender with a fresh Rhea and NATO aircraft. Aircraft tests control geometry/camera direction, so they prove capability under recorded conditions, not autonomous combat tactics or production-mod behavior.

- Broad survey: `tests/priority-aa/artifacts/20260911-154853-054/`, 99 assertions, no assertion failures, one native Nyx Recon MFD error compiling `(ammo1+ammo2)` during vehicle creation. The runner preserved the error and returned failure. It occurred before fixture configuration reads, outside the changed mission SQF.
- Camera follow-up: `tests/priority-aa/artifacts/20260911-155742-667/`, 73 assertions, no failures or script errors.
- Emitting-fighter follow-up: `tests/priority-aa/artifacts/20260911-160629-956/`, 75 assertions, no failures or script errors. A preceding probe, `20260911-160227-889`, was interrupted because its sources were outside the emitter's forward radar beam; its evidence is retained and it is not a completed validation.
- RPT records `T420_AA_DATALINK_CONFIG`, `T420_AA_DATALINK_RESULT` and samples distinguish source acquisition, Rhea reception, controller selection and actual firing.

The fixture's historical `uav_sentinel_defend` label refers to the logged CSAT class `O_T_UAV_04_CAS_F` (Fenghuang), not the NATO Sentinel. The class identifier in the evidence is authoritative.

These optional surveys are separate from the main AA regression suite. No global enemy contact-sharing policy was changed by this audit; ordinary CAS retains its existing transmission settings.
