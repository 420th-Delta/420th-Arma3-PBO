private _until = diag_tickTime + 120;
waitUntil {uiSleep 0.2; missionNamespace getVariable ['IA_hqDelete_clientReady',FALSE] || {diag_tickTime >= _until}};
private _clientReady = missionNamespace getVariable ['IA_hqDelete_clientReady',FALSE];
['hq_probe_client_ready',_clientReady] call IA_fnc_assert;
if (!_clientReady) exitWith {[] call IA_fnc_finish;};
private _lateJoin = (missionNamespace getVariable ['IA_hqDelete_expectedClients',1]) > 1;
if (_lateJoin) then {
    ['hq_probe_published_before_second_client',
        !(missionNamespace getVariable ['IA_hqDelete_client1Ready',FALSE]) &&
        {count (allPlayers select {!(_x isKindOf 'HeadlessClient_F')}) isEqualTo 1}] call IA_fnc_assert;
};
private _classes = ['Land_Unfinished_Building_01_F','Land_Cargo_HQ_V2_F','Land_d_Windmill01_F',
    'Land_Cargo_House_V2_F','Land_Cargo_Patrol_V2_F'];
private _data = [];
{_data pushBack [_x,[_forEachIndex * 60,0,0],23 + (_forEachIndex * 31),
    [[],[5,3]] select (_forEachIndex isEqualTo 2),FALSE,FALSE,FALSE,{}];} forEach _classes;
private _base = [14000,16000,0];
private _objects = [_base,0,_data,TRUE] call QS_fnc_serverObjectsMapper;
private _proposedData = _data apply {+_x};
{
    _x set [7,{
        params ['_house'];
        _house setVariable ['QS_client_featureType',1,FALSE];
        if (_house isKindOf 'Land_d_Windmill01_F') then {
            [_house,8,-6] call BIS_fnc_setPitchBank;
        };
        [_house]
    }];
} forEach _proposedData;
private _proposed = [_base vectorAdd [0,120,0],0,_proposedData,TRUE] call IA_fnc_mapperFinalPosition;
_objects append _proposed;
private _labels = ['mapped','mapped','mapped','mapped','mapped',
    'proposed','proposed','proposed','proposed','proposed','direct','crate','simple'];
