// Narrow engine fixtures: layout, engine creation, native helicopter creation,
// ownership and teardown are production code. Loadout/UI/AI scheduler hooks are
// inert here; their integrated behavior is a separate mission acceptance pass.
{
	missionNamespace setVariable ['QS_fnc_' + _x,compile preprocessFileLineNumbers ('production\code\functions\fn_' + _x + '.sqf')];
} forEach ['spawnGroup','waterIntersect','findRandomPos','serverDetector','scSpawnHeli'];
QS_core_groups_map = createHashMapFromArray [
	['ia_fixture_sentry',[['O_Soldier_F','PRIVATE'],['O_Soldier_F','PRIVATE']]],
	['ia_fixture_squad',[]]
];
QS_core_groups_map set ['ia_fixture_squad',[]];
WEST setFriend [RESISTANCE,0];
RESISTANCE setFriend [WEST,0];
for '_index' from 1 to 12 do {(QS_core_groups_map get 'ia_fixture_squad') pushBack ['O_Soldier_F','PRIVATE'];};
QS_core_units_map = createHashMap;
QS_core_vehicles_map = createHashMap;
QS_core_unittraits_map = createHashMap;
QS_system_AI_owners = FALSE;
QS_fnc_unitSetup = {_this};
QS_fnc_perfBegin = {[]};
QS_fnc_perfEnd = {};
QS_fnc_vehicleLoadouts = {};
QS_fnc_serverSetAISkill = {};
QS_fnc_vKilled2 = {};
QS_fnc_AIXMissileCountermeasure = {};
QS_fnc_AIGroupEventEnemyDetected2 = {};
QS_fnc_serverSetEntityFeatureType = {};
QS_fnc_addWeapon = {};
QS_fnc_combatAir = {};
QS_AI_supportProviders_CASHELI = [];
QS_AI_supportProviders_INTEL = [];
QS_AI_vehicles = [];
QS_analytics_entities_deleted = 0;
QS_normalAO_deferredAIObjects = [];
QS_aoPos = [14100,16200,0];
QS_aoSize = 500;
if (isServer) then {call compile preprocessFileLineNumbers 'tests\ai-spawn-extracted\ai-pressure.sqf';};
