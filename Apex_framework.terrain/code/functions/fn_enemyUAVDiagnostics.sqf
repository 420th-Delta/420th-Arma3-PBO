/*
File: fn_enemyUAVDiagnostics.sqf

Description:

	Log the network and motion state of every enemy UAV created during the
	mission. The delay allows spawn initialization and createVehicleCrew to
	finish before the state is sampled.
__________________________________________________*/

if (!isServer) exitWith {};
if (missionNamespace getVariable ['QS_enemyUAVDiagnostics_initialized',FALSE]) exitWith {};
missionNamespace setVariable ['QS_enemyUAVDiagnostics_initialized',TRUE,FALSE];

QS_enemyUAVDiagnostics_entityCreatedEH = addMissionEventHandler [
	'EntityCreated',
	{
		params ['_entity'];
		if (!(unitIsUAV _entity)) exitWith {};

		[_entity] spawn {
			params ['_uav'];
			uiSleep 1;
			if (isNull _uav) exitWith {};

			private _crew = crew _uav;
			private _liveSide = if (_crew isNotEqualTo []) then {
				side (group (_crew # 0))
			} else {
				side _uav
			};
			private _configSide = [EAST,WEST,RESISTANCE,CIVILIAN,sideUnknown] param [
				getNumber ((configOf _uav) >> 'side'),
				sideUnknown
			];
			if (!((_liveSide in [EAST,RESISTANCE]) || {_configSide in [EAST,RESISTANCE]})) exitWith {};

			if (
				(_uav isKindOf 'Plane') &&
				{!isNil {missionNamespace getVariable 'QS_fnc_transformDiagRegisterEnemyJet'}}
			) then {
				private _source = ['normalAO.enemyUAV','defend.enemyUAV'] select (missionNamespace getVariable ['QS_defendActive',FALSE]);
				[_uav,_source] call (missionNamespace getVariable 'QS_fnc_transformDiagRegisterEnemyJet');
			};

			diag_log text format [
				'QS_ENEMY_UAV_SPAWN class="%1" netId="%2" owner=%3 position=%4 velocity=%5 orientation=[heading=%6,vectorDir=%7,vectorUp=%8] side=%9 configSide=%10 local=%11',
				typeOf _uav,
				netId _uav,
				owner _uav,
				getPosWorld _uav,
				velocity _uav,
				getDir _uav,
				vectorDir _uav,
				vectorUp _uav,
				_liveSide,
				_configSide,
				local _uav
			];
		};
	}
];
