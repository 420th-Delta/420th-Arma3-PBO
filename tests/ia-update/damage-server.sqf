if (!isServer) exitWith {};
['damage.dedicated',isDedicated] call IA_fnc_assert;
QS_fnc_clientDamageModifier = compile preprocessFileLineNumbers 'production\code\functions\fn_clientDamageModifier.sqf';
TGC_fnc_isFriendlyFire = compile preprocessFileLineNumbers 'production\TGC\Functions\Damage\fn_isFriendlyFire.sqf';
QS_missionConfig_reducedDamage = {0};
missionNamespace setVariable ['TGC_allowFF',nil];
private _profiles = call compile preprocessFileLineNumbers 'tests\damage-extracted\profiles.sqf';
private _fn_resolveAmmo = compile preprocessFileLineNumbers 'tests\damage-extracted\resolve-ammo.sqf';
private _release = preprocessFileLineNumbers 'tests\damage-extracted\release.sqf';
['damage.production.releaseAvailable',_release isNotEqualTo ''] call IA_fnc_assert;
if (_release isEqualTo '') exitWith {[] call IA_fnc_finish;};
private _fn_productionRelease = compile (_release + toString [10] + '_projectile');
['damage.production.eightProfiles',count _profiles isEqualTo 8] call IA_fnc_assert;
['damage_probe_policy',['Exact production profiles/resolver/release/modifier/helper; raw damage returned unchanged. NULL_SOURCE deliberately changes attribution after exact release to test the historical damage regression. CALLER_SOURCE leaves production attribution intact. No full worker, danger-close admission, real player or Robocop UI claim.']] call IA_fnc_log;

