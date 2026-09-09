/*/
File: fn_clientArsenal.sqf
Author:

	Quiksilver

Last Modified:

	4/11/2022 A3 2.10 by Quiksilver

Description:

	Setup Client Arsenal
____________________________________________________/*/

params [['_unit',player],['_checkRunningScript',true]];

// This is client UI setup and must not run on dedicated servers or headless
// clients, where there is no Arsenal interface to initialize.
if (!hasInterface) exitWith {};

// Below is a very primitive way of preventing concurrency
// and is prone to race conditions:
// 1. Multiple calls to QS_fnc_clientArsenal will be ignored,
//    potentially missing out on updates if the script is almost done
// 2. This check is not atomic and two scripts can still be spawned at once
if (
	_checkRunningScript
	&& {!isNil 'QS_client_arsenalScript'
	&& {!scriptDone QS_client_arsenalScript}}
) exitWith {
	waitUntil {scriptDone QS_client_arsenalScript};
};
// if (
// 	!_checkRunningScript
// 	&& {!isNil '_thisScript'
// 	&& {!isNil 'QS_client_arsenalScript'
// 	&& {_thisScript isNotEqualTo QS_client_arsenalScript}}}
// ) exitWith {};
if (_checkRunningScript) exitWith {
	QS_client_arsenalScript = [_unit,false] spawn QS_fnc_clientArsenal;
	waitUntil {scriptDone QS_client_arsenalScript};
};

_unit setVariable ['bis_addVirtualWeaponCargo_cargo',[[],[],[],[]],FALSE];

if (QS_missionConfig_Arsenal isEqualTo 3) exitWith {};
private _configRestrictions = (getMissionConfigValue ['arsenalRestrictedItems',[]]) apply {toLowerANSI _x};

// This script can take a long time depending on installed mods
// so we'll record performance statistics per step
private _startTime = diag_tickTime;
private _lastStepTime = _startTime;
private _logDurationThreshold = 1;
private _logStatistics = [];
private _getStepTime = {
	private _time = diag_tickTime;
	private _delta = _time - _lastStepTime;
	_lastStepTime = _time;
	_delta;
};
private _logStep = {
	_logStatistics pushBack [_this,call _getStepTime];
};

// Load the global restriction lists before merging them into the Arsenal lists.
(call (missionNamespace getVariable 'QS_data_restrictedGear')) params [
	['_restrictedWeapons',[]],
	['_restrictedMagazines',[]],
	['_restrictedItems',[]],
	['_restrictedBackpacks',[]]
];

