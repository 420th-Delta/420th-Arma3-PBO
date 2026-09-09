/*/
File: fn_serverSetTeamFeature.sqf

Description:

	Set the global team-map or name-tag feature state without transmitting code
	through public variables. The fixed JIP IDs retain only the latest state.
__________________________________________________/*/

if (!isServer) exitWith {};

params [
	['_feature','',['']],
	['_enabled',TRUE,[TRUE]]
];

_feature = toUpperANSI _feature;
private _jipID = switch (_feature) do {
	case 'MAP_ICONS': {'QS_TEAM_FEATURE_MAP_ICONS'};
	case 'NAME_TAGS': {'QS_TEAM_FEATURE_NAME_TAGS'};
	default {''};
};

if (_jipID isEqualTo '') exitWith {};

[_feature,_enabled] remoteExecCall ['QS_fnc_clientSetTeamFeature',-2,_jipID];
