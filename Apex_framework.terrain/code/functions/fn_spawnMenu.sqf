/*
	Client controller for the role-filtered Spawn Menu dialog.
*/
params [
	['_mode','',['']],
	['_arg1',objNull],
	['_arg2',-1]
];

if (!hasInterface) exitWith {};

if (_mode isEqualTo 'CAN_ACCESS') exitWith {
	private _terminal = _arg1;
	private _unit = _arg2;
	if (isNull _terminal || {isNull _unit}) exitWith {FALSE};

	private _role = toLowerANSI (_unit getVariable ['QS_unit_role','rifleman']);
	if (_role isEqualTo 'staff') exitWith {TRUE};

	private _allowedRoles = _terminal getVariable ['QS_spawnMenu_allowedRoles',[]];
	if (_allowedRoles isEqualType '') then {
		_allowedRoles = [_allowedRoles];
	};
	if !(_allowedRoles isEqualType []) exitWith {FALSE};
	if ((_allowedRoles findIf {!(_x isEqualType '')}) isNotEqualTo -1) exitWith {FALSE};
	if (_allowedRoles isEqualTo []) exitWith {TRUE};

	_role in (_allowedRoles apply {toLowerANSI _x})
};

if (_mode isEqualTo 'OPEN') exitWith {
	private _terminal = _arg1;
	if (isNull _terminal || {!(_terminal getVariable ['QS_spawnMenu_terminal',FALSE])}) exitWith {};
	if (!(['CAN_ACCESS',_terminal,player] call QS_fnc_spawnMenu)) exitWith {
		systemChat 'Spawn Menu: your current role cannot use this terminal.';
	};

	private _terminalID = toLowerANSI (_terminal getVariable ['QS_spawnMenu_id','']);
	private _spawnPoints = (allMissionObjects 'All') select {
		(_x getVariable ['QS_spawnMenu_spawnPoint',FALSE]) &&
		{
			(_terminalID isEqualTo '') ||
			{(toLowerANSI (_x getVariable ['QS_spawnMenu_id',''])) isEqualTo _terminalID}
		}
	};
	if (_spawnPoints isEqualTo []) exitWith {
		systemChat format [
			'Spawn Menu: no spawn point is configured%1.',
			['',format [' for ID "%1"',_terminalID]] select (_terminalID isNotEqualTo '')
		];
	};

	private _spawnPoint = objNull;
	private _distance = 1e10;
	{
		private _testDistance = _terminal distance2D _x;
		if (_testDistance < _distance) then {
			_distance = _testDistance;
			_spawnPoint = _x;
		};
	} forEach _spawnPoints;

	uiNamespace setVariable ['QS_spawnMenu_terminal',_terminal];
	uiNamespace setVariable ['QS_spawnMenu_spawnPoint',_spawnPoint];
	uiNamespace setVariable ['QS_spawnMenu_id',_terminalID];
	createDialog 'QS_RD_client_dialog_spawnMenu';
};

