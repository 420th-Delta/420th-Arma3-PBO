/*
File: fn_clientRadio.sqf
Author:

	Quiksilver

Last Modified:

	29/06/2016 A3 1.62 by Quiksilver

Description:

	Client Radio
	
Example:

	[0,((missionNamespace getVariable 'QS_radioChannels') # 2)] call (missionNamespace getVariable 'QS_fnc_clientRadio');
__________________________________________________________*/

params ['_type','_channel',['_unit',player],['_oldUnit',objNull]];
// Added Code
// General is a required broadcast subscription, including while awaiting respawn.
if ((_type isEqualTo 0) && {_channel isEqualTo 8}) exitWith {};
// End Updated Code
if (_type isEqualTo 0) then {
	if (_channel in (missionNamespace getVariable 'QS_client_radioChannels')) then {
		_channel radioChannelRemove [_unit];
		if (currentChannel > 5) then {
			setCurrentChannel 5;
		};
		diag_log format ['***** RADIO ***** Removed from channel %1',_channel];
		missionNamespace setVariable [
			'QS_client_radioChannels',
			((missionNamespace getVariable 'QS_client_radioChannels') - [_channel]),
			FALSE
		];
	};
} else {
	if (_type isEqualTo 1) then {
		if (!(_channel in (missionNamespace getVariable 'QS_client_radioChannels'))) then {
			_channel radioChannelAdd [_unit];
			diag_log format ['***** RADIO ***** Added to channel %1',_channel];
			missionNamespace setVariable [
				'QS_client_radioChannels',
				((missionNamespace getVariable 'QS_client_radioChannels') + [_channel]),
				FALSE
			];
		};
	} else {
		if (_type isEqualTo 2) then {
			/*/Respawn Event/*/
			private _channels = +(missionNamespace getVariable 'QS_client_radioChannels');
			if (_channels isNotEqualTo []) then {
				{
					_x radioChannelAdd [_unit];
				} forEach _channels;
			};
			if (!isNull _oldUnit && {_oldUnit isNotEqualTo _unit} && {_channels isNotEqualTo []}) then {
				// Same-frame remove/add can restore the old roster on a client.
				// Observe the new membership before retiring the captured old body.
				[_unit,_oldUnit,_channels] spawn {
					params ['_newBody','_oldBody','_channels'];
					// Keep one bounded observer alive long enough for the normal one-second
					// add retry and slower channel-roster replication to converge.
					private _until = diag_tickTime + 10;
					waitUntil {
						uiSleep 0.1;
						private _done = FALSE;
						isNil {
							if (isNull _oldBody || {_oldBody isEqualTo player && {alive _oldBody}}) exitWith {_done = TRUE;};
							private _pending = FALSE;
							private _wanted = missionNamespace getVariable ['QS_client_radioChannels',[]];
							{
								private _members = (radioChannelInfo _x) param [3,[]];
								if (_oldBody in _members) then {
									_pending = TRUE;
									// A dead/deleted replacement or revoked subscription need not join first.
									if (_newBody in _members || {isNull _newBody} || {!alive _newBody} || {!(_x in _wanted)}) then {
										_x radioChannelRemove [_oldBody];
									};
								};
							} forEach _channels;
							_done = !_pending || {diag_tickTime >= _until};
						};
						_done
					};
				};
			};
		} else {
			if (_type isEqualTo 3) then {
				/*/Killed Event/*/
				if (currentChannel > 5) then {
					setCurrentChannel 5;
				};
				if ((missionNamespace getVariable 'QS_client_radioChannels') isNotEqualTo []) then {
					{
/* Legacy Code as of 9.9.2026 */
//|						_x radioChannelRemove [player];
// Updated Code
						if (_x isNotEqualTo 8) then {_x radioChannelRemove [_unit];};
// End Updated Code
					} forEach (missionNamespace getVariable 'QS_client_radioChannels');
				};
			} else {
				if (_type isEqualTo 4) then {
					/*/Group Leaders channel eligibility/*/
					private _requested = missionProfileNamespace getVariable ['QS_client_radioChannel_groupLeaders',FALSE];
					private _eligible = alive player && {player isEqualTo (leader (group player))};
					[([0,1] select (_requested && _eligible)),_channel] call (missionNamespace getVariable 'QS_fnc_clientRadio');
				};
			};
		};
	};
};
