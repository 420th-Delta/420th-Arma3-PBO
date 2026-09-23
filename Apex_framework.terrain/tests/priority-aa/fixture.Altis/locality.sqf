/* Real server -> HC -> server ownership; only sensor-contact input is deterministic. */
if !(missionNamespace getVariable ['T420_AA_headlessExpected',FALSE]) exitWith {
	diag_log 'T420_AA_LOCALITY_SKIP|reason=Headless client was not requested';
};
private _readyDeadline = diag_tickTime + 60;
waitUntil {uiSleep 0.1; (missionNamespace getVariable ['T420_AA_headlessOwner',-1]) > 2 || {diag_tickTime > _readyDeadline}};
private _hcOwner = missionNamespace getVariable ['T420_AA_headlessOwner',-1];
[_hcOwner > 2,'locality/headless client ready',_hcOwner] call T420_AA_fnc_assert;
if (_hcOwner <= 2) exitWith {};
private _savedKeys = ['QS_fnc_airDefenseSelectTarget','QS_airDefense_vehicles','QS_missionConfig_airDefense_enabled','QS_missionConfig_airDefense_interval','QS_missionConfig_airDefense_baseExclusionRadius'];
private _saved = _savedKeys apply {[_x,!isNil {missionNamespace getVariable _x},missionNamespace getVariable [_x,[]]]};
private _hadController = !isNil 'QS_airDefense_controller';
private _scenarioDeadline = diag_tickTime + 30;
private _wait = {
	params ['_condition','_label',['_timeout',4]];
	private _deadline = (diag_tickTime + _timeout) min _scenarioDeadline;
	waitUntil {uiSleep 0.05; call _condition || {diag_tickTime > _deadline}};
	[call _condition,_label,call _snapshot] call T420_AA_fnc_assert;
};
private _site = [missionNamespace getVariable ['QS_AOpos',[22000,21000,0]],diag_tickTime + 10] call QS_fnc_priorityAAFindSite;
[_site isNotEqualTo [],'locality/fixture finds a dry clear vehicle site',_site] call T420_AA_fnc_assert;
if (_site isEqualTo []) exitWith {};
private _position = _site # 0;
private _vehicle = createVehicle ['O_APC_Tracked_02_AA_F',_position,[],0,'NONE'];
private _group = createVehicleCrew _vehicle;
private _crew = crew _vehicle;
_vehicle allowDamage FALSE;
_vehicle setFuel 0;
_group setBehaviourStrong 'CARELESS';
private _original = [];
{
	private _target = _forEachIndex isNotEqualTo 0;
	private _auto = _forEachIndex isNotEqualTo 1;
	_x enableAIFeature ['TARGET',_target];
	_x enableAIFeature ['AUTOTARGET',_auto];
	_x setUnitCombatMode 'GREEN';
	_x allowDamage FALSE;
	_original pushBack [_x,_target,_auto,'GREEN'];
} forEach _crew;
private _jet = createVehicle ['B_Plane_Fighter_01_F',_position vectorAdd [600,0,300],[],0,'FLY'];
private _jetGroup = createVehicleCrew _jet;
_jet allowDamage FALSE;
_jet enableSimulationGlobal FALSE;
{_x allowDamage FALSE} forEach crew _jet;
private _assets = [_vehicle,_group,_jet,_jetGroup] + _crew + crew _jet;
private _snapshot = {
	[
		['physical',getPosATL _vehicle,surfaceIsWater getPosATL _vehicle,alive _vehicle,damage _vehicle,_crew apply {alive _x}],
		['owners',owner _vehicle,groupOwner _group,local _vehicle],
		['serverController',if (isNil 'QS_airDefense_controller') then {'missing'} else {scriptDone QS_airDefense_controller}],
		['registered',_vehicle getVariable ['QS_airDefense_registered',FALSE],_vehicle in (missionNamespace getVariable ['QS_airDefense_vehicles',[]])],
		['crew',_crew apply {[_x,local _x,vehicle _x,_x checkAIFeature 'TARGET',_x checkAIFeature 'AUTOTARGET',unitCombatMode _x]}],
		['saved',_vehicle getVariable ['QS_airDefense_savedCrew',[]]],
		['control',_vehicle getVariable ['QS_airDefense_target',objNull],_vehicle getVariable ['QS_airDefense_holding',FALSE]],
		['hcHeartbeat',missionNamespace getVariable ['T420_AA_headlessHeartbeat',[]]],
		['hcReport',_vehicle getVariable ['T420_AA_localityReport',[]]]
	]
};
T420_AA_localityRealSelect = QS_fnc_airDefenseSelectTarget;
QS_fnc_airDefenseSelectTarget = {
	private _vehicle = _this # 0;
	if (_vehicle getVariable ['T420_AA_localityFixture',FALSE]) exitWith {
		[_vehicle,missionNamespace getVariable ['T420_AA_localityContacts',[]],TRUE] call T420_AA_localityRealSelect
	};
	_this call T420_AA_localityRealSelect
};
missionNamespace setVariable ['QS_missionConfig_airDefense_enabled',TRUE,TRUE];
missionNamespace setVariable ['QS_missionConfig_airDefense_interval',1,TRUE];
missionNamespace setVariable ['QS_missionConfig_airDefense_baseExclusionRadius',2000,TRUE];
missionNamespace setVariable ['T420_AA_localityDone',FALSE,TRUE];
missionNamespace setVariable ['T420_AA_localityVehicle',_vehicle,TRUE];
missionNamespace setVariable ['T420_AA_localityContacts',[[_jet,TRUE]],TRUE];
_vehicle setVariable ['T420_AA_localityFixture',TRUE,TRUE];
[_vehicle] call QS_fnc_airDefenseRegister;
[] call QS_fnc_airDefenseController;
[{(_vehicle getVariable ['QS_airDefense_target',objNull]) isEqualTo _jet && {count (_vehicle getVariable ['QS_airDefense_savedCrew',[]]) isEqualTo count _crew}},'locality/server controller acquires the jet and saves original crew state'] call _wait;
[(_vehicle getVariable ['QS_airDefense_savedCrew',[]]) isEqualTo _original,'locality/original mixed TARGET and AUTOTARGET flags are captured'] call T420_AA_fnc_assert;
private _transfer = _group setGroupOwner _hcOwner;
[_transfer,'locality/group transfer to HC accepted'] call T420_AA_fnc_assert;
[{groupOwner _group isEqualTo _hcOwner && {owner _vehicle isEqualTo _hcOwner}},'locality/vehicle and group actually move to HC'] call _wait;
[{
	private _report = _vehicle getVariable ['T420_AA_localityReport',[]];
	(count _report) >= 6 && {(_report # 0) isEqualTo _hcOwner} && {(_report # 4) isEqualTo _jet} &&
	{((_report # 2) findIf {!(_x # 1) || {_x # 3} || {(_x # 4) isNotEqualTo 'YELLOW'}}) isEqualTo -1}
},'locality/HC controller commands its local crew'] call _wait;
[(_vehicle getVariable ['QS_airDefense_savedCrew',[]]) isEqualTo _original,'locality/HC transfer preserves the original pre-controller snapshot'] call T420_AA_fnc_assert;
_jet setPosATL ((markerPos 'QS_marker_base_marker') vectorAdd [500,0,300]);
[{
	private _report = _vehicle getVariable ['T420_AA_localityReport',[]];
	(count _report) >= 6 && {(_report # 5)} &&
	{((_report # 2) findIf {!(_x # 1) || {_x # 2} || {_x # 3} || {(_x # 4) isNotEqualTo 'BLUE'}}) isEqualTo -1}
},'locality/HC enforces base hold with TARGET and AUTOTARGET disabled'] call _wait;
[_group setGroupOwner 2,'locality/group transfer back to server accepted'] call T420_AA_fnc_assert;
diag_log format ['T420_AA_LOCALITY_RELEASE_DURING_TRANSFER|%1',call _snapshot];
[_vehicle,FALSE] call QS_fnc_airDefenseRegister;
[{local _vehicle && {groupOwner _group isEqualTo 2} && {(_crew findIf {!local _x}) isEqualTo -1}},'locality/vehicle and crew actually return to server',10] call _wait;
[{
	((_original findIf {
		_x params ['_unit','_target','_auto','_combat'];
		(_unit checkAIFeature 'TARGET') isNotEqualTo _target || {(_unit checkAIFeature 'AUTOTARGET') isNotEqualTo _auto} || {unitCombatMode _unit isNotEqualTo _combat}
	}) isEqualTo -1) && {(_vehicle getVariable ['QS_airDefense_savedCrew',[]]) isEqualTo []}
},'locality/unregister during an in-flight transfer restores every original crew flag'] call _wait;
[isNull (_vehicle getVariable ['QS_airDefense_target',objNull]) && {!(_vehicle getVariable ['QS_airDefense_holding',FALSE])},'locality/unregister clears forced target and base hold'] call T420_AA_fnc_assert;

// A crew member leaving the vehicle must regain its own pre-controller state.
_jet setPosATL (_position vectorAdd [600,0,300]);
[_vehicle] call QS_fnc_airDefenseRegister;
[{(_vehicle getVariable ['QS_airDefense_target',objNull]) isEqualTo _jet},'locality/server controller can resume after restored ownership'] call _wait;
private _departed = gunner _vehicle;
private _departedState = _original # (_original findIf {(_x # 0) isEqualTo _departed});
moveOut _departed;
[{
	(vehicle _departed) isEqualTo _departed &&
	{(_departed checkAIFeature 'TARGET') isEqualTo (_departedState # 1)} &&
	{(_departed checkAIFeature 'AUTOTARGET') isEqualTo (_departedState # 2)} &&
	{unitCombatMode _departed isEqualTo (_departedState # 3)} &&
	{((_vehicle getVariable ['QS_airDefense_savedCrew',[]]) findIf {(_x # 0) isEqualTo _departed}) isEqualTo -1}
},'locality/departed crew regain their original controller settings'] call _wait;
[_vehicle,FALSE] call QS_fnc_airDefenseRegister;
[{(_vehicle getVariable ['QS_airDefense_savedCrew',[]]) isEqualTo []},'locality/remaining crew are released before cleanup'] call _wait;
[(missionNamespace getVariable ['T420_AA_headlessErrors',[]]) isEqualTo [],'locality/headless controller completed without script errors',missionNamespace getVariable ['T420_AA_headlessErrors',[]]] call T420_AA_fnc_assert;
missionNamespace setVariable ['T420_AA_localityDone',TRUE,TRUE];
missionNamespace setVariable ['T420_AA_localityVehicle',objNull,TRUE];
missionNamespace setVariable ['T420_AA_localityContacts',[],TRUE];
if (!_hadController) then {
	terminate QS_airDefense_controller;
	missionNamespace setVariable ['QS_airDefense_controller',nil];
};
{
	_x params ['_key','_present','_value'];
	missionNamespace setVariable [_key,if (_present) then {_value} else {nil},_key isNotEqualTo 'QS_fnc_airDefenseSelectTarget'];
} forEach _saved;
[_assets] call T420_AA_fnc_cleanup;
missionNamespace setVariable ['T420_AA_localityRealSelect',nil];
diag_log 'T420_AA_LOCALITY_LIMIT|Sensor contacts are injected; ownership transfer and owner-local controller restoration are real. No human remote-control takeover was simulated.';
