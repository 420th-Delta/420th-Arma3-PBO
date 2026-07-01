/* Player-owned vehicle seat access and persistent access dialog. */
params ['_mode',['_arg1',objNull],['_arg2',''],['_arg3',objNull],['_arg4',[]]];

private _seatGroup = {
	params ['_role','_personTurret'];
	_role = toLowerANSI _role;
	if (_role isEqualTo 'driver') exitWith {'driver'};
	if (_role isEqualTo 'commander') exitWith {'commander'};
	if ((_role isEqualTo 'cargo') || {_personTurret}) exitWith {'passenger'};
	'gunner'
};

if (_mode isEqualTo 'CHECK') exitWith {
	private _unit = _arg1;
	private _role = _arg2;
	private _vehicle = _arg3;
	private _ownerUID = _vehicle getVariable ['QS_vehicleAccess_ownerUID',''];
	if ((_ownerUID isEqualTo '') || {(getPlayerUID _unit) isEqualTo _ownerUID}) exitWith {};
	private _crewEntry = (fullCrew [_vehicle,'',FALSE]) select {(_x # 0) isEqualTo _unit};
	private _personTurret = if (_crewEntry isEqualTo []) then {FALSE} else {(_crewEntry # 0) # 4};
	private _group = [_role,_personTurret] call _seatGroup;
	if (_vehicle getVariable [format ['QS_vehicleAccess_%1Locked',_group],FALSE]) then {
		['moveOut',_unit,_vehicle] remoteExec ['QS_fnc_remoteExecCmd',_unit,FALSE];
	};
};

if (_mode isEqualTo 'REMOVE_ACTIONS') exitWith {
	{ if (_x in (actionIDs player)) then {player removeAction _x;}; } forEach (localNamespace getVariable ['QS_vehicleAccess_actions',[]]);
	localNamespace setVariable ['QS_vehicleAccess_actions',[]];
};

if (_mode isEqualTo 'ACTIONS') exitWith {
	['REMOVE_ACTIONS'] call QS_fnc_clientVehicleAccess;
	private _vehicle = _arg1;
	private _take = player addAction ['Take Ownership',{
		private _vehicle = objectParent player;
		if (isNull _vehicle) exitWith {};
		_vehicle setVariable ['QS_vehicleAccess_ownerUID',getPlayerUID player,TRUE];
		_vehicle setVariable ['QS_vehicleAccess_driverLocked',TRUE,TRUE];
		['ACTIONS',_vehicle] call QS_fnc_clientVehicleAccess;
	},nil,6,FALSE,TRUE,'','private _v = objectParent player; !isNull _v && {player isEqualTo driver _v} && {(_v getVariable [''QS_vehicleAccess_ownerUID'','''']) isEqualTo ''''}'];
	private _access = player addAction ['Vehicle Access',{
		uiNamespace setVariable ['QS_vehicleAccess_vehicle',objectParent player];
		createDialog 'QS_RD_client_dialog_vehicle_access';
	},nil,5,FALSE,TRUE,'','private _v = objectParent player; !isNull _v && {(_v getVariable [''QS_vehicleAccess_ownerUID'','''']) isEqualTo getPlayerUID player}'];
	localNamespace setVariable ['QS_vehicleAccess_actions',[_take,_access]];
};

if (_mode isEqualTo 'LOAD') exitWith {
	uiNamespace setVariable ['QS_vehicleAccess_display',_arg1];
	['REFRESH'] call QS_fnc_clientVehicleAccess;
};

private _vehicle = uiNamespace getVariable ['QS_vehicleAccess_vehicle',objNull];
if (isNull _vehicle || {!alive _vehicle} || {(_vehicle getVariable ['QS_vehicleAccess_ownerUID','']) isNotEqualTo getPlayerUID player}) exitWith {closeDialog 2;};

if (_mode isEqualTo 'REFRESH') exitWith {
	private _display = uiNamespace getVariable ['QS_vehicleAccess_display',displayNull];
	private _crew = fullCrew [_vehicle,'',TRUE];
	{
		_x params ['_group','_idc'];
		private _exists = switch _group do {
			case 'driver': {TRUE};
			case 'commander': {(_crew findIf {toLowerANSI (_x # 1) isEqualTo 'commander'}) >= 0};
			case 'passenger': {(_crew findIf {(toLowerANSI (_x # 1) isEqualTo 'cargo') || {_x # 4}}) >= 0};
			default {(_crew findIf {private _r = toLowerANSI (_x # 1); (_r in ['gunner','turret']) && {!(_x # 4)}}) >= 0};
		};
		private _control = _display displayCtrl _idc;
		_control ctrlShow _exists;
		_control ctrlEnable _exists;
		_control ctrlSetText format ['%1: %2',toUpper (_group select [0,1]) + (_group select [1]),['Unlocked','Locked'] select (_vehicle getVariable [format ['QS_vehicleAccess_%1Locked',_group],FALSE])];
	} forEach [['driver',42012],['gunner',42013],['commander',42014],['passenger',42015]];
};

if (_mode isEqualTo 'TOGGLE') exitWith {
	private _key = format ['QS_vehicleAccess_%1Locked',_arg1];
	_vehicle setVariable [_key,!(_vehicle getVariable [_key,FALSE]),TRUE];
	['REFRESH'] call QS_fnc_clientVehicleAccess;
};

if (_mode isEqualTo 'EJECT') exitWith {
	if ((_vehicle isKindOf 'Air') && {((getPosATL _vehicle) # 2) > 10}) exitWith {systemChat 'Ejection is disabled while the aircraft is more than 10 meters above ground level.';};
	{
		_x params ['_unit','_role','','','_personTurret'];
		private _group = [_role,_personTurret] call _seatGroup;
		if (!isNull _unit && {(_arg1 isEqualTo 'exceptDriver') || {_group isEqualTo 'passenger'}} && {!((_arg1 isEqualTo 'exceptDriver') && {_group isEqualTo 'driver'})}) then {
			['moveOut',_unit,_vehicle] remoteExec ['QS_fnc_remoteExecCmd',_unit,FALSE];
		};
	} forEach (fullCrew [_vehicle,'',FALSE]);
};
