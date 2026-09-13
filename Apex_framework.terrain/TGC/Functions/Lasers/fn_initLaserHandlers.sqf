/*
Function: TGC_fnc_initLaserHandlers

Description:
    Set up laser target handlers.
    Function must be executed in scheduled environment.

Author:
    thegamecracks

*/
// TODO: add stringtable for localization
private _category = "420th Delta";
private _laser = "Laser Designators";
[
    "TGC_laserTarget_ignore",
    "CHECKBOX",
    ["Prevent AI Targeting", "Prevent AI in your group from targeting lasers. Useful for AI gunners in vehicles."],
    [_category, _laser],
    true,
    false,
    {
        // TODO: retroactively apply to existing laser targets
    },
    false
] call TGC_fnc_addSetting;
[
    "TGC_laserTarget_ignore_skipLocal",
    "CHECKBOX",
    ["Allow Local Targets", "When preventing AI targeting, allow AI to target your own lasers."],
    [_category, _laser],
    true,
    false,
    {
        // TODO: retroactively apply to existing laser targets
    },
    false
] call TGC_fnc_addSetting;
[
    "TGC_laserTarget_draw3D",
    "CHECKBOX",
    ["Visualize Laser Targets", "Render 3D icons for laser targets detected by your vehicle's sensors."],
    [_category, _laser],
    true,
    false,
    {},
    false
] call TGC_fnc_addSetting;

if (!hasInterface) exitWith {};

addMissionEventHandler ["EntityCreated", {
    params ["_entity"];
    if (!TGC_laserTarget_ignore) exitWith {};
    if (TGC_laserTarget_ignore_skipLocal && {local _entity}) exitWith {};
    if !(_entity isKindOf "LaserTarget") exitWith {};

    private _groups = allGroups select {local _x};
    {_x ignoreTarget _entity} forEach _groups;
}];

addMissionEventHandler ["Draw3D", {
    if (!TGC_laserTarget_draw3D) exitWith {};

    private _vehicle = objectParent focusOn;
    if (isNull _vehicle) exitWith {};

    assignedVehicleRole focusOn params [["_role", ""]];
    if !(_role in ["driver", "turret"]) exitWith {};

    private _laserTargets =
        getSensorTargets _vehicle
        select {_x # 1 isEqualTo "lasertarget"}
        apply {_x # 0};
    if (count _laserTargets < 1) exitWith {};

    private _side = side group focusOn;
/* Legacy Code as of 9.9.2026 */
//|    private _laserInstigators = [_side] call TGC_fnc_findLaserInstigators;
// Updated Code
    // Only owner labels need a short cache; sensor targets and icon positions
    // still update every draw. Changing the observer, vehicle or side refreshes it.
    private _observer = focusOn;
    private _now = diag_tickTime;
    private _labelCache = localNamespace getVariable ["TGC_laserTarget_labelCache",[]];
    if (
        (count _labelCache isNotEqualTo 5) ||
        {(_labelCache # 0) isNotEqualTo _side} ||
        {(_labelCache # 1) isNotEqualTo _observer} ||
        {(_labelCache # 2) isNotEqualTo _vehicle} ||
        {_now >= (_labelCache # 3)}
    ) then {
        _labelCache = [_side,_observer,_vehicle,_now + 0.25,[_side] call TGC_fnc_findLaserInstigators];
        localNamespace setVariable ["TGC_laserTarget_labelCache",_labelCache];
    };
    private _laserInstigators = _labelCache # 4;
// End Updated Code
    {
        private _isTarget = cursorTarget isEqualTo _x;
        private _distance = focusOn distanceSqr _x;
        private _size = linearConversion [2500, 6250000, _distance, 1, 0.5, true];

/* Legacy Code as of 9.9.2026 */
//|        _laserInstigators
//|            get netId _x
// Updated Code
        (_laserInstigators getOrDefault [netId _x,[objNull,objNull]])
// End Updated Code
            params [["_vehicle", objNull], ["_instigator", objNull]];
        if (_vehicle isEqualTo _instigator) then {_vehicle = objNull};

        private _vehicleName = configOf _vehicle call BIS_fnc_displayName;
        private _name = switch (true) do {
            case (isPlayer _instigator): {name _instigator};
            case (!isNull _instigator): {"AI"};
            default {""};
        };
        private _text = switch (true) do {
            case (_vehicleName != "" && {_name != ""}): {format ["%1 (%2)", _vehicleName, _name]};
            case (_vehicleName != ""): {_vehicleName};
            default {_name};
        };

        drawIcon3D [
            "\a3\ui_f_curator\data\cfgcurator\laser_ca.paa",
            [1, 0.2, 0.2, [0.5, 0.9] select _isTarget],
            getPosATL _x,
            _size,
            _size,
            0,
            _text,
            2
        ];
    } forEach _laserTargets;
}];
