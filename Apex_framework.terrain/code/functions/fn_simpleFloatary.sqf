/* Initializes Simple Floatary on the server and on each interface client. */
if (isServer) then {
  if !(isNil "isFloataryAllowedServer") exitWith {}; 
  isFloataryAllowedServer = true; 
 
  FLRYLeakiness = 0.1; 
 
  comment "any helicopter bigger than this will float"; 
  FLRYFloatLowerSizeThreshold = 24; 
 
  comment "any aircraft bigger than this will float"; 
  FLRYFloatUpperSizeThreshold = 24.75; 
 
  comment "any ship smaller than this can be carried"; 
  FLRYShipSizeThreshold = 10; 
 
  FLRYAllWatercraftCarrierClassNames = [ 
   "O_Heli_Transport_04_covered_F", 
   "I_Heli_Transport_02_F", 
   "B_Heli_Transport_03_F", 
   "B_Heli_Transport_03_unarmed_F", 
   "B_T_VTOL_01_infantry_F", 
   "B_T_VTOL_01_vehicle_F", 
   "C_IDAP_Heli_Transport_02_F", 
   "O_T_VTOL_02_infantry_F", 
   "O_T_VTOL_02_vehicle_F" 
  ]; 
 
  FLRYAllAircraftOffsets = [ 
   ["O_Heli_Transport_04_covered_F",[0,0.75,-0.75]], 
   ["I_Heli_Transport_02_F",[0,0.75,-0.75]], 
   ["B_Heli_Transport_03_F",[0,0.75,-0.75]], 
   ["B_Heli_Transport_03_unarmed_F",[0,0.75,-0.75]], 
   ["B_T_VTOL_01_infantry_F",[0,0.75,-2.65]], 
   ["B_T_VTOL_01_vehicle_F",[0,0.75,-2.65]], 
   ["O_T_VTOL_02_infantry_F",[0,0.5,-0.75]], 
   ["O_T_VTOL_02_vehicle_F",[0,0.5,-0.75]] 
  ]; 
 
  publicVariable "FLRYFloatLowerSizeThreshold"; 
  publicVariable "FLRYFloatUpperSizeThreshold"; 
  publicVariable "FLRYShipSizeThreshold"; 
  publicVariable "FLRYAllWatercraftCarrierClassNames"; 
  publicVariable "FLRYAllAircraftOffsets"; 
 
  FLRY_fnc_getIsValidAircraft = { 
   params ["_entity"]; 
   if !(_entity isKindOf "Air") exitWith {false}; 
   private _size = sizeOf typeOf _entity; 
   if (_size < FLRYFloatLowerSizeThreshold) exitWith {false}; 
   if (_entity isKindOf "Plane" && !(_size >= FLRYFloatUpperSizeThreshold)) exitWith {false}; 
   true 
  }; 
 
  publicVariable "FLRY_fnc_getIsValidAircraft"; 
 
  FLRY_fnc_getIsValidShip = { 
   params ["_ship",["_isPlane",false]]; 
   if !(_ship isKindOf "Ship") exitWith {false}; 
   private _size = sizeOf typeOf _ship; 
   if (_isPlane && ((sizeOf typeOf _ship) < 15)) exitWith {true}; 
   if (_size > FLRYShipSizeThreshold) exitWith {false}; 
   true 
  }; 
 
  publicVariable "FLRY_fnc_getIsValidShip"; 
 
  comment "Set leakiness when created"; 
  FLRYCreatedEvent = addMissionEventHandler ["EntityCreated", { 
   params ["_entity"]; 
 
   if !([_entity] call FLRY_fnc_getIsValidAircraft) exitWith {}; 
 
   [_entity,FLRYLeakiness] remoteExec ["setWaterLeakiness",owner _entity]; 
   [_entity] remoteExec ["QS_fnc_simpleFloataryAddActions",-2]; 
  }]; 
 
  comment "Set leakiness on existing vehicles"; 
  { 
   if !([_x] call FLRY_fnc_getIsValidAircraft) then {continue}; 
   [_x,FLRYLeakiness] remoteExec ["setWaterLeakiness",owner _x]; 
  } foreach vehicles; 
};

