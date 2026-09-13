/*/
File: fn_AIHandleUnit.sqf
Author: 

	Quiksilver

Last Modified:

	9/10/2023 A3 2.14 by Quiksilver

Description:

	Handle Unit AI
_______________________________________________________/*/

scriptName 'QS_fnc_AIHandleUnit';
params ['_unit','_uiTime','_fps','_playercount'];
if (
	(!(alive _unit)) ||
	{(!(local _unit))} ||
	{(!(simulationEnabled _unit))} ||
	{(!((lifeState _unit) in ['HEALTHY','INJURED']))}
) exitWith {
	if (_unit isEqualTo (leader (group _unit))) then {
		_grp = group _unit;
		if (!alive _unit) then {
			private _grpUnits = (units _grp) select {((alive _x) && ((lifeState _x) in ['HEALTHY','INJURED']))};
			if (_grpUnits isNotEqualTo []) then {
				_grpUnits = _grpUnits apply {[rankId _x,_x]};
				_grpUnits sort FALSE;
				_grp selectLeader ((_grpUnits # 0) # 1);
			};
		};
	};
};
private _grp = group _unit;
_objectParent = objectParent _unit;

// Keep non-sniper enemy infantry standing. This is enforced by
// the recurring AI handler because other mission behaviors can restore AUTO or
// explicitly select DOWN after the unit's initial setup.
private _unitType = toLowerANSI (typeOf _unit);
// Primary-only exceptions include tropical and ghillie sniper classes. Other
// activities retain their native stance rules.
private _primaryAO = !isNil 'QS_fnc_aoPressure' && {['CONTEXT',_unit] call QS_fnc_aoPressure};
private _primarySniper = _primaryAO && {['SNIPER',_unitType] call QS_fnc_aoPressure};
private _primaryArtilleryAllowed = !_primaryAO || {['ARTY_ALLOWED',_unit] call QS_fnc_aoPressure};
if (_primaryAO) then {
	_unit setVariable ['QS_AI_UNIT_disableStanceAdjust',!_primarySniper,FALSE];
	if (_primarySniper && {isNull _objectParent}) then {_unit setUnitPos 'AUTO';};
};
if (
	(isNull _objectParent) &&
	{(!isPlayer _unit)} &&
	{((side _unit) in [EAST,RESISTANCE])} &&
	{(_unit isKindOf 'CAManBase')} &&
	{(!((_unitType select [0,8]) in ['o_sniper','i_sniper']))} &&
	{!_primarySniper}
) then {
	_unit setUnitPos 'Up';
};
if (!(_unit getVariable ['QS_AI_UNIT',FALSE])) then {
	_unit setVariable ['QS_AI_UNIT',TRUE,FALSE];
	_unit setVariable ['QS_AI_UNIT_rv',[(random 1),(random 1),(random 1)],FALSE];
	if (isNil {_unit getVariable 'QS_AI_UNIT_nextSelfRearm'}) then {
		_unit setVariable ['QS_AI_UNIT_nextSelfRearm',(_uiTime + (random [180,300,420])),FALSE];
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_lastSelfHeal'}) then {
		_unit setVariable ['QS_AI_UNIT_lastSelfHeal',_uiTime,FALSE];
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_isMG'}) then {
		if (
			((toLowerANSI (primaryWeapon _unit)) in (missionNamespace getVariable ['QS_AI_weapons_MG',[]])) ||
			{((!isNull _objectParent) && {(_unit isEqualTo (gunner _objectParent))})}
		) then {
			if (
				(isNull _objectParent) || 
				{(!(['_aa_',(typeOf _objectParent),FALSE] call (missionNamespace getVariable 'QS_fnc_inString')))}
			) then {
				_unit setVariable ['QS_AI_UNIT_isMG',TRUE,FALSE];
			} else {
				_unit setVariable ['QS_AI_UNIT_isMG',FALSE,FALSE];
			};
		} else {
			_unit setVariable ['QS_AI_UNIT_isMG',FALSE,FALSE];
		};
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_isGL'}) then {
		if ((toLowerANSI (primaryWeapon _unit)) in (missionNamespace getVariable ['QS_AI_weapons_GL',[]])) then {
			_unit setVariable ['QS_AI_UNIT_isGL',TRUE,FALSE];
		} else {
			_unit setVariable ['QS_AI_UNIT_isGL',FALSE,FALSE];
		};
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_lastSmoke'}) then {
		_unit setVariable ['QS_AI_UNIT_lastSmoke',_uiTime,FALSE];
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_lastFrag'}) then {
		_unit setVariable ['QS_AI_UNIT_lastFrag',_uiTime,FALSE];
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_lastStanceAdjust'}) then {
		_unit setVariable ['QS_AI_UNIT_lastStanceAdjust',_uiTime,FALSE];
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_lastGesture'}) then {
		_unit setVariable ['QS_AI_UNIT_lastGesture',(_uiTime + (random [5,30,60])),FALSE];
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_exp'}) then {
		if (_unit getUnitTrait 'explosiveSpecialist') then {
			_unit setVariable ['QS_AI_UNIT_lastExpEval',(_uiTime + (random [30,60,90])),FALSE];
		};
	};
	if (_unit getUnitTrait 'engineer') then {
		if (isNil {_unit getVariable 'QS_AI_UNIT_assignedVehicle'}) then {
			_unit setVariable ['QS_AI_UNIT_assignedVehicle',(assignedVehicle _unit),FALSE];
		};
	};
	if (isNil {_unit getVariable 'QS_AI_unstuckInterval'}) then {
		_unit setVariable ['QS_AI_unstuckInterval',(_uiTime + (180 + (random 600))),FALSE];
	};
	if ((secondaryWeapon _unit) isNotEqualTo '') then {
		if ((_playercount < 20) || ((random 1) > 0.5)) then {
			if ((random 1) > 0.25) then {
				[_unit,_grp] call (missionNamespace getVariable 'QS_fnc_AISetRockets');
			};
		};
	};
};
_isLeader = _unit isEqualTo (leader _grp);
if (_isLeader) then {
	if (isNil {_unit getVariable 'QS_AI_UNIT_lastSupportRequest'}) then {
		_unit setVariable ['QS_AI_UNIT_lastSupportRequest',-1,FALSE];
	};
	if (isNil {_unit getVariable 'QS_AI_UNIT_lastRegroup'}) then {
		_unit setVariable ['QS_AI_UNIT_lastRegroup',(_uiTime + (random [30,60,90])),FALSE];
	};
	if (!alive _unit) then {
		private _grpUnits = (units _grp) select {((lifeState _x) in ['HEALTHY','INJURED'])};
		if (_grpUnits isNotEqualTo []) then {
			_grpUnits = _grpUnits apply {[rankId _x,_x]};
			_grpUnits sort FALSE;
			_grp selectLeader ((_grpUnits # 0) # 1);
		};
	};
};
_attackTarget = getAttackTarget _unit;

if (
	((random 1) > 0.5) &&
	(!alive _attackTarget) &&
	(_fps > 15)
) then {
	_attackTarget = [_unit,300,TRUE] call (missionNamespace getVariable 'QS_fnc_AIGetAttackTarget');
};
if (alive _attackTarget) then {
	_unit setVariable ['QS_AI_UNIT_attackTarget',_attackTarget,FALSE];
};
// Primary reports come only from actual server/HC AI knowledge. They are capped
// per leader and never read player positions to create a pursuit destination.
if (_primaryAO && {_isLeader} && {(WEST getFriend (side _grp)) < 0.6}) then {
	private _epoch = missionNamespace getVariable ['QS_primaryPressure_epoch',-1];
	private _next = _grp getVariable ['QS_primaryPressure_nextIntel',[-1,-1]];
	if ((_unit getVariable ['QS_primaryPressure_rosterEpoch',-1]) isEqualTo _epoch &&
		{(_next # 0) isNotEqualTo _epoch || {_uiTime >= (_next # 1)}}) then {
		_grp setVariable ['QS_primaryPressure_nextIntel',[_epoch,_uiTime + 10],FALSE];
		private _targets = (_unit targets [TRUE,1000,[WEST],30]) select {
			alive _x && {!captive _x} &&
			{(isPlayer _x && {lifeState _x in ['HEALTHY','INJURED']} && {isNull (objectParent _x)}) ||
				{_x isKindOf 'LandVehicle' && {((crew _x) findIf {isPlayer _x && {alive _x} && {lifeState _x in ['HEALTHY','INJURED']}}) >= 0}}}
		};
		for '_sample' from 0 to ((count _targets min 3) - 1) do {
			private _target = _targets # ((floor (_uiTime / 10) * 3 + _sample) mod (count _targets));
			private _knowledge = _unit targetKnowledge _target;
			private _age = time - (_knowledge # 2);
			if ((_knowledge # 0) && {_age >= 0} && {_age <= 30} && {(_knowledge # 5) <= 75}) then {
				private _report = [_target,serverTime - _age,ASLToAGL (_knowledge # 6),_grp knowsAbout _target,_grp,TRUE,rating _target];
				if (isServer) then {_report call QS_fnc_serverAIIntelDelta;} else {_report remoteExecCall ['QS_fnc_serverAIIntelDelta',2,FALSE];};
			};
		};
	};
};
_suppression = getSuppression _unit;
_unitReady = unitReady _unit;
_unitBehaviour = behaviour _unit;
_unitMorale = morale _unit;
_unitDamage = damage _unit;
_formationPos = formationPosition _unit;
_expectedDestination = expectedDestination _unit;
_currentCommand = currentCommand _unit;
_aiPath = _unit checkAIFeature 'PATH';
if (
	!scriptDone (_grp getVariable ['QS_AI_GRP_SCRIPT',scriptNull])
) exitWith {};
//=========== DELAYED INSTRUCTIONS
if ((_unit getVariable ['QS_AI_UNIT_delayedInstructions',[]]) isNotEqualTo []) then {
	_delayedInstructions = _unit getVariable ['QS_AI_UNIT_delayedInstructions',[-1,-1]];
	if (_uiTime > (_delayedInstructions # 0)) then {
		[_unit,(_delayedInstructions # 1)] call (missionNamespace getVariable 'QS_fnc_AIXDelayedInstruction');
	};
};
if (isNull _objectParent) then {
	
	//=============================== ADD TRACERS
	if (
		(!(_unit getVariable ['QS_AI_tracersAdded',FALSE])) &&
		{((_unit getUnitTrait 'audibleCoef') > 0.5)}
	) then {
		if (
			(
				((missionNamespace getVariable ['QS_missionConfig_tracers',1]) isEqualTo 1) &&
				{((_playercount < 15) || (([0,0,0] getEnvSoundController 'night') isEqualTo 1))}
			) ||
			{((missionNamespace getVariable ['QS_missionConfig_tracers',1]) isEqualTo 2)}
		) then {
			[_unit,_grp] call (missionNamespace getVariable 'QS_fnc_AISetTracers');
		};
	};

	//=============================== UNSTUCK CHECK
	if (_uiTime > (_unit getVariable ['QS_AI_unstuckInterval',-1])) then {
		_unit setVariable ['QS_AI_unstuckInterval',(_uiTime + (180 + (random 600))),FALSE];
		[_unit,group _unit,'CAManBase'] call (missionNamespace getVariable 'QS_fnc_AIXVehicleUnstuck');
	};

	//=============================== STANCE ADJUST
	if (!(_unit getVariable ['QS_AI_UNIT_disableStanceAdjust',FALSE])) then {
		_unitPos = unitPos _unit;
		if (
			(_unitBehaviour isEqualTo 'COMBAT') &&
			{((_suppression > 0) || (_unitDamage > 0.1))}
		) then {
			if (_uiTime > (_unit getVariable ['QS_AI_UNIT_lastStanceAdjust',-1])) then {
				_unit setVariable ['QS_AI_UNIT_lastStanceAdjust',(_uiTime + (random [15,30,45])),FALSE];
				if (_unitPos isEqualTo 'Up') then {
					_unit setUnitPos 'Middle';
				};
			};
		} else {
			if (_unitPos isEqualTo 'Down') then {
				_unit setUnitPos 'Auto';
			};
		};
	};
	//================================ SELF HEAL

	if (_uiTime > (_unit getVariable ['QS_AI_UNIT_lastSelfHeal',-1])) then {
		_unit setVariable ['QS_AI_UNIT_lastSelfHeal',(_uiTime + (random [30,60,90])),FALSE];
		if (
			(isNull _objectParent) &&
			{(
				(isNull _attackTarget) ||
				{_unitReady} ||
				{weaponLowered _unit}
			)} &&
			{(
				((damage _unit) isNotEqualTo 0) ||
				{((((getAllHitPointsDamage _unit) # 2) findIf {(_x isNotEqualTo 0)}) isNotEqualTo -1)}
			)}
		) then {
			_unit action ['HealSoldierSelf',_unit];
			_unit setDamage [0,FALSE];
		};
	};
	
	//================================ THROWABLES
	
	if (_aiPath) then {
		if (alive _attackTarget) then {
			if (
				((random 1) > 0.75) &&
				{(_unitBehaviour isNotEqualTo 'STEALTH')} &&
				{(_uiTime > (_unit getVariable ['QS_AI_UNIT_lastSmoke',-1]))} &&
				{(((alive _attackTarget) && ((_unit distance2D _attackTarget) < 100)) || {(_suppression > 0)})}
			) then {
				QS_AI_managed_smoke = QS_AI_managed_smoke select {(serverTime < _x)};
				if ((count QS_AI_managed_smoke) < QS_AI_managed_smoke_max) then {
					QS_AI_managed_smoke pushBack (serverTime + 45);
					_unit setVariable ['QS_AI_UNIT_lastSmoke',(_uiTime + (random [15,30,45])),FALSE];
					[_unit,_attackTarget,'SMOKE',TRUE] call (missionNamespace getVariable 'QS_fnc_AIXThrow');
				};
			};
			private _fragAttempted = FALSE;
			if (
				((random 1) > 0.75) &&
				{(_uiTime > (_unit getVariable ['QS_AI_UNIT_lastFrag',-1]))} &&
				{((_unit distance2D _attackTarget) < 65)}
			) then {
				QS_AI_managed_frags = QS_AI_managed_frags select {(serverTime < _x)};
				if ((count QS_AI_managed_frags) < QS_AI_managed_frags_max) then {
					QS_AI_managed_frags pushBack (serverTime + 15);
					_fragAttempted = TRUE;
					_unit setVariable ['QS_AI_UNIT_lastFrag',(_uiTime + (random [15,45,65])),FALSE];
					[_unit,_attackTarget,'FRAG',TRUE] call (missionNamespace getVariable 'QS_fnc_AIXThrow');
				};
			};
		};
	};
	
	//================================== VEHICLE DEMOLITION
	
	if (_fps > 10) then {
		if (_aiPath) then {
			if ((random 1) > 0.75) then {
				if (_uiTime > (_unit getVariable ['QS_AI_UNIT_LastGesture',-1])) then {
					_unit setVariable ['QS_AI_UNIT_LastGesture',(_uiTime + (random ([[5,10,15],[20,40,60]] select (_unitMorale < 0)))),FALSE];
					if (_unit checkAIFeature 'PATH') then {
						if ((count (missionNamespace getVariable 'QS_AI_unitsGestureReady')) < ([5,10] select (_fps > 15))) then {
							_unit setVariable ['QS_AI_UNIT_gestureEvent',TRUE,FALSE];
							_unit addEventHandler ['Hit',{call (missionNamespace getVariable 'QS_fnc_AIXHitEvade')}];
							(missionNamespace getVariable 'QS_AI_unitsGestureReady') pushBack _unit;
						};
					};
				};
			};
			if ((_unit getUnitTrait 'explosiveSpecialist') || {(_unit getUnitTrait 'engineer')}) then {
				if ((random 1) > 0.5) then {
					if (!(_unit getVariable ['QS_AI_JOB',FALSE])) then {
						if (_uiTime > (_unit getVariable ['QS_AI_UNIT_lastExpEval',-1])) then {
							_unit setVariable ['QS_AI_UNIT_lastExpEval',(serverTime + (random [30,45,60])),FALSE];
							if ((count (missionNamespace getVariable 'QS_AI_scripts_Assault')) < 3) then {
								private _targetFound = FALSE;
								_assignedTarget = assignedTarget _unit;
								if (alive _assignedTarget) then {
									_assignedTargetVehicle = vehicle _assignedTarget;
									if (
										(_assignedTargetVehicle isKindOf 'AllVehicles') &&
										{(!(_assignedTargetVehicle isKindOf 'CAManBase'))} &&
										{(isTouchingGround _assignedTargetVehicle)} &&
										{((_unit distance2D _assignedTargetVehicle) < 150)}
									) then {
										_targetFound = TRUE;
										_QS_script = [_unit,_assignedTargetVehicle,300,(selectRandomWeighted ['explosive charge',0.666,'satchel',0.333]),6,FALSE,TRUE] spawn (missionNamespace getVariable 'QS_fnc_AIXSetMine');
										_unit setVariable ['QS_AI_JOB',TRUE,FALSE];
										_unit setVariable ['QS_AI_UNIT_script',_QS_script,FALSE];
										missionNamespace setVariable ['QS_AI_scripts_Assault',((missionNamespace getVariable 'QS_AI_scripts_Assault') + [serverTime + 300]),QS_system_AI_owners];
									};
								} else {
									_unitPos = getPosATL _unit;
									_nearVehicles = [6,EAST,_unitPos,350] call (missionNamespace getVariable 'QS_fnc_AIGetKnownEnemies');
									if (_nearVehicles isNotEqualTo []) then {
										private _nearVPos = 99999;
										private _nearV = objNull;
										{
											if ((_x distance2D _unitPos) < _nearVPos) then {
												_nearVPos = _x distance2D _unitPos;
												_nearV = _x;
											};
										} forEach _nearVehicles;
										_unit doTarget _nearV;
										_targetFound = TRUE;
										_QS_script = [_unit,_nearV,300,(selectRandomWeighted ['explosive charge',0.666,'satchel',0.333]),6,FALSE,TRUE] spawn (missionNamespace getVariable 'QS_fnc_AIXSetMine');
										_unit setVariable ['QS_AI_JOB',TRUE,FALSE];
										_unit setVariable ['QS_AI_UNIT_script',_QS_script,FALSE];
										missionNamespace setVariable ['QS_AI_scripts_Assault',((missionNamespace getVariable 'QS_AI_scripts_Assault') + [serverTime + 300]),QS_system_AI_owners];
									};
								};
								if (!(_targetFound)) then {
									if ((_grp getVariable ['QS_AI_GRP_nearTargets',[]]) isNotEqualTo []) then {
										_targets = (_grp getVariable 'QS_AI_GRP_nearTargets') # 0;
										private _targetFound = FALSE;
										if (_targets isNotEqualTo []) then {
											{
												if (alive _x) then {
													if (_x isKindOf 'AllVehicles') then {
														if (!(_x isKindOf 'CAManBase')) then {
															if (isTouchingGround _x) then {
																if ((_x distance2D _unit) < 150) then {
																	_targetFound = TRUE;
																	_QS_script = [_unit,_x,300,(selectRandomWeighted ['explosive charge',0.666,'satchel',0.333]),6,FALSE,TRUE] spawn (missionNamespace getVariable 'QS_fnc_AIXSetMine');
																	_unit setVariable ['QS_AI_JOB',TRUE,FALSE];
																	_unit setVariable ['QS_AI_UNIT_script',_QS_script,FALSE];
																	missionNamespace setVariable ['QS_AI_scripts_Assault',((missionNamespace getVariable 'QS_AI_scripts_Assault') + [serverTime + 300]),QS_system_AI_owners];
																};
															};
														};
													};
												};
												if (_targetFound) exitWith {};
											} forEach _targets;
										};
									};
								};
								if (!(_targetFound)) then {
									_targets = [6,EAST,(getPosATL _unit),(150 + (random 100))] call (missionNamespace getVariable 'QS_fnc_AIGetKnownEnemies');
									if (_targets isNotEqualTo []) then {
										_targetFound = TRUE;
										_target = selectRandom _targets;
										_QS_script = [_unit,_target,300,(selectRandomWeighted ['explosive charge',0.666,'satchel',0.333]),6,FALSE,TRUE] spawn (missionNamespace getVariable 'QS_fnc_AIXSetMine');
										_unit setVariable ['QS_AI_JOB',TRUE,FALSE];
										_unit setVariable ['QS_AI_UNIT_script',_QS_script,FALSE];
										missionNamespace setVariable ['QS_AI_scripts_Assault',((missionNamespace getVariable 'QS_AI_scripts_Assault') + [serverTime + 300]),QS_system_AI_owners];
									};
								};
							};
						};
					};
				};
			};
		};
	};
	//================================== Vehicle Repair
	if (_aiPath) then {
		if (_unit getUnitTrait 'engineer') then {
			if ((count (missionNamespace getVariable 'QS_AI_scripts_support')) < 2) then {
				if (isNil {_grp getVariable 'QS_AI_engineer_vehicles'}) then {
					_grp setVariable ['QS_AI_engineer_vehicles',[],FALSE];
				};
				_grp setVariable ['QS_AI_engineer_vehicles',((_grp getVariable 'QS_AI_engineer_vehicles') select {(alive _x)}),FALSE];
				if ((count (_grp getVariable ['QS_AI_engineer_vehicles',[]])) < 2) then {
					private _vehicle = objNull;
					private _QS_script = scriptNull;
					{
						_vehicle = _x;
						if (alive _vehicle) then {
							if (_vehicle isNotEqualTo (_unit getVariable ['QS_AI_UNIT_assignedVehicle',objNull])) then {
								if (!(_vehicle in (_grp getVariable ['QS_AI_engineer_vehicles',[]]))) then {
									if (!canMove _vehicle) then {
										if ((_vehicle distance2D _unit) < 500) then {
											_grp setVariable ['QS_AI_engineer_vehicles',((_grp getVariable 'QS_AI_engineer_vehicles') + [_vehicle]),FALSE];
											_grp addVehicle _vehicle;
											_QS_script = [_unit,_vehicle,300,7,TRUE] spawn (missionNamespace getVariable 'QS_fnc_AIXRepairVehicle');
											_unit setVariable ['QS_AI_UNIT_script',_QS_script,FALSE];
											missionNamespace setVariable ['QS_AI_scripts_support',((missionNamespace getVariable 'QS_AI_scripts_support') + [serverTime + 300]),QS_system_AI_owners];
										};
									};
								} else {
									if (canMove _vehicle) then {
										_grp setVariable ['QS_AI_engineer_vehicles',((_grp getVariable 'QS_AI_engineer_vehicles') - [_vehicle]),FALSE];
										if ((alive (_unit getVariable ['QS_AI_UNIT_assignedVehicle',objNull])) || {(!('VEHICLE' in (_grp getVariable ['QS_AI_GRP_CONFIG',[]])))}) then {
											_grp leaveVehicle _vehicle;
										};
									};
								};
							};
						};
					} forEach (missionNamespace getVariable 'QS_AI_vehicles');
				} else {
					_grp setVariable ['QS_AI_engineer_vehicles',((_grp getVariable 'QS_AI_engineer_vehicles') select {(!canMove _x)}),FALSE];
				};
			};
		};
	};
};
// OUTGOING COVER FIRE: use the existing owner-local infantry pass. A small
// number of non-leading soldiers suppress a recent real sighting while the
// rest of the group moves; this creates no projectile or scheduled worker.
private _fn_coverReady = {
	params ['_fps','_now','_after','_active','_limit','_range','_age','_error','_ammo'];
	_now >= _after && {_active < _limit} && {_range >= 60} && {_range <= 500} &&
	{_age >= 0} && {_age <= 20} && {_error <= 30} && {_ammo >= 8}
};
private _fn_coverProfile = {
	params ['_players','_members'];
	if (_players <= 8) exitWith {[2,4,6,60,90]};
	[[2,4] select (_members >= 8),8,12,24,36]
};
private _fn_coverShooters = {
	params ['_candidates','_machineGunners','_limit'];
	(_machineGunners + (_candidates - _machineGunners)) select [0,_limit]
};
private _coverManaged = isNull _objectParent && {!isPlayer _unit} &&
	{(WEST getFriend (side _grp)) < 0.6} && {_unit checkAIFeature 'PATH'} &&
	{!(_unit getVariable ['QS_primaryAO_exempt',FALSE])} && {!(_grp getVariable ['QS_primaryAO_exempt',FALSE])} &&
	{!(_unit getVariable ['QS_RD_missionObjective',FALSE])} && {!(_unit getVariable ['QS_aoTask_medevac_unit',FALSE])} &&
	{_primaryAO || {missionNamespace getVariable ['QS_defendControl_active',FALSE] &&
	{(_unit distance2D (missionNamespace getVariable ['QS_HQpos',[0,0,0]])) < 2500}}};
_unit setVariable ['QS_AI_coverManaged',_coverManaged,FALSE];
//======================================================================= SUPPRESSIVE FIRE (UNIT)
if (_coverManaged || {_fps > 10}) then {
	private _isSuppressing = _currentCommand isEqualTo 'Suppress';
	if (_coverManaged && {!_isSuppressing} && {!captive _unit} &&
		{isNull (_unit getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])} &&
		{!(_unit getVariable ['QS_AI_JOB',FALSE])} && {_unitBehaviour in ['AWARE','COMBAT']} &&
		{(primaryWeapon _unit) isNotEqualTo ''} &&
		{serverTime >= (_unit getVariable ['QS_AI_coverAfter',0])} &&
		{(_unit ammo (primaryWeapon _unit)) >= 8}) then {
		private _members = (units _grp) select {alive _x && {!isPlayer _x} && {isNull (objectParent _x)}};
		private _candidates = _members select {_x isNotEqualTo leader _grp && {lifeState _x in ['HEALTHY','INJURED']}};
		private _machineGunners = _candidates select {
			_x getVariable ['QS_AI_UNIT_isMG',FALSE] ||
			{(toLowerANSI (primaryWeapon _x)) in (missionNamespace getVariable ['QS_AI_weapons_MG',[]])}
		};
		private _groundPlayers = missionNamespace getVariable [['QS_defendControl_groundCount','QS_primaryPressure_groundCount'] select _primaryAO,0];
		private _coverProfile = [_groundPlayers,count _members] call _fn_coverProfile;
		_coverProfile params ['_limit','_burstMin','_burstMax','_coolMin','_coolMax'];
		private _shooters = [_candidates,_machineGunners,_limit] call _fn_coverShooters;
		private _active = {serverTime < (_x getVariable ['QS_AI_coverUntil',0])} count _members;
		if (_unit in _shooters && {_active < _limit}) then {
			private _targets = (_unit targets [TRUE,500,[WEST],20]) select {
				isPlayer _x && {alive _x} && {!captive _x} && {lifeState _x in ['HEALTHY','INJURED']} && {isNull (objectParent _x)}
			};
			private _ordered = FALSE;
			{
				private _knowledge = _unit targetKnowledge _x;
				private _point = +(_knowledge # 6);
				private _age = time - (_knowledge # 2);
				private _distance = (eyePos _unit) distance _point;
				if (_knowledge # 0 && {(_unit knowsAbout _x) >= 1.5} &&
					{[_fps,serverTime,_unit getVariable ['QS_AI_coverAfter',0],_active,_limit,_distance,_age,_knowledge # 5,_unit ammo (primaryWeapon _unit)] call _fn_coverReady}) then {
					_point = _point vectorAdd [0,0,1];
					private _start = eyePos _unit;
					private _ray = _point vectorDiff _start;
					private _length2 = _ray vectorDotProduct _ray;
					private _friends = (_unit nearEntities ['CAManBase',500]) select {
						alive _x && {_x isNotEqualTo _unit} && {((side _grp) getFriend (side (group _x))) >= 0.6}
					};
					private _blocked = _friends findIf {
						private _position = eyePos _x;
						private _along = ((_position vectorDiff _start) vectorDotProduct _ray) / (1 max _length2);
						_along > 0 && {_along <= 1.03} && {(_position distance (_start vectorAdd (_ray vectorMultiply _along))) < 5}
					};
					if (_blocked < 0 && {!terrainIntersectASL [_start,_point]}) then {
						private _duration = _burstMin + random (_burstMax - _burstMin);
						_unit doSuppressiveFire _point;
						_unit suppressFor _duration;
						_unit setVariable ['QS_AI_coverUntil',serverTime + _duration,FALSE];
						_unit setVariable ['QS_AI_coverAfter',serverTime + _coolMin + random (_coolMax - _coolMin),FALSE];
						_unit setVariable ['QS_AI_UNIT_lastSuppressiveFire',serverTime + 24,FALSE];
						_grp setVariable ['QS_AI_coverUntil',(serverTime + _duration) max (_grp getVariable ['QS_AI_coverUntil',0]),FALSE];
						_ordered = TRUE;
						_isSuppressing = TRUE;
					};
				};
				if (_ordered) exitWith {};
			} forEach (_targets select [0,3]);
		};
	};
	if (
		(!_isSuppressing) &&
		{_fps > 10} &&
		{!_coverManaged} &&
		{(isNull _objectParent)} &&
		{((random 1) > 0.666)} &&
		{((_unit getVariable ['QS_AI_UNIT_isMG',FALSE]) || (_unit getVariable ['QS_AI_UNIT_isGL',FALSE]) || (((_unit getVariable ['QS_AI_UNIT_rv',[-1,-1,-1]]) # 0) > 0.85))} &&
		{(_uiTime > (_unit getVariable ['QS_AI_UNIT_lastSuppressiveFire',-1]))} &&
		{(_unitBehaviour in ['AWARE','COMBAT'])}
	) then {
		if (alive _attackTarget) then {
			private _attackTarget = vehicle _attackTarget;
			if (([_unit,'FIRE',_attackTarget] checkVisibility [(eyePos _unit),(aimPos _attackTarget)]) > 0) then {
				_isSuppressing = [_unit,_attackTarget,1,TRUE,TRUE,FALSE,-1] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
			} else {
				_isSuppressing = [
					_unit,
					((_unit targetKnowledge _attackTarget) # 6),
					1,
					FALSE,
					FALSE,
					FALSE,
					-1
				] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
			};
			if (((_unit getEventHandlerInfo ['FiredMan',0]) # 2) isNotEqualTo 0) then {
				_unit removeAllEventHandlers 'FiredMan';
			};
			_unit setVariable ['QS_AI_UNIT_lastSuppressiveFire',(serverTime + (random [10,15,20])),FALSE];
		};
		_hostileBuildings = missionNamespace getVariable ['QS_AI_hostileBuildings',[]];
		if (_hostileBuildings isNotEqualTo []) then {
			private _hostileBuilding = objNull;
			{
				if (([_objectParent,'VIEW',_x] checkVisibility [(eyePos _objectParent),(aimPos _x)]) > 0.1) exitWith {
					_hostileBuilding = _x;
				};
			} forEach _hostileBuildings;
			if (!isNull _hostileBuilding) then {
				if (((_unit getEventHandlerInfo ['FiredMan',0]) # 2) isNotEqualTo 0) then {
					_unit removeAllEventHandlers 'FiredMan';
				};
				_unit setVariable ['QS_AI_UNIT_lastSuppressiveFire',(serverTime + (random [10,15,20])),FALSE];
				_isSuppressing = [_unit,_hostileBuilding,selectRandomWeighted [1,0.5,2,0.5],TRUE,FALSE,FALSE,-1] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
			};
		};
	};
	
	//======================================= SUPPRESSIVE FIRE (VEHICLE)

	if (
		(alive _objectParent) &&
		{(!(_isSuppressing))} &&
		{(!((_objectParent unitTurret _unit) in [[],[-1]]))} &&
		{((['Air','StaticMortar','O_APC_Tracked_02_AA_F','O_T_APC_Tracked_02_AA_ghex_F'] findIf { _objectParent isKindOf _x }) isEqualTo -1)} &&
		{(!((toLowerANSI (currentMuzzle _unit)) in ['','fakehorn','laserdesignator_vehicle']))} &&
		{(!(_unit getVariable ['QS_AI_disableSuppFire',FALSE]))}
	) then {
		if (_uiTime > (_unit getVariable ['QS_AI_UNIT_lastSuppressiveFire',-1])) then {
			if ((random 1) > 0.666) then {
				if (_unitBehaviour in ['AWARE','COMBAT']) then {
					
					//=================================== Suppress target
					if (alive _attackTarget) then {
						private _attackTarget = vehicle _attackTarget;
						if (!(_attackTarget isKindOf 'Air')) then {
							if ((_attackTarget distance2D _unit) < 500) then {
								if (((_unit getEventHandlerInfo ['FiredMan',0]) # 2) isNotEqualTo 0) then {
									_unit removeAllEventHandlers 'FiredMan';
								};
								_unit setVariable ['QS_AI_UNIT_lastSuppressiveFire',(serverTime + (random [10,15,20])),FALSE];
								if (([_unit,'FIRE',_attackTarget] checkVisibility [[_objectParent,0] call (missionNamespace getVariable 'QS_fnc_getVehicleGunEnd'),(aimPos _attackTarget)]) > 0) then {
									_isSuppressing = [_unit,_attackTarget,selectRandomWeighted [1,0.5,2,0.5],TRUE,FALSE,FALSE,-1] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
								} else {
									_isSuppressing = [_unit,((_unit targetKnowledge _attackTarget) # 6),selectRandomWeighted [1,0.5,2,0.5],FALSE,FALSE,FALSE,-1] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
								};
							};
						};
					};

					//==================================== Suppress Building
					if (!(_isSuppressing)) then {
						_hostileBuildings = missionNamespace getVariable ['QS_AI_hostileBuildings',[]];
						if (_hostileBuildings isNotEqualTo []) then {
							private _hostileBuilding = objNull;
							{
								if ((_objectParent distance2D _x) < 500) then {
									_hostileBuilding = _x;
								};
							} forEach _hostileBuildings;
							if (!isNull _hostileBuilding) then {
								if (!(terrainIntersectASL [[_objectParent,0] call (missionNamespace getVariable 'QS_fnc_getVehicleGunEnd'),aimPos _hostileBuilding])) then {
									if (((_unit getEventHandlerInfo ['FiredMan',0]) # 2) isNotEqualTo 0) then {
										_unit removeAllEventHandlers 'FiredMan';
									};
									_unit setVariable ['QS_AI_UNIT_lastSuppressiveFire',(serverTime + (random [10,15,20])),FALSE];
									_isSuppressing = [_unit,_hostileBuilding,selectRandomWeighted [1,0.5,2,0.5],TRUE,FALSE,FALSE,-1] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
								};
							};
						};
					};
					
					//==================================== Direct Fire Support

					if (!(_isSuppressing)) then {
						private _smokeTargets = (missionNamespace getVariable ['QS_AI_smokeTargets',[]]) select {!isNull _x};
						if (_smokeTargets isNotEqualTo []) then {
							_smokeTargets = _smokeTargets inAreaArray [_unit,1000,1000,0,FALSE];
							if (_smokeTargets isNotEqualTo []) then {
								_smokeTargets = _smokeTargets apply {
									[
										(
											[
												_objectParent,
												'VIEW',			// 'FIRE'
												objNull
											] checkVisibility [
												[_objectParent,0] call (missionNamespace getVariable 'QS_fnc_getVehicleGunEnd'),
												(getPosASL _x) vectorAdd [0,0,1]
											]
										),
										_x,
										getPosASL _x
									]
								};
								_smokeTargets = _smokeTargets select {((_x # 0) > 0) && ((_x # 2) isNotEqualTo [0,0,0])};
								if (_smokeTargets isNotEqualTo []) then {
									_smokeTargets sort FALSE;
									_attackTarget = ((_smokeTargets # 0) # 2) vectorAdd [-5 + (random 10),-5 + (random 10),2 + (random 2)];
									_isSuppressing = [_unit,_attackTarget,selectRandomWeighted [1,0.5,2,0.5],TRUE,FALSE,FALSE,-1] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
								};
							};
						};
					};
					if (
						(!(_isSuppressing)) &&
						{((random 1) > 0.666)}
					) then {
						private _targets = _unit targets [TRUE, 1000];
						if (_targets isNotEqualTo []) then {
							_isSuppressing = [_unit,selectRandom _targets,selectRandomWeighted [1,0.5,2,0.5],FALSE,FALSE,FALSE,-1] call (missionNamespace getVariable 'QS_fnc_AIDoSuppressiveFire');
						};
					};
				};
			};
		};
	};
	if (
		(!(_isSuppressing)) &&
		{!_coverManaged} &&
		{((random 1) > 0.666)} &&
		{(_unitBehaviour isNotEqualTo 'STEALTH')} &&
		{((_unit getVariable ['QS_AI_UNIT_isMG',FALSE]) || (_unit getVariable ['QS_AI_UNIT_isGL',FALSE]) || (((_unit getVariable ['QS_AI_UNIT_rv',[-1,-1,-1]]) # 0) > 0.85))} &&
		{(((_unit getEventHandlerInfo ['FiredMan',0]) # 2) isEqualTo 0)} &&
		{(_uiTime > (_unit getVariable ['QS_AI_UNIT_lastSuppressiveFire',-1]))}
	) then {
		_unit addEventHandler ['FiredMan',{call (missionNamespace getVariable 'QS_fnc_AIXSuppressiveFire')}];
	};
};
if (isNull _objectParent) then {
	// SELF RE-ARM
	if (_uiTime > (_unit getVariable ['QS_AI_UNIT_nextSelfRearm',0])) then {
		_unit setVariable ['QS_AI_UNIT_nextSelfRearm',(_uiTime + (random [240,300,360])),FALSE];
		if ((primaryWeapon _unit) isNotEqualTo '') then {
			if ((_unit ammo (primaryWeapon _unit)) isEqualTo 0) then {
					private _baseWeapon = toLowerANSI ([(primaryWeapon _unit)] call (missionNamespace getVariable 'QS_fnc_baseWeapon'));
					private _magIndex = (missionNamespace getVariable 'QS_AI_weaponMagazines') findIf {((_x # 0) isEqualTo _baseWeapon)};
					private _cfgMagazines = [];
					if (_magIndex isEqualTo -1) then {
						_cfgMagazines = QS_hashmap_configfile getOrDefaultCall [
							format ['cfgweapons_%1_magazines',_baseWeapon],
							{(getArray (configFile >> 'CfgWeapons' >> _baseWeapon >> 'magazines')) apply {toLowerANSI _x}},
							TRUE
						];
						(missionNamespace getVariable 'QS_AI_weaponMagazines') pushBack [_baseWeapon,_cfgMagazines];
					} else {
						_cfgMagazines = ((missionNamespace getVariable 'QS_AI_weaponMagazines') # _magIndex) # 1;
					};
					if (_cfgMagazines isNotEqualTo []) then {
						_cfgMagazines = _cfgMagazines apply {(toLowerANSI _x)};
						private _magazines = (magazines _unit) select {((toLowerANSI _x) in _cfgMagazines)};
						if (_magazines isEqualTo []) then {
							for '_i' from 0 to 5 step 1 do {
								_unit addMagazine (_cfgMagazines # 0);
							};
							_unit addPrimaryWeaponItem (_cfgMagazines # 0);
							_unit selectWeapon (primaryWeapon _unit);
							_unit setVariable ['QS_AI_tracersAdded',FALSE,FALSE];
						};
					};
			};
		};
		if ((secondaryWeapon _unit) isNotEqualTo '') then {
			if ((_unit ammo (secondaryWeapon _unit)) isEqualTo 0) then {
				private _baseWeapon = toLowerANSI ([(secondaryWeapon _unit)] call (missionNamespace getVariable 'QS_fnc_baseWeapon'));
				private _magIndex = (missionNamespace getVariable 'QS_AI_weaponMagazines') findIf {((_x # 0) isEqualTo _baseWeapon)};
				private _cfgMagazines = [];
				if (_magIndex isEqualTo -1) then {
					_cfgMagazines = QS_hashmap_configfile getOrDefaultCall [
						format ['cfgweapons_%1_magazines',_baseWeapon],
						{(getArray (configFile >> 'CfgWeapons' >> _baseWeapon >> 'magazines')) apply {toLowerANSI _x}},
						TRUE
					];
					(missionNamespace getVariable 'QS_AI_weaponMagazines') pushBack [_baseWeapon,_cfgMagazines];
				} else {
					_cfgMagazines = ((missionNamespace getVariable 'QS_AI_weaponMagazines') # _magIndex) # 1;
				};
				if (_cfgMagazines isNotEqualTo []) then {
					_cfgMagazines = _cfgMagazines apply {(toLowerANSI _x)};
					private _magazines = (magazines _unit) select {((toLowerANSI _x) in _cfgMagazines)};
					if (_magazines isEqualTo []) then {
						for '_i' from 0 to 2 step 1 do {
							_unit addMagazine (_cfgMagazines # 0);
						};
						_unit addSecondaryWeaponItem (_cfgMagazines # 0);
						_unit selectWeapon (primaryWeapon _unit);
					};
				};
				if ((_playercount < 20) || ((random 1) > 0.5)) then {
					if ((random 1) > 0.25) then {
						[_unit,_grp] call (missionNamespace getVariable 'QS_fnc_AISetRockets');
					};
				};
			};
		};
	};
};
if (
	(_fps >= 15) &&
	{((random 1) > 0.666)} &&
	{(isNull _objectParent)} &&
	{(!_isLeader)} &&
	{(_aiPath)} &&
	{(_currentCommand in ['ATTACK','ATTACKFIRE'])} &&
	{((alive _attackTarget) && {((_unit distance2D _attackTarget) < 50)})}
) then {
	_inHouse = [_attackTarget,getPosWorld _attackTarget] call (missionNamespace getVariable 'QS_fnc_inHouse');
	private _buildingPositions = (_inHouse # 1) buildingPos -1;
	if (
		(_inHouse # 0) &&
		{(_buildingPositions isNotEqualTo [])}
	) then {
		doStop _unit;
		private _dist = 100;
		private _buildingPos = selectRandom _buildingPositions;
		{
			if ((_attackTarget distance _x) < _dist) then {
				_buildingPos = _x;
				_dist = _attackTarget distance _x;
			};
		} forEach _buildingPositions;
		if (_dist < 100) then {
			_unit doMove _buildingPos;
		};
	};
};
if (_isLeader) then {
	if (
		_aiPath &&
		{(isNull _objectParent)} &&
		{((stance _unit) isNotEqualTo 'PRONE')} &&
		{(!(_unit getVariable ['QS_AI_UNIT_regroup_disable',FALSE]))} &&
		{(_uiTime > (_unit getVariable ['QS_AI_UNIT_lastRegroup',-1]))}
	) then {
		_unit setVariable ['QS_AI_UNIT_lastRegroup',(_uiTime + (random [30,60,90])),FALSE];
		if (({(alive _x)} count (units _grp)) isEqualTo 1) then {
			[_unit,300] call (missionNamespace getVariable 'QS_fnc_AIFindNearestRegroup');
		};
	};
	if ((combatMode _grp) in ['YELLOW','RED']) then {
		if ((_unit getSlotItemName 611) isNotEqualTo '') then {
			if (_uiTime > (_unit getVariable 'QS_AI_UNIT_lastSupportRequest')) then {
				_unit setVariable ['QS_AI_UNIT_lastSupportRequest',(serverTime + (120 + (random 120))),FALSE];
				private _target = _attackTarget;
				if (!alive _target) then {
					_allTargets = _unit targets [TRUE,600];
					if (_allTargets isNotEqualTo []) then {
						_time = time;
						private _filteredTargets = _allTargets select {(((_time - ((_unit targetKnowledge _x) # 2)) < 30) && (isTouchingGround _x) && ((lifeState _x) in ['HEALTHY','INJURED']))};
						if (_filteredTargets isNotEqualTo []) then {
							if ((count _filteredTargets) isEqualTo 1) then {
								_target = _filteredTargets # 0;
							} else {
								if ((random 1) > 0.5) then {
									_target = selectRandom _filteredTargets;
								} else {
									private _rating = -9999;
									{
										if ((rating _x) > _rating) then {
											_target = _x;
											_rating = rating _x;
										};
									} count _filteredTargets;
								};
							};
						};
					};
				};
				if (
					(alive _target) && 
					(isTouchingGround _target)
				) then {
					if ((count (missionNamespace getVariable 'QS_AI_scripts_fireMissions')) <= 3) then {
						private _exit = FALSE;
						private _supportProviders = [];
						private _supportProvider = objNull;
						private _targetPos = [0,0,0];
						private _smokePos = [0,0,0];
						if (_primaryArtilleryAllowed && {(missionNamespace getVariable 'QS_AI_supportProviders_ARTY') isNotEqualTo []}) then {
							_supportProviders = missionNamespace getVariable 'QS_AI_supportProviders_ARTY';
							{
								_supportProvider = _x;
								if (!isNull _supportProvider) then {
									if (alive _supportProvider) then {
										if ((vehicle _supportProvider) isKindOf 'LandVehicle') then {
											_supportGroup = group _supportProvider;
											if ((_supportGroup getVariable 'QS_AI_GRP_DATA') # 0) then {
												if (isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'}) then {
													if (isNil {_supportGroup getVariable 'QS_AI_GRP_MTR_cooldown'}) then {
														if (((_unit targetKnowledge _target) # 6) inRangeOfArtillery [[_supportProvider],((magazines (vehicle _supportProvider)) # 0)]) then {
															_unit playActionNow 'HandSignalRadio';
															if (missionNamespace getVariable ['QS_virtualSectors_active',FALSE]) then {
																if (missionNamespace getVariable ['QS_virtualSectors_sub_1_active',FALSE]) then {
																	EAST reportRemoteTarget [_target,60];
																};
															};
															_smokePos = ((_unit targetKnowledge _target) # 6) getPos [(random 10),(random 360)];
															_smokeShell = createVehicle ['SmokeShellRed',_smokePos,[],0,'NONE'];
															_smokeShell setPosWorld ((getPosWorld _smokeShell) vectorAdd [0,0,(75 + (random 50))]);
															missionNamespace setVariable ['QS_AI_smokeTargets',((missionNamespace getVariable ['QS_AI_smokeTargets',[]]) + [_smokeShell]),QS_system_AI_owners];
															(missionNamespace getVariable 'QS_garbageCollector') pushBack [_smokeShell,'DELAYED_FORCED',(time + 120)];
															_targetPos = ((_unit targetKnowledge _target) # 6) getPos [(random 25),(random 360)];
															_targetPos set [2,0];
															_supportGroup setVariable ['QS_AI_GRP_fireMission',[_targetPos,((magazines (vehicle _supportProvider)) # 0),(round (2 + (random 2))),(serverTime + 180)],QS_system_AI_owners];
															_exit = TRUE;
														};
													};
												};
											};
										};
									};
								};
								if (_exit) exitWith {};
							} forEach _supportProviders;
						};
						if (_primaryArtilleryAllowed && {(missionNamespace getVariable 'QS_AI_supportProviders_MTR') isNotEqualTo []}) then {
							_supportProviders = missionNamespace getVariable 'QS_AI_supportProviders_MTR';
							{
								_supportProvider = _x;
								if (!isNull _supportProvider) then {
									if (alive _supportProvider) then {
										if ((vehicle _supportProvider) isKindOf 'StaticMortar') then {
											_supportGroup = group _supportProvider;
											if ((_supportGroup getVariable 'QS_AI_GRP_DATA') # 0) then {
												if (isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'}) then {
													if (isNil {_supportGroup getVariable 'QS_AI_GRP_MTR_cooldown'}) then {
														if (((_unit targetKnowledge _target) # 6) inRangeOfArtillery [[_supportProvider],((magazines (vehicle _supportProvider)) # 0)]) then {
															_unit playActionNow 'HandSignalRadio';
															if (missionNamespace getVariable ['QS_virtualSectors_active',FALSE]) then {
																if (missionNamespace getVariable ['QS_virtualSectors_sub_1_active',FALSE]) then {
																	EAST reportRemoteTarget [_target,60];
																};
															};
															_smokePos = ((_unit targetKnowledge _target) # 6) getPos [(random 10),(random 360)];
															_smokeShell = createVehicle ['SmokeShellRed',_smokePos,[],0,'NONE'];
															_smokeShell setPosWorld ((getPosWorld _smokeShell) vectorAdd [0,0,(75 + (random 50))]);
															missionNamespace setVariable ['QS_AI_smokeTargets',((missionNamespace getVariable ['QS_AI_smokeTargets',[]]) + [_smokeShell]),QS_system_AI_owners];
															(missionNamespace getVariable 'QS_garbageCollector') pushBack [_smokeShell,'DELAYED_FORCED',(time + 120)];
															_targetPos = ((_unit targetKnowledge _target) # 6) getPos [(random 25),(random 360)];
															_targetPos set [2,0];
															if (_primaryAO) then {
																private _knowledge = _unit targetKnowledge _target;
																_targetPos = ASLToAGL (_knowledge # 6);
																_targetPos set [2,0];
																private _seen = serverTime - (time - (_knowledge # 2));
																_supportGroup setVariable ['QS_AI_GRP_fireMission',[_targetPos,((magazines (vehicle _supportProvider)) # 0),6,serverTime + 30,[_target,+_targetPos,_seen]],QS_system_AI_owners];
															} else {
																_supportGroup setVariable ['QS_AI_GRP_fireMission',[_targetPos,((magazines (vehicle _supportProvider)) # 0),(round (2 + (random 2))),(serverTime + 180)],QS_system_AI_owners];
															};
															_exit = TRUE;
														};
													};
												};
											};
										};
									};
								};
								if (_exit) exitWith {};
							} forEach _supportProviders;
						};
						if (_exit) exitWith {};
						if ((missionNamespace getVariable 'QS_AI_supportProviders_CASHELI') isNotEqualTo []) then {
							_supportProviders = missionNamespace getVariable 'QS_AI_supportProviders_CASHELI';
							{
								_supportProvider = _x;
								if (!isNull _supportProvider) then {
									if (alive _supportProvider) then {
										if ((vehicle _supportProvider) isKindOf 'Helicopter') then {
											if (((vehicle _supportProvider) distance2D _target) < 3000) then {
												_supportGroup = group _supportProvider;
												if (isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'}) then {
													_unit playActionNow 'HandSignalRadio';
													_exit = TRUE;
													_supportGroup setVariable ['QS_AI_GRP_fireMission',[_target,(serverTime + 240)],QS_system_AI_owners];
													_smokePos = ((_unit targetKnowledge _target) # 6) getPos [(random 10),(random 360)];
													_smokeShell = createVehicle ['SmokeShellRed',_smokePos,[],0,'NONE'];
													_smokeShell setPosWorld ((getPosWorld _smokeShell) vectorAdd [0,0,(75 + (random 50))]);
													missionNamespace setVariable ['QS_AI_smokeTargets',((missionNamespace getVariable ['QS_AI_smokeTargets',[]]) + [_smokeShell]),QS_system_AI_owners];
													(missionNamespace getVariable 'QS_garbageCollector') pushBack [_smokeShell,'DELAYED_FORCED',(time + 120)];
													if (isDedicated) then {
														_handle = [1,_supportProvider,_supportGroup,_target,(position _target),_smokePos,(serverTime + 240)] spawn (missionNamespace getVariable 'QS_fnc_AIFireMission');
														missionNamespace setVariable ['QS_AI_scripts_fireMissions',((missionNamespace getVariable 'QS_AI_scripts_fireMissions') + [serverTime + 240]),QS_system_AI_owners];
													} else {
														[99,[1,_supportProvider,_supportGroup,_target,(position _target),_smokePos,(serverTime + 240)],(serverTime + 240)] remoteExec ['QS_fnc_remoteExec',2,FALSE];
													};
												};
											};
										};
									};
								};
								if (_exit) exitWith {};
							} forEach _supportProviders;
						};
						if (_exit) exitWith {};
						if ((missionNamespace getVariable 'QS_AI_supportProviders_CASPLANE') isNotEqualTo []) then {
							_supportProviders = missionNamespace getVariable 'QS_AI_supportProviders_CASPLANE';
							private _laserPos = [0,0,0];
							{
								_supportProvider = _x;
								if (!isNull _supportProvider) then {
									if (alive _supportProvider) then {
										if ((vehicle _supportProvider) isKindOf 'Plane') then {
											_supportGroup = group _supportProvider;
											if (isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'}) then {
												_unit playActionNow 'HandSignalRadio';
												_exit = TRUE;
												_supportGroup setVariable ['QS_AI_GRP_fireMission',[_target,(serverTime + 180)],QS_system_AI_owners];
												_laserPos = (_unit targetKnowledge _target) # 6;
												_laserPos set [2,1];
												_smokePos = ((_unit targetKnowledge _target) # 6) getPos [(random 10),(random 360)];
												_smokeShell = createVehicle ['SmokeShellRed',_smokePos,[],0,'NONE'];
												_smokeShell setPosWorld ((getPosWorld _smokeShell) vectorAdd [0,0,(75 + (random 50))]);
												missionNamespace setVariable ['QS_AI_smokeTargets',((missionNamespace getVariable ['QS_AI_smokeTargets',[]]) + [_smokeShell]),QS_system_AI_owners];
												(missionNamespace getVariable 'QS_garbageCollector') pushBack [_smokeShell,'DELAYED_FORCED',(time + 120)];
												if (isDedicated) then {
													_handle = [2,_supportProvider,_supportGroup,_target,(position _target),(serverTime + 120)] spawn (missionNamespace getVariable 'QS_fnc_AIFireMission');
													missionNamespace setVariable ['QS_AI_scripts_fireMissions',((missionNamespace getVariable 'QS_AI_scripts_fireMissions') + [serverTime + 120]),QS_system_AI_owners];
												} else {
													[99,[2,_supportProvider,_supportGroup,_target,(position _target),(serverTime + 120)],(serverTime + 120)] remoteExec ['QS_fnc_remoteExec',2,FALSE];
												};
											};
										};
									};
								};
								if (_exit) exitWith {};
							} forEach _supportProviders;
						};
						if (_exit) exitWith {};
						if ((missionNamespace getVariable 'QS_AI_supportProviders_CASUAV') isNotEqualTo []) then {
							_supportProviders = missionNamespace getVariable 'QS_AI_supportProviders_CASUAV';
							private _laserPos = [0,0,0];
							{
								_supportProvider = _x;
								if (!isNull _supportProvider) then {
									if (alive _supportProvider) then {
										if (unitIsUav _supportProvider) then {
											_supportGroup = group _supportProvider;
											if (isNil {_supportGroup getVariable 'QS_AI_GRP_fireMission'}) then {
												_unit playActionNow 'HandSignalRadio';
												_exit = TRUE;
												_supportGroup setVariable ['QS_AI_GRP_fireMission',[_target,(serverTime + 180)],QS_system_AI_owners];
												_laserPos = ((_unit targetKnowledge _target) # 6) getPos [(random 10),(random 360)];
												_laserPos set [2,1];
												_smokeShell = createVehicle ['SmokeShellRed',_laserPos,[],0,'NONE'];
												_smokeShell setPosWorld ((getPosWorld _smokeShell) vectorAdd [0,0,(75 + (random 50))]);
												missionNamespace setVariable ['QS_AI_smokeTargets',((missionNamespace getVariable ['QS_AI_smokeTargets',[]]) + [_smokeShell]),QS_system_AI_owners];
												_handle = [3,_supportProvider,_supportGroup,_target,(position _target),(serverTime + 120)] spawn (missionNamespace getVariable 'QS_fnc_AIFireMission');
												missionNamespace setVariable ['QS_AI_scripts_fireMissions',((missionNamespace getVariable 'QS_AI_scripts_fireMissions') + [serverTime + 120]),QS_system_AI_owners];
												if (isDedicated) then {
													_handle = [3,_supportProvider,_supportGroup,_target,(position _target),(serverTime + 120)] spawn (missionNamespace getVariable 'QS_fnc_AIFireMission');
													missionNamespace setVariable ['QS_AI_scripts_fireMissions',((missionNamespace getVariable 'QS_AI_scripts_fireMissions') + [serverTime + 120]),QS_system_AI_owners];
												} else {
													[99,[3,_supportProvider,_supportGroup,_target,(position _target),(serverTime + 120)],(serverTime + 120)] remoteExec ['QS_fnc_remoteExec',2,FALSE];
												};
											};
										};
									};
								};
								if (_exit) exitWith {};
							} forEach _supportProviders;
						};
						if (_exit) exitWith {};
					};
				};
			};
		};
	};
};
