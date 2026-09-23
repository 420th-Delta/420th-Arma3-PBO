/* Find the entire battery footprint before creating any assets. */
params [['_aoPosition',[]],['_deadline',diag_tickTime + 15]];
if ((count _aoPosition) < 2) exitWith {[]};
private _aoDistance = missionNamespace getVariable ['QS_missionConfig_priorityAA_aoDistance',[1200,3500]];
private _baseDistance = missionNamespace getVariable ['QS_missionConfig_priorityAA_baseDistance',5000];
private _satelliteCount = 0 max (floor (missionNamespace getVariable ['QS_missionConfig_priorityAA_satelliteCount',2])) min 2;
private _satelliteDistance = missionNamespace getVariable ['QS_missionConfig_priorityAA_satelliteDistance',[50,200]];
private _basePosition = markerPos 'QS_marker_base_marker';
private _fobPosition = markerPos 'QS_marker_module_fob';
private _blockedTerrain = ['TREE','SMALL TREE','BUILDING','HOUSE','ROCK','ROCKS','WALL','FENCE','POWER LINES','TRANSMITTER'];
private _validPosition = {
	params ['_position','_footprint'];
	if ((diag_tickTime >= _deadline) || {surfaceIsWater _position}) exitWith {FALSE};
	if ((_position distance2D _basePosition) < (_baseDistance + _footprint)) exitWith {FALSE};
	if ((_position distance2D _fobPosition) < (250 + _footprint)) exitWith {FALSE};
	if (!(_position inArea (missionNamespace getVariable 'QS_terrain_worldArea'))) exitWith {FALSE};
	if ((allPlayers findIf {alive _x && {(_position distance2D _x) < 300}}) isNotEqualTo -1) exitWith {FALSE};
	if ((_position isFlatEmpty [_footprint,0,0.2,_footprint,0,FALSE,objNull]) isEqualTo []) exitWith {FALSE};
	if ((nearestTerrainObjects [_position,_blockedTerrain,_footprint,FALSE,TRUE]) isNotEqualTo []) exitWith {FALSE};
	if ((_position nearRoads (_footprint + 5)) isNotEqualTo []) exitWith {FALSE};
	if ((toLowerANSI (surfaceType _position)) in ['#gdtasphalt']) exitWith {FALSE};
	!([_position,_footprint,12] call QS_fnc_waterInRadius)
};
private _result = [];
private _minimum = 500 max (_aoDistance # 0);
private _maximum = (_minimum + 100) max (_aoDistance # 1);
private _widenAt = diag_tickTime + (0.666 * (0 max (_deadline - diag_tickTime)));
private _satelliteMinimum = 50 max (_satelliteDistance # 0);
private _satelliteMaximum = (_satelliteMinimum + 25) max (_satelliteDistance # 1);
for '_attempt' from 1 to 300 do {
	if ((diag_tickTime >= _deadline) || {missionNamespace getVariable ['QS_priorityAA_abort',FALSE]}) exitWith {};
	private _searchMaximum = if (_attempt > 200 || {diag_tickTime >= _widenAt}) then {_maximum max 5000} else {_maximum};
	private _radius = sqrt ((_minimum * _minimum) + (random ((_searchMaximum * _searchMaximum) - (_minimum * _minimum))));
	private _position = _aoPosition getPos [_radius,random 360];
	if ([_position,32] call _validPosition) then {
		private _reserved = [[_position,32]];
		private _satellites = [];
		private _guards = [];
		for '_slot' from 0 to (_satelliteCount + 2) do {
			if (diag_tickTime >= _deadline) exitWith {};
			private _isSatellite = _slot < _satelliteCount;
			private _footprint = [9,12] select _isSatellite;
			private _range = [[50,250],[_satelliteMinimum,_satelliteMaximum]] select _isSatellite;
			private _found = [];
			for '_trial' from 1 to 30 do {
				if (diag_tickTime >= _deadline) exitWith {};
				private _candidate = _position getPos [(_range # 0) + random ((_range # 1) - (_range # 0)),random 360];
				if (
					((_reserved findIf {(_candidate distance2D (_x # 0)) < ((_x # 1) + _footprint + 5)}) isEqualTo -1) &&
					{[_candidate,_footprint] call _validPosition}
				) exitWith {_found = _candidate};
			};
			if (_found isEqualTo []) exitWith {};
			_reserved pushBack [_found,_footprint];
			if (_isSatellite) then {_satellites pushBack _found} else {_guards pushBack _found};
		};
		if (((count _satellites) isEqualTo _satelliteCount) && {(count _guards) isEqualTo 3}) exitWith {
			_result = [_position,_satellites,_guards,random 360];
		};
	};
	if (_result isNotEqualTo []) exitWith {};
	if (canSuspend && {(_attempt mod 10) isEqualTo 0}) then {uiSleep 0.01};
};
_result