/*/ To Do: Implement this instead of the below lists
(call (missionNamespace getVariable 'QS_data_restrictedGear')) params [
	['_restrictedWeapons',[]],
	['_restrictedMagazines',[]],
	['_restrictedItems',[]],
	['_restrictedBackpacks',[]]
];
/*/
/*
private _QS_restrictedItems = [
	'h_helmetleadero_oucamo',
	'h_helmetleadero_ocamo',
	'h_helmetleadero_ghex_f',
	'h_helmeto_oucamo',
	'h_helmeto_ocamo',
	'h_helmeto_ghex_f',
	'h_racinghelmet_1_black_f',
	'h_racinghelmet_1_blue_f',
	'h_racinghelmet_2_f',
	'h_racinghelmet_1_f',
	'h_racinghelmet_1_green_f',
	'h_racinghelmet_1_orange_f',
	'h_racinghelmet_1_red_f',
	'h_racinghelmet_3_f',
	'h_racinghelmet_4_f',
	'h_racinghelmet_1_white_f',
	'h_racinghelmet_1_yellow_f',
	'u_c_idap_man_cargo_f',
	'u_c_idap_man_jeans_f',
	'u_c_idap_man_casual_f',
	'u_c_idap_man_shorts_f',
	'u_c_idap_man_tee_f',
	'u_c_idap_man_teeshorts_f',
	'u_c_driver_1_black',
	'u_c_driver_1_blue',
	'u_c_driver_2',
	'u_c_driver_1',
	'u_c_driver_1_green',
	'u_c_driver_1_orange',
	'u_c_driver_1_red',
	'u_c_driver_3',
	'u_c_driver_4',
	'u_c_driver_1_white',
	'u_c_driver_1_yellow',
	'u_o_t_soldier_f',
	'u_o_combatuniform_ocamo',
	'u_o_combatuniform_oucamo',
	'u_o_fullghillie_ard',
	'u_o_t_fullghillie_tna_f',
	'u_o_fullghillie_lsh',
	'u_o_fullghillie_sard',
	'u_o_t_sniper_f',
	'u_o_ghilliesuit',
	'u_orestesbody',
	'u_o_officer_noinsignia_hex_f',
	'u_o_t_officer_f',
	'u_o_officeruniform_ocamo',
	'u_o_pilotcoveralls',
	'u_o_specopsuniform_ocamo',
	'u_o_v_soldier_viper_f',
	'u_o_v_soldier_viper_hex_f',
	'v_plain_medical_f',
	'v_eod_idap_blue_f',
	'apersminedispenser_mag',
	'integrated_nvg_f',
	'integrated_nvg_ti_0_f',
	'integrated_nvg_ti_1_f',
	'o_uavterminal',
	'i_uavterminal',
	'c_uavterminal',
	'i_e_uavterminal'
];*/
private _QS_restrictedItems = [
	'o_uavterminal',
	'i_uavterminal',
	'c_uavterminal',
	'i_e_uavterminal'
];
private _QS_restrictedWeapons = [
	'apersminedispenser_mag'
];
private _QS_restrictedMagazines = [
	'apersminedispenser_mag'
];
private _QS_restrictedBackpacks = [
	'weapon_bag_base',
	'o_hmg_01_support_f',
	'i_hmg_01_support_f',
	'o_hmg_01_support_high_f',
	'i_hmg_01_support_high_f',
	'o_hmg_01_weapon_f',
	'i_hmg_01_weapon_f',
	'b_hmg_01_a_weapon_f',
	'o_hmg_01_a_weapon_f',
	'i_hmg_01_a_weapon_f',
	'i_hmg_02_support_f',
	'i_e_hmg_02_support_f',
	//'i_c_hmg_02_support_f',		// These are allowed in Arsenal until BIS fixes the Blufor variant
	'i_g_hmg_02_support_f',
	'i_hmg_02_support_high_f',
	'i_e_hmg_02_support_high_f',
	//'i_c_hmg_02_support_high_f',
	'i_g_hmg_02_support_high_f',
	'i_hmg_02_weapon_f',
	'i_e_hmg_02_weapon_f',
	//'i_c_hmg_02_weapon_f',
	'i_g_hmg_02_weapon_f',
	'i_hmg_02_high_weapon_f',
	'i_e_hmg_02_high_weapon_f',
	//'i_c_hmg_02_high_weapon_f',
	'i_g_hmg_02_high_weapon_f',
	'o_gmg_01_weapon_f',
	'i_gmg_01_weapon_f',
	'b_gmg_01_a_weapon_f',
	'o_gmg_01_a_weapon_f',
	'i_gmg_01_a_weapon_f',
	'o_hmg_01_high_weapon_f',
	'i_hmg_01_high_weapon_f',
	'o_gmg_01_high_weapon_f',
	'i_gmg_01_high_weapon_f',
	'o_mortar_01_support_f',
	'i_mortar_01_support_f',
	'o_mortar_01_weapon_f',
	'i_mortar_01_weapon_f',
	'b_o_parachute_02_f',
	'b_i_parachute_02_f',
	'o_aa_01_weapon_f',
	'i_aa_01_weapon_f',
	'o_at_01_weapon_f',
	'i_at_01_weapon_f',
	'o_uav_01_backpack_f',
	'i_uav_01_backpack_f',
	'b_respawn_tentdome_f',
	'b_respawn_tenta_f',
	'b_respawn_sleeping_bag_f',
	'b_respawn_sleeping_bag_blue_f',
	'b_respawn_sleeping_bag_brown_f',
	'o_static_designator_02_weapon_f',
	'b_patrol_respawn_bag_f',
	'b_messenger_idap_f',
	'c_idap_uav_01_backpack_f',
	'o_uav_06_backpack_f',
	'i_uav_06_backpack_f',
	'c_idap_uav_06_backpack_f',
	'c_uav_06_backpack_f',
	'c_idap_uav_06_antimine_backpack_f',
	'o_uav_06_medical_backpack_f',
	'i_uav_06_medical_backpack_f',
	'c_idap_uav_06_medical_backpack_f',
	'c_uav_06_medical_backpack_f',
	'i_e_mortar_01_support_f',
	'i_e_mortar_01_weapon_f',
	'i_e_hmg_01_support_high_f',
	'i_e_hmg_01_support_f',
	'i_e_gmg_01_a_weapon_f',
	'i_e_hmg_01_a_weapon_f',
	'i_e_hmg_01_high_weapon_f',
	'i_e_hmg_01_weapon_f',
	'i_e_gmg_01_high_weapon_f',
	'i_e_gmg_01_weapon_f',
	'i_e_ugv_02_demining_backpack_f',
	'i_ugv_02_science_backpack_f',
	'o_ugv_02_science_backpack_f',
	'i_e_ugv_02_science_backpack_f',
	'i_e_aa_01_weapon_f',
	'i_e_at_01_weapon_f',
	'i_e_uav_06_backpack_f',
	'i_e_uav_06_medical_backpack_f',
	'i_e_uav_01_backpack_f',
	'c_idap_ugv_02_demining_backpack_f',
	'i_ugv_02_demining_backpack_f',
	'o_ugv_02_demining_backpack_f'
];

