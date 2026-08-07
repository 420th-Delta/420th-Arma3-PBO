/*
	Adds the Simple Floatary load/unload actions on an interface client.
	The function is safe to remoteExec because it accepts only a vehicle and
	validates both the client context and configured carrier classes.
*/
params [["_vehicle",objNull,[objNull]]];

if (!hasInterface || {isNull _vehicle}) exitWith {};
if (isNil "FLRYAllWatercraftCarrierClassNames") exitWith {};
if !(typeOf _vehicle in FLRYAllWatercraftCarrierClassNames) exitWith {};
if (_vehicle getVariable ["QS_floatary_actionsAdded",false]) exitWith {};

_vehicle setVariable ["QS_floatary_actionsAdded",true];

private _picPath = "\A3\boat_F\Boat_Transport_01\data\UI\map_Boat_Transport_01_CA.paa";

[
	_vehicle,
	"<a color='#ffffff' font='RobotoCondensed' shadow='1' size='1.1'>Load Watercraft<img image='"+_picPath+"'/></a>",
	"a3\ui_f\data\igui\cfg\holdactions\holdaction_loaddevice_ca.paa",
	"a3\ui_f\data\igui\cfg\holdactions\holdaction_loaddevice_ca.paa",
	"_this distance _target < 25 && ([_target] call FLRY_fnc_getAttachedBoat isEqualTo objNull) && ([vehicle _this,_target isKindOf 'Plane'] call FLRY_fnc_getIsValidShip) && (driver vehicle _this isEqualTo _this) && ([getPosASL vehicle _this, _target] call FLRY_fnc_getIsBehindAircraft)",
	"_caller distance _target < 25",
	{},
	{},
	{[vehicle _caller,_target] call FLRY_fnc_attachWatercraft;},
	{},
	[],
	3,
	0,
	false,
	false
] call BIS_fnc_holdActionAdd;

[
	_vehicle,
	"<a color='#ffffff' font='RobotoCondensed' shadow='1' size='1.1'>Unload Watercraft<img image='"+_picPath+"'/></a>",
	"a3\ui_f\data\igui\cfg\holdactions\holdaction_unloaddevice_ca.paa",
	"a3\ui_f\data\igui\cfg\holdactions\holdaction_unloaddevice_ca.paa",
	"_this distance _target < 25 && !([_target] call FLRY_fnc_getAttachedBoat isEqualTo objNull) && ((driver _target isEqualTo _this) || ((driver ([_target] call FLRY_fnc_getAttachedBoat)) isEqualTo _this))",
	"_caller distance _target < 25",
	{},
	{},
	{[_target] call FLRY_fnc_detachWatercraft;},
	{},
	[],
	3,
	0,
	false,
	false
] call BIS_fnc_holdActionAdd;
