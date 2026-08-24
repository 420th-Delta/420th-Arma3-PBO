/*
Function: TGC_fnc_dbWhitelistInit

Description:
    Initialize database whitelist mission event handlers.

Author:
    thegamecracks

*/
if (isRemoteExecuted) exitWith {};

// PlayerConnected can run before the joining client has loaded this mission code.
// Register the response handler first, then tell the server that this client is
// ready to receive its whitelist snapshot.
if (!isServer) exitWith {
    if (missionNamespace getVariable ["TGC_dbWhitelistClientInitialized", false]) exitWith {};
    missionNamespace setVariable ["TGC_dbWhitelistClientInitialized", true, false];

    "TGC_dbWhitelistClientData" addPublicVariableEventHandler {
        params ["", "_payload"];
        _payload params [["_uid", ""], ["_roles", []]];
        if (_uid isNotEqualTo getPlayerUID player) exitWith {};
        missionNamespace setVariable ["TGC_dbWhitelistReceived", true, false];

        if (isNil "QS_whitelist_data") then {QS_whitelist_data = createHashMap};
        {
            private _roleMap = QS_whitelist_data getOrDefaultCall [_x, {createHashMap}, true];
            _roleMap deleteAt _uid;
        } forEach keys QS_whitelist_data;
        {
            QS_whitelist_data
                getOrDefaultCall [_x, {createHashMap}, true]
                set [_uid, 1];
        } forEach _roles;

        diag_log format ["TGC_fnc_dbWhitelistInit: received client whitelist for %1 with roles %2", _uid, _roles];
        missionNamespace setVariable ["QS_RSS_refreshUI", true, false];
    };

    0 spawn {
        waitUntil {
            uiSleep 0.1;
            !isNull player && {(getPlayerUID player) isNotEqualTo ""}
        };
        missionNamespace setVariable ["TGC_dbWhitelistReceived", false, false];
        for "_attempt" from 1 to 5 do {
            if (missionNamespace getVariable ["TGC_dbWhitelistReceived", false]) exitWith {};
            TGC_dbWhitelistRequest = [clientOwner, getPlayerUID player, profileName, diag_tickTime];
            publicVariableServer "TGC_dbWhitelistRequest";
            uiSleep 3;
        };
    };
};

if (missionNamespace getVariable ["TGC_dbWhitelistServerInitialized", false]) exitWith {};
missionNamespace setVariable ["TGC_dbWhitelistServerInitialized", true, false];
diag_log "TGC_fnc_dbWhitelistInit: server connect handlers initialized";

TGC_fnc_dbWhitelistInit_refreshPlayer = {
    params [["_ownerId", -1], ["_uid", ""], ["_name", ""]];
    if (missionNamespace getVariable ["QS_missionConfig_dbWhitelistEnabled", false] isNotEqualTo true) exitWith {};
    if (_uid isEqualTo "") exitWith {};
    if (isNil "QS_whitelist_data") then {QS_whitelist_data = createHashMap};

    private _users = [];
    private _querySucceeded = true;
    try {
        _users = ["getPlayerWhitelist", [_uid]] call TGC_fnc_dbQuery;
    } catch {
        _querySucceeded = false;
        diag_log format ["TGC_fnc_dbWhitelistInit: whitelist query failed for %1 (%2): %3", _name, _uid, _exception];
    };

    if (!_querySucceeded) exitWith {};

    private _clientRoles = [];
    {
        _x params ["", "_role_s3", "_role_cas", "_role_s1", "_role_opfor", "_role_all", "_role_admin", "_role_moderator", "_role_trusted", "_role_media", "_role_curator", "_role_developer", ["_role_donator", false]];
        if (_role_s3       ) then {_clientRoles pushBack "S3"};
        if (_role_cas      ) then {_clientRoles pushBack "CAS"};
        if (_role_s1       ) then {_clientRoles pushBack "S1"};
        if (_role_opfor    ) then {_clientRoles pushBack "OPFOR"};
        if (_role_all      ) then {_clientRoles pushBack "ALL"};
        if (_role_admin    ) then {_clientRoles pushBack "ADMIN"};
        if (_role_moderator) then {_clientRoles pushBack "MODERATOR"};
        if (_role_trusted  ) then {_clientRoles pushBack "TRUSTED"};
        if (_role_media    ) then {_clientRoles pushBack "MEDIA"};
        if (_role_curator  ) then {_clientRoles pushBack "CURATOR"};
        if (_role_developer) then {_clientRoles pushBack "DEVELOPER"};
        if (_role_donator  ) then {_clientRoles pushBack "DONATOR"};
    } forEach _users;

    private _removed = 0;
    {
        private _roleMap = QS_whitelist_data getOrDefaultCall [_x, {createHashMap}, true];
        private _old = _roleMap deleteAt _uid;
        if (!isNil "_old") then {_removed = _removed + 1};
    } forEach keys QS_whitelist_data;

    {
        QS_whitelist_data
            getOrDefaultCall [_x, {createHashMap}, true]
            set [_uid, 1];
    } forEach _clientRoles;

    diag_log format ["TGC_fnc_dbWhitelistInit: refreshed %1 (%2), roles %3, removed %4 stale entries", _name, _uid, _clientRoles, _removed];
    publicVariable "QS_whitelist_data";

    if (_ownerId > 0) then {
        TGC_dbWhitelistClientData = [_uid, _clientRoles];
        _ownerId publicVariableClient "TGC_dbWhitelistClientData";
        diag_log format ["TGC_fnc_dbWhitelistInit: sent client whitelist for %1 to owner %2", _uid, _ownerId];
    };
};

// Early server-side refresh for systems initialized before the client is ready.
addMissionEventHandler ["PlayerConnected", {
    params ["", "_uid", "_name", "", "_ownerId"];
    [_ownerId, _uid, _name] spawn TGC_fnc_dbWhitelistInit_refreshPlayer;
}];

// Reliable refresh: this request is sent only after the client installed its
// response handler and has a valid player UID.
"TGC_dbWhitelistRequest" addPublicVariableEventHandler {
    params ["", "_request"];
    _request params [["_ownerId", -1], ["_uid", ""], ["_name", ""], ["_requestId", -1]];

    private _matchingPlayer = allPlayers findIf {
        (owner _x isEqualTo _ownerId) && {(getPlayerUID _x) isEqualTo _uid}
    };
    if (_matchingPlayer isEqualTo -1) exitWith {
        diag_log format ["TGC_fnc_dbWhitelistInit: rejected unmatched whitelist request for %1 from owner %2", _uid, _ownerId];
    };

    [_ownerId, _uid, _name] spawn TGC_fnc_dbWhitelistInit_refreshPlayer;
};

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