// Mission-configured restrictions may contain weapons, magazines, items, or backpacks.
// Keep them in every category so arsenalRestrictedItems[] is enforced regardless of
// the config class type and by the runtime gear restriction checks below.
_QS_restrictedItems append _configRestrictions;
_QS_restrictedWeapons append _configRestrictions;
_QS_restrictedMagazines append _configRestrictions;
_QS_restrictedBackpacks append _configRestrictions;

// Merge the global restricted-gear lists into the Arsenal restrictions.
_QS_restrictedItems append _restrictedItems;
_QS_restrictedWeapons append _restrictedWeapons;
_QS_restrictedMagazines append _restrictedMagazines;
_QS_restrictedBackpacks append _restrictedBackpacks;

private _unitSide = _unit getVariable ['QS_unit_side',WEST];
if (_unitSide in [EAST,RESISTANCE]) then {
	_QS_restrictedItems = _QS_restrictedItems -	[
		'','u_i_c_soldier_bandit_4_f','u_i_c_soldier_bandit_1_f','u_i_c_soldier_bandit_2_f','u_i_c_soldier_bandit_5_f','u_i_c_soldier_bandit_3_f','u_o_t_soldier_f',
		'u_o_combatuniform_ocamo','u_o_combatuniform_oucamo','u_o_fullghillie_ard','u_o_t_fullghillie_tna_f','u_o_fullghillie_lsh','u_o_fullghillie_sard','u_o_t_sniper_f',
		'u_o_ghilliesuit','u_bg_guerrilla_6_1','u_bg_guerilla1_1','u_bg_guerilla1_2_f','u_bg_guerilla2_2','u_bg_guerilla2_1','u_bg_guerilla2_3','u_bg_guerilla3_1','u_bg_leader',
		'u_o_officer_noinsignia_hex_f','u_o_t_officer_f','u_o_officeruniform_ocamo','u_i_c_soldier_para_2_f','u_i_c_soldier_para_3_f','u_i_c_soldier_para_5_f','u_i_c_soldier_para_4_f',
		'u_i_c_soldier_para_1_f','u_o_pilotcoveralls','u_o_specopsuniform_ocamo','u_i_c_soldier_camo_f'
	];
};

_combinedRestrictions = [];
_combinedRestrictions append _QS_restrictedItems;
_combinedRestrictions append _QS_restrictedWeapons;
_combinedRestrictions append _QS_restrictedMagazines;
_combinedRestrictions append _QS_restrictedBackpacks;
QS_arsenal_missionBlacklist = [
	[_QS_restrictedItems,_QS_restrictedWeapons,_QS_restrictedMagazines,_QS_restrictedBackpacks],
	_combinedRestrictions
];
'Define restrictions' call _logStep;

// Optimize membership testing for above restrictions
_combinedRestrictionsMap = createHashMap;
{_combinedRestrictionsMap set [toLowerANSI _x,true]} forEach _combinedRestrictions;
'Create restriction hashmap' call _logStep;

