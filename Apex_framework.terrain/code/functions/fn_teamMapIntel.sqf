/* Initializes local team map intelligence. Runs once on each interface client. */
if (!hasInterface) exitWith {};
  [] spawn {   
      
   if (isMultiplayer) then {waitUntil {sleep 0.1; getClientState == "BRIEFING READ"};};   
   waitUntil {sleep 0.1; !((findDisplay 12 displayCtrl 51) isEqualTo controlNull)};   
      
   if !(isNil "RKAGRevealedGroups") exitWith {};   
   
   comment "Parameters";   
   RKAGOnlyShowMarkersOnMap = true;   
   RKAGIncludePlayerGroups = false;   
   RKAGHideFriendlyForces = true;   
   RKAGMinGroupSize = 5;   
   RKAGLastKnownLocationMarkerTime = 180;   
   RKAGBulletMarkerSpeed = 7.5;   
   RKAGBulletMarkerSize = [1,4];   
   RKAGBulletMarkerColor = "ColorWhite";   
   RKAGBulletMarkerLifetime = 0.5;   
   RKAGBulletIncludePlayers = false;   
   RKAGShowGroups = true;   
   
   setGroupIconsVisible [true,true];   
   setGroupIconsSelectable true;   
   disableMapIndicators [RKAGHideFriendlyForces,true,false,false];   
   uiNamespace setVariable ["_map",findDisplay 12 displayCtrl 51];    
   
   RKAG_fnc_createMapTooltip = {   
    with uiNamespace do {   
     _display = (finddisplay 12);   
   
     RKAGMapTooltipGroup = _display ctrlCreate ["RscControlsGroup", 2300];   
     RKAGMapTooltipGroup ctrlSetPosition [0, 0, 0.4625, 0.34];   
     RKAGMapTooltipGroup ctrlCommit 0;    
   
     RKAGMapInfantryTooltipHeader = _display ctrlCreate ["RscStructuredText", 1100,RKAGMapTooltipGroup];   
     RKAGMapInfantryTooltipHeader ctrlSetPosition [0.0125, 0.02, 0.4375, 0.04];   
     RKAGMapInfantryTooltipHeader ctrlSetStructuredText parseText ("<t font='PuristaSemibold' valign='middle' size='1' shadow='0' align='center'>Infantry Intel</t>");   
     RKAGMapInfantryTooltipHeader ctrlSetBackgroundColor [0.15,0.15,0.15,0.75];   
     RKAGMapInfantryTooltipHeader ctrlCommit 0;   
   
     RKAGMapInfantryTooltipBody = _display ctrlCreate ["RscStructuredText", 1101,RKAGMapTooltipGroup];   
     RKAGMapInfantryTooltipBody ctrlSetPosition [0.0125, 0.06, 0.4375, 0.1];   
     RKAGMapInfantryTooltipBody ctrlSetBackgroundColor [0.05,0.05,0.05,0.75];   
     RKAGMapInfantryTooltipBody ctrlCommit 0;   
   
     RKAGMapVehicleTooltipHeader = _display ctrlCreate ["RscStructuredText", 1102,RKAGMapTooltipGroup];   
     RKAGMapVehicleTooltipHeader ctrlSetPosition [0.0125, 0.18, 0.4375, 0.04];   
     RKAGMapVehicleTooltipHeader ctrlSetStructuredText parseText ("<t font='PuristaSemibold' valign='middle' size='1' shadow='0' align='center'>Vehicle Intel</t>");   
     RKAGMapVehicleTooltipHeader ctrlSetBackgroundColor [0.15,0.15,0.15,0.75];   
     RKAGMapVehicleTooltipHeader ctrlCommit 0;   
   
     RKAGMapVehicleTooltipBody = _display ctrlCreate ["RscStructuredText", 1103,RKAGMapTooltipGroup];   
     RKAGMapVehicleTooltipBody ctrlSetPosition [0.0125, 0.22, 0.4375, 0.1];   
     RKAGMapVehicleTooltipBody ctrlSetBackgroundColor [0.05,0.05,0.05,0.75];   
     RKAGMapVehicleTooltipBody ctrlCommit 0;   
    };   
   
    addMissionEventHandler ["EachFrame", {   
     with uiNamespace do    
     {   
      _mousePos = getMousePosition;   
      RKAGMapTooltipGroup ctrlSetPosition [(getMousePosition select 0),(getMousePosition select 1)+0.05,0.4625, 0.34];   
      RKAGMapTooltipGroup ctrlCommit 0;   
     };   
    }];   
   };   
   
   RKAG_fnc_createMapHideMarkersCheckbox = {   
    with uiNamespace do {   
     private _display = finddisplay 12;   
     private _RscCheckbox_2800 = _display ctrlCreate ["RscCheckbox", 2800];   
     _RscCheckbox_2800 ctrlSetPosition [0.965937 * safezoneW + safezoneX, 0.948 * safezoneH + safezoneY, 0.018125 * safezoneW, 0.0336666 * safezoneH];   
     _RscCheckbox_2800 ctrlSetTooltip "Show Unit Markers: ON";   
     _RscCheckbox_2800 cbSetChecked true;   
     _RscCheckbox_2800 ctrlSetBackgroundColor [0,0.5,0,1];   
     _RscCheckbox_2800 ctrlCommit 0;   
     missionNamespace setVariable ["QS_teamNameTags_enabled",true];
     _RscCheckbox_2800 ctrlAddEventHandler ["CheckedChanged",{   
      params ["_control", "_checked"];   
   
      if (_checked == 1) then    
      {   
       setGroupIconsVisible [true,true];   
       setGroupIconsSelectable true;   
       disableMapIndicators [RKAGHideFriendlyForces,true,false,false];   
       RKAGShowGroups = true;   
       missionNamespace setVariable ["QS_teamNameTags_enabled",true];
       _control ctrlSetTooltip "Show Unit Markers: ON";   
      }   
      else    
      {   
       setGroupIconsVisible [false,false];   
       setGroupIconsSelectable false;   
       RKAGShowGroups = false;   
       missionNamespace setVariable ["QS_teamNameTags_enabled",false];
       _control ctrlSetTooltip "Show Unit Markers: OFF";   
      };   
     }];   
    };   
   };   
   
   RKAG_fnc_getGroupNATOMarkerType = {   
    params["_group"];   
    private _side = sideUnknown;   
    private _mkr = "";   
   
    private _prefix = "";   
    _prefix = switch (side _group) do    
    {   
     case west: {"b_"};   
     case east: {"o_"};   
     case independent: {"n_"};   
     default {""};   
    };   
   
    private ["_grp","_vehlist","_infantry","_cars","_apcs","_tanks","_aa","_helis","_planes","_boats","_veh","_type"];   
   
    _grp = _group;   
   
    _vehlist = [];   
    _infantry = 0;   
    _cars = 0;   
    _apcs = 0;   
    _tanks = 0;   
    _aa = 0;   
    _helis = 0;   
    _planes = 0;   
    _uavs = 0;   
    _boats = 0;   
    _artys = 0;   
    _mortars = 0;   
    _support_reammo = 0;   
    _support_repair = 0;   
    _support_refuel = 0;   
    _support_medic = 0;   
    _support = 0;   
    {   
     if (!canstand vehicle _x && alive vehicle _x && !(vehicle _x in _vehlist)) then {   
      _veh = vehicle _x;   
      _vehlist = _vehlist + [_veh];   
   
      if (_veh iskindof "car") then {_cars = _cars + 1};   
      if (_veh iskindof "tank") then {_tanks = _tanks + 1;};   
      if (getnumber(configfile >> "cfgvehicles" >> typeof _veh >> "artilleryScanner") > 0) then{_artys = _artys + 1;};   
      if (_veh iskindof "Wheeled_APC_F" || _veh iskindof "APC_Tracked_01_base_F"   
      || _veh iskindof "APC_Tracked_02_base_F" || _veh iskindof "APC_Tracked_03_base_F") then {_apcs = _apcs + 1};   
      if (getnumber(configfile >> "cfgvehicles" >> typeof _veh >> "radarType") > 0) then {_aa = _aa + 1};   
      if (_veh iskindof "helicopter") then {_helis = _helis + 1};   
      if (_veh iskindof "plane") then {_planes = _planes + 1;};   
      if (_veh in allUnitsUAV) then {_uavs = _uavs + 1;};   
      if (_veh iskindof "staticcanon") then {_artys = _artys + 1};   
      if (_veh iskindof "staticmortar") then {_mortars = _mortars + 1};   
      if (_veh iskindof "ship") then {_boats = _boats + 1};   
      _canHeal = getnumber (configfile >> "cfgvehicles" >> typeof _veh >> "attendant") > 0;   
      _canReammo = getnumber (configfile >> "cfgvehicles" >> typeof _veh >> "transportAmmo") > 0;   
      _canRefuel = getnumber (configfile >> "cfgvehicles" >> typeof _veh >> "transportFuel") > 0;   
      _canRepair = getnumber (configfile >> "cfgvehicles" >> typeof _veh >> "transportRepair") > 0;   
      if (_canHeal) then {_support_medic = _support_medic + 1};   
      if (_canReammo) then {_support_reammo = _support_reammo + 1};   
      if (_canRefuel) then {_support_refuel = _support_refuel + 1};   
      if (_canRepair) then {_support_repair = _support_repair + 1};   
     };   
     if ((vehicle _x isEqualTo _x)) then {_infantry = (_infantry + 1)};   
    } foreach units _grp;   
   
    _type = "unknown";   
    if (_infantry >= 1) then {_type = "inf"};   
    if (_cars >= 1) then {_type = "motor_inf"};   
    if (_tanks >= 1) then {_type = "armor"};   
    if (_apcs >= 1) then {_type = "mech_inf"};   
    if (_aa >= 1) then {_type = "antiair"};   
    if (_artys >= 1) then {_type = "art"};   
    if (_mortars >= 1) then {_type = "mortar"};   
    if ((_support_reammo + _support_refuel) >= 1) then {_type = "support"};   
    if (_support_repair >= 1) then {_type = "maint"};   
    if (_support_medic >= 1) then {_type = "med"};   
    if ((_support_medic + _support_reammo + _support_refuel + _support_repair) > 1) then {_type = "support"};   
    if (_boats >= 1) then {_type = "naval"};   
    if (_helis >= 1) then {_type = "air"};   
    if (_planes >= 1) then {_type = "plane"};   
    if (_uavs >= 1) then {_type = "uav"};   
       
    _mkr = (_prefix+_type);   
    _mkr   
   };   
   
   RKAG_fnc_spawnRevealGroup = {   
    params["_group"];   
   
    clearGroupIcons (_group);   
    private _mkrType = [_group] call RKAG_fnc_getGroupNATOMarkerType;   
    private _id = (_group) addGroupIcon [_mkrType, [0,0]];   
    _group setGroupIconParams [([side _group, false] call BIS_fnc_sideColor),"",1,true];   
   
    while {!(_group isEqualTo grpNull) && (_group in RKAGRevealedGroups)} do    
    {   
     _mkrType = [_group] call RKAG_fnc_getGroupNATOMarkerType;   
     _group setGroupIcon [_id, _mkrType];   
   
     comment "Check if any units are alive";   
     private _i = units _group findIf {alive _x};   
     if (_i < 0) then {_group setGroupIconParams [[0,0,0,0.75],"",1,true];};   
   
     sleep 1;   
    };   
   
    comment "Show last location";   
    private _j = units _group findIf {alive _x};   
    if (!(_group isEqualTo grpNull) && (_j > -1) && (side _group != side player)) then {[_group] spawn RKAG_fnc_spawnLastKnownPositionMarker;};   
   
    clearGroupIcons (_group);   
   };   
   
   RKAG_fnc_hideGroup = {   
    params["_group"];   
    RKAGRevealedGroups = (RKAGRevealedGroups-[_group]);   
   };   
   
   RKAG_fnc_hideMapTooltip = {   
    with uiNamespace do    
    {   
     RKAGMapTooltipGroup ctrlShow false;   
     RKAGMapInfantryTooltipHeader ctrlShow false;   
     RKAGMapInfantryTooltipBody ctrlShow false;   
     RKAGMapVehicleTooltipHeader ctrlShow false;   
     RKAGMapVehicleTooltipBody ctrlShow false;   
    };   
   };   
   
   RKAG_fnc_showMapTooltip = {   
    params["_group","_vehicleCount","_footCount"];   
   
    with uiNamespace do    
    {   
     private _sideColor = ([side _group, false] call BIS_fnc_sideColor);   
     _sideColor set[3,0.75];   
     RKAGMapInfantryTooltipHeader ctrlSetBackgroundColor (_sideColor);   
     RKAGMapVehicleTooltipHeader ctrlSetBackgroundColor (_sideColor);   
     RKAGMapTooltipGroup ctrlShow true;   
   
     private _footText = "";   
     private _vehicleText = "";   
     private _vehs = [];   
     {   
      private _unit = _x;   
   
      if (!alive _unit) then {continue};   
   
      if (_footCount > 0 && (vehicle _unit isEqualTo _unit)) then    
      {   
       _iconName = getText (configFile >> "CfgVehicles" >> typeOf _unit >> "icon");   
       _iconPath = getText(configfile >> "CfgVehicleIcons" >> _iconName);   
       _footText=(_footText+"<img image='"+_iconPath+"' shadow='0' size='1.2' valign='middle'></img>");   
      };   
       
      if (_vehicleCount > 0 && !(vehicle _unit isEqualTo _unit) && !(vehicle _unit in _vehs)) then   
      {   
       _vehs pushBack vehicle _unit;   
          
   
       _vehicleText=(_vehicleText+"<img image='"+(getText (configfile >> 'CfgVehicles' >> typeOf vehicle _unit >> 'picture'))+"' shadow='0' size='1.33' valign='middle'></img>");   
      };   
     } foreach units _group;   
   
     if !(_footText isEqualTo "") then    
     {   
      RKAGMapInfantryTooltipHeader ctrlShow true;   
      RKAGMapInfantryTooltipBody ctrlShow true;   
      RKAGMapInfantryTooltipBody ctrlSetStructuredText parseText ("<t size='0.1'>&#160;</t><br/>"+_footText);   
      RKAGMapInfantryTooltipBody ctrlCommit 0;   
     }   
     else    
     {   
      RKAGMapInfantryTooltipHeader ctrlShow false;   
      RKAGMapInfantryTooltipBody ctrlShow false;   
     };   
   
     if !(_vehicleText isEqualTo "") then    
     {   
      RKAGMapVehicleTooltipHeader ctrlShow true;   
      RKAGMapVehicleTooltipBody ctrlShow true;   
      RKAGMapVehicleTooltipBody ctrlSetStructuredText parseText ("<t size='0.5'>&#160;</t><br/>"+_vehicleText);   
      RKAGMapVehicleTooltipBody ctrlCommit 0;   
   
      if (_footText isEqualTo "") then    
      {   
       RKAGMapVehicleTooltipHeader ctrlSetPosition [0.0125, 0.02, 0.4375, 0.04];   
       RKAGMapVehicleTooltipBody ctrlSetPosition [0.0125, 0.06, 0.4375, 0.1];   
       RKAGMapVehicleTooltipHeader ctrlcommit 0.05;   
       RKAGMapVehicleTooltipBody ctrlcommit 0.05;   
      }   
      else    
      {   
       RKAGMapVehicleTooltipHeader ctrlSetPosition [0.0125, 0.18, 0.4375, 0.04];   
       RKAGMapVehicleTooltipBody ctrlSetPosition [0.0125, 0.22, 0.4375, 0.1];   
       RKAGMapVehicleTooltipHeader ctrlCommit 0.05;   
       RKAGMapVehicleTooltipBody ctrlCommit 0.05;   
   
      };   
     }   
     else    
     {    
      RKAGMapVehicleTooltipHeader ctrlShow false;   
      RKAGMapVehicleTooltipBody ctrlShow false;   
     };   
    };   
   };   
   
   RKAG_fnc_spawnLastKnownPositionMarker = {   
    params["_group"];   
       
    private _mkr = createMarkerLocal ["marker_"+str(count allMapMarkers),getPos leader _group];   
    _mkr setMarkerTypeLocal "mil_unknown";   
   
    _colorName = switch (side _group) do    
    {   
     case west: {"colorBLUFOR"};   
     case east: {"colorOPFOR"};   
     case independent: {"colorIndependent"};   
     case civilian: {"colorCivilian"};   
     default {"ColorUNKNOWN"};   
    };   
    _mkr setMarkerColorLocal _colorName;   
    _mkr setMarkerSizeLocal [0.5,0.5];   
   
    _time = 0;   
    _maxTime = RKAGLastKnownLocationMarkerTime;   
    while {!(_group isEqualTo grpNull) && !(_group in RKAGRevealedGroups)} do    
    {   
     uisleep 1;   
     _time=_time+1;   
     if (_time >= _maxTime) exitWith {};   
    };   
    deleteMarkerLocal _mkr;   
   };   
   
   RKAG_fnc_spawnFireEffect = {   
    params["_unit"];   
   
    private _group = group _unit;   
    _group spawn    
    {   
     _this setGroupIconParams [[1,1,0.9,0.75],"",1,true];   
     uisleep 0.05;   
     _this setGroupIconParams [([side _this, false] call BIS_fnc_sideColor),"",1,true];   
    }; 
   };   
   
   RKAG_fnc_tryInitUnit = {   
    params["_unit"];   
       
    private _initValue = _unit getVariable "RKAGInit";   
    if (isNil "_initValue") then    
    {   
     _unit addEventHandler ["FiredMan",{   
      params["_unit"];   
      [_unit] spawn RKAG_fnc_spawnFireEffect;   
     }];   
     _unit setVariable ["RKAGInit",true];   
    };   
   };   
   
   onGroupIconOverEnter   
   {   
    private _group = _this select 1;   
    private _mkrType = [_group] call RKAG_fnc_getGroupNATOMarkerType;   
    private _text = (getText(configfile >> "CfgMarkers" >> _mkrType >> "name"));   
    private _vehCount = 0;   
    private _footCount = 0;   
    private _vehName = '';   
    private _vehs = [];   
   
    comment "Determine marker name based on vehicle count and type";   
    {   
     if (!(vehicle _x isEqualTo _x) && !(vehicle _x in _vehs)) then    
     {   
      _vehCount = (_vehCount+1);   
      _vehs pushBack vehicle _x;   
      if (_vehName isEqualTo '') then {_vehName = [configFile >> "CfgVehicles" >> typeOf vehicle _x] call BIS_fnc_displayName;};   
     };   
     if (vehicle _x isEqualTo _x) then {_footCount = (_footCount+1);};   
    } foreach units _group;   
    if (_vehCount == 1) then {_text = _vehName;};   
   
    comment "Check if any units alive";   
    _i = units _group findIf {alive _x};   
    if (_i < 0) then {_group setGroupIconParams [[0,0,0,0.75],_text+" (DEAD)",1.25,true];}   
    else {_group setGroupIconParams [([side _group, false] call BIS_fnc_sideColor),_text,1.25,true];};   
   
    comment "Show map tooltip";   
    if (visibleMap) then {[_group,_vehCount,_footCount] call RKAG_fnc_showMapTooltip;};   
   };   
   
   onGroupIconOverLeave   
   {   
    private _group = _this select 1;   
    _group setGroupIconParams [([side _group, false] call BIS_fnc_sideColor),"",1,true];   
    call RKAG_fnc_hideMapTooltip;   
   };   
   
   RKAGRevealedGroups = [];   
   
   call RKAG_fnc_createMapTooltip;   
   call RKAG_fnc_hideMapTooltip;   
   call RKAG_fnc_createMapHideMarkersCheckbox;   
   
   addMissionEventHandler    
   [ "Map",{    
    params ["_isOpened","_isForced"];    
       
    if (RKAGOnlyShowMarkersOnMap && !_isOpened) then    
    {   
     setGroupIconsVisible [false,false];   
     setGroupIconsSelectable false;   
    };   
   
    if (RKAGOnlyShowMarkersOnMap && _isOpened && RKAGShowGroups) then    
    {   
     setGroupIconsVisible [true,true];   
     setGroupIconsSelectable true;   
    };   
   
    if (!_isOpened) then {call RKAG_fnc_hideMapTooltip;};   
   }];   
   
   if (RKAGOnlyShowMarkersOnMap) then    
   {   
    setGroupIconsVisible [false,false];   
    setGroupIconsSelectable false;   
   };   
   
   while {!isNil "RKAGRevealedGroups"} do    
   {   
    if (alive player) then    
    {   
      {   
       private _group = _x;   
       if !(side _group in [EAST,INDEPENDENT]) then {continue};
       _inVehicle = !(vehicle (units _group select 0) isEqualTo (units _group select 0));   
      if (isNil "_inVehicle") then {_inVehicle = false;};   
         
      private _i = -1;   
      if (RKAGIncludePlayerGroups) then {_i = -1;}   
      else {_i = units _group findIf {_x in allPlayers};};   
         
      if (_i > -1 || (side _group isEqualTo side player && (count units _group <= 1) && !_inVehicle) || side _group isEqualTo civilian) then {continue};   
   
      private _spottedAnyGroupMember = false;   
      {   
       _spottedAnyGroupMember = ((side player) knowsAbout vehicle _x == 4);   
       [_x] call RKAG_fnc_tryInitUnit;   
      } forEach units _group;   
   
      if (_spottedAnyGroupMember) then    
      {   
       if (_group in RKAGRevealedGroups) exitWith {};   
       if (count units _group < RKAGMinGroupSize && ((vehicle (units _group select 0)) isEqualTo (units _group select 0))) exitWith {};   
       RKAGRevealedGroups pushBack _group;   
       [_group] spawn RKAG_fnc_spawnRevealGroup;   
      }   
      else    
      {   
       [_group] call RKAG_fnc_hideGroup;   
      };   
     } foreach allGroups;   
   
     comment "Try Init Players";   
     if (RKAGBulletIncludePlayers) then {    
      {   
       if !(side _x isEqualTo side player) then {continue};   
       [_x] call RKAG_fnc_tryInitUnit;   
      } foreach allPlayers;   
     };   
    };   
    RKAGRevealedGroups = (RKAGRevealedGroups - [grpNull]);   
    {deleteGroup _x;} foreach allGroups;   
    uisleep 1;   
   };   
  };   
