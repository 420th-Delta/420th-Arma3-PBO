/*/
File: fn_AIXMissileCountermeasure.sqf
Author:

	Quiksilver
	
Last Modified:

	14/1/2023 A3 2.10 by Quiksilver
	
Description:

	Missile countermeasures for AI
_________________________________________________/*/

params ['_vehicle','','_shooter','_instigator','_projectile'];
// Added Code
// Managed combat flights react to missile warnings on their owning machine.
// A real flare burst consumes the installed launcher ammunition; missile
// guidance, countermeasure resistance and the pilot's maneuver remain native.
if ((group (driver _vehicle)) getVariable ['QS_combatAir_managed',FALSE]) exitWith {
	private _pilot = driver _vehicle;
	if (!local _vehicle || {!alive _pilot} || {isPlayer _pilot} || {captive _pilot} || {((crew _vehicle) findIf {isPlayer _x || {!isNull (_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}) >= 0}) exitWith {};
	private _flight = group _pilot;
	// Cancel through the native finalizer before the flight can intercept.
	// It owns and deletes its laser/assistant; no second mover takes over early.
	if (!isNull _projectile && {!isNil {_flight getVariable 'QS_AI_GRP_fireMission'}}) then {
		_flight setVariable ['QS_AI_GRP_fireMission',nil,QS_system_AI_owners];
	};
	private _attacker = vehicle _shooter;
	if (_attacker isKindOf 'Air') then {
		_vehicle setVariable ['QS_combatAir_threat',[_attacker,serverTime + 30],FALSE];
		_flight setVariable ['QS_combatAir_nextCheck',0,FALSE];
	};
	if (serverTime >= (_vehicle getVariable ['QS_combatAir_flareAfter',0])) then {
		private _launchers = (weapons _vehicle) select {_x isKindOf ['CMFlareLauncher',configFile >> 'CfgWeapons']};
		if (_launchers isNotEqualTo []) then {
			private _weapon = _launchers # 0;
			private _modes = getArray (configFile >> 'CfgWeapons' >> _weapon >> 'modes');
			private _mode = if ('AIBurst' in _modes) then {'AIBurst'} else {_modes param [0,'this']};
			if ((_vehicle ammo _weapon) > 0) then {
				_pilot forceWeaponFire [_weapon,_mode];
				_vehicle setVariable ['QS_combatAir_flareAfter',serverTime + 3,FALSE];
			};
		};
	};
};
// End Updated Code
if (alive (effectiveCommander _vehicle)) then {
	if (
		(_vehicle isKindOf 'Air') &&
		{(!isNull _projectile)} &&
		{(isNull (objectParent _instigator))} &&
		{((_vehicle distance _shooter) > 1000)} &&
		{((!((vehicle _shooter) isKindOf 'CAManBase')) && (!((vehicle _shooter) isKindOf 'Static')))} &&
		{((random 1) > ([0.75,0.5] select ((count allPlayers) > 15)))}
	) then {
		(group (effectiveCommander _vehicle)) reveal [_shooter,4];
		(group (effectiveCommander _vehicle)) reveal [vehicle _shooter,4];
		if ((random 1) > 0.5) then {
			[_projectile,objNull] remoteExec ['setMissileTarget',_shooter,FALSE];
			(driver _vehicle) spawn {
				scriptName 'QS Incoming Missile Flares';
				_this forceWeaponFire ['CMFlareLauncher','AIBurst'];
				sleep 1;
				_this forceWeaponFire ['CMFlareLauncher','AIBurst'];
				sleep 1;
				_this forceWeaponFire ['CMFlareLauncher','AIBurst'];
			};
		} else {
			[_vehicle,_shooter,_projectile] spawn {
				params ['_vehicle','_shooter','_projectile'];
				_timeout = diag_tickTime + 15;
				waitUntil {
					uiSleep 0.1;
					(((_projectile distance _vehicle) < 150) || {(isNull _projectile)} || {(diag_tickTime >= _timeout)})
				};
				if (!isNull _projectile) then {
					if (diag_tickTime < _timeout) then {
						(driver _vehicle) spawn {
							scriptName 'QS Incoming Missile Flares';
							_this forceWeaponFire ['CMFlareLauncher','AIBurst'];
							sleep 1;
							_this forceWeaponFire ['CMFlareLauncher','AIBurst'];
							sleep 1;
							_this forceWeaponFire ['CMFlareLauncher','AIBurst'];
						};
						[_projectile,objNull] remoteExecCall ['setMissileTarget',_shooter,FALSE];
					};
				};
			};
		};
	};
	if (_vehicle isKindOf 'LandVehicle') then {
		if (alive (effectiveCommander _vehicle)) then {
			if (_vehicle isKindOf 'mbt_04_base_f') then {
				(crew _vehicle) doWatch (getPosATL _shooter);
			};
			if (_vehicle isKindOf 'Tank') then {
				_grp = group (effectiveCommander _vehicle);
				if (!isNull _grp) then {
					{
						_grp reveal _x;
					} forEach [
						[_shooter,4],
						[vehicle _shooter,4],
						[_instigator,4],
						[vehicle _instigator,4]
					];
				};
			};
		};
	};
};
