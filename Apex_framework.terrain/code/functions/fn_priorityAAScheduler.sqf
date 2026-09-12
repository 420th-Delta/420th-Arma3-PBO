/* Server-only Priority AA channel. TICK is called by core; AO records a new Classic AO. */
if (!isServer) exitWith {};
params [['_action','TICK'],['_data',[]],['_aoPlayerCount',-1]];
private _population = if (_action isEqualTo 'TICK') then {_data param [3,-1]} else {_aoPlayerCount};
private _enhanced = [_population] call QS_fnc_airDefenseUseEnhanced;
private _onNewAO = missionNamespace getVariable ['QS_missionConfig_priorityAA_onNewAO',FALSE];
private _state = serverNamespace getVariable ['QS_priorityAA_scheduler',createHashMap];
if ((count _state) isEqualTo 0) then {
	_state = createHashMapFromArray [
		['script',scriptNull],['active',FALSE],['instance',0],['generation',0],
		['pending',[]],['request',[]],['due',-1],['retryAt',0],['spawnRecorded',FALSE],
		['mode',_onNewAO],['requestIsAO',FALSE],['requestForced',FALSE],['enhanced',_enhanced]
	];
	serverNamespace setVariable ['QS_priorityAA_scheduler',_state];
	missionNamespace setVariable ['QS_priorityAA_active',FALSE,TRUE];
	missionNamespace setVariable ['QS_priorityAA_position',[],TRUE];
	missionNamespace setVariable ['QS_priorityAA_evacPosition',[],TRUE];
};
if ((_state get 'enhanced') isNotEqualTo _enhanced) then {
	// A population transition begins a fresh policy period; active objectives finish normally.
	_state set ['enhanced',_enhanced];
	_state set ['pending',[]];
	_state set ['requestIsAO',FALSE];
	_state set ['due',-1];
	_state set ['retryAt',0];
};
if ((_state get 'mode') isNotEqualTo _onNewAO) then {
	// A mode switch cannot replay an AO request captured under the other policy.
	_state set ['mode',_onNewAO];
	_state set ['pending',[]];
	_state set ['requestIsAO',FALSE];
	_state set ['due',-1];
};
if (_action isEqualTo 'AO') exitWith {
	private _generation = (_state get 'generation') + 1;
	_state set ['generation',_generation];
	if (_onNewAO && _enhanced) then {
		// Retain only the latest AO while an unfinished battery owns the channel.
		_state set ['pending',[_generation,+_data]];
	};
};
if (_action isNotEqualTo 'TICK') exitWith {};
_data params ['_now','_aiCount','_unitCap','_playerCount'];
private _interval = missionNamespace getVariable ['QS_missionConfig_priorityAA_interval',[600,1800]];
private _intervalMin = (_interval param [0,600]) max 1;
private _intervalMax = (_interval param [1,1800]) max _intervalMin;
private _active = _state get 'active';
if (_active) then {
	private _instance = _state get 'instance';
	if (
		!(_state get 'spawnRecorded') &&
		{(missionNamespace getVariable ['QS_priorityAA_spawnedInstance',-1]) isEqualTo _instance}
	) then {
		_state set ['spawnRecorded',TRUE];
		if (_enhanced) then {_state set ['due',_now + _intervalMin + random (_intervalMax - _intervalMin)];};
		_state set ['request',[]];
	};
	if (scriptDone (_state get 'script')) then {
		if !(_state get 'spawnRecorded') then {
			private _request = _state get 'request';
			private _pending = _state get 'pending';
			if (
				_enhanced && {_onNewAO} && {_state get 'requestIsAO'} &&
				{!(missionNamespace getVariable ['QS_priorityAA_abort',FALSE])} &&
				{_request isNotEqualTo []} &&
				{(_pending isEqualTo []) || {(_request # 0) > (_pending # 0)}}
			) then {
				_state set ['pending',_request];
			};
			if ((_state get 'requestForced') && {!(missionNamespace getVariable ['QS_priorityAA_abort',FALSE])}) then {
				missionNamespace setVariable ['QS_priorityAA_force',TRUE,FALSE];
			};
			_state set ['retryAt',_now + 60];
			diag_log format ['Priority AA: instance %1 did not publish a successful spawn; retry deferred.',_instance];
		};
		_state set ['active',FALSE];
		_state set ['script',scriptNull];
		missionNamespace setVariable ['QS_priorityAA_active',FALSE,TRUE];
		missionNamespace setVariable ['QS_priorityAA_position',[],TRUE];
		missionNamespace setVariable ['QS_priorityAA_abort',FALSE,FALSE];
	};
};
private _enabled = missionNamespace getVariable ['QS_missionConfig_priorityAA_enabled',TRUE];
private _aoPosition = missionNamespace getVariable ['QS_AOpos',[]];
private _validAO = (_aoPosition isEqualType []) && {(count _aoPosition) >= 2} && {(_aoPosition # 0) > 0 || {(_aoPosition # 1) > 0}};
private _ready = _enabled && _enhanced && (_now > 80) && _validAO;
if (!_ready) exitWith {};
// The initial timer starts after readiness; later timers start at successful creation.
if ((_state get 'due') < 0) then {
	_state set ['due',_now + _intervalMin + random (_intervalMax - _intervalMin)];
};
if (_state get 'active') exitWith {};
if (
	(missionNamespace getVariable ['QS_priorityAA_paused',FALSE]) ||
	{missionNamespace getVariable ['QS_priorityAA_legacyActive',FALSE]} ||
	{missionNamespace getVariable ['QS_customAO_blockSideMissions',FALSE]} ||
	{_aiCount >= _unitCap && {_playerCount >= 20}} ||
	{_now < (_state get 'retryAt')}
) exitWith {};
private _forced = missionNamespace getVariable ['QS_priorityAA_force',FALSE];
private _pending = _state get 'pending';
private _due = if (_onNewAO) then {_pending isNotEqualTo []} else {_now >= (_state get 'due')};
if (!_forced && !_due) exitWith {};
private _request = if (_onNewAO && {_pending isNotEqualTo []}) then {+_pending} else {[(_state get 'generation'),+_aoPosition]};
private _instance = (_state get 'instance') + 1;
_state set ['instance',_instance];
_state set ['request',_request];
_state set ['requestIsAO',_onNewAO && {_pending isNotEqualTo []}];
_state set ['requestForced',_forced];
_state set ['pending',[]];
_state set ['spawnRecorded',FALSE];
_state set ['active',TRUE];
missionNamespace setVariable ['QS_priorityAA_instanceId',_instance,FALSE];
missionNamespace setVariable ['QS_priorityAA_spawnedInstance',-1,FALSE];
missionNamespace setVariable ['QS_priorityAA_abort',FALSE,FALSE];
missionNamespace setVariable ['QS_priorityAA_success',FALSE,FALSE];
missionNamespace setVariable ['QS_priorityAA_force',FALSE,FALSE];
missionNamespace setVariable ['QS_priorityAA_active',TRUE,TRUE];
_state set ['script',[_instance,+(_request # 1)] spawn QS_fnc_SMpriorityAA];
