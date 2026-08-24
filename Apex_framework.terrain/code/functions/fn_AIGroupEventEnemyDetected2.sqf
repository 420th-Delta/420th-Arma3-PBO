/*/
File: fn_AIGroupEventEnemyDetected2.sqf
Author:

	Quiksilver
	
Last Modified:

	25/08/2022 A3 2.10 by Quiksilver
	
Description:

	AI Intel Collectors (Aircraft, etc)
		- Target
		- Time seen
		- Position seen
		- Level of knowledge
		- Last group to report info
		- Is target on ground
___________________________________________/*/

params [['_grp',grpNull],['_target',objNull]];
if ((isNull _grp) || {isNull _target}) exitWith {};
if (serverTime < (_grp getVariable ['QS_AI_GRP_intelED_cooldown',-1])) exitWith {};
_grp setVariable ['QS_AI_GRP_intelED_cooldown',serverTime + 5,FALSE];
([_target,'SAFE'] call QS_fnc_inZone) params ['_inSafezone','_safezoneLevel','_safezoneActive'];
if (_inSafezone && _safezoneActive && (_safezoneLevel > 1)) exitWith {};
private _leader = leader _grp;
if (isNull _leader) exitWith {};
private _intelDelta = [
	_target,
	serverTime,
	ASLToAGL ((_leader targetKnowledge _target) # 6),
	_grp knowsAbout _target,
	_grp,
	isTouchingGround _target,
	rating _target
];
if (isServer) then {
	_intelDelta call (missionNamespace getVariable 'QS_fnc_serverAIIntelDelta');
} else {
	_intelDelta remoteExecCall ['QS_fnc_serverAIIntelDelta',2,FALSE];
};
