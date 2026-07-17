/*
Function: TGC_fnc_processPlayerProfileQueue

Description:
    Process validated Player Profile database requests outside RemoteExec context.

Author:
    420th
*/
params [["_init", ""]];

if (!isServer) exitWith {};
if (_init in ["preInit", "postInit"]) exitWith {
    [""] spawn TGC_fnc_processPlayerProfileQueue;
};

if (isNil {missionNamespace getVariable "TGC_playerProfile_queryQueue"}) then {
    missionNamespace setVariable ["TGC_playerProfile_queryQueue", []];
};

while {true} do {
    private _queue = missionNamespace getVariable ["TGC_playerProfile_queryQueue", []];
    if (_queue isEqualTo []) then {
        uiSleep 0.1;
        continue;
    };

    (_queue deleteAt 0) params ["_requestOwner", "_uid", "_playerName"];

    try {
        if (isNil "fdelta_stats_fnc_dbQuery") then {
            throw "420th Stats Tracker is unavailable";
        };
        if !(localNamespace getVariable ["fdelta_stats_db_ready", false]) then {
            throw "420th Stats Tracker database is unavailable";
        };

        private _rows = [];
        private _queryResult = ["getPlayerProfile", [_uid, "main"]] call fdelta_stats_fnc_dbQuery;
        if (!isNil "_queryResult") then {
            _rows = _queryResult;
        };

        private _stats = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        if (_rows isEqualType [] && {count _rows > 0}) then {
            private _row = _rows param [0, []];
            if (_row isEqualType []) then {
                for "_i" from 0 to 10 do {
                    private _value = _row param [_i, 0];
                    if (_value isEqualType "") then {
                        _value = parseNumber _value;
                    };
                    if (_value isEqualType 0) then {
                        _stats set [_i, _value];
                    };
                };
            };
        };

        [124, [_playerName, _uid, _stats, true]] remoteExecCall ["QS_fnc_remoteExec", _requestOwner, false];
    } catch {
        diag_log format ["TGC_fnc_processPlayerProfileQueue: failed to fetch %1 (%2): %3", _playerName, _uid, _exception];
        [124, [_playerName, _uid, [], false]] remoteExecCall ["QS_fnc_remoteExec", _requestOwner, false];
    };
};
