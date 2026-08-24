/*/
File: fn_scBrief.sqf
Author: 

	Quiksilver

Last Modified:

	17/05/2017 A3 1.70 by Quiksilver

Description:

	Aware clients
____________________________________________________________________________/*/

params ['_type','_data'];
if (_type isEqualTo 0) exitWith {
	_data params ['_scWinningSide','_duration'];
	{
		_x setMarkerColorLocal 'ColorOPFOR';
		_x setMarkerAlpha 0;
	} forEach [
		'QS_marker_aoCircle',
		'QS_marker_aoMarker'
	];
	missionNamespace setVariable ['QS_missionStatus_SC_canShow',FALSE,TRUE];
	//comment 'Communicate here';
	if (_scWinningSide in [0,2]) then {
		//comment 'Mission failed!';
		['SC_EXIT_BAD',['',localize 'STR_QS_Notif_065']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
		[[],{playSound 'QS_SC_outro_lose';}] remoteExec ['spawn',-2,FALSE];
	} else {
		//comment 'Mission complete!';
		['SC_EXIT_GOOD',['',localize 'STR_QS_Notif_066']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
		[[],{playSound 'QS_SC_outro_win';}] remoteExec ['spawn',-2,FALSE];
	};
};
if (_type isEqualTo 1) exitWith {
	{
		_x params [
			'_flagData',
			'_sectorAreaObjects',
			'_locationData',
			'_objectData',
			'_markerData',
			'_taskData'
		];
		{
			_x setMarkerAlpha 0.75;
		} count _markerData;
	} forEach _data;
	{
		_x setMarkerColorLocal 'ColorOPFOR';
		_x setMarkerAlpha 0.8;
	} forEach [
		'QS_marker_aoCircle',
		'QS_marker_aoMarker'
	];
	if ((missionNamespace getVariable 'QS_virtualSectors_sub_1_markers') isNotEqualTo []) then {
		{
			_x setMarkerColorLocal 'ColorOPFOR';
			_x setMarkerAlpha 0.5;
		} forEach (missionNamespace getVariable 'QS_virtualSectors_sub_1_markers');
	};
	if ((missionNamespace getVariable 'QS_virtualSectors_sub_2_markers') isNotEqualTo []) then {
		{
			_x setMarkerColorLocal 'ColorOPFOR';
			_x setMarkerAlpha 0.5;
		} forEach (missionNamespace getVariable 'QS_virtualSectors_sub_2_markers');
	};
	if ((missionNamespace getVariable 'QS_virtualSectors_sub_3_markers') isNotEqualTo []) then {
		{
			_x setMarkerColorLocal 'ColorOPFOR';
			_x setMarkerAlpha 0.5;
		} forEach (missionNamespace getVariable 'QS_virtualSectors_sub_3_markers');
	};
	if ((missionNamespace getVariable 'QS_ao_aaMarkers') isNotEqualTo []) then {
		{
			if (_x in allMapMarkers) then {
				_x setMarkerAlpha 0.5;
			};
		} forEach (missionNamespace getVariable 'QS_ao_aaMarkers');
	};
	if ((missionNamespace getVariable 'QS_virtualSectors_siteMarkers') isNotEqualTo []) then {
		{
			_x setMarkerAlpha 0.5;
		} forEach (missionNamespace getVariable 'QS_virtualSectors_siteMarkers');
	};
	//comment 'Communicate here';	
	['SC_INIT',['',localize 'STR_QS_Notif_075']] remoteExec ['QS_fnc_showNotification',-2,FALSE];
	missionNamespace setVariable ['QS_missionStatus_SC_canShow',TRUE,TRUE];
};
