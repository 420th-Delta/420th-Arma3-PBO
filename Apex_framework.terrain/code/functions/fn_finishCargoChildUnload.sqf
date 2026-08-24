/*
File: fn_finishCargoChildUnload.sqf

Description:

	Terminal child-local cargo unload worker.
__________________________________________________*/

params ['_child'];
if (
	(isNull _child) ||
	{(!local _child)}
) exitWith {};

if (isEngineOn _child) then {
	_child engineOn FALSE;
};

if (
	(_child isKindOf 'StaticWeapon') ||
	{(_child isKindOf 'Reammobox_F')}
) then {
	_child allowDamage (_child getVariable ['cargo_isDamageAllowed',TRUE]);
};
