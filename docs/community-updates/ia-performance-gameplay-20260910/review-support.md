# Player support, roles, and damage review

Reviewed 2026-09-10. Incoming paths below are relative to `the supplied IA_PerformanceGameplayUpdate/mission directory`. Review compared introduced code in `combat_update.patch` with the incoming files and read unchanged integration functions from `420th-Arma3-PBO` at `origin/main:Apex_framework.terrain/`. No incoming or repository files were edited. This is source review, not Arma execution. Contributor offline fixtures were absent and their claimed passes are not independent validation.

## Findings

### SUP-1 — P1: postInit does not enter the support initializer

- Location: `code/functions/fn_artillerySupport.sqf:9-10`, `:128-138`; registration `description.ext:181`.
- Trigger: Every normal mission load or JIP invokes the registered postInit function.
- Evidence: Bohemia's Functions Library specifies that a postInit function receives `["postInit", didJIP]`. The function copies any leading string into `_mode`, so it selects `postInit`. Its initialization branch accepts only `INIT`. There is no explicit `INIT` call elsewhere in the delivered source. Consequently the client-started flag, EntityKilled/EntityRespawned handlers, and two-second CLIENT observer never start. [Official CfgFunctions reference](https://community.bistudio.com/wiki/CfgFunctions).
- Consequence: `INIT_ROLE` may add the menus on a role change, but `fn_incapacitated.sqf:186` removes them while unconscious and there is no observer to restore them after revive. Death/respawn and remote-control reconciliation, and expired ping-handler cleanup, also lack the promised lifecycle observer. Mortar support depends on the same observer through the CLIENT branch at line 161.
- Minimal correction: Explicitly map `postInit` to `INIT`, or accept both names in the initialization branch. Verify fresh join, incapacitation/revive, respawn, role change, and Zeus control exit with all three roles.
- Confidence: Confirmed source/API contract mismatch; engine reproduction still outstanding.

### SUP-2 — P1: virtual ordnance supplies a null firing source to handlers that reject null sources

- Location: `code/functions/fn_artillerySupport.sqf:564`; integration at `code/functions/fn_clientEventHit.sqf:85-100` and `code/functions/fn_clientDamageModifier.sqf:74-82`.
- Trigger: A released support projectile damages a friendly player on foot, for example a player moving into the area after release, or being caught by a submunition. The release-time exclusion does not prevent that case and the package explicitly leaves fired ordnance alive.
- Evidence: New support projectiles use `setShotParents [objNull,_caller]`. The first element identifies the firing vehicle/killer; the second identifies the trigger-puller. The Hit handler immediately exits for a null `_causedBy`, and also excludes an empty firing-vehicle crew. The damage modifier's null-object-source branch leaves `_return` at 0.925 when an instigator/projectile is present; its normal friendly on-foot branch returns 0 or 0.05. `fn_clientEventHandleDamage` calls this modifier before filling in any missing last source. [Official setShotParents reference](https://community.bistudio.com/wiki/setShotParents?useskin=darkvector).
- Consequence: The new support path is incompatible with the stated promise to retain ordinary friendly-fire reduction and Robocop reporting. With a null-source event, support damage bypasses both the normal on-foot friendly-fire multiplier and the report prompt even though the caller is an instigator. Vehicle victims take a different path and should be covered separately.
- Minimal correction: Supply a valid firing source consistent with the existing handlers, or adapt the handlers to resolve player attribution when the firing source is absent. Preserve the distinction between the physical combat side and controller accountability. Run a dedicated-server Hit/HandleDamage capture for HE, guided rounds, rockets, bombs, and cluster submunitions before choosing the correction.
- Confidence: High-confidence integration defect conditional on the documented shot-source event mapping; exact current-engine payloads and submunition inheritance were not executed here. Do not represent this as a reproduced engine result.

### SUP-3 — P2: the new mortar RPC trusts the client to spend its tube

