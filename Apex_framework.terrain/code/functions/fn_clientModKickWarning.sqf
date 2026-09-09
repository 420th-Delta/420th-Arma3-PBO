/*
File: fn_clientModKickWarning.sqf

Description:

	Show a pre-kick warning without using RscMsgBox, which client warning
	suppressor mods may close before the engine populates the kick reason.
__________________________________________________*/

if ((!hasInterface) || {!isRemoteExecuted} || {remoteExecutedOwner isNotEqualTo 2}) exitWith {};

params [['_message','',['']]];
if (_message isEqualTo '') exitWith {};

private _warning = format ['%1\n\nYou will be disconnected in 5 seconds.',_message];
'QS_ModKickWarning' cutText [_warning,'BLACK FADED',0.1,TRUE,FALSE,TRUE];
