/* Fixed headless-client fixture: no arbitrary code or production RPC endpoints. */
if (isServer || {hasInterface}) exitWith {};
T420_AA_headlessErrors = [];
addMissionEventHandler ['ScriptError',{
	T420_AA_headlessErrors pushBack str _this;
	publicVariableServer 'T420_AA_headlessErrors';
	diag_log format ['T420_AA_HC_SCRIPT_ERROR|%1',_this];
}];
QS_hashmap_classLists = createHashMap;
QS_data_listVehicles = compile preprocessFileLineNumbers 'code\config\QS_data_listVehicles.sqf';
{
	missionNamespace setVariable ['QS_fnc_' + _x,compile preprocessFileLineNumbers ('code\functions\fn_' + _x + '.sqf')];
} forEach ['airDefenseController','airDefenseApply','airDefenseRelease','airDefenseFired','airDefenseSelectTarget','airDefenseClassifyTarget'];
T420_AA_localityRealSelect = QS_fnc_airDefenseSelectTarget;
QS_fnc_airDefenseSelectTarget = {
	private _vehicle = _this # 0;
	if (_vehicle getVariable ['T420_AA_localityFixture',FALSE]) exitWith {
		[_vehicle,missionNamespace getVariable ['T420_AA_localityContacts',[]],TRUE] call T420_AA_localityRealSelect
	};
	_this call T420_AA_localityRealSelect
};
[] call QS_fnc_airDefenseController;
T420_AA_headlessOwner = clientOwner;
publicVariableServer 'T420_AA_headlessOwner';
publicVariableServer 'T420_AA_headlessErrors';
diag_log format ['T420_AA_HC_READY|owner=%1',clientOwner];
[] spawn {
	while {!(missionNamespace getVariable ['T420_AA_localityDone',FALSE])} do {
		private _vehicle = missionNamespace getVariable ['T420_AA_localityVehicle',objNull];
		T420_AA_headlessHeartbeat = [clientOwner,diag_tickTime,_vehicle,local _vehicle,scriptDone QS_airDefense_controller];
		publicVariableServer 'T420_AA_headlessHeartbeat';
		if (!isNull _vehicle && {local _vehicle}) then {
			private _crewState = (crew _vehicle) apply {[_x,local _x,_x checkAIFeature 'TARGET',_x checkAIFeature 'AUTOTARGET',unitCombatMode _x]};
			_vehicle setVariable ['T420_AA_localityReport',[
				clientOwner,serverTime,_crewState,+(_vehicle getVariable ['QS_airDefense_savedCrew',[]]),
				_vehicle getVariable ['QS_airDefense_target',objNull],_vehicle getVariable ['QS_airDefense_holding',FALSE],
				_vehicle in (missionNamespace getVariable ['QS_airDefense_vehicles',[]]),_vehicle getVariable ['QS_airDefense_registered',FALSE],
				scriptDone QS_airDefense_controller,missionNamespace getVariable ['T420_AA_localityContacts',[]],
				markerPos 'QS_marker_base_marker',missionNamespace getVariable ['QS_missionConfig_airDefense_enabled',TRUE],
				[_vehicle] call QS_fnc_airDefenseSelectTarget,
				[alive _vehicle,damage _vehicle,getPosATL _vehicle,surfaceIsWater getPosATL _vehicle]
			],TRUE];
		};
		uiSleep 0.2;
	};
	QS_fnc_airDefenseSelectTarget = T420_AA_localityRealSelect;
	diag_log 'T420_AA_HC_LOCALITY_DONE';
};
