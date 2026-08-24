/*/
File: fn_serverRestart.sqf
Author:
	
	Quiksilver
	
Last Modified:

	21/10/2023 A3 2.14 by Quiksilver
	
Description:

	Server Restart procedure
______________________________________________________/*/

if (isRemoteExecuted) exitWith {};
scriptName 'QS Restart Procedure';
//comment 'Play unique sound here as a hint';
['playSound','QS_restart'] remoteExec ['QS_fnc_remoteExecCmd',-2,FALSE];
uiSleep 25;		// Roughly 30 second procedure
_text = localize 'STR_QS_Notif_044';
['System',['',_text]] remoteExec ['QS_fnc_showNotification',-2,FALSE];
// Server Restart message
{} remoteExec ['call',-2,FALSE];
missionProfileNamespace setVariable ['QS_leaderboards2',(missionNamespace getVariable 'QS_leaderboards2')];	// Leaderboards persistence
{
	_x setVariable ['QS_respawn_disable',-1,TRUE];
} forEach allPlayers;
uiSleep 4;
saveMissionProfileNamespace;
uiSleep 1;
(call (uiNamespace getVariable 'QS_fnc_serverCommandPassword')) serverCommand '#restartserver';