- Location: `code/functions/fn_mortarSupport.sqf:351-364`, `:395`, `:434-438`; client consumption at `:133-136`.
- Trigger: An authorized Mortar Gunner with one tube sends REQUEST/TUBE and a matching ACK with `_placed = TRUE` without running the client placement/consumption branch.
- Evidence: The server checks that a tube exists at request admission. It does not reserve or debit that inventory; the only `removeBackpack` is on the client. A mortar entry stores object, nonce, pending state, and deadline, but not whether tube consumption was required. ACK checks object/nonce/role/deadline and the client Boolean, without verifying inventory consumption. Thus that same tube remains eligible for further REQUEST/TUBE operations. TUBE intentionally has no request cooldown.
- Consequence: The exposed RPC allows an eligible client to turn one backpack into repeated eight-round mortars, defeating the newly advertised inventory cost. The three-section cap does not fix issuance: spent mortars can retire, or RESET can clear the section while retaining the backpack.
- Minimal correction: Track the admitted request kind and server-observed tube consumption as part of the reservation/acknowledgment protocol. Revalidate the inventory state before making the mortar usable. This must account for inventory locality and cancellation; simply trusting another client Boolean is insufficient.
- Confidence: Confirmed source-level missing trust-boundary check; adversarial RPC test not executed. This is a new endpoint's resource-accounting defect, not a claim that the existing mission is generally cheat-proof.

## Commit boundaries and dependencies

1. **Centralize physical-attacker attribution for damage and friendly-fire reporting.** Keep the ATTACKER helper in `TGC/Functions/Damage/fn_isFriendlyFire.sqf` together with its consumers in `fn_clientDamageModifier.sqf`, `fn_clientEventHit.sqf`, and the attribution hunks of `fn_incapacitated.sqf`. This is independently reviewable from support gameplay.
2. **Add Forward Observer/JTAC support and role registration.** New `fn_artillerySupport.sqf`, its CfgFunctions/CfgCommunicationMenu/CfgRemoteExec entries, FO UI image and role/arsenal aliases, plus activity lifecycle hunks in `fn_AI.sqf`, `fn_aoDefend.sqf`, and `fn_core.sqf`. The PRIMARY key currently uses the new `QS_primaryPressure_epoch`, so this integration depends on that controller's lifecycle or needs its own equivalent activity token. Resolve SUP-1 and SUP-2 before acceptance.
3. **Add server-tracked mortar sections and supply drops.** New `fn_mortarSupport.sqf`, `fn_clientInteractMortarLite.sqf`, mortar description/menu/security entries, role-description hunks, and the existing core's TICK hook. As written this also depends on the artillery CLIENT observer, which calls it unconditionally. An exact-source stack therefore must introduce both support function files before the observer can run, or temporarily guard that call until the mortar commit. Resolve SUP-3 before claiming server-enforced inventory accounting.
4. **Adjust bleed-out and pilot-revive exceptions.** `description.ext`'s 600-to-240-second setting and the non-attribution `fn_incapacitated.sqf` hunks should be separated from the damage attribution refactor. Kavala's exception depends on its activity flag and core cleanup hunks; support-specific trait exceptions/menu reconciliation depend on the support feature.

Shared whole files must be split by hunks or kept in a clearly named integration commit; copying whole `description.ext`, `fn_roles.sqf`, `fn_incapacitated.sqf`, `fn_core.sqf`, or `fn_AI.sqf` into each topic is not an independent feature split. Preserve the current upstream description changes when integrating the snapshot.

## Additional validation needs, not confirmed findings

- `remoteControlled` requires a local unit according to the [official remote-control tutorial](https://community.bistudio.com/wiki/Remote_Control_Tutorial). Server role guards use it on remote players, while victim-side attacker resolution has a replicated BIS-owner fallback. Confirm remote-control cancellation in a dedicated multiplayer session; server checks alone should not be described as sufficient evidence.
- The mortar entry is reserved before locality transfer, owner and nonce are checked, and RESET/RELEASE invalidate pending acknowledgments before retirement. Retirement waits for crew extraction instead of deleting crew. These are useful safeguards, but must be exercised with an unconscious occupant, reset during placement, disconnect, and a late ACK.
- Artillery reserves stock before worker creation and refunds only its pending rounds. Debits include UID usage and slot usage, with fixed issuance per activity. No definite normal-client stock/refund arithmetic error was established in this review.
- The mortar server handler assumes REQUEST uses remoteExecCall; an authorized client can instead use scheduled remoteExec. Unlike TICK, admission through reservation is not enclosed in an unscheduled transition. Exercise interleaved requests before asserting the three-section cap is race-proof against custom clients.
- Guidance, impact timing, CBU/ICM submunition behavior, per-shot attribution, locality transfer, and actual in-game communication menus still require engine execution. No local fixture or parser substitutes for those tests.
