/*
File: fn_eventBuildingChanged.sqf
Author:

	Quiksilver
	
Last modified:

	9/10/2023 A3 2.14 by Quiksilver
	
Description:

	Building Changed event
	
	Need to be careful that we aren't deleting terrain object ruins
__________________________________________________*/

params ['_changedFrom','_changedTo','_isRuin'];
if (_isRuin) then {
	if (_changedTo isKindOf 'Land_TTowerBig_2_ruins_F') then {
		(missionNamespace getVariable 'QS_garbageCollector') pushBack [_changedTo,'NOW_DISCREET',(time + 120)];
	};
	if (QS_list_playerBuildables isNotEqualTo []) then {
		private _queue = missionNamespace getVariable ['QS_buildingChanged_cleanupQueue',[]];
		_queue pushBackUnique _changedTo;
		if ((count _queue) > 64) then {
			_queue = _queue select [((count _queue) - 64),64];
		};
		missionNamespace setVariable ['QS_buildingChanged_cleanupQueue',_queue,FALSE];
		if (!(missionNamespace getVariable ['QS_buildingChanged_cleanupRunning',FALSE])) then {
			missionNamespace setVariable ['QS_buildingChanged_cleanupRunning',TRUE,FALSE];
			[] spawn {
				while {(missionNamespace getVariable ['QS_buildingChanged_cleanupQueue',[]]) isNotEqualTo []} do {
					private _queue = missionNamespace getVariable ['QS_buildingChanged_cleanupQueue',[]];
					private _changedTo = _queue deleteAt 0;
					missionNamespace setVariable ['QS_buildingChanged_cleanupQueue',_queue,FALSE];
					if (!isNull _changedTo) then {
						(0 boundingBoxReal _changedTo) params ['','','_radius'];
						private _buildables = +(missionNamespace getVariable ['QS_list_playerBuildables',[]]);
						for '_index' from 0 to ((count _buildables) - 1) step 1 do {
							private _buildable = _buildables # _index;
							if ((!isNull _buildable) && {_buildable inArea [_changedTo,_radius,_radius,0,FALSE]}) then {
								deleteVehicle _buildable;
							};
							if ((_index mod 32) isEqualTo 31) then {
								uiSleep 0.005;
							};
						};
					};
					uiSleep 0.01;
				};
				missionNamespace setVariable ['QS_buildingChanged_cleanupRunning',FALSE,FALSE];
			};
		};
	};
};
if (_changedFrom isEqualTo (missionNamespace getVariable ['QS_sidemission_building',objNull])) then {
	if (_isRuin) then {
		missionNamespace setVariable ['QS_sidemission_buildingDestroyed',TRUE,FALSE];
	};
};
