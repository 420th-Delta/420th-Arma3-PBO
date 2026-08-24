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
params ["_function", ["_args", []], ["_wait", true]];
if (_wait && {!canSuspend}) then {
	throw "fn_dbQuery.sqf: Waiting database queries require a scheduled environment";
};

// extDB3 calls cannot be interrupted while the extension is executing, but
// response polling still needs a hard ceiling so a lost key cannot leave a
// scheduled server worker alive forever.
private _queryTimeout = 30;
private _maxResponsePolls = 300;
private _responsePollInterval = 0.1;
private _maxMultipartChunks = 2048;
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
private _keyResponse = "extDB3" callExtension _args;

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

	private _messageRaw = "extDB3" callExtension format ["4:%1", _key];
	if (diag_tickTime >= _deadline) then {
		throw format ["fn_dbQuery.sqf: Timed out during response poll %1 for query %2", _responsePolls, _query];
	};
	if (_messageRaw isEqualTo "") then {
		throw format ["fn_dbQuery.sqf: No response received for query %1", _query];
	};

	if (QS_missionConfig_dbQueryDebug) then {
		diag_log format ["fn_dbQuery.sqf: Query %1 received ""%2""", _query, _messageRaw];
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
				private _pipe = "extDB3" callExtension format ["5:%1", _key];
				if (diag_tickTime >= _deadline) then {
					throw format ["fn_dbQuery.sqf: Timed out during multipart read for query %1", _query];
				};

				if (_pipe isEqualTo "") then {
					_multipartComplete = true;
				} else {
					if (_multipartChunks >= _maxMultipartChunks) then {
						throw format ["fn_dbQuery.sqf: Exceeded %1 multipart chunks for query %2", _maxMultipartChunks, _query];
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
					"fn_dbQuery.sqf: Query %1 received multipart ""%2""",
					_query, str _result
				];
			};
			_complete = true;
		};
		default {
			throw format ["fn_dbQuery.sqf: Unexpected response %1 for query %2", _message, _query];
		};
	};
};
_result;
