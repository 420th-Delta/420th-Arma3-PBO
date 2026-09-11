/*
File: fn_SMpriorityAA.sqf
Original mission: Quiksilver. Independent radar/SAM battery for the 420th.
*/
scriptName 'QS - Priority AA Battery';
params [['_instanceId',''],['_aoPosition',[]]];
if (!isServer || {_instanceId isEqualTo ''}) exitWith {FALSE};
private _site = [_aoPosition,diag_tickTime + 15] call QS_fnc_priorityAAFindSite;
if (_site isEqualTo []) exitWith {
	diag_log format ['QS Priority AA: deferred instance %1; no complete safe site near %2',_instanceId,_aoPosition];
	FALSE
};
if (missionNamespace getVariable ['QS_priorityAA_abort',FALSE]) exitWith {FALSE};
_site params ['_position','_satellitePositions','_vehiclePositions','_direction'];
private _taskId = format ['QS_IA_TASK_PRIORITY_AA_%1',_instanceId];
private _markerId = format ['QS_marker_priorityAA_%1',_instanceId];
private _circleId = format ['QS_marker_priorityAACircle_%1',_instanceId];
private _assets = [];
private _objectives = [];
private _launchers = [];
private _groups = [];
private _green = worldName in ['Tanoa','Enoch','Lingor3'];
private _wallType = ['Land_HBarrierWall6_F','Land_HBarrier_01_wall_6_green_F'] select _green;
private _compositionData = [];
// A 36 x 48 metre perimeter leaves room for the platforms and their turrets.
for '_offset' from -15 to 15 step 6 do {
	// Omit the central two panels on the south side for a vehicle-width entrance.
	if ((abs _offset) > 3) then {
		_compositionData pushBack [_wallType,[_offset,-24,0],180,[],FALSE,FALSE,TRUE,{}];
	};
	_compositionData pushBack [_wallType,[_offset,24,0],0,[],FALSE,FALSE,TRUE,{}];
};
for '_offset' from -21 to 21 step 6 do {
	_compositionData pushBack [_wallType,[-18,_offset,0],270,[],FALSE,FALSE,TRUE,{}];
	_compositionData pushBack [_wallType,[18,_offset,0],90,[],FALSE,FALSE,TRUE,{}];
};
private _composition = [_position,_direction,_compositionData,FALSE] call QS_fnc_serverObjectsMapper;
_assets append _composition;
// Explicit classes preserve CSAT hardware across mission vehicle mapping presets.
private _internalLauncher = createVehicle ['O_SAM_System_04_F',_position getPos [10,_direction + 180],[],0,'NONE'];
_internalLauncher setDir (_direction + 180);
private _radar = createVehicle ['O_Radar_System_02_F',_position getPos [10,_direction],[],0,'NONE'];
_radar setDir _direction;
private _staticAssets = [_internalLauncher,_radar];
_assets append _staticAssets;
{
	private _launcher = createVehicle ['O_SAM_System_04_F',_x,[],0,'NONE'];
	_launcher setDir (random 360);
	_staticAssets pushBack _launcher;
	_assets pushBack _launcher;
} forEach _satellitePositions;
if ((_staticAssets findIf {isNull _x}) isNotEqualTo -1) exitWith {
	{if (!isNull _x) then {deleteVehicle _x}} forEach _assets;
	diag_log format ['QS Priority AA: failed to create complete battery %1',_instanceId];
	FALSE
};
{
	private _vehicle = _x;
	private _isRadar = (toLowerANSI typeOf _vehicle) isEqualTo 'o_radar_system_02_f';
	_objectives pushBack _vehicle;
	_vehicle setVariable ['QS_uav_protected',TRUE,FALSE];
	_vehicle setVariable ['QS_dynSim_ignore',TRUE,TRUE];
	_vehicle setVariable ['QS_client_canAttachExp',TRUE,TRUE];
	_vehicle setVariable ['QS_RD_noRepair',TRUE,TRUE];
	_vehicle setVariable ['QS_priorityAA_instance',_instanceId,TRUE];
	_vehicle lock 2;
	_vehicle enableDynamicSimulation FALSE;
	_vehicle enableSimulationGlobal TRUE;
	_vehicle setVehicleRadar 1;
	_vehicle setVehicleReceiveRemoteTargets TRUE;
	_vehicle setVehicleReportRemoteTargets _isRadar;
	{
		_vehicle setObjectTextureGlobal [_forEachIndex,_x];
	} forEach getArray ((configOf _vehicle) >> 'TextureSources' >> (['AridHex','JungleHex'] select _green) >> 'textures');
	clearItemCargoGlobal _vehicle;
	clearBackpackCargoGlobal _vehicle;
	clearWeaponCargoGlobal _vehicle;
	clearMagazineCargoGlobal _vehicle;
	_vehicle addEventHandler ['HandleDamage',{
		params ['_vehicle','','_damage','','','_hitPartIndex'];
		private _oldDamage = if (_hitPartIndex isEqualTo -1) then {damage _vehicle} else {_vehicle getHitIndex _hitPartIndex};
		_oldDamage + ((_damage - _oldDamage) * 0.5)
	}];
	_vehicle addEventHandler ['Deleted',{
		{deleteVehicle _x} forEach attachedObjects (_this # 0);
	}];
	private _group = createVehicleCrew _vehicle;
	_group setBehaviourStrong 'AWARE';
	_group setCombatMode 'RED';
	_groups pushBack _group;
	{
		_x setVariable ['QS_hidden',TRUE,TRUE];
		_assets pushBack _x;
	} forEach crew _vehicle;
	QS_AI_vehicles pushBackUnique _vehicle;
	if (!_isRadar) then {
		_launchers pushBack [_vehicle,-1];
		[_vehicle] call QS_fnc_airDefenseRegister;
	};
} forEach _staticAssets;
private _anchor = _staticAssets # 0;
private _guardAssets = [_anchor,'PRIORITY_AA',_vehiclePositions] call QS_fnc_smEnemyEast;
_assets append _guardAssets;
_groups append (_anchor getVariable ['QS_priorityAA_guardGroups',[]]);
if (({alive _x && {_x isKindOf 'Tank'}} count _guardAssets) isNotEqualTo 3) exitWith {
	{
		if (!isNull _x) then {
			if (_x isKindOf 'LandVehicle') then {[_x,FALSE] call QS_fnc_airDefenseRegister};
			if (!(_x isKindOf 'CAManBase')) then {
				private _vehicle = _x;
				{_vehicle deleteVehicleCrew _x} forEach crew _vehicle;
			};
			deleteVehicle _x;
		};
	} forEach _assets;
	{if (!isNull _x) then {deleteGroup _x}} forEach _groups;
	diag_log format ['QS Priority AA: failed to create required guards for %1',_instanceId];
	FALSE
};
missionNamespace setVariable ['QS_priorityAA_assets',+_assets,FALSE];
private _fuzzyPosition = _position getPos [random 150,random 360];
private _markerRadius = 300 max (50 * ceil (((selectMax (_objectives apply {_x distance2D _fuzzyPosition})) + 32) / 50));
createMarker [_markerId,_fuzzyPosition];
_markerId setMarkerType 'mil_dot';
_markerId setMarkerColor 'ColorOPFOR';
_markerId setMarkerText (format ['%1 %2',toString [32,32,32],localize 'STR_QS_Marker_037']);
createMarker [_circleId,_fuzzyPosition];
_circleId setMarkerShape 'ELLIPSE';
_circleId setMarkerSize [_markerRadius,_markerRadius];
_circleId setMarkerBrush 'Border';
_circleId setMarkerColor 'ColorOPFOR';
[
	_taskId,TRUE,
	[localize 'STR_QS_Task_094',localize 'STR_QS_Task_095',localize 'STR_QS_Task_095'],
	_fuzzyPosition,'CREATED',5,FALSE,TRUE,'destroy',TRUE
] call BIS_fnc_setTask;
missionNamespace setVariable ['QS_priorityAA_position',+_position,TRUE];
missionNamespace setVariable ['QS_priorityAA_spawnedInstance',_instanceId,FALSE];
['NewPriorityTarget',[localize 'STR_QS_Notif_096']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
private _success = FALSE;
waitUntil {
	uiSleep 1;
	private _now = diag_tickTime;
	{
		_x params ['_launcher','_reloadAt'];
		if (alive _launcher && {local _launcher}) then {
			// UAVs retain a FakeWeapon magazine after their real missiles run out.
			private _hasAmmo = ((magazinesAllTurrets [_launcher,TRUE]) findIf {
				private _ammo = getText (configFile >> 'CfgMagazines' >> (_x # 0) >> 'ammo');
				((_x # 2) > 0) && {(toLowerANSI getText (configFile >> 'CfgAmmo' >> _ammo >> 'simulation')) isEqualTo 'shotmissile'}
			}) isNotEqualTo -1;
			if (_hasAmmo) then {
				_x set [1,-1];
			} else {
				if (_reloadAt < 0) then {
					_x set [1,_now + random [15,20,30]];
				} else {
					if (_now >= _reloadAt) then {
						_launcher setVehicleAmmo 1;
						_x set [1,-1];
					};
				};
			};
		};
	} forEach _launchers;
	_success = ((_objectives findIf {alive _x}) isEqualTo -1) || {missionNamespace getVariable ['QS_priorityAA_success',FALSE]};
	_success || {missionNamespace getVariable ['QS_priorityAA_abort',FALSE]}
};
if (missionNamespace getVariable ['QS_priorityAA_abort',FALSE]) then {_success = FALSE};
if (_success) then {
	['CompletedPriorityTarget',[localize 'STR_QS_Notif_097']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
} else {
	['TaskFailed',['',localize 'STR_QS_Notif_079']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
};
[[0,1] select _success,_position,[_taskId,_markerId,_circleId,_instanceId]] call QS_fnc_priorityAADebrief;
if ((missionNamespace getVariable ['QS_priorityAA_instanceId','']) isEqualTo _instanceId) then {
	missionNamespace setVariable ['QS_priorityAA_position',[],TRUE];
	missionNamespace setVariable ['QS_priorityAA_assets',[],FALSE];
};
{
	[_x] call QS_fnc_airDefenseRelease;
	[_x,FALSE] call QS_fnc_airDefenseRegister;
	_x setVehicleAmmo 0;
	_x setVehicleRadar 2;
	_x setVehicleReportRemoteTargets FALSE;
	(group gunner _x) setCombatMode 'BLUE';
} forEach _staticAssets;
// Armed mobile guards retain targeting/base protection until the collector removes them.
{
	if (_x isEqualType objNull && {!isNull _x}) then {
		QS_garbageCollector pushBack [_x,'NOW_DISCREET',0];
	};
} forEach (_assets arrayIntersect _assets);
{if (!isNull _x) then {_x deleteGroupWhenEmpty TRUE}} forEach _groups;
_success
