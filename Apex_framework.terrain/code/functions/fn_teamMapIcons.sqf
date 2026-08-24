SLT_fnc_RE_Server = { params ["_arguments","_code"]; _varName = ("SLT" + str (round random 10000)); TempCode = compile ("if(!isServer) exitWith{};_this call " + str _code + "; " + (_varName + " = nil;")); TempArgs = _arguments; call compile (_varName + " = [TempArgs,TempCode]; publicVariable '" + _varName + "'; [[], {(" + _varName + " select 0) spawn (" + _varName + " select 1);}] remoteExec ['spawn',2];"); };

with uiNamespace do {SLTScriptDisplayName = "Team Map Icons";}; 
 
SLT_fnc_enableScript = { 
  [] spawn  
  { 
   if(!hasInterface) exitWith {}; 
   if (!isNil "TeamMapEvent") exitWith {}; 
   if(isMultiplayer) then {waitUntil{getClientState isEqualTo "BRIEFING READ"};}; 
   sleep 1; 
   waitUntil {sleep 0.1; !((findDisplay 12 displayCtrl 51) isEqualTo controlNull)}; 
   disableMapIndicators [true,false,false,false]; 
 
   with uiNamespace do  
   { 
    TMIMaxCursorRangeUnitMarker = 0.02; 
    TMIMinMapZoomUnitMarker = 0.0500; 
 
    comment "[location,direction,isOnFoot,lifetime]"; 
    TMIAllMapTrails = []; 
    TMITrailLifetime = 30; 
    TMITrailDistance = 10; 
    TMIMaxAlpha = 0.5; 
    TMITrailSize = 1; 
 
    TMI_fnc_mapTrailTick = { 
 
     comment "Add new trails"; 
     private _unit = player; 
 
     private _lastTrailLocation = _unit getVariable "TMILastTrailLocation"; 
 
     if (isNil "_lastTrailLocation") then  
     { 
      _unit setVariable ["TMILastTrailLocation",(_unit modelToWorldVisual [0,0,0])]; 
      _lastTrailLocation = (_unit modelToWorldVisual [0,0,0]); 
     }; 
 
     private _currentLocation = (_unit modelToWorldVisual [0,0,0]); 
     private _dist = _lastTrailLocation distance2D _currentLocation; 
 
     if (_dist >= TMITrailDistance) then  
     { 
      TMIAllMapTrails pushBack [_lastTrailLocation,getdir _unit,vehicle _unit isEqualTo _unit,TMITrailLifetime]; 
      _unit setVariable ["TMILastTrailLocation",_currentLocation]; 
     }; 
 
     private _updatedTrails = TMIAllMapTrails; 
     { 
      private _location = _x select 0; 
      private _direction = _x select 1; 
      private _isOnFoot = _x select 2; 
      private _timeLeft = _x select 3; 
 
      comment "Update trails data"; 
      _updatedTrails set [_forEachIndex,[_location,_direction,_isOnFoot,_timeleft-diag_deltaTime]]; 
      if (_timeLeft <= 0) then {_updatedTrails deleteAt _forEachIndex;}; 
     } foreach TMIAllMapTrails; 
 
     TMIAllMapTrails = _updatedTrails; 
    }; 
 
    TMI_fnc_mapTrailDraw = { 
     { 
      private _location = _x select 0; 
      private _direction = _x select 1; 
      private _isOnFoot = _x select 2; 
      private _timeLeft = _x select 3; 
      private _alpha = linearConversion [0, 1, (_timeLeft/TMITrailLifetime), 0, TMIMaxAlpha, true]; 
      private _color = [1,1,1,_alpha]; 
      private _scale = 6.4 * worldSize / 8192 * ctrlMapScale (findDisplay 12 displayCtrl 51); 
      private _size = (TMITrailSize) / _scale; 
      private _iconFile = if (_isOnFoot)  
      then {"\a3\ui_f\data\igui\cfg\simpletasks\types\walk_ca.paa"}  
      else {"\a3\ui_f_curator\data\cfgcurator\entity_selected_ca.paa"}; 
 
      (findDisplay 12 displayCtrl 51) drawIcon 
      [ 
       _iconFile, 
       _color, 
       _location, 
       _size, 
       _size, 
       _direction-10, 
       "", 
       0 
      ]; 
     } foreach TMIAllMapTrails; 
    }; 
   }; 

   TMISelectedVehicle = objNull;
   TMIVisibleVehicleIcons = [];
 
   TeamMapMissionEvent = addMissionEventHandler ["EachFrame",{ 
    with uiNamespace do {call TMI_fnc_mapTrailTick;}; 
   }]; 

   TMI_fnc_getUnitRole = {
    params ["_unit"];
    if (isNull _unit) exitWith {""};
    if (isPlayer _unit) exitWith {
     private _roleName = _unit getVariable ["QS_unit_role_displayName",-1];
     if (_roleName isEqualType "") then {
      _roleName
     } else {
      ["GET_ROLE_DISPLAYNAME",_unit getVariable ["QS_unit_role","rifleman"]] call (missionNamespace getVariable "QS_fnc_roles")
     }
    };
    getText ((configOf _unit) >> "displayName")
   };

   TMI_fnc_getUnitRoleIcon = {
    params ["_unit"];
    if (isPlayer _unit) exitWith {
     private _roleIcon = _unit getVariable ["QS_unit_role_icon",-1];
     if (_roleIcon isEqualTo -1) then {
      _roleIcon = [
       "GET_ROLE_ICONMAP",
       _unit getVariable ["QS_unit_role","rifleman"],
       _unit
      ] call (missionNamespace getVariable "QS_fnc_roles");
     };
     _roleIcon
    };

    private _classId = toLowerANSI typeOf _unit;
    private _containsAny = {
     ((_this findIf {(_classId find _x) isNotEqualTo -1}) isNotEqualTo -1)
    };
    private _inferredRole = _unit getVariable ["QS_unit_role",""];
    if (_inferredRole isEqualTo "") then {
     _inferredRole = switch (true) do {
      case (["medic"] call _containsAny): {"medic"};
      case (["helipilot","helicrew","heli_pilot","heli_crew"] call _containsAny): {"pilot_heli"};
      case (["pilot"] call _containsAny): {"pilot_plane"};
      case (["_uav_","uavoperator","uav_operator"] call _containsAny): {"uav"};
      case (["mortar","support_mort","_mort_"] call _containsAny): {"mortar_gunner"};
      case (["jtac","recon_jtac","_jfo_"] call _containsAny): {"jtac"};
      case (["sniper","spotter"] call _containsAny): {"sniper"};
      case (["autorifleman","_soldier_ar_","_ar_"] call _containsAny): {"autorifleman"};
      case (["machinegunner","heavygunner","_soldier_mg_","_mg_"] call _containsAny): {"machine_gunner"};
      case (["_soldier_aa_","_aa_"] call _containsAny): {"rifleman_aa"};
      case (["_soldier_at_","riflemanat","_hat_"] call _containsAny): {"rifleman_hat"};
      case (["_soldier_lat_","riflemanlat","_lat_"] call _containsAny): {"rifleman_lat"};
      case (["engineer","_repair_","_exp_","explosive","demolition"] call _containsAny): {"engineer"};
      case (["commander","crew","officer","squadleader","teamleader","_sl_","_tl_"] call _containsAny): {"commander"};
      default {"rifleman"};
     };
    };

    private _cachedRoleIcon = _unit getVariable ["TMI_AI_roleIconCache",[]];
    if ((count _cachedRoleIcon) isEqualTo 2 && {(_cachedRoleIcon # 0) isEqualTo _inferredRole}) exitWith {
     _cachedRoleIcon # 1
    };
    private _roleIcon = [
     "GET_ROLE_ICONMAP",
     _inferredRole,
     objNull
    ] call (missionNamespace getVariable "QS_fnc_roles");
    _unit setVariable ["TMI_AI_roleIconCache",[_inferredRole,_roleIcon],false];
    _roleIcon
   };
    
   TMI_fnc_drawUnitIcons = {
    params ["_mapControl",["_showText",true]];
    private _scale = 0;
    private _dist = 0;
    if (_showText) then {TMIVisibleVehicleIcons = [];};
    _vehicleList = []; 
    {  
     if((side group _x) isEqualTo (side group player)) then 
     { 
      _pos = _x modelToWorldVisual [0,0,0]; 
      _driver = if (driver vehicle _x isEqualTo objNull) then {effectiveCommander vehicle _x} else {driver vehicle _x}; 
      if (isNull _driver) then {_driver = _x;};
      _dir = getDir _x; 
      _text = "";
      if (_showText) then {
       _text = if (isPlayer _x) then {name _x} else {"AI"};
      };
      _textSize = 0.05; 
      _font = "RobotoCondensedBold"; 
      _distance = player distance _x; 
      _iconFile = [_x] call TMI_fnc_getUnitRoleIcon; 
      _iconSize = 21; 
      _vehicleIconSize = 21; 
 
      comment "Dead"; 
      _deadIcon = "\A3\ui_f\data\igui\cfg\revive\overlayicons\d100_ca.paa"; 
      _deadColor = [0.25,0.25,0.25,0.75];  
 
      comment "Incap"; 
      _incapIcon = "\A3\ui_f\data\igui\cfg\revive\overlayicons\u100_ca.paa"; 
      _incapColor = [1,0.41,0,1]; 
 
      comment "Mic"; 
      _micIcon = "\a3\ui_f\data\IGUI\RscIngameUI\RscDisplayVoiceChat\microphone_ca.paa"; 
       
      _alpha = 1; 
      _color = switch (side group _x) do 
      { 
       case west: {[0,0.3,0.6,_alpha]}; 
       case east: {[0.5,0,0,_alpha]}; 
       case independent: {[0,0.5,0,_alpha]}; 
       case civilian: {[0.4,0,0.5,_alpha]}; 
       default {[1,1,1,_alpha]}; 
      }; 
       
      if((group player) isEqualTo (group _driver)) then  
      { 
       _color = switch (side group _x) do 
       { 
        case west: {[0,0.45,1,_alpha]}; 
        case east: {[0.8,0.35,0,_alpha]}; 
        case independent: {[0.34,0.75,0,_alpha]}; 
        case civilian: {[0.7,0,0.75,_alpha]}; 
        default {[1,1,1,_alpha]}; 
       }; 
      }; 
 
      if (lifeState _driver isEqualTo "INCAPACITATED") then  
      { 
       _color = _incapColor; 
       _iconFile = _incapIcon; 
       _dir = 0; 
       _iconSize = 25; 
      }; 
 
      if (!alive _driver) then  
      { 
       _color = _deadColor; 
       _iconFile = _deadIcon; 
       _dir = 0; 
       _iconSize = 25; 
      }; 
 
      if !(getPlayerChannel _driver isEqualTo -1) then  
      { 
       _iconFile = _micIcon; 
       _dir = 0; 
      }; 
       
      _mapDirection = if (_showText) then {0} else {ctrlMapDir _mapControl};
      private _isMouseOver = false;
      if (_showText) then {
       _pos2D = _mapControl ctrlMapWorldToScreen _pos; 
       _posCursor2D = getMousePosition; 
       _dist = _pos2D distance2D _posCursor2D; 
       _scale = ctrlMapScale _mapControl; 
       _isMouseOver = _dist <= (uiNamespace getVariable "TMIMaxCursorRangeUnitMarker");
      };
    
      if (vehicle _x == _x) then  
      { 
       if (_showText) then {
        if (isPlayer _x && _isMouseOver) then {
         private _roleName = [_x] call TMI_fnc_getUnitRole;
         if !(_roleName isEqualTo "") then {_text = format ["%1 (%2)",name _x,_roleName];};
        };
        if((_scale > (uiNamespace getVariable "TMIMinMapZoomUnitMarker")) && !_isMouseOver) then {_text = "";}; 
       };
    
       _mapControl drawIcon 
       [ 
        _iconFile, 
        _color, 
        _pos, 
        _iconSize, 
        _iconSize, 
        _dir + _mapDirection, 
        _text, 
        2, 
        _textSize, 
        _font, 
        "left" 
       ]; 
    
       _mapControl drawIcon 
       [ 
        _iconFile, 
        _color, 
        _pos, 
        _iconSize, 
        _iconSize, 
        _dir + _mapDirection, 
        _text, 
        1, 
        _textSize, 
        _font, 
        "left" 
       ]; 
      } 
      else   
      { 
       if !((vehicle _x) in _vehicleList) then  
       { 
        _vehicleList pushback vehicle _x; 
        if (_showText) then {
         TMIVisibleVehicleIcons pushBack [vehicle _x,_pos];
        };
    
        _dir = getDir vehicle _x; 
    
        _className = (typeOf vehicle _x); 
        _iconFile = getText (configfile >> "CfgVehicles" >> _className >> "icon"); 
    
        _text = "";
        _text2 = ""; 
        private _isSelectedVehicle = false;
        private _occupantNames = [];
        if (_showText) then {
         _vehName = getText (configfile >> "CfgVehicles" >> _className >> "displayName"); 
         _text = _vehName; 
         private _vehicle = vehicle _x;
         private _crew = crew _vehicle;
         _isSelectedVehicle = (missionNamespace getVariable ["TMISelectedVehicle",objNull]) isEqualTo _vehicle;
         _count = count _crew; 
         _driverName = if (isPlayer _driver) then {
          if (_isMouseOver) then {
           private _driverRole = [_driver] call TMI_fnc_getUnitRole;
           if (_driverRole isEqualTo "") then {name _driver} else {format ["%1 (%2)",name _driver,_driverRole]}
          } else {
           name _driver
          }
         } else {
          "AI"
         };
         if (_isSelectedVehicle) then {
          _occupantNames = ([_driver] + (_crew - [_driver])) apply {
           private _occupantName = if (isPlayer _x) then {name _x} else {"AI"};
           private _occupantRole = [_x] call TMI_fnc_getUnitRole;
           if (_occupantRole isEqualTo "") then {
            _occupantName
           } else {
            format ["%1 (%2)",_occupantName,_occupantRole]
           }
          };
         } else {
          _text2 = if (_count > 1) then {
           _driverName + " + " + str (_count - 1) + " more"
          } else {
           _driverName
          };
         };
        }; 
  
        if (_showText) then {
         if((_scale > (uiNamespace getVariable "TMIMinMapZoomUnitMarker")) && !_isMouseOver && {!_isSelectedVehicle}) then {_text = ""; _text2 = "";}; 
        };
         
        _mapControl drawIcon 
        [ 
         _iconFile, 
         _color, 
         _pos, 
         _vehicleIconSize, 
         _vehicleIconSize, 
         _dir + _mapDirection, 
         _text, 
         2, 
         _textSize, 
         _font, 
         "left" 
        ]; 
 
        _mapControl drawIcon 
        [ 
         _iconFile, 
         _color, 
         _pos, 
         _vehicleIconSize, 
         _vehicleIconSize, 
         _dir + _mapDirection, 
         _text, 
         1, 
         _textSize, 
         _font, 
         "left" 
        ]; 
    
        if (_isSelectedVehicle && _showText) then {
         private _occupantAnchor = _mapControl ctrlMapWorldToScreen _pos;
         {
          private _occupantScreenPosition = +_occupantAnchor;
          _occupantScreenPosition set [1,(_occupantScreenPosition # 1) + (_forEachIndex * 0.05)];
          private _occupantMapPosition = _mapControl ctrlMapScreenToWorld _occupantScreenPosition;
          _mapControl drawIcon
          [
           "#(argb,8,8,3)color(0,0,0,0)",
           _color,
           _occupantMapPosition,
           _vehicleIconSize,
           _vehicleIconSize,
           0,
           _x,
           2,
           _textSize,
           _font,
           "right"
          ];
         } forEach _occupantNames;
        } else {
         _mapControl drawIcon 
         [ 
          _iconFile, 
          _color, 
          _pos, 
          _vehicleIconSize, 
          _vehicleIconSize, 
          _dir + _mapDirection, 
          _text2, 
          1, 
          _textSize, 
          _font, 
          "right" 
         ]; 
     
         _mapControl drawIcon 
         [ 
          _iconFile, 
          _color, 
          _pos, 
          _vehicleIconSize, 
          _vehicleIconSize, 
          _dir + _mapDirection, 
          _text2, 
          2, 
          _textSize, 
          _font, 
          "right" 
         ]; 
        };
       }; 
      }; 
    
      if(_x == player) then  
      { 
       _color set[3,0.5]; 
       _draw = { 
         _this select 0 drawIcon 
        [ 
         "\a3\ui_f\data\Map\groupIcons\selector_selected_ca.paa", 
         _color, 
         _pos, 
         32, 
         32, 
          _dir + _mapDirection, 
         "", 
         0, 
         0.05, 
         _font, 
         "left" 
        ]; 
       }; 
        [_mapControl] call _draw; 
        [_mapControl] call _draw; 
      }; 
     }; 
    } foreach (if (_showText) then {allUnits+allDeadMen} else {allUnits}); 
     
    if (_showText) then {
     private _selectedVehicle = missionNamespace getVariable ["TMISelectedVehicle",objNull];
     if (!isNull _selectedVehicle && {!(_selectedVehicle in _vehicleList)}) then {
      TMISelectedVehicle = objNull;
     };
     with uiNamespace do {call TMI_fnc_mapTrailDraw;};
    };
   };

   TeamMapEvent = (findDisplay 12 displayCtrl 51) ctrlAddEventHandler ["Draw",{
    [_this select 0,true] call TMI_fnc_drawUnitIcons;
   }];

   TeamMapClickEvent = addMissionEventHandler ["MapSingleClick",{
    params ["_units","_position"];
    private _mapControl = findDisplay 12 displayCtrl 51;
    if (isNull _mapControl) exitWith {};

    private _mousePosition = _mapControl ctrlMapWorldToScreen _position;
    private _clickedVehicle = objNull;
    private _closestDistance = uiNamespace getVariable ["TMIMaxCursorRangeUnitMarker",0.02];
    {
     _x params ["_vehicle","_worldPosition"];
     if (!isNull _vehicle) then {
      private _screenPosition = _mapControl ctrlMapWorldToScreen _worldPosition;
      private _clickDistance = _screenPosition distance2D _mousePosition;
      if (_clickDistance <= _closestDistance) then {
       _clickedVehicle = _vehicle;
       _closestDistance = _clickDistance;
      };
     };
    } forEach (missionNamespace getVariable ["TMIVisibleVehicleIcons",[]]);

    private _selectedVehicle = missionNamespace getVariable ["TMISelectedVehicle",objNull];
    TMISelectedVehicle = if (isNull _clickedVehicle || {_clickedVehicle isEqualTo _selectedVehicle}) then {
     objNull
    } else {
     _clickedVehicle
    };
   }];

   TeamMapGPSEvents = [];
   TeamMapGPSMonitor = [] spawn {
    disableSerialization;
    while {!isNil "TeamMapEvent"} do {
     TeamMapGPSEvents = TeamMapGPSEvents select {!isNull (_x select 0)};
     {
      private _gpsControl = _x displayCtrl 101;
      if (!isNull _gpsControl && {(((str _x) find "311") >= 0)}) then {
       if ((TeamMapGPSEvents findIf {(_x select 0) isEqualTo _gpsControl}) isEqualTo -1) then {
        private _gpsEvent = _gpsControl ctrlAddEventHandler ["Draw",{
         [_this select 0,false] call TMI_fnc_drawUnitIcons;
        }];
        TeamMapGPSEvents pushBack [_gpsControl,_gpsEvent];
       };
      };
     } forEach (uiNamespace getVariable ["IGUI_displays",[]]);
     uiSleep 0.5;
    };
   };
   }; 
 }; 
 
SLT_fnc_disableScript = { 
 {} remoteExec ['BIS_fnc_call',0,'TeamMapIcons'];
 {
 (findDisplay 12 displayCtrl 51) ctrlRemoveEventHandler ['Draw',missionNamespace getVariable ['TeamMapEvent',-1]];
 if (!isNil 'TeamMapClickEvent') then {removeMissionEventHandler ['MapSingleClick',TeamMapClickEvent];};
 {if (!isNull (_x # 0)) then {(_x # 0) ctrlRemoveEventHandler ['Draw',_x # 1];};} forEach (missionNamespace getVariable ['TeamMapGPSEvents',[]]);
 if (!isNil 'TeamMapGPSMonitor') then {terminate TeamMapGPSMonitor;};
 if (!isNil 'TeamMapMissionEvent') then {removeMissionEventHandler ['EachFrame',TeamMapMissionEvent];};
 TeamMapEvent = nil; TeamMapClickEvent = nil; TeamMapGPSEvents = nil; TeamMapGPSMonitor = nil; TeamMapMissionEvent = nil;
 TMISelectedVehicle = nil; TMIVisibleVehicleIcons = nil;
 } remoteExec ['BIS_fnc_call',0];
};
 
SLT_fnc_init = { 
 params[["_useToggleOptions",true]]; 
 
 with uiNamespace do { 
   
  createDialog "RscDisplayEmpty"; 
  private _display = findDisplay -1; 
  {_x ctrlShow false;} foreach allControls _display; 
 
  private _ctrlHeader = _display ctrlCreate ["RscStructuredText",-1]; 
  _ctrlHeader ctrlSetPosition [0.396875 * safezoneW + safezoneX,0.445 * safezoneH + safezoneY,0.20625 * safezoneW,0.022 * safezoneH]; 
  _ctrlHeader ctrlSetBackgroundColor [1,0.7,0,0.66]; 
  _ctrlHeader ctrlSetStructuredText parseText ("<t size='0.85' font='PuristaMedium'>"+toUpper SLTScriptDisplayName+"</t>"); 
  _ctrlHeader ctrlCommit 0; 
 
  private _ctrlBorder = _display ctrlCreate ["RscPicture",-1]; 
  _ctrlBorder ctrlSetPosition [0.396875 * safezoneW + safezoneX,0.467 * safezoneH + safezoneY,0.20625 * safezoneW,0.077 * safezoneH]; 
  _ctrlBorder ctrlSetText "#(rgb,1,1,1)color(1,1,1,1)"; 
  _ctrlBorder ctrlSetTextColor [0,0,0,0.5]; 
  _ctrlBorder ctrlCommit 0; 
 
  private _ctrlBackground = _display ctrlCreate ["RscPicture",-1]; 
  _ctrlBackground ctrlSetPosition [0.402031 * safezoneW + safezoneX,0.478 * safezoneH + safezoneY,0.195937 * safezoneW,0.055 * safezoneH]; 
  _ctrlBackground ctrlSetText "#(rgb,1,1,1)color(1,1,1,1)"; 
  _ctrlBackground ctrlSetTextColor [0.1,0.1,0.1,0.75]; 
  _ctrlBackground ctrlCommit 0; 
 
  SLTEnableButton = _display ctrlCreate ["RscButtonMenu",-1]; 
  SLTEnableButton ctrlSetPosition [0.407187 * safezoneW + safezoneX,0.489 * safezoneH + safezoneY,0.0928125 * safezoneW,0.033 * safezoneH]; 
  SLTEnableButton ctrlSetText "ENABLE"; 
  SLTEnableButton ctrlCommit 0; 
  SLTEnableButton ctrlAddEventHandler ["ButtonClick",{ 
   [[],missionNamespace getVariable "SLT_fnc_enableScript"] call (missionNamespace getVariable "SLT_fnc_RE_Server"); 
   closeDialog 0; 
  }]; 
 
  SLTDisableButton = _display ctrlCreate ["RscButtonMenu",-1]; 
  SLTDisableButton ctrlSetPosition [0.5 * safezoneW + safezoneX,0.489 * safezoneH + safezoneY,0.0928125 * safezoneW,0.033 * safezoneH]; 
  SLTDisableButton ctrlSetText "DISABLE"; 
  SLTDisableButton ctrlCommit 0; 
  SLTDisableButton ctrlAddEventHandler ["ButtonClick",{ 
   [[],missionNamespace getVariable "SLT_fnc_disableScript"] call (missionNamespace getVariable "SLT_fnc_RE_Server"); 
   closeDialog 0; 
  }]; 
 
  if (!_useToggleOptions) then  
  { 
   SLTEnableButton ctrlSetText "ARE YOU SURE?"; 
   SLTEnableButton ctrlSetTooltip "This script cannot be disabled!"; 
   SLTEnableButton ctrlCommit 0; 
 
   SLTDisableButton ctrlSetText "CANCEL"; 
   SLTDisableButton ctrlCommit 0; 
  }; 
 }; 
 deleteVehicle this; 
}; 
 
[] spawn SLT_fnc_enableScript;
