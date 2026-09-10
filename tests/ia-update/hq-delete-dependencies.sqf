// Diagnostic native deletion probe. Actual mapper code; only its profiler is inert.
QS_fnc_perfBegin = {[]};
QS_fnc_perfEnd = {};
if (isServer) then {
    QS_core_vehicles_map = createHashMap;
    QS_hashmap_simpleObjectInfo = createHashMap;
    QS_fnc_commonMultiplyMatrix = compile preprocessFileLineNumbers 'production\code\functions\fn_commonMultiplyMatrix.sqf';
    QS_fnc_serverObjectsRecycler = compile preprocessFileLineNumbers 'production\code\functions\fn_serverObjectsRecycler.sqf';
    QS_fnc_serverObjectsMapper = compile preprocessFileLineNumbers 'tests\hq-delete-extracted\mapper-baseline.sqf';
    IA_fnc_mapperFinalPosition = compile preprocessFileLineNumbers 'tests\hq-delete-extracted\mapper-final-position.sqf';
    QS_fnc_customBuildingPositions = compile preprocessFileLineNumbers 'production\code\functions\fn_customBuildingPositions.sqf';
    missionNamespace setVariable ['QS_recycler_enabled',FALSE];
};
IA_hqDelete_deleted = [];
IA_fnc_hqDeleteWatch = {
    params ['_rows'];
    {
        _x params ['_index','','','_object'];
        _object setVariable ['IA_hqDelete_index',_index];
        _object addEventHandler ['Deleted',{
            params ['_object'];
            private _index = _object getVariable ['IA_hqDelete_index',-1];
            IA_hqDelete_deleted pushBackUnique _index;
            ['hq_deleted_event',[_index,netId _object,typeOf _object,owner _object]] call IA_fnc_log;
        }];
    } forEach _rows;
};
IA_fnc_hqDeleteSnapshot = {
    params ['_phase','_rows'];
    private _worldObjects = allMissionObjects 'All';
    {
        _x params ['_index','_label','_class','_object','_identity','_position','_rays','_direction','_up'];
        private _near = nearestObjects [ASLToAGL _position,[],40,TRUE];
        private _lookup = objectFromNetId _identity;
        private _geometryHits = 0;
        if (!isNull _object) then {
            {
                private _hits = lineIntersectsSurfaces [_x # 0,_x # 1,objNull,objNull,TRUE,20,'GEOM','NONE'];
                if ((_hits findIf {((_x # 2) isEqualTo _object) || {(_x # 3) isEqualTo _object}}) >= 0) then {
                    _geometryHits = _geometryHits + 1;
                };
            } forEach _rays;
        };
        ['hq_delete_snapshot',[_phase,_index,_label,_class,_identity,isNull _object,
            owner _object,local _object,isSimpleObject _object,getObjectType _object,alive _object,
            isNull _lookup,(!isNull _lookup && {_lookup isEqualTo _object}),
            _object in _worldObjects,_object in _near,_index in IA_hqDelete_deleted,_geometryHits,
            if (isNull _object) then {[]} else {getPosWorld _object}]] call IA_fnc_log;
        if (_phase isEqualTo 'before') then {
            ['hq_probe_created_' + str _index,!isNull _object,[_label,_identity]] call IA_fnc_assert;
            ['hq_probe_identity_before_' + str _index,!(_identity in ['','0:0']) &&
                {!isNull _lookup} && {_lookup isEqualTo _object},[_label,_identity]] call IA_fnc_assert;
            if (isServer || {_label isNotEqualTo 'mapped'}) then {
                ['hq_probe_geometry_before_' + str _index,_geometryHits > 0,[_label,_geometryHits]] call IA_fnc_assert;
                ['hq_probe_world_before_' + str _index,_object in _near &&
                    {_label isEqualTo 'simple' || {_object in _worldObjects}},[_label]] call IA_fnc_assert;
                private _directionError = vectorMagnitude ((vectorDir _object) vectorDiff _direction);
                private _upError = vectorMagnitude ((vectorUp _object) vectorDiff _up);
                ['hq_probe_transform_before_' + str _index,
                    (getPosWorld _object) distance _position <= 1 && {_directionError <= 0.02} && {_upError <= 0.02},
                    [_label,_directionError,_upError,vectorDir _object,vectorUp _object]] call IA_fnc_assert;
            };
        } else {
            ['hq_probe_removed_' + _phase + '_' + str _index,isNull _object && {isNull _lookup} &&
                {!(_object in _worldObjects)} && {!(_object in _near)} && {_geometryHits isEqualTo 0} &&
                {_label isEqualTo 'simple' || {_index in IA_hqDelete_deleted}},[_label,_identity]] call IA_fnc_assert;
        };
    } forEach _rows;
};
