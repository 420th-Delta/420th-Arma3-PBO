# Local remediation verification

The focused remediation suites pass on Windows Arma 3 **2.22.0.154045**. The controlled full-mission matrix also passes, including a final two-HC cycle on the complete corrected source. Stock-content integration retains the external Scout MFD failure described below. The [issue ledger](REMEDIATION_LEDGER.md) records mission defects, fixes, test-fixture defects and historical failures. These are locally executed results; the supplied contributor verifiers were not available.

## Latest focused results

| Suite | Frozen cell | Assertions | Result and scope |
| --- | --- | ---: | --- |
| Player artillery and mortar support | `b11ac9b1b0a4-support` | 207 | Pass. Real client menus and observer lifecycle; authenticated requests; scheduled admission/cancellation; mortar resource reservation, exact-container debit, ownership handoff at the real three-second cadence, three-slot cap and free-request preservation; role/epoch publication; actual JTAC release and rejected-release refund. |
| Damage and guided ammunition | `f57c8d30a524-damage` | 98 | Pass. Eight production ammunition profiles, exact atomic release, finite native flight/impacts, attribution and 5,286 eligible friendly on-foot callbacks across sixteen variants; native cluster descendants; dead/missing designation rejection without round debit. |
| AI and spawn placement | `9159954efb59-ai-spawn` | 23 | Pass. Final slot exclusions/spacing, legacy mandatory-call behavior, concurrent/expired/stale claims, rotary hull/crew registration and cleanup, exemptions and cancellation during creation. |
| Radio and deferred cleanup | `3e45c5f9b45c-radio-cleanup` | 70 | Pass. Actual channel permissions/membership and staff GUI; donor expiry; old/replacement-body races; Side fallback; city generation/protection checks; holder cargo deadline renewal and next-frame deletion. |

A fifth focused comparison, **`efdcf250f5be-hq-delete`**, passes **282/282** checks with two actual graphical clients and a 75-second launch gap. It reproduces the baseline placement failure, then verifies the corrected mapper, post-callback orientation, authenticated feature-field transport, later snapshot replacement, genuine engine JIP replay, forged-client rejection and native deletion. Feature evidence covers transport and production setter execution, not visual rendering. The exact tested candidate is now production source; see the [HQ investigation](hq-native-investigation.md).

All five cells completed with **zero failed assertions, script errors, malformed records, cleanup errors or changed frozen/deployed files**. Assertion counts include repeated status/transport observations and are not counts of independent gameplay scenarios. Historical failed runs remain part of the campaign evidence.

The focused support fixture uses an explicit native attach helper instead of the complete interactive placement UI. AI setup/task dependencies are inert where documented. Damage victims/callers are engine AI; the actual damage modifier is executed, but this does not establish player-facing Robocop UI behavior. Radio fixtures use real engine objects and GUI controls, including separate old/replacement bodies; they do not establish voice audibility or a human death/respawn session.

## Full mission and configuration

The integration matrix runs the complete mission with one actual local graphical client and zero, one and two HCs. It uses private Apex configuration, CLASSIC mode, disabled automatic restart and no database addon. Private `skipLobby=1` and `joinUnassigned=0` automate role entry. Source gameplay functions, real player counts, mission time and AI caps are retained.

Stock-content cell `a599b201e269-integration` admitted its player, passed all nine assertions and observed 120 seconds of mission activity. It remains a failed strict-RPT run: one stock Nyx Scout MFD expression failure produced five matched error lines. The same error was previously reproduced in this lab by creating only that stock vehicle with no mission code; the installed Tank PBO still matches that reproduction's SHA-256. A separate baseline mission defect, vehicle sound-controller queries while on foot, produced eighteen native client warnings and is corrected as SYS-08. The earlier rappel errors did not recur.

The following runs use `reviewed-scout-v1`, the lab's pinned private addon that disables only the Scout READY TO/FIRE display condition. They are altered-content controls, with strict error rejection retained, and cannot establish a stock-content pass or a repaired stock asset.

