# EXT-1: Stock Nyx Scout MFD failure

The full-mission cell `a599b201e269-integration` reports one native expression failure at 21:01:12: undefined `ammo1` while compiling `(ammo1+ammo2)`. The next RPT line identifies the evaluator: `unable to compile MFD condition`. Its ScriptError event has no SQF source filename or call stack. Mission SQF contains no `ammo1` expression. This is an external stock-asset issue, not an artillery resource variable introduced by the community update.

The owning installed configuration is:

```text
Tank/Addons/armor_f_tank.pbo
  LT_01/config.bin
  CfgVehicles/LT_01_scout_base_F/MFD/MFD_Gunner_Ready_To_Fire/Draw/condition
  value: (ammo1+ammo2)
  inherited concrete vehicle: I_LT_01_scout_F
```

The PBO was rehashed on 2026-09-10: SHA-256 `792ac23ecc486d20ae83d962e5f3abd14e1db3cfcb5d4f1324ef0f31e8ab104d`. This matches the preserved Server Lab investigation's input pin. That investigation retains the original extracted/decoded config entry and native reproduction; no installed asset was changed for this review.

## Existing independent engine evidence

`420th-Arma3-Server-Lab/docs/MFD_AMMO_WARNING.md` records two fresh Windows Arma 3 2.22.154045 dedicated processes with no Apex mission code, custom mods, database, headless client or graphical player:

| Control | Result |
| --- | --- |
| Read Scout configuration without creating an object | Zero MFD/expression errors. |
| Create one stock I_LT_01_scout_F with createVehicleLocal | Exactly one matching compilation failure between creation begin/end sentinels; the strict error gate fails. Creation and cleanup still complete. |

The primary artifacts remain under the Lab's ignored `artifacts/ammo-mfd-investigation/`. A subsequent independently preserved four-cell control, `artifacts/owner-campaign-20260906/mfd-control/runs/mfd-134b087007e8`, compares 2,301 measured properties per cell. Its private configuration addon changes only the one defining Scout ready-to-fire condition to `0` (two effective inherited paths). It removes that observed error, but does not establish cockpit correctness, gameplay equivalence, a production remedy or a stock-content pass. The original stock creation failure remains a failure.

The Lab supports that exact pinned addon as an explicit prospective control through `scripts/freeze/mission/mfd_control.py`. The community-update runner now has a separate, optional `reviewed-scout-v1` adapter; the default remains off. No error allowlist, global ammo variable or hidden addon activation was introduced here.

## Optional controlled integration lane

`tests/ia-update/mfd_control.py` adapts the existing reviewed Lab implementation. Before staging, it validates all pinned source/build files, the existing PBO, both recorded Arma 3 Tools binaries and the installed Tank PBO through the Lab validator. It copies only the verified PBO into the run's private `fixture/mfd-control/@MfdControl/addons/`, declares the dependency only in the private mission, and records relative provenance and hashes. It does not rebuild the addon or modify the source mission or installed game.

Every participating process executes a read-only native witness immediately after the common harness definitions. The assertions require the activated `FRZ_MfdControl` patch and exact dependency, both effective typed condition values `0`, expected inheritance and addon-source lists, and Windows x64 Arma 3 stable build 2.22.154045. The strict script/RPT error gates still apply. Missing or incorrect control activation fails the cell; controlled results must be labelled altered-content evidence.

The staging-only check `acc4e4306e5e-mfd-stage-check` passed eight checks against the actual pinned inputs: Python syntax, complete reviewed provenance validation, one-file PBO staging, dependency insertion, witness placement after common helpers, sanitized provenance, duplicate-stage rejection and source-mission rejection. This did not launch an engine. Native controlled integration results are recorded separately in the local test report once complete.

## Baseline and startup-path comparison

The inherited `fn_config.sqf` startup spawns `fn_easterEggs.sqf`, which creates four random decorative vehicles. Both of its vehicle lists include I_LT_01_scout_F. The four model warning groups immediately before the full-mission failure match selectable vehicles on that path. This identifies a plausible startup trigger; the exact caller in `a599b201e269` remains an inference because its error event has no call stack or creation sentinel.

The relevant source is unchanged between upstream baseline `a0a58e1` and imported review snapshot `dec9787`:

| File | Identical Git blob |
| --- | --- |
| code/functions/fn_easterEggs.sqf | `77ec48ffd5fa412120db6369196e3e34fae3fda3` |
| code/config/QS_data_listVehicles.sqf | `c3cb191a13ac678188df98dc2d5871fe51b6258c` |

The stock class also remains available through normal gameplay paths, including the inherited regenerator side mission. Removing it from a decorative list would not correct the underlying asset condition. No mission source change is justified by this investigation alone. Preserve the strict stock integration result and report any separately selected content control as altered-content evidence.
