# Systems merge resolution

Resolved in `420th-Arma3-PBO-ia-update-20260910`, based on upstream `origin/main` a0a58e1, the reconstructed contributor baseline, and the submitted payload. The original Downloads package remains unchanged.

| File | Resolution |
| --- | --- |
| `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf` | Keep the contributor's General/optional Side policy and state cache; preserve upstream donor entitlement reconciliation. Add donor entitlement to the cached state so expiry or renewal cannot be hidden by the early return. Keep group and side at their original cache indexes. |
| `code/functions/fn_clientRadio.sqf` | Preserve upstream's optional third argument identifying the exact target unit. Add the contributor's old-body argument as a fourth optional argument. Keep General subscribed on death and protect mandatory General removal. All add/remove operations continue to use the captured target unit. |
| `code/functions/fn_clientEventRespawn.sqf` | Call `[2,-1,_newUnit,_oldUnit]` synchronously, then force access reconciliation. Retain upstream's one-second retry, player identity guard, aircraft preference restoration, and group-leader reconciliation. |
| `code/functions/fn_spawnGroup.sqf` | Keep the new ground-placement helper and all existing upstream creation/total telemetry. Start the total timer before the new ground admission, and close it with zero units if placement rejects the group. |
| `code/functions/fn_core.sqf` | Keep incoming housekeeping/Kavala/Mega Defense behavior and unconflicted upstream fixes. Restore upstream deletion telemetry around the three field-holder deletion branches moved under the arsenal exclusion. Move former ruin deletion telemetry to the new queued ruin deletion branch. Close periodic cleanup telemetry after the new ruin rotation. Keep the four upstream `count` to `forEach` corrections and completion-based cleanup scheduling. |

Verification: manually reviewed upstream-only diffs; checked resolved radio code against both variants; verified all upstream `QS_fnc_perfBegin` labels and their occurrence counts in `spawnGroup` and `core` remain present (core: 22 ordinary deletes, three crew deletes, and the six existing aggregate/census/AO labels). Conflict-marker check passed for all five resolved files. `git diff --check` found one contributor-origin trailing space in a commented old line in `core`; this is whitespace hygiene, not an engine result. No Arma execution was performed for these resolutions.

The three-way artifact retained a clean UTF-8 en dash in the radio mapping comment, but the committed resolution was later re-encoded into mojibake. The review follow-up replaces all separators in that comment with ASCII hyphens. Other clean-merged files need the same encoding audit before committing.
