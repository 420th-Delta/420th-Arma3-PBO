/*/
File: fn_spawnViperTeam.sqf
Author:

	Quiksilver
	
Last Modified:

	2/07/2023 A3 2.12 by Quiksilver
	
Description:

	Spawn Viper Team
_________________________________________________/*/

params ['_type','_quantity','_total',['_viperGroup',grpNull]];
// Added Code
// Low server turnout: no piecemeal specialist replenishment. At most a 1%
// chance per native opportunity, and only with more than eight nearby ground
// players. The native scheduler retains its five-minute retry interval.
private _connected = allPlayers select {isPlayer _x && {!(_x isKindOf 'HeadlessClient_F')}};
private _smallServer = count _connected < 25;
private _viperAllowed = TRUE;
if (_smallServer && {_type in ['CLASSIC','SC']}) then {
	private _center = missionNamespace getVariable ['QS_aoPos',[0,0,0]];
	private _radius = (missionNamespace getVariable ['QS_aoSize',300]) + 600;
	private _ground = _connected select {
		alive _x && {!captive _x} && {lifeState _x in ['HEALTHY','INJURED']} &&
		{side (group _x) isEqualTo WEST} && {!((vehicle _x) isKindOf 'Air')} && {(_x distance2D _center) <= _radius}
	};
	_viperAllowed = _quantity isEqualTo 0 && {count _ground > 8} && {random 1 < 0.01};
	if (_viperAllowed) then {_total = 6;};
};
if (!_viperAllowed) exitWith {[]};
// End Updated Code
_unitTypes = ['viper_types_2'] call QS_data_listUnits;
private _lowPop = (count allPlayers) < 15;
if (_type in ['CLASSIC','SC']) exitWith {
	private _centerPos = missionNamespace getVariable ['QS_aoPos',[0,0,0]];
	private _aoSize = missionNamespace getVariable ['QS_aoSize',[0,0,0]];
	private _iterations = 0;
	private _checkVisibleDistance = 500;
	private _players = allPlayers;
	private _playersOnGround = (_players unitsBelowHeight 25) select {((side _x) in [WEST,CIVILIAN,SIDEFRIENDLY])};
	private _position1 = [0,0,0];
	for '_x' from 0 to 1 step 0 do {
		_position1 = ['RADIUS',_centerPos,_aoSize,'LAND',[1.5,0,0.5,3,0,FALSE,objNull],TRUE,[_centerPos,300,'(1 + forest) * (1 - houses)',15,3],[],FALSE] call (missionNamespace getVariable 'QS_fnc_findRandomPos');
		if (
			(
				((_position1 distance2D _centerPos) < 1500) &&
				{((_players inAreaArray [_position1,250,250,0,FALSE]) isEqualTo [])} &&
				{((((_position1 select [0,2]) nearRoads 25) select {((_x isEqualType objNull) && ((roadsConnectedTo _x) isNotEqualTo []))}) isEqualTo [])} &&
				{(([(AGLToASL _position1),_checkVisibleDistance,_playersOnGround,[WEST,CIVILIAN,SIDEFRIENDLY],0,0] call (missionNamespace getVariable 'QS_fnc_isPosVisible')) <= 0.1)}
			) || 
			{(_iterations > 300)}
		) exitWith {};
		_iterations = _iterations + 1;
	};
	if (_iterations > 300) exitWith {};
// Added Code
	private _slots = ['SLOTS',_position1,_total - _quantity,random 360] call QS_fnc_spawnGroup;
	if (_slots isEqualTo []) exitWith {[]};
// End Updated Code
	private _unit = objNull;
	private _grp = _viperGroup;
	if (isNull _grp) then {
		_grp = createGroup [EAST,TRUE];
	};
	private _unitType = '';
	for '_x' from 0 to ((_total - _quantity) - 1) step 1 do {
		_unitType = selectRandomWeighted _unitTypes;
/* Legacy Code as of 9.9.2026 */
//|		_unit = _grp createUnit [QS_core_units_map getOrDefault [toLowerANSI _unitType,_unitType],_position1,[],0,'NONE'];
// Updated Code
		_unit = _grp createUnit [QS_core_units_map getOrDefault [toLowerANSI _unitType,_unitType],_slots # _x,[],0,'NONE'];
// End Updated Code
		_unit call (missionNamespace getVariable 'QS_fnc_unitSetup');
		_unit setVehiclePosition [(getPosWorld _unit),[],0,'NONE'];
		_unit setAnimSpeedCoef 1.15;
		_unit setCustomAimCoef 0.5;
		_unit setUnitRecoilCoefficient 0.5;
		_unit setUnitTrait ['camouflageCoef',0.5,FALSE];
		_unit setUnitTrait ['audibleCoef',0.5,FALSE];
		_unit enableAIFeature ['AIMINGERROR',FALSE];
		_unit enableAIFeature ['SUPPRESSION',FALSE];
		_unit setVariable ['QS_tracersAdded',TRUE,FALSE];
		if ((random 1) > 0.5) then {
			_unit setVariable ['QS_AI_UNIT_isMG',TRUE,FALSE];
			_unit setVariable ['QS_AI_UNIT_lastSuppressiveFire',-1,FALSE];
		};
		_unit addEventHandler [
			'Hit',
			{
				if ((random 1) > 0.5) then {
					params ['_u','','','_i'];
					if (
						(local _u) &&
						{(((vectorMagnitude (velocity _u)) * 3.6) < 0.5)} &&
						{(alive _i)} &&
						{((side _i) isEqualTo WEST)} &&
						{((stance _u) in ['CROUCH','STAND'])}
					) then {
						_u playAction (selectRandom ['TactLB','TactRB','TactL','TactR','TactLF','TactRf']);
						if ((random 1) > 0.5) then {
							_u playAction (selectRandom ['TactLB','TactRB','TactL','TactR','TactLF','TactRf']);
						};
					};
				};
			}
		];
		
		if (_lowPop) then {
			removeAllPrimaryWeaponItems _unit;
		};
		
		_unit setVehiclePosition [(getPosWorld _unit),[],0,'NONE'];
		_unit setUnitPos 'Auto';
	};
	_grp setBehaviour 'AWARE';
	_grp setCombatMode 'YELLOW';
	[(units _grp),2] call (missionNamespace getVariable 'QS_fnc_serverSetAISkill');
	_grp setGroupIdGlobal ['Viper Team'];
	{
		_grp setVariable _x;
	} forEach [
		['QS_AI_GRP',TRUE,QS_system_AI_owners],
		['QS_AI_GRP_TASK',['HUNT',_position1,serverTime,-1],QS_system_AI_owners],
		['QS_AI_GRP_CONFIG',['GENERAL','INF_VIPER',(count (units _grp))],QS_system_AI_owners],
		['QS_AI_GRP_DATA',[_position1],QS_system_AI_owners],
		// This persistent group is replenished by the server and must remain server-local.
		['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE],
		['QS_AI_GRP_HC',[0,-1],QS_system_AI_owners]
	];
	(units _grp);
};
if (_type isEqualTo 'GRID') exitWith {

};
if (_type isEqualTo 'SM') exitWith {

};
