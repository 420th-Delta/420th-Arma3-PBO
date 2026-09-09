/*/
File: fn_removeAircraftBombs.sqf

Description:

	Remove all bomb ammunition from a locally owned fixed-wing aircraft while
	leaving missiles, rockets, guns, and countermeasures unchanged.
____________________________________________________________/*/

params [['_aircraft',objNull]];
if (
	(isNull _aircraft) ||
	{(!(_aircraft isKindOf 'Plane'))} ||
	{(!local _aircraft)}
) exitWith {0};

private _isBombMagazine = {
	params ['_magazine'];
	if (_magazine isEqualTo '') exitWith {FALSE};
	private _ammo = getText (configFile >> 'CfgMagazines' >> _magazine >> 'ammo');
	(
		(_ammo isNotEqualTo '') &&
		{(_ammo isKindOf ['BombCore',(configFile >> 'CfgAmmo')])}
	)
};

private _removed = 0;
private _bombPylonWeapons = [];
{
	private _magazine = _x;
	if ([_magazine] call _isBombMagazine) then {
		private _pylonIndex = _forEachIndex + 1;
		private _pylonWeapon = getText (configFile >> 'CfgMagazines' >> _magazine >> 'pylonWeapon');
		if (_pylonWeapon isNotEqualTo '') then {
			_bombPylonWeapons pushBackUnique _pylonWeapon;
		};
		_aircraft setPylonLoadout [_pylonIndex,'',TRUE];
		_aircraft setAmmoOnPylon [_pylonIndex,0];
		_removed = _removed + 1;
	};
} forEach (getPylonMagazines _aircraft);

private _bombMagazines = [];
{
	_x params ['_magazine','_turret'];
	if ([_magazine] call _isBombMagazine) then {
		_bombMagazines pushBack [_magazine,_turret];
	};
} forEach (magazinesAllTurrets [_aircraft,TRUE]);
{
	_aircraft removeMagazineTurret _x;
	_removed = _removed + 1;
} forEach _bombMagazines;

{
	_aircraft removeWeaponGlobal _x;
} forEach _bombPylonWeapons;

_aircraft setVariable ['QS_enemyJet_bombsRemoved',_removed,FALSE];
_removed;