| Headless clients | Frozen cell | Assertions | Result |
| ---: | --- | ---: | --- |
| 0 | `8ff629b6241a-integration` | 22 | Pass. 120-second observation, active Primary controller, admitted player and clean native/error/cleanup/integrity checks. Final ownership: 117 server AI. No on-foot controller warnings across 119.535 seconds of admitted-client heartbeats. |
| 1 | `d3ae2b632fb3-integration` | 28 | Pass. 120-second observation with actual HC object/registry agreement and retained player/controller. Native ownership observations show 29 AI on the HC and 93 on the server; all error/cleanup/integrity checks pass. |
| 2 | `ebf08d51fc72-integration` | 45 | Failed: old-HQ all-null assertion and its aggregate cycle result. All transition checks pass; zero script, cleanup, malformed-record or integrity errors. |
| 2 | `2bd3366547c5-integration` | 45 | Diagnostic rerun fails the same two assertions, with all other gates clean. Of 85 captured HQ objects, 80 become null; five ordinary buildings retain non-null references with owner 0 after the cleanup log. The subsequent physical/network checks resolve this as TEST-19. |
| 2 | `4f1ab1639be5-integration` | 45 | Pass. Primary, forced Defense, cancellation and next Primary complete with both HCs and the player retained. All 45 HQ objects retire: 39 become null; six retained House references have observed deletion events and no network lookup, world/nearest membership or saved collision geometry. All strict error, cleanup and integrity gates pass. This precedes the separate SYS-09 mapper correction. |
| 2 | `7a98937cbfa8-integration` | 45 | Final source pass. Primary, forced Defense, cancellation and next Primary complete with the player and both HCs retained. All 56 HQ objects retire: 53 become null; three House handles satisfy every physical/network deletion criterion. Zero assertion, script, malformed-record, cleanup or integrity errors. |

The zero/one-HC cells and `4f1ab1639be5` precede SYS-09. The final 282-check mapper comparison verifies all three corrected files, and `7a98937cbfa8` runs the complete final production source. All 916 production source hashes match that final frozen cell after execution.

The two-HC run includes the production forced-Defense control and existing cancellation control to exercise Primary -> Defense -> next Primary. That route is distinct from natural objective victory and a full-duration Defense. Population and AO content vary between these cells, so their FPS values are not a comparative performance result.

Native CfgConvert cell `29ab162a5888-config` passes `description.ext`, `code/config/security.hpp` and unchanged `mission.sqm` with exit code zero for all three. The original 56-file outer SQF compilation passed before remediation, but did not compile embedded strings: full mission startup subsequently exposed the five rappel helper failures recorded as AI-06. The corrected full mission now initializes without those errors on the server, graphical client and tested HC. This verifies helper initialization, while actual insertion/descent remains separate acceptance.

Final static checks pass for all **61 changed production SQFs**, **23 SQF fixtures** and **10 Python tools**. The path audit accounts for all 35 corrective production files once; the complete branch changes 64 runtime paths versus upstream. SQF delimiter/string balance and Python compilation are syntax checks, separate from the native assertions above.

An independent final source audit confirms unchanged diagnostic/performance helpers and registrations, retained hostile-aircraft bomb stripping, enabled UAVs, disabled recycler and bounds-loop registration, and exactly one consistent function/RPC registration for each support service. These are source-preservation checks against the recorded upstream and import commits.

## Evidence and reproduction

Run commands and containment are in the [test README](../../../tests/ia-update/README.md). Cell IDs resolve under the sibling Server Lab's ignored `artifacts/ia-update/` directory. Each completed cell retains source/fixture manifests, runner identities, result JSON, native records, RPTs and owned-process cleanup evidence. The committed campaign index preserves all 40 attempts (including 25 recorded failures and four attempts without a recorded pass status). It contains allowlisted metadata and manifest/result hashes, with failed and incomplete attempts retained; raw logs, private configuration and game binaries stay outside the commits.

## Remaining acceptance scope

Human testing is still required for interactive placement, actual respawn/revive and remote-control transitions, voice delivery and player-facing accountability. Independent Steam accounts are needed to establish independent-UID permission behavior. Live mod/database deployment, Linux hosting, moving guided targets, interrupted real insertion/rappelling, natural mission victory, full-duration Defense and matched-population performance comparisons remain separate acceptance work. These local results establish no FPS gain or live-server deployment acceptance.