_isBlacklisted = QS_missionConfig_Arsenal isEqualTo 2;
private _arsenalPreloadFailed = FALSE;
if (_isBlacklisted || {QS_missionConfig_Arsenal isEqualTo 0}) then {
	// If using blacklist, we first have to add everything, so we can remove the blacklisted items.

	if (!isNil 'QS_client_arsenalCache') exitWith {
		private _cachedCargo = +QS_client_arsenalCache;
		{
			_cachedCargo set [_forEachIndex,(_x select {!(toLowerANSI _x in _combinedRestrictionsMap)})];
		} forEach _cachedCargo;
		QS_client_arsenalCache = _cachedCargo;
		_unit setVariable ['bis_addVirtualWeaponCargo_cargo',+_cachedCargo,FALSE];
		'Reuse cached arsenal data' call _logStep;
	};

	["Preload"] call BIS_fnc_arsenal;
	// Do not assume the function's internal cache exists immediately.  Waiting
	// also covers engine/mod implementations which finish the preload
	// asynchronously.
	if (isNil {missionNamespace getVariable 'BIS_fnc_arsenal_data'}) then {
		private _preloadDeadline = diag_tickTime + 10;
		waitUntil {
			uiSleep 0.05;
			(!isNil {missionNamespace getVariable 'BIS_fnc_arsenal_data'})
			|| {diag_tickTime >= _preloadDeadline}
		};
	};
	private _data = +(missionNamespace getVariable ['BIS_fnc_arsenal_data',[]]);
	if ((count _data) < 27) exitWith {
		_arsenalPreloadFailed = TRUE;
		diag_log format [
			'QS_fnc_clientArsenal: BIS_fnc_arsenal preload returned invalid data (%1 entries); arsenal setup aborted',
			count _data
		];
	};
	_data params [
		'_primaries',
		'_secondaries',
		'_handguns',
		'_uniforms',
		'_vests',
		'_backpacks',
		'_headwear',
		'_facewear',
		'_goggles',
		'_binoculars',
		'_maps',
		'_GPS',
		'_radios',
		'_compasses',
		'_watches',
		'_faces',
		'_voices',
		'_insignias',
		'', // optics, not preloaded
		'', // accessories, not preloaded
		'', // muzzles, not preloaded
		'', // bipods, not preloaded
		'_throwables',
		'_placeables',
		'_specials',
		'', // ???
		'_magazines'
	];
	format ['Preload vanilla arsenal (total: %1)', count flatten _data] call _logStep;

	// ~1.9ms for 1500 items
	private _attachments = toString {
		getNumber (_x >> 'ItemInfo' >> 'type') in [101, 201, 301, 302]
		&& {
			if (isNumber (_x >> 'scopeArsenal')) then {getNumber (_x >> 'scopeArsenal') >= 2}
			else {getNumber (_x >> 'scope') >= 2}
		}
	} configClasses (configFile >> 'CfgWeapons') apply {configName _x};

	_data pushBack _attachments; // Include in item restrictions
	format ['Collect weapon attachments (total: %1)', count _attachments] call _logStep;

	// ~3.75ms with 5000+ items
	{
		private _group = _x;
		private _toRemove = [];
		{
			if (toLowerANSI _x in _combinedRestrictionsMap) then {
				_toRemove pushBack _forEachIndex;
			};
		} forEach _group;
		{_group deleteAt _x} forEachReversed _toRemove;
	} forEach _data;
	'Apply global item restrictions' call _logStep;

	private _items =
		_uniforms + _vests + _headwear + _facewear + _goggles + _maps + _GPS
		+ _radios + _compasses + _watches + _attachments + _specials;
	private _weapons = _primaries + _secondaries + _handguns + _binoculars;
	_magazines = _magazines + _throwables + _placeables;

	QS_client_arsenalCache = [_items,_weapons,_magazines,_backpacks];
	_unit setVariable ['bis_addVirtualWeaponCargo_cargo',+QS_client_arsenalCache,FALSE];
};

if (_arsenalPreloadFailed) exitWith {};

