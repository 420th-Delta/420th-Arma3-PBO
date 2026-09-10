private _slots = ['SLOTS',[14100,16200,0],2,0,'O_Soldier_F',TRUE,FALSE,-1,{TRUE}] call QS_fnc_spawnGroup;
['spawn_client_cannot_create_independent_claims',_slots isEqualTo [] && {missionNamespace getVariable ['QS_groundSpawn_claims',[]] isEqualTo []},[]] call IA_fnc_assert;
[] call IA_fnc_finish;
