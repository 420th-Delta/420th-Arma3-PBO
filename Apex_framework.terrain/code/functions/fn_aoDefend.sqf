/*/
File: fn_aoDefend.sqf
Author:

	Quiksilver
	
Last modified:

	27/10/2022 A3 2.10 by Quiksilver

Version:

	01.10 testing draft

Draft revision:

	20/08/2026 Defense balance and spawn-pacing proposal
	Original I&A mission behavior retained except for the documented balance and pacing changes
	
Description:

	AO Defend
__________________________________________________/*/

scriptName 'QS AO Defend';
private [
	'_centerPos','_duration','_allArray','_infantryMaxSpawned','_infantryArray',
	'_infantryCheckDelay','_infantrySpawnDelay','_foundSpawnPos','_spawnPos',
	'_index','_grp','_side','_infTypes','_infType','_direction','_infantryInitialSpawnDelay',
	'_wp','_uavInitialSpawnDelay','_uavMaxSpawned','_uavArray','_uavCheckDelay','_uavSpawnDelay',
	'_uavTypes','_uavType','_uav','_uavFlyInHeight','_updateMoveDelay','_armorInitialSpawnDelay',
	'_armorMaxSpawned','_armorArray','_armorCheckDelay','_armorSpawnDelay','_armorTypes','_armorType',
	'_av','_destination','_groundTransportInitialSpawnDelay','_groundTransportMaxSpawned','_groundTransportArray',
	'_groundTransportCheckDelay','_groundTransportSpawnDelay','_groundTransportTypes','_groundTransportType',
	'_v','_unitTypes','_unitType','_grp2','_unloadPos','_checkHeldInitialDelay','_checkHeldDelay','_checkGroupDelay',
	'_QS_uavs','_QS_infantry','_QS_armor','_QS_groundTransport','_QS_flyBy','_startPos1','_startPos2','_endPos1',
	'_endPos2','_playersInArea','_QS_flyByDelay','_QS_airSuperiority','_jetsToSpawn','_jetType','_jetArray',
	'_jetInitialDelay','_jetSpawnDelay','_jetTrackedCount','_QS_flyByHeight','_updatePlayers','_playerVehicles','_unit','_helicopters','_helicoptersToSpawn',
	'_helicopterTypes','_helicopterType','_helicopterArray','_helicopterInitialDelay','_helicopter','_paratroopers',
	'_paratroopersToSpawn','_paratrooperTypes','_paratrooperArray','_paratrooperInitialDelay','_paratrooper','_paratrooperType',
	'_QS_flyByType','_QS_flyBySpeed','_QS_flyByAltitude','_allPlayersCount','_exitSuccess','_exitFail','_defendMessages',
	'_durationAlmostOver','_durationAlmostOverHint','_heli','_heliParaGrp','_heliParaCheckDelay','_paratroopers2','_paratrooper2InitialDelay',
	'_LorR','_vPara','_vParaTypes','_vParaType','_vParaV','_vParaInitialDelay','_vParaHeightMin','_vParaHeightRandom','_vParaDelay','_vParaArray',
	'_vParaToSpawn','_grp3','_openHeight','_QS_priorMissionStatistics','_currentStats','_defendStats','_vehicleReammoDelay','_groundTransportSpawned',
	'_divisor','_hqBuildings','_hqBuildingPositions','_building','_buildingPositions','_sectorControlTicker','_sectorControlThreshold','_text',
	'_enemyInHQCount','_playersInHQCount','_moveToPos','_infantrySpawnDistanceFixed','_infantrySpawnDistanceRandom','_infantrySpawnDistanceFromPlayer',
	'_fn_blacklist','_QS_worldName','_QS_worldSize','_nearRoads','_roadsValid','_validRoadSurfaces','_timeNow','_tickTimeNow','_serverTime','_taskID'
];
diag_log 'Defend AO 0';
/* Legacy Code as of 9.9.2026 */
//|if (time < 300) exitWith {};
// Updated Code
// MEGA_DEFENSE_ENTRY_BEGIN
private _megaDefense = missionNamespace getVariable ['QS_megaDefense_pending',FALSE];
if ((time < 300) && {!_megaDefense}) exitWith {};
private _defendForce = [missionNamespace getVariable 'QS_forceDefend',1] select _megaDefense;
// End Updated Code
_allPlayersCount = count allPlayers;
/* Legacy Code as of 9.9.2026 */
//|if ((diag_fps < 13) && ((missionNamespace getVariable 'QS_forceDefend') isEqualTo 0)) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
//|if (((count ((units WEST) inAreaArray [(missionNamespace getVariable 'QS_HQpos'),500,500,0,FALSE,-1])) < 4) && ((missionNamespace getVariable 'QS_forceDefend') isEqualTo 0)) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
//|if (((random 1) > 0.333) && ((missionNamespace getVariable 'QS_forceDefend') isEqualTo 0)) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
//|if ((missionNamespace getVariable 'QS_forceDefend') isEqualTo 2) then {};
//|if ((missionNamespace getVariable 'QS_forceDefend') isEqualTo 1) then {missionNamespace setVariable ['QS_forceDefend',0,TRUE];};
//|if ((missionNamespace getVariable 'QS_forceDefend') isEqualTo -1) exitWith {missionNamespace setVariable ['QS_forceDefend',0,TRUE];missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
//|if ((missionNamespace getVariable 'QS_forceDefend') isEqualTo -2) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
//|if ((_allPlayersCount > 60) && ((missionNamespace getVariable 'QS_defendCount') > 3) && ((missionNamespace getVariable 'QS_forceDefend') isEqualTo 0)) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
// Updated Code
if ((diag_fps < 13) && (_defendForce isEqualTo 0)) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
if (((count ((units WEST) inAreaArray [(missionNamespace getVariable 'QS_HQpos'),500,500,0,FALSE,-1])) < 4) && (_defendForce isEqualTo 0)) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
// More eligible AO completions lead into Defense; force controls and safety gates remain.
if (((random 1) > 0.666) && (_defendForce isEqualTo 0)) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
if (_defendForce isEqualTo 2) then {};
if ((_defendForce isEqualTo 1) && {!_megaDefense}) then {missionNamespace setVariable ['QS_forceDefend',0,TRUE];};
if (_defendForce isEqualTo -1) exitWith {missionNamespace setVariable ['QS_forceDefend',0,TRUE];missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
if (_defendForce isEqualTo -2) exitWith {missionNamespace setVariable ['QS_defendActive',FALSE,TRUE];};
if (_megaDefense) then {missionNamespace setVariable ['QS_megaDefense_pending',FALSE,FALSE];};
// MEGA_DEFENSE_ENTRY_END
// QS_defendCount remains a statistic, not a high-population lifetime cutoff.
// End Updated Code
diag_log 'Defend AO 0.5';
{
	missionNamespace setVariable _x;
} forEach [
	['QS_defendCount',((missionNamespace getVariable 'QS_defendCount') + 1),TRUE],
	['QS_defendActive',TRUE,TRUE],
	['QS_system_restartEnabled',FALSE,FALSE]
];
_defendMessages = [
	localize 'STR_QS_Chat_010',
	localize 'STR_QS_Chat_011',
	localize 'STR_QS_Chat_012'
];
['DEFEND_HQ',[localize 'STR_QS_Notif_003',localize 'STR_QS_Notif_004']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
{
	_x setMarkerAlphaLocal 0.75;
	_x setMarkerPos (missionNamespace getVariable 'QS_HQpos');
} forEach ['QS_marker_aoCircle','QS_marker_aoMarker'];
'QS_marker_aoMarker' setMarkerText format['%1 %3 %2 %4',(toString [32,32,32]),(missionNamespace getVariable 'QS_aoDisplayName'),localize 'STR_QS_Marker_002',localize 'STR_QS_Marker_003'];

if (worldName in ['Stratis']) then {
	missionNamespace setVariable ['QS_hqPos',missionNamespace getVariable 'QS_aoPos'];
};
_centerPos = missionNamespace getVariable 'QS_HQpos';
// Added Code
// WIND ONLY: reset calibration for this Defense. The helper is defined in the
// existing AI loop; an unavailable helper leaves the original drop positions.
if (!isNil 'QS_fnc_aoPressure') then {['DROP_RESET','DEFENSE'] call QS_fnc_aoPressure;};
// End Updated Code
_centerPos params ['_centerPosX','_centerPosY','_centerPosZ'];
private _allPlayers = allPlayers;
_taskID = 'QS_IA_TASK_DEFENDHQ';
[_taskID,TRUE,[localize 'STR_QS_Task_010',localize 'STR_QS_Task_011',localize 'STR_QS_Task_011'],_centerPos,'AUTOASSIGNED',5,FALSE,TRUE,'Defend',TRUE] call (missionNamespace getVariable 'BIS_fnc_setTask');
_timeNow = time;
_serverTime = serverTime;
_tickTimeNow = diag_tickTime;
_QS_worldName = worldName;
_QS_worldSize = worldSize;
/* Legacy Code as of 9.9.2026 */
//|_duration = serverTime + 900 + (random 450);
// Updated Code
// MEGA_DEFENSE_TIMER_BEGIN
private _defenseStartedAt = serverTime;
_duration = if (_megaDefense) then {_defenseStartedAt + 1800} else {_defenseStartedAt + 900 + (random 450)};
missionNamespace setVariable ['QS_megaDefense_state',['RUNNING',_defenseStartedAt,_duration,_megaDefense,FALSE],FALSE];
if (_megaDefense) then {
	private _megaDefenseText = 'HQ defense ordered. Hold this position for 30 minutes.';
	['sideChat',[WEST,'HQ'],_megaDefenseText] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
	['hint',_megaDefenseText] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
};
// MEGA_DEFENSE_TIMER_END
// End Updated Code
_durationAlmostOver = _duration - 60;
[_taskID,TRUE,_duration] call (missionNamespace getVariable 'QS_fnc_taskSetTimer');			//----- Task timer reduces suspense and tension, better to not know how long remaining? Uncomment to show timer UI
[_taskID,['Defend','Defend 1','Defend 2']] call (missionNamespace getVariable 'QS_fnc_taskSetCustomData');
[_taskID,TRUE,1] call (missionNamespace getVariable 'QS_fnc_taskSetProgress');
_durationAlmostOverHint = FALSE;
_exitSuccess = FALSE;
_exitFail = FALSE;
_checkHeldInitialDelay = time + 30;
_checkHeldDelay = time + 5;
_checkGroupDelay = time + 30;
_updatePlayers = time + 15;
_allArray = [];
_side = EAST;
_direction = 0;
_destination = [0,0,0];
_moveToPos = [0,0,0];
_validRoadSurfaces = ['#gdtreddirt','#gdtasphalt','#gdtsoil','#gdtconcrete'];
_grp2 = grpNull;
_updateMoveDelay = time + 30;
_hqFlag = missionNamespace getVariable ['QS_AO_HQ_flag',objNull];
[_hqFlag,WEST,'',FALSE,objNull,1] call (missionNamespace getVariable 'QS_fnc_setFlag');
if (_QS_worldName isEqualTo 'Tanoa') then {
	_fn_blacklist = {
		private _c = TRUE;
		{
			if ((_this distance2D (_x # 0)) < (_x # 1)) exitWith {
				_c = FALSE;
			};
		} count [
			[[13415.7,5194.57,0.00172806],350],
			[[12897.9,5442.16,0.00107098],175],
			[[2257.59,1664.31,0.00162601],90],
			[[3681.47,9377.08,0.00176811],400],
			[[11440.4,14422,0.0013628],275]
		];
		_c;
	};
} else {
	_fn_blacklist = {TRUE};
};
_QS_uavs = TRUE;
_uavInitialSpawnDelay = 0;
_uavMaxSpawned = 1;
if (_allPlayersCount > 0) then {_uavMaxSpawned = 1;};
if (_allPlayersCount > 10) then {_uavMaxSpawned = 1;};
if (_allPlayersCount > 20) then {_uavMaxSpawned = 2;};
if (_allPlayersCount > 30) then {_uavMaxSpawned = 2;};
if (_allPlayersCount > 40) then {_uavMaxSpawned = 3;};
if (_allPlayersCount > 50) then {_uavMaxSpawned = 4;};
_uavArray = [];
_uavCheckDelay = time + 5;
_uavSpawnDelay = time + 5;
_uavTypes = ['defend_uavtypes_1'] call QS_data_listVehicles;
_uavType = '';
_uav = objNull;
_uavFlyInHeight = 600 + (random 1400);
_QS_infantry = TRUE;
_infantryInitialSpawnDelay = time + 60;

private _infantryLimit_0 = 30;
private _infantryLimit_1 = 40;
private _infantryLimit_2 = 50;
private _infantryLimit_3 = 75;
private _infantryLimit_4 = 100;
private _infantryLimit_5 = 125;
private _infantryLimit_6 = 150;

if (_allPlayersCount > 0) then {_infantryMaxSpawned = _infantryLimit_0;};
if (_allPlayersCount > 10) then {_infantryMaxSpawned = _infantryLimit_1;};
if (_allPlayersCount > 20) then {_infantryMaxSpawned = _infantryLimit_2;};
if (_allPlayersCount > 30) then {_infantryMaxSpawned = _infantryLimit_3;};
if (_allPlayersCount > 40) then {_infantryMaxSpawned = _infantryLimit_4;};
if (_allPlayersCount > 50) then {_infantryMaxSpawned = _infantryLimit_5;};
if (_allPlayersCount > 60) then {_infantryMaxSpawned = _infantryLimit_6;};
_infantryArray = [];
_infantryCheckDelay = _tickTimeNow + 5;
_infantrySpawnDelay = time + 5;

_infantrySpawnDistanceFixed = 200; //legacy parameter retained; active spawn bands are defined in the infantry spawn block
_infantrySpawnDistanceRandom = 50; //legacy parameter retained; active outer band reaches 200m
_infantrySpawnDistanceFromPlayer = 30; //player exclusion bubble used by the infantry spawn block

if (worldName isEqualTo 'Tanoa') then {
	_infantrySpawnDistanceFixed = 200;
	_infantrySpawnDistanceRandom = 350;
	_infantrySpawnDistanceFromPlayer = 25;
};
if (worldName isEqualTo 'Stratis') then {
	_infantrySpawnDistanceFixed = 200;
	_infantrySpawnDistanceRandom = 350;
	_infantrySpawnDistanceFromPlayer = 25;
};
_infTypes = ['defend_grptypes_1'] call QS_data_listUnits;
if (worldName isEqualTo 'Stratis') then {
	_infTypes = ['defend_grptypes_2'] call QS_data_listUnits;
};
_infType = '';
_QS_armor = TRUE;
_armorInitialSpawnDelay = time + 10 + (random 30);
if (_allPlayersCount > 0) then {_armorMaxSpawned = 0;};
if (_allPlayersCount > 10) then {_armorMaxSpawned = 0;};
if (_allPlayersCount > 20) then {_armorMaxSpawned = 2;};
if (_allPlayersCount > 30) then {_armorMaxSpawned = 3;};
if (_allPlayersCount > 40) then {_armorMaxSpawned = 4;};
if (_allPlayersCount > 50) then {_armorMaxSpawned = 5;};
if (_allPlayersCount > 60) then {_armorMaxSpawned = 7;};
/*
if (_armorMaxSpawned < 2) then {
	if ((missionNamespace getVariable ['QS_AI_targetsKnowledge_threat_armor',0]) > 1) then {
		_armorMaxSpawned = _armorMaxSpawned max 2;
	};
};
*/
_armorArray = [];
_armorCheckDelay = time + 5;
_armorSpawnDelay = time + 5;
private _isArmedAirEnabled = missionNamespace getVariable ['QS_armedAirEnabled',TRUE];
private _motorPool = 0;
if (worldName in ['Stratis']) then {
	_motorPool = 8;
};
_armorType = '';
_QS_groundTransport = FALSE;
if ((random 1) > 0.033) then {_QS_groundTransport = TRUE;};
_groundTransportInitialSpawnDelay = time + 90 + (random 30);
if (_allPlayersCount > 0) then {_groundTransportMaxSpawned = 1;};
if (_allPlayersCount > 10) then {_groundTransportMaxSpawned = 2;};
if (_allPlayersCount > 20) then {_groundTransportMaxSpawned = 3;};
if (_allPlayersCount > 30) then {_groundTransportMaxSpawned = 4;};
if (_allPlayersCount > 40) then {_groundTransportMaxSpawned = 5;};
if (_allPlayersCount > 50) then {_groundTransportMaxSpawned = 5;};
_groundTransportSpawned = 0;
_groundTransportArray = [];
_groundTransportCheckDelay = time + 5;
_groundTransportSpawnDelay = time + 5;
_groundTransportTypes = ['defend_transporttypes_1'] call QS_data_listVehicles;
_groundTransportType = '';
_v = objNull;
_unitTypes = ['defend_unittypes_1'] call QS_data_listUnits;
_unitType = '';
_foundSpawnPos = FALSE;
_spawnPos = [0,0,0];
_index = 0;
_grp = grpNull;
_QS_airSuperiority = TRUE && (!(worldName in ['Stratis']));
if (_allPlayersCount > 0) then {_jetsToSpawn = 0;};
if (_allPlayersCount > 10) then {_jetsToSpawn = 0;};
if (_allPlayersCount > 20) then {_jetsToSpawn = 1;};
if (_allPlayersCount > 30) then {_jetsToSpawn = 1;};
if (_allPlayersCount > 40) then {_jetsToSpawn = 1;};
if (_allPlayersCount > 50) then {_jetsToSpawn = 2;};
if (_allPlayersCount > 60) then {_jetsToSpawn = 2;};
_jetType = selectRandomWeighted (['defend_jettypes_1'] call QS_data_listVehicles);
_jetArray = [];
_jetInitialDelay = time + (120 + (random 180));
_jetSpawnDelay = 0;
_jet = objNull;
_helicopters = TRUE;
_helicoptersToSpawn = 1;
if (_allPlayersCount > 0) then {_helicoptersToSpawn = 1;};
if (_allPlayersCount > 10) then {_helicoptersToSpawn = 1;};
if (_allPlayersCount > 20) then {_helicoptersToSpawn = 2;};
if (_allPlayersCount > 30) then {_helicoptersToSpawn = 2;};
if (_allPlayersCount > 40) then {_helicoptersToSpawn = 3;};
if (_allPlayersCount > 50) then {_helicoptersToSpawn = 3;};
if (_allPlayersCount > 60) then {_helicoptersToSpawn = 4;};
if (_allPlayersCount > 20) then {
	if (worldName in ['Tanoa','Enoch','Stratis']) then {
		_helicopterTypes = ['defend_helitypes_1'] call QS_data_listVehicles;
	} else {
		_helicopterTypes = ['defend_helitypes_2'] call QS_data_listVehicles;
	};
} else {
	_helicopterTypes = ['defend_helitypes_3'] call QS_data_listVehicles;
};
_helicopterType = '';
_helicopterArray = [];
_heliParaGrp = grpNull;
_helicopterInitialDelay = _groundTransportInitialSpawnDelay;
_helicopter = objNull;
_heliParaCheckDelay = time + 3;
if ((random 1) > 0.033) then {
	_paratroopers = TRUE;
} else {
	_paratroopers = FALSE;
};
if ((random 1) > 0.666) then {
	_paratroopers2 = TRUE;
} else {
	_paratroopers2 = FALSE;
};
if (!(_paratroopers)) then {
	_infantryMaxSpawned = round (_infantryMaxSpawned * 1.25);
	if (!(_paratroopers2)) then {
		_infantryMaxSpawned = round (_infantryMaxSpawned * 1.25);
	};
};
if (_allPlayersCount > 0) then {_paratroopersToSpawn = 0;};
if (_allPlayersCount > 10) then {_paratroopersToSpawn = 0;};
if (_allPlayersCount > 20) then {_paratroopersToSpawn = 5;};
if (_allPlayersCount > 30) then {_paratroopersToSpawn = 10;};
if (_allPlayersCount > 40) then {_paratroopersToSpawn = 15;};
if (_allPlayersCount > 50) then {_paratroopersToSpawn = 20;};
_paratrooperTypes = ['defend_paratypes_1'] call QS_data_listUnits;
_paratrooperType = '';
_paratrooperArray = [];
_paratrooperInitialDelay = time + 10 + (random 60);
_paratrooper2InitialDelay = _paratrooperInitialDelay + 30 + (random 120);
_paratrooper = objNull;
_vPara = FALSE;
if ((random 1) > 0.006) then {
	_vPara = TRUE;
};
_vParaTypes = ['defend_paravtypes_1'] call QS_data_listVehicles;
_vParaType = '';
_vParaV = objNull;
_vParaInitialDelay = _paratrooper2InitialDelay + 10 + (random 20);
_vParaHeightMin = 100;
_vParaHeightRandom = 150;
_vParaDelay = time + 4;
_vParaArray = [];
_vParaToSpawn = 0;
if (_allPlayersCount > 0) then {_vParaToSpawn = 0;};
if (_allPlayersCount > 10) then {_vParaToSpawn = 2;};
if (_allPlayersCount > 20) then {_vParaToSpawn = 2;};
if (_allPlayersCount > 30) then {_vParaToSpawn = 3;};
if (_allPlayersCount > 40) then {_vParaToSpawn = 4;};
if (_allPlayersCount > 50) then {_vParaToSpawn = 6;};
if (_allPlayersCount > 60) then {_vParaToSpawn = 8;};
_QS_flyBy = FALSE;
if ((random 1) > 0.033) then {
	_QS_flyBy = TRUE;
};
_QS_flyByDelay = _jetInitialDelay - 10;
_QS_flyByHeight = 25 + (random 100);
_QS_flyByType = selectRandomWeighted (['defend_flybytypes_1'] call QS_data_listVehicles);
_QS_flyBySpeed = 'FULL';
_QS_flyByAltitude = 50 + (random 150);
if ((random 1) > 0.666) then {
	_startPos1 = [worldSize,(_centerPos # 1),100];
	_startPos2 = [worldSize,((_centerPos # 1) + 50),100];
	_endPos1 = [0,(_centerPos # 1),100];
	_endPos2 = [0,((_centerPos # 1) + 50),100];
} else {
	_startPos1 = [0,(_centerPos # 1),100];
	_startPos2 = [0,((_centerPos # 1) + 50),100];
	_endPos1 = [worldSize,(_centerPos # 1),100];
	_endPos2 = [worldSize,((_centerPos # 1) + 50),100];
};
missionNamespace setVariable ['QS_defend_terminate',FALSE,FALSE];
sleep 2;
if (_allPlayersCount > 20) then {
	if ((random 1) > 0.366) then {
		if (isClass (missionConfigFile >> 'CfgSounds' >> 'Bells')) then {
			['playSound','Bells'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
		};
	};
};
_vehicleReammoDelay = time + 30;
//comment 'Get all HQ building positions so units know where to go';
_hqBuildingPositions = [];
_hqBuildings = nearestObjects [_centerPos,['House','Building'],50,TRUE];
private _hqBuildingPosition = [0,0,0];
{
	_building = _x;
	_buildingPositions = _building buildingPos -1;
	_buildingPositions = [_building,_buildingPositions] call (missionNamespace getVariable 'QS_fnc_customBuildingPositions');
	if (_buildingPositions isNotEqualTo []) then {
		{
			_hqBuildingPosition = _x;
			0 = _hqBuildingPositions pushBack _hqBuildingPosition;
		} forEach _buildingPositions;
	};
} forEach _hqBuildings;
if (_hqBuildingPositions isNotEqualTo []) then {
	_hqBuildingPositions = _hqBuildingPositions apply {[(_x # 0),(_x # 1),((_x # 2) + 1)]};
};
_sectorControlTicker = 0;
_sectorControlThreshold = 7;
_enemyInHQCount = 0;
_playersInHQCount = 0;
_defendMessage = selectRandom _defendMessages;
['sideChat',[WEST,'HQ'],_defendMessage] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
_QS_priorMissionStatistics = [0,0];
private _priorDefendStats = [];
if (!isNil {missionProfileNamespace getVariable 'QS_defendHQ_statistics'}) then {
	_QS_priorMissionStatistics = missionProfileNamespace getVariable 'QS_defendHQ_statistics';
	if ((count _QS_priorMissionStatistics) > 100) then {
		_QS_priorMissionStatistics set [0,FALSE];
		_QS_priorMissionStatistics deleteAt 0;
		missionProfileNamespace setVariable ['QS_defendHQ_statistics',_QS_priorMissionStatistics];
		saveMissionProfileNamespace;
	};
} else {
	missionProfileNamespace setVariable ['QS_defendHQ_statistics',_QS_priorMissionStatistics];
	saveMissionProfileNamespace;
};
if (isNil {missionProfileNamespace getVariable 'QS_defend_stat_2'}) then {
	missionProfileNamespace setVariable ['QS_defend_stat_2',[]];
	saveMissionProfileNamespace;
} else {
	_priorDefendStats = missionProfileNamespace getVariable 'QS_defend_stat_2';
	if ((count _priorDefendStats) > 100) then {
		_priorDefendStats set [0,FALSE];
		_priorDefendStats deleteAt 0;
		missionProfileNamespace setVariable ['QS_defend_stat_2',_QS_priorMissionStatistics];
		saveMissionProfileNamespace;
	};
};
_currentStats = [_allPlayersCount,(count (allPlayers inAreaArray [(missionNamespace getVariable 'QS_hqPos'),300,300,0,FALSE])),0,0,_exitSuccess];
private _unitGroup = grpNull;
private _groupLeader = objNull;
missionNamespace setVariable ['QS_defend_blockTimeout',FALSE,FALSE]; //missionNamespace setVariable ['QS_defend_blockTimeout',((random 1) > 0.95),FALSE];
private _extended = FALSE;
private _blockMessageShown = FALSE;
private _blockMessage = localize 'STR_QS_Chat_015';
missionNamespace setVariable ['QS_AI_targetsKnowledge_suspend',TRUE,FALSE];
//comment 'Functions preload';
_fn_serverDetector = missionNamespace getVariable 'QS_fnc_serverDetector';
_fn_findSafePos = missionNamespace getVariable 'QS_fnc_findSafePos';
_fn_waterIntersect = missionNamespace getVariable 'QS_fnc_waterIntersect';
_fn_findOverwatchPos = missionNamespace getVariable 'QS_fnc_findOverwatchPos';
_fn_setAISkill = missionNamespace getVariable 'QS_fnc_serverSetAISkill';
_fn_taskAttack = missionNamespace getVariable 'QS_fnc_taskAttack';
_fn_vehicleLoadouts = missionNamespace getVariable 'QS_fnc_vehicleLoadouts';
_fn_spawnGroup = missionNamespace getVariable 'QS_fnc_spawnGroup';
_fn_downgradeVehicleWeapons = missionNamespace getVariable 'QS_fnc_downgradeVehicleWeapons';
_fn_unitSetup = missionNamespace getVariable 'QS_fnc_unitSetup';
_fn_taskSetProgress = missionNamespace getVariable 'QS_fnc_taskSetProgress';
_fn_setFlag = missionNamespace getVariable 'QS_fnc_setFlag';
_fn_getAIMotorPool = missionNamespace getVariable 'QS_fnc_getAIMotorPool';

// Added Code
// DEFENSE_FLANK_CONTROLLER_BEGIN
// Borrow existing assault infantry for known, persistent positions outside HQ.
// This runs in the existing Defense loop. Spawn counts, waves and timer are unchanged.
private _defendEpoch = 1 + (missionNamespace getVariable ['QS_defendControl_epoch',0]);
missionNamespace setVariable ['QS_defendControl_epoch',_defendEpoch,TRUE];
missionNamespace setVariable ['QS_defendControl_active',TRUE,TRUE];
missionNamespace setVariable ['QS_defendControl_groundCount',0,TRUE];
// DEFENSE_COVER_MOVE_BEGIN
private _fn_coverMove = {
	params ['_group','_goal'];
	if (serverTime < (_group getVariable ['QS_AI_coverUntil',0])) then {
		{if (serverTime >= (_x getVariable ['QS_AI_coverUntil',0])) then {_x doMove _goal;};} forEach (units _group);
	} else {_group move _goal;};
};
// DEFENSE_COVER_MOVE_END
private _flankNext = serverTime + 15;
private _flankCamps = [];
private _flankJobs = [];
// DEFENSE_FLANK_POLICIES_BEGIN
private _fn_flankQuota = {
	params ['_groups','_players'];
	if (_groups < 4 || {_players < 10}) exitWith {0};
	2 min (1 max (round (_groups * 0.05))) min (_groups - 3)
};
private _fn_flankBand = {
	params ['_hqDistance','_baseDistance','_sideDistance','_speed'];
	_hqDistance >= 400 && {_hqDistance <= 2000} && {_baseDistance > 1000} &&
		{_sideDistance > 600} && {abs _speed <= 15}
};
private _fn_flankLive = {
	params ['_now','_ends','_lastSeen','_valid','_sameActivity'];
	_valid && {_sameActivity} && {_now < _ends} && {(_now - _lastSeen) <= 90}
};
// DEFENSE_FLANK_POLICIES_END
private _fn_flankRelease = {
	params ['_job'];
	_job params ['_group','','','','','','','','_restore'];
	if (isNull _group) exitWith {};
	_group setVariable ['QS_defendFlank_epoch',-1,TRUE];
	_group setVariable ['QS_defendFlank_cooldown',serverTime + 120,FALSE];
	_restore params ['_hcExcluded','_attack','_combat','_regroup'];
	if (local _group && {((units _group) findIf {isPlayer _x || {captive _x} || {!isNull (remoteControlled _x)} || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}) < 0}) then {
		_group enableAttack _attack;
		_group setCombatMode _combat;
		{if (alive _x && {isNull (objectParent _x)}) then {_x doFollow (leader _group);};} forEach (units _group);
		_group move _centerPos;
	};
	{(_x # 0) setVariable ['QS_AI_UNIT_regroup_disable',_x # 1,TRUE];} forEach _regroup;
	_group setVariable ['QS_AI_GRP_HC_EXCLUDED',_hcExcluded,TRUE];
};
private _fn_flankReport = {
	params ['_target'];
	private _report = [];
	// Shared reports are already bounded by the native intelligence service.
	{
		if ((vehicle (_x # 0)) isEqualTo _target && {(_x # 1) <= serverTime + 1} &&
			{serverTime - (_x # 1) <= 60} && {(_x # 3) >= 1.5} &&
			{(WEST getFriend (side (_x # 4))) < 0.6}) exitWith {
			_report = [+(_x # 2),_x # 1];
		};
	} forEach (missionNamespace getVariable ['QS_AI_targetsIntel',[]]);
	if (_report isEqualTo []) then {
		// Own Defense observers can supply a last-seen position before a shared
		// report exists. Never substitute the player's current coordinates.
		{
			private _known = _x targetKnowledge _target;
			if ((_known param [0,FALSE]) && {(_x knowsAbout _target) >= 1.5} &&
				{(_known # 2) > 0} && {time - (_known # 2) <= 60} && {(_known # 5) <= 100}) exitWith {
				_report = [ASLToAGL (_known # 6),serverTime - (0 max (time - (_known # 2)))];
			};
		} forEach _flankObservers;
	};
	if (_report isNotEqualTo [] && {(_report # 0) isEqualTo [0,0,0] || {surfaceIsWater (_report # 0)}}) then {_report = [];};
	_report
};
// SOLO_SUPPORT_STALKING_BEGIN
// Eligibility only: these current positions never become pursuit destinations.
// Count every living human, including incapacitated players and vehicle crews.
private _fn_stalkPlayers = {
	_this select {isPlayer _x && {alive _x} && {!(_x isKindOf 'HeadlessClient_F')}}
};
private _fn_stalkTargetAllowed = {
	params ['_target'];
	(_target call QS_fnc_groundTargetPriority) >= 0
};
// SOLO_SUPPORT_STALKING_END
private _fn_flankTick = {
	private _now = serverTime;
	private _ground = _allPlayers select {
		alive _x && {!captive _x} && {lifeState _x in ['HEALTHY','INJURED']} &&
		{side (group _x) isEqualTo WEST} && {!((vehicle _x) isKindOf 'Air')} &&
		{(_x distance2D _centerPos) <= 2500}
	};
	// Reuse this 15-second census for the owner-local covering-fire handlers.
	if ((missionNamespace getVariable ['QS_defendControl_groundCount',-1]) isNotEqualTo count _ground) then {
		missionNamespace setVariable ['QS_defendControl_groundCount',count _ground,TRUE];
	};
	private _stalkPlayers = _allPlayers call _fn_stalkPlayers;
	private _targets = [];
	// Human turnout still selects the quota. Only fresh observed WEST assets
	// extend the target roster to AI/autonomous crews. No vehicle-world scan.
	private _assets = [];
	{
		_x params ['_target','_seen','','_knowledge','_observer','_groundAsset'];
		private _priority = _target call QS_fnc_groundTargetPriority;
		if (_groundAsset && {_priority >= 0} && {_priority < 4} && {_knowledge >= 1.5} &&
			{_seen <= _now + 1} && {_now - _seen <= 60} && {!isNull _observer} &&
			{(WEST getFriend (side _observer)) < 0.6}) then {
			_assets pushBack [_priority,_forEachIndex,vehicle _target];
		};
	} forEach (missionNamespace getVariable ['QS_AI_targetsIntel',[]]);
	_assets sort TRUE;
	private _candidates = _ground apply {vehicle _x};
	{_candidates pushBackUnique (_x # 2);} forEach (_assets select [0,64]);
	private _base = markerPos 'QS_marker_base_marker';
	private _sidePos = markerPos 'QS_marker_sideMarker';
	{
		private _target = _x;
		if ([_target,_stalkPlayers] call _fn_stalkTargetAllowed &&
			{[_target distance2D _centerPos,_target distance2D _base,_target distance2D _sidePos,speed _target] call _fn_flankBand}) then {
			_targets pushBackUnique _target;
		};
	} forEach _candidates;
	// Live ordinary assault groups only. Crew, parachutists and other activities
	// are not drawn into this roster. Whole squads are borrowed, never assembled.
	private _groups = [];
	{if (alive _x) then {_groups pushBackUnique (group _x);};} forEach _infantryArray;
	_groups = _groups select {!isNull _x && {alive (leader _x)}};
	private _quota = [count _groups,count _ground] call _fn_flankQuota;
	private _flankObservers = [];
	{
		if (_x isKindOf 'CAManBase' && {local _x} && {alive _x} && {_x isEqualTo leader (group _x)}) then {
			_flankObservers pushBackUnique _x;
		};
	} forEach _allArray;
	_flankObservers resize ((count _flankObservers) min 32);
	private _keep = [];
	{
		private _job = _x;
		_job params ['_group','_target','_anchor','_point','_lastSeen','_ends','_bearing','_nextMove','_restore'];
		private _valid = !isNull _group && {local _group} && {alive (leader _group)} &&
			{_target in _targets} && {(_target distance2D _anchor) <= 75} &&
			{((leader _group) distance2D _centerPos) <= 2200} &&
			{((units _group) findIf {alive _x && {isPlayer _x || {captive _x} || {!isNull (remoteControlled _x)} || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])} || {!isNull (objectParent _x)}}}) < 0};
		private _fresh = [];
		if (_valid) then {_fresh = [_target] call _fn_flankReport;};
		if (_fresh isNotEqualTo []) then {_point = _fresh # 0; _lastSeen = _fresh # 1;};
		if ([ _now,_ends,_lastSeen,_valid,
			missionNamespace getVariable ['QS_defendControl_active',FALSE] &&
			{(missionNamespace getVariable ['QS_defendControl_epoch',-1]) isEqualTo _defendEpoch}
		] call _fn_flankLive && {count _keep < _quota}) then {
			if (_now >= _nextMove && {diag_fps >= 18}) then {
				private _leader = leader _group;
				private _mounted = !(_target isKindOf 'CAManBase');
				private _standOff = [130,300] select _mounted;
				private _goal = _point getPos [_standOff,_bearing];
				private _step = (getPosATL _leader) getPos [180 min (_leader distance2D _goal),_leader getDir _goal];
				if (!surfaceIsWater _step && {(_step distance2D _centerPos) <= 2200} &&
					{(_step distance2D _base) > 1000} && {(_step distance2D _sidePos) > 600} &&
					{!([getPosATL _leader,_step,25] call _fn_waterIntersect)}) then {
					[_group,_step] call _fn_coverMove;
					_group setFormDir (_leader getDir _point);
				};
				_nextMove = _now + 15;
			};
			_keep pushBack [_group,_target,_anchor,_point,_lastSeen,_ends,_bearing,_nextMove,_restore];
		} else {[_job] call _fn_flankRelease;};
	} forEach _flankJobs;
	_flankJobs = _keep;
	private _camps = [];
	{
		private _target = _x;
		private _index = _flankCamps findIf {(_x # 0) isEqualTo _target};
		private _camp = [_target,getPosATL _target,_now];
		if (_index >= 0 && {(_target distance2D ((_flankCamps # _index) # 1)) <= 75}) then {_camp = _flankCamps # _index;};
		_camps pushBack _camp;
	} forEach _targets;
	_flankCamps = _camps;
	if (diag_fps < 18 || {_quota <= 0} ||
		{(missionNamespace getVariable ['QS_defend_propulsion',2]) isEqualTo 5}) exitWith {};
	private _ready = _flankCamps select {_now - (_x # 2) >= 45 && {private _target = _x # 0; (_flankJobs findIf {(_x # 1) isEqualTo _target}) < 0}};
	// Highest observed asset tier first; retain the established camp dwell,
	// range, whole-squad and AT requirements. Infantry remains last.
	private _rankedCamps = [];
	{_rankedCamps pushBack [(_x # 0) call QS_fnc_groundTargetPriority,_forEachIndex,_x];} forEach _ready;
	_ready = _rankedCamps;
	_ready sort TRUE;
	_ready resize ((count _ready) min 8);
	private _sent = FALSE;
	{
		private _camp = _x # 2;
		_camp params ['_target','_anchor'];
		private _report = [_target] call _fn_flankReport;
		if (_report isNotEqualTo []) then {
			private _choices = [];
			{
				private _group = _x;
				private _men = (units _group) select {alive _x};
				private _replace = _flankJobs findIf {(_x # 0) isEqualTo _group &&
					{((_x # 1) call QS_fnc_groundTargetPriority) > (_target call QS_fnc_groundTargetPriority)}};
				if ((count _flankJobs < _quota || {_replace >= 0}) && {local _group} && {count _men >= 8} && {count _men <= 12} &&
					{((_group getVariable ['QS_AI_GRP_HC',[0,-1]]) # 0) in [0,4]} &&
					{scriptDone (_group getVariable ['QS_AI_GRP_SCRIPT',scriptNull])} &&
					{_now >= (_group getVariable ['QS_defendFlank_cooldown',0])} &&
					{(_group getVariable ['QS_defendFlank_epoch',-1]) isNotEqualTo _defendEpoch || {_replace >= 0}} &&
					{((leader _group) distance2D _centerPos) > 250} &&
					{((leader _group) distance2D (_report # 0)) <= 1800} &&
					{(_men findIf {isPlayer _x || {captive _x} || {!isNull (remoteControlled _x)} || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])} || {!local _x} || {!isNull (objectParent _x)} ||
						{lifeState _x isEqualTo 'INCAPACITATED'} || {!scriptDone (_x getVariable ['QS_AI_UNIT_script',scriptNull])}}) < 0}) then {
					private _cache = _group getVariable ['QS_defendFlank_ATCache',[0,FALSE]];
					if (_now >= (_cache # 0)) then {
					private _hasAT = (_men findIf {
						secondaryWeapon _x isNotEqualTo '' && {((magazines _x) findIf {
							private _ammo = configFile >> 'CfgAmmo' >> getText (configFile >> 'CfgMagazines' >> _x >> 'ammo');
							toLowerANSI (getText (_ammo >> 'simulation')) in ['shotmissile','shotrocket'] && {getNumber (_ammo >> 'airLock') < 2}
						}) >= 0}
					}) >= 0;
					_cache = [_now + 60,_hasAT];
					_group setVariable ['QS_defendFlank_ATCache',_cache,FALSE];
					};
					private _needsAT = !(_target isKindOf 'CAManBase');
					// No rifle-only squad is sent to surround an armored position.
					if (!_needsAT || {_cache # 1}) then {_choices pushBack [(leader _group) distance2D (_report # 0),_group,_replace];};
				};
			} forEach _groups;
			if (_choices isNotEqualTo []) then {
				_choices sort TRUE;
				private _group = (_choices # 0) # 1;
				private _replace = (_choices # 0) # 2;
				// Replace only after the higher-tier camp passed dwell, real sighting
				// and usable-squad/AT checks. The borrowed squad count cannot grow.
				if (_replace >= 0) then {[_flankJobs deleteAt _replace] call _fn_flankRelease;};
				private _regroup = (units _group) apply {[_x,_x getVariable ['QS_AI_UNIT_regroup_disable',FALSE]]};
				private _restore = [_group getVariable ['QS_AI_GRP_HC_EXCLUDED',FALSE],attackEnabled _group,combatMode _group,_regroup];
				_group setVariable ['QS_defendFlank_epoch',_defendEpoch,TRUE];
				_group setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
				_group enableAttack TRUE;
				{
					_x setVariable ['QS_AI_UNIT_regroup_disable',TRUE,TRUE];
					_x enableAIFeature ['TARGET',TRUE]; _x enableAIFeature ['AUTOTARGET',TRUE];
					_x doFollow (leader _group);
				} forEach (units _group);
				private _bearing = ((_report # 0) getDir (leader _group)) + selectRandom [-60,60];
				_flankJobs pushBack [_group,_target,+_anchor,_report # 0,_report # 1,_now + 300,_bearing,0,_restore];
				diag_log format ['[Defense] FLANK assigned squad=%1 target=%2 range=%3',count (units _group),typeOf _target,round (_target distance2D _centerPos)];
				_sent = TRUE;
			};
		};
		if (_sent) exitWith {};
	} forEach _ready;
};
// DEFENSE_FLANK_CONTROLLER_END

// DEFENSE_TARU_STATE_BEGIN
private _taruFlights = [];
private _taruNext = 0;
private _taruSince = 0;
private _taruBand = -1;
// DEFENSE_TARU_STATE_END
// End Updated Code
diag_log 'Defend AO 1';
for '_x' from 0 to 1 step 0 do {
	_timeNow = time;
	_tickTimeNow = diag_tickTime;
	_serverTime = serverTime;
// Added Code
	// MEGA_DEFENSE_CONVERT_BEGIN
	isNil {
		if (missionNamespace getVariable ['QS_megaDefense_pending',FALSE]) then {
			missionNamespace setVariable ['QS_megaDefense_pending',FALSE,FALSE];
			if ((!_megaDefense) && {_serverTime < _duration} && {!(missionNamespace getVariable ['QS_defend_terminate',FALSE])}) then {
				_megaDefense = TRUE;
				_duration = _duration max (_serverTime + 1800);
				_durationAlmostOver = _duration - 60;
				_durationAlmostOverHint = _durationAlmostOverHint && {_serverTime >= _durationAlmostOver};
				[_taskID,TRUE,_duration] call (missionNamespace getVariable 'QS_fnc_taskSetTimer');
				missionNamespace setVariable ['QS_megaDefense_state',['RUNNING',_defenseStartedAt,_duration,TRUE,_extended],FALSE];
				private _megaDefenseText = 'Defense extended. Hold HQ for another 30 minutes.';
				['sideChat',[WEST,'HQ'],_megaDefenseText] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
				['hint',_megaDefenseText] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
				diag_log '[Mega Defense] Active Defense extended to at least 30 minutes remaining.';
			} else {
				diag_log '[Mega Defense] Request expired or Defense is ending; request cleared.';
			};
		};
	};
	// MEGA_DEFENSE_CONVERT_END
// End Updated Code
	_allPlayers = allPlayers;
	_allPlayersCount = count _allPlayers;
	_allArray = _allArray select {(alive _x)};
// Added Code
	// A 15-second bounded pass borrows at most one whole squad at a time.
	if (serverTime >= _flankNext) then {call _fn_flankTick; _flankNext = serverTime + 15;};
// End Updated Code
	if ((missionNamespace getVariable ['QS_enemyUAVSpawningEnabled',FALSE]) && {_timeNow > _uavInitialSpawnDelay}) then {
		if (_timeNow > _uavCheckDelay) then {
			// Maintained live cap follows the current player count.
			_uavMaxSpawned = 1;
			if (_allPlayersCount > 20) then {_uavMaxSpawned = 2;};
			if (_allPlayersCount > 40) then {_uavMaxSpawned = 3;};
			if (_allPlayersCount > 50) then {_uavMaxSpawned = 4;};
			_uavArray = _uavArray select {(alive _x) && {canMove _x}};
			if (_timeNow > _uavSpawnDelay) then {
				if ((count _uavArray) < _uavMaxSpawned) then {
					_foundSpawnPos = FALSE;
					for '_x' from 0 to 49 step 1 do {
						_spawnPos = _centerPos getPos [(2000 + (random 2000)),(random 360)];
						if ((_allPlayers inAreaArray [_spawnPos,1000,1000,0,FALSE]) isEqualTo []) then {
							_foundSpawnPos = TRUE;
						};
						if (_foundSpawnPos) exitWith {};
					};
					_uavType = selectRandom _uavTypes;
					private _perfSpawn = ['aoDefend.createVehicle',1] call QS_fnc_perfBegin;
					_uav = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _uavType,_uavType],_spawnPos,[],0,'FLY'];
					[_perfSpawn,([0,1] select (!isNull _uav)),[typeOf _uav,netId _uav]] call QS_fnc_perfEnd;
					private _perfCrew = ['aoDefend.createVehicleCrew',1,[typeOf _uav,netId _uav]] call QS_fnc_perfBegin;
					_grp = createVehicleCrew _uav;
					[_perfCrew,count (crew _uav)] call QS_fnc_perfEnd;
					if (_allPlayersCount >= 15) then {
						[_uav,1,[]] call _fn_vehicleLoadouts;
					} else {
						{ 
							_uav removeWeaponGlobal (getText (configFile >> 'CfgMagazines' >> _x >> 'pylonWeapon'));
						} forEach (getPylonMagazines _uav);
					};
					clearMagazineCargoGlobal _uav;
					clearWeaponCargoGlobal _uav;
					clearItemCargoGlobal _uav;
					clearBackpackCargoGlobal _uav;
					_uav setVariable ['QS_uav_protected',TRUE,FALSE];
					[_uav,2] remoteExecCall ['QS_fnc_serverSetEntityFeatureType',2,FALSE];
					0 = _uavArray pushBack _uav;
					0 = _allArray pushBack _uav;
					{
						0 = _allArray pushBack _x;
					} count (crew _uav);
					_uav setPos [((getPosWorld _uav) # 0),((getPosWorld _uav) # 1),_uavFlyInHeight];
					_direction = _spawnPos getDir _centerPos;
					_uav setDir _direction;
					_uav enableRopeAttach FALSE;
					_uav enableVehicleCargo FALSE;
					[(units _grp),0] call _fn_setAISkill;
					_wp = _grp addWaypoint [_centerPos,0];
					_wp setWaypointType 'LOITER';
					_wp setWaypointSpeed 'NORMAL';
					_wp setWaypointBehaviour 'CARELESS';
					_wp setWaypointCombatMode 'WHITE';
					_wp setWaypointLoiterType 'CIRCLE';
					_wp setWaypointLoiterRadius (800 + (random 300));
					_uav setVehicleReportRemoteTargets TRUE;
					_uav setVehicleReceiveRemoteTargets TRUE;
					_uav setVehicleRadar 1;
					_uav flyInHeight _uavFlyInHeight;
					_uav flyInHeightASL [_uavFlyInHeight,_uavFlyInHeight,_uavFlyInHeight];
					_grp setFormDir _direction;
					(gunner _uav) doWatch _centerPos;
					_uavSpawnDelay = time + 60 + (random 30);
				};
			};
			_uavCheckDelay = time + 5;
		};
	};
	if ((_timeNow > _infantryInitialSpawnDelay) && {(_tickTimeNow > _infantryCheckDelay)}) then {
		if (_allPlayersCount > 0) then {_infantryMaxSpawned = _infantryLimit_0;};
		if (_allPlayersCount > 10) then {_infantryMaxSpawned = _infantryLimit_1;};
		if (_allPlayersCount > 20) then {_infantryMaxSpawned = _infantryLimit_2;};
		if (_allPlayersCount > 30) then {_infantryMaxSpawned = _infantryLimit_3;};
		if (_allPlayersCount > 40) then {_infantryMaxSpawned = _infantryLimit_4;};
		if (_allPlayersCount > 50) then {_infantryMaxSpawned = _infantryLimit_5;};
		if (_allPlayersCount > 60) then {_infantryMaxSpawned = _infantryLimit_6;};
		if (_extended) then {
			_infantryMaxSpawned = round (_infantryMaxSpawned * 1.25);
		};
		_infantryArray = _infantryArray select {(alive _x)};
		if ((count _infantryArray) < _infantryMaxSpawned) then {
			_index = 0;
// Added Code
			// DEFENSE_INFANTRY_POSITION_BEGIN
			private _foundInfantrySpawn = FALSE;
			private _fn_infantryPosition = {
				params ['_candidatePoint'];
				(_candidatePoint isNotEqualTo []) &&
				{(_allPlayers inAreaArray [_candidatePoint,_infantrySpawnDistanceFromPlayer,_infantrySpawnDistanceFromPlayer,0,FALSE]) isEqualTo []} &&
				{(_candidatePoint distance2D _centerPos) < 1001} &&
				{_candidatePoint call _fn_blacklist} &&
				{!([_candidatePoint,_centerPos,25] call _fn_waterIntersect)}
			};
// End Updated Code
			for '_x' from 0 to 49 step 1 do {
				_spawnPos = [_centerPos,_infantrySpawnDistanceFixed,_infantrySpawnDistanceFixed + _infantrySpawnDistanceRandom,5,0,0.5,0] call _fn_findSafePos;
/* Legacy Code as of 9.9.2026 */
//|				if (
//|					(_spawnPos isNotEqualTo []) &&
//|					{((_allPlayers inAreaArray [_spawnPos,_infantrySpawnDistanceFromPlayer,_infantrySpawnDistanceFromPlayer,0,FALSE]) isEqualTo [])} &&
//|					{((_spawnPos distance2D _centerPos) < 1001)} &&
//|					{(_spawnPos call _fn_blacklist)} &&
//|					{(!([_spawnPos,_centerPos,25] call _fn_waterIntersect))}
//|				) exitWith {};
// Updated Code
				if ([_spawnPos] call _fn_infantryPosition) exitWith {_foundInfantrySpawn = TRUE;};
// End Updated Code
			};
// Added Code
			// DEFENSE_INFANTRY_POSITION_END
// End Updated Code
			_infType = selectRandomWeighted _infTypes;
/* Legacy Code as of 9.9.2026 */
//|			_direction = _spawnPos getDir _centerPos;
//|			_grp = [_spawnPos,_direction,EAST,_infType,FALSE,grpNull,TRUE,TRUE] call _fn_spawnGroup;
// Updated Code
			// DEFENSE_TARU_ADMIT_BEGIN
			call {
			// Exhausted center searches and incomplete ground layouts retry on
			// the normal Defense cadence; never create a partial or unsafe squad.
			if (!_foundInfantrySpawn) exitWith {};
			private _size = count (QS_core_groups_map getOrDefault [toLowerANSI _infType,[]]);
			private _room = _infantryMaxSpawned - count _infantryArray;
			if (_size <= 0 || {_size > _room}) exitWith {};
			private _connected = {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}} count allPlayers;
			private _band = [0,1] select (_connected >= 20);
			if (_band isNotEqualTo _taruBand) then {_taruSince = 0; _taruBand = _band;};
			_taruFlights = _taruFlights select {!scriptDone (_x # 1)};
			private _cap = [3,1] select (_connected >= 20);
			private _ready = diag_fps >= 18 && {_room >= _size + 1} && {_tickTimeNow >= _taruNext} && {count _taruFlights < _cap};
			if (_connected > 0 && {_connected < 20} && {_room >= _size + 1} && {diag_fps >= 18} && {!_ready}) exitWith {};
			private _lift = ['TARU_POLICY',_connected,_taruSince,_size,_ready,random 1] call QS_fnc_AIXHeliInsert;
			private _flight = [];
			private _drop = +_spawnPos;
			private _entry = [];
			if (_lift) then {
				// Search before spawning: the same admitted group begins aboard.
				// No visible ground squad is teleported into an aircraft.
				for '_attempt' from 1 to 18 do {
					private _candidate = _centerPos getPos [700 + random 300,random 360];
					_candidate set [2,200];
					if ((_candidate # 0) > 50 && {(_candidate # 1) > 50} &&
						{(_candidate # 0) < worldSize - 50} && {(_candidate # 1) < worldSize - 50} &&
						{(_candidate distance2D (markerPos 'QS_marker_base_marker')) > 1200} &&
						{(_allPlayers inAreaArray [_candidate,400,400,0,FALSE]) isEqualTo []} &&
						{(_taruFlights findIf {((_x # 0) distance2D _candidate) < 150}) < 0}) exitWith {_entry = _candidate;};
				};
				if (_entry isNotEqualTo [] && {!surfaceIsWater _drop} &&
					{(_allPlayers inAreaArray [_drop,50,50,0,FALSE]) isEqualTo []}) then {
					_flight = ['TARU_CREATE',_entry,_size] call QS_fnc_AIXHeliInsert;
				};
			};
			_lift = _flight isNotEqualTo [];
			private _spawn = [_spawnPos,_entry] select _lift;
			_direction = _spawn getDir _centerPos;
			_grp = [[_spawn,[-1015,-1015,0]] select _lift,_direction,EAST,_infType,FALSE,grpNull,!_lift,TRUE,_fn_infantryPosition,_infantrySpawnDistanceFromPlayer] call _fn_spawnGroup;
			if (_lift) then {
				private _heli = _flight # 0; private _pilots = _flight # 1;
				if (isNull _grp || {count (units _grp) isNotEqualTo _size}) then {
					{deleteVehicle _x;} forEach (units _grp);
					deleteVehicleCrew _heli; deleteVehicle _heli; deleteGroup _pilots;
					_lift = FALSE;
				} else {
					_grp setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
					_grp setVariable ['QS_taruDelivery_busy',TRUE,TRUE];
					{_x moveInCargo _heli;} forEach (units _grp);
					if (((units _grp) findIf {(objectParent _x) isNotEqualTo _heli}) >= 0) exitWith {
						{if ((objectParent _x) isEqualTo _heli) then {_heli deleteVehicleCrew _x;} else {deleteVehicle _x;};} forEach (units _grp);
						deleteVehicleCrew _heli; deleteVehicle _heli; deleteGroup _pilots;
						_lift = FALSE;
					};
					_allArray append [_heli,driver _heli];
					// Pilot is inside the existing Defense infantry allowance too.
					_infantryArray pushBack (driver _heli);
					private _exit = _centerPos getPos [2200,_centerPos getDir _entry];
					_taruFlights pushBack [_heli,['TARU_DELIVER',_heli,_grp,_drop,_exit,_centerPos,'DEFENSE',_defendEpoch] spawn QS_fnc_AIXHeliInsert];
					_taruNext = _tickTimeNow + ([45,240] select (_connected >= 20));
				};
			};
			if (isNull _grp || {units _grp isEqualTo []}) exitWith {};
			if (_band isEqualTo 1) then {_taruSince = [_taruSince + count (units _grp),0] select _lift;};
			// DEFENSE_TARU_ADMIT_END
// End Updated Code
			{
				0 = _infantryArray pushBack _x;
				0 = _allArray pushBack _x;
				_x enableStamina FALSE;
				_x enableFatigue FALSE;
				_x setDir _direction;
				//_x enableAIFeature ['AUTOCOMBAT',FALSE];
				_x enableAIFeature ['COVER',FALSE];
				_x enableAIFeature ['SUPPRESSION',FALSE];
			} forEach (units _grp);
			if (((random 1) > 0.8) || {(_extended)}) then {
				{
					_x setAnimSpeedCoef 1.1;
				} forEach (units _grp);
			};
			_grp enableAttack FALSE;
			_grp setCombatMode 'YELLOW';
			_grp setBehaviour 'AWARE';
			_grp setSpeedMode 'FULL';
			if ((random 1) > 0.5) then {
				{
					_x addEventHandler [
						'FiredNear',
						{
							{
								_x removeAllEventHandlers 'FiredNear';
								_x removeAllEventHandlers 'Hit';
								_x enableAIFeature ['TARGET',TRUE];
								_x enableAIFeature ['AUTOTARGET',TRUE];
							} forEach (units (group (_this # 0)));
						}
					];
					_x addEventHandler [
						'Hit',
						{
							{
								_x removeAllEventHandlers 'FiredNear';
								_x removeAllEventHandlers 'Hit';
								_x enableAIFeature ['TARGET',TRUE];
								_x enableAIFeature ['AUTOTARGET',TRUE];
							} forEach (units (group (_this # 0)));
						}
					];
					_x enableAIFeature ['TARGET',FALSE];
					_x enableAIFeature ['AUTOTARGET',FALSE];
				} forEach (units _grp);
			} else {
				{
					_x addEventHandler [
						'Hit',
						{
							(_this # 0) removeEventHandler [_thisEvent,_thisEventHandler];
							(_this # 0) enableAIFeature ['TARGET',TRUE];
							(_this # 0) enableAIFeature ['AUTOTARGET',TRUE];
						}
					];
					_x enableAIFeature ['TARGET',FALSE];
					_x enableAIFeature ['AUTOTARGET',FALSE];
				} forEach (units _grp);
			};
			[(units _grp),([1,2] select ((random 1) > 0.8))] call _fn_setAISkill;
			if ((missionNamespace getVariable ['QS_defend_propulsion',1]) isEqualTo 5) then {
				_wp = _grp addWaypoint [[_centerPosX,_centerPosY,1],5];
				_wp setWaypointType 'MOVE';
				_wp setWaypointSpeed 'FULL';
				_wp setWaypointBehaviour 'AWARE';
				_wp setWaypointCombatMode 'YELLOW';
				_grp setBehaviour 'AWARE';
				_wp setWaypointForceBehaviour TRUE;
				_wp setWaypointCompletionRadius 5;
				_grp setCurrentWaypoint _wp;
				_grp lockWP TRUE;
			} else {
				_grp move _centerPos;
			};
// Added Code
			}; // DEFENSE_TARU_ADMIT_SCOPE_END
// End Updated Code
		};
		// Recheck every 6-10 seconds. Close spawn bands keep pressure high while
		// reducing group creation, AI initialization, and network bursts.
		_infantryCheckDelay = _tickTimeNow + 6 + (random 4);
	};
	if (_timeNow > _armorInitialSpawnDelay) then {
		if (_timeNow > _armorCheckDelay) then {
			if (_allPlayersCount > 0) then {_armorMaxSpawned = 0;};
			if (_allPlayersCount > 10) then {_armorMaxSpawned = 0;};
			if (_allPlayersCount > 20) then {_armorMaxSpawned = 2;};
			if (_allPlayersCount > 30) then {_armorMaxSpawned = 3;};
			if (_allPlayersCount > 40) then {_armorMaxSpawned = 4;};
			if (_allPlayersCount > 50) then {_armorMaxSpawned = 5;};
			if (_allPlayersCount > 60) then {_armorMaxSpawned = 7;};
			/*
				Legacy threat-based minimum disabled in v01.10 so the advertised
				player-tier combat-vehicle cap remains authoritative.
				if (_armorMaxSpawned < 2) then {
					if ((missionNamespace getVariable ['QS_AI_targetsKnowledge_threat_armor',0]) > 1) then {
						_armorMaxSpawned = 2;
					};
				};
			*/
			{
				if (!canMove _x) then {
					_x setDamage [1,TRUE];
				};
			} forEach _armorArray;
			_armorArray = _armorArray select {(alive _x)};
			if ((count _armorArray) < _armorMaxSpawned) then {
				_foundSpawnPos = FALSE;
				_roadsValid = [];
				_nearRoads = [];
				for '_x' from 0 to 49 step 1 do {
					_spawnPos = [_centerPos,600,1000,10,0,0.5,0] call _fn_findSafePos;
					
					if (
						(_spawnPos isNotEqualTo []) &&
						{((_allPlayers inAreaArray [_spawnPos,400,400,0,FALSE]) isEqualTo [])} &&
						{((_spawnPos distance2D _centerPos) < 1201)} &&
						{(_spawnPos call _fn_blacklist)} &&
						{(!([_spawnPos,_centerPos,25] call _fn_waterIntersect))}
					) then {
						_nearRoads = ((_spawnPos select [0,2]) nearRoads 150) select {((_x isEqualType objNull) && ((roadsConnectedTo _x) isNotEqualTo []))};
						if (_nearRoads isNotEqualTo []) then {
							{
								if ((toLowerANSI (surfaceType (getPosATL _x))) in _validRoadSurfaces) then {
									0 = _roadsValid pushBack (getPosATL _x);
								};
							} count _nearRoads;
							if (_roadsValid isNotEqualTo []) then {
								_foundSpawnPos = TRUE;
								_spawnPos = selectRandom _roadsValid;
							};
						};
					};
					if (_foundSpawnPos) exitWith {};
				};
// Added Code
				// GROUND_VEHICLE_PLACEMENT_BEGIN
				call {
// End Updated Code
				_armorType = selectRandomWeighted ([_motorPool] call _fn_getAIMotorPool);
// Added Code
				if (!_foundSpawnPos) exitWith {};
				private _slots = ['VEHICLE_SLOTS',_spawnPos,1,0,QS_core_vehicles_map getOrDefault [toLowerANSI _armorType,_armorType],TRUE,FALSE,400,{
					params ['_point'];
					(_point distance2D _centerPos) < 1201 && {_point call _fn_blacklist} && {!([_point,_centerPos,25] call _fn_waterIntersect)}
				}] call QS_fnc_spawnGroup;
				if (_slots isEqualTo []) exitWith {};
				_spawnPos = _slots # 0;
				if (!(_spawnPos call _fn_blacklist) || {[_spawnPos,_centerPos,25] call _fn_waterIntersect}) exitWith {};
// End Updated Code
				private _perfSpawn = ['aoDefend.createVehicle',1] call QS_fnc_perfBegin;
				_av = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _armorType,_armorType],_spawnPos,[],0,'NONE'];
				[_perfSpawn,([0,1] select (!isNull _av)),[typeOf _av,netId _av]] call QS_fnc_perfEnd;
				_av setVariable ['QS_dynSim_ignore',TRUE,FALSE];
				_av enableDynamicSimulation FALSE;
				0 = _armorArray pushBack _av;
				0 = _allArray pushBack _av;
				(missionNamespace getVariable 'QS_AI_vehicles') pushBack _av;
				clearMagazineCargoGlobal _av;
				clearWeaponCargoGlobal _av;
				clearItemCargoGlobal _av;
				clearBackpackCargoGlobal _av;
				_av setConvoySeparation 50;
				[_av] call _fn_downgradeVehicleWeapons;
				_av allowDamage FALSE;
				_av allowCrewInImmobile [TRUE,TRUE];
				[0,_av,EAST,1] call (missionNamespace getVariable 'QS_fnc_vSetup2');
				_av lock 2;
				_direction = _spawnPos getDir _centerPos;
				_av setDir _direction;
				private _perfCrew = ['aoDefend.createVehicleCrew',1,[typeOf _av,netId _av]] call QS_fnc_perfBegin;
				_grp = createVehicleCrew _av;
				[_perfCrew,count (crew _av)] call QS_fnc_perfEnd;
				if (!((side _grp) in [EAST,RESISTANCE])) then {
					_grp = createGroup [EAST,TRUE];
					(crew _av) joinSilent _grp;
				};
				_destination = [_centerPos,(200 + (random 200)),(50 + (random 50)),10] call _fn_findOverwatchPos;
				_grp move _destination;
				_grp addVehicle _av;
				{
					doStop _x;
					_x doMove _destination;
					_x addEventHandler [
						'Killed',
						{
							params ['_killed'];
							_vehicle = vehicle _killed;
							if (((crew _vehicle) findIf {(alive _x)}) isEqualTo -1) then {
								_vehicle setDamage [1,TRUE];
							};
						}
					];
				} forEach (units _grp);
				_av enableRopeAttach FALSE;
				_av enableVehicleCargo FALSE;
				_av addEventHandler [
					'GetOut',
					{
						params ['_vehicle','','',''];
						if (((crew _vehicle) findIf {(alive _x)}) isEqualTo -1) then {
							_vehicle setDamage [1,TRUE];
						};
					}
				];
				[(units _grp),([1,2] select ((random 1) > 0.85))] call _fn_setAISkill;
				_grp setCombatMode 'RED';
				_grp setBehaviour 'AWARE';
				{
					0 = _allArray pushBack _x;
				} count (units _grp);
				if (!isNull (gunner _av)) then {
					(gunner _av) doWatch _centerPos;
				};
				if (!isNull (commander _av)) then {
					(commander _av) doWatch _centerPos;
				};
				_av allowDamage TRUE;
// Added Code
				};
				// GROUND_VEHICLE_PLACEMENT_END
// End Updated Code
			};
			_armorCheckDelay = time + 15;
		};
	};
	
	
	//QS_core_vehicles_map getOrDefault [toLowerANSI _armorType,_armorType]
	
	if (_timeNow > _groundTransportInitialSpawnDelay) then {
		if (_timeNow > _groundTransportCheckDelay) then {
			if (_timeNow > _groundTransportSpawnDelay) then {
				if (_groundTransportSpawned < _groundTransportMaxSpawned) then {
					if (({(alive _x)} count _groundTransportArray) < _groundTransportMaxSpawned) then {
						_foundSpawnPos = FALSE;
						_roadsValid = [];
						_nearRoads = [];
						for '_x' from 0 to 49 step 1 do {
							_spawnPos = [_centerPos,600,1000,10,0,0.5,0] call _fn_findSafePos;
							if (
								(_spawnPos isNotEqualTo []) &&
								{((_allPlayers inAreaArray [_spawnPos,400,400,0,FALSE]) isEqualTo [])} &&
								{((_spawnPos distance2D _centerPos) < 1201)} &&
								{(_spawnPos call _fn_blacklist)} &&
								{(!([_spawnPos,_centerPos,25] call _fn_waterIntersect))}
							) then {
								_nearRoads = ((_spawnPos select [0,2]) nearRoads 150) select {((_x isEqualType objNull) && ((roadsConnectedTo _x) isNotEqualTo []))};
								if (_nearRoads isNotEqualTo []) then {
									{
										if ((toLowerANSI (surfaceType (getPosATL _x))) in _validRoadSurfaces) then {
											0 = _roadsValid pushBack (getPosATL _x);
										};
									} count _nearRoads;
									if (_roadsValid isNotEqualTo []) then {
										_foundSpawnPos = TRUE;
										_spawnPos = selectRandom _roadsValid;
									};
								};
							};
							if (_foundSpawnPos) exitWith {};
						};
// Added Code
						// GROUND_VEHICLE_PLACEMENT_BEGIN
						call {
// End Updated Code
						_groundTransportType = selectRandom _groundTransportTypes;
// Added Code
						if (!_foundSpawnPos) exitWith {};
						private _slots = ['VEHICLE_SLOTS',_spawnPos,1,0,QS_core_vehicles_map getOrDefault [toLowerANSI _groundTransportType,_groundTransportType],TRUE,FALSE,400,{
							params ['_point'];
							(_point distance2D _centerPos) < 1201 && {_point call _fn_blacklist} && {!([_point,_centerPos,25] call _fn_waterIntersect)}
						}] call QS_fnc_spawnGroup;
						if (_slots isEqualTo []) exitWith {};
						_spawnPos = _slots # 0;
						if (!(_spawnPos call _fn_blacklist) || {[_spawnPos,_centerPos,25] call _fn_waterIntersect}) exitWith {};
// End Updated Code
						private _perfSpawn = ['aoDefend.createVehicle',1] call QS_fnc_perfBegin;
						_v = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _groundTransportType,_groundTransportType],_spawnPos,[],0,'NONE'];
						[_perfSpawn,([0,1] select (!isNull _v)),[typeOf _v,netId _v]] call QS_fnc_perfEnd;
						_v setVariable ['QS_dynSim_ignore',TRUE,FALSE];
						_v enableDynamicSimulation FALSE;
						0 = _groundTransportArray pushBack _v;
						0 = _allArray pushBack _v;
						(missionNamespace getVariable 'QS_AI_vehicles') pushBack _v;
						_v allowDamage FALSE;
						_v allowCrewInImmobile [FALSe,FALSE];
						_v setUnloadInCombat [FALSE,FALSE];
						/*/_v forceFollowRoad TRUE;/*/
						_v setConvoySeparation 50;
						_v lock 3;
						_v enableRopeAttach FALSE;
						_v enableVehicleCargo FALSE;
						clearMagazineCargoGlobal _v;
						clearWeaponCargoGlobal _v;
						clearItemCargoGlobal _v;
						clearBackpackCargoGlobal _v;
						_direction = _spawnPos getDir _centerPos;
						_v setDir _direction;
						private _perfCrew = ['aoDefend.createVehicleCrew',1,[typeOf _v,netId _v]] call QS_fnc_perfBegin;
						_grp = createVehicleCrew _v;
						[_perfCrew,count (crew _v)] call QS_fnc_perfEnd;
						[(units _grp),3] call _fn_setAISkill;
						_v allowDamage TRUE;
						_v addEventHandler [
							'HandleDamage',
							{
								params ['_vehicle','_selection','_damage','_source','_ammo','',''];
								if (((crew _vehicle) findIf {(alive _x)}) isEqualTo -1) then {_vehicle removeEventHandler [_thisEvent,_thisEventHandler];};
								if (_selection isNotEqualTo '?') then {
									_oldDamage = if (_selection isEqualTo '') then [{(damage _vehicle)},{(_vehicle getHit _selection)}];
									if (!isNull _source) then {
										_scale = 0.25;
										_oldDamage = if (_selection isEqualTo '') then [{(damage _vehicle)},{(_vehicle getHit _selection)}];
										_damage = ((_damage - _oldDamage) * _scale) + _oldDamage;
									} else {
										if (_ammo isEqualTo '') then {
											_scale = 0.25;
											if (['wheel',_selection,FALSE] call (missionNamespace getVariable 'QS_fnc_inString')) then {
												_scale = 0.05;
											};
											_damage = ((_damage - _oldDamage) * _scale) + _oldDamage;
										};
									};
								};
							}
						];
						_v addEventHandler ['Killed',{(_this # 0) removeAllEventHandlers 'HandleDamage';}];
						_v addEventHandler [
							'GetOut',
							{
								params ['_vehicle','_position','_unit','_turret'];
								if (_unit isEqualTo (leader (group _unit))) then {
									(group _unit) move ((group _unit) getVariable ['QS_grp_movepos',(missionNamespace getVariable 'QS_hqPos')]);
								};
							}
						];
						_grp setVariable ['QS_IA_spawnPos',_spawnPos,TRUE];
						{
							_x call _fn_unitSetup;
							0 = _allArray pushBack _x;
							_x enableStamina FALSE;
							_x enableFatigue FALSE;
							_x allowFleeing 0;
						} count (units _grp);
						_grp2 = createGroup [_side,TRUE];
						_divisor = 1;
						if ((_v emptyPositions 'Cargo') > 6) then {
							_divisor = 2;
						};
						for '_x' from 0 to (round(((_v emptyPositions 'Cargo') - 1) / _divisor)) step 1 do {
							_unitType = selectRandom _unitTypes;
							private _perfSpawn = ['aoDefend.createUnit',1] call QS_fnc_perfBegin;
							_unit = _grp2 createUnit [QS_core_units_map getOrDefault [toLowerANSI _unitType,_unitType],[0,0,0],[],0,'NONE'];
							[_perfSpawn,([0,1] select (!isNull _unit)),[typeOf _unit,netId _unit]] call QS_fnc_perfEnd;
							sleep 0.1;
							_unit = _unit call _fn_unitSetup;
							_unit moveInAny _v;
						};
						{
							0 = _allArray pushBack _x;
							_x enableStamina FALSE;
							_x enableFatigue FALSE;
							//_x enableAIFeature ['AUTOCOMBAT',FALSE];
							_x enableAIFeature ['COVER',FALSE];
						} count (units _grp2);
						_unloadPos = [_centerPos,30,75,10,0,0.5,0] call _fn_findSafePos;
						_wp = _grp addWaypoint [_unloadPos,15];
						_wp setWaypointType 'TR UNLOAD';
						_wp setWaypointSpeed 'FULL';
						_wp setWaypointBehaviour 'CARELESS';
						_wp setWaypointCombatMode 'BLUE';
						_wp setWaypointCompletionRadius (50 + (random 100));
						_wp setWaypointStatements [
							'TRUE',
							'
								if (local this) then {
									(group this) setBehaviour "CARELESS";
									_v = vehicle this;
									{
										if (_x isNotEqualTo this) then {
											_x action ["getOut",(vehicle this)];
											_x leaveVehicle _v;
										};
									} count (crew _v);
									_wp = (group this) addWaypoint [((group this) getVariable "QS_IA_spawnPos"),0];
									_wp setWaypointType "MOVE";
									_wp setWaypointSpeed "FULL";
									_wp setWaypointBehaviour "CARELESS";
									_wp setWaypointCombatMode "BLUE";
								};
							'
						];
						_grp2 setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
						_grp2 setVariable ['QS_grp_movepos',_centerPos,FALSE];
						[(units _grp2),1] call _fn_setAISkill;
						_groundTransportSpawned = _groundTransportSpawned + 1;
						_groundTransportSpawnDelay = time + 15 + (random 10);
// Added Code
						};
						// GROUND_VEHICLE_PLACEMENT_END
// End Updated Code
					};
				};
			};
			if (_groundTransportArray isNotEqualTo []) then {
				{
					if (_x isKindOf 'LandVehicle') then {
						if ((_x distance2D _centerPos) < 75) then {
							if (isNil {_x getVariable 'QS_vehicle_canUnload'}) then {
								_x setVariable ['QS_vehicle_canUnload',TRUE,FALSE];
								_x setUnloadInCombat [TRUE,TRUE];
							};
						};
					};
				} forEach _groundTransportArray;
			};
			_groundTransportCheckDelay = time + 5;
		};
	};
	
	if (_vPara) then {
		if (_timeNow > _vParaInitialDelay) then {
			_vPara = FALSE;
			if (_vParaToSpawn > 0) then {
				for '_x' from 0 to (_vParaToSpawn - 1) step 1 do {
					_foundSpawnPos = FALSE;
					for '_x' from 0 to 49 step 1 do {
						_spawnPos = _centerPos getPos [(75 + (random 350)),(random 360)];
						_spawnPos set [2,75];
						if ((_allPlayers inAreaArray [_spawnPos,100,100,0,FALSE]) isEqualTo []) then {
							_foundSpawnPos = TRUE;
						};
						if (_foundSpawnPos) exitWith {};
					};
					_spawnPos set [2,(800 + (random 400))];
					_vParaType = selectRandom _vParaTypes;
					private _perfSpawn = ['aoDefend.createVehicle',1] call QS_fnc_perfBegin;
					_vParaV = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _vParaType,_vParaType],[0,0,(100 + (random 1000))],[],0,'NONE'];
					[_perfSpawn,([0,1] select (!isNull _vParaV)),[typeOf _vParaV,netId _vParaV]] call QS_fnc_perfEnd;
					_allArray pushBack _vParaV;
					_vParaV setVariable ['QS_uav_protected',TRUE,FALSE];
					_vParaV setPos _spawnPos;
					_vParaV enableRopeAttach FALSE;
					_vParaV enableVehicleCargo FALSE;
					_vParaV setVariable ['QS_dynSim_ignore',TRUE,FALSE];
					_vParaV enableDynamicSimulation FALSE;
					clearMagazineCargoGlobal _vParaV;
					clearWeaponCargoGlobal _vParaV;
					clearItemCargoGlobal _vParaV;
					clearBackpackCargoGlobal _vParaV;
					private _perfCrew = ['aoDefend.createVehicleCrew',1,[typeOf _vParaV,netId _vParaV]] call QS_fnc_perfBegin;
					createVehicleCrew _vParaV;
					[_perfCrew,count (crew _vParaV)] call QS_fnc_perfEnd;
					if ((crew _vParaV) isNotEqualTo []) then {
						_grp = group (effectiveCommander _vParaV);
						{
							_x call _fn_unitSetup;
							0 = _allArray pushBack _x;
						} forEach (units _grp);
						_grp move (selectRandom _hqBuildingPositions);
						[(units _grp),1] call _fn_setAISkill;
					};
					if ((_vParaV emptyPositions 'CARGO') > 0) then {
						_grp3 = createGroup [_side,TRUE];
						for '_x' from 0 to ((_vParaV emptyPositions 'CARGO') - 1) step 1 do {
							_unitType = selectRandom _unitTypes;
							private _perfSpawn = ['aoDefend.createUnit',1] call QS_fnc_perfBegin;
							_unit = _grp3 createUnit [QS_core_units_map getOrDefault [toLowerANSI _unitType,_unitType],[0,0,0],[],0,'NONE'];
							[_perfSpawn,([0,1] select (!isNull _unit)),[typeOf _unit,netId _unit]] call QS_fnc_perfEnd;
							_unit = _unit call _fn_unitSetup;
							_unit assignAsCargo _vParaV;
							_unit moveInCargo _vParaV;
							0 = _allArray pushBack _unit;
						};
						_grp3 move (selectRandom _hqBuildingPositions);
						_grp3 setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
						[(units _grp3),1] call _fn_setAISkill;
					};
					_openHeight = _vParaHeightMin + (random _vParaHeightRandom);
					[_vParaV,_openHeight] spawn (missionNamespace getVariable 'QS_fnc_paraDrop');
					_vParaV lock 3;
					sleep 0.5;
				};
			};
		};
	};
	if (_tickTimeNow > _updateMoveDelay) then {
		// Mode 2 is the fallback for Defend: groups outside the capture area are
		// pushed toward HQ. An explicitly configured server value still wins.
		private _propulsionMode = missionNamespace getVariable ['QS_defend_propulsion',2];
		if (_propulsionMode isEqualTo 1) then {
			{
/* Legacy Code as of 9.9.2026 */
//|				if (alive _x) then {
// Updated Code
				if (alive _x && {!((group _x) getVariable ['QS_taruDelivery_busy',FALSE])} && {serverTime >= (_x getVariable ['QS_AI_coverUntil',0])} && {((group _x) getVariable ['QS_defendFlank_epoch',-1]) isNotEqualTo _defendEpoch}) then {
// End Updated Code
					if ((vehicle _x) isKindOf 'CAManBase') then {
						_unit = _x;
						_unitGroup = group _unit;
						_groupLeader = leader _unitGroup;
						if ((_groupLeader distance2D _centerPos) > 50) then {
							if (_unit isEqualTo _groupLeader) then {
								if (((random 1) > 0.5) || {(weaponLowered _unit)}) then {
									if (((vectorMagnitude (velocity _groupLeader)) * 3.6) < 2) then {
/* Legacy Code as of 9.9.2026 */
//|										_unitGroup move (selectRandom _hqBuildingPositions);
// Updated Code
										[_unitGroup,(selectRandom _hqBuildingPositions)] call _fn_coverMove;
// End Updated Code
									};
								};
							};
						} else {
							if (((random 1) > 0.333) || {(weaponLowered _unit)}) then {
								if ((random 1) > 0.5) then {
									_unit setUnitPosWeak (selectRandomWeighted ['UP',0.75,'MIDDLE',0.25]);
								};
								if (((vectorMagnitude (velocity _unit)) * 3.6) < 2) then {
									if ((random 1) > 0.5) then {
										if (alive (getAttackTarget _unit)) then {
											if (((getAttackTarget _unit) distance2D _unit) < 50) then {
												_moveToPos = getPosATL (getAttackTarget _unit);
											} else {
												_moveToPos = selectRandom _hqBuildingPositions;
											}
										} else {
											_moveToPos = selectRandom _hqBuildingPositions;
										};
									} else {
										_moveToPos = selectRandom _hqBuildingPositions;
									};
									_moveToPos = _moveToPos vectorAdd [0,0,1];
									if (_unit isEqualTo _groupLeader) then {
										if ((missionNamespace getVariable ['QS_debug_test',1]) isEqualTo 1) then {
											_unit commandMove _moveToPos;
										} else {
/* Legacy Code as of 9.9.2026 */
//|											_unitGroup move _moveToPos;
// Updated Code
											[_unitGroup,_moveToPos] call _fn_coverMove;
// End Updated Code
										};
									} else {
										_unit doMove _moveToPos;
									};
								};
							};
						};
					};
				};
				uiSleep 0.025;
			} count _allArray;
			if (_paratrooperArray isNotEqualTo []) then {
				_paratrooperArray = _paratrooperArray select {(alive _x)};
				if (_paratrooperArray isNotEqualTo []) then {
					{
						_unit = _x;
/* Legacy Code as of 9.9.2026 */
//|						if ((getSuppression _unit) < 0.5) then {
// Updated Code
						if ((getSuppression _unit) < 0.5 && {serverTime >= (_unit getVariable ['QS_AI_coverUntil',0])}) then {
// End Updated Code
							doStop _unit;
							_unit doMove (selectRandom _hqBuildingPositions);
						};
					} forEach _paratrooperArray;
				};
			};	
		};
		if (_propulsionMode isEqualTo 2) then {
			{
/* Legacy Code as of 9.9.2026 */
//|				if (alive _x) then {
// Updated Code
				if (alive _x && {!((group _x) getVariable ['QS_taruDelivery_busy',FALSE])} && {serverTime >= (_x getVariable ['QS_AI_coverUntil',0])} && {((group _x) getVariable ['QS_defendFlank_epoch',-1]) isNotEqualTo _defendEpoch}) then {
// End Updated Code
					if ((vehicle _x) isKindOf 'CAManBase') then {
						_unit = _x;
						_unitGroup = group _unit;
						_groupLeader = leader _unitGroup;
						if ((_groupLeader distance2D _centerPos) > 25) then {
							if (_unit isEqualTo _groupLeader) then {
								if ((random 1) > 0.5) then {
/* Legacy Code as of 9.9.2026 */
//|									_unitGroup move [(_centerPosX + (6 - (random 12))),(_centerPosY + (6 - (random 12))),_centerPosZ];
// Updated Code
									[_unitGroup,[(_centerPosX + (6 - (random 12))),(_centerPosY + (6 - (random 12))),_centerPosZ]] call _fn_coverMove;
// End Updated Code
								};
							};
						};
					};
				};
				uiSleep 0.025;
/* Legacy Code as of 9.9.2026 */
//|			} count _allArray;
// Updated Code
			} count (_allArray select {
				// Mode 2 only orders leaders. Avoid a scheduled sleep for every
				// rifleman, vehicle and crew member that cannot receive this order.
				_x isKindOf 'CAManBase' && {isNull (objectParent _x)} && {_x isEqualTo leader (group _x)}
			});
// End Updated Code
			if (_paratrooperArray isNotEqualTo []) then {
				_paratrooperArray = _paratrooperArray select {(alive _x)};
				if (_paratrooperArray isNotEqualTo []) then {
					{
						_unit = _x;
/* Legacy Code as of 9.9.2026 */
//|						if ((getSuppression _unit) < 0.5) then {
// Updated Code
						if ((getSuppression _unit) < 0.5 && {serverTime >= (_unit getVariable ['QS_AI_coverUntil',0])}) then {
// End Updated Code
							doStop _unit;
							_unit doMove (selectRandom _hqBuildingPositions);
						};
					} forEach _paratrooperArray;
				};
			};		
		};
		if (_propulsionMode isEqualTo 3) then {
			{
/* Legacy Code as of 9.9.2026 */
//|				if (alive _x) then {
// Updated Code
				if (alive _x && {!((group _x) getVariable ['QS_taruDelivery_busy',FALSE])} && {serverTime >= (_x getVariable ['QS_AI_coverUntil',0])} && {((group _x) getVariable ['QS_defendFlank_epoch',-1]) isNotEqualTo _defendEpoch}) then {
// End Updated Code
					if ((vehicle _x) isKindOf 'CAManBase') then {
						_unit = _x;
						doStop _unit;
						_unit doMove [(_centerPosX + (6 - (random 12))),(_centerPosY + (6 - (random 12))),_centerPosZ];
					};
				};
				uiSleep 0.025;
			} count _allArray;
			if (_paratrooperArray isNotEqualTo []) then {
				_paratrooperArray = _paratrooperArray select {(alive _x)};
				if (_paratrooperArray isNotEqualTo []) then {
					{
						_unit = _x;
/* Legacy Code as of 9.9.2026 */
//|						if ((getSuppression _unit) < 0.5) then {
// Updated Code
						if ((getSuppression _unit) < 0.5 && {serverTime >= (_unit getVariable ['QS_AI_coverUntil',0])}) then {
// End Updated Code
							doStop _unit;
							_unit doMove (selectRandom _hqBuildingPositions);
						};
					} forEach _paratrooperArray;
				};
			};				
		};
		if (_propulsionMode isEqualTo 4) then {
			{
/* Legacy Code as of 9.9.2026 */
//|				if (alive _x) then {
// Updated Code
				if (alive _x && {!((group _x) getVariable ['QS_taruDelivery_busy',FALSE])} && {serverTime >= (_x getVariable ['QS_AI_coverUntil',0])} && {((group _x) getVariable ['QS_defendFlank_epoch',-1]) isNotEqualTo _defendEpoch}) then {
// End Updated Code
					if ((vehicle _x) isKindOf 'CAManBase') then {
						_unit = _x;
/* Legacy Code as of 9.9.2026 */
//|						if ((getSuppression _unit) < 0.5) then {
// Updated Code
						if ((getSuppression _unit) < 0.5 && {serverTime >= (_unit getVariable ['QS_AI_coverUntil',0])}) then {
// End Updated Code
							doStop _unit;
							_unit doMove [(_centerPosX + (6 - (random 12))),(_centerPosY + (6 - (random 12))),_centerPosZ];
						};
					};
				};
				uiSleep 0.025;
			} count _allArray;
			if (_paratrooperArray isNotEqualTo []) then {
				_paratrooperArray = _paratrooperArray select {(alive _x)};
				if (_paratrooperArray isNotEqualTo []) then {
					{
						_unit = _x;
/* Legacy Code as of 9.9.2026 */
//|						if ((getSuppression _unit) < 0.5) then {
// Updated Code
						if ((getSuppression _unit) < 0.5 && {serverTime >= (_unit getVariable ['QS_AI_coverUntil',0])}) then {
// End Updated Code
							doStop _unit;
							_unit doMove (selectRandom _hqBuildingPositions);
						};
					} forEach _paratrooperArray;
				};
			};
		};
		if (_propulsionMode isEqualTo 5) then {

		};
		_updateMoveDelay = diag_tickTime + (random [5,10,15]);
	};
	if (_timeNow > _checkGroupDelay) then {
		{
			_grp = _x;
			if (((units _grp) findIf {(alive _x)}) isEqualTo -1) then {
				deleteGroup _grp;
			};
		} count allGroups;
		_checkGroupDelay = time + 20;
	};
	if (_QS_flyBy) then {
		if (_timeNow > _QS_flyByDelay) then {
			_QS_flyBy = FALSE;
			{
				private _planesBeforeFlyby = entities 'Plane';
				_x call (missionNamespace getVariable 'BIS_fnc_ambientFlyby');
				{
					if (!(_x in _planesBeforeFlyby)) then {
						[_x] call (missionNamespace getVariable 'QS_fnc_removeAircraftBombs');
						if (!isNil {missionNamespace getVariable 'QS_fnc_transformDiagRegisterEnemyJet'}) then {
							[_x,'defend.ambientFlyby'] call (missionNamespace getVariable 'QS_fnc_transformDiagRegisterEnemyJet');
						};
					};
				} forEach (entities 'Plane');
			} forEach [
				[_startPos1,_endPos1,_QS_flyByAltitude,_QS_flyBySpeed,_QS_flyByType,_side],
				[_startPos2,_endPos2,_QS_flyByAltitude,_QS_flyBySpeed,_QS_flyByType,_side]
			];
		};
	};
	if (_QS_airSuperiority) then {
		if (_timeNow > _jetInitialDelay) then {
			// Maintained live cap follows the current player count.
			_jetsToSpawn = 0;
			if (_allPlayersCount > 20) then {_jetsToSpawn = 1;};
			if (_allPlayersCount > 30) then {_jetsToSpawn = 2;};
			if (_allPlayersCount > 50) then {_jetsToSpawn = 3;};
			if (_allPlayersCount > 60) then {_jetsToSpawn = 4;};
			_jetTrackedCount = count _jetArray;
			_jetArray = _jetArray select {(alive _x) && {canMove _x}};
			if ((count _jetArray) < _jetTrackedCount) then {
				_jetSpawnDelay = time + 60 + (random 60);
			};
			if (((count _jetArray) < _jetsToSpawn) && {_timeNow > _jetSpawnDelay}) then {
				for '_x' from 0 to 49 step 1 do {
					_spawnPos = _centerPos getPos [(6000 + (random 2000)),(random 360)];
					if ((_allPlayers inAreaArray [_spawnPos,1000,1000,0,FALSE]) isEqualTo []) exitWith {};
				};
				_jetType = selectRandomWeighted (['defend_jettypes_1'] call QS_data_listVehicles);
				private _perfSpawn = ['aoDefend.createVehicle',1] call QS_fnc_perfBegin;
				_jet = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _jetType,_jetType],_spawnPos,[],0,'FLY'];
				[_perfSpawn,([0,1] select (!isNull _jet)),[typeOf _jet,netId _jet]] call QS_fnc_perfEnd;
				_jetArray pushBack _jet;
				_jet engineOn TRUE;
				_jet allowCrewInImmobile [TRUE,TRUE];
				_jet lock 2;
				_jet enableRopeAttach FALSE;
				[_jet,([1,2] select ((random 1) > 0.5)),[]] call _fn_vehicleLoadouts;
				[_jet] call (missionNamespace getVariable 'QS_fnc_removeAircraftBombs');
				clearMagazineCargoGlobal _jet;
				clearWeaponCargoGlobal _jet;
				clearItemCargoGlobal _jet;
				clearBackpackCargoGlobal _jet;
				private _perfCrew = ['aoDefend.createVehicleCrew',1,[typeOf _jet,netId _jet]] call QS_fnc_perfBegin;
				_grp = createVehicleCrew _jet;
				[_perfCrew,count (crew _jet)] call QS_fnc_perfEnd;
				[_grp,_centerPos,FALSE] call _fn_taskAttack;
				_grp enableAttack TRUE;
				_grp lockWP TRUE;
				_grp addVehicle _jet;
				[_jet,2] remoteExecCall ['QS_fnc_serverSetEntityFeatureType',2,FALSE];
				_jet setVehicleReportRemoteTargets TRUE;
				_jet setVehicleReceiveRemoteTargets TRUE;
				_jet setVehicleRadar 1;
				[(units _grp),4] call _fn_setAISkill;
				(driver _jet) enableStamina FALSE;
				(driver _jet) enableFatigue FALSE;
				0 = _allArray pushBack _jet;
				0 = _allArray pushBack (driver _jet);
				_grp setCombatMode 'RED';
				if (!isNil {missionNamespace getVariable 'QS_fnc_transformDiagRegisterEnemyJet'}) then {
					[_jet,'defend.airSuperiority'] call (missionNamespace getVariable 'QS_fnc_transformDiagRegisterEnemyJet');
				};
// Added Code
// End Updated Code
				_jetSpawnDelay = time + 60 + (random 60);
			};
		};
	};
	if (_helicopters) then {
		if (_timeNow > _helicopterInitialDelay) then {
			if (_helicoptersToSpawn > 0) then {
				for '_x' from 0 to 49 step 1 do {
					_spawnPos = _centerPos getPos [(3000 + (random 2000)),(random 360)];
					if ((_allPlayers inAreaArray [_spawnPos,1000,1000,0,FALSE]) isEqualTo []) exitWith {};
				};
				_helicopterType = selectRandom _helicopterTypes;
				private _perfSpawn = ['aoDefend.createVehicle',1] call QS_fnc_perfBegin;
				_helicopter = createVehicle [QS_core_vehicles_map getOrDefault [toLowerANSI _helicopterType,_helicopterType],_spawnPos,[],0,'FLY'];
				[_perfSpawn,([0,1] select (!isNull _helicopter)),[typeOf _helicopter,netId _helicopter]] call QS_fnc_perfEnd;
				[_helicopter,2,[]] call _fn_vehicleLoadouts;
				[_helicopter,2] remoteExecCall ['QS_fnc_serverSetEntityFeatureType',2,FALSE];
				_allArray pushBack _helicopter;
				_helicopterArray pushBack _helicopter;
				private _perfCrew = ['aoDefend.createVehicleCrew',1,[typeOf _helicopter,netId _helicopter]] call QS_fnc_perfBegin;
				_grp = createVehicleCrew _helicopter;
				[_perfCrew,count (crew _helicopter)] call QS_fnc_perfEnd;
				_direction = _spawnPos getDir _centerPos;
				_helicopter setDir _direction;
				_helicopter lock 2;
				_helicopter allowCrewInImmobile [TRUE,TRUE];
				clearMagazineCargoGlobal _helicopter;
				clearWeaponCargoGlobal _helicopter;
				clearItemCargoGlobal _helicopter;
				clearBackpackCargoGlobal _helicopter;
				if ((random 1) > 0) then {
					_helicopter setVariable ['QS_V_availableCargo',(round((_helicopter emptyPositions 'Cargo') * 2)),FALSE];
					_helicopter setVariable ['QS_V_dropInterval',(time + 10),FALSE];
				};
				[_grp,_centerPos,FALSE] call _fn_taskAttack;
				_grp lockWP TRUE;
				_grp setBehaviour 'AWARE';
				_grp setCombatMode 'RED';
				_grp setSpeedMode 'FULL';
				_grp enableAttack TRUE;
				[(units _grp),4] call _fn_setAISkill;
				_grp allowFleeing 0;
				{
					_x call _fn_unitSetup;
					0 = _allArray pushBack _x;
				} count (units _grp);
// Added Code
// End Updated Code
				_helicoptersToSpawn = _helicoptersToSpawn - 1;
				_helicopterInitialDelay = time + 15 + (random 15);
			};
			if (_helicoptersToSpawn <= 0) then {
				_helicopters = FALSE;
			};
		};
	};
	
	if (_timeNow > _heliParaCheckDelay) then {
		if (_helicopterArray isNotEqualTo []) then {
			{
				_heli = _x;
				if (!isNull _heli) then {
					if (alive _heli) then {
						if (canMove _heli) then {
							if (((getPosWorld _heli) # 2) > 40) then {
								if ((_heli distance2D _centerPos) < 400) then {
									if (!isNil {_heli getVariable 'QS_V_availableCargo'}) then {
										if ((_heli getVariable 'QS_V_availableCargo') > 0) then {
											if (time > (_heli getVariable 'QS_V_dropInterval')) then {
												if ((count (units EAST)) < 150) then {
													if (isNull _heliParaGrp) then {
														_heliParaGrp = createGroup [_side,TRUE];
														_heliParaGrp move _centerPos;
													};
													_paratrooperType = selectRandom _paratrooperTypes;
													private _perfSpawn = ['aoDefend.createUnit',1] call QS_fnc_perfBegin;
													_parajumper = _heliParaGrp createUnit [QS_core_units_map getOrDefault [toLowerANSI _paratrooperType,_paratrooperType],[0,0,0],[],0,'NONE'];
													[_perfSpawn,([0,1] select (!isNull _parajumper)),[typeOf _parajumper,netId _parajumper]] call QS_fnc_perfEnd;
													0 = _allArray pushBack _parajumper;
													_parajumper = _parajumper call _fn_unitSetup;
													if ((random 1) > 0.5) then {
														_LorR = 2;
													} else {
														_LorR = -2;
													};
													_parajumper setPos (_heli modelToWorld [_LorR,-5,-3]);
													//_parajumper enableAIFeature ['AUTOCOMBAT',FALSE];
													_parajumper enableAIFeature ['COVER',FALSE];
													_paratrooperArray pushBack _parajumper;
													sleep 0.01;
													_heli setVariable [
														'QS_V_availableCargo',
														((_heli getVariable 'QS_V_availableCargo') - 1),
														FALSE
													];
													_heli setVariable [
														'QS_V_dropInterval',
														(time + (3 + (random 7))),
														FALSE
													];
													_heliParaGrp setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
													[(units _heliParaGrp),1] call _fn_setAISkill;
												};
											};
										};
									};
								};
							};
						};
					};
				};
			} count _helicopterArray;
		};
		_heliParaCheckDelay = time + 3;
	};
	
	if (_paratroopers) then {
		if (_timeNow > _paratrooperInitialDelay) then {
			_paratroopers = FALSE;
			_grp = createGroup [_side,TRUE];
			for '_x' from 0 to (_paratroopersToSpawn - 1) step 1 do {
				_spawnPos = _centerPos getPos [(250 + (random 150)),(random 360)];
				_spawnPos set [2,(60 + (random 150))];
				_paratrooperType = selectRandom _paratrooperTypes;
				private _perfSpawn = ['aoDefend.createUnit',1] call QS_fnc_perfBegin;
				_paratrooper = _grp createUnit [QS_core_units_map getOrDefault [toLowerANSI _paratrooperType,_paratrooperType],[0,0,0],[],0,'NONE'];
				[_perfSpawn,([0,1] select (!isNull _paratrooper)),[typeOf _paratrooper,netId _paratrooper]] call QS_fnc_perfEnd;
				_paratrooper = _paratrooper call _fn_unitSetup;
				0 = _allArray pushBack _paratrooper;
				0 = _paratrooperArray pushBack _paratrooper;
				if ((backpack _paratrooper) isNotEqualTo QS_core_classNames_parachute) then {
					_paratrooper addBackpack QS_core_classNames_parachute;
				};
				//_paratrooper enableAIFeature ['AUTOCOMBAT',FALSE];
				_paratrooper enableAIFeature ['COVER',FALSE];
// Added Code
				// Preserve the intended landing point, offset only the airborne spawn.
				private _dropTarget = +_spawnPos;
				if (!isNil 'QS_fnc_aoPressure') then {_spawnPos = ['DROP_SPAWN',_spawnPos,150,_grp] call QS_fnc_aoPressure;};
// End Updated Code
				_paratrooper setPos _spawnPos;
// Added Code
				if (!isNil 'QS_fnc_aoPressure') then {['DROP_TRACK',_paratrooper,_dropTarget,_spawnPos] call QS_fnc_aoPressure;};
// End Updated Code
			};
			_grp move (selectRandom _hqBuildingPositions);
			_grp enableAttack TRUE;
			_grp setSpeedMode 'FULL';
			_grp setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
			[(units _grp),1] call _fn_setAISkill;
		};
	};
	
	if (_paratroopers2) then {
		if (_timeNow > _paratrooper2InitialDelay) then {
			_paratroopers2 = FALSE;
			if ((count (units EAST)) < 125) then {
				_grp = createGroup [_side,TRUE];
				for '_x' from 0 to (_paratroopersToSpawn - 1) step 1 do {
					_spawnPos = _centerPos getPos [(250 + (random 150)),(random 360)];
					_spawnPos set [2,(60 + (random 150))];
					_paratrooperType = selectRandom _paratrooperTypes;
					private _perfSpawn = ['aoDefend.createUnit',1] call QS_fnc_perfBegin;
					_paratrooper = _grp createUnit [QS_core_units_map getOrDefault [toLowerANSI _paratrooperType,_paratrooperType],[0,0,0],[],0,'NONE'];
					[_perfSpawn,([0,1] select (!isNull _paratrooper)),[typeOf _paratrooper,netId _paratrooper]] call QS_fnc_perfEnd;
					_paratrooper = _paratrooper call _fn_unitSetup;
					//_paratrooper enableAIFeature ['AUTOCOMBAT',FALSE];
					_paratrooper enableAIFeature ['COVER',FALSE];
					0 = _allArray pushBack _paratrooper;
					0 = _paratrooperArray pushBack _paratrooper;
					if ((backpack _paratrooper) isNotEqualTo QS_core_classNames_parachute) then {
						_paratrooper addBackpack QS_core_classNames_parachute;
					};
/* Legacy Code as of 9.9.2026 */
//|					_paratrooper setPos _spawnPos;
// Updated Code
					// Preserve the intended landing point, offset only the airborne spawn.
				private _dropTarget = +_spawnPos;
				if (!isNil 'QS_fnc_aoPressure') then {_spawnPos = ['DROP_SPAWN',_spawnPos,150,_grp] call QS_fnc_aoPressure;};
				_paratrooper setPos _spawnPos;
				if (!isNil 'QS_fnc_aoPressure') then {['DROP_TRACK',_paratrooper,_dropTarget,_spawnPos] call QS_fnc_aoPressure;};
// End Updated Code
				};
				_grp move (selectRandom _hqBuildingPositions);
				_grp enableAttack TRUE;
				_grp setSpeedMode 'FULL';
				_grp setVariable ['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners];
				[(units _grp),1] call _fn_setAISkill;
			};
		};
	};
	
	if (_timeNow > _vehicleReammoDelay) then {
		private _perfRearm = ['aoDefend.rearmBatch',count _allArray] call QS_fnc_perfBegin;
		private _perfRearmed = 0;
		if (_allArray isNotEqualTo []) then {
			{
				if (!isNull _x) then {
					private _perfAmmo = ['aoDefend.setVehicleAmmo',1,[typeOf _x,netId _x]] call QS_fnc_perfBegin;
					_x setVehicleAmmo 1;
					[_perfAmmo,1] call QS_fnc_perfEnd;
					_perfRearmed = _perfRearmed + 1;
				};
				sleep 0.007;
			} count _allArray;
		};
		[_perfRearm,_perfRearmed] call QS_fnc_perfEnd;
		_vehicleReammoDelay = time + 70;
	};
	
	if (_timeNow > _updatePlayers) then {
		_playersInArea = _allPlayers inAreaArray [_centerPos,600,600,0,FALSE];
		if (_playersInArea isNotEqualTo []) then {
			_playerVehicles = [];
			{
				if (!isNull (objectParent _x)) then {
					0 = _playerVehicles pushBack _x;
				};
			} count _playersInArea;
			if (_playerVehicles isNotEqualTo []) then {
				{
					if (_x isKindOf 'CAManBase') then {
						if (alive _x) then {
							_unit = _x;
							if (!(isNull (objectParent _unit))) then {
								{
									if (alive _x) then {
										if ((_unit knowsAbout _x) < 1) then {
											_unit reveal [_x,(round(random 4))];
										};
									};
								} count _playerVehicles;
							};
						};
					};
				} forEach _allArray;
			};
		};
		_updatePlayers = time + 15;
	};
	
	if (!(_durationAlmostOverHint)) then {
		if (serverTime > _durationAlmostOver) then {
			_durationAlmostOverHint = TRUE;
			if ((random 1) > 0.5) then {
				_text = localize 'STR_QS_Chat_013';
			} else {
				_text = localize 'STR_QS_Chat_014';
			};
			['sideChat',[WEST,'HQ'],_text] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
		};
	};
	
// Added Code
	// MEGA_DEFENSE_TIMEOUT_BEGIN
// End Updated Code
	if (serverTime > _duration) then {
/* Legacy Code as of 9.9.2026 */
//|		if (!(missionNamespace getVariable ['QS_defend_blockTimeout',FALSE])) then {
// Updated Code
		if (_megaDefense || {!(missionNamespace getVariable ['QS_defend_blockTimeout',FALSE])}) then {
// End Updated Code
			_exitSuccess = TRUE;
		} else {
			if (!(_blockMessageShown)) then {
				_extended = TRUE;
				missionNamespace setVariable ['QS_defend_blockTimeout',FALSE,FALSE];
				_duration = serverTime + 600 + (random 600);
// Added Code
				missionNamespace setVariable ['QS_megaDefense_state',['RUNNING',_defenseStartedAt,_duration,_megaDefense,_extended],FALSE];
// End Updated Code
				//[_taskID,TRUE,_duration] call (missionNamespace getVariable 'QS_fnc_taskSetTimer');
				_blockMessageShown = TRUE;
				['sideChat',[WEST,'HQ'],_blockMessage] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
			};
		};
	};
// Added Code
	// MEGA_DEFENSE_TIMEOUT_END
// End Updated Code

	if (_timeNow > _checkHeldInitialDelay) then {
		if (_timeNow > _checkHeldDelay) then {
			_enemyInHQCount = count ((units EAST) inAreaArray [_centerPos,25,25,0,FALSE,-1]);
			_playersInHQCount = count ((units WEST) inAreaArray [_centerPos,35,35,0,FALSE,-1]);
			if (_playersInHQCount isEqualTo 0) then {
				//comment 'No players in HQ';
				if (_enemyInHQCount > 3) then {
					//comment 'More than 3 enemies in HQ';
					_exitFail = TRUE;
				};
			} else {
				//comment 'There are still players in HQ area';
				if (_enemyInHQCount >= 5) then {
					//comment 'There are more than 5 enemies in HQ';
					if (_sectorControlTicker isEqualTo 1) then {
						['sideChat',[WEST,'HQ'],localize 'STR_QS_Chat_016'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
					};
					if (_sectorControlTicker > _sectorControlThreshold) then {
						_exitFail = TRUE;
					};
					if (!(_exitFail)) then {
						_sectorControlTicker = _sectorControlTicker + 1;
						if ((round((_sectorControlTicker / _sectorControlThreshold) * 100)) >= 100) then {
							//['systemChat',localize 'STR_QS_Chat_079'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
						};
					};
				} else {
					//comment 'Less than 10 enemies in HQ';
					if (_sectorControlTicker isNotEqualTo 0) then {
						if (_enemyInHQCount < 8) then {
							//comment 'Below threshold of acceptable enemies in HQ';
							_sectorControlTicker = 0;
						};
					};
				};
			};
			[_hqFlag,WEST,'',FALSE,objNull,(0 max (1 - (_sectorControlTicker / _sectorControlThreshold)) min 1)] call _fn_setFlag;
			[_taskID,TRUE,(0 max (1 - (_sectorControlTicker / _sectorControlThreshold)) min 1)] call _fn_taskSetProgress;
			_checkHeldDelay = time + 15;
		};
	};
	
	if (_exitSuccess) exitWith {
		[_hqFlag,WEST,'',FALSE,objNull,1] call _fn_setFlag;
		['sideChat',[WEST,'HQ'],localize 'STR_QS_Chat_017'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
		['DEFEND_SUCCESS',[localize 'STR_QS_Notif_003',localize 'STR_QS_Notif_005']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
		['QS_IA_TASK_DEFENDHQ','SUCCEEDED',FALSE] call (missionNamespace getVariable 'BIS_fnc_taskSetState');
		missionProfileNamespace setVariable [
			'QS_defendHQ_statistics',
			[
				(((missionProfileNamespace getVariable 'QS_defendHQ_statistics') # 0) + 1),
				((missionProfileNamespace getVariable 'QS_defendHQ_statistics') # 1)
			]
		];
	};
	if (_exitFail) exitWith {
		[_hqFlag,EAST,'',FALSE,objNull,1] call _fn_setFlag;
		['sideChat',[WEST,'HQ'],localize 'STR_QS_Chat_018'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
		['DEFEND_FAIL',[localize 'STR_QS_Notif_003',localize 'STR_QS_Notif_006']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
		['QS_IA_TASK_DEFENDHQ','FAILED',FALSE] call (missionNamespace getVariable 'BIS_fnc_taskSetState');
		missionProfileNamespace setVariable [
			'QS_defendHQ_statistics',
			[
				((missionProfileNamespace getVariable 'QS_defendHQ_statistics') # 0),
				(((missionProfileNamespace getVariable 'QS_defendHQ_statistics') # 1) + 1)
			]
	   ];
	};
	if (missionNamespace getVariable 'QS_defend_terminate') exitWith {
		['hint','Defense cancelled!'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
	};
	sleep 1.5;
};
// Added Code
// MEGA_DEFENSE_CLOSING_BEGIN
missionNamespace setVariable ['QS_megaDefense_state',['CLOSING',_defenseStartedAt,_duration,_megaDefense,_extended],FALSE];
missionNamespace setVariable ['QS_megaDefense_pending',FALSE,FALSE];
// MEGA_DEFENSE_CLOSING_END
// Release ownership before the native cleanup waits and deletes this roster.
missionNamespace setVariable ['QS_defendControl_active',FALSE,TRUE];
{[_x] call _fn_flankRelease;} forEach _flankJobs;
_flankJobs = [];
// End Updated Code
missionNamespace setVariable ['QS_defend_blockTimeout',FALSE,FALSE];
_currentStats set [2,(count allPlayers)];
_currentStats set [3,([(missionNamespace getVariable 'QS_HQpos'),300,[WEST],allPlayers,1] call (missionNamespace getVariable 'QS_fnc_serverDetector'))];
_currentStats set [4,_exitSuccess];
_defendStats = [];
_defendStats = missionProfileNamespace getVariable 'QS_defend_stat_2';
_defendStats pushBack _currentStats;
missionProfileNamespace setVariable ['QS_defend_stat_2',_defendStats];
saveMissionProfileNamespace;
{
	_x setMarkerAlpha 0;
} forEach ['QS_marker_aoCircle','QS_marker_aoMarker'];
sleep 3;
[_taskID] call (missionNamespace getVariable 'BIS_fnc_deleteTask');
sleep 7 + (random 7);
{
	missionNamespace setVariable [
		'QS_analytics_entities_deleted',
		((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),
		FALSE
	];
	deleteVehicle _x;
	sleep 0.05;
} count _allArray;
{
	missionNamespace setVariable [
		'QS_analytics_entities_deleted',
		((missionNamespace getVariable 'QS_analytics_entities_deleted') + 1),
		FALSE
	];
	if (!(_x getVariable ['QS_dead_prop',FALSE])) then {
		deleteVehicle _x;
		sleep 0.01;
	};
} count allDeadMen;
{
	deleteVehicle _x;
} forEach (allMines inAreaArray [_centerPos,300,300,0,FALSE]);
{
	if (local _x) then {
		if (((units _x) findIf {(alive _x)}) isEqualTo -1) then {
			deleteGroup _x;
		};
	};
	sleep 0.001;
} count allGroups;
if ((count allPlayers) > 5) then {
	if ((random 1) > 0.666) then {
		if (isClass (missionConfigFile >> 'CfgSounds' >> 'TheEnd')) then {
			['playSound','TheEnd'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
		};
	};
};
diag_log 'Defend AO 2';
{
	missionNamespace setVariable _x;
} forEach [
	['QS_AI_targetsKnowledge_suspend',FALSE,FALSE],
	['QS_system_restartEnabled',TRUE,FALSE],
	['QS_defendActive',FALSE,TRUE]
];
// Added Code
// MEGA_DEFENSE_CLEAR_BEGIN
missionNamespace setVariable ['QS_megaDefense_state',[],FALSE];
// MEGA_DEFENSE_CLEAR_END
// End Updated Code
