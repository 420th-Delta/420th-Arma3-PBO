if (!isServer) exitWith {};
['guided.dedicated',isDedicated] call IA_fnc_assert;
QS_fnc_clientDamageModifier = compile preprocessFileLineNumbers 'production\code\functions\fn_clientDamageModifier.sqf';
TGC_fnc_isFriendlyFire = compile preprocessFileLineNumbers 'production\TGC\Functions\Damage\fn_isFriendlyFire.sqf';
QS_missionConfig_reducedDamage = {0};
missionNamespace setVariable ['TGC_allowFF',nil];
private _source = loadFile 'production\code\functions\fn_artillerySupport.sqf';
private _start = _source find 'private _profiles = [';
['guided.production.profileStart',_start >= 0] call IA_fnc_assert;
if (_start < 0) exitWith {[] call IA_fnc_finish;};
private _tail = _source select [_start];
private _end = _tail find '];';
['guided.production.profileEnd',_end > 0] call IA_fnc_assert;
if (_end < 0) exitWith {[] call IA_fnc_finish;};
private _profiles = (call compile ((_tail select [0,_end + 2]) + '_profiles')) select {(_x # 0) in ['LASER','IR']};
['guided.production.twoProfiles',count _profiles isEqualTo 2] call IA_fnc_assert;
['guided_scope',['Focused direct-child targeting comparison: immediate native, delayed native, immediate forced target. These are controlled diagnostics, not copied production release. Actual profiles/modifier/helper loaded. All native damage returned unchanged; no real-player/full-worker claim.']] call IA_fnc_log;

IA_guided_tracks = [];
IA_guided_counts = createHashMap;
IA_guided_ff = createHashMap;
IA_guided_serial = 0;
IA_guided_fnc_count = {
    params ['_case','_event'];
    private _key = _case + ':' + _event;
    IA_guided_counts set [_key,1 + (IA_guided_counts getOrDefault [_key,0])];
};
IA_guided_fnc_target = {
    params ['_shot','_target','_case','_when',['_force',FALSE]];
    private _assigned = alive _target && {if (_force) then {_shot setMissileTarget [_target,TRUE]} else {_shot setMissileTarget _target}};
    ['guided_target',[_case,_when,typeOf _shot,_assigned,typeOf (missileTarget _shot),getPosASL _shot,velocity _shot,vectorDir _shot,_force,alive _target]] call IA_fnc_log;
    ['guided.case.targetAccepted',_assigned,[_case,_when,_force,alive _target]] call IA_fnc_assert;
};
IA_guided_fnc_track = {
    params ['_shot','_case','_target','_mode',['_generation',0]];
    IA_guided_serial = IA_guided_serial + 1;
    private _id = IA_guided_serial;
    IA_guided_tracks pushBack [_shot,_case,_generation,_id,FALSE,[],diag_tickTime,typeOf _shot,_target];
    _shot setVariable ['IA_guided_meta',[_case,_target,_mode,_generation,_id]];
    _shot addEventHandler ['SubmunitionCreated',{
        params ['_parent','_child','_position','_velocity'];
        (_parent getVariable 'IA_guided_meta') params ['_case','_target','_mode','_generation','_id'];
        [_case,'SubmunitionCreated'] call IA_guided_fnc_count;
        ['guided_child',[_case,_id,typeOf _parent,typeOf _child,_position,_velocity,vectorDir _child,
            typeOf (missileTarget _child),(getShotParents _child) apply {typeOf _x}]] call IA_fnc_log;
        [_child,_case,_target,_mode,_generation + 1] call IA_guided_fnc_track;
        if (_mode isEqualTo 'CHILD_IMMEDIATE_500') then {[_child,_target,_case,'child-immediate'] call IA_guided_fnc_target;};
        if (_mode isEqualTo 'CHILD_DELAYED_500') then {
            [_child,_target,_case] spawn {
                params ['_child','_target','_case'];
                uiSleep 0.1;
                if (!isNull _child) then {[_child,_target,_case,'child-after-0.1s'] call IA_guided_fnc_target;};
            };
        };
    }];
    _shot addEventHandler ['Explode',{
        params ['_shot','_position','_velocity'];
        (_shot getVariable 'IA_guided_meta') params ['_case','_target','_mode','_generation','_id'];
        [_case,'Explode'] call IA_guided_fnc_count;
        private _finitePosition = (_position findIf {!finite _x}) < 0;
        private _distance = if (_finitePosition) then {_position distance (getPosASL _target)} else {-1};
        ['guided_explode',[_case,_id,typeOf _shot,_position,_velocity,_distance,
            (getShotParents _shot) apply {typeOf _x},_finitePosition]] call IA_fnc_log;
    }];
};
IA_guided_fnc_watch = {
    params ['_unit','_case','_label'];
    _unit setVariable ['IA_guided_victim',[_case,_label]];
    _unit setVariable ['QS_inzone',[FALSE,0,FALSE]];
    _unit setVariable ['QS_unit_side',WEST];
    _unit setVariable ['TGC_vehicle_side',WEST];
    _unit addEventHandler ['HandleDamage',{
        params ['_unit','_selection','_damage','_source','_ammo','_hitIndex','_instigator'];
        (_unit getVariable 'IA_guided_victim') params ['_case','_label'];
        if (_ammo isNotEqualTo '') then {
            [_case,'OrdnanceDamage'] call IA_guided_fnc_count;
            private _modifier = if (_unit isKindOf 'CAManBase') then {_this call QS_fnc_clientDamageModifier} else {-1};
            if (_unit isKindOf 'CAManBase' && {isNull objectParent _unit} && {!isNull _instigator} &&
                {side (group _instigator) isEqualTo WEST} && {_source isNotEqualTo _unit}) then {
                private _ff = IA_guided_ff getOrDefault [_case,[0,0]];
                _ff set [0,(_ff # 0) + 1];
                if (_modifier isNotEqualTo 0) then {_ff set [1,(_ff # 1) + 1];};
                IA_guided_ff set [_case,_ff];
            };
            ['guided_damage',[_case,_label,_selection,_damage,_ammo,typeOf _source,typeOf _instigator,
                str (side (group _instigator)),_modifier,_this call TGC_fnc_isFriendlyFire]] call IA_fnc_log;
        };
        _damage
    }];
    _unit addEventHandler ['Hit',{
        params ['_unit','_source','_damage','_instigator'];
        (_unit getVariable 'IA_guided_victim') params ['_case','_label'];
        ['guided_hit',[_case,_label,_damage,typeOf _source,typeOf _instigator,
            str (side (group _instigator)),(['ATTACKER',_source,_instigator,_unit] call TGC_fnc_isFriendlyFire) isEqualTo _instigator]] call IA_fnc_log;
    }];
};

private _callerGroup = createGroup [WEST,TRUE];
private _caller = _callerGroup createUnit ['B_Soldier_F',[14500,18500,0],[],0,'CAN_COLLIDE'];
_caller disableAI 'ALL';
_caller allowDamage FALSE;
_caller addRating 1e6;
private _objects = [_caller];
private _groups = [_callerGroup];
private _cases = [];
private _modes = ['DIRECT_CHILD_FORCE_500','DIRECT_CHILD_IMMEDIATE_500','DIRECT_CHILD_DELAYED_500'];
{
    private _profile = _x;
    private _profileIndex = _forEachIndex;
    private _ammo = getText (configFile >> 'CfgMagazines' >> (_profile # 4) >> 'ammo');
    private _childAmmo = getText (configFile >> 'CfgAmmo' >> _ammo >> 'submunitionAmmo');
    ['guided.ammo.nativeClasses',isClass (configFile >> 'CfgAmmo' >> _ammo) && {isClass (configFile >> 'CfgAmmo' >> _childAmmo)},[_ammo,_childAmmo]] call IA_fnc_assert;
    {
        private _class = _x;
        private _cfg = configFile >> 'CfgAmmo' >> _class;
        {
            private _fields = _x apply {
                private _property = _cfg >> _x;
                [_x,if (isText _property) then {getText _property} else {if (isArray _property) then {getArray _property} else {getNumber _property}}]
            };
            ['guided_config',[_class,_fields]] call IA_fnc_log;
        } forEach [
            ['simulation','submunitionAmmo','triggerTime','triggerDistance','submunitionDirectionType','submunitionInitSpeed','submunitionParentSpeedCoef'],
            ['autoSeekTarget','laserLock','irLock','missileLockCone','missileLockMinDistance','missileLockMaxDistance','fuseDistance'],
            ['initTime','thrust','thrustTime','timeToLive','maxSpeed','maneuvrability','indirectHit','indirectHitRange']
        ];
    } forEach [_ammo,_childAmmo];
    {
        private _mode = _x;
        private _case = (_profile # 0) + ':' + _mode;
        // Put IR first at the original damage arena to reproduce its immediate
        // assignment rejection; LASER is a separate designation control lane.
        private _origin = [14500 + (700 * _forEachIndex),16000 + (1400 * (1 - _profileIndex)),0];
        ['guided.arena.land',!surfaceIsWater _origin,[_case,_origin]] call IA_fnc_assert;
        private _group = createGroup [WEST,TRUE];
        _groups pushBack _group;
        private _designation = createVehicle [['LaserTargetW','B_Quadbike_01_F'] select ((_profile # 0) isEqualTo 'IR'),_origin,[],0,'CAN_COLLIDE'];
        if ((_profile # 0) isEqualTo 'IR') then {
            private _enemyGroup = createGroup [EAST,TRUE];
            private _driver = _enemyGroup createUnit ['O_Soldier_F',_origin vectorAdd [20,0,0],[],0,'CAN_COLLIDE'];
            _driver disableAI 'ALL';
            _driver moveInDriver _designation;
            _designation setVehicleTIPars [1,1,1];
            _caller reveal [_designation,4];
            _groups pushBack _enemyGroup;
            _objects pushBack _driver;
            ['guided.ir.enemyDesignation',!isNull effectiveCommander _designation &&
                {((side group effectiveCommander _designation) getFriend WEST) < 0.6} &&
                {(_caller knowsAbout _designation) >= 1.5},[_case,str (side group effectiveCommander _designation)]] call IA_fnc_assert;
        };
        [_designation,_case,'DESIGNATION'] call IA_guided_fnc_watch;
        _objects pushBack _designation;
        {
            _x params ['_radius','_angle'];
            private _unit = _group createUnit ['B_Soldier_F',_origin getPos [_radius,_angle],[],0,'CAN_COLLIDE'];
            _unit disableAI 'ALL';
            [_unit,_case,format ['FOOT_%1',_radius]] call IA_guided_fnc_watch;
            _objects pushBack _unit;
        } forEach [[3,0],[8,120],[15,240]];
        private _height = [_profile # 7,700] select (_mode isEqualTo 'NATIVE_700');
        private _class = _childAmmo;
        private _shot = objNull;
        isNil {
            _shot = createVehicle [_class,_origin vectorAdd [0,0,_height],[],0,'CAN_COLLIDE'];
            [_shot,_case,_designation,_mode] call IA_guided_fnc_track;
            _shot setShotParents [_caller,_caller];
            _shot setVectorDirAndUp [[0,0,-1],[0,1,0]];
            if (_mode isNotEqualTo 'DIRECT_CHILD_DELAYED_500') then {
                [_shot,_designation,_case,'release',_mode isEqualTo 'DIRECT_CHILD_FORCE_500'] call IA_guided_fnc_target;
            };
            _shot setVelocity [0,0,-(_profile # 8)];
        };
        if (_mode isEqualTo 'DIRECT_CHILD_DELAYED_500') then {
            [_shot,_designation,_case] spawn {
                params ['_shot','_designation','_case'];
                uiSleep 0.1;
                if (!isNull _shot) then {[_shot,_designation,_case,'direct-child-after-0.1s'] call IA_guided_fnc_target;};
            };
        };
        ['guided_release',[_case,_class,_height,_profile # 8,getPosASL _shot,getPosASL _designation,vectorDir _shot,velocity _shot]] call IA_fnc_log;
        _cases pushBack _case;
    } forEach _modes;
} forEach _profiles;
private _until = diag_tickTime + 30;
private _fastUntil = diag_tickTime + 7;
while {diag_tickTime < _until} do {
    {
        _x params ['_shot','_case','_generation','_id','_gone','_last','_born','_class','_target'];
        if (!_gone) then {
            if (isNull _shot) then {
                _x set [4,TRUE];
                ['guided_disappeared',[_case,_id,_class,diag_tickTime - _born,_last]] call IA_fnc_log;
            } else {
                private _position = getPosASL _shot;
                private _finitePosition = (_position findIf {!finite _x}) < 0;
                private _state = [_position,velocity _shot,vectorDir _shot,typeOf (missileTarget _shot),
                    if (_finitePosition) then {_shot distance _target} else {-1},vectorUp _shot,_finitePosition];
                _x set [5,_state];
                ['guided_trace',[_case,_id,_class,diag_tickTime - _born,_state]] call IA_fnc_log;
            };
        };
    } forEach IA_guided_tracks;
    uiSleep ([0.5,0.1] select (diag_tickTime < _fastUntil));
};
{
    private _case = _x;
    private _ff = IA_guided_ff getOrDefault [_case,[0,0]];
    private _counts = ['SubmunitionCreated','Explode','OrdnanceDamage'] apply {[_x,IA_guided_counts getOrDefault [_case + ':' + _x,0]]};
    ['guided_summary',[_case,_counts,_ff]] call IA_fnc_log;
    ['guided.case.nativeOrdnanceHit',(IA_guided_counts getOrDefault [_case + ':OrdnanceDamage',0]) > 0,[_case,_counts]] call IA_fnc_assert;
    ['guided.case.footFriendlyProtection',(_ff # 0) > 0 && {(_ff # 1) isEqualTo 0},[_case,_ff]] call IA_fnc_assert;
} forEach _cases;
{if (!isNull (_x # 0)) then {deleteVehicle (_x # 0);};} forEach IA_guided_tracks;
{if (!isNull _x) then {deleteVehicle _x;};} forEach _objects;
{deleteGroup _x;} forEach _groups;
[] call IA_fnc_finish;
