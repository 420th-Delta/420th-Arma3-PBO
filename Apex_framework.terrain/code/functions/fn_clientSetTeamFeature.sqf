/*/
File: fn_clientSetTeamFeature.sqf

Description:

	Apply the latest global team-map or name-tag feature state locally.
__________________________________________________/*/

if (!hasInterface) exitWith {};

params [
	['_feature','',['']],
	['_enabled',TRUE,[TRUE]]
];

[_feature,_enabled] spawn {
	params ['_feature','_enabled'];
	private _functionName = switch (toUpperANSI _feature) do {
		case 'MAP_ICONS': {
			['QS_fnc_teamMapIconsDisable','QS_fnc_teamMapIconsEnable'] select _enabled
		};
		case 'NAME_TAGS': {
			['QS_fnc_teamNameTagsDisable','QS_fnc_teamNameTagsEnable'] select _enabled
		};
		default {''};
	};
	if (_functionName isEqualTo '') exitWith {};
	waitUntil {
		uiSleep 0.1;
		!isNil {missionNamespace getVariable _functionName}
	};
	[] call (missionNamespace getVariable _functionName);
};
