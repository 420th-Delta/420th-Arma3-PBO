/*/
File: fn_dbWhitelistRefresher.sqf
Author:

	thegamecracks

Last modified:

	2023/10/01 A3 2.12 by thegamecracks

Description:

	Periodically updates the whitelist.
___________________________________________________________________________/*/

private _parseWhitelistsFromUsers = {
	params ["_users"];
	private _whitelists = [];
	{
		_x params ["_steam_id", "_role_s3", "_role_cas", "_role_s1", "_role_opfor", "_role_all", "_role_admin", "_role_moderator", "_role_trusted", "_role_media", "_role_curator", "_role_developer", ["_role_donator", false]];
		if (_role_s3       ) then {_whitelists pushBack [_steam_id, "S3"]};
		if (_role_cas      ) then {_whitelists pushBack [_steam_id, "CAS"]};
		if (_role_s1       ) then {_whitelists pushBack [_steam_id, "S1"]};
		if (_role_opfor    ) then {_whitelists pushBack [_steam_id, "OPFOR"]};
		if (_role_all      ) then {_whitelists pushBack [_steam_id, "ALL"]};
		if (_role_admin    ) then {_whitelists pushBack [_steam_id, "ADMIN"]};
		if (_role_moderator) then {_whitelists pushBack [_steam_id, "MODERATOR"]};
		if (_role_trusted  ) then {_whitelists pushBack [_steam_id, "TRUSTED"]};
		if (_role_media    ) then {_whitelists pushBack [_steam_id, "MEDIA"]};
		if (_role_curator  ) then {_whitelists pushBack [_steam_id, "CURATOR"]};
		if (_role_developer) then {_whitelists pushBack [_steam_id, "DEVELOPER"]};
		if (_role_donator  ) then {_whitelists pushBack [_steam_id, "DONATOR"]};
	} forEach _users;
	_whitelists
};

for "_i" from 0 to 1 step 0 do {
	try {
		private _whitelists = ["getWhitelists"] call TGC_fnc_dbQuery;
		_whitelists = [_whitelists] call _parseWhitelistsFromUsers;
		QS_whitelist_data = createHashMap;
		{
			_x params ["_id", "_role"];
			QS_whitelist_data
				getOrDefaultCall [_role, {createHashMap}, true]
				set [_id, 1];
		} forEach _whitelists;
		publicVariable "QS_whitelist_data";
	} catch {
		diag_log format ["Ignoring exception in fn_dbWhitelistRefresher.sqf: %1", _exception];
	};
	uiSleep QS_missionConfig_dbWhitelistRefreshInterval;
};