_classes append +_classes;
private _direct = createVehicle ['Land_Cargo_HQ_V2_F',_base vectorAdd [300,0,0],[],0,'CAN_COLLIDE'];
_direct allowDamage FALSE;
_direct enableSimulationGlobal FALSE;
_objects pushBack _direct;
_objects pushBack createVehicle ['Box_NATO_Ammo_F',_base vectorAdd [360,0,0],[],0,'CAN_COLLIDE'];
_objects pushBack createSimpleObject ['a3\structures_f\mil\fortification\hbarrier_3_f.p3d',ATLToASL (_base vectorAdd [420,0,0])];
_classes append ['Land_Cargo_HQ_V2_F','Box_NATO_Ammo_F','Land_HBarrier_3_F'];
// Let engine registration and model geometry settle before serializing references.
uiSleep 3;
// Defense queries these engine positions before cleanup. Keep the direct-house
// control free of this query to distinguish that path from mapping alone.
{
    private _nativePositions = _x buildingPos -1;
    private _customPositions = [_x,+_nativePositions] call QS_fnc_customBuildingPositions;
    ['hq_building_positions',[_forEachIndex,typeOf _x,count _nativePositions,count _customPositions]] call IA_fnc_log;
} forEach (_objects select [0,10]);
private _captureRow = {
    params ['_object','_index'];
    private _bounds = boundingBoxReal _object;
    private _lo = _bounds # 0;
    private _hi = _bounds # 1;
    private _rays = [];
    {
        private _fx = _x;
        {
            private _mx = (_lo # 0) + (((_hi # 0) - (_lo # 0)) * _fx);
            private _my = (_lo # 1) + (((_hi # 1) - (_lo # 1)) * _x);
            _rays pushBack [_object modelToWorldWorld [_mx,_my,(_hi # 2) + 2],
                _object modelToWorldWorld [_mx,_my,(_lo # 2) - 2]];
        } forEach [0.2,0.5,0.8];
    } forEach [0.2,0.5,0.8];
    [_index,_labels # _index,_classes # _index,_object,netId _object,
        getPosWorld _object,_rays,vectorDir _object,vectorUp _object]
};
private _rows = [];
{_rows pushBack ([_x,_forEachIndex] call _captureRow);} forEach _objects;
[_rows] call IA_fnc_hqDeleteWatch;
missionNamespace setVariable ['IA_hqDelete_rows',_rows,TRUE];
['before',_rows] call IA_fnc_hqDeleteSnapshot;
missionNamespace setVariable ['IA_hqDelete_phase','before',TRUE];
_until = diag_tickTime + 30;
waitUntil {uiSleep 0.1; (missionNamespace getVariable ['IA_hqDelete_clientPhase','']) isEqualTo 'before' || {diag_tickTime >= _until}};
['hq_probe_client_before',(missionNamespace getVariable ['IA_hqDelete_clientPhase','']) isEqualTo 'before'] call IA_fnc_assert;
// Replace the same snapshot with a new windmill tilt and feature update. The
// final orientation must replace the earlier callback tilt on a late client.
private _windmill = _proposed # 2;
private _previousUp = vectorUp _windmill;
[_windmill,-6,4] call BIS_fnc_setPitchBank;
['hq_probe_replacement_orientation_changed',(vectorUp _windmill) vectorDistance _previousUp > 0.05] call IA_fnc_assert;
_windmill setVariable ['QS_client_houseVectors',[vectorDir _windmill,vectorUp _windmill],FALSE];
_rows set [7,[_windmill,7] call _captureRow];
['before',[_rows # 7]] call IA_fnc_hqDeleteSnapshot;
missionNamespace setVariable ['IA_hqDelete_rows',_rows,TRUE];
{
    _x setVariable ['QS_client_featureType',2,FALSE];
    [_x] call QS_fnc_serverPublishEntityState;
} forEach _proposed;
if (_lateJoin) then {
    ['hq_probe_latest_snapshot_before_second_client',
        !(missionNamespace getVariable ['IA_hqDelete_client1Ready',FALSE]) &&
        {count (allPlayers select {!(_x isKindOf 'HeadlessClient_F')}) isEqualTo 1}] call IA_fnc_assert;
};
missionNamespace setVariable ['IA_hqDelete_phase','state_updated',TRUE];
_until = diag_tickTime + (if (_lateJoin) then {150} else {25});
waitUntil {
    uiSleep 0.1;
    ((missionNamespace getVariable ['IA_hqDelete_clientPhase','']) isEqualTo 'state_updated' &&
        {!_lateJoin || {(missionNamespace getVariable ['IA_hqDelete_client1Phase','']) isEqualTo 'state_updated'}}) ||
        {diag_tickTime >= _until}
};
['hq_probe_client_snapshot_replacement',(missionNamespace getVariable ['IA_hqDelete_clientPhase','']) isEqualTo 'state_updated'] call IA_fnc_assert;
if (_lateJoin) then {
    ['hq_probe_late_client_snapshot',(missionNamespace getVariable ['IA_hqDelete_client1Phase','']) isEqualTo 'state_updated'] call IA_fnc_assert;
};
{deleteVehicle _x;} forEach _objects;
['hq_delete_requested',_rows apply {[_x # 0,_x # 4]}] call IA_fnc_log;
{
    _x params ['_phase','_delay'];
    uiSleep _delay;
    [_phase,_rows] call IA_fnc_hqDeleteSnapshot;
    missionNamespace setVariable ['IA_hqDelete_phase',_phase,TRUE];
    _until = diag_tickTime + 10;
    waitUntil {uiSleep 0.1; ((missionNamespace getVariable ['IA_hqDelete_clientPhase','']) isEqualTo _phase &&
        {!_lateJoin || {(missionNamespace getVariable ['IA_hqDelete_client1Phase','']) isEqualTo _phase}}) || {diag_tickTime >= _until}};
    ['hq_probe_client_' + _phase,(missionNamespace getVariable ['IA_hqDelete_clientPhase','']) isEqualTo _phase] call IA_fnc_assert;
    if (_lateJoin) then {
        ['hq_probe_late_client_' + _phase,(missionNamespace getVariable ['IA_hqDelete_client1Phase','']) isEqualTo _phase] call IA_fnc_assert;
    };
} forEach [['after_1s',1],['after_10s',9]];
missionNamespace setVariable ['IA_hqDelete_phase','finished',TRUE];
[] call IA_fnc_finish;
