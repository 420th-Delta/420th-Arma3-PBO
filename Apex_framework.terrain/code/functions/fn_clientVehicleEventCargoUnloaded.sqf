/*/
File: fn_clientVehicleEventCargoUnloaded.sqf
Author:

	Quiksilver
	
Last Modified:

	18/04/2022 2.08 by Quiksilver
	
Description:

	Cargo Unloaded event
_______________________________________________________/*/

params ['_parentVehicle','_cargoVehicle'];
if (isNull _parentVehicle) exitWith {};

private _transaction = (_parentVehicle getVariable ['QS_clientCargoUnload_transaction',0]) + 1;
_parentVehicle setVariable ['QS_clientCargoUnload_transaction',_transaction,FALSE];

[_parentVehicle,_transaction] spawn {
	params ['_parentVehicle','_transaction'];
	uiSleep 0.05;
	if (
		(!isNull _parentVehicle) &&
		{local _parentVehicle} &&
		{(_parentVehicle getVariable ['QS_clientCargoUnload_transaction',-1]) isEqualTo _transaction}
	) then {
		[_parentVehicle,TRUE,TRUE] call QS_fnc_updateCenterOfMass;
	};
};
