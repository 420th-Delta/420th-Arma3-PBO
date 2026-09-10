"""Stage the Lab's fixed, reviewed Scout control in an isolated test fixture."""
import hashlib
import importlib.util
from pathlib import Path


MODE = "reviewed-scout-v1"
PBO_SHA = "fe7471e5491262c4b157bb3408cb8515bb2fe60b405b731c1da86018d49b31a5"
WITNESS = r'''// Altered-content observation only; no configuration writes or error filtering.
private _patch = configFile >> 'CfgPatches' >> 'FRZ_MfdControl';
private _active = (activatedAddons findIf {toLower _x isEqualTo 'frz_mfdcontrol'}) >= 0;
private _required = getArray (_patch >> 'requiredAddons');
private _patchOK = isClass _patch && {_active} && {_required isEqualTo ['A3_Armor_F_Tank_LT_01']};
['mfd_control_patch_active',_patchOK,[isClass _patch,_active,_required]] call IA_fnc_assert;
private _properties = [];
private _conditionsOK = TRUE;
{
    _x params ['_class','_parent'];
    private _cfg = configFile >> 'CfgVehicles' >> _class;
    private _draw = _cfg >> 'MFD' >> 'MFD_Gunner_Ready_To_Fire' >> 'Draw';
    private _condition = _draw >> 'condition';
    private _sources = configSourceAddonList _draw;
    private _ok = isClass _cfg && {configName (inheritsFrom _cfg) isEqualTo _parent}
        && {isText _condition} && {getText _condition isEqualTo '0'}
        && {_sources isEqualTo ['A3_Armor_F_Tank_LT_01','FRZ_MfdControl']};
    private _row = [_class,isClass _cfg,configName (inheritsFrom _cfg),isText _condition,getText _condition,_sources];
    _properties pushBack _row;
    _conditionsOK = _conditionsOK && {_ok};
    ['mfd_control_condition_' + _class,_ok,_row] call IA_fnc_assert;
} forEach [['LT_01_scout_base_F','LT_01_base_F'],['I_LT_01_scout_F','LT_01_scout_base_F']];
private _version = productVersion;
private _buildOK = (_version # 1) isEqualTo 'Arma3'
    && {(_version select [2,3]) isEqualTo [222,154045,'Stable']}
    && {(_version select [6,2]) isEqualTo ['Windows','x64']};
['mfd_control_native_build',_buildOK,[_version]] call IA_fnc_assert;
['mfd_control_observed',[1,'reviewed-scout-v1','__PBO_SHA__',clientOwner,_version,
    isClass _patch,_active,_required,_properties]] call IA_fnc_log;
['mfd_control_native',_patchOK && {_conditionsOK} && {_buildOK}] call IA_fnc_assert;
'''.replace("__PBO_SHA__", PBO_SHA)


def stage(lab, arma, fixture, mission):
    """Return (private addon directory, sanitized provenance); never modify installed assets."""
    lab, arma, fixture, mission = (Path(p).absolute() for p in (lab, arma, fixture, mission))
    module_path = lab / "scripts/freeze/mission/mfd_control.py"
    spec = importlib.util.spec_from_file_location("ia_reviewed_mfd_control", module_path)
    if spec is None or spec.loader is None:
        raise ValueError("Reviewed Lab MFD validator is unavailable")
    reviewed = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reviewed)
    reviewed.need(reviewed.MODE == MODE and reviewed.PBO_SHA == PBO_SHA, "Reviewed MFD adapter identity changed")
    reviewed.need(fixture.name == "fixture" and mission == fixture / "mission", "MFD requires the private fixture mission")
    reviewed.regular(fixture / "unused", lab / "artifacts/ia-update", False)
    sqm = reviewed.regular(mission / "mission.sqm", fixture)
    init = reviewed.regular(mission / "init.sqf", fixture)
    reviewed.need(init.stat().st_size <= 1024 * 1024, "MFD init exceeds bounded size")
    initial = init.read_text(encoding="utf-8-sig")
    anchor = "// HARNESS_ABORT_BEGIN"
    reviewed.need(initial.count(anchor) == 1 and "IA_fnc_assert =" in initial.split(anchor)[0]
                  and "IA_fnc_log =" in initial.split(anchor)[0], "MFD requires initialized native harness witnesses")
    reviewed.declare_bytes(sqm.read_bytes())
    addon = fixture / "mfd-control/@MfdControl"
    target = reviewed.regular(addon / "addons/frz_mfd_control.pbo", fixture, False)
    witness = reviewed.regular(mission / "ia-tests/mfd-control.sqf", fixture, False)
    reviewed.need(not addon.parent.exists() and not witness.exists(), "MFD staging refuses existing output")
    plan = {"lab": str(lab), "arma_root": str(arma), "tools_root": str(arma.parent / "Arma 3 Tools"),
            "mfd_control_mode": MODE}
    plan["mfd_control_identity"] = reviewed.identity(plan)
    identity = reviewed.validate(plan)
    payload = (Path(identity["root"]) / reviewed.PBO).read_bytes()
    reviewed.need(hashlib.sha256(payload).hexdigest() == PBO_SHA, "MFD package changed while staging")
    target.parent.mkdir(parents=True, exist_ok=False)
    with target.open("xb") as stream:
        stream.write(payload)
    reviewed.need(reviewed.digest(target) == PBO_SHA, "MFD private package copy differs")
    dependency = reviewed.declare_dependency(sqm)
    witness.parent.mkdir(parents=True, exist_ok=True)
    with witness.open("x", encoding="utf-8") as stream:
        stream.write(WITNESS)
    call = "call compile preprocessFileLineNumbers 'ia-tests\\mfd-control.sqf';\n"
    init.write_text(initial.replace(anchor, call + anchor), encoding="utf-8")
    provenance = {
        "schema": "420th.ia-update.mfd-control/1", "mode": MODE,
        "source": reviewed.RELATIVE.as_posix(), "pbo_sha256": PBO_SHA,
        "files": dict(reviewed.PINS), "tools": dict(reviewed.TOOL_PINS),
        "tank_asset": "Tank/Addons/armor_f_tank.pbo", "tank_sha256": identity["tank_sha256"],
        "native_build": identity["native_build"], "scope": identity["scope"],
        "staged_pbo": target.relative_to(fixture).as_posix(),
        "mission_dependency": dependency,
        "witness": witness.relative_to(mission).as_posix(), "witness_sha256": reviewed.digest(witness),
        "init_sha256": reviewed.digest(init),
    }
    return addon, provenance