if (_mode isEqualTo 'LOAD') exitWith {
	private _display = _arg1;
	uiNamespace setVariable ['QS_spawnMenu_display',_display];
	private _supplyCrateClasses = ['loadable_cargo_objects_1'] call QS_data_listVehicles;

	private _role = player getVariable ['QS_unit_role','rifleman'];
	private _roleName = player getVariable ['QS_unit_role_displayName',_role];
	(_display displayCtrl 42101) ctrlSetText format ['Role: %1',_roleName];

	if (isNil {uiNamespace getVariable 'QS_spawnMenu_vehicleCatalog'}) then {
		private _catalog = [];
		{
			private _class = configName _x;
			private _displayName = switch (_class) do {
				case 'Land_Cargo10_military_green_F': {'Combat Outpost'};
				case 'Land_Cargo10_grey_F': {'Forward Operating Base'};
				case 'Land_Cargo10_light_green_F': {'Patrol Base'};
				case 'Land_Cargo10_white_F': {'Mobile Respawn'};
				case 'Land_Cargo10_sand_F': {'Platform Module'};
				case 'Land_Cargo10_yellow_F': {'Terrain Leveler'};
				case 'Land_Cargo10_blue_F': {'MIM-145 Defender'};
				case 'Land_Cargo10_cyan_F': {'AN/MPQ-105 Radar'};
				default {getText (_x >> 'displayName')};
			};
			if (
				_displayName isNotEqualTo '' &&
				{
					(_class isKindOf 'LandVehicle') ||
					{(_class isKindOf 'Ship')} ||
					{(_class isKindOf 'Helicopter')} ||
					{(_class isKindOf 'Plane')} ||
					{(_class isKindOf 'CAManBase')} ||
					{(_class isKindOf 'ReammoBox_F')} ||
					{(toLowerANSI _class) in _supplyCrateClasses} ||
					{
						(['Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F'] findIf {
							_class isKindOf _x
						}) isNotEqualTo -1
					}
				}
			) then {
				private _category = if (_class isKindOf 'CAManBase') then {
					'AI'
				} else {
					if (
						(_class isKindOf 'ReammoBox_F') ||
						{(toLowerANSI _class) in _supplyCrateClasses} ||
						{
							(['Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F'] findIf {
								_class isKindOf _x
							}) isNotEqualTo -1
						}
					) then {
						'Supply'
					} else {
						if (_class isKindOf 'Ship') then {
							'Boat'
						} else {
							if (_class isKindOf 'LandVehicle') then {
								'Ground'
							} else {
								if (_class isKindOf 'VTOL_Base_F') then {
									'VTOL'
								} else {
									['Plane','Helicopter'] select (_class isKindOf 'Helicopter')
								}
							}
						}
					}
				};
				_catalog pushBack [
					toLowerANSI _displayName,
					_displayName,
					_class,
					getText (_x >> 'editorPreview'),
					getText (_x >> 'picture'),
					_category,
					getNumber (_x >> 'transportSoldier')
				];
			};
		} forEach ('(getNumber (_x >> "scope")) >= 1' configClasses (configFile >> 'CfgVehicles'));
		_catalog sort TRUE;
		uiNamespace setVariable ['QS_spawnMenu_vehicleCatalog',_catalog];
	};

	private _terminal = uiNamespace getVariable ['QS_spawnMenu_terminal',objNull];
	private _hasVehicleWhitelist = !isNull _terminal && {!isNil {_terminal getVariable 'QS_spawnMenu_vehicleClasses'}};
	private _vehicleWhitelist = if (_hasVehicleWhitelist) then {
		_terminal getVariable ['QS_spawnMenu_vehicleClasses',[]]
	} else {
		[]
	};
	if !(_vehicleWhitelist isEqualType []) then {
		_vehicleWhitelist = [];
		_hasVehicleWhitelist = TRUE;
	};
	if ((_vehicleWhitelist findIf {!(_x isEqualType '')}) isNotEqualTo -1) then {
		_vehicleWhitelist = [];
	};
	if (_hasVehicleWhitelist) then {
		private _catalog = +(uiNamespace getVariable ['QS_spawnMenu_vehicleCatalog',[]]);
		{
			private _class = _x;
			if ((_catalog findIf {(toLowerANSI (_x # 2)) isEqualTo (toLowerANSI _class)}) isEqualTo -1) then {
				private _config = configFile >> 'CfgVehicles' >> _class;
				if (
					isClass _config &&
					{[_class,TRUE] call QS_fnc_spawnMenuVehicleAllowed}
				) then {
					private _displayName = switch (_class) do {
						case 'Land_Cargo10_military_green_F': {'Combat Outpost'};
						case 'Land_Cargo10_grey_F': {'Forward Operating Base'};
						case 'Land_Cargo10_light_green_F': {'Patrol Base'};
						case 'Land_Cargo10_white_F': {'Mobile Respawn'};
						case 'Land_Cargo10_sand_F': {'Platform Module'};
						case 'Land_Cargo10_yellow_F': {'Terrain Leveler'};
						case 'Land_Cargo10_blue_F': {'MIM-145 Defender'};
						case 'Land_Cargo10_cyan_F': {'AN/MPQ-105 Radar'};
						default {getText (_config >> 'displayName')};
					};
					if (_displayName isEqualTo '') then {
						_displayName = _class;
					};
					private _category = if (_class isKindOf 'CAManBase') then {
						'AI'
					} else {
						if (
							(_class isKindOf 'ReammoBox_F') ||
							{(toLowerANSI _class) in _supplyCrateClasses} ||
							{
								(['Cargo_base_F','Slingload_01_Base_F','Pod_Heli_Transport_04_base_F'] findIf {
									_class isKindOf _x
								}) isNotEqualTo -1
							}
						) then {
							'Supply'
						} else {
							if (_class isKindOf 'Ship') then {
								'Boat'
							} else {
								if (_class isKindOf 'LandVehicle') then {
									'Ground'
								} else {
									if (_class isKindOf 'VTOL_Base_F') then {
										'VTOL'
									} else {
										['Plane','Helicopter'] select (_class isKindOf 'Helicopter')
									}
								}
							}
						}
					};
					_catalog pushBack [
						toLowerANSI _displayName,
						_displayName,
						_class,
						getText (_config >> 'editorPreview'),
						getText (_config >> 'picture'),
						_category,
						getNumber (_config >> 'transportSoldier')
					];
				};
			};
		} forEach _vehicleWhitelist;
		_catalog sort TRUE;
		uiNamespace setVariable ['QS_spawnMenu_vehicleCatalog',_catalog];
	};
	private _vehicleWhitelistLower = _vehicleWhitelist apply {toLowerANSI _x};
	private _availableCatalog = (uiNamespace getVariable ['QS_spawnMenu_vehicleCatalog',[]]) select {
		private _class = _x # 2;
		private _isExplicitlyWhitelisted = _hasVehicleWhitelist && {
			(toLowerANSI _class) in _vehicleWhitelistLower
		};
		(
			([_class,_isExplicitlyWhitelisted] call QS_fnc_spawnMenuVehicleAllowed) &&
			{
				!_hasVehicleWhitelist ||
					{_isExplicitlyWhitelisted}
			}
		)
	};
	uiNamespace setVariable ['QS_spawnMenu_availableCatalog',_availableCatalog];
	uiNamespace setVariable ['QS_spawnMenu_category','All'];
	['REFRESH_LIST'] call QS_fnc_spawnMenu;
};

if (_mode isEqualTo 'CATEGORY') exitWith {
	private _category = _arg1;
	if !(_category in ['All','Ground','Boat','Helicopter','VTOL','Plane','AI','Supply']) exitWith {};
	uiNamespace setVariable ['QS_spawnMenu_category',_category];
	['REFRESH_LIST'] call QS_fnc_spawnMenu;
};

if (_mode isEqualTo 'REFRESH_LIST') exitWith {
	private _display = uiNamespace getVariable ['QS_spawnMenu_display',displayNull];
	if (isNull _display) exitWith {};

	private _category = uiNamespace getVariable ['QS_spawnMenu_category','All'];
	private _availableCatalog = uiNamespace getVariable ['QS_spawnMenu_availableCatalog',[]];
	{
		_x params ['_buttonCategory','_idc'];
		private _button = _display displayCtrl _idc;
		private _hasEntries = if (_buttonCategory isEqualTo 'All') then {
			_availableCatalog isNotEqualTo []
		} else {
			(_availableCatalog findIf {(_x # 5) isEqualTo _buttonCategory}) isNotEqualTo -1
		};
		_button ctrlShow _hasEntries;
		_button ctrlEnable (_hasEntries && {_buttonCategory isNotEqualTo _category});
	} forEach [
		['All',42110],
		['Ground',42111],
		['Helicopter',42112],
		['VTOL',42113],
		['Plane',42114],
		['AI',42115],
		['Supply',42116],
		['Boat',42117]
	];

	private _list = _display displayCtrl 42102;
	lbClear _list;
	private _catalog = +_availableCatalog;
	if (_category isNotEqualTo 'All') then {
		_catalog = _catalog select {(_x # 5) isEqualTo _category};
	};
	{
		_x params ['','_displayName','_class','','_picture'];
		private _index = _list lbAdd _displayName;
		_list lbSetData [_index,_class];
		if (_picture isNotEqualTo '') then {
			_list lbSetPicture [_index,_picture];
		};
	} forEach _catalog;

	(_display displayCtrl 42106) ctrlEnable ((lbSize _list) > 0);
	if ((lbSize _list) > 0) then {
		_list lbSetCurSel 0;
	} else {
		(_display displayCtrl 42103) ctrlSetText '';
		(_display displayCtrl 42104) ctrlSetText 'No objects available';
		(_display displayCtrl 42105) ctrlSetStructuredText parseText '';
	};
};

if (_mode isEqualTo 'SELECT') exitWith {
	private _list = _arg1;
	private _index = _arg2;
	private _display = ctrlParent _list;
	if (_index < 0) exitWith {};

	private _class = _list lbData _index;
	private _catalog = uiNamespace getVariable ['QS_spawnMenu_vehicleCatalog',[]];
	private _catalogIndex = _catalog findIf {(_x # 2) isEqualTo _class};
	if (_catalogIndex < 0) exitWith {};

	(_catalog # _catalogIndex) params ['','_displayName','','_editorPreview','_picture','_category','_passengers'];
	private _preview = [_picture,_editorPreview] select (_editorPreview isNotEqualTo '');
	private _details = switch _category do {
		case 'AI': {'AI unit'};
		case 'Supply': {'Supply crate'};
		default {format ['Passenger seats: %1',_passengers]};
	};
	(_display displayCtrl 42103) ctrlSetText _preview;
	(_display displayCtrl 42104) ctrlSetText _displayName;
	(_display displayCtrl 42105) ctrlSetStructuredText parseText format [
		'<t color="#8BE28B">Category:</t> %1<br/><t color="#8BE28B">%2</t>',
		_category,
		_details
	];
};

if (_mode isEqualTo 'SPAWN') exitWith {
	private _display = uiNamespace getVariable ['QS_spawnMenu_display',displayNull];
	if (isNull _display) exitWith {};
	private _list = _display displayCtrl 42102;
	private _index = lbCurSel _list;
	if (_index < 0) exitWith {};

	private _class = _list lbData _index;
	private _spawnPoint = uiNamespace getVariable ['QS_spawnMenu_spawnPoint',objNull];
	private _terminal = uiNamespace getVariable ['QS_spawnMenu_terminal',objNull];
	if (
		(_class isKindOf 'CAManBase') &&
		{(leader (group player)) isNotEqualTo player}
	) exitWith {
		['You must be a Group Leader to recruit AI'] call QS_fnc_hint;
	};
	if (
		(_class isKindOf 'CAManBase') &&
		{({!isPlayer _x} count (units (group player))) >= 10}
	) exitWith {
		['You cannot recruit more than 10 AI'] call QS_fnc_hint;
	};
	if (isNull _terminal || {isNull _spawnPoint}) exitWith {
		systemChat 'Spawn Menu: the configured terminal or spawn point is no longer available.';
	};
	if (!(['CAN_ACCESS',_terminal,player] call QS_fnc_spawnMenu)) exitWith {
		systemChat 'Spawn Menu: your current role can no longer use this terminal.';
		closeDialog 2;
	};
	if (!([_class] call QS_fnc_spawnMenuVehicleAllowed)) exitWith {
		systemChat 'Spawn Menu: that class is not supported.';
		closeDialog 2;
	};

	// Vehicle/group creation and full setup are native-heavy.  remoteExec runs
	// the server function in scheduled context instead of blocking an
	// unscheduled network-dispatch frame.
	[player,_class,_terminal,_spawnPoint] remoteExec ['QS_fnc_spawnMenuServerSpawn',2,FALSE];
	closeDialog 2;
};
