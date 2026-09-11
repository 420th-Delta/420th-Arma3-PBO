/* Rebuild from the ordinary pool so population/config changes never leave a stale AA entry. */
params [['_pool',[]],['_playerCount',-1]];
private _result = [];
for '_index' from 0 to ((count _pool) - 2) step 2 do {
	if !((toLower (_pool # _index)) in ['qs_fnc_smpriorityaa','qs_fnc_smpriorityaalegacy']) then {
		_result append [_pool # _index,_pool # (_index + 1)];
	};
};
if (
	!([_playerCount] call QS_fnc_airDefenseUseEnhanced) &&
	{missionNamespace getVariable ['QS_missionConfig_priorityAA_enabled',TRUE]} &&
	{!(missionNamespace getVariable ['QS_priorityAA_paused',FALSE])} &&
	{!(missionNamespace getVariable ['QS_priorityAA_active',FALSE])}
) then {
	_result append ['QS_fnc_SMpriorityAALegacy',0.4];
};
_result
