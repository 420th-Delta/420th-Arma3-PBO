private _lateJoin = IA_role isEqualTo 'client1';
private _phaseKey = if (_lateJoin) then {'IA_hqDelete_client1Phase'} else {'IA_hqDelete_clientPhase'};
private _readyKey = if (_lateJoin) then {'IA_hqDelete_client1Ready'} else {'IA_hqDelete_clientReady'};
missionNamespace setVariable [_readyKey,TRUE,TRUE];
private _firstPhase = if (_lateJoin) then {'state_updated'} else {'before'};
private _until = diag_tickTime + 90;
waitUntil {uiSleep 0.1; (missionNamespace getVariable ['IA_hqDelete_phase','']) isEqualTo _firstPhase || {diag_tickTime >= _until}};
private _rows = +(missionNamespace getVariable ['IA_hqDelete_rows',[]]);
['hq_probe_client_rows',count _rows isEqualTo 13,[count _rows]] call IA_fnc_assert;
if (count _rows isNotEqualTo 13) exitWith {[] call IA_fnc_finish;};
// Baseline mapper discrepancies are the negative reproduction. Proposed and
// direct controls must reach their recorded positions before strict ray checks.
private _expectedPositionRows = _rows select {(_x # 1) isNotEqualTo 'mapped'};
private _proposedRows = _rows select {(_x # 1) isEqualTo 'proposed'};
private _stateReady = {
    params ['_feature'];
    (_proposedRows findIf {
        isNull (_x # 3) || {(((_x # 3) getVariable ['IA_hq_receivedState',[-1]]) # 0) isNotEqualTo _feature} ||
        {(vectorDir (_x # 3)) vectorDistance (_x # 7) > 0.02} ||
        {(vectorUp (_x # 3)) vectorDistance (_x # 8) > 0.02}
    }) < 0
};
_until = diag_tickTime + 15;
waitUntil {
    uiSleep 0.1;
    (((_expectedPositionRows findIf {isNull (_x # 3) || {(getPosWorld (_x # 3)) distance (_x # 5) > 1}}) < 0) &&
        {[if (_lateJoin) then {2} else {1}] call _stateReady}) || {diag_tickTime >= _until}
};
['hq_probe_client_positions_ready',(_expectedPositionRows findIf {isNull (_x # 3) ||
    {(getPosWorld (_x # 3)) distance (_x # 5) > 1}}) < 0] call IA_fnc_assert;
['hq_probe_initial_snapshot_transport_and_vectors',[if (_lateJoin) then {2} else {1}] call _stateReady,[_lateJoin]] call IA_fnc_assert;
if (_lateJoin) then {
    ['hq_probe_real_jip_snapshot',(_proposedRows findIf {
        !(((_x # 3) getVariable ['IA_hq_receivedState',[-1,'',FALSE,[],FALSE]]) # 4)
    }) < 0] call IA_fnc_assert;
};
if (!_lateJoin) then {
    private _baselineMismatches = _rows select {(_x # 1) isEqualTo 'mapped' &&
        {!isNull (_x # 3)} && {(getPosWorld (_x # 3)) distance (_x # 5) > 1}};
    ['hq_probe_baseline_mismatch_reproduced',count _baselineMismatches > 0,
        _baselineMismatches apply {[_x # 0,_x # 2]}] call IA_fnc_assert;
};
[_rows] call IA_fnc_hqDeleteWatch;
['before',_rows] call IA_fnc_hqDeleteSnapshot;
if (!_lateJoin) then {
    missionNamespace setVariable [_phaseKey,'before',TRUE];
    _until = diag_tickTime + 25;
    waitUntil {
        uiSleep 0.1;
        if ((missionNamespace getVariable ['IA_hqDelete_phase','']) isEqualTo 'state_updated') then {
            _rows = +(missionNamespace getVariable ['IA_hqDelete_rows',[]]);
            _proposedRows = _rows select {(_x # 1) isEqualTo 'proposed'};
        };
        ((missionNamespace getVariable ['IA_hqDelete_phase','']) isEqualTo 'state_updated' &&
            {[2] call _stateReady}) || {diag_tickTime >= _until}
    };
};
['hq_probe_replaced_snapshot_transport_and_vectors',[2] call _stateReady,[_lateJoin]] call IA_fnc_assert;
if (!_lateJoin) then {['before',[_rows # 7]] call IA_fnc_hqDeleteSnapshot;};
// A real remote client owner must not overwrite the authoritative snapshot.
private _house = (_proposedRows # 2) # 3;
[_house,0,'',FALSE,[[0,1,0],[0,0,1]]] remoteExecCall ['QS_fnc_clientApplyEntityState',clientOwner,FALSE];
uiSleep 0.5;
['hq_probe_forged_remote_snapshot_rejected',[2] call _stateReady,[_lateJoin]] call IA_fnc_assert;
missionNamespace setVariable [_phaseKey,'state_updated',TRUE];
{
    private _phase = _x;
    _until = diag_tickTime + (if (_lateJoin) then {35} else {170});
    waitUntil {uiSleep 0.1; (missionNamespace getVariable ['IA_hqDelete_phase','']) isEqualTo _phase || {diag_tickTime >= _until}};
    ['hq_probe_phase_' + _phase,(missionNamespace getVariable ['IA_hqDelete_phase','']) isEqualTo _phase] call IA_fnc_assert;
    [_phase,_rows] call IA_fnc_hqDeleteSnapshot;
    missionNamespace setVariable [_phaseKey,_phase,TRUE];
} forEach ['after_1s','after_10s'];
[] call IA_fnc_finish;
