// Final normal fast-jet variant: an emitting NATO F/A-181, native sensors only.
// Negative observations remain findings; RWR warnings alone are not a shared track.
T420_AA_datalinkSourceFilter = [
	'neophron_classic_cas','uav_ababil_defend','uav_greyhawk_defend_native',
	'uav_sentinel_defend','kajman_classic_escort'
];
T420_AA_datalinkRequireCurrentLaunch = FALSE;
T420_AA_datalinkTargetClass = 'B_Plane_Fighter_01_F';
T420_AA_datalinkTargetRadar = 1;
T420_AA_datalinkSenderAhead = TRUE;
T420_AA_datalinkConfigOnly = ['B_APC_Tracked_01_AA_F','O_T_VTOL_02_infantry_dynamicLoadout_F'];
call compile preprocessFileLineNumbers 'datalink.sqf';
T420_AA_datalinkSourceFilter = nil;
T420_AA_datalinkRequireCurrentLaunch = nil;
T420_AA_datalinkTargetClass = nil;
T420_AA_datalinkTargetRadar = nil;
T420_AA_datalinkSenderAhead = nil;
T420_AA_datalinkConfigOnly = nil;
TRUE
