# Phase 1 rollout validation

Run the static boundary guard from the repository root:

```powershell
python tests/phase-1/validate_scope.py
```

It prevents Phase 2 AA/jet behavior and Phase 3 Support, role, and Kavala lifecycle code from entering this branch. It is not a replacement for an Arma engine test.

Before review moves this branch out of draft, capture the following controlled Server Lab results against the built PBO:

| Scenario | Required observation |
| --- | --- |
| Primary delivery census | No reinforcement census or spawn work runs before a delivery is due; sub-18 FPS pauses new arrivals. |
| Population boundary | Nearby conscious ground players produce 8–12 person squads and a 24–120 ceiling; aircraft occupants do not count. |
| Primary artillery | Population selects the fixed 3/6/9 mission budget; objective links reduce the remaining budget; mortars use 4 or 6 rounds. |
| Final clearance | All objectives are complete, no inbound delivery remains, and fewer than ten hostile ground troops persist for 15 seconds. |
| Taru delivery | Below 20 players Taru is preferred; at 20+ it stays within the 12.5% cap. Exercise parachute, fast-rope, blocked-rope fallback, pilot loss, 30-second descent drain, and an HC/locality handoff. |
| Spawn Menu locality | Repeated ownership changes, a JIP client, and reconnect leave exactly one vehicle damage callback. |
| Cleanup under load | Arsenal holders, player logistics crates, and ruins drain in bounded batches; induce low FPS and verify smaller batches and no removal of active/player-near assets. |
| Manual Mega Defense | An admin/server-console `['START'] call compile preprocessFileLineNumbers 'code/scripts/IA_MegaDefense.sqf'` requests one 30-minute Defense; it never starts automatically. |

Use CfgConvert on the built PBO and the existing Server Lab mission launch for every native run. A graphical multiplayer client is required for the Taru and Spawn Menu locality cases.
