// Focused capability investigation after the full default/native survey.
// Negative observations remain visible; this case does not require a positive.
T420_AA_datalinkSourceFilter = [
	'neophron_classic_cas','uav_ababil_defend','uav_greyhawk_defend_native',
	'uav_sentinel_defend','kajman_classic_escort'
];
T420_AA_datalinkRequireCurrentLaunch = FALSE;
call compile preprocessFileLineNumbers 'datalink.sqf';
T420_AA_datalinkSourceFilter = nil;
T420_AA_datalinkRequireCurrentLaunch = nil;
TRUE
