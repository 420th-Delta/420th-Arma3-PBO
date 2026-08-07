SLT_fnc_RE_Server = { 
 params["_arguments","_code"]; 
 _varName = ("SLT"+str (round random 10000)); 
 
 TempCode = compile ("if(!isServer) exitWith{};_this call "+str _code+"; "+(_varName+" = nil;")); 
 TempArgs = _arguments; 
 
 call compile (_varName +" = [TempArgs,TempCode]; 
 publicVariable '"+_varName+"'; 
 
 [[], { 
 ("+_varName+" select 0) spawn ("+_varName+" select 1); 
 }] remoteExec ['spawn',2];"); 
}; 
 
with uiNamespace do {SLTScriptDisplayName = "Team Name Tags";}; 
 
SLT_fnc_enableScript = { 
  [] spawn 
  { 
   if(!hasInterface) exitWith {}; 
   if (!isNil "TeamNameTagEvent") exitWith {}; 
   if(isMultiplayer) then {waitUntil{getClientState isEqualTo "BRIEFING READ"};}; 
   sleep 1; 
   disableMapIndicators [true,false,false,false]; 
    
    TNTMaxDistanceUnitMarker3D = 7000; 
    TNTMaxDistanceUnitMarkerText3D = 10; 
    TNTNearbyFriendlyAI = [];
     
    TeamNameTagEvent = addMissionEventHandler ["Draw3D", { 
     private _vehicleList = []; 
     private _unitsToDraw = allPlayers + (missionNamespace getVariable ["TNTNearbyFriendlyAI",[]]);
     private _cursorObject = cursorTarget;
     if (!isNull _cursorObject) then {
      private _cursorUnits = if (_cursorObject isKindOf "CAManBase") then {[_cursorObject]} else {crew _cursorObject};
      {
       if (!isPlayer _x && {(side group _x) isEqualTo (side group player)}) then {
        _unitsToDraw pushBackUnique _x;
       };
      } forEach _cursorUnits;
     };
     { 
     if(((side group _x) isEqualTo (side group player)) && (_x != player)) then 
     { 
      _position = _x modelToWorldVisual (_x selectionPosition "head_axis"); 
      _position set[2,(_position select 2)+0.5]; 
      _distance = (player) distance (_position); 
      _driver = if (driver vehicle _x isEqualTo objNull) then {effectiveCommander vehicle _x} else {driver vehicle _x}; 
      _textSize = 0.0325; 
      _text = if (isPlayer _x) then {name _x} else {"AI"}; 
      _imageSize = [0.5,0.5]; 
    
      _dif = (TNTMaxDistanceUnitMarker3D-_distance); 
      _alpha = 0.75 min (_dif/TNTMaxDistanceUnitMarker3D); 
      if(vehicle _x == cursorTarget) then {_alpha = 1;}; 
 
      _color = switch (side group player) do 
      { 
       case west: {[0,0.3,0.6,_alpha]}; 
       case east: {[0.5,0,0,_alpha]}; 
       case independent: {[0,0.5,0,_alpha]}; 
       case civilian: {[0.4,0,0.5,_alpha]}; 
       default {[1,1,1,_alpha]}; 
      }; 
       
      if((group player) isEqualTo (group _x)) then  
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
    
      _rankPath = switch (rank _x) do  
      { 
       case "COLONEL": {"\a3\ui_f\data\GUI\cfg\Ranks\colonel_pr.paa"}; 
       case "MAJOR": {"\a3\ui_f\data\GUI\cfg\Ranks\major_pr.paa"}; 
       case "CAPTAIN": {"\a3\ui_f\data\GUI\cfg\Ranks\captain_pr.paa"}; 
       case "LIEUTENANT": {"\a3\ui_f\data\GUI\cfg\Ranks\lieutenant_pr.paa"}; 
       case "SERGEANT": {"\a3\ui_f\data\GUI\cfg\Ranks\sergeant_pr.paa"}; 
       case "CORPORAL": {"\a3\ui_f\data\GUI\cfg\Ranks\corporal_pr.paa"}; 
       case "PRIVATE": {"\a3\ui_f\data\GUI\cfg\Ranks\private_pr.paa"}; 
       default {"\a3\ui_f\data\GUI\cfg\Ranks\private_pr.paa"}; 
      }; 
 
      if((rank _x) isEqualTo "COLONEL") then {_imageSize = [0.75,0.75]; _color = [1,1,1,_alpha];}; 
 
      comment "Dead"; 
      _deadIcon = "\A3\ui_f\data\igui\cfg\revive\overlayicons\d100_ca.paa"; 
      _deadColor = [0.25,0.25,0.25,0.75];  
 
      comment "Incap"; 
      _incapIcon = "\A3\ui_f\data\igui\cfg\revive\overlayicons\u100_ca.paa"; 
      _incapColor = [1,0.41,0,_alpha]; 
 
      comment "Mic"; 
      _micIcon = "\a3\ui_f\data\IGUI\RscIngameUI\RscDisplayVoiceChat\microphone_ca.paa"; 
 
      if (lifeState _driver isEqualTo "INCAPACITATED" && damage _driver > 0.4) then  
      { 
       _color = _incapColor; 
       _rankPath = _incapIcon; 
      }; 
 
      if (!alive _driver) then  
      { 
       _color = _deadColor; 
       _rankPath = _deadIcon; 
      }; 
 
      if !(getPlayerChannel _driver isEqualTo -1) then  
      { 
       _rankPath = _micIcon; 
      }; 
 
      if (vehicle _x != _x) then 
      { 
       if !((vehicle _x) in _vehicleList) then  
       { 
        _vehicleList pushback vehicle _x; 
 
        if (vehicle _x isEqualTo vehicle player) exitWith {}; 
 
        _position = (vehicle _x) modelToWorldVisual [0,0,2]; 
 
        _className = (typeOf vehicle _x); 
        _file = getText (configfile >> "CfgVehicles" >> _className >> "icon"); 
        _rankPath = _file; 
 
        if(_driver isEqualTo objNull) then {_driver = _x;}; 
 
        _vehName = getText (configfile >> "CfgVehicles" >> _className >> "displayName"); 
        _text = _vehName; 
 
        _driverName = if (isPlayer _driver) then {name _driver} else {"AI"};
        _count = count crew vehicle _x; 
        if(_count > 1) then  
        { 
         _text = (_driverName + " + " + (str (_count-1)) + " more"); 
        } 
        else 
        { 
         _text = _driverName; 
        }; 
 
        _imageSize = [0.65,0.65]; 
 
        if((_distance > TNTMaxDistanceUnitMarkerText3D) && (vehicle _x != cursorTarget)) then {_text = "";}; 
 
        if ((_distance < TNTMaxDistanceUnitMarker3D) || (vehicle _x == cursorTarget)) then 
        { 
         drawIcon3D [_rankPath,_color,_position, _imageSize select 0,_imageSize select 1, 0,(_text), 2, _textSize, "RobotoCondensedBold","center",false]; 
        }; 
       }; 
      }; 
       
      if !((vehicle _x) in _vehicleList) then  
      { 
       if((_distance > TNTMaxDistanceUnitMarkerText3D) && (vehicle _x != cursorTarget)) then {_text = "";}; 
 
       if ((_distance < TNTMaxDistanceUnitMarker3D) || (vehicle _x == cursorTarget)) then 
       { 
        drawIcon3D [_rankPath,_color,_position, _imageSize select 0,_imageSize select 1, 0,(_text), 2, _textSize, "RobotoCondensedBold","center",false]; 
       }; 
      }; 
     }; 
    } foreach _unitsToDraw; 
    }]; 

    TeamNameTagAIUpdater = [] spawn {
     while {!isNil "TeamNameTagEvent"} do {
      private _playerSide = side group player;
      TNTNearbyFriendlyAI = allUnits select {
       !isPlayer _x &&
       {(side group _x) isEqualTo _playerSide} &&
       {(_x distance player) <= TNTMaxDistanceUnitMarker3D}
      };
      uiSleep 0.5;
     };
    };
   }; 
 }; 
 
SLT_fnc_disableScript = { 
 {  
  removeMissionEventHandler ['Draw3D', TeamNameTagEvent]; 
  if (!isNil 'TeamNameTagAIUpdater') then {terminate TeamNameTagAIUpdater;};
  TeamNameTagEvent = nil; 
  TeamNameTagAIUpdater = nil;
  TNTNearbyFriendlyAI = nil;
  } remoteExec ['bis_fnc_call', 0]; 
 
 {} remoteExec ['BIS_fnc_call',0,'TeamNameTag']; 
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
