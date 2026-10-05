params ['_kind','_heli','_load','_lz','_entry','_goal',['_activity',''],['_epoch',-1],['_returnSuccess',true],['_methodRequest','',['']]];
if (!isServer || {!canSuspend}) exitWith {false};
private _claimed = false;
private _ticket = -1;
isNil {
    if (isNull _heli || {!(_heli getVariable ['QS_Taru_running',false])}) then {
        _ticket = 1 + (missionNamespace getVariable ['QS_Taru_serial',0]);
        missionNamespace setVariable ['QS_Taru_serial',_ticket];
        if (!isNull _heli) then {_heli setVariable ['QS_Taru_running',true]; _heli setVariable ['QS_Taru_ticket',_ticket];};
        _claimed = true;
    };
};
if (!_claimed) exitWith {false};
private _empty = _kind isEqualTo 'RETURN';
private _troops = _kind isEqualTo 'TROOPS';
private _cargo = if (_troops) then {_load} else {grpNull};
private _payload = if (_troops) then {objNull} else {_load};
private _members = if (_troops) then {+units _cargo} else {+crew _payload};
private _pilot = driver _heli;
private _pilots = group _pilot;
private _originalCrew = (crew _heli) - _members;
private _groups = if (_troops) then {[_cargo]} else {[]};
{_groups pushBackUnique group _x;} forEach _members;
_groups = _groups select {!isNull _x};
private _hc = _groups apply {[_x,_x getVariable ['QS_AI_GRP_HC_EXCLUDED',false]]};
private _ropes = ropes _heli;
private _air = [];
private _ownedObjects = _heli getVariable ['QS_Taru_ownedObjects',[]];
private _handles = [];
private _handed = false;
private _taken = false;
private _failed = false;
private _delivered = false;
private _loadLost = false;
private _payloadReleased = false;
private _lastReleaseAt = -1;
private _paraHoldPosition = [];
private _paraOrderAt = -1;
private _paraNextAt = -1;
private _paraRadius = 10;
private _paraOrigin = [];
private _paraInterval = -1;
private _releasedUnits = [];
private _departureStarted = false;
private _departureFrom = [];
private _retired = false;
private _outBy = -1;
private _orderAt = -1;
private _fn_exempt = {
    !isNull _this && {isPlayer _this || {captive _this} || {!local _this} ||
        {!isNull (remoteControlled _this)} || {!isNull (_this getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}}
};
private _fn_transportOwned = {
    (isNull _heli || {local _heli && {(_heli getVariable ['QS_Taru_ticket',-1]) isEqualTo _ticket}}) &&
    {isNull _pilots || {local _pilots}} &&
    {((_originalCrew + crew _heli) findIf {isPlayer _x || {alive _x && {_x call _fn_exempt}}}) < 0}
};
private _fn_payloadOwned = {
    (_members findIf {alive _x && {_x call _fn_exempt}}) < 0 &&
    {(_groups findIf {!isNull _x && {(units _x findIf {alive _x}) >= 0} && {!local _x}}) < 0} &&
    {_troops || {isNull _payload || {local _payload && {!(_payload call _fn_exempt)}}}}
};
private _fn_owned = {
    call _fn_transportOwned && {_handed || {_payloadReleased} || {call _fn_payloadOwned}} &&
    {_troops || {_empty} || {(isNull getSlingLoad _heli || {(getSlingLoad _heli) isEqualTo _payload}) &&
        {((ropeAttachedObjects _heli) findIf {_x isNotEqualTo _payload}) < 0}}}
};
private _fn_current = {
    if (_activity isEqualTo '') exitWith {true};
    if (_activity isEqualTo 'PRIMARY') exitWith {
        missionNamespace getVariable ['QS_primaryPressure_running',false] &&
        {!(missionNamespace getVariable ['QS_defendActive',false])} &&
        {(missionNamespace getVariable ['QS_primaryPressure_epoch',-1]) isEqualTo _epoch}
    };
    missionNamespace getVariable ['QS_defendControl_active',false] &&
    {missionNamespace getVariable ['QS_defendActive',false]} &&
    {(missionNamespace getVariable ['QS_defendControl_epoch',-1]) isEqualTo _epoch}
};
private _fn_healthy = {alive _heli && {canMove _heli} && {alive _pilot} && {(driver _heli) isEqualTo _pilot}};
private _fn_payloadAttached = {
    !isNull _payload && {(getSlingLoad _heli) isEqualTo _payload || {_payload in (ropeAttachedObjects _heli)} || {(attachedTo _payload) isEqualTo _heli}}
};
private _fn_pending = {if (isNull _heli) exitWith {[]}; _members select {alive _x && {(objectParent _x) isEqualTo _heli}}};
private _fn_stage = {
    params ['_stage'];
    if (!isNull _heli) then {_heli setVariable ['QS_Taru_stage',_stage,true];};
};
private _fn_holdPara = {
    params [['_start',false,[true]]];
    if ((_paraHoldPosition isEqualTo [] && {!_start}) || {_loadLost} || {_departureStarted} ||
        {!(call _fn_owned)} || {!(call _fn_healthy)} || {!(call _fn_current)} || {diag_tickTime < _paraOrderAt}) exitWith {};
    isNil {
        if (!(call _fn_owned) || {!(call _fn_healthy)} || {!(call _fn_current)}) exitWith {};
        if (_paraHoldPosition isEqualTo []) then {
            _paraHoldPosition = getPosATL _heli;
            _paraHoldPosition set [2,200];
            for '_wpIndex' from ((count waypoints _pilots) - 1) to 0 step -1 do {deleteWaypoint [_pilots,_wpIndex];};
        };
        _paraOrderAt = diag_tickTime + 1;
        _heli land 'NONE';
        _heli flyInHeight [200,true];
        _heli limitSpeed 35;

        if (_heli distance2D _paraHoldPosition > 25) then {
            _pilots move _paraHoldPosition;
            _pilot doMove _paraHoldPosition;
        } else {doStop _pilot;};
    };
};
private _fn_paraSize = {
    private _box = boundingBoxReal _this;
    private _low = _box # 0;
    private _high = _box # 1;
    10 max (vectorMagnitude [
        (abs (_low # 0)) max (abs (_high # 0)),
        (abs (_low # 1)) max (abs (_high # 1)),
        (abs (_low # 2)) max (abs (_high # 2))
    ])
};
private _fn_paraPoint = {
    private _box = boundingBoxReal _heli;
    private _low = _box # 0;
    private _high = _box # 1;
    private _bottom = getPosWorld _heli # 2;
    {
        private _xCorner = _x;
        {
            private _yCorner = _x;
            {
                _bottom = _bottom min ((_heli modelToWorldWorld [_xCorner,_yCorner,_x]) # 2);
            } forEach [_low # 2,_high # 2];
        } forEach [_low # 1,_high # 1];
    } forEach [_low # 0,_high # 0];
    private _point = _heli modelToWorldWorld [0,-5,0];

    _point set [2,_bottom - (25 max (_paraRadius + 8))];
    _point
};
private _fn_paraClear = {
    params ['_point',['_otherCanopies',[]]];
    if ((ASLToATL _point # 2) < 60 || {surfaceIsWater ASLToATL _point} ||
        {(allPlayers inAreaArray [ASLToATL _point,50,50,0,false]) isNotEqualTo []}) exitWith {false};
    (((_air apply {_x # 1}) + _otherCanopies) findIf {
        private _previous = _x;
        !isNull _previous && {((getPosWorld _previous) vectorDistance _point) < (_paraRadius + (_previous call _fn_paraSize) + 4)}
    }) < 0
};
private _fn_paraSlot = {
    params [['_exclude',objNull]];
    private _otherCanopies = (allMissionObjects 'ParachuteBase') - [_exclude];
    private _base = call _fn_paraPoint;
    if (_paraOrigin isEqualTo []) then {_paraOrigin = +_base;};
    _base set [0,_paraOrigin # 0];
    _base set [1,_paraOrigin # 1];
    private _spacing = (_paraRadius * 2) + 8;
    private _point = [];

    {
        private _candidate = _base vectorAdd [(_x # 0) * _spacing,(_x # 1) * _spacing,0];
        if ([_candidate,_otherCanopies] call _fn_paraClear) exitWith {_point = _candidate;};
    } forEach [
        [0,0],[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1],
        [2,0],[-2,0],[0,2],[0,-2],[2,1],[-2,-1],[2,-1],[-2,1],
        [1,2],[-1,-2],[-1,2],[1,-2],[2,2],[-2,-2],[2,-2],[-2,2]
    ];
    _point
};
private _fn_loss = {

    if (!_handed && {_troops} && {(_members findIf {alive _x}) < 0}) then {_loadLost = true;};
    if (!_handed && {!_empty} && {!_troops} && {isNull _payload || {!alive _payload} || {isNull _heli || {!alive _heli}}}) then {
        if (isNull _payload || {!alive _payload}) then {_loadLost = true;};
        if (call _fn_owned) then {
            if (!isNull _heli && {!isNull _payload} && {(getSlingLoad _heli) isEqualTo _payload}) then {_heli setSlingLoad objNull;};
            {if (!isNull _x) then {ropeDestroy _x;};} forEach _ropes;
            _ropes = [];
            if (!isNull _heli) then {_heli setVariable ['QS_Taru_load',objNull];};
        };
    };
};
private _fn_moveOut = {
    params ['_unit'];

    isNil {
        if (call _fn_owned && {alive _unit} && {(objectParent _unit) isEqualTo _heli}) then {
            private _lock = locked _heli;
            _heli lock 0;
            moveOut _unit;
            _heli lock _lock;
        };
    };
};
private _fn_releaseGround = {
    if (!(call _fn_owned) || {isNull _heli}) exitWith {};
    if ((isTouchingGround _heli || {(getPosATL _heli # 2) < 2.5}) && {vectorMagnitude velocity _heli < 3}) then {
        {
            [_x] allowGetIn false;
            unassignVehicle _x;
            [_x] call _fn_moveOut;
        } forEach (call _fn_pending);
    };
};
private _fn_handoff = {
    params [['_success',false]];
    isNil {
        if (_handed) exitWith {};
        private _cargoOrdersAllowed = _success && {call _fn_owned} && {call _fn_payloadOwned} && {call _fn_current};
        if (_success && {!_cargoOrdersAllowed}) then {_success = false; _delivered = false; if (!(call _fn_transportOwned)) then {_taken = true;};};
        _handed = true;
        if (!isNull _heli) then {_heli setVariable ['QS_Taru_load',nil];};
        {
            _x params ['_group','_previousHC'];
            if (!isNull _group) then {
                _group setVariable ['QS_taruDelivery_busy',false,true];

                _group setVariable ['QS_AI_GRP_HC_EXCLUDED',[_previousHC,false] select (_activity isEqualTo 'DEFENSE' || {!_success && {_troops}}),true];
            };
        } forEach _hc;
        if (_cargoOrdersAllowed && {_troops} && {_activity isEqualTo 'DEFENSE'} && {local _cargo}) then {
            _cargo setSpeedMode 'FULL';
            _cargo setBehaviour 'AWARE';
            {
                if (alive _x && {local _x} && {!(_x call _fn_exempt)}) then {
                    _x enableAI 'PATH';
                    _x enableAI 'TARGET';
                    _x enableAI 'AUTOTARGET';
                    _x setUnitPos 'UP';
                    _x doFollow leader _cargo;
                };
            } forEach _members;
            _cargo move _goal;
        };
        if (_success) then {
            if (!isNull _heli) then {_heli setVariable ['QS_taruDelivery_landed',true];};
            if (_troops && {!isNull _cargo}) then {_cargo setVariable ['QS_taruDelivery_landed',true];};
        };
    };
};
private _fn_beginDeparture = {
    if (_departureStarted || {!(call _fn_owned)} || {!(call _fn_healthy)} ||
        {!_troops && {!_empty} && {alive _payload} && {call _fn_payloadAttached}}) exitWith {};
    _departureStarted = true;
    _departureFrom = getPosATL _heli;
    private _now = diag_tickTime;
    _outBy = _now + 180;
    _orderAt = _now + 15;
    _heli setVariable ['QS_Taru_departAt',_now,true];
    ['DEPART'] call _fn_stage;
    _heli land 'NONE';
    _heli limitSpeed 160;
    _heli flyInHeight [150,true];
    for '_wpIndex' from ((count waypoints _pilots) - 1) to 0 step -1 do {deleteWaypoint [_pilots,_wpIndex];};
    _pilots move _entry;
    _pilot doMove _entry;
};
private _fn_departureTick = {
    if (_departureStarted && {call _fn_owned} && {call _fn_healthy} && {diag_tickTime >= _orderAt}) then {
        _orderAt = diag_tickTime + 15;
        _pilots move _entry;
        _pilot doMove _entry;
    };
};
private _fn_lossEgressReady = {

    !(_loadLost && {!_troops} && {call _fn_healthy}) ||
    {_departureStarted && {(_heli distance2D _departureFrom) >= 500} && {(_heli distance2D _lz) > 1400}}
};
if (!(call _fn_owned) || {!(call _fn_healthy)}) exitWith {
    call _fn_loss;
    private _unavailable = if (call _fn_owned) then {'TRANSPORT_UNAVAILABLE'} else {'CONTROL_HANDOFF'};
    if (call _fn_owned && {!isNull _heli} && {(call _fn_pending) isEqualTo []} && {isNull getSlingLoad _heli} && {!isNil 'QS_garbageCollector'} &&
        {crew _heli findIf {!(_x in _originalCrew)} < 0}) then {
        {if (!isNull _x) then {QS_garbageCollector pushBackUnique [_x,'DELAYED_DISCREET',time + 180];};} forEach (_originalCrew + [_heli]);
    };
    [false] call _fn_handoff;
    if (!isNull _heli && {(_heli getVariable ['QS_Taru_ticket',-1]) isEqualTo _ticket}) then {
        _heli setVariable ['QS_Taru_running',false];
        _heli setVariable ['QS_Taru_result',_unavailable,true];
        _heli setVariable ['QS_Taru_stage',_unavailable,true];
    };
    false
};
_heli setVariable ['QS_Taru_running',true];
_heli setVariable ['QS_Taru_load',_payload];
_heli setVariable ['QS_Taru_handles',_handles];
_heli setVariable ['QS_Taru_air',_air];
_heli setVariable ['QS_Taru_ownedObjects',_ownedObjects];
_heli setVariable ['QS_Taru_result','RUNNING',true];
_heli setVariable ['QS_Taru_lastReleaseAt',-1,true];
_heli setVariable ['QS_Taru_releasedCount',0,true];
_heli setVariable ['QS_Taru_departAt',-1,true];
{_x setVariable ['QS_AI_GRP_HC_EXCLUDED',true,true]; _x setVariable ['QS_taruDelivery_busy',true,true];} forEach _groups;
_pilots setVariable ['QS_AI_GRP_HC_EXCLUDED',true,true];
_pilots setBehaviour 'CARELESS';
_pilots setCombatMode 'BLUE';
_pilots setSpeedMode 'FULL';
_pilots allowFleeing 0;
_pilot disableAI 'AUTOCOMBAT';
_pilot disableAI 'TARGET';
_pilot disableAI 'AUTOTARGET';
_heli allowCrewInImmobile [true,true];
_heli setUnloadInCombat [false,false];

private _method = ['SLING','PARA'] select _troops;
_heli setVariable ['QS_Taru_method',_method,true];
private _aim = +_lz;
private _fn_releaseSling = {
    params ['_point'];
    private _released = false;
    isNil {
        if (_troops || {_empty} || {!(call _fn_owned)} || {!(call _fn_current)} || {!(call _fn_healthy)} ||
            {isNull _payload} || {!alive _payload} || {!(call _fn_payloadAttached)}) exitWith {};
        private _height = getPosATL _payload # 2;
        if (_payload distance2D _point > 70 || {vectorMagnitude velocity _heli >= 3} ||
            {vectorMagnitude velocity _payload >= 3} || {surfaceIsWater getPosATL _payload} ||
            {!(isTouchingGround _payload || {_height >= -0.5 && {_height <= 1.5}})}) exitWith {};
        _heli setSlingLoad objNull;
        _released = !(call _fn_payloadAttached);
    };
    _released
};
private _aborted = false;
for '_attempt' from 0 to 1 do {
    if (_empty) exitWith {};
    call _fn_loss;
    if (!(call _fn_owned)) exitWith {_taken = true;};
    if (!(call _fn_healthy)) exitWith {_failed = true;};
    if (!(call _fn_current)) exitWith {_aborted = true;};
    if (_troops && {(call _fn_pending) isEqualTo []}) exitWith {};
    if (!_handed && {!_empty} && {!_troops} && {isNull _payload || {!alive _payload} || {!(call _fn_payloadAttached)}}) exitWith {};
    if (_attempt > 0) then {
        if (_troops) then {_method = 'PARA';} else {
            private _next = [_lz,25,100,17,0,0.5,0] call QS_fnc_findSafePos;
            if (_next isEqualType [] && {count _next >= 2} && {!surfaceIsWater _next} && {_next distance2D _lz <= 100}) then {_aim = +_next; _aim set [2,0];};
        };
    };
    private _height = [200,40] select (_method isEqualTo 'SLING');
    if (_method isEqualTo 'PARA' && {!isNil 'QS_fnc_aoPressure'}) then {
        private _drop = _lz vectorAdd [0,0,_height];
        private _windAim = ['DROP_SPAWN',_drop,_height,_cargo] call QS_fnc_aoPressure;
        if (_windAim isEqualType [] && {count _windAim >= 2} && {!surfaceIsWater _windAim} &&
            {(_windAim # 0) > 50} && {(_windAim # 1) > 50} && {(_windAim # 0) < worldSize - 50} && {(_windAim # 1) < worldSize - 50} &&
            {(allPlayers inAreaArray [_windAim,50,50,0,false]) isEqualTo []}) then {_aim = +_windAim; _aim set [2,0];};
    };
    _heli land 'NONE';
    _heli engineOn true;
    _heli flyInHeight [_height,true];
    _heli limitSpeed 160;
    _pilot enableAI 'PATH';
    if (_paraHoldPosition isEqualTo []) then {_pilots move _aim; _pilot doMove _aim;} else {[false] call _fn_holdPara;};
    ['APPROACH_' + _method] call _fn_stage;
    private _by = diag_tickTime + 110;
    private _nextOrder = diag_tickTime + 8;
    private _unhook = false;
    while {diag_tickTime < _by} do {
        uiSleep (if (_method isEqualTo 'PARA' && {_paraHoldPosition isNotEqualTo []}) then {0.05} else {0.25});
        call _fn_loss;
        if (!(call _fn_owned)) exitWith {_taken = true;};
        if (!(call _fn_healthy)) exitWith {_failed = true;};
        if (!(call _fn_current)) exitWith {_aborted = true;};
        if (_troops && {(call _fn_pending) isEqualTo []}) exitWith {};
        if (!_handed && {!_empty} && {!_troops} && {isNull _payload || {!alive _payload} || {!(call _fn_payloadAttached)}}) exitWith {};
        private _distance = _heli distance2D _aim;
        private _speed = vectorMagnitude velocity _heli;
        private _altitude = getPosATL _heli # 2;
        if (diag_tickTime >= _nextOrder) then {
            _nextOrder = diag_tickTime + 8;
            if (!_unhook && {_paraHoldPosition isEqualTo []}) then {_pilots move _aim; _pilot doMove _aim;};
        };
        if (_method isEqualTo 'PARA') then {[false] call _fn_holdPara;};
        if (_distance < 180) then {_heli limitSpeed 35;};
        private _clear = !surfaceIsWater (getPosATL _heli) && {(allPlayers inAreaArray [_heli,50,50,0,false]) isEqualTo []};
        if (_method isEqualTo 'PARA' && {_distance <= 100} && {_altitude >= 120} && {_altitude <= 350} && {_speed <= 18} && {_clear}) then {
            [true] call _fn_holdPara;
            ['RELEASE_PARA'] call _fn_stage;
            private _remaining = call _fn_pending;
            if (_paraInterval < 0 && {_remaining isNotEqualTo []}) then {
                private _count = count _remaining;
                _paraInterval = 0.1 max ((3 max (4 min (_count * 0.5))) / (1 max (_count - 1)));
            };
            if (_remaining isNotEqualTo [] && {_speed <= 8} && {diag_tickTime >= _paraNextAt}) then {
                private _dropASL = [] call _fn_paraSlot;
                private _unit = _remaining # 0;
                private _chute = objNull;

                isNil {

                    _paraNextAt = diag_tickTime + _paraInterval;
                    if (_dropASL isEqualTo [] || {!(call _fn_owned)} || {!(call _fn_healthy)} || {!(call _fn_current)} ||
                        {!alive _unit} || {(objectParent _unit) isNotEqualTo _heli}) exitWith {};
                    _chute = createVehicle ['Steerable_Parachute_F',ASLToATL _dropASL,[],0,'FLY'];
                    if (isNull _chute) exitWith {};
                    _chute hideObjectGlobal true;
                    _chute enableSimulationGlobal false;
                    _chute setVariable ['QS_Taru_requestId',_heli getVariable ['QS_Taru_requestId',''],false];
                    _ownedObjects pushBack _chute;
                    _paraRadius = _paraRadius max (_chute call _fn_paraSize);
                    _dropASL = [_chute] call _fn_paraSlot;
                    if (!alive _chute || {_dropASL isEqualTo []}) exitWith {deleteVehicle _chute;};
                    _chute setDir getDir _heli;
                    _chute setVectorUp [0,0,1];
                    _chute setPosWorld _dropASL;
                    [_unit] allowGetIn false;
                    unassignVehicle _unit;
                    [_unit] call _fn_moveOut;
                    if (alive _unit && {isNull objectParent _unit} && {local _unit} && {!(_unit call _fn_exempt)}) then {
                        _unit setPosASL _dropASL;
                        _unit setVelocity [0,0,0];
                        _chute enableSimulationGlobal true;
                        _unit moveInDriver _chute;
                        if (isNull objectParent _unit) then {_unit moveInDriver _chute;};
                    };

                    _chute enableSimulationGlobal true;
                    _chute hideObjectGlobal false;
                    if (alive _unit && {isNull objectParent _unit} && {call _fn_owned} && {call _fn_healthy}) then {_unit moveInCargo _heli;};
                };
                if (!isNull _chute) then {
                    private _seatBy = diag_tickTime + 2;
                    waitUntil {
                        uiSleep 0.05;
                        [false] call _fn_holdPara;
                        isNil {
                            if (alive _unit && {local _unit} && {!(_unit call _fn_exempt)} && {isNull objectParent _unit} &&
                                {local _chute} && {alive _chute} && {crew _chute isEqualTo []} &&
                                {isNull _heli || {(getPosWorld _chute # 2) <= ((call _fn_paraPoint) # 2)}}) then {
                                _unit moveInDriver _chute;
                            };
                        };
                        !isNull objectParent _unit || {!alive _unit} || {_unit call _fn_exempt} || {isNull _chute} || {diag_tickTime >= _seatBy}
                    };
                    if (!isNull _chute && {alive _chute} && {alive _unit} && {(objectParent _unit) isEqualTo _chute}) then {
                        _releasedUnits pushBackUnique _unit;
                        _heli setVariable ['QS_Taru_releasedCount',count _releasedUnits,true];
                        _lastReleaseAt = diag_tickTime;
                        _heli setVariable ['QS_Taru_lastReleaseAt',_lastReleaseAt,true];
                        if (local _chute && {!(_unit call _fn_exempt)}) then {_chute setVelocity [0,0,-5];};
                        _air pushBack [_unit,_chute];
                        if (!isNil 'QS_fnc_aoPressure') then {
                            private _drop = ASLToATL _dropASL;
                            ['DROP_TRACK',_unit,_lz vectorAdd [0,0,_drop # 2],_drop] call QS_fnc_aoPressure;
                        };
                    } else {
                        if (alive _unit && {isNull objectParent _unit} && {call _fn_owned} && {call _fn_healthy}) then {_unit moveInCargo _heli;};
                        if ((objectParent _unit) isEqualTo _heli && {crew _chute isEqualTo []}) then {deleteVehicle _chute;} else {_air pushBack [_unit,_chute];};
                    };
                };
            };
        };
        if (_method isEqualTo 'SLING' && {_distance <= 150} && {!_unhook}) then {
            ['RELEASE_SLING'] call _fn_stage;
            private _wp = _pilots addWaypoint [_aim,0];
            _wp setWaypointType 'UNHOOK';
            _wp setWaypointSpeed 'LIMITED';
            _pilots setCurrentWaypoint _wp;
            _unhook = true;

            _by = diag_tickTime + 90;
        };
        if (_method isEqualTo 'SLING') then {[_aim] call _fn_releaseSling;};
    };
    if (_taken || {_failed} || {_aborted}) exitWith {};
};
call _fn_loss;
if (!(call _fn_owned)) then {_taken = true;};
if (!(call _fn_healthy)) then {_failed = true;};

if (_failed && {!_taken} && {_troops}) then {call _fn_releaseGround;};
private _fn_grounded = {
    if (_empty) exitWith {true};
    if (_troops) exitWith {
        (_members findIf {alive _x}) >= 0 && {(call _fn_pending) isEqualTo []} &&
        {(_members findIf {alive _x && {(getPosATL _x # 2) > 3 || {(objectParent _x) isKindOf 'Air'}}}) < 0}
    };
    !isNull _payload && {alive _payload} && {!(call _fn_payloadAttached)} &&
    {isTouchingGround _payload || {(getPosATL _payload # 2) < 3}}
};
private _fn_landed = {
    if (!(call _fn_grounded)) exitWith {false};
    if (_empty) exitWith {_returnSuccess};
    if (_troops) exitWith {(_members findIf {alive _x && {surfaceIsWater getPosATL _x || {_x distance2D _lz > 650}}}) < 0};
    !surfaceIsWater getPosATL _payload && {_payload distance2D _lz <= 400}
};
private _fn_cleanCanopies = {
    {
        _x params ['_unit','_chute'];
        if (alive _unit && {local _unit} && {!(_unit call _fn_exempt)} && {(objectParent _unit) isEqualTo _chute} &&
            {isTouchingGround _chute || {(getPosATL _unit # 2) < 1.8}}) then {unassignVehicle _unit; moveOut _unit;};
        if (!isNull _chute && {crew _chute isEqualTo []}) then {deleteVehicle _chute;};
    } forEach _air;
};
if (_troops && {(call _fn_pending) isEqualTo []}) then {
    _payloadReleased = true;
    if (!_taken && {!_failed}) then {

        private _departBy = if (_lastReleaseAt >= 0) then {_lastReleaseAt + 5} else {diag_tickTime};
        if (_lastReleaseAt >= 0 && {!_loadLost} && {diag_tickTime < _departBy}) then {['HOLD_PARA'] call _fn_stage;};
        waitUntil {
            uiSleep 0.05;
            call _fn_loss;
            [false] call _fn_holdPara;
            _loadLost || {!(call _fn_owned)} || {!(call _fn_healthy)} || {!(call _fn_current)} || {diag_tickTime >= _departBy}
        };
        call _fn_beginDeparture;
    };
};
call _fn_cleanCanopies;
private _settleBy = diag_tickTime + 150;
if (!_taken && {!_loadLost} && {(_troops && {(call _fn_pending) isEqualTo []}) || {!_troops && {!(call _fn_payloadAttached)}}}) then {
    if (!_departureStarted) then {['SETTLING'] call _fn_stage;};
    while {diag_tickTime < _settleBy && {!_loadLost} && {!(call _fn_grounded)}} do {
        uiSleep 0.5;
        call _fn_loss;
        if (!(call _fn_owned)) exitWith {_taken = true;};
        call _fn_departureTick;
        call _fn_cleanCanopies;
    };
};
call _fn_cleanCanopies;
_delivered = !_taken && {call _fn_owned} && {call _fn_current} && {call _fn_landed};
if (!_taken && {call _fn_owned} && {call _fn_current} && {call _fn_grounded}) then {[true] call _fn_handoff;};
if (!_troops && {!_empty} && {!_loadLost} && {!_taken} && {!_failed} && {!_aborted} &&
    {call _fn_current} && {call _fn_owned} && {call _fn_healthy} && {call _fn_payloadAttached}) then {
    private _fallback = [_lz,0,150,17,0,0.4,0] call QS_fnc_findSafePos;
    if (_fallback isEqualType [] && {count _fallback >= 2} && {!surfaceIsWater _fallback} &&
        {_fallback distance2D _lz <= 150} && {(allPlayers inAreaArray [_fallback,50,50,0,false]) isEqualTo []}) then {
        ['FALLBACK_SLING'] call _fn_stage;
        for '_wpIndex' from ((count waypoints _pilots) - 1) to 0 step -1 do {deleteWaypoint [_pilots,_wpIndex];};
        _heli land 'NONE';
        private _wp = _pilots addWaypoint [_fallback,0];
        _wp setWaypointType 'UNHOOK';
        _wp setWaypointSpeed 'LIMITED';
        _pilots setCurrentWaypoint _wp;
        private _groundBy = diag_tickTime + 90;
        while {diag_tickTime < _groundBy && {call _fn_payloadAttached}} do {
            uiSleep 0.25;
            call _fn_loss;
            if (_loadLost || {!(call _fn_owned)} || {!(call _fn_current)} || {!(call _fn_healthy)}) exitWith {};
            [_fallback] call _fn_releaseSling;
        };
        if (call _fn_grounded && {call _fn_owned} && {call _fn_current}) then {
            _delivered = call _fn_landed;
            [true] call _fn_handoff;
        };
    };
};
if (!(call _fn_owned)) then {_taken = true;};
if (!(call _fn_healthy)) then {_failed = true;};
if (!_taken && {!_failed} && {call _fn_owned} && {call _fn_healthy} &&
    {_troops || {_empty} || {!(call _fn_payloadAttached)}}) then {
    call _fn_beginDeparture;
    waitUntil {
        uiSleep 0.5;
        call _fn_loss;
        call _fn_departureTick;
        !(call _fn_owned) || {!(call _fn_healthy)} ||
        {(_heli distance2D _lz) > 1400 && {call _fn_lossEgressReady} && {(allPlayers inAreaArray [_heli,500,500,0,false]) isEqualTo []}} || {diag_tickTime >= _outBy}
    };
    if (!(call _fn_owned)) then {_taken = true;};

    if (_troops && {!_empty} && {!_loadLost} && {!_taken} && {!_aborted} && {call _fn_current} && {call _fn_healthy} && {!(call _fn_grounded)} &&
        {(call _fn_pending) isNotEqualTo []}) then {
        private _fallback = [getPosATL _heli,0,150,17,0,0.4,0] call QS_fnc_findSafePos;
        if (_fallback isEqualType [] && {count _fallback >= 2} && {!surfaceIsWater _fallback} &&
            {_fallback distance2D _heli <= 150} && {(allPlayers inAreaArray [_fallback,50,50,0,false]) isEqualTo []}) then {
            ['FALLBACK_GROUND'] call _fn_stage;
            _pilots move _fallback; _pilot doMove _fallback;
            _heli land 'GET OUT';
            private _groundBy = diag_tickTime + 90;
            while {diag_tickTime < _groundBy && {!_loadLost} && {call _fn_owned} && {call _fn_healthy}} do {
                uiSleep 0.5;
                call _fn_loss;
                if (_loadLost || {!(call _fn_owned)} || {!(call _fn_current)} || {!(call _fn_healthy)}) exitWith {};
                call _fn_releaseGround;
                if (call _fn_grounded) exitWith {_delivered = call _fn_landed;};
            };
            if (call _fn_grounded && {call _fn_owned} && {call _fn_current}) then {[true] call _fn_handoff;};
        };
    };
    if (call _fn_owned && {call _fn_healthy} && {call _fn_lossEgressReady} && {_delivered || {_troops && {(call _fn_pending) isEqualTo []}} || {!_troops && {isNull getSlingLoad _heli} && {!(call _fn_payloadAttached)}}}) then {

        if ((allPlayers inAreaArray [_heli,500,500,0,false]) isEqualTo [] && {crew _heli findIf {!(_x in _originalCrew)} < 0}) then {
            {if (!isNull _x && {!(_x call _fn_exempt)}) then {deleteVehicle _x;};} forEach _originalCrew;
            {if (!isNull _x) then {ropeDestroy _x;};} forEach _ropes;
            _heli setVariable ['QS_Taru_result',if (_loadLost) then {'LOAD_LOST'} else {['INCOMPLETE','DELIVERED'] select _delivered},true];
            _heli setVariable ['QS_Taru_stage','RETIRED',true];
            _retired = true;
            deleteVehicle _heli;
            if (!isNull _pilots && {units _pilots isEqualTo []}) then {deleteGroup _pilots;};
        };
    };
};
if (!_taken && {!isNull _heli} && {call _fn_owned} && {call _fn_lossEgressReady} && {(call _fn_pending) isEqualTo []} && {isNull getSlingLoad _heli} && {!(call _fn_payloadAttached)}) then {
    if (!isNil 'QS_garbageCollector') then {
        {if (!isNull _x) then {QS_garbageCollector pushBackUnique [_x,'DELAYED_DISCREET',time + 180];};} forEach (_originalCrew + [_heli]);
    };
};
if (!_handed) then {[false] call _fn_handoff;};
if (!_retired && {!(call _fn_healthy)}) then {_failed = true;};
private _result = if (_taken) then {'CONTROL_HANDOFF'} else {if (_failed) then {'TRANSPORT_LOST'} else {if (_loadLost) then {'LOAD_LOST'} else {if (_delivered) then {'DELIVERED'} else {'INCOMPLETE'}}}};
if (!isNull _heli && {(_heli getVariable ['QS_Taru_ticket',-1]) isEqualTo _ticket}) then {
    _heli setVariable ['QS_Taru_running',false];
    _heli setVariable ['QS_Taru_load',nil];
    _heli setVariable ['QS_Taru_handles',[]];
    _heli setVariable ['QS_Taru_result',_result,true];
    _heli setVariable ['QS_Taru_stage',_result,true];
};
if (_result in ['INCOMPLETE','TRANSPORT_LOST','LOAD_LOST']) then {diag_log format ['[I&A Taru] %1: remaining=%2',_result,count (call _fn_pending)];};
_delivered
