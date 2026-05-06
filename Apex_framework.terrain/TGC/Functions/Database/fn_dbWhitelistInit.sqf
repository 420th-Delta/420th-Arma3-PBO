/*
Function: TGC_fnc_dbWhitelistInit

Description:
    Initialize database whitelist mission event handlers.

Author:
    thegamecracks

*/
if (!isServer) exitWith {};
if (isRemoteExecuted) exitWith {};

// CAUTION: fetching whitelists may take too long before player initialization starts.
addMissionEventHandler ["PlayerConnected", {
    if (missionNamespace getVariable ["QS_missionConfig_dbWhitelistEnabled", false] isNotEqualTo true) exitWith {};
    if (isNil "QS_whitelist_data") then {QS_whitelist_data = createHashMap};

    _this spawn {
        scriptName "TGC_fnc_dbWhitelistInit_addWhitelist";
        params ["", "_uid", "_name"];

        private _parseWhitelistsFromUsers = {
            params ["_users"];
            private _whitelists = [];
            {
                _x params ["_steam_id", "_role_s3", "_role_cas", "_role_s1", "_role_opfor", "_role_all", "_role_admin", "_role_moderator", "_role_trusted", "_role_media", "_role_curator", "_role_developer"];
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
            } forEach _users;
            _whitelists
        };

        private _users = [];
        try {
            _users = ["getPlayerWhitelist", [_uid]] call TGC_fnc_dbQuery;
        } catch {
            diag_log format ["Ignoring exception in TGC_fnc_dbWhitelistInit_addWhitelist: %1", _exception];
        };

        private _whitelists = [_users] call _parseWhitelistsFromUsers;
        private _added = 0;
        {
            _x params ["_uid", "_role"];
            private _roles = QS_whitelist_data getOrDefaultCall [_role, {createHashMap}, true];
            private _overwritten = _roles set [_uid, 1, false];
            if (!_overwritten) then {_added = _added + 1};
        } forEach _whitelists;

        diag_log format ["TGC_fnc_dbWhitelistInit: %1 (%2) connected, adding %3 new whitelists", _name, _uid, _added];
        if (_added > 0) then {publicVariable "QS_whitelist_data"};
    };
}];

addMissionEventHandler ["PlayerDisconnected", {
    params ["", "_uid", "_name"];
    if (missionNamespace getVariable ["QS_missionConfig_dbWhitelistEnabled", false] isNotEqualTo true) exitWith {};
    if (isNil "QS_whitelist_data") then {QS_whitelist_data = createHashMap};

    // TGC_fnc_dbWhitelistInit_cleanOnDisconnect = true;
    // The above variable can be set to enable cleaning up whitelists after disconnect.
    // This reduces network traffic when a lot of unique whitelisted players
    // frequently connect and disconnect.
    //
    // However, note that the database may fail to respond in a timely manner
    // before a player's initialization begins. This can cause issues such as
    // curator modules not being created.
    //
    // By disabling cleanup, players can re-connect as a workaround to
    // re-initialize themselves, if the database whitelists arrived late.
    // As such, it is recommended to keep this disabled.
    if (missionNamespace getVariable ["TGC_fnc_dbWhitelistInit_cleanOnDisconnect", false] isNotEqualTo true) exitWith {};

    private _removed = 0;
    {
        private _roles = QS_whitelist_data getOrDefaultCall [_role, {createHashMap}, true];
        private _old = _roles deleteAt _uid;
        if (!isNil "_old") then {_removed = _removed + 1};
    } forEach keys QS_whitelist_data;

    diag_log format ["TGC_fnc_dbWhitelistInit: %1 (%2) disconnected, removing %3 whitelists", _name, _uid, _removed];
    // Leave below commented to reduce network traffic.
    // The next whitelisted player that connects will trigger a broadcast.
    // if (_removed > 0) then {publicVariable "QS_whitelist_data"};
}];
