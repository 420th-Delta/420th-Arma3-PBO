if (!isServer) exitWith {};
call compile preprocessFileLineNumbers 'testConfig.sqf';
T420_AA_errors = [];
T420_AA_passes = 0;
T420_AA_failures = 0;
addMissionEventHandler ['ScriptError',{
    T420_AA_errors pushBack str _this;
    diag_log format ['T420_AA_TEST_SCRIPT_ERROR|%1',_this];
}];
T420_AA_fnc_assert = {
    params ['_condition','_label',['_details','']];
    if (_condition) then {T420_AA_passes = T420_AA_passes + 1} else {T420_AA_failures = T420_AA_failures + 1};
    diag_log format ['T420_AA_TEST_ASSERT|pass=%1|label=%2|details=%3',_condition,_label,_details];
};
T420_AA_fnc_cleanup = {
    params [['_assets',[]]];
    private _groups = [];
    {
        if (_x isEqualType grpNull) then {
            _groups pushBackUnique _x;
            {deleteVehicle _x} forEach units _x;
        } else {
            if (_x isEqualType objNull && {!isNull _x}) then {
                if (!isNull group _x) then {_groups pushBackUnique group _x};
                {if (!isNull group _x) then {_groups pushBackUnique group _x}} forEach crew _x;
                if (_x isKindOf 'AllVehicles' && {!(_x isKindOf 'Man')}) then {deleteVehicleCrew _x};
                deleteVehicle _x;
            };
        };
    } forEach _assets;
    {if (!isNull _x && {units _x isEqualTo []}) then {deleteGroup _x}} forEach _groups;
};
[] spawn {
    waitUntil {time > 0};
    diag_log 'T420_AA_TEST_BEGIN';
    [allUnits select {!(_x isKindOf 'HeadlessClient_F')}] call T420_AA_fnc_cleanup;
    {
        private _source = preprocessFileLineNumbers _x;
        private _compiled = compile _source;
        [_source isNotEqualTo '' && {_compiled isEqualType {}},'compile/' + _x] call T420_AA_fnc_assert;
    } forEach (call compile preprocessFileLineNumbers 'changed.sqf');
    {
        missionNamespace setVariable ['QS_fnc_' + _x,compile preprocessFileLineNumbers ('code\functions\fn_' + _x + '.sqf')];
    } forEach [
        'airDefenseInit','airDefenseUseEnhanced','airDefenseRegister','airDefenseController','airDefenseClassifyTarget',
        'airDefenseSelectTarget','airDefenseApply','airDefenseRelease','airDefenseFired','airDefenseReinforcementPool',
        'priorityAAScheduler','priorityAASidePool','priorityAADebrief','sideMissionPositions','priorityAAFindSite','priorityAAGuards',
        'SMpriorityAA','SMpriorityAALegacy','smEnemyEast','smDebrief','waterInRadius','serverObjectsMapper','commonMultiplyMatrix',
        'getAIMotorPool','perfBegin','perfEnd'
    ];
    {
        missionNamespace setVariable ['QS_data_' + _x,compile preprocessFileLineNumbers ('code\config\QS_data_' + _x + '.sqf')];
    } forEach ['listVehicles','listUnits','groupCompositions'];
    // Initial public config changes are delivered after the first scheduler yield.
    // Drain both real init publications before individual cases make local overrides.
    T420_AA_configPublications = 0;
    'QS_missionConfig_airDefense_reinforcementWeight' addPublicVariableEventHandler {
        T420_AA_configPublications = T420_AA_configPublications + 1;
    };
    [] call QS_fnc_airDefenseInit;
    [(missionNamespace getVariable 'QS_missionConfig_priorityAA_interval') isEqualTo [600,1800],'config/default-timer-10-30-minutes'] call T420_AA_fnc_assert;
    [!(missionNamespace getVariable 'QS_missionConfig_priorityAA_onNewAO'),'config/ao-mode-default-off'] call T420_AA_fnc_assert;
    [(missionNamespace getVariable 'QS_missionConfig_airDefense_baseExclusionRadius') isEqualTo 2000,'config/base-exclusion-default'] call T420_AA_fnc_assert;
    private _configuredThreshold = missionNamespace getVariable 'QS_missionConfig_priorityAA_minPlayers';
    [_configuredThreshold isEqualTo 40,'config/default-population-threshold-40'] call T420_AA_fnc_assert;
    [!([_configuredThreshold - 1] call QS_fnc_airDefenseUseEnhanced),'config/below-threshold-uses-legacy'] call T420_AA_fnc_assert;
    [[_configuredThreshold] call QS_fnc_airDefenseUseEnhanced,'config/at-threshold-uses-enhanced'] call T420_AA_fnc_assert;
    [[_configuredThreshold + 1] call QS_fnc_airDefenseUseEnhanced,'config/above-threshold-uses-enhanced'] call T420_AA_fnc_assert;
    missionNamespace setVariable ['QS_missionConfig_priorityAA_interval',['invalid']];
    missionNamespace setVariable ['QS_missionConfig_airDefense_reinforcementWeight','invalid'];
    [] call QS_fnc_airDefenseInit;
    [(missionNamespace getVariable 'QS_missionConfig_priorityAA_interval') isEqualTo [600,1800],'config/invalid-timer-falls-back'] call T420_AA_fnc_assert;
    [(missionNamespace getVariable 'QS_missionConfig_airDefense_reinforcementWeight') isEqualTo 2,'config/invalid-weight-falls-back'] call T420_AA_fnc_assert;
    private _publicationDeadline = diag_tickTime + 5;
    waitUntil {uiSleep 0.01; T420_AA_configPublications >= 2 || {diag_tickTime > _publicationDeadline}};
    [T420_AA_configPublications >= 2,'config/initial-publications-delivered-before-case-overrides',T420_AA_configPublications] call T420_AA_fnc_assert;
    {
        createMarker [_x # 0,_x # 1];
    } forEach [
        ['QS_marker_base_marker',[14500,16500,0]],['QS_marker_module_fob',[0,0,0]],
        ['QS_marker_sideMarker',[17000,18000,0]],['QS_marker_sideCircle',[17000,18000,0]]
    ];
    QS_AOpos = [22000,21000,0];
    QS_terrain_worldArea = [[15360,15360,0],15360,15360,0,TRUE];
    QS_core_vehicles_map = createHashMap;
    QS_core_units_map = createHashMap;
    QS_system_AI_owners = [2];
    QS_AI_vehicles = [];
    QS_garbageCollector = [];
    QS_hashmap_simpleObjectInfo = createHashMap;
    QS_hashmap_classLists = createHashMap;
    QS_priorityAA_abort = FALSE;
    QS_priorityAA_success = FALSE;
    {
        diag_log ('T420_AA_TEST_CASE_BEGIN|' + _x);
        call compile preprocessFileLineNumbers (_x + '.sqf');
        diag_log ('T420_AA_TEST_CASE_END|' + _x);
    } forEach T420_AA_cases;
    diag_log format ['T420_AA_TEST_SUMMARY|pass=%1|passes=%2|failures=%3|scriptErrors=%4',
        T420_AA_failures isEqualTo 0 && {T420_AA_errors isEqualTo []},T420_AA_passes,T420_AA_failures,count T420_AA_errors];
    diag_log 'T420_AA_TEST_DONE';
    endMission 'END1';
};
