/* The MIT License (MIT)  Copyright (c) 2016 Seth Duda  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
if (!isNil {missionNamespace getVariable "AR_RAPPELLING_INIT"}) exitWith {};
/* Legacy Code as of 9.9.2026 */
//|AR_RAPPELLING_INIT = compileFinal "TRUE";
// Updated Code
AR_RAPPELLING_INIT = compileFinal "TRUE";
// AI launchers can require bounded cleanup before choosing rappel insertion.
AR_QS_CLEANUP_VERSION = 1;
// End Updated Code
AP_RAPPEL_POINTS = [];
AR_RAPPEL_POINT_CLASS_HEIGHT_OFFSET = [ 	["All", [-0.05, -0.05, -0.05, -0.05, -0.05, -0.05]] ];
AR_Has_Addon_Animations_Installed = compileFinal " 	(count getText ( configFile / ""CfgMovesBasic"" / ""ManActions"" / ""AR_01"" )) > 0; ";
AR_Has_Addon_Sounds_Installed = compileFinal " 	private [""_config"",""_configMission""]; 	_config = getArray ( configFile / ""CfgSounds"" / ""AR_Rappel_Start"" / ""sound"" ); 	_configMission = getArray ( missionConfigFile / ""CfgSounds"" / ""AR_Rappel_Start"" / ""sound"" ); 	(((count _config) > 0) || ((count _configMission) > 0)); ";
/* Legacy Code as of 9.9.2026 */
//|AR_Rappel_All_Cargo = compileFinal " 	params [""_vehicle"",[""_rappelHeight"",25],[""_positionASL"",[]]]; 	if(isPlayer (driver _vehicle)) exitWith {}; 	if(local _vehicle) then { 		_this spawn { 			params [""_vehicle"",[""_rappelHeight"",25],[""_positionASL"",[]]]; 	 			_heliGroup = group driver _vehicle; 			_vehicle setVariable [""AR_Units_Rappelling"",true];  			_heliGroupOriginalBehaviour = behaviour (leader _heliGroup); 			_heliGroupOriginalCombatMode = combatMode (leader _heliGroup); 			_heliGroupOriginalFormation = formation _heliGroup;  			if (_positionASL isEqualTo []) then { 				_positionASL = AGLtoASL [(getPos _vehicle) # 0, (getPos _vehicle) # 1, 0]; 			}; 			_positionASL = _positionASL vectorAdd [0, 0, _rappelHeight]; 			 			_gameLogicLeader = _heliGroup createUnit [""LOGIC"", ASLToAGL _positionASL, [], 0, """"]; 			_heliGroup selectLeader _gameLogicLeader;  			_heliGroup setBehaviour ""Careless""; 			_heliGroup setCombatMode ""Blue""; 			_heliGroup setFormation ""File""; 			 			waitUntil { (vectorMagnitude (velocity _vehicle)) < 10 && _vehicle distance2d _gameLogicLeader < 50  }; 			 			[_vehicle, _positionASL] spawn { 				params [""_vehicle"",""_positionASL""]; 				 				while { _vehicle getVariable [""AR_Units_Rappelling"",false] && alive _vehicle } do {  					_velocityMagatude = 5; 					_distanceToPosition = ((getPosASL _vehicle) distance _positionASL); 					if( _distanceToPosition <= 10 ) then { 						_velocityMagatude = (_distanceToPosition / 10) * _velocityMagatude; 					}; 					 					_currentVelocity = velocity _vehicle; 					_currentVelocity = _currentVelocity vectorAdd (( (getPosASL _vehicle) vectorFromTo _positionASL ) vectorMultiply _velocityMagatude); 					_currentVelocity = (vectorNormalized _currentVelocity) vectorMultiply ( (vectorMagnitude _currentVelocity) min _velocityMagatude ); 					_vehicle setVelocity _currentVelocity; 					 					sleep 0.05; 				}; 			};  			_rappelUnits = []; 			_rappelledGroups = []; 			{ 				if( group _x != _heliGroup && alive _x ) then { 					_rappelUnits pushBack _x; 					_rappelledGroups = _rappelledGroups + [group _x]; 				}; 			} forEach crew _vehicle; 	 			_unitsOutsideVehicle = []; 			while { count _unitsOutsideVehicle != count _rappelUnits } do { 	 				_distanceToPosition = ((getPosASL _vehicle) distance _positionASL); 				if(_distanceToPosition < 3) then { 					{ 						[_x, _vehicle] call AR_Rappel_From_Heli;					 						sleep 1; 					} forEach (_rappelUnits-_unitsOutsideVehicle); 					{ 						if!(_x in _vehicle) then { 							_unitsOutsideVehicle pushBack _x; 						}; 					} forEach (_rappelUnits-_unitsOutsideVehicle); 				}; 				sleep 2; 			}; 			 			_unitsRappelling = true; 			while { _unitsRappelling } do { 				_unitsRappelling = false; 				{ 					if( _x getVariable [""AR_Is_Rappelling"",false] ) then { 						_unitsRappelling = true; 					}; 				} forEach _rappelUnits; 				sleep 3; 			}; 			 			deleteVehicle _gameLogicLeader; 			 			_heliGroup setBehaviour _heliGroupOriginalBehaviour; 			_heliGroup setCombatMode _heliGroupOriginalCombatMode; 			_heliGroup setFormation _heliGroupOriginalFormation;  			_vehicle setVariable [""AR_Units_Rappelling"",nil]; 	 		}; 	} else { 		[_this,""AR_Rappel_All_Cargo"",_vehicle] call AR_RemoteExec; 	}; ";
// Updated Code
// Keep annotated function bodies as Code so normal file preprocessing handles
// their comments before compileFinal makes them immutable (Arma 3 2.14+).
AR_QS_AI_Rappel_Clear = compileFinal {
// AI_RAPPEL_CLEARANCE_BEGIN
// One local pass per available anchor, at most six per release attempt.
// The worker spaces attempts by 0.6 s; there are no per-frame world scans.
// The actual rope anchor, descent time and present drift define the footprint.
params ['_heli','_point'];
private _anchor = _heli modelToWorldVisualWorld _point;
private _ground = [_anchor # 0,_anchor # 1,0];
private _height = (_anchor # 2) - (getTerrainHeightASL _ground);
if (_height < 8 || {_height > 45}) exitWith {FALSE};
private _drift = velocity _heli;
_drift set [2,0];
// The worker limits speed to 5 m/s. Cover descent plus one second, with
// 4 m for the initial +/-2 m displacement, body width and anchor motion.
private _radius = 4 + (((vectorMagnitude _drift) min 5) * (1 + ((_height + 3) / 5)));
if ((allPlayers inAreaArray [_ground,50 + _radius,50 + _radius,0,FALSE]) isNotEqualTo []) exitWith {FALSE};
if ((nearestTerrainObjects [_ground,['TREE','SMALL TREE','ROCK','ROCKS','BUILDING','HOUSE','WALL','FENCE','POWER LINES'],_radius + 10,FALSE,TRUE]) isNotEqualTo []) exitWith {FALSE};
private _occupied = (nearestObjects [_ground,['Man','LandVehicle','Static','ReammoBox_F'],_radius + 10,TRUE]) findIf {
    if (_x isKindOf 'Man') then {
        alive _x && {isNull (objectParent _x)} && {((getPosATL _x) # 2) < 3} && {(_x distance2D _ground) < (_radius + 1)}
    } else {TRUE}
};
if (_occupied >= 0) exitWith {FALSE};
private _clear = TRUE;
// Nine terrain samples cover the center and perimeter; one vertical ray at
// the real anchor catches geometry above the landing surface, including roofs.
{
    private _sample = _ground vectorAdd [(_x # 0) * _radius,(_x # 1) * _radius,0];
    if ((_sample # 0) < 50 || {(_sample # 1) < 50} ||
        {(_sample # 0) > worldSize - 50} || {(_sample # 1) > worldSize - 50} ||
        {surfaceIsWater _sample} || {((surfaceNormal _sample) # 2) <= 0.96} ||
        {abs ((getTerrainHeightASL _sample) - (getTerrainHeightASL _ground)) > 3}) exitWith {_clear = FALSE;};
} forEach [[0,0],[1,0],[-1,0],[0,1],[0,-1],[0.7071,0.7071],[-0.7071,0.7071],[0.7071,-0.7071],[-0.7071,-0.7071]];
if (!_clear) exitWith {FALSE};
private _bottom = [_ground # 0,_ground # 1,(getTerrainHeightASL _ground) + 0.2];
(lineIntersectsSurfaces [_anchor,_bottom,_heli,objNull,TRUE,1,'GEOM','ROADWAY',TRUE]) isEqualTo []
// AI_RAPPEL_CLEARANCE_END
};
AR_QS_AI_Rappel_Egress = compileFinal {
// AI_RAPPEL_EGRESS_BEGIN
// A landed AI gets one bounded search and one movement order, not a new worker.
params ['_unit','_heli','_bearing'];
if (!alive _unit || {!local _unit} || {isPlayer _unit} || {captive _unit} ||
    {!isNull (remoteControlled _unit)} || {!isNull (_unit getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}) exitWith {FALSE};
private _center = getPosATL _heli;
_center set [2,0];
private _drift = velocity _heli;
_drift set [2,0];
private _height = ((getPosATL _heli) # 2) max 8 min 45;
private _radius = 20 max (16 + (((vectorMagnitude _drift) min 5) * (1 + ((_height + 3) / 5))));
private _point = [];
for '_i' from 0 to 5 do {
    private _candidate = _center getPos [_radius,_bearing + (60 * _i)];
    if ((_candidate # 0) > 50 && {(_candidate # 1) > 50} &&
        {(_candidate # 0) < worldSize - 50} && {(_candidate # 1) < worldSize - 50} &&
        {!surfaceIsWater _candidate} && {((surfaceNormal _candidate) # 2) > 0.96} &&
        {(nearestTerrainObjects [_candidate,['TREE','SMALL TREE','ROCK','ROCKS','BUILDING','HOUSE','WALL','FENCE'],4,FALSE,TRUE]) isEqualTo []} &&
        {((nearestObjects [_candidate,['Man','LandVehicle','Static','ReammoBox_F'],4,TRUE]) findIf {_x isNotEqualTo _unit && {alive _x}}) < 0}) exitWith {_point = _candidate;};
};
if (_point isEqualTo []) exitWith {FALSE};
_unit doMove _point;
TRUE
// AI_RAPPEL_EGRESS_END
};
AR_Rappel_All_Cargo = compileFinal {
// One bounded worker controls the existing pilot; no Game Logic is created.
// Player rappelling keeps its existing controls and descent speed.
params ['_vehicle',['_rappelHeight',25],['_positionASL',[]],['_budget',45]];
if (isNull _vehicle || {!alive _vehicle} || {(isPlayer (driver _vehicle) || {!isNull (remoteControlled (driver _vehicle))} || {!isNull ((driver _vehicle) getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])})}) exitWith {};
if (!local _vehicle) exitWith {[_this,'AR_Rappel_All_Cargo',_vehicle] call AR_RemoteExec;};
if (_vehicle getVariable ['AR_Units_Rappelling',FALSE]) exitWith {};
private _pilot = driver _vehicle;
private _heliGroup = group _pilot;
if (!alive _pilot || {isNull _heliGroup} || {!local _heliGroup}) exitWith {};
private _fn_activity = { [
	+(missionNamespace getVariable ['QS_aoPos',[0,0,0]]),
	missionNamespace getVariable ['QS_classic_AI_active',FALSE],
	missionNamespace getVariable ['QS_primaryPressure_running',FALSE],
	missionNamespace getVariable ['QS_primaryPressure_epoch',-1],
	missionNamespace getVariable ['QS_defendActive',FALSE],
	missionNamespace getVariable ['QS_defendControl_active',FALSE],
	missionNamespace getVariable ['QS_defendControl_epoch',-1],
	missionNamespace getVariable ['QS_customAO_GT_active',FALSE]
] };
private _activity = call _fn_activity;
// Claim before spawn, so two calls in one frame cannot create two leaders.
_vehicle setVariable ['AR_Units_Rappelling',TRUE];
_vehicle setVariable ['QS_AR_releaseState','WAITING'];
private _handle = [_vehicle,_rappelHeight,_positionASL,_pilot,_heliGroup,_fn_activity,_activity,_budget] spawn {
	params ['_vehicle','_rappelHeight','_positionASL','_pilot','_heliGroup','_fn_activity','_activity','_budget'];
	scriptName 'QS AI Rappel Insertion';
	if (!alive _vehicle || {!alive _pilot} || {!local _vehicle} || {!local _heliGroup} ||
		{_activity isNotEqualTo (call _fn_activity)}) exitWith {
		_vehicle setVariable ['AR_Units_Rappelling',nil];
		_vehicle setVariable ['QS_AR_bulkHandle',nil];
	};
	private _expires = diag_tickTime + (0 max _budget min 45);
	private _approachExpires = _expires min (diag_tickTime + 15);
	private _behaviour = behaviour _pilot;
	private _combatMode = combatMode _heliGroup;
	private _formation = formation _heliGroup;
	private _hcExcluded = _heliGroup getVariable ['QS_AI_GRP_HC_EXCLUDED',FALSE];
	_heliGroup setVariable ['QS_AI_GRP_HC_EXCLUDED',TRUE,TRUE];
	if (_positionASL isEqualTo []) then {_positionASL = AGLToASL [(getPos _vehicle) # 0,(getPos _vehicle) # 1,0];};
	_positionASL = _positionASL vectorAdd [0,0,_rappelHeight];
	private _landing = ASLToAGL _positionASL;
	_landing set [2,0];
	_vehicle flyInHeight [_rappelHeight,TRUE];
	_pilot doMove _landing;
	_heliGroup move _landing;
	private _onEnd = {
		params ['_vehicle'];
		_vehicle setVariable ['AR_Units_Rappelling',FALSE];
	};
	private _killedEH = _vehicle addEventHandler ['Killed',_onEnd];
	private _deletedEH = _vehicle addEventHandler ['Deleted',_onEnd];
	private _fn_current = {
		alive _vehicle && {alive _pilot} && {canMove _vehicle} &&
		{local _vehicle} && {local _heliGroup} && {!(isPlayer (driver _vehicle) || {!isNull (remoteControlled (driver _vehicle))} || {!isNull ((driver _vehicle) getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])})} &&
		{_vehicle getVariable ['AR_Units_Rappelling',FALSE]} &&
		{diag_tickTime < _expires} && {_activity isEqualTo (call _fn_activity)}
	};
	private _rappelUnits = (crew _vehicle) select {
		alive _x && {!isPlayer _x} && {isNull (remoteControlled _x)} &&
		{isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])} && {(group _x) isNotEqualTo _heliGroup}
	};
	if (call _fn_current) then {
		_heliGroup setBehaviour 'CARELESS'; _heliGroup setCombatMode 'BLUE'; _heliGroup setFormation 'FILE';
		waitUntil {
			uiSleep 0.25;
			!(call _fn_current) || {diag_tickTime >= _approachExpires} ||
			{(_vehicle distance2D _landing) <= 20 &&
				{abs (((getPosASL _vehicle) # 2) - (_positionASL # 2)) <= 8}}
		};
		private _approached = diag_tickTime < _approachExpires;
		private _nextUnit = 0;
        private _egressChecked = [];
        private _nextEgress = 0;
		// Approach correction and unloading share one worker; movement is allowed.
		// Release one available AI every 0.6 s; six anchors still limit concurrency.
		while {_approached && {call _fn_current}} do {
            // Make room before the next anchors are reused. Never move a
            // player/Zeus takeover or order an AI that is still on its rope.
            if (diag_tickTime >= _nextEgress) then {
                {
                    if (!(_x in _egressChecked) && {alive _x} && {isNull (objectParent _x)} &&
                        {!(_x getVariable ['AR_Is_Rappelling',FALSE])} && {((getPosATL _x) # 2) < 3}) then {
                        _egressChecked pushBack _x;
                        [_x,_vehicle,360 * (_forEachIndex / (1 max (count _rappelUnits)))] call AR_QS_AI_Rappel_Egress;
                    };
                } forEach _rappelUnits;
                _nextEgress = diag_tickTime + 0.6;
            };
			private _pending = _rappelUnits select {alive _x && {!isPlayer _x} && {!captive _x} && {isNull (remoteControlled _x)} &&
                {isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])} &&
                {_x in _vehicle} && {!(_x getVariable ['AR_Is_Rappelling',FALSE])}};
			private _descending = _rappelUnits select {alive _x && {_x getVariable ['AR_Is_Rappelling',FALSE]}};
			if (_pending isEqualTo [] && {_descending isEqualTo []}) exitWith {};
			private _distance = (getPosASL _vehicle) distance _positionASL;
			private _speed = 5 * (1 min (_distance / 10));
			private _velocity = (velocity _vehicle) vectorAdd (((getPosASL _vehicle) vectorFromTo _positionASL) vectorMultiply _speed);
			_vehicle setVelocity ((vectorNormalized _velocity) vectorMultiply ((vectorMagnitude _velocity) min _speed));
			// Release at the required altitude inside the insertion area. The
			// aircraft may still be moving; no stationary/settled prerequisite.
			if ((_vehicle distance2D _landing) <= 20 &&
				{abs (((getPosASL _vehicle) # 2) - (_positionASL # 2)) <= 8} &&
				{diag_tickTime >= _nextUnit} && {_pending isNotEqualTo []}) then {
				[_pending # 0,_vehicle] call AR_Rappel_From_Heli;
				_nextUnit = diag_tickTime + 0.6;
			};
			if ((_vehicle getVariable ['QS_AR_releaseState','']) isEqualTo 'BLOCKED') exitWith {};
			uiSleep 0.05;
		};
	};
	// Administrative cancellation stops new releases, but an already descending
	// unit keeps its rope while the Taru caller holds position. Fatal aircraft
	// failure still ends every attached descent immediately.
	if (!alive _vehicle || {!alive _pilot} || {!canMove _vehicle}) then {
		{
			if ((_x getVariable ['AR_Rappelling_Vehicle',objNull]) isEqualTo _vehicle) then {
				_x setVariable ['AR_Is_Rappelling',FALSE,TRUE];
			};
		} forEach _rappelUnits;
	};
	if (!isNull _heliGroup && {local _heliGroup}) then {
		_heliGroup setBehaviour _behaviour; _heliGroup setCombatMode _combatMode; _heliGroup setFormation _formation;
		_heliGroup setVariable ['QS_AI_GRP_HC_EXCLUDED',_hcExcluded,TRUE];
	};
	if (!isNull _vehicle) then {
		_vehicle removeEventHandler ['Killed',_killedEH];
		_vehicle removeEventHandler ['Deleted',_deletedEH];
		_vehicle setVariable ['AR_Units_Rappelling',nil];
		_vehicle setVariable ['QS_AR_bulkHandle',nil];
	};
};
_vehicle setVariable ['QS_AR_bulkHandle',_handle];
_handle
};
// End Updated Code
AR_Get_Heli_Rappel_Points = compileFinal " 	params [""_vehicle""]; 	 	 	private [""_preDefinedRappelPoints"",""_className"",""_rappelPoints"",""_preDefinedRappelPointsConverted""]; 	_preDefinedRappelPoints = []; 	{ 		_className = _x # 0; 		_rappelPoints = _x # 1; 		if( _vehicle isKindOf _className ) then { 			_preDefinedRappelPoints = _rappelPoints; 		}; 	} forEach (AP_RAPPEL_POINTS + (missionNamespace getVariable [""AP_CUSTOM_RAPPEL_POINTS"",[]])); 	if(count _preDefinedRappelPoints > 0) exitWith { 		_preDefinedRappelPointsConverted = []; 		{ 			if (_x isEqualType '') then { 				_modelPosition = _vehicle selectionPosition _x; 				if( [0,0,0] distance _modelPosition > 0 ) then { 					_preDefinedRappelPointsConverted pushBack _modelPosition; 				}; 			} else { 				_preDefinedRappelPointsConverted pushBack _x; 			}; 		} forEach _preDefinedRappelPoints; 		_preDefinedRappelPointsConverted; 	};  	private [ 		""_rappelPointsArray"",""_cornerPoints"",""_frontLeftPoint"",""_frontRightPoint"",""_rearLeftPoint"",""_rearRightPoint"",""_rearLeftPointFinal"", 		""_rearRightPointFinal"",""_frontLeftPointFinal"",""_frontRightPointFinal"",""_middleLeftPointFinal"",""_middleRightPointFinal"",""_vehicleUnitVectorUp"", 		""_rappelPoints"",""_modelPoint"",""_modelPointASL"",""_surfaceIntersectStartASL"",""_surfaceIntersectEndASL"",""_surfaces"",""_intersectionASL"",""_intersectionObject"", 		""_la"",""_lb"",""_n"",""_p0"",""_l"",""_d"",""_validRappelPoints"" 	]; 	 	_rappelPointsArray = []; 	_cornerPoints = [_vehicle] call AR_Get_Corner_Points; 	 	_frontLeftPoint = (((_cornerPoints # 2) vectorDiff (_cornerPoints # 3)) vectorMultiply 0.2) vectorAdd (_cornerPoints # 3); 	_frontRightPoint = (((_cornerPoints # 2) vectorDiff (_cornerPoints # 3)) vectorMultiply 0.8) vectorAdd (_cornerPoints # 3); 	_rearLeftPoint = (((_cornerPoints # 0) vectorDiff (_cornerPoints # 1)) vectorMultiply 0.2) vectorAdd (_cornerPoints # 1); 	_rearRightPoint = (((_cornerPoints # 0) vectorDiff (_cornerPoints # 1)) vectorMultiply 0.8) vectorAdd (_cornerPoints # 1); 	 	_rearLeftPointFinal = ((_frontLeftPoint vectorDiff _rearLeftPoint) vectorMultiply 0.2) vectorAdd _rearLeftPoint; 	_rearRightPointFinal = ((_frontRightPoint vectorDiff _rearRightPoint) vectorMultiply 0.2) vectorAdd _rearRightPoint; 	_frontLeftPointFinal = ((_rearLeftPoint vectorDiff _frontLeftPoint) vectorMultiply 0.2) vectorAdd _frontLeftPoint; 	_frontRightPointFinal = ((_rearRightPoint vectorDiff _frontRightPoint) vectorMultiply 0.2) vectorAdd _frontRightPoint; 	_middleLeftPointFinal = ((_frontLeftPointFinal vectorDiff _rearLeftPointFinal) vectorMultiply 0.5) vectorAdd _rearLeftPointFinal; 	_middleRightPointFinal = ((_frontRightPointFinal vectorDiff _rearRightPointFinal) vectorMultiply 0.5) vectorAdd _rearRightPointFinal;  	_vehicleUnitVectorUp = vectorNormalized (vectorUp _vehicle); 	 	_rappelPointHeightOffset = 0; 	{ 		if(_vehicle isKindOf (_x # 0)) then { 			_rappelPointHeightOffset = (_x # 1); 		}; 	} forEach AR_RAPPEL_POINT_CLASS_HEIGHT_OFFSET; 	 	_rappelPoints = []; 	{ 		_modelPoint = _x; 		_modelPointASL = _vehicle modelToWorldVisualWorld _modelPoint; 		_surfaceIntersectStartASL = _modelPointASL vectorAdd ( _vehicleUnitVectorUp vectorMultiply -5 ); 		_surfaceIntersectEndASL = _modelPointASL vectorAdd ( _vehicleUnitVectorUp vectorMultiply 5 );  		_la = ASLToAGL _surfaceIntersectStartASL; 		_lb = ASLToAGL _surfaceIntersectEndASL; 		 		if(_la # 2 < 0 && _lb # 2 > 0) then { 			_n = [0,0,1]; 			_p0 = [0,0,0.1]; 			_l = (_la vectorFromTo _lb); 			if((_l vectorDotProduct _n) != 0) then { 				_d = ( ( _p0 vectorAdd ( _la vectorMultiply -1 ) ) vectorDotProduct _n ) / (_l vectorDotProduct _n); 				_surfaceIntersectStartASL = AGLToASL ((_l vectorMultiply _d) vectorAdd _la); 			}; 		}; 		 		_surfaces = lineIntersectsSurfaces [_surfaceIntersectStartASL, _surfaceIntersectEndASL, objNull, objNull, true, 100]; 		_intersectionASL = []; 		{ 			_intersectionObject = _x # 2; 			if (_intersectionObject isEqualTo _vehicle) exitWith { 				_intersectionASL = _x # 0; 			}; 		} forEach _surfaces; 		if (_intersectionASL isNotEqualTo []) then { 			_intersectionASL = _intersectionASL vectorAdd (( _surfaceIntersectStartASL vectorFromTo _surfaceIntersectEndASL ) vectorMultiply (_rappelPointHeightOffset select (count _rappelPoints))); 			_rappelPoints pushBack (_vehicle worldToModelVisual (ASLToAGL _intersectionASL)); 		} else { 			_rappelPoints pushBack []; 		}; 	} forEach [_middleLeftPointFinal, _middleRightPointFinal, _frontLeftPointFinal, _frontRightPointFinal, _rearLeftPointFinal, _rearRightPointFinal];  	_validRappelPoints = []; 	{ 		if(count _x > 0 && count _validRappelPoints < missionNamespace getVariable [""AR_MAX_RAPPEL_POINTS_OVERRIDE"",6]) then { 			_validRappelPoints pushBack _x; 		}; 	} forEach _rappelPoints; 	 	_validRappelPoints; ";
/* Legacy Code as of 9.9.2026 */
//|AR_Rappel_From_Heli = compileFinal " 	params [""_player"",""_heli""]; 	if (isServer) then { 	 		if!(_player in _heli) exitWith {}; 		if(_player getVariable [""AR_Is_Rappelling"", false]) exitWith {};  		_rappelPoints = [_heli] call AR_Get_Heli_Rappel_Points; 		_rappelPointIndex = 0; 		{ 			_rappellingPlayer = _heli getVariable [""AR_Rappelling_Player_"" + str _rappelPointIndex,objNull]; 			if(isNull _rappellingPlayer) exitWith {}; 			_rappelPointIndex = _rappelPointIndex + 1; 		} forEach _rappelPoints;  		if ((count _rappelPoints) isEqualTo _rappelPointIndex) exitWith { 			if(isPlayer _player) then { 				[[""All rappel anchors in use. Please try again."", false],""AR_Hint"",_player] call AR_RemoteExec; 			}; 		}; 		 		_heli setVariable [""AR_Rappelling_Player_"" + str _rappelPointIndex,_player];  		_player setVariable [""AR_Is_Rappelling"",true,true];  		[_player,_heli,_rappelPoints # _rappelPointIndex] spawn AR_Client_Rappel_From_Heli;  		[_player, _heli, _rappelPointIndex] spawn { 			params [""_player"",""_heli"", ""_rappelPointIndex""]; 			for '_x' from 0 to 1 step 0 do { 				if(!alive _player) exitWith {}; 				if!(_player getVariable [""AR_Is_Rappelling"", false]) exitWith {}; 				sleep 2; 			}; 			_heli setVariable [""AR_Rappelling_Player_"" + str _rappelPointIndex, nil]; 		};  	} else { 		[_this,""AR_Rappel_From_Heli"",true] call AR_RemoteExecServer; 	}; ";
//|AR_Client_Rappel_From_Heli = compileFinal "
//|	params [""_player"",""_heli"",""_rappelPoint""];
// Updated Code
AR_Rappel_From_Heli = compileFinal {
params ['_player','_heli',['_requestOwner',2,[0]]];
if (isServer) then {
	private _fn_authorizedRequest = {
		if (_requestOwner <= 2) exitWith {TRUE};
        private _sender = (allPlayers select {((owner _x) isEqualTo _requestOwner) && {!(_x isKindOf 'HeadlessClient_F')}}) param [0,objNull];
        private _selfRequest = _player isEqualTo _sender;
        private _groupAIRequest = !isPlayer _player && {(owner _player) isEqualTo _requestOwner} &&
            {(group _player) isEqualTo (group _sender)} && {(leader _sender) isEqualTo _sender} &&
            {isNull (remoteControlled _player)} &&
            {isNull (_player getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])};
		!isNull _sender && {_sender in _heli} &&
            {_selfRequest || {_groupAIRequest}} &&
			{[_player,_heli] call AR_Rappel_From_Heli_Action_Check}
	};
    if (!(call _fn_authorizedRequest)) exitWith {};
    if (!alive _player || {!alive _heli} || {!(_player in _heli)}) exitWith {};
    if (_player getVariable ['AR_Is_Rappelling',FALSE]) exitWith {};
    private _rappelPoints = [_heli] call AR_Get_Heli_Rappel_Points;
    // AI_RAPPEL_RELEASE_GATE_BEGIN
    // Human rappelling retains its controls. Bulk AI try at most six free
    // anchors, so a landed soldier at one rope cannot starve another clear rope.
    private _bulkAI = !isPlayer _player && {isNull (remoteControlled _player)} &&
        {isNull (_player getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])} &&
        {_heli getVariable ['AR_Units_Rappelling',FALSE]};
    private _rappelPointIndex = -1;
    private _freeAnchors = 0;
    {
        private _available = isNull (_heli getVariable ['AR_Rappelling_Player_' + str _forEachIndex,objNull]);
        if (_available) then {_freeAnchors = _freeAnchors + 1;};
        if (_available && {!_bulkAI || {[_heli,_x] call AR_QS_AI_Rappel_Clear}}) exitWith {_rappelPointIndex = _forEachIndex;};
    } forEach (if (_bulkAI) then {_rappelPoints select [0,6]} else {_rappelPoints});
    if (_rappelPointIndex < 0) exitWith {
        // Only a fully blocked attempt before the first rope asks for fallback.
        if (_bulkAI && {_freeAnchors > 0} && {(_heli getVariable ['QS_AR_releaseState','']) isEqualTo 'WAITING'}) then {
            _heli setVariable ['QS_AR_releaseState','BLOCKED'];
        };
        if (isPlayer _player) then {[["All rappel anchors in use. Please try again.",FALSE],'AR_Hint',_player] call AR_RemoteExec;};
    };
    if (_bulkAI) then {_heli setVariable ['QS_AR_releaseState','RELEASED'];};
    // AI_RAPPEL_RELEASE_GATE_END
		private _sessionOwner = owner _player;
		private _clientSessionKey = ['',netId _player] select (_sessionOwner > 2);
		if (_sessionOwner > 2 && {_clientSessionKey in ['','0:0']}) exitWith {};
		private _serial = -1;
		private _claimed = FALSE;
		// Claim the passenger, anchor and globally unique generation in one server
		// transition. Client-published object variables never choose the serial.
		isNil {
			if (call _fn_authorizedRequest && {alive _player} && {alive _heli} && {_player in _heli} &&
				{!(_player getVariable ['AR_Is_Rappelling',FALSE])} &&
				{isNull (_heli getVariable ['AR_Rappelling_Player_' + str _rappelPointIndex,objNull])}) then {
				private _lastSerial = serverNamespace getVariable ['QS_AR_nextSerial',0];
				if (!(_lastSerial isEqualType 0) || {!finite _lastSerial} || {_lastSerial < 0}) then {_lastSerial = 0;};
				_serial = _lastSerial + 1;
				serverNamespace setVariable ['QS_AR_nextSerial',_serial];
				_heli setVariable ['AR_Rappelling_Player_' + str _rappelPointIndex,_player];
				_player setVariable ['AR_Is_Rappelling',TRUE,TRUE];
				_player setVariable ['AR_Rappelling_Vehicle',_heli,TRUE];
				_player setVariable ['QS_AR_serial',_serial,TRUE];
				if (_sessionOwner > 2) then {
					private _sessions = serverNamespace getVariable ['QS_AR_clientSessions',createHashMap];
					_sessions set [_clientSessionKey,[_player,_serial,_sessionOwner,_heli,diag_tickTime + 240,objNull,objNull,FALSE]];
					serverNamespace setVariable ['QS_AR_clientSessions',_sessions];
				};
				_claimed = TRUE;
			};
		};
		if (!_claimed) exitWith {};
		_heli setVariable ['QS_AR_anchorSerial_' + str _rappelPointIndex,_serial];  		[_player,_heli,_rappelPoints # _rappelPointIndex,_serial] spawn AR_Client_Rappel_From_Heli;  		[_player, _heli, _rappelPointIndex,_serial,_clientSessionKey] spawn { 			params ["_player","_heli", "_rappelPointIndex",'_serial','_clientSessionKey'];
            private _expires = diag_tickTime + 180; 			for '_x' from 0 to 1 step 0 do { 				if (!alive _player || {!alive _heli} ||
                    {(_player getVariable ['QS_AR_serial',-1]) isNotEqualTo _serial} ||
                    {!isPlayer _player && {diag_tickTime >= _expires}}) exitWith {}; 				if!(_player getVariable ["AR_Is_Rappelling", false]) exitWith {}; 				sleep 2; 			}; 			// RAPPEL_ANCHOR_RELEASE_BEGIN
            // A late old monitor must not release a reused anchor or a new rappel.
            if ((_player getVariable ['QS_AR_serial',-1]) isEqualTo _serial) then {
                _player setVariable ['AR_Is_Rappelling',false,true];
            };
            if (!isNil {_heli getVariable ('QS_AR_anchorSerial_' + str _rappelPointIndex)} &&
                {(_heli getVariable ('QS_AR_anchorSerial_' + str _rappelPointIndex)) isEqualTo _serial} &&
                {(_heli getVariable ['AR_Rappelling_Player_' + str _rappelPointIndex,objNull]) isEqualTo _player}) then {
                _heli setVariable ['AR_Rappelling_Player_' + str _rappelPointIndex,nil];
                _heli setVariable ['QS_AR_anchorSerial_' + str _rappelPointIndex,nil];
			};
			private _sessions = serverNamespace getVariable ['QS_AR_clientSessions',createHashMap];
			private _session = _sessions getOrDefault [_clientSessionKey,[]];
			if ((count _session) >= 2 && {(_session # 0) isEqualTo _player} && {(_session # 1) isEqualTo _serial}) then {
				_sessions deleteAt _clientSessionKey;
			};
            // RAPPEL_ANCHOR_RELEASE_END
                    };  	} else { 		[_this,"AR_Rappel_From_Heli",true] call AR_RemoteExecServer; 	};
};
AR_Client_Rappel_From_Heli = compileFinal {
params ["_player","_heli","_rappelPoint",['_serial',-1]];
    if (_serial < 0) then {_serial = _player getVariable ['QS_AR_serial',0];};
    // A server request can precede public-variable replication on the owner.
    // Wait briefly for its serial, then reject a cancelled or superseded request.
    if (local _player && {canSuspend}) then {
        private _syncBy = diag_tickTime + 2;
        waitUntil {uiSleep 0.05; !alive _player || {diag_tickTime >= _syncBy} ||
            {(_player getVariable ['QS_AR_serial',0]) >= _serial}};
    };
    if (!alive _player || {!alive _heli} ||
        {(_player getVariable ['QS_AR_serial',0]) isNotEqualTo _serial} ||
        {!(_player getVariable ['AR_Is_Rappelling',false])}) exitWith {};
// End Updated Code
	if (local _player) then {
		[_player] orderGetIn false;
		moveOut _player;
/* Legacy Code as of 9.9.2026 */
//|		waitUntil { vehicle _player isEqualTo _player};
// Updated Code
		// Failed dismounts used to hold this worker forever, before helper cleanup.
        private _exitBy = diag_tickTime + 10;
        waitUntil {uiSleep 0.05; isNull (objectParent _player) || {!alive _player} || {!alive _heli} || {!local _player} || {diag_tickTime >= _exitBy}};
        if (!alive _player || {!alive _heli} || {!local _player} || {!isNull (objectParent _player)}) exitWith {
            if ((_player getVariable ['QS_AR_serial',0]) isEqualTo _serial) then {_player setVariable ['AR_Is_Rappelling',false,true];};
        };
        private _expires = diag_tickTime + 180;
        private _fn_current = {
            local _player && {alive _player} && {alive _heli} &&
            {_player getVariable ['AR_Is_Rappelling',false]} &&
            {(_player getVariable ['QS_AR_serial',0]) isEqualTo _serial} &&
            {isPlayer _player || {diag_tickTime < _expires}}
        };
// End Updated Code
		_playerStartPosition = (_heli modelToWorldVisualWorld _rappelPoint) vectorAdd [
			-((((random 100)-50))/25),
			-((((random 100)-50))/25),
			-1
		];
		_player setPosWorld _playerStartPosition;
		_anchor = createVehicle ['Land_Can_V2_F',[(random 10),(random 10),(10 + (random 10))],[],0,'NONE'];
		_anchor allowDamage false;
		_anchor hideObject TRUE;
		[[_anchor,_player,_serial,_heli],'AR_Hide_Object_Global',TRUE] call AR_RemoteExecServer;
		_anchor disableCollisionWith _heli;
		_heli disableCollisionWith _anchor;
		[1,_anchor,[_heli,_rappelPoint]] call QS_fnc_eventAttach;
		_deviceType = 'B_UAV_01_F';
		_rappelDevice = createVehicle [_deviceType,[(random 10),(random 10),(10 + (random 10))],[],0,'NONE'];
		_rappelDevice allowDamage false;
		_rappelDevice hideObject TRUE;
		_rappelDevice hideObject TRUE;
		_rappelDevice hideObject TRUE;
		for '_x' from 0 to 1 step 1 do {
			[[_rappelDevice,_player,_serial,_heli],'AR_Hide_Object_Global',TRUE] call AR_RemoteExecServer;
		};
		_rappelDevice disableCollisionWith _heli;
		_heli disableCollisionWith _rappelDevice;
		if (canSuspend) then {
			uiSleep 0.01;
		};
/* Legacy Code as of 9.9.2026 */
//|		_rappelDevice setPosWorld ((getPosWorld player) vectorAdd [0,0,-1]);
// Updated Code
		_rappelDevice setPosWorld ((getPosWorld _player) vectorAdd [0,0,-1]);
// End Updated Code
		_bottomRopeLength = 60;
		_topRopeLength = 3;
		_topRope = ropeCreate [_rappelDevice, [0,0.15,0], _anchor, [0, 0, 0], _topRopeLength];
		_topRope allowDamage false;
// Added Code
        private _helpers = [_anchor,_rappelDevice,_topRope];
        _player setVariable ['QS_AR_helpers',[_serial,_helpers]];
        private _onDeleted = {
            params ['_unit'];
            private _record = _unit getVariable ['QS_AR_helpers',[]];
            if (_record isNotEqualTo []) then {
                private _objects = _record # 1;
                ropeDestroy (_objects # 2);
                deleteVehicle (_objects # 0); deleteVehicle (_objects # 1);
                _unit setVariable ['AR_Is_Rappelling',false,true];
            };
        };
        private _deletedEH = _player addEventHandler ['Deleted',_onDeleted];
        private _killedEH = _player addEventHandler ['Killed',_onDeleted];
// End Updated Code
		[_player] spawn AR_Enable_Rappelling_Animation_Client;
		_gravityAccelerationVec = [0,0,-9.8];
		_velocityVec = [0,0,0];
		_lastTime = diag_tickTime;
		_lastPosition = _rappelDevice modelToWorldVisualWorld [0,0,0];
		_lookDirFreedom = 50;
		_dir = (random 360) + (_lookDirFreedom / 2);
		_dirSpinFactor = (((random 10) - 5) / 5) max 0.1;
// Added Code
		private _ropeDisplay = findDisplay 46;
// End Updated Code
		_ropeKeyDownHandler = -1;
		_ropeKeyUpHandler = -1;
		if (_player isEqualTo player) then {
			_player setVariable ["AR_DECEND_PRESSED",false];
			_player setVariable ["AR_FAST_DECEND_PRESSED",false];
			_player setVariable ["AR_RANDOM_DECEND_SPEED_ADJUSTMENT",0];
/* Legacy Code as of 9.9.2026 */
//|			_ropeKeyDownHandler = (findDisplay 46) displayAddEventHandler [
// Updated Code
			_ropeKeyDownHandler = _ropeDisplay displayAddEventHandler [
// End Updated Code
				"KeyDown",
				{
					if(_this # 1 in (actionKeys "MoveBack")) then {
						player setVariable ["AR_DECEND_PRESSED",true];
					};
					if(_this # 1 in (actionKeys "Turbo")) then {
						player setVariable ["AR_FAST_DECEND_PRESSED",true];
					};
				}
			];
/* Legacy Code as of 9.9.2026 */
//|			_ropeKeyUpHandler = (findDisplay 46) displayAddEventHandler [
// Updated Code
			_ropeKeyUpHandler = _ropeDisplay displayAddEventHandler [
// End Updated Code
				"KeyUp",
				{
					if(_this # 1 in (actionKeys "MoveBack")) then {
						player setVariable ["AR_DECEND_PRESSED",false];
					};
					if(_this # 1 in (actionKeys "Turbo")) then {
						player setVariable ["AR_FAST_DECEND_PRESSED",false];
					};
				}
			];
		} else {
			_player setVariable ["AR_DECEND_PRESSED",false];
			_player setVariable ["AR_FAST_DECEND_PRESSED",false];
/* Legacy Code as of 9.9.2026 */
//|			_player setVariable ["AR_RANDOM_DECEND_SPEED_ADJUSTMENT",(random 2) - 1];
//|			[_player] spawn {
//|				params ["_player"];
//|				uiSleep 2;
//|				_player setVariable ["AR_DECEND_PRESSED",true];
// Updated Code
			_player setVariable ["AR_RANDOM_DECEND_SPEED_ADJUSTMENT",0];
			[_player,_serial] spawn {
                params ["_player",'_serial'];
                uiSleep 2;
                if ((_player getVariable ['QS_AR_serial',-1]) isEqualTo _serial && {_player getVariable ['AR_Is_Rappelling',false]}) then {
                    _player setVariable ["AR_DECEND_PRESSED",true];
                };
// End Updated Code
			};
		};
/* Legacy Code as of 9.9.2026 */
//|		_this spawn {
//|			params ["_player","_heli"];
//|			while {_player getVariable ["AR_Is_Rappelling", false]} do {
// Updated Code
		[_player,_heli,_serial] spawn {
			params ["_player","_heli","_serial"];
			while {alive _player && {alive _heli} && {_player getVariable ['AR_Is_Rappelling',false]} && {(_player getVariable ['QS_AR_serial',-1]) isEqualTo _serial}} do {
// End Updated Code
				if(speed _heli > 150) then {
					if(isPlayer _player) then {
						["Moving too fast! You've lost grip of the rope.", false] call AR_Hint;
					};
					[_player] call AR_Rappel_Detach_Action;
				};
				uiSleep 2;
			};
		};
		for '_x' from 0 to 1 step 0 do {
// Added Code
			if (!(call _fn_current)) exitWith {};
// End Updated Code
			_currentTime = diag_tickTime;
			_timeSinceLastUpdate = _currentTime - _lastTime;
			_lastTime = _currentTime;
			if (_timeSinceLastUpdate > 1) then {
				_timeSinceLastUpdate = 0;
			};
			_environmentWindVelocity = wind;
			_playerWindVelocity = _velocityVec vectorMultiply -1;
			_helicopterWindVelocity = (vectorUp _heli) vectorMultiply -30;
			_totalWindVelocity = _environmentWindVelocity vectorAdd _playerWindVelocity vectorAdd _helicopterWindVelocity;
			_totalWindForce = _totalWindVelocity vectorMultiply (9.8/53);
			_accelerationVec = _gravityAccelerationVec vectorAdd _totalWindForce;
			_velocityVec = _velocityVec vectorAdd ( _accelerationVec vectorMultiply _timeSinceLastUpdate );
			_newPosition = _lastPosition vectorAdd ( _velocityVec vectorMultiply _timeSinceLastUpdate );
			_heliPos = _heli modelToWorldVisualWorld _rappelPoint;
			if((_newPosition distance _heliPos) > _topRopeLength) then {
				_newPosition = (_heliPos) vectorAdd (( vectorNormalized ( (_heliPos) vectorFromTo _newPosition )) vectorMultiply _topRopeLength);
				_surfaceVector = ( vectorNormalized ( _newPosition vectorFromTo (_heliPos) ));
				_velocityVec = _velocityVec vectorAdd (( _surfaceVector vectorMultiply (_velocityVec vectorDotProduct _surfaceVector)) vectorMultiply -1);
			};
			_rappelDevice setPosWorld (_lastPosition vectorAdd ((_newPosition vectorDiff _lastPosition) vectorMultiply 6));
			_rappelDevice setVectorDir (vectorDir _player);
			_player setPosWorld (_newPosition vectorAdd [0,0,-0.6]);
			_player setVelocity [0,0,0];
			if(_player getVariable ["AR_DECEND_PRESSED",false]) then {
/* Legacy Code as of 9.9.2026 */
//|				_decendSpeedMetersPerSecond = 3.5;
// Updated Code
				// AI use the existing fast descent rate; player input remains unchanged.
				_decendSpeedMetersPerSecond = [5,3.5] select (isPlayer _player);
// End Updated Code
				if(_player getVariable ["AR_FAST_DECEND_PRESSED",false]) then {
					_decendSpeedMetersPerSecond = 5;
				};
				_decendSpeedMetersPerSecond = _decendSpeedMetersPerSecond + (_player getVariable ["AR_RANDOM_DECEND_SPEED_ADJUSTMENT",0]);
				_bottomRopeLength = _bottomRopeLength - (_timeSinceLastUpdate * _decendSpeedMetersPerSecond);
				_topRopeLength = _topRopeLength + (_timeSinceLastUpdate * _decendSpeedMetersPerSecond);
				ropeUnwind [_topRope, _decendSpeedMetersPerSecond, _topRopeLength - 0.5];
			};
			_dir = _dir + ((360/1000) * _dirSpinFactor);
			if(isPlayer _player) then {
				_currentDir = getDir _player;
				_minDir = (_dir - (_lookDirFreedom/2)) mod 360;
				_maxDir = (_dir + (_lookDirFreedom/2)) mod 360;
				_minDegreesToMax = 0;
				_minDegreesToMin = 0;
				if( _currentDir > _maxDir ) then {
					_minDegreesToMax = (_currentDir - _maxDir) min (360 - _currentDir + _maxDir);
				};
				if( _currentDir < _maxDir ) then {
					_minDegreesToMax = (_maxDir - _currentDir) min (360 - _maxDir + _currentDir);
				};
				if( _currentDir > _minDir ) then {
					_minDegreesToMin = (_currentDir - _minDir) min (360 - _currentDir + _minDir);
				};
				if( _currentDir < _minDir ) then {
					_minDegreesToMin = (_minDir - _currentDir) min (360 - _minDir + _currentDir);
				};
				if( _minDegreesToMin > _lookDirFreedom || _minDegreesToMax > _lookDirFreedom ) then {
					if( _minDegreesToMin < _minDegreesToMax ) then {
						_player setDir _minDir;
					} else {
						_player setDir _maxDir;
					};
				} else {
					_player setDir (_currentDir  + ((360/1000) * _dirSpinFactor));
				};
			} else {
				_player setDir _dir;
			};
			_lastPosition = _newPosition;
			if ( (((getPos _player) # 2) < 1) || (!((lifeState _player) in ['HEALTHY','INJURED'])) || ((vehicle _player) isNotEqualTo _player) || (_bottomRopeLength <= 1) || (_player getVariable ["AR_Detach_Rope",false]) ) exitWith {};
			uiSleep 0.01;
		};
/* Legacy Code as of 9.9.2026 */
//|		if ((_bottomRopeLength > 1) && ((lifeState _player) in ['HEALTHY','INJURED']) && ((vehicle _player) isEqualTo _player)) then {
// Updated Code
		if ((call _fn_current) && (_bottomRopeLength > 1) && ((lifeState _player) in ['HEALTHY','INJURED']) && ((vehicle _player) isEqualTo _player)) then {
// End Updated Code
			_playerStartASLIntersect = getPosASL _player;
			_playerEndASLIntersect = [_playerStartASLIntersect # 0, _playerStartASLIntersect # 1, (_playerStartASLIntersect # 2) - 5];
			_surfaces = lineIntersectsSurfaces [_playerStartASLIntersect, _playerEndASLIntersect, _player, objNull, true, 10];
			_intersectionASL = [];
			{
				scopeName "surfaceLoop";
				_intersectionObject = _x # 2;
				_objectFileName = str _intersectionObject;
				if((_objectFileName find " t_") isEqualTo -1 && (_objectFileName find " b_") isEqualTo -1) then {
					_intersectionASL = _x # 0;
					breakOut "surfaceLoop";
				};
			} forEach _surfaces;
			if (_intersectionASL isNotEqualTo []) then {
				_player allowDamage false;
				_player setPosASL _intersectionASL;
			};
			if(_player getVariable ["AR_Detach_Rope",false]) then {
				if (_intersectionASL isEqualTo []) then {
					_player allowDamage true;
				};
			};
			if(!isEngineOn _heli) then {
				_player allowDamage true;
			};
		};
/* Legacy Code as of 9.9.2026 */
//|		ropeDestroy _topRope;
// Updated Code
		// These handler IDs belong to this worker. A newer serial owns shared
		// state, but it does not own or replace these registrations.
		_player removeEventHandler ['Deleted',_deletedEH];
		_player removeEventHandler ['Killed',_killedEH];
        if (((_player getVariable ['QS_AR_helpers',[-1]]) # 0) isEqualTo _serial) then {_player setVariable ['QS_AR_helpers',nil];};
        ropeDestroy _topRope;
// End Updated Code
		deleteVehicle _anchor;
		deleteVehicle _rappelDevice;
/* Legacy Code as of 9.9.2026 */
//|		_player setVariable ["AR_Is_Rappelling",nil,true];
// Updated Code
		if ((_player getVariable ['QS_AR_serial',0]) isEqualTo _serial) then {
        _player setVariable ["AR_Is_Rappelling",nil,true];
// End Updated Code
		_player setVariable ["AR_Rappelling_Vehicle", nil, true];
		_player setVariable ["AR_Detach_Rope",nil];
// Added Code
        };
// End Updated Code
		if (_ropeKeyDownHandler isNotEqualTo -1) then {
/* Legacy Code as of 9.9.2026 */
//|			(findDisplay 46) displayRemoveEventHandler ["KeyDown", _ropeKeyDownHandler];
// Updated Code
			_ropeDisplay displayRemoveEventHandler ["KeyDown", _ropeKeyDownHandler];
// End Updated Code
		};
		if (_ropeKeyUpHandler isNotEqualTo -1) then {
/* Legacy Code as of 9.9.2026 */
//|			(findDisplay 46) displayRemoveEventHandler ["KeyUp", _ropeKeyUpHandler];
// Updated Code
			_ropeDisplay displayRemoveEventHandler ["KeyUp", _ropeKeyUpHandler];
// End Updated Code
		};
		uiSleep 2;
/* Legacy Code as of 9.9.2026 */
//|		_player allowDamage true;
// Updated Code
		if ((_player getVariable ['QS_AR_serial',0]) isEqualTo _serial) then {_player allowDamage true;};
// End Updated Code
	} else {
		[_this,"AR_Client_Rappel_From_Heli",_player] call AR_RemoteExec;
	};
};
AR_Enable_Rappelling_Animation = compileFinal " 	params [""_player""]; 	[75,[_player,TRUE],'AR_Enable_Rappelling_Animation_Client',FALSE] remoteExec ['QS_fnc_remoteExec',0,FALSE]; ";
AR_Current_Weapon_Type_Selected = compileFinal " 	params [""_player""]; 	if(currentWeapon _player isEqualTo handgunWeapon _player) exitWith {""HANDGUN""}; 	if(currentWeapon _player isEqualTo primaryWeapon _player) exitWith {""PRIMARY""}; 	if(currentWeapon _player isEqualTo secondaryWeapon _player) exitWith {""SECONDARY""}; 	""OTHER""; ";
/* Legacy Code as of 9.9.2026 */
//|AR_Enable_Rappelling_Animation_Client = compileFinal " 	params [""_player"",[""_globalExec"",false]]; 	 	if(local _player && _globalExec) exitWith {}; 	 	if(local _player && !_globalExec) then { 		[[_player],""AR_Enable_Rappelling_Animation""] call AR_RemoteExecServer; 	};  	if (_player isNotEqualTo player) then { 		_player enableSimulation false; 	}; 	 	if(call AR_Has_Addon_Animations_Installed) then {		 		if([_player] call AR_Current_Weapon_Type_Selected isEqualTo ""HANDGUN"") then { 			if(local _player) then { 				if(missionNamespace getVariable [""AR_DISABLE_SHOOTING_OVERRIDE"",false]) then { 					_player switchMove ""AR_01_Idle_Pistol_No_Actions""; 				} else { 					_player switchMove ""AR_01_Idle_Pistol""; 				}; 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_Pistol_No_Actions"",true]; 			} else { 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_Pistol_No_Actions""];			 			}; 		} else { 			if(local _player) then { 				if(missionNamespace getVariable [""AR_DISABLE_SHOOTING_OVERRIDE"",false]) then { 					_player switchMove ""AR_01_Idle_No_Actions""; 				} else { 					_player switchMove ""AR_01_Idle""; 				}; 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_No_Actions"",true]; 			} else { 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_No_Actions""]; 			}; 		}; 		if!(local _player) then {  			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 			sleep 1; 			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 			sleep 1; 			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 			sleep 1; 			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 		}; 	} else { 		if(local _player) then { 			_player switchMove ""HubSittingChairC_idle1""; 			_player setVariable [""AR_Animation_Move"",""HubSittingChairC_idle1"",true]; 		} else { 			_player setVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""];		 		}; 	};  	_animationEventHandler = -1; 	if(local _player) then { 		_animationEventHandler = _player addEventHandler [""AnimChanged"",{ 			params [""_player"",""_animation""]; 			if(call AR_Has_Addon_Animations_Installed) then { 				if((toLowerANSI _animation) find ""ar_"" < 0) then { 					if([_player] call AR_Current_Weapon_Type_Selected isEqualTo ""HANDGUN"") then { 						_player switchMove ""AR_01_Aim_Pistol""; 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_Pistol_No_Actions"",true]; 					} else { 						_player switchMove ""AR_01_Aim""; 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_No_Actions"",true]; 					}; 				} else { 					if(toLowerANSI _animation isEqualTo ""ar_01_aim"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_No_Actions"",true]; 					}; 					if(toLowerANSI _animation isEqualTo ""ar_01_idle"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Idle_No_Actions"",true]; 					}; 					if(toLowerANSI _animation isEqualTo ""ar_01_aim_pistol"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_Pistol_No_Actions"",true]; 					}; 					if(toLowerANSI _animation isEqualTo ""ar_01_idle_pistol"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Idle_Pistol_No_Actions"",true]; 					}; 				}; 			} else { 				_player switchMove ""HubSittingChairC_idle1""; 				_player setVariable [""AR_Animation_Move"",""HubSittingChairC_idle1"",true]; 			}; 		}]; 	}; 	 	if(!local _player) then { 		[_player] spawn { 			params [""_player""]; 			private [""_currentState""]; 			while {_player getVariable [""AR_Is_Rappelling"",false]} do { 				_currentState = toLowerANSI animationState _player; 				_newState = toLowerANSI (_player getVariable [""AR_Animation_Move"",""""]); 				if!(call AR_Has_Addon_Animations_Installed) then { 					_newState = ""HubSittingChairC_idle1""; 				}; 				if(_currentState != _newState) then { 					_player switchMove _newState; 					_player switchGesture """"; 					sleep 1; 					_player switchMove _newState; 					_player switchGesture """"; 				}; 				sleep 0.1; 			};			 		}; 	}; 	 	waitUntil {!(_player getVariable [""AR_Is_Rappelling"",false])}; 	 	if (_animationEventHandler isNotEqualTo -1) then { 		_player removeEventHandler [""AnimChanged"", _animationEventHandler]; 	}; 	 	_player switchMove """";	 	_player enableSimulation true; 	 ";
// Updated Code
AR_Enable_Rappelling_Animation_Client = compileFinal "
params [""_player"",[""_globalExec"",false]];
        private _serial = _player getVariable ['QS_AR_serial',0];
        if (!alive _player || {!(_player getVariable ['AR_Is_Rappelling',false])}) exitWith {}; 	 	if(local _player && _globalExec) exitWith {}; 	 	if(local _player && !_globalExec) then { 		[[_player],""AR_Enable_Rappelling_Animation""] call AR_RemoteExecServer; 	};  	if (_player isNotEqualTo player) then { 		_player enableSimulation false; 	}; 	 	if(call AR_Has_Addon_Animations_Installed) then {		 		if([_player] call AR_Current_Weapon_Type_Selected isEqualTo ""HANDGUN"") then { 			if(local _player) then { 				if(missionNamespace getVariable [""AR_DISABLE_SHOOTING_OVERRIDE"",false]) then { 					_player switchMove ""AR_01_Idle_Pistol_No_Actions""; 				} else { 					_player switchMove ""AR_01_Idle_Pistol""; 				}; 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_Pistol_No_Actions"",true]; 			} else { 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_Pistol_No_Actions""];			 			}; 		} else { 			if(local _player) then { 				if(missionNamespace getVariable [""AR_DISABLE_SHOOTING_OVERRIDE"",false]) then { 					_player switchMove ""AR_01_Idle_No_Actions""; 				} else { 					_player switchMove ""AR_01_Idle""; 				}; 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_No_Actions"",true]; 			} else { 				_player setVariable [""AR_Animation_Move"",""AR_01_Idle_No_Actions""]; 			}; 		}; 		if!(local _player) then {  			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 			sleep 1; 			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 			sleep 1; 			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 			sleep 1; 			_player switchMove (_player getVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""]); 		}; 	} else { 		if(local _player) then { 			_player switchMove ""HubSittingChairC_idle1""; 			_player setVariable [""AR_Animation_Move"",""HubSittingChairC_idle1"",true]; 		} else { 			_player setVariable [""AR_Animation_Move"",""HubSittingChairC_idle1""];		 		}; 	};  	_animationEventHandler = -1; 	if(local _player) then { 		_animationEventHandler = _player addEventHandler [""AnimChanged"",{ 			params [""_player"",""_animation""]; 			if(call AR_Has_Addon_Animations_Installed) then { 				if((toLowerANSI _animation) find ""ar_"" < 0) then { 					if([_player] call AR_Current_Weapon_Type_Selected isEqualTo ""HANDGUN"") then { 						_player switchMove ""AR_01_Aim_Pistol""; 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_Pistol_No_Actions"",true]; 					} else { 						_player switchMove ""AR_01_Aim""; 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_No_Actions"",true]; 					}; 				} else { 					if(toLowerANSI _animation isEqualTo ""ar_01_aim"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_No_Actions"",true]; 					}; 					if(toLowerANSI _animation isEqualTo ""ar_01_idle"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Idle_No_Actions"",true]; 					}; 					if(toLowerANSI _animation isEqualTo ""ar_01_aim_pistol"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Aim_Pistol_No_Actions"",true]; 					}; 					if(toLowerANSI _animation isEqualTo ""ar_01_idle_pistol"") then { 						_player setVariable [""AR_Animation_Move"",""AR_01_Idle_Pistol_No_Actions"",true]; 					}; 				}; 			} else { 				_player switchMove ""HubSittingChairC_idle1""; 				_player setVariable [""AR_Animation_Move"",""HubSittingChairC_idle1"",true]; 			}; 		}]; 	}; 	 	if(!local _player) then { 		[_player,_serial] spawn { 			params [""_player"",""_serial""]; 			private [""_currentState""]; 			while {alive _player && {_player getVariable ['AR_Is_Rappelling',false]} && {(_player getVariable ['QS_AR_serial',0]) isEqualTo _serial}} do { 				_currentState = toLowerANSI animationState _player; 				_newState = toLowerANSI (_player getVariable [""AR_Animation_Move"",""""]); 				if!(call AR_Has_Addon_Animations_Installed) then { 					_newState = ""HubSittingChairC_idle1""; 				}; 				if(_currentState != _newState) then { 					_player switchMove _newState; 					_player switchGesture """"; 					sleep 1; 					_player switchMove _newState; 					_player switchGesture """"; 				}; 				sleep 0.1; 			};			 		}; 	}; 	 	waitUntil {uiSleep 0.1; !alive _player || {!(_player getVariable ['AR_Is_Rappelling',false])} || {(_player getVariable ['QS_AR_serial',0]) isNotEqualTo _serial}};
        if (_animationEventHandler isNotEqualTo -1) then { 		_player removeEventHandler [""AnimChanged"", _animationEventHandler]; 	}; 	 	if ((_player getVariable ['QS_AR_serial',0]) isNotEqualTo _serial) exitWith {};
        _player switchMove """";	 	_player enableSimulation true;
";
// End Updated Code
AR_Rappel_Detach_Action = compileFinal " 	params [""_player""]; 	_player setVariable [""AR_Detach_Rope"",true]; ";
AR_Rappel_Detach_Action_Check = compileFinal " 	params [""_player""]; 	if!(_player getVariable [""AR_Is_Rappelling"",false]) exitWith {false;}; 	true; ";
AR_Rappel_From_Heli_Action = compileFinal " 	params [""_player"",""_vehicle""];	 	if([_player, _vehicle] call AR_Rappel_From_Heli_Action_Check) then { 		[_player, _vehicle] call AR_Rappel_From_Heli; 	}; ";
// The server may see a remote occupant before assignedVehicleRole catches up;
// fullCrew supplies the authoritative occupied role for the security recheck.
AR_Rappel_From_Heli_Action_Check = compileFinal "
	params ['_player','_vehicle'];
	private _c = FALSE;
	private _role = assignedVehicleRole _player;
	if (_role isEqualTo [] && {_player in _vehicle}) then {
		private _crewSlot = ((fullCrew _vehicle) select {(_x # 0) isEqualTo _player}) param [0,[]];
		if ((count _crewSlot) >= 4) then {
			_role = [_crewSlot # 1];
			if ((toLowerANSI (_crewSlot # 1)) isEqualTo 'turret') then {_role pushBack (_crewSlot # 3);};
		};
	};
	private _roleName = toLowerANSI (_role param [0,'',['']]);
	if ([_vehicle] call AR_Is_Supported_Vehicle) then {
		if (_player isNotEqualTo (currentPilot _vehicle)) then {
			private _vehPos = getPosWorld _vehicle;
			if (surfaceIsWater _vehPos) then {
				_vehPos = getPosASL _vehicle;
			} else {
				_vehPos = getPosATL _vehicle;
			};
			if (
				(!(_vehicle getVariable ['QS_rappellSafety',FALSE])) &&
				{((_vehPos # 2) < 55)} &&
				{((_vehPos # 2) > 5)} &&
				{((lineIntersectsSurfaces [(_vehicle modelToWorldWorld [0,0,-1]),(_vehicle modelToWorldWorld [0,0,-6]),_vehicle,objNull,TRUE,-1,'GEOM','ROADWAY',TRUE]) isEqualTo [])} &&
				{(((vectorMagnitude (velocity _vehicle)) * 3.6) < 35)} &&
				{_roleName in ['cargo','turret']}
			) then {
				if ((count _role) > 1) then {
					if (!((_roleName isEqualTo 'turret') && {((_role # 1) param [0,0]) < 1})) then {
						_c = TRUE;
					};
				} else {
					_c = TRUE;
				};
			};
		};
	};
	_c;
";
AR_Rappel_AI_Units_From_Heli_Action_Check = compileFinal " 	params [""_player""]; 	if((leader _player) != _player) exitWith {false}; 	_canRappelOne = false; 	{ 		if(((vehicle _x) != _x) && (!isPlayer _x)) then { 			if([_x, vehicle _x] call AR_Rappel_From_Heli_Action_Check) then { 				_canRappelOne = true; 			}; 		}; 	} forEach (units _player); 	_canRappelOne; ";
AR_Get_Corner_Points = compileFinal " 	params [""_vehicle""]; 	private [""_centerOfMass"",""_bbr"",""_p1"",""_p2"",""_rearCorner"",""_rearCorner2"",""_frontCorner"",""_frontCorner2""]; 	private [""_maxWidth"",""_widthOffset"",""_maxLength"",""_lengthOffset"",""_widthFactor"",""_lengthFactor"",""_maxHeight"",""_heightOffset""]; 	 	_widthFactor = 0.5; 	_lengthFactor = 0.5; 	if(_vehicle isKindOf ""Air"") then { 		_widthFactor = 0.3; 	}; 	if(_vehicle isKindOf ""Helicopter"") then { 		_widthFactor = 0.2; 		_lengthFactor = 0.45; 	}; 	 	_centerOfMass = getCenterOfMass _vehicle; 	_bbr = boundingBoxReal _vehicle; 	_p1 = _bbr # 0; 	_p2 = _bbr # 1; 	_maxWidth = abs ((_p2 # 0) - (_p1 # 0)); 	_widthOffset = ((_maxWidth / 2) - abs ( _centerOfMass # 0 )) * _widthFactor; 	_maxLength = abs ((_p2 # 1) - (_p1 # 1)); 	_lengthOffset = ((_maxLength / 2) - abs (_centerOfMass # 1 )) * _lengthFactor; 	_maxHeight = abs ((_p2 # 2) - (_p1 # 2)); 	_heightOffset = _maxHeight/6; 	 	_rearCorner = [(_centerOfMass # 0) + _widthOffset, (_centerOfMass # 1) - _lengthOffset, (_centerOfMass # 2)+_heightOffset]; 	_rearCorner2 = [(_centerOfMass # 0) - _widthOffset, (_centerOfMass # 1) - _lengthOffset, (_centerOfMass # 2)+_heightOffset]; 	_frontCorner = [(_centerOfMass # 0) + _widthOffset, (_centerOfMass # 1) + _lengthOffset, (_centerOfMass # 2)+_heightOffset]; 	_frontCorner2 = [(_centerOfMass # 0) - _widthOffset, (_centerOfMass # 1) + _lengthOffset, (_centerOfMass # 2)+_heightOffset]; 	 	[_rearCorner,_rearCorner2,_frontCorner,_frontCorner2]; "; /*/"VTOL_Base_F"/*/
AR_SUPPORTED_VEHICLES = [ 	"Helicopter" ];
AR_Is_Supported_Vehicle = compileFinal " 	params [""_vehicle"",""_isSupported""]; 	_isSupported = false; 	if(not isNull _vehicle) then { 		{ 			if(_vehicle isKindOf _x) then { 				_isSupported = true; 			}; 		} forEach (missionNamespace getVariable [""AR_SUPPORTED_VEHICLES_OVERRIDE"",AR_SUPPORTED_VEHICLES]); 	}; 	_isSupported; ";
AR_Hint = compileFinal "
	params ['_msg',['_isSuccess',true]];
	hint _msg;
";
AR_Hide_Object_Global = compileFinal "
	params ['_obj','_unit','_serial','_heli'];
	if((_obj isKindOf 'Land_Can_V2_F') || {(_obj isKindOf 'B_static_AA_F')} || {(_obj isKindOf 'B_UAV_01_F')}) then {
		for '_x' from 0 to 2 step 1 do {
			_obj hideObject TRUE;
			_obj hideObjectGlobal TRUE;
		};
		if (!isNull _heli) then {
			[65,_obj,_heli,FALSE,[0,101] select (_obj isKindOf 'B_UAV_01_F')] remoteExecCall ['QS_fnc_remoteExec',0,FALSE];
		};
	};
";
AR_RemoteExec = compileFinal "
	params ['_params','_functionName','_target',['_isCall',false]];
	[75,_params,_functionName,_isCall] remoteExecCall ['QS_fnc_remoteExec',_target];
";
AR_RemoteExecServer = compileFinal "
	params ['_params','_functionName',['_isCall',false]];
	[75,_params,_functionName,_isCall] remoteExecCall ['QS_fnc_remoteExec',2];
";
