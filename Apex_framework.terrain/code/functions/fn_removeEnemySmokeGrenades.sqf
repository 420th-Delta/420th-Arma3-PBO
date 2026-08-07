/*
	File: fn_removeEnemySmokeGrenades.sqf

	Description:
		Remove all carried smoke grenades and grenade-launcher smoke rounds
		from enemy AI. Matches all color/mod variants that follow the
		SmokeShell* or *Rnd_Smoke*_Grenade_shell naming conventions.
*/

params [['_unit',objNull]];

if (
	isNull _unit ||
	{isPlayer _unit} ||
	{(!((side (group _unit)) in [EAST,RESISTANCE]))}
) exitWith {_unit};

{
	private _magazineType = toLowerANSI _x;
	if (
		((_magazineType find 'smokeshell') isEqualTo 0) ||
		{
			((_magazineType find 'rnd_smoke') > -1) &&
			{((_magazineType find '_grenade_shell') > -1)}
		}
	) then {
		_unit removeMagazines _x;
	};
} forEach (magazines _unit);

_unit