IA_damage_counts = createHashMap;
IA_damage_ff = createHashMap;
IA_damage_finite = createHashMap;
IA_damage_shots = [];
IA_damage_fnc_entity = {
    params ['_entity'];
    [str _entity,typeOf _entity,netId _entity,isNull _entity,isPlayer _entity,str (side (group _entity)),owner _entity]
};
IA_damage_fnc_record = {
    params ['_case','_kind','_payload'];
    private _key = _case + ':' + _kind;
    private _count = 1 + (IA_damage_counts getOrDefault [_key,0]);
    IA_damage_counts set [_key,_count];
    // Keep every kind count; cap huge cluster event payloads separately.
    if (_count <= 160) then {['damage_event',[_case,_kind,_count,_payload]] call IA_fnc_log;};
};
IA_damage_fnc_sampleFlight = {
    params ['_case','_position','_velocity','_direction'];
    private _totals = IA_damage_finite getOrDefault [_case,[0,0,[]]];
    _totals set [0,(_totals # 0) + 1];
    if (((_position + _velocity + _direction) findIf {!finite _x}) >= 0) then {
        _totals set [1,(_totals # 1) + 1];
        if ((_totals # 2) isEqualTo []) then {_totals set [2,[_position,_velocity,_direction]];};
    };
    IA_damage_finite set [_case,_totals];
};
IA_damage_fnc_trackShot = {
    params ['_shot','_case',['_generation',0]];
    _shot setVariable ['IA_damage_case',_case];
    _shot setVariable ['IA_damage_generation',_generation];
    IA_damage_shots pushBack _shot;
    [_case,getPosASL _shot,velocity _shot,vectorDir _shot] call IA_damage_fnc_sampleFlight;
    _shot addEventHandler ['SubmunitionCreated',{
        params ['_parent','_child','_position','_velocity'];
        private _case = _parent getVariable ['IA_damage_case','UNKNOWN'];
        private _generation = 1 + (_parent getVariable ['IA_damage_generation',0]);
        [_case,'SubmunitionCreated',[typeOf _parent,typeOf _child,_generation,_position,_velocity,
            (getShotParents _parent) apply {[_x] call IA_damage_fnc_entity},
            (getShotParents _child) apply {[_x] call IA_damage_fnc_entity},
            typeOf (missileTarget _child),vectorDir _child]] call IA_damage_fnc_record;
        [_child,_case,_generation] call IA_damage_fnc_trackShot;
    }];
    _shot addEventHandler ['Explode',{
        params ['_shot','_position','_velocity'];
        [_shot getVariable ['IA_damage_case','UNKNOWN'],_position,_velocity,vectorDir _shot] call IA_damage_fnc_sampleFlight;
        [_shot getVariable ['IA_damage_case','UNKNOWN'],'Explode',[typeOf _shot,_position,_velocity,
            (getShotParents _shot) apply {[_x] call IA_damage_fnc_entity}]] call IA_damage_fnc_record;
    }];
};
IA_damage_fnc_watch = {
    params ['_victim','_case','_label'];
    _victim setVariable ['IA_damage_case',_case];
    _victim setVariable ['IA_damage_label',_label];
    _victim setVariable ['QS_inzone',[FALSE,0,FALSE]];
    _victim setVariable ['QS_unit_side',WEST];
    _victim setVariable ['TGC_vehicle_side',WEST];
    _victim addEventHandler ['HandleDamage',{
        params ['_unit','_selection','_damage','_source','_ammo','_hitIndex','_instigator','_hitPoint','_direct'];
        private _modifier = if (_unit isKindOf 'CAManBase') then {_this call QS_fnc_clientDamageModifier} else {-1};
        private _attacker = ['ATTACKER',_source,_instigator,_unit] call TGC_fnc_isFriendlyFire;
        if (_ammo isNotEqualTo '') then {
            private _key = (_unit getVariable 'IA_damage_case') + ':OrdnanceHandleDamage';
            IA_damage_counts set [_key,1 + (IA_damage_counts getOrDefault [_key,0])];
        };
        if (_unit isKindOf 'CAManBase' && {isNull objectParent _unit} && {_ammo isNotEqualTo ''} &&
            {!isNull _instigator} && {(side (group _instigator)) isEqualTo WEST} && {_source isNotEqualTo _unit}) then {
            private _case = _unit getVariable 'IA_damage_case';
            private _totals = IA_damage_ff getOrDefault [_case,[0,0,[]]];
            _totals set [0,(_totals # 0) + 1];
            if (_modifier isNotEqualTo 0) then {
                _totals set [1,(_totals # 1) + 1];
                if ((_totals # 2) isEqualTo []) then {_totals set [2,[_ammo,_modifier,str _source,str _instigator,str _attacker]];};
            };
            IA_damage_ff set [_case,_totals];
        };
        [_unit getVariable 'IA_damage_case','HandleDamage',[
            _unit getVariable 'IA_damage_label',_selection,_damage,_ammo,_hitIndex,_hitPoint,_direct,_this param [9,-1],
            [_source] call IA_damage_fnc_entity,[_instigator] call IA_damage_fnc_entity,
            [_attacker] call IA_damage_fnc_entity,_modifier,_this call TGC_fnc_isFriendlyFire,
            !isNull objectParent _unit,damage _unit]] call IA_damage_fnc_record;
        _damage
    }];
    _victim addEventHandler ['Hit',{
        params ['_unit','_source','_damage','_instigator'];
        private _attacker = ['ATTACKER',_source,_instigator,_unit] call TGC_fnc_isFriendlyFire;
        [_unit getVariable 'IA_damage_case','Hit',[
            _unit getVariable 'IA_damage_label',_damage,[_source] call IA_damage_fnc_entity,
            [_instigator] call IA_damage_fnc_entity,[_attacker] call IA_damage_fnc_entity,
            isNull _source,count crew (vehicle _source),lifeState _unit,time]] call IA_damage_fnc_record;
    }];
    _victim addEventHandler ['Killed',{
        params ['_unit','_killer','_instigator','_effects',['_shot',objNull]];
        [_unit getVariable 'IA_damage_case','Killed',[
            _unit getVariable 'IA_damage_label',[_killer] call IA_damage_fnc_entity,
            [_instigator] call IA_damage_fnc_entity,typeOf _shot,
            (getShotParents _shot) apply {[_x] call IA_damage_fnc_entity}]] call IA_damage_fnc_record;
    }];
    _victim addEventHandler ['AmmoExplodedNear',{
        params ['_unit','_shot','_position','_velocity','_ammo','_explosive','_indirect','_invArmor','_damage'];
        [_unit getVariable 'IA_damage_case','AmmoExplodedNear',[
            _unit getVariable 'IA_damage_label',_ammo,_position,_damage,_indirect,
            (getShotParents _shot) apply {[_x] call IA_damage_fnc_entity}]] call IA_damage_fnc_record;
    }];
};

private _callerGroup = createGroup [WEST,TRUE];
private _caller = _callerGroup createUnit ['B_Soldier_F',[14500,17500,0],[],0,'CAN_COLLIDE'];
_caller disableAI 'ALL';
_caller allowDamage FALSE;
_caller addRating 1e6;
private _policyVictim = _callerGroup createUnit ['B_Soldier_F',[14502,17500,0],[],0,'CAN_COLLIDE'];
_policyVictim setVariable ['QS_inzone',[FALSE,0,FALSE]];
_policyVictim setVariable ['QS_unit_side',WEST];
private _enemyGroup = createGroup [EAST,TRUE];
private _physicalEnemy = _enemyGroup createUnit ['O_Soldier_F',[14510,17500,0],[],0,'CAN_COLLIDE'];
_physicalEnemy disableAI 'ALL';
_physicalEnemy setVariable ['bis_fnc_moduleRemoteControl_owner',_caller];
['damage.policy.physicalEnemyBeatsWestInstigator',(['ATTACKER',_physicalEnemy,_caller,_policyVictim] call TGC_fnc_isFriendlyFire) isEqualTo _physicalEnemy] call IA_fnc_assert;
['damage.policy.enemyDamageNotFriendly',([_policyVictim,'',0.5,_physicalEnemy,'Sh_155mm_AMOS',-1,_caller,'',FALSE] call QS_fnc_clientDamageModifier) isEqualTo 0.925] call IA_fnc_assert;
['damage.policy.nullSourceFriendlyInstigator',([_policyVictim,'',0.5,objNull,'Sh_155mm_AMOS',-1,_caller,'',FALSE] call QS_fnc_clientDamageModifier) isEqualTo 0] call IA_fnc_assert;
['damage.policy.selfCollisionDoesNotInventAttacker',isNull (['ATTACKER',_policyVictim,objNull,_policyVictim] call TGC_fnc_isFriendlyFire)] call IA_fnc_assert;
['damage.policy.unattributedImpactRetainsReduction',([_policyVictim,'',0.5,objNull,'',-1,objNull,'',FALSE] call QS_fnc_clientDamageModifier) isEqualTo 0.025] call IA_fnc_assert;
['damage.policy.unattributedOrdnanceNotFriendly',([_policyVictim,'',0.5,objNull,'Sh_155mm_AMOS',-1,objNull,'',FALSE] call QS_fnc_clientDamageModifier) isEqualTo 0.925] call IA_fnc_assert;
{deleteVehicle _x;} forEach [_policyVictim,_physicalEnemy];
deleteGroup _enemyGroup;
['damage_policy_scope',['Direct source/helper cases use controlled input payloads and AI objects. The WEST instigator is not a real Zeus player; native remote-control accountability is still separate.']] call IA_fnc_log;
private _rejectedRelease = [];
isNil {
    private _profile = (_profiles select {(_x # 0) isEqualTo 'IR'}) # 0;
    private _ammo = [_profile] call _fn_resolveAmmo;
    private _aim = [14500,17510,0];
    private _deadTarget = createVehicle ['B_Quadbike_01_F',_aim,[],0,'CAN_COLLIDE'];
    _deadTarget setDamage 1;
    private _designation = [_aim,_deadTarget];
    private _job = ['',scriptNull,0,_caller,0,_profile # 3,1];
    private _released = FALSE;
    private _shot = call _fn_productionRelease;
    _rejectedRelease = [_released,_job # 6,_shot,alive _deadTarget];
    deleteVehicle _deadTarget;
};
private _rejectedDeleteUntil = diag_tickTime + 1;
waitUntil {uiSleep 0.01; isNull (_rejectedRelease # 2) || {diag_tickTime >= _rejectedDeleteUntil}};
['damage.release.rejectedTargetRetainsRound',!(_rejectedRelease # 0) && {(_rejectedRelease # 1) isEqualTo 1} && {isNull (_rejectedRelease # 2)},
    [_rejectedRelease # 3,_rejectedRelease # 0,_rejectedRelease # 1,isNull (_rejectedRelease # 2)]] call IA_fnc_assert;
if (!isNull (_rejectedRelease # 2)) then {deleteVehicle (_rejectedRelease # 2);};
private _missingRelease = [];
isNil {
    private _profile = (_profiles select {(_x # 0) isEqualTo 'IR'}) # 0;
    private _ammo = [_profile] call _fn_resolveAmmo;
    private _aim = [14500,17510,0];
    // A designation can disappear between lookup and atomic release. Execute
    // the exact production release with that now-null object, not a new aim.
    private _designation = [_aim,objNull];
    private _job = ['',scriptNull,0,_caller,0,_profile # 3,1];
    private _released = FALSE;
    private _shot = call _fn_productionRelease;
    _missingRelease = [_released,_job # 6,_shot];
};
private _missingDeleteUntil = diag_tickTime + 1;
waitUntil {uiSleep 0.01; isNull (_missingRelease # 2) || {diag_tickTime >= _missingDeleteUntil}};
['damage.release.missingDesignationRetainsRound',!(_missingRelease # 0) &&
    {(_missingRelease # 1) isEqualTo 1} && {isNull (_missingRelease # 2)},
    [_missingRelease # 0,_missingRelease # 1,isNull (_missingRelease # 2)]] call IA_fnc_assert;
if (!isNull (_missingRelease # 2)) then {deleteVehicle (_missingRelease # 2);};
private _globalDeadline = diag_tickTime + 118;
private _executed = 0;
{
    if (diag_tickTime >= _globalDeadline) exitWith {};
    private _profile = _x;
    private _ammo = [_profile] call _fn_resolveAmmo;
    ['damage.profile.ammoAvailable',isClass (configFile >> 'CfgAmmo' >> _ammo),[_profile # 0,_ammo]] call IA_fnc_assert;
    private _groups = [];
    private _objects = [];
    private _cases = [];
    {
        private _mode = _x;
        private _case = (_profile # 0) + ':' + _mode;
        _cases pushBack _case;
        private _origin = [[14500,16000,0],[15200,16000,0]] select (_mode isEqualTo 'CALLER_SOURCE');
        private _group = createGroup [WEST,TRUE];
        _groups pushBack _group;
        {
            _x params ['_radius','_angle'];
            private _position = _origin getPos [_radius,_angle];
            private _victim = _group createUnit ['B_Soldier_F',_position,[],0,'CAN_COLLIDE'];
            _victim disableAI 'ALL';
            _victim setUnitPos 'UP';
            [_victim,_case,format ['FOOT_%1_%2',_radius,_angle]] call IA_damage_fnc_watch;
            _objects pushBack _victim;
        } forEach [[2,0],[12,90],[25,180],[45,270],[65,45]];
        {
            _x params ['_class','_radius','_angle'];
            private _car = createVehicle [_class,_origin getPos [_radius,_angle],[],0,'CAN_COLLIDE'];
            private _occupant = _group createUnit ['B_Soldier_F',_origin getPos [_radius + 3,_angle],[],0,'CAN_COLLIDE'];
            _occupant disableAI 'ALL';
            _occupant moveInDriver _car;
            [_car,_case,_class] call IA_damage_fnc_watch;
            [_occupant,_case,'CREW_' + _class] call IA_damage_fnc_watch;
            _objects append [_occupant,_car];
        } forEach [['C_Offroad_01_F',8,225],['B_Quadbike_01_F',20,45]];
        private _designationObject = objNull;
        if ((_profile # 5) isEqualTo 'LASER') then {
            _designationObject = createVehicle ['LaserTargetW',_origin,[],0,'CAN_COLLIDE'];
        };
        if ((_profile # 5) isEqualTo 'IR') then {
            _designationObject = createVehicle ['B_Quadbike_01_F',_origin,[],0,'CAN_COLLIDE'];
            private _enemyGroup = createGroup [EAST,TRUE];
            private _driver = _enemyGroup createUnit ['O_Soldier_F',_origin vectorAdd [30,0,0],[],0,'CAN_COLLIDE'];
            _driver disableAI 'ALL';
            _driver moveInDriver _designationObject;
            _designationObject setVehicleTIPars [1,1,1];
            _caller reveal [_designationObject,4];
            _objects pushBack _driver;
            _groups pushBack _enemyGroup;
            ['damage.ir.eligibleEnemyDesignation',!isNull effectiveCommander _designationObject &&
                {((side group effectiveCommander _designationObject) getFriend WEST) < 0.6} &&
                {(_caller knowsAbout _designationObject) >= 1.5},[_case]] call IA_fnc_assert;
            [_designationObject,_case,'IR_DESIGNATION'] call IA_damage_fnc_watch;
        };
        if (!isNull _designationObject) then {_objects pushBack _designationObject;};
        private _aim = +_origin;
        private _designation = [_aim,_designationObject];
        private _job = ['',scriptNull,0,_caller,0,_profile # 3,1];
        private _released = FALSE;
        private _shot = objNull;
        // Execute the exact production release statements in their original
        // unscheduled context; attach observers before the next engine frame.
        isNil {
            _shot = call _fn_productionRelease;
            if (!isNull _shot) then {
                if (_mode isEqualTo 'NULL_SOURCE') then {_shot setShotParents [objNull,_caller];};
                [_shot,_case] call IA_damage_fnc_trackShot;
            };
        };
        ['damage.case.releaseAccepted',_released && {(_job # 6) isEqualTo 0} && {!isNull _shot},[_case,_ammo,_job # 6]] call IA_fnc_assert;
        if ((_profile # 5) isNotEqualTo 'NONE') then {
            ['damage.case.guidedTargetAccepted',_released && {(missileTarget _shot) isEqualTo _designationObject},[_case,typeOf (missileTarget _shot)]] call IA_fnc_assert;
        };
        [_case,'Designation',[_profile # 5,typeOf _designationObject,_released,typeOf (missileTarget _shot)]] call IA_damage_fnc_record;
        [_case,'Released',[_profile,_ammo,getPosASL _shot,
            (getShotParents _shot) apply {[_x] call IA_damage_fnc_entity},getShotInfo _shot select [0,8]]] call IA_damage_fnc_record;
    } forEach ['NULL_SOURCE','CALLER_SOURCE'];
    private _until = (diag_tickTime + 13) min _globalDeadline;
    waitUntil {
        uiSleep 0.1;
        {if (!isNull _x) then {
            [_x getVariable ['IA_damage_case','UNKNOWN'],getPosASL _x,velocity _x,vectorDir _x] call IA_damage_fnc_sampleFlight;
        };} forEach IA_damage_shots;
        diag_tickTime >= _until
    };
    {
        private _case = _x;
        private _counts = ['HandleDamage','OrdnanceHandleDamage','Hit','Killed','AmmoExplodedNear','SubmunitionCreated','Explode'] apply {
            [_x,IA_damage_counts getOrDefault [_case + ':' + _x,0]]
        };
        ['damage_case_summary',[_case,_ammo,_counts]] call IA_fnc_log;
        private _ff = IA_damage_ff getOrDefault [_case,[0,0,[]]];
        private _flight = IA_damage_finite getOrDefault [_case,[0,0,[]]];
        ['damage.case.finiteFlight',(_flight # 0) > 1 && {(_flight # 1) isEqualTo 0},[_case,_flight]] call IA_fnc_assert;
        ['damage.case.nativeFootFriendlyProtection',(_ff # 0) > 0 && {(_ff # 1) isEqualTo 0},[_case,_ff]] call IA_fnc_assert;
        // Keep coverage failures distinct from modifier-policy failures.
        ['damage.case.damageCaptured',(IA_damage_counts getOrDefault [_case + ':OrdnanceHandleDamage',0]) > 0,[_case,_counts]] call IA_fnc_assert;
        if ((_profile # 0) in ['ICM','BOMB_CLUSTER']) then {
            ['damage.case.nativeSubmunitionsCaptured',(IA_damage_counts getOrDefault [_case + ':SubmunitionCreated',0]) > 0,[_case,_counts]] call IA_fnc_assert;
        };
    } forEach _cases;
    {if (!isNull _x) then {deleteVehicle _x;};} forEach IA_damage_shots;
    IA_damage_shots = [];
    {if (!isNull _x) then {if (_x isKindOf 'CAManBase' && {!isNull objectParent _x}) then {(objectParent _x) deleteVehicleCrew _x;} else {deleteVehicle _x;};};} forEach _objects;
    {deleteGroup _x;} forEach _groups;
    _executed = _executed + 1;
} forEach _profiles;
['damage.allProfilesExecuted',_executed isEqualTo count _profiles,[_executed,count _profiles]] call IA_fnc_assert;
deleteVehicle _caller;
deleteGroup _callerGroup;
{['damage_count',[_x,_y]] call IA_fnc_log;} forEach IA_damage_counts;
[] call IA_fnc_finish;
