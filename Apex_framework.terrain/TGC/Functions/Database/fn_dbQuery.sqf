/*/
File: fn_dbQuery.sqf
Author:

	thegamecracks

Last modified:

	4/28/2023 A3 2.12 by thegamecracks

Description:

	Runs the given prepared statement asynchronously
	and returns its result.

Parameters:
	[_function,_args,_wait]
	String _function: The function to run.
	Array _args:
		The arguments to pass to the function.
		Note that nested arrays must be turned into strings beforehand.
	Boolean _wait: (default: true)
		If enabled, waits for the query to return a response.
		This requires the script to be running in scheduled envrionment.

Returns:
	Whatever response was given, or an empty string if `_wait` is false.
___________________________________________________________________________/*/
// https://github.com/SteezCram/extDB3/blob/master/Optional/legacy/original_source_code/sqf_examples/sqf/fn_async_custom.sqf
// CfgRemoteExec is allowlist-only and does not expose this function. Do not
// reject isRemoteExecuted here: Arma carries that context into server-owned
// workers spawned by validated RemoteExec handlers (for example, the Donator
// Skins menu), causing legitimate queries to return nil without reaching
// extDB3.
if (!isServer) exitWith {};
params ["_function", ["_args", []], ["_wait", true]];
if (_wait && {!canSuspend}) then {
	throw "fn_dbQuery.sqf: Waiting database queries require a scheduled environment";
};

// Keep a damaged database from accumulating an unlimited number of scheduled
// pollers. This bounds both active extension users and scripts waiting for a
// slot. Unscheduled fire-and-forget callers are rejected when all slots are in
// use because they cannot safely wait here.
private _maxConcurrentQueries = 4;
private _maxQueuedQueries = 64;
private _queueWaitTimeout = 10;
private _breakerFailureLimit = 5;
private _breakerWindow = 30;
private _breakerCooldown = 60;

private _now = diag_tickTime;
private _breaker = missionNamespace getVariable ["TGC_dbCircuitBreaker", [_now, 0, 0]];
_breaker params ["_breakerWindowStarted", "_breakerFailures", "_breakerOpenUntil"];
if (_breakerOpenUntil > _now) then {
	throw format ["fn_dbQuery.sqf: Database circuit breaker open for %1 more seconds", ceil (_breakerOpenUntil - _now)];
};
if ((_now - _breakerWindowStarted) > _breakerWindow) then {
	_breakerWindowStarted = _now;
	_breakerFailures = 0;
	missionNamespace setVariable ["TGC_dbCircuitBreaker", [_breakerWindowStarted, _breakerFailures, 0], false];
};

private _slotAcquired = false;
private _registeredAsQueued = false;
private _queueDeadline = _now + _queueWaitTimeout;
while {!_slotAcquired} do {
	private _activeQueries = missionNamespace getVariable ["TGC_dbActiveQueries", 0];
	if (_activeQueries < _maxConcurrentQueries) then {
		missionNamespace setVariable ["TGC_dbActiveQueries", _activeQueries + 1, false];
		_slotAcquired = true;
		if (_registeredAsQueued) then {
			private _queuedQueries = missionNamespace getVariable ["TGC_dbQueuedQueries", 1];
			missionNamespace setVariable ["TGC_dbQueuedQueries", (_queuedQueries - 1) max 0, false];
		};
	} else {
		if (!_registeredAsQueued) then {
			private _queuedQueries = missionNamespace getVariable ["TGC_dbQueuedQueries", 0];
			if (_queuedQueries >= _maxQueuedQueries) then {
				throw format ["fn_dbQuery.sqf: Database queue is full (%1 waiting)", _queuedQueries];
			};
			missionNamespace setVariable ["TGC_dbQueuedQueries", _queuedQueries + 1, false];
			_registeredAsQueued = true;
		};
		if (!canSuspend || {diag_tickTime >= _queueDeadline}) then {
			private _queuedQueries = missionNamespace getVariable ["TGC_dbQueuedQueries", 1];
			missionNamespace setVariable ["TGC_dbQueuedQueries", (_queuedQueries - 1) max 0, false];
			throw "fn_dbQuery.sqf: Timed out waiting for a database concurrency slot";
		};
		uiSleep 0.05;
	};
};

