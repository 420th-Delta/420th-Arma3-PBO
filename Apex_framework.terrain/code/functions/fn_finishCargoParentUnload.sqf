/*
File: fn_finishCargoParentUnload.sqf

Description:

	Terminal parent-local cargo unload worker.
__________________________________________________*/

params ['_parent','_child',['_isCustom',FALSE]];
if (
	(isNull _parent) ||
	{(!local _parent)}
) exitWith {};

if (_isCustom && {(!isNull _child)}) then {
	_parent setMass ((getMass _parent) - (getMass _child));
};

[_parent,TRUE,TRUE] call QS_fnc_updateCenterOfMass;
