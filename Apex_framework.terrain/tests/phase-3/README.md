# Phase 3 static validation

Run these checks from the repository root:

```powershell
python Apex_framework.terrain/tests/phase-3/validate_scope.py
python Apex_framework.terrain/tests/phase-3/validate_role_systems.py
```

`validate_scope.py` compares the worktree with `stage/phase2-aa-turrets-20260912`. It protects the Phase 1 Taru integration block, the Phase 2 AA/controller and deployable-container sources, and the files deliberately excluded from Jolly's update.

`validate_role_systems.py` verifies static registration and lifecycle markers for Support roles, optional shared radio/staff channels, revive/Kavala, and mapped-house entity state. Both checks use only Python's standard library and Git; neither executes SQF or replaces the engine acceptance cases in [the rollout plan](../../../docs/rollouts/PHASED_UPDATE_ROLLOUT.md).
