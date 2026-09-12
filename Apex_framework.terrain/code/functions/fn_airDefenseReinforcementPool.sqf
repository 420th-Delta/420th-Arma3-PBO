/* Copy the ordinary pool so initial AO composition probabilities stay unchanged. */
params [['_case',0,[0]],['_playerCount',-1,[0]]];
private _pool = +([_case] call QS_fnc_getAIMotorPool);
if !([_playerCount] call QS_fnc_airDefenseUseEnhanced) exitWith {_pool};
private _weight = (missionNamespace getVariable ['QS_missionConfig_airDefense_reinforcementWeight',2]) max 0;
for '_index' from 0 to ((count _pool) - 2) step 2 do {
	if ((toLowerANSI (_pool # _index)) in ['o_apc_tracked_02_aa_f','o_t_apc_tracked_02_aa_ghex_f','i_lt_01_aa_f']) then {
		_pool set [_index + 1,(_pool # (_index + 1)) * _weight];
	};
};
_pool
