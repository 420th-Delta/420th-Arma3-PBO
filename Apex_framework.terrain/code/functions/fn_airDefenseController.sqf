/* Public registration list includes JIP/HC owners; a UI client only restores human-controlled units. */
if (!isNil 'QS_airDefense_controller') exitWith {};
QS_airDefense_controller = [] spawn {
	private _managed = [];
	private _pendingRelease = [];
	while {TRUE} do {
		private _registry = missionNamespace getVariable ['QS_airDefense_vehicles',[]];
		private _live = _registry select {!isNull _x && {alive _x}};
		_pendingRelease append (_managed - _live);
		_pendingRelease = (_pendingRelease arrayIntersect _pendingRelease) select {!isNull _x};
		if (isServer) then {
			// owner is server-only; HC/UI owners need these IDs to retire remote acknowledgments.
			{
				private _savedUnits = (_x getVariable ['QS_airDefense_savedCrew',[]]) apply {_x # 0};
				private _units = (crew _x) + _savedUnits;
				{
					if (!isNull _x && {(owner _x) isNotEqualTo (_x getVariable ['QS_airDefense_ownerId',-1])}) then {
						_x setVariable ['QS_airDefense_ownerId',owner _x,TRUE];
					};
				} forEach (_units arrayIntersect _units);
			} forEach ((_live + _pendingRelease) arrayIntersect (_live + _pendingRelease));
		};
		{
			if (!isNull _x) then {[_x] call QS_fnc_airDefenseRelease;};
		} forEach (_pendingRelease - _live);
		_pendingRelease = _pendingRelease select {(_x getVariable ['QS_airDefense_savedCrew',[]]) isNotEqualTo []};
		_managed = _live;
		{
			private _vehicle = _x;
			if (local _vehicle) then {
				[_vehicle] call QS_fnc_airDefenseApply;
			} else {
				private _localSaved = (_vehicle getVariable ['QS_airDefense_savedCrew',[]]) select {local (_x # 0)};
				private _human = ((crew _vehicle) findIf {alive _x && {isPlayer _x || {!isNull remoteControlled _x}}}) >= 0;
				if (!isNil 'TGC_fnc_isPlayerControlled') then {_human = _human || {[_vehicle] call TGC_fnc_isPlayerControlled};};
				if (_localSaved isNotEqualTo [] && {_human}) then {
					[_vehicle] call QS_fnc_airDefenseRelease;
				};
			};
		} forEach _managed;
		if (isServer && {_managed isNotEqualTo _registry}) then {
			missionNamespace setVariable ['QS_airDefense_vehicles',_managed,TRUE];
		};
		uiSleep ((missionNamespace getVariable ['QS_missionConfig_airDefense_interval',3]) max 1);
	};
};
