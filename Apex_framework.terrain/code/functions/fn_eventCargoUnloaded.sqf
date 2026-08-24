/*
File: fn_eventCargoUnloaded.sqf
Author:

	Quiksilver
	
Last modified:

	28/01/2023 A3 2.12 by Quiksilver
	
Description:

	Server Cargo Unloaded
__________________________________________________*/

params ['_parent','_child',['_isCustom',FALSE]];

private _transaction = -1;
if (!isNull _parent) then {
	_transaction = (_parent getVariable ['QS_cargoUnload_transaction',0]) + 1;
	_parent setVariable ['QS_cargoUnload_transaction',_transaction,FALSE];
};

[_parent,_child,_isCustom,_transaction] spawn {
	params ['_parent','_child','_isCustom','_transaction'];
	uiSleep 0.05;

	if (
		(!isNull _parent) &&
		{(_parent getVariable ['QS_cargoUnload_transaction',-1]) isEqualTo _transaction}
	) then {
		[_parent,_child,_isCustom] remoteExec ['QS_fnc_finishCargoParentUnload',_parent,FALSE];
	};

	if (!isNull _child) then {
		[_child] remoteExec ['QS_fnc_finishCargoChildUnload',_child,FALSE];
	};
};