// Get blacklist/whitelist from arsenal.sqf
private _unitRole = _unit getVariable ['QS_unit_role','rifleman'];
[_unitSide,_unitRole] call QS_data_arsenal params ['_arsenalBlacklist','_arsenalWhitelist'];
(
	[_arsenalWhitelist,_arsenalBlacklist]
	select _isBlacklisted
	params ['_itemsData','_magazines','_backpacks','_weapons']
);

_backpacks = _backpacks select {_x call QS_fnc_baseBackpack == _x};
_weapons = _weapons select {_x call QS_fnc_baseWeapon == _x};
'Get blacklist/whitelist' call _logStep;

private _items = [];
private _goggles = _itemsData # 5;
if (_goggles isNotEqualTo []) then {
	_binGoggles = configFile >> 'CfgGlasses';
	for '_i' from 0 to ((count _binGoggles) - 1) step 1 do {
		private _className = _binGoggles select _i;
		if (isClass _className) then {
			private _goggleClassname = configName _className;
			if (toLowerANSI _goggleClassname in _goggles) then {
				_goggles set [_goggles find (toLowerANSI _goggleClassname),_goggleClassname];
			};
		};
	};
	_itemsData set [5,_goggles];
};
_items append flatten _itemsData;
'Merge blacklist/whitelist' call _logStep;

if (_isBlacklisted) then {
	_cargo = _unit getVariable ['bis_addVirtualWeaponCargo_cargo',[[],[],[],[]]];
	_cargo params ['_cargoItems','_cargoWeapons','_cargoMagazines','_cargoBackpacks'];
	{
		private _class = _x;
		private _foundIndex = _cargoItems findIf {toLowerANSI _x isEqualTo toLowerANSI _class};
		if (_foundIndex isNotEqualTo -1) then {
			_cargoItems deleteAt _foundIndex;
		};
	} forEach _items;
	{
		private _class = configName (configFile >> 'CfgWeapons' >> _x);
		private _foundIndex = _cargoWeapons findIf {toLowerANSI _x isEqualTo toLowerANSI _class};
		if (_foundIndex isNotEqualTo -1) then {
			_cargoWeapons deleteAt _foundIndex;
		};
	} forEach _weapons;
	{
		private _class = configName (configFile >> 'CfgWeapons' >> _x);
		private _foundIndex = _cargoMagazines findIf {toLowerANSI _x isEqualTo toLowerANSI _class};
		if (_foundIndex isNotEqualTo -1) then {
			_cargoMagazines deleteAt _foundIndex;
		};
	} forEach _magazines;
	{
		private _class = _x;
		private _foundIndex = _cargoBackpacks findIf {toLowerANSI _x isEqualTo toLowerANSI _class};
		if (_foundIndex isNotEqualTo -1) then {
			_cargoBackpacks deleteAt _foundIndex;
		};
	} forEach _backpacks;
	_unit setVariable ['bis_addVirtualWeaponCargo_cargo',[_cargoItems,_cargoWeapons,_cargoMagazines,_cargoBackpacks],FALSE];
} else {
	_items = _items select {!(toLowerANSI _x in _combinedRestrictionsMap)};
	_magazines = _magazines select {!(toLowerANSI _x in _combinedRestrictionsMap)};
	_backpacks = _backpacks select {!(toLowerANSI _x in _combinedRestrictionsMap)};
	_weapons = _weapons select {!(toLowerANSI _x in _combinedRestrictionsMap)};
	[_unit,_items,FALSE,FALSE] call BIS_fnc_addVirtualItemCargo;
	[_unit,_magazines,FALSE,FALSE] call BIS_fnc_addVirtualMagazineCargo;
	[_unit,_backpacks,FALSE,FALSE] call BIS_fnc_addVirtualBackpackCargo;
	[_unit,_weapons,FALSE,FALSE] call BIS_fnc_addVirtualWeaponCargo;
};
'Apply blacklist/whitelist' call _logStep;

private _timeElapsed = diag_tickTime - _startTime;
if (_timeElapsed > _logDurationThreshold) then {
	diag_log format ['fn_clientArsenal.sqf took %1 seconds to execute',_timeElapsed];
	{
		_x params ['_message','_time'];
		diag_log format ['%1: %2s',_message,_time];
	} forEach _logStatistics;
};
