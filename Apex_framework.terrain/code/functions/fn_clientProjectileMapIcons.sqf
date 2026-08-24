/*/
File: fn_clientProjectileMapIcons.sqf

Description:

	Draw tracked projectile icons on the main map independently of the disabled
	Soldier Tracker (fn_icons.sqf).
____________________________________________________________/*/

if (isDedicated || {!hasInterface}) exitWith {};

waitUntil {
	uiSleep 0.1;
	!isNull ((findDisplay 12) displayCtrl 51)
};

private _mapControl = (findDisplay 12) displayCtrl 51;
private _existingEventHandler = missionNamespace getVariable ['QS_projectileMapIcons_EH',-1];
if (_existingEventHandler isNotEqualTo -1) then {
	_mapControl ctrlRemoveEventHandler ['Draw',_existingEventHandler];
};

private _eventHandler = _mapControl ctrlAddEventHandler [
	'Draw',
	{
		params ['_mapControl'];
		private _projectiles = missionNamespace getVariable ['QS_draw2D_projectiles',[]];
		if (_projectiles isEqualTo []) exitWith {};

		private _direction = ((ceil diag_tickTime) - diag_tickTime) * 360;
		{
			if ((_x isEqualType objNull) && {!isNull _x}) then {
				private _position = getPosWorldVisual _x;
				if (
					(finite (_position # 0)) &&
					{finite (_position # 1)} &&
					{finite (_position # 2)} &&
					{finite _direction}
				) then {
					_mapControl drawIcon [
						'a3\ui_f\data\igui\cfg\cursors\explosive_ca.paa',
						[1,0,0,0.75],
						_position,
						13,
						13,
						_direction,
						'',
						0,
						0,
						'RobotoCondensed',
						'right'
					];
				};
			};
		} forEach _projectiles;
	}
];

missionNamespace setVariable ['QS_projectileMapIcons_EH',_eventHandler,FALSE];