if (hasInterface) then {
  if (isMultiplayer) then {waitUntil {sleep 0.1; getClientState isEqualTo "BRIEFING READ"};}; 
  if !(isNil "isFloataryAllowed") exitWith {}; 
  isFloataryAllowed = true; 
 
  waitUntil {!isNil "FLRYFloatLowerSizeThreshold"}; 
  waitUntil {!isNil "FLRYFloatUpperSizeThreshold"}; 
  waitUntil {!isNil "FLRYAllWatercraftCarrierClassNames"}; 
  waitUntil {!isNil "FLRYShipSizeThreshold"}; 
  waitUntil {!isNil "FLRY_fnc_getIsValidAircraft"}; 
  waitUntil {!isNil "FLRY_fnc_getIsValidShip"}; 
  waitUntil {!isNil "FLRYAllAircraftOffsets"}; 
 
  FLRY_fnc_getAircraftOffset = { 
   params["_aircraft"]; 
    
   private _offset = [0,0,0]; 
   { 
    if (typeOf _aircraft isEqualTo (_x select 0)) exitWith {_offset = _x select 1;}; 
   } forEach FLRYAllAircraftOffsets; 
   _offset 
  }; 
 
  FLRY_fnc_getAttachedBoat = { 
   params["_vehicle"]; 
 
   private _boat = objNull; 
   private _isPlane = _vehicle isKindOf "Plane"; 
   { 
    if ([_x,_isPlane] call FLRY_fnc_getIsValidShip) exitWith {_boat = _x;}; 
   } foreach attachedObjects _vehicle; 
   _boat 
  }; 
 
  FLRY_fnc_attachWatercraft = { 
   params["_watercraft","_aircraft"]; 
 
   private _isPlane = _aircraft isKindOf "Plane"; 
   if !([_watercraft,_isPlane] call FLRY_fnc_getIsValidShip) exitWith {false}; 
   if !([_aircraft] call FLRY_fnc_getIsValidAircraft) exitWith {false}; 
   private _offset = [_aircraft] call FLRY_fnc_getAircraftOffset; 
   _watercraft attachto [_aircraft,_offset]; 
   playSound3D ["A3\sounds_f\structures\doors\servodoors\ServoDoorsSqueak_1.wss",_aircraft,false,getPosASL _aircraft,5,1,100]; 
   true 
  }; 
 
  FLRY_fnc_detachWatercraft = { 
   params["_aircraft"]; 
 
   if !([_aircraft] call FLRY_fnc_getIsValidAircraft) exitWith {false}; 
   private _watercraft = [_aircraft] call FLRY_fnc_getAttachedBoat; 
   private _distance = if (_aircraft isKindOf "Plane") then {15} else {10}; 
   private _newPos = (_aircraft getpos [_distance,(getdir _aircraft)+180]); 
   _newPos set [2,(getPosASL _aircraft) select 2]; 
   detach _watercraft; 
   _watercraft setPosASL _newPos; 
   _watercraft setDir (getDir _aircraft + 180); 
   playSound3D ["A3\sounds_f\structures\doors\servodoors\ServoDoorsSqueak_3.wss",_aircraft,false,getPosASL _aircraft,5,1,100]; 
   true 
  }; 
 
  FLRY_fnc_getIsBehindAircraft = { 
   params["_location","_aircraft"]; 
 
   private _relDir = _aircraft getRelDir _location; 
 
   if (_relDir < 160  || _relDir > 200) exitWith {false}; 
   true 
  }; 
 
  comment "add actions to existing vehicles locally"; 
  { 
   if !([_x] call FLRY_fnc_getIsValidAircraft) then {continue}; 
   [_x] call QS_fnc_simpleFloataryAddActions; 
  } foreach vehicles; 
};