private _executionStarted = diag_tickTime;
private _dbResult = "";
private _dbException = "";
try {
	_dbResult = call {

// extDB3 calls cannot be interrupted while the extension is executing, but
// response polling still needs a hard ceiling so a lost key cannot leave a
// scheduled server worker alive forever.
private _queryTimeout = 30;
private _maxResponsePolls = 300;
private _responsePollInterval = 0.1;
private _maxMultipartChunks = 2048;
private _maxMultipartBytes = 2 * 1024 * 1024;
private _multipartPollInterval = 0.01;

private _mode = ["1", "2"] select _wait;
private _query =
	[_function]
	+ (_args apply {
		if (_x isEqualType "") then {_x} else {str _x}
		call TGC_fnc_dbStrip
	})
	joinString ":";
private _args = format ["%1:ina:%2", _mode, _query];
if (QS_missionConfig_dbQueryDebug) then {diag_log format ["fn_dbQuery.sqf: Executing query %1", _query]};
private _deadline = diag_tickTime + _queryTimeout;
private _perfDbSubmit = ['dbQuery.callExtension.submit',0,[_function]] call QS_fnc_perfBegin;
private _keyResponse = "extDB3" callExtension _args;
[_perfDbSubmit,0,[count _keyResponse,missionNamespace getVariable ['TGC_dbActiveQueries',0]]] call QS_fnc_perfEnd;

if (!_wait) exitWith {""};
if (diag_tickTime >= _deadline) then {
	throw format ["fn_dbQuery.sqf: Initial extDB3 call exceeded the %1 second deadline for query %2", _queryTimeout, _query];
};

private _keyMessage = [];
try {
	_keyMessage = parseSimpleArray _keyResponse;
} catch {
	throw format ["fn_dbQuery.sqf: Invalid initial response for query %1: %2 (%3)", _query, _keyResponse, _exception];
};
if !(_keyMessage isEqualType [] && {count _keyMessage >= 2}) then {
	throw format ["fn_dbQuery.sqf: Malformed initial response for query %1: %2", _query, _keyResponse];
};
_keyMessage params ["_type", "_key"];
if (_type isNotEqualTo 2) exitWith {
	throw format ["fn_dbQuery.sqf: Failed to execute query %1 (type %2, data %3)", _query, _type, _key];
};

uiSleep random 0.03;

private _result = "";
private _responsePolls = 0;
private _complete = false;
while {!_complete} do {
	if (diag_tickTime >= _deadline) then {
		throw format ["fn_dbQuery.sqf: Timed out after %1 seconds waiting for query %2", _queryTimeout, _query];
	};
	if (_responsePolls >= _maxResponsePolls) then {
		throw format ["fn_dbQuery.sqf: Exceeded %1 response polls waiting for query %2", _maxResponsePolls, _query];
	};
	_responsePolls = _responsePolls + 1;

	private _perfDbPoll = ['dbQuery.callExtension.poll',0,[_function]] call QS_fnc_perfBegin;
	private _messageRaw = "extDB3" callExtension format ["4:%1", _key];
	[_perfDbPoll,0,[count _messageRaw]] call QS_fnc_perfEnd;
	if (diag_tickTime >= _deadline) then {
		throw format ["fn_dbQuery.sqf: Timed out during response poll %1 for query %2", _responsePolls, _query];
	};
	if (_messageRaw isEqualTo "") then {
		throw format ["fn_dbQuery.sqf: No response received for query %1", _query];
	};

	private _message = [];
	try {
		_message = parseSimpleArray _messageRaw;
	} catch {
		throw format ["fn_dbQuery.sqf: Invalid response for query %1: %2 (%3)", _query, _messageRaw, _exception];
	};
	if !(_message isEqualType [] && {count _message >= 1}) then {
		throw format ["fn_dbQuery.sqf: Malformed response for query %1: %2", _query, _messageRaw];
	};

	switch (_message # 0) do {
		case 0: {
			throw format ["fn_dbQuery.sqf: Query %1 failed with %2", _query, str (_message param [1, "Unknown extDB3 error"])];
		};
		case 1: {
			if (count _message < 2) then {
				throw format ["fn_dbQuery.sqf: Successful response contained no data for query %1: %2", _query, _messageRaw];
			};
			if (QS_missionConfig_dbQueryDebug) then {
				diag_log format ["fn_dbQuery.sqf: Query %1 completed after %2 poll(s)", _query, _responsePolls];
			};
			_result = _message # 1;
			_complete = true;
		};
		case 3: {
			uiSleep _responsePollInterval;
		};
		case 5: {
			private _multipart = "";
			private _multipartChunks = 0;
			private _multipartComplete = false;
			while {!_multipartComplete} do {
				if (diag_tickTime >= _deadline) then {
					throw format ["fn_dbQuery.sqf: Timed out after %1 seconds reading multipart query %2", _queryTimeout, _query];
				};
				private _perfDbPart = ['dbQuery.callExtension.multipart',0,[_function]] call QS_fnc_perfBegin;
				private _pipe = "extDB3" callExtension format ["5:%1", _key];
				[_perfDbPart,0,[count _pipe]] call QS_fnc_perfEnd;
				if (diag_tickTime >= _deadline) then {
					throw format ["fn_dbQuery.sqf: Timed out during multipart read for query %1", _query];
				};

				if (_pipe isEqualTo "") then {
					_multipartComplete = true;
				} else {
					if (_multipartChunks >= _maxMultipartChunks) then {
						throw format ["fn_dbQuery.sqf: Exceeded %1 multipart chunks for query %2", _maxMultipartChunks, _query];
					};
					if (((count _multipart) + (count _pipe)) > _maxMultipartBytes) then {
						throw format ["fn_dbQuery.sqf: Multipart response exceeded %1 bytes for query %2", _maxMultipartBytes, _query];
					};
					_multipart = _multipart + _pipe;
					_multipartChunks = _multipartChunks + 1;
					uiSleep _multipartPollInterval;
				};
			};

			private _multipartMessage = [];
			try {
				_multipartMessage = parseSimpleArray _multipart;
			} catch {
				throw format ["fn_dbQuery.sqf: Invalid multipart response for query %1 (%2)", _query, _exception];
			};
			if !(
				_multipartMessage isEqualType []
				&& {count _multipartMessage >= 2}
				&& {_multipartMessage # 0 isEqualTo 1}
			) then {
				throw format ["fn_dbQuery.sqf: Malformed multipart response for query %1: %2", _query, _multipartMessage];
			};
			_result = _multipartMessage # 1;
			if (QS_missionConfig_dbQueryDebug) then {
				diag_log format [
					"fn_dbQuery.sqf: Query %1 completed in %2 multipart chunk(s)",
					_query, _multipartChunks
				];
			};
			_complete = true;
		};
		default {
			throw format ["fn_dbQuery.sqf: Unexpected response %1 for query %2", _message, _query];
		};
	};
};
	_result
	};
} catch {
	_dbException = _exception;
};

private _activeQueries = missionNamespace getVariable ["TGC_dbActiveQueries", 1];
missionNamespace setVariable ["TGC_dbActiveQueries", (_activeQueries - 1) max 0, false];

if (_dbException isNotEqualTo "") then {
	_now = diag_tickTime;
	_breaker = missionNamespace getVariable ["TGC_dbCircuitBreaker", [_now, 0, 0]];
	_breaker params ["_breakerWindowStarted", "_breakerFailures", "_breakerOpenUntil"];
	if ((_now - _breakerWindowStarted) > _breakerWindow) then {
		_breakerWindowStarted = _now;
		_breakerFailures = 0;
	};
	_breakerFailures = _breakerFailures + 1;
	if (_breakerFailures >= _breakerFailureLimit) then {
		_breakerOpenUntil = _now + _breakerCooldown;
		diag_log format ["fn_dbQuery.sqf: Opening database circuit breaker for %1 seconds after %2 failures", _breakerCooldown, _breakerFailures];
	};
	missionNamespace setVariable ["TGC_dbCircuitBreaker", [_breakerWindowStarted, _breakerFailures, _breakerOpenUntil], false];
	throw _dbException;
};

missionNamespace setVariable ["TGC_dbCircuitBreaker", [diag_tickTime, 0, 0], false];
if (QS_missionConfig_dbQueryDebug) then {
	diag_log format ["fn_dbQuery.sqf: Database operation finished in %1 seconds", (diag_tickTime - _executionStarted) toFixed 3];
};
_dbResult;
