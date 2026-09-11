/*
Real Cronus radar, native data link, Rhea AI weapon launch, and protected-base hold.
No reveal, injected contacts, fireAtTarget, or scripted projectiles. The WEST jet
flies a real AI loiter orbit; it is invulnerable and does not fight back.
*/
private _basePosition = markerPos 'QS_marker_base_marker';
private _oldEnabled = missionNamespace getVariable ['QS_missionConfig_airDefense_enabled',TRUE];
private _oldRadius = missionNamespace getVariable ['QS_missionConfig_airDefense_baseExclusionRadius',2000];
private _oldRegistry = +(missionNamespace getVariable ['QS_airDefense_vehicles',[]]);
private _oldEastFriend = EAST getFriend WEST;
private _oldWestFriend = WEST getFriend EAST;
private _oldViewDistance = viewDistance;
QS_missionConfig_airDefense_enabled = TRUE;
QS_missionConfig_airDefense_baseExclusionRadius = 2000;
EAST setFriend [WEST,0];
WEST setFriend [EAST,0];
setViewDistance 6000;
T420_AA_liveShots = [];
T420_AA_liveProjectiles = [];
private _samPosition = [20000,20000,0];
private _empty = _samPosition findEmptyPosition [0,100,'O_SAM_System_04_F'];
if (_empty isNotEqualTo []) then {_samPosition = _empty};
private _radarPosition = _samPosition getPos [40,270];
_empty = _radarPosition findEmptyPosition [0,75,'O_Radar_System_02_F'];
if (_empty isNotEqualTo []) then {_radarPosition = _empty};
private _sam = createVehicle ['O_SAM_System_04_F',_samPosition,[],0,'NONE'];
private _radar = createVehicle ['O_Radar_System_02_F',_radarPosition,[],0,'NONE'];
private _orbitCenter = _samPosition getPos [2500,90];
private _targetPosition = _orbitCenter getPos [1200,90];
_targetPosition set [2,500];
private _jet = createVehicle ['B_Plane_CAS_01_F',_targetPosition,[],0,'FLY'];
private _samGroup = createVehicleCrew _sam;
private _radarGroup = createVehicleCrew _radar;
private _jetGroup = createVehicleCrew _jet;
private _owned = [_sam,_radar,_jet] + crew _sam + crew _radar + crew _jet + [_samGroup,_radarGroup,_jetGroup];
{
	_x allowDamage FALSE;
	_x enableDynamicSimulation FALSE;
} forEach [_sam,_radar,_jet];
{
	_x setBehaviourStrong 'AWARE';
	_x setCombatMode 'RED';
} forEach [_samGroup,_radarGroup];
{
	_x setSkill 1;
	_x allowDamage FALSE;
} forEach (crew _sam + crew _radar);
_sam setDir 90;
_radar setDir 90;
_radar setVehicleRadar 1;
_radar setVehicleReportRemoteTargets TRUE;
_sam setVehicleRadar 1;
_sam setVehicleReceiveRemoteTargets TRUE;
_sam setVehicleAmmo 1;
_jet setDir 0;
_jet setVehicleRadar 2;
_jet setVehicleAmmo 0;
_jet engineOn TRUE;
{
	_x disableAI 'TARGET';
	_x disableAI 'AUTOTARGET';
	_x disableAI 'AUTOCOMBAT';
	_x allowDamage FALSE;
} forEach crew _jet;
_jetGroup setBehaviourStrong 'CARELESS';
_jetGroup setCombatMode 'BLUE';
_jet enableSimulationGlobal TRUE;
_jet setPosATL _targetPosition;
_jet setVectorDirAndUp [[0,1,0],[0,0,1]];
_jet setVelocity [0,150,0];
_jet flyInHeight 500;
(driver _jet) forceSpeed 150;
private _orbit = _jetGroup addWaypoint [_orbitCenter,0];
_orbit setWaypointType 'LOITER';
_orbit setWaypointLoiterRadius 1200;
_orbit setWaypointLoiterType 'CIRCLE_L';
_orbit setWaypointSpeed 'NORMAL';
private _shotEH = _sam addEventHandler ['Fired',{
	params ['_vehicle','_weapon','','','_ammo','','_projectile','_gunner'];
	private _record = [diag_tickTime,_ammo,typeOf _projectile,missileTarget _projectile,getAttackTarget _gunner,assignedTarget _gunner,_weapon,_vehicle getVariable ['QS_airDefense_target',objNull]];
	private _index = T420_AA_liveShots pushBack _record;
	T420_AA_liveProjectiles pushBack _projectile;
	// Allow native lock/target initialization, then remove only this fixture's shot.
	[_projectile,_index] spawn {
		params ['_projectile','_index'];
		uiSleep 0.05;
		if (!isNull _projectile) then {
			(T420_AA_liveShots # _index) set [3,missileTarget _projectile];
			deleteVehicle _projectile;
		};
	};
}];
[_sam] call QS_fnc_airDefenseRegister;
private _radarSawJet = FALSE;
private _samSawDataLink = FALSE;
private _selectedJet = FALSE;
private _samples = [];
private _deadline = diag_tickTime + 45;
private _tick = 0;
waitUntil {
	private _radarContacts = getSensorTargets _radar;
	private _samContacts = getSensorTargets _sam;
	_radarSawJet = _radarSawJet || {(_radarContacts findIf {(_x # 0) isEqualTo _jet && {'activeradar' in (_x # 3)}}) >= 0};
	_samSawDataLink = _samSawDataLink || {(_samContacts findIf {(_x # 0) isEqualTo _jet && {'datalink' in (_x # 3)}}) >= 0};
	private _selection = [_sam] call QS_fnc_airDefenseSelectTarget;
	_selectedJet = _selectedJet || {(_selection # 0) isEqualTo _jet};
	[_sam] call QS_fnc_airDefenseApply;
	if ((_tick mod 5) isEqualTo 0) then {
		_samples pushBack [diag_tickTime,_radarContacts,_samContacts,_selection,assignedTarget gunner _sam,getAttackTarget gunner _sam,getPosATL _jet,speed _jet,velocity _jet,isVehicleRadarOn _radar];
	};
	_tick = _tick + 1;
	uiSleep 1;
	((T420_AA_liveShots findIf {(_x # 7) isEqualTo _jet}) >= 0) || {diag_tickTime >= _deadline}
};
uiSleep 0.25;
[_radarSawJet,'live.cronus_detects_real_flying_jet',_samples] call T420_AA_fnc_assert;
[_samSawDataLink,'live.rhea_receives_native_datalink_contact',_samples] call T420_AA_fnc_assert;
[_selectedJet,'live.controller_selects_native_sensor_contact',_samples] call T420_AA_fnc_assert;
private _missileShots = T420_AA_liveShots select {(toLowerANSI getText (configFile >> 'CfgAmmo' >> (_x # 1) >> 'simulation')) isEqualTo 'shotmissile'};
[(count _missileShots) > 0,'live.native_rhea_missile_launch',T420_AA_liveShots] call T420_AA_fnc_assert;
[(_missileShots findIf {(_x # 7) isEqualTo _jet}) >= 0,'live.launch_uses_controller_selected_jet',T420_AA_liveShots] call T420_AA_fnc_assert;
diag_log format ['T420_AA_LIVE_MAGAZINES %1; sensors %2; shots %3',magazinesAllTurrets _sam,listVehicleSensors _sam,T420_AA_liveShots];

// The loitering jet remains within this exclusion during the ten-second phase.
'QS_marker_base_marker' setMarkerPos (getPosATL _jet);
[_sam] call QS_fnc_airDefenseApply;
_sam setVehicleAmmo 1;
private _protectedShots = count T420_AA_liveShots;
private _held = _sam getVariable ['QS_airDefense_holding',FALSE];
private _protectUntil = diag_tickTime + 10;
waitUntil {
	[_sam] call QS_fnc_airDefenseApply;
	_held = _held || {_sam getVariable ['QS_airDefense_holding',FALSE]};
	uiSleep 1;
	diag_tickTime >= _protectUntil
};
[_held,'live.real_tracked_target_inside_base_is_held',[_sam getVariable ['QS_airDefense_holding',FALSE],getSensorTargets _sam]] call T420_AA_fnc_assert;
[(count T420_AA_liveShots) isEqualTo _protectedShots,'live.no_new_shots_into_protected_base',[count T420_AA_liveShots,_protectedShots]] call T420_AA_fnc_assert;
_radar setVehicleRadar 2;
_radar setVehicleReportRemoteTargets FALSE;
uiSleep 2;
diag_log format ['T420_AA_LIVE_RADAR_OFF diagnostic cached contacts may persist: radar=%1 sam=%2',getSensorTargets _radar,getSensorTargets _sam];
[_sam] call QS_fnc_airDefenseRelease;
[_sam,FALSE] call QS_fnc_airDefenseRegister;
_sam removeEventHandler ['Fired',_shotEH];
_sam setVehicleAmmo 0;
[_owned + T420_AA_liveProjectiles] call T420_AA_fnc_cleanup;
'QS_marker_base_marker' setMarkerPos _basePosition;
QS_missionConfig_airDefense_enabled = _oldEnabled;
QS_missionConfig_airDefense_baseExclusionRadius = _oldRadius;
QS_airDefense_vehicles = _oldRegistry;
EAST setFriend [WEST,_oldEastFriend];
WEST setFriend [EAST,_oldWestFriend];
setViewDistance _oldViewDistance;
TRUE
