// Runs in the scope of the exact production HOUSEKEEPING_HELPERS block.
private _origin = [14500,16000,0];
private _arsenal = createVehicle ['Box_NATO_Ammo_F',_origin,[],0,'CAN_COLLIDE'];
missionNamespace setVariable ['QS_arsenals',[_arsenal]];
missionNamespace setVariable ['QS_spawnMenu_spawnedEntities',[]];
missionNamespace setVariable ['QS_logistics_deployedAssets',[]];
missionNamespace setVariable ['QS_cleanup_holderQueue',[]];
missionNamespace setVariable ['QS_analytics_entities_deleted',0];
_cleanupCrateScanAt = serverTime + 1e6;
_cleanupLoadAfter = diag_tickTime + 1e6;
private _holder = createVehicle ['GroundWeaponHolder',_origin vectorAdd [2,0,0],[],0,'CAN_COLLIDE'];
_holder addItemCargoGlobal ['FirstAidKit',1];
private _initialCargo = [_holder] call _fn_cleanupHolderCargo;
missionNamespace setVariable ['QS_cleanup_holderQueue',[[_holder,serverTime - 1,_initialCargo]]];
_holder addItemCargoGlobal ['FirstAidKit',1];
call _productionTick;
['cleanup.holder.lateAdditionSurvives',!isNull _holder] call IA_fnc_assert;
private _queue = missionNamespace getVariable ['QS_cleanup_holderQueue',[]];
['cleanup.holder.lateAdditionRenewsDeadline',count _queue isEqualTo 1 && {(_queue # 0 # 1) >= serverTime + 29},_queue] call IA_fnc_assert;
(_queue # 0) set [1,serverTime - 1];
private _deletedBefore = missionNamespace getVariable ['QS_analytics_entities_deleted',0];
call _productionTick;
['cleanup.holder.expiryRequestsDeletion',(missionNamespace getVariable ['QS_analytics_entities_deleted',0]) isEqualTo (_deletedBefore + 1) &&
    {(missionNamespace getVariable ['QS_cleanup_holderQueue',[]]) isEqualTo []}] call IA_fnc_assert;
private _deleteUntil = diag_tickTime + 1;
waitUntil {uiSleep 0.01; isNull _holder || {diag_tickTime >= _deleteUntil}};
['cleanup.holder.unchangedCargoExpires',isNull _holder,[diag_tickTime,_deletedBefore,
    missionNamespace getVariable ['QS_analytics_entities_deleted',0]]] call IA_fnc_assert;

private _transport = createVehicle ['C_Offroad_01_F',_origin vectorAdd [10,0,0],[],0,'CAN_COLLIDE'];
_holder = createVehicle ['GroundWeaponHolder',_origin,[],0,'CAN_COLLIDE'];
_holder addMagazineCargoGlobal ['30Rnd_65x39_caseless_mag',2];
_holder attachTo [_transport,[0,0,1]];
missionNamespace setVariable ['QS_cleanup_holderQueue',[[_holder,serverTime - 1,[_holder] call _fn_cleanupHolderCargo]]];
call _productionTick;
['cleanup.holder.attachedHolderSurvives',!isNull _holder] call IA_fnc_assert;
detach _holder;
deleteVehicle _holder;

['cleanup.budget.lowFpsShrinks',([100,17,2,-1] call _fn_cleanupBudget) isEqualTo [0,-1]] call IA_fnc_assert;
['cleanup.budget.recoveryWaits',([144,25,0,100] call _fn_cleanupBudget) isEqualTo [0,100]] call IA_fnc_assert;
['cleanup.budget.recoveryOneStep',([145,25,0,100] call _fn_cleanupBudget) isEqualTo [1,-1]] call IA_fnc_assert;
['cleanup.crate.absenceStarts',([100,-1,FALSE,FALSE] call _fn_cleanupAbsence) isEqualTo [100,FALSE]] call IA_fnc_assert;
['cleanup.crate.absenceFiveMinutes',([400,100,FALSE,FALSE] call _fn_cleanupAbsence) isEqualTo [100,TRUE]] call IA_fnc_assert;
['cleanup.crate.returnResets',([400,100,TRUE,FALSE] call _fn_cleanupAbsence) isEqualTo [-1,FALSE]] call IA_fnc_assert;
['cleanup.crate.inUseResets',([400,100,FALSE,TRUE] call _fn_cleanupAbsence) isEqualTo [-1,FALSE]] call IA_fnc_assert;
['cleanup.crate.flyoverIgnored',!([TRUE,TRUE,TRUE,FALSE] call _fn_cleanupGroundFact)] call IA_fnc_assert;
['cleanup.crate.landedAircraftProtects',[TRUE,TRUE,TRUE,TRUE] call _fn_cleanupGroundFact] call IA_fnc_assert;
['cleanup.crate.groundPlayerProtects',[TRUE,TRUE,FALSE,FALSE] call _fn_cleanupGroundFact] call IA_fnc_assert;

private _cover = createVehicle ['Land_HBarrier_1_F',_origin vectorAdd [20,0,0],[],0,'CAN_COLLIDE'];
private _playersClear = ((allPlayers select {!(_x isKindOf 'HeadlessClient_F')}) inAreaArray [_cover,150,150,0,FALSE]) isEqualTo [];
['cleanup.testArena.playersClear',_playersClear] call IA_fnc_assert;
_cover hideObjectGlobal TRUE;
missionNamespace setVariable ['IA_cleanup_generation',2];
private _retired = [_cover,['IA_cleanup_generation',1]] call _fn_cleanupRestoreTerrain;
['cleanup.kavala.staleRestoreRetires',_retired && {isObjectHidden _cover}] call IA_fnc_assert;
if (_playersClear) then {
    _retired = [_cover,['IA_cleanup_generation',2]] call _fn_cleanupRestoreTerrain;
    ['cleanup.kavala.currentRestoreUnhides',_retired && {!isObjectHidden _cover}] call IA_fnc_assert;
    ['cleanup.kavala.clearObjectEligible',[_cover] call _fn_cleanupKavalaSafe] call IA_fnc_assert;
};
_cover setVariable ['QS_cleanup_protected',TRUE];
['cleanup.kavala.lateProtectionBlocks',!([_cover] call _fn_cleanupKavalaSafe)] call IA_fnc_assert;
_cover setVariable ['QS_cleanup_protected',FALSE];
_cover attachTo [_transport,[0,0,2]];
['cleanup.kavala.lateAttachmentBlocks',!([_cover] call _fn_cleanupKavalaSafe)] call IA_fnc_assert;
detach _cover;
private _group = createGroup [WEST,TRUE];
private _captive = _group createUnit ['B_Soldier_F',_origin,[],0,'CAN_COLLIDE'];
_captive setCaptive TRUE;
_captive moveInDriver _transport;
['cleanup.kavala.captiveCrewBlocks',!([_transport] call _fn_cleanupKavalaSafe)] call IA_fnc_assert;
_transport deleteVehicleCrew _captive;
deleteGroup _group;
{deleteVehicle _x;} forEach [_transport,_cover,_arsenal];
removeMissionEventHandler ['EntityCreated',_cleanupHolderEH];
missionNamespace setVariable ['QS_cleanup_holderEH',-1];
['NOTE',['cleanup fixtures execute exact production helpers and tick; remote Put, real ground-player return and complete Kavala restart still require integrated client tests.']] call IA_fnc_log;
