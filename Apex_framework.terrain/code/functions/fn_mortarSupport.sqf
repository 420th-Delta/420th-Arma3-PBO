// Added Code
/*
File: fn_mortarSupport.sqf
Description:
    Mortar Gunner equipment through the native communication and placement menus.
    Separate ten-minute request cooldowns belong to the player's UID for this
    server session. The server core owns equipment/drop cleanup; no role loops.
*/
private _mode = _this param [0,'',['']];
if (isRemoteExecutedJIP) exitWith {};
if (isServer && {_mode isEqualTo 'REQUEST'} && {missionNamespace getVariable ['QS_mortarSupport_diagnostics',FALSE]}) then {
    diag_log ['[Mortar Support] context',canSuspend,isRemoteExecuted,remoteExecutedOwner];
};

// MORTAR_POLICY_BEGIN
private _fn_admission = {
    params ['_now','_readyAt','_hasAsset','_eligible','_penalty'];
    if (!_eligible) exitWith {'ROLE'};
    if (_penalty > 1) exitWith {'ROBOCOP'};
    if (_now < _readyAt) exitWith {'COOLDOWN'};
    if (_hasAsset) exitWith {'EXISTS'};
    ''
};
private _fn_retireNeeded = {
    params ['_connected','_alive','_sameRole','_sameBody','_distance'];
    (!_connected) || {!_alive} || {!_sameRole} || {!_sameBody} || {_distance > 500}
};
private _fn_sectionAdmission = {
    params ['_count','_pending'];
    if (_count >= 3) exitWith {'FULL'};
    if (_pending) exitWith {'PENDING'};
    ''
};
// MORTAR_POLICY_END

private _fn_hasTube = {
    params ['_unit'];
    (toLowerANSI (backpack _unit)) in (['mortar_tubes_1'] call QS_data_listItems)
};

private _fn_clientEligible = {
    !isNull player && {alive player} && {(lifeState player) isNotEqualTo 'INCAPACITATED'} &&
    {(player getVariable ['QS_unit_role','']) isEqualTo 'mortar_gunner'} &&
    {(player getVariable ['QS_unit_side',WEST]) isEqualTo WEST} &&
    {!isRemoteControlling player} && {isNull curatorCamera}
};

if (_mode isEqualTo 'CLIENT') exitWith {
    if (!hasInterface || {isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}}) exitWith {};
    private _eligible = call _fn_clientEligible;
    private _owner = localNamespace getVariable ['QS_mortarSupport_menuOwner',[objNull,[]]];
    _owner params ['_unit','_menus'];
    if (_menus isNotEqualTo [] && {(!_eligible) || {player isNotEqualTo _unit}}) then {
        {if (!isNull _unit && {_x >= 0}) then {[_unit,_x] call BIS_fnc_removeCommMenuItem;};} forEach _menus;
        _menus = [];
        private _object = uiNamespace getVariable ['QS_targetBoundingBox_requestedObject',objNull];
        if (!isNull _object && {(_object getVariable ['QS_mortarSupport_owner',objNull]) isEqualTo _unit}) then {
            missionNamespace setVariable ['QS_targetBoundingBox_placementModeCancel',TRUE,FALSE];
        };
    };
    if (!isNull _unit && {!isNull player} && {player isNotEqualTo _unit || {!alive _unit} ||
        {(_unit getVariable ['QS_unit_role','']) isNotEqualTo 'mortar_gunner'}}) then {
        // Retain the body while unconscious; latch a later departure even if
        // incapacitation already removed its menus. Cooldowns stay on server.
        ['RELEASE',player,_unit] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
        _unit = objNull;
    };
    if (_eligible && {_menus isEqualTo []}) then {
        _unit = player;
        _menus = ['QS_RequestMk6Mortar','QS_RequestMortarResupply','QS_ResetMortarSection'] apply {
            [_unit,_x,[],[],''] call BIS_fnc_addCommMenuItem
        };
    };
    localNamespace setVariable ['QS_mortarSupport_menuOwner',[_unit,_menus]];
};
if (_mode isEqualTo 'REQUEST_RESET') exitWith {
    if (isRemoteExecuted || {!hasInterface} || {!(call _fn_clientEligible)}) exitWith {};
    // Recovery remains available while Robocop blocks new equipment. It does
    // not read or write either request cooldown or create another timer.
    ['RESET',player] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
};
if (_mode in ['REQUEST_MORTAR','REQUEST_SUPPLY','REQUEST_TUBE']) exitWith {
    if (isRemoteExecuted || {!hasInterface} || {!(call _fn_clientEligible)}) exitWith {};
    if ((player getVariable ['QS_tto',0]) > 1) exitWith {systemChat 'Too much reported friendly fire';};
    private _kind = ['MORTAR','SUPPLY','TUBE'] # (['REQUEST_MORTAR','REQUEST_SUPPLY','REQUEST_TUBE'] find _mode);
    if (_kind isNotEqualTo 'SUPPLY' && {
        !isNull (objectParent player) || {missionNamespace getVariable ['QS_targetBoundingBox_placementMode',FALSE]}
    }) exitWith {systemChat 'Stand on foot and finish placing your current object first.';};
    if (_kind isEqualTo 'TUBE' && {!([player] call _fn_hasTube)}) exitWith {};
    private _target = _this param [1,[],[[]]];
    private _rateKey = 'QS_mortarSupport_requestAfter_' + _kind;
    if (diag_tickTime < (localNamespace getVariable [_rateKey,0])) exitWith {};
    localNamespace setVariable [_rateKey,diag_tickTime + 2];
    ['REQUEST',player,_kind,_target] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
};

// Client/object-local operations only accept the server. These cannot be used
// by a requester to create objects, grant stock, or eject another player.
if (_mode in ['PLACE','CANCEL','EJECT','ARM','DEBIT']) exitWith {
    if (!isRemoteExecuted || {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
    if (_mode isEqualTo 'DEBIT') exitWith {
        params ['',['_unit',objNull,[objNull]],['_tube',objNull,[objNull]]];
        // Check and remove at the inventory's locality in one unscheduled call.
        // A backpack swapped while this RPC was in flight is never consumed.
        if (!isNull _unit && {local _unit} && {!isNull _tube} &&
            {(backpackContainer _unit) isEqualTo _tube}) then {removeBackpack _unit;};
    };
    if (_mode isEqualTo 'ARM') exitWith {
        params ['',['_mortar',objNull,[objNull]],['_nonce',-1,[0]]];
        if (!isNull _mortar && {_mortar turretLocal [0]} &&
            {(_mortar getVariable ['QS_mortarSupport_nonce',-1]) isEqualTo _nonce} &&
            {!(_mortar getVariable ['QS_mortarSupport_retiring',FALSE])}) then {
            _mortar addMagazineTurret ['8Rnd_82mm_Mo_shells',[0],8];
            _mortar allowDamage TRUE;
            _mortar lock FALSE;
        };
    };
    if (_mode isEqualTo 'EJECT') exitWith {
        params ['','_unit','_mortar'];
        if (!isNull _unit && {local _unit} && {(objectParent _unit) isEqualTo _mortar}) then {
            if ((lifeState _unit) isEqualTo 'INCAPACITATED') then {
                // Existing revive-aware extraction preserves incapacitation.
                [70,_unit] call QS_fnc_remoteExec;
            } else {unassignVehicle _unit; moveOut _unit;};
        };
    };
    if (!hasInterface) exitWith {};
    if (_mode isEqualTo 'CANCEL') exitWith {
        private _object = _this param [1,objNull,[objNull]];
        if (!isNull _object && {(uiNamespace getVariable ['QS_targetBoundingBox_requestedObject',objNull]) isEqualTo _object}) then {
            missionNamespace setVariable ['QS_targetBoundingBox_placementModeCancel',TRUE,FALSE];
        };
    };
    _this spawn {
        params ['','_unit','_mortar','_nonce'];
        private _until = diag_tickTime + 8;
        waitUntil {uiSleep 0.1; isNull _mortar ||
            {local _mortar && {(_mortar getVariable ['QS_mortarSupport_nonce',-1]) isEqualTo _nonce}} ||
            {diag_tickTime >= _until}};
        if (missionNamespace getVariable ['QS_mortarSupport_diagnostics',FALSE]) then {
            diag_log ['[Mortar Support] PLACE readiness',_nonce,isNull _mortar,local _mortar,
                clientOwner,_mortar turretLocal [0],_mortar getVariable ['QS_mortarSupport_nonce',-1],
                _unit isEqualTo player,alive player,lifeState player,
                player getVariable ['QS_unit_role',''],isRemoteControlling player,isNull curatorCamera,
                isNull objectParent player,missionNamespace getVariable ['QS_targetBoundingBox_placementMode',FALSE],
                player distance2D _mortar,_mortar getVariable ['QS_mortarSupport_retiring',FALSE]];
        };
        private _placed = FALSE;
        if (_unit isEqualTo player && {!isNull _mortar} && {local _mortar} &&
            {alive player} && {(lifeState player) isNotEqualTo 'INCAPACITATED'} &&
            {(player getVariable ['QS_unit_role','']) isEqualTo 'mortar_gunner'} &&
            {!isRemoteControlling player} && {isNull curatorCamera} && {isNull (objectParent player)} &&
            {!(missionNamespace getVariable ['QS_targetBoundingBox_placementMode',FALSE])} &&
            {(player distance2D _mortar) <= 10} &&
            {!(_mortar getVariable ['QS_mortarSupport_retiring',FALSE])} &&
            {(_mortar getVariable ['QS_mortarSupport_nonce',-1]) isEqualTo _nonce}
        ) then {
            [player,_mortar,FALSE,TRUE] call QS_fnc_unloadCargoPlacementMode;
            _placed = (attachedTo _mortar) isEqualTo player;
        };
        if (missionNamespace getVariable ['QS_mortarSupport_diagnostics',FALSE]) then {
            diag_log ['[Mortar Support] PLACE result',_nonce,_placed,local _mortar,_mortar turretLocal [0],
                isNull _mortar,(attachedTo _mortar) isEqualTo player];
        };
        ['ACK',_unit,_mortar,_nonce,_placed] remoteExecCall ['QS_fnc_mortarSupport',2,FALSE];
    };
};
if (!isServer) exitWith {};
if (isRemoteExecuted && {!(_mode in ['REQUEST','ACK','RELEASE','RESET'])}) exitWith {};
// isNil can clear the engine's remote-execution context. Capture provenance from
// this actual entry, never from request arguments, before entering the atomic
// server transition. Recursive API calls would otherwise reject remoteExec.
private _remoteCall = isRemoteExecuted;
private _remoteOwner = remoteExecutedOwner;
private _serverArgs = +_this;
private _fn_serverDispatch = {
private _state = serverNamespace getVariable ['QS_mortarSupport_state',createHashMap];
if (_mode isEqualTo 'TICK' && {count _state isEqualTo 0}) exitWith {};
if (count _state isEqualTo 0) then {
    _state = createHashMapFromArray [['rows',createHashMap],['nonce',0]];
    serverNamespace setVariable ['QS_mortarSupport_state',_state];
};
private _rows = _state get 'rows';
private _controlledOwners = allUnits apply {_x getVariable ['bis_fnc_moduleRemoteControl_owner',objNull]};
private _fn_private = {
    params ['_unit','_message'];
    if (!isNull _unit && {isPlayer _unit}) then {
        ['systemChat',_message] remoteExec ['QS_fnc_remoteExecCmd',_unit,FALSE];
    };
};
private _fn_full = {
    params ['_unit'];
    ['System',['','Mortars fully deployed!']] remoteExec ['QS_fnc_showNotification',_unit,FALSE];
    [_unit,'Three mortar section fully deployed.'] call _fn_private;
};
private _fn_roleHolder = {
    params ['_unit',['_conscious',TRUE]];
    if (isNull _unit || {!isPlayer _unit} || {!alive _unit} ||
        {(side group _unit) isNotEqualTo WEST} ||
        {(_unit getVariable ['QS_unit_role','']) isNotEqualTo 'mortar_gunner'} ||
        {_conscious && {((lifeState _unit) isEqualTo 'INCAPACITATED') ||
            {_unit getVariable ['QS_client_remoteControlling',FALSE]} || {_unit in _controlledOwners} ||
            {local _unit && {isRemoteControlling _unit}}}}
    ) exitWith {FALSE};
    private _roles = (missionNamespace getVariable ['QS_unit_roles',[[],[],[],[]]]) # 1;
    private _index = _roles findIf {((_x # 0) # 0) isEqualTo 'mortar_gunner'};
    if (_index < 0) exitWith {FALSE};
    (((_roles # _index) # 1) findIf {(_x # 0) isEqualTo getPlayerUID _unit}) >= 0
};
if (_mode isEqualTo 'REQUEST' && {missionNamespace getVariable ['QS_mortarSupport_diagnostics',FALSE]}) then {
    private _unit = _this param [1,objNull,[objNull]];
    diag_log ['[Mortar Support] admission',_remoteCall,_remoteOwner,canSuspend,
        owner _unit,isPlayer _unit,alive _unit,str side group _unit,[_unit] call _fn_roleHolder,
        getPlayerUID _unit isNotEqualTo '',backpack _unit,[_unit] call _fn_hasTube,
        stance _unit,str lifeState _unit,isNull objectParent _unit];
};
private _fn_penalty = {
    params ['_unit'];
    (missionNamespace getVariable ['QS_robocop',createHashMap]) getOrDefault [getPlayerUID _unit,0]
};
private _fn_eject = {
    params ['_unit','_mortar'];
    ['EJECT',_unit,_mortar] remoteExecCall ['QS_fnc_mortarSupport',_unit,FALSE];
};
private _fn_retire = {
    params ['_object'];
    if (isNull _object) exitWith {TRUE};
    if !(_object getVariable ['QS_mortarSupport_retiring',FALSE]) then {
        _object setVariable ['QS_mortarSupport_retiring',TRUE,TRUE];
    };
    // Never delete a crew member. Recheck occupied mortars on the next core
    // pass after native/local extraction has completed.
    if ((crew _object) isNotEqualTo []) exitWith {
        {[_x,_object] call _fn_eject;} forEach crew _object;
        FALSE
    };
    ['CANCEL',_object] remoteExecCall ['QS_fnc_mortarSupport',owner _object,FALSE];
    [0,_object] call QS_fnc_eventAttach;
    if (!isNull (isVehicleCargo _object)) then {objNull setVehicleCargo _object;};
    deleteVehicle _object;
    TRUE
};
private _fn_configureMortar = {
    params ['_mortar','_unit'];
    _mortar enableWeaponDisassembly FALSE;
    _mortar setVariable ['QS_mortarSupport_owner',_unit,TRUE];
    _mortar setVariable ['QS_mortarSupport_retiring',FALSE,TRUE];
    _mortar setVariable ['QS_services_reammo_disabled',TRUE,TRUE];
    _mortar setVariable ['QS_RD_draggable',TRUE,TRUE];
    _mortar setVariable ['QS_cleanup_protected',TRUE,TRUE];
    // Native UI already checks QS_trait_gunner. GetIn is a global-argument
    // event; the server also verifies actual occupied role slots on each tick.
    _mortar addEventHandler ['GetIn',{
        params ['_mortar','','_unit'];
        if ((_unit getVariable ['QS_unit_role','']) isNotEqualTo 'mortar_gunner' ||
            {!isPlayer _unit} || {_mortar getVariable ['QS_mortarSupport_retiring',FALSE]}) then {
            ['EJECT',_unit,_mortar] remoteExecCall ['QS_fnc_mortarSupport',_unit,FALSE];
        };
    }];
    _unit setVariable ['QS_mortar_lite',_mortar,TRUE];
};

private _fn_clearSection = {
    params ['_row'];
    private _kept = [];
    {
        private _entry = _x;
        // Invalidate the placement reply before extraction/deletion. A late
        // ACK cannot revive an asset from a reset or a departed role.
        _entry set [2,FALSE];
        if (!([_entry # 0] call _fn_retire)) then {_kept pushBack _entry;};
    } forEach (_row get 'mortars');
    _row set ['mortars',_kept];
    if ([_row get 'crate'] call _fn_retire) then {_row set ['crate',objNull];};
    private _chute = _row get 'chute';
    if (!isNull _chute) then {deleteVehicle _chute;};
    _row set ['chute',objNull];
    _row set ['dropState',''];
    if (_kept isEqualTo []) then {(_row get 'unit') setVariable ['QS_mortar_lite',objNull,TRUE];};
};
private _fn_settlePlacement = {
    params ['_entry','_unit','_row'];
    _entry params ['_mortar','','_pending','','_kind','_tube','_debit','_ack'];
    if (!_pending || {!_ack}) exitWith {};
    if (_kind isEqualTo 'TUBE' && {!_debit}) then {
        // The reserved physical backpack must still be worn. A dropped or
        // substituted bag cannot pay for this request and is never removed.
        if (!isNull _tube && {(backpackContainer _unit) isEqualTo _tube} && {[_unit] call _fn_hasTube}) then {
            _entry set [6,TRUE];
            ['DEBIT',_unit,_tube] remoteExecCall ['QS_fnc_mortarSupport',_unit,FALSE];
        } else {
            _entry set [2,FALSE];
            [_mortar] call _fn_retire;
        };
    };
    // Global inventory removal is asynchronous for remote players. An ACK,
    // a changed backpack class, or dropping the bag is not proof of payment.
	if (!(_entry # 2) || {_kind isEqualTo 'TUBE' && {!(_entry # 6) || {!isNull _tube}}}) exitWith {};
	// A free request starts its long cooldown only after the placement handoff
	// succeeds. Timeouts, cancellation and false acknowledgements grant nothing
	// and therefore leave the request available for a clean retry.
	if (_kind isEqualTo 'MORTAR') then {(_row get 'cooldowns') set [0,diag_tickTime + 600];};
	_entry set [2,FALSE];
    _mortar hideObjectGlobal FALSE;
    ['ARM',_mortar,_entry # 1] remoteExecCall ['QS_fnc_mortarSupport',_mortar turretOwner [0],FALSE];
    [_unit,'Mk6 mortar ready. Eight HE rounds.'] call _fn_private;
    if (({alive (_x # 0) && {!(_x # 2)}} count (_row get 'mortars')) >= 3) then {[_unit] call _fn_full;};
};
private _fn_sweepMortars = {
    params ['_row','_uid','_now'];
    private _unit = _row get 'unit';
    private _connected = !isNull _unit && {isPlayer _unit} && {_unit in allPlayers};
    private _holder = [_unit,FALSE] call _fn_roleHolder;
    private _sameBody = _connected && {(getPlayerUID _unit) isEqualTo _uid};
    private _kept = [];
    {
        private _entry = _x;
        _entry params ['_mortar','_nonce','_pending','_deadline'];
        if (!isNull _mortar) then {
            private _retire = [_connected,alive _unit,_holder,_sameBody,_unit distance2D _mortar] call _fn_retireNeeded;
            _retire = _retire || {!alive _mortar} || {_mortar getVariable ['QS_mortarSupport_retiring',FALSE]} ||
                {_pending && {_now >= _deadline || {!([_unit] call _fn_roleHolder)} || {([_unit] call _fn_penalty) > 1} ||
                    {(_mortar getVariable ['QS_mortarSupport_nonce',-1]) isNotEqualTo _nonce}}};
            private _done = FALSE;
            if (_retire) then {
                _entry set [2,FALSE];
                _done = [_mortar] call _fn_retire;
            } else {
                if (_pending && {!(_entry # 8)} && {(owner _mortar) > 0}) then {
                    // Newly created vehicles can have owner 0 and reject a
                    // first-frame transfer. Retry from the existing core sweep,
                    // while the reserved slot and original deadline stay valid.
                    private _newOwner = owner _unit;
                    private _transferred = (owner _mortar) isEqualTo _newOwner || {_mortar setOwner _newOwner};
                    if (missionNamespace getVariable ['QS_mortarSupport_diagnostics',FALSE]) then {
                        diag_log ['[Mortar Support] transfer',_nonce,_newOwner,_transferred,owner _mortar,_mortar turretOwner [0]];
                    };
                    if (_transferred) then {
                        _entry set [8,TRUE];
                        // Transfer and client placement each have one bounded
                        // window. Core scheduling must not consume the client's
                        // eight-second locality wait plus the later debit tick.
                        _entry set [3,_now + 15];
                        ['PLACE',_unit,_mortar,_nonce] remoteExecCall ['QS_fnc_mortarSupport',_unit,FALSE];
                    };
                };
                [_entry,_unit,_row] call _fn_settlePlacement;
                {if (!([_x] call _fn_roleHolder) || {([_x] call _fn_penalty) > 1}) then {[_x,_mortar] call _fn_eject;};} forEach crew _mortar;
            };
            if (!_done) then {_kept pushBack _entry;};
        };
    } forEach (_row get 'mortars');
    _row set ['mortars',_kept];
    if (_kept isEqualTo [] && {!isNull (_unit getVariable ['QS_mortar_lite',objNull])}) then {
        _unit setVariable ['QS_mortar_lite',objNull,TRUE];
    };
};

if (_mode isEqualTo 'TICK') exitWith {
    // One pass in the existing three-second server core, including Kavala and
    // side missions. No per-gunner worker, module, Game Logic or map handler.
    isNil {
        private _now = diag_tickTime;
        {
            private _uid = _x;
            private _row = _rows get _uid;
            private _unit = _row get 'unit';
            private _crate = _row get 'crate';
            private _chute = _row get 'chute';
            private _connected = !isNull _unit && {isPlayer _unit} && {_unit in allPlayers};
            private _holder = [_unit,FALSE] call _fn_roleHolder;
            private _sameBody = _connected && {(getPlayerUID _unit) isEqualTo _uid};
            [_row,_uid,_now] call _fn_sweepMortars;
            if (!isNull _crate) then {
                private _retire = [_connected,alive _unit,_holder,_sameBody,_unit distance2D _crate] call _fn_retireNeeded;
                private _inbound = (_row get 'dropState') isEqualTo 'INBOUND';
                _retire = _retire || {!alive _crate} || {_crate getVariable ['QS_mortarSupport_retiring',FALSE]} ||
                    {_inbound && {isNull _chute || {!alive _chute} ||
                        {(attachedTo _crate) isNotEqualTo _chute} || {_now >= (_row get 'dropDeadline')}}};
                if (_retire) then {
                    if ([_crate] call _fn_retire) then {_row set ['crate',objNull]; _row set ['dropState',''];};
                    if (!isNull _chute) then {deleteVehicle _chute; _row set ['chute',objNull];};
                } else {
                    if (_inbound) then {
                        if (isTouchingGround _crate || {((getPosATL _crate) # 2) <= 2}) then {
                            [0,_crate] call QS_fnc_eventAttach;
                            _crate setVelocity [0,0,0];
                            _crate allowDamage TRUE;
                            _crate lockInventory FALSE;
                            _row set ['dropState','LANDED']; _row set ['chuteDeleteAt',_now + 5];
                            [_unit,'Mortar resupply delivered. Five HE mortar tubes.'] call _fn_private;
                        } else {
                            // Small horizontal corrections keep the cargo aimed at
                            // its selected landing point; normal parachute descent.
                            private _at = getPosATL _chute;
                            private _target = _row get 'dropTarget';
                            private _velocity = velocity _chute;
                            _chute setVelocity [(((_target # 0) - (_at # 0)) * 0.4) max -4 min 4,
                                (((_target # 1) - (_at # 1)) * 0.4) max -4 min 4,(_velocity # 2) min -3];
                        };
                    } else {
                        // Empty boxes can retire; never mistake a box containing
                        // deposited player equipment for an empty resupply.
                        if (getBackpackCargo _crate isEqualTo [[],[]] &&
                            {getWeaponCargo _crate isEqualTo [[],[]]} &&
                            {getMagazineCargo _crate isEqualTo [[],[]]} &&
                            {getItemCargo _crate isEqualTo [[],[]]}) then {
                            if ([_crate] call _fn_retire) then {_row set ['crate',objNull];};
                        };
                    };
                };
            };
            _chute = _row get 'chute';
            if (!isNull _chute && {isNull (_row get 'crate') ||
                {(_row get 'dropState') isNotEqualTo 'INBOUND' && {_now >= (_row get 'chuteDeleteAt')}}}) then {
                deleteVehicle _chute; _row set ['chute',objNull];
            };
            if ((_row get 'mortars') isEqualTo [] && {isNull (_row get 'crate')} &&
                {isNull (_row get 'chute')} && {((_row get 'cooldowns') findIf {_now < _x}) < 0} &&
                {_now >= (_row getOrDefault ['attemptAfter',0])}) then {
                _rows deleteAt _uid;
            };
        } forEach (keys _rows);
    };
};
if (!_remoteCall || {!(_mode in ['REQUEST','ACK','RELEASE','RESET'])}) exitWith {};
private _caller = _this param [1,objNull,[objNull]];
if (isNull _caller || {!isPlayer _caller} || {(owner _caller) isNotEqualTo _remoteOwner}) exitWith {};
private _uid = getPlayerUID _caller;
if (_uid isEqualTo '') exitWith {};
private _row = _rows getOrDefault [_uid,createHashMap];
if (_mode isEqualTo 'RESET') exitWith {
    if (count _this isNotEqualTo 2 || {!([_caller,FALSE] call _fn_roleHolder)}) exitWith {};
    if (count _row > 0) then {[_row] call _fn_clearSection;};
    [_caller,'Mortar section reset.'] call _fn_private;
};
if (_mode isEqualTo 'RELEASE') exitWith {
    if (count _this isNotEqualTo 3 || {count _row isEqualTo 0} ||
        {(_row get 'unit') isNotEqualTo (_this # 2)}) exitWith {};
    [_row] call _fn_clearSection;
};
if (_mode isEqualTo 'ACK') exitWith {
    if (count _this isNotEqualTo 5 || {count _row isEqualTo 0}) exitWith {};
    params ['','','_mortar','_nonce','_placed'];
    if (!(_mortar isEqualType objNull) || {!(_nonce isEqualType 0)} || {!(_placed isEqualType TRUE)} ||
        {isNull _mortar} || {!finite _nonce} ||
        {(_row get 'unit') isNotEqualTo _caller}) exitWith {};
    private _index = (_row get 'mortars') findIf {(_x # 0) isEqualTo _mortar && {(_x # 1) isEqualTo _nonce}};
    if (_index < 0) exitWith {};
    private _entry = (_row get 'mortars') # _index;
    if (!(_entry # 2) || {!(_entry # 8)} || {_entry # 7}) exitWith {};
    if (_placed && {[_caller] call _fn_roleHolder} && {([_caller] call _fn_penalty) <= 1} &&
        {diag_tickTime < (_entry # 3)} &&
        {!(_mortar getVariable ['QS_mortarSupport_retiring',FALSE])}) then {
        _entry set [7,TRUE];
        [_entry,_caller,_row] call _fn_settlePlacement;
    } else {
        _entry set [2,FALSE];
        [_mortar] call _fn_retire;
        [_caller,'Mortar delivery cancelled.'] call _fn_private;
    };
};
if (!([_caller] call _fn_roleHolder) || {([_caller] call _fn_penalty) > 1}) exitWith {
    if (([_caller] call _fn_penalty) > 1) then {[_caller,'Too much reported friendly fire'] call _fn_private;};
};
if (count _this isNotEqualTo 4) exitWith {};
private _kind = _this param [2,'',['']];
if !(_kind in ['MORTAR','SUPPLY','TUBE']) exitWith {};
if (count _row isEqualTo 0) then {
    _row = createHashMapFromArray [['unit',_caller],['mortars',[]],['crate',objNull],['chute',objNull],
        ['cooldowns',[0,0]],
        ['attemptAfter',0],['dropState',''],['dropTarget',[0,0,0]],['dropDeadline',0],['chuteDeleteAt',0]];
    _rows set [_uid,_row];
};
// A new body must wait for its old equipment to retire; its cooldowns persist.
[_row,_uid,diag_tickTime] call _fn_sweepMortars;
if ((_row get 'unit') isNotEqualTo _caller) then {
    if ((_row get 'mortars') isEqualTo [] && {isNull (_row get 'crate')} && {isNull (_row get 'chute')}) then {
        _row set ['unit',_caller];
    };
};
if ((_row get 'unit') isNotEqualTo _caller) exitWith {
    [_caller,'Previous mortar equipment is being cleared.'] call _fn_private;
};
private _section = '';
if (_kind in ['MORTAR','TUBE']) then {
    private _mortars = _row get 'mortars';
    _section = [count _mortars,(_mortars findIf {_x # 2}) >= 0] call _fn_sectionAdmission;
};
if (_section isEqualTo 'FULL') exitWith {[_caller] call _fn_full;};
if (_section isEqualTo 'PENDING') exitWith {[_caller,'Finish placing your current mortar first.'] call _fn_private;};
if (_kind isEqualTo 'TUBE' && {!([_caller] call _fn_hasTube)}) exitWith {};
private _pool = ['MORTAR','SUPPLY'] find _kind;
// Backpack construction uses owned inventory, not either support cooldown.
private _readyAt = if (_pool < 0) then {0} else {(_row get 'cooldowns') # _pool};
private _hasAsset = _kind isEqualTo 'SUPPLY' && {!isNull (_row get 'crate') || {!isNull (_row get 'chute')}};
private _decision = [diag_tickTime,_readyAt,_hasAsset,TRUE,[_caller] call _fn_penalty] call _fn_admission;
if (_decision isNotEqualTo '') exitWith {
    private _message = 'Your requested equipment is still deployed.';
    if (_decision isEqualTo 'COOLDOWN') then {_message = format ['%1 available in %2 seconds.',['Mk6 mortar','Mortar resupply'] # _pool,ceil (_readyAt - diag_tickTime)];};
    if (_decision isEqualTo 'ROBOCOP') then {_message = 'Too much reported friendly fire';};
    [_caller,_message] call _fn_private;
};
([_caller,'SAFE'] call QS_fnc_inZone) params ['_inSafezone','_level','_safezoneActive'];
if (_inSafezone && {_safezoneActive} && {_level > 1}) exitWith {[_caller,localize 'STR_QS_Text_067'] call _fn_private;};
private _fn_takeAttempt = {
    private _requestNow = diag_tickTime;
    if (_requestNow < (_row getOrDefault ['attemptAfter',0])) exitWith {FALSE};
    _row set ['attemptAfter',_requestNow + 2];
    TRUE
};
if (_kind in ['MORTAR','TUBE']) exitWith {
    if (!isNull (objectParent _caller) || {surfaceIsWater getPosATL _caller} ||
        {!(stance _caller in ['STAND','CROUCH'])}) exitWith {[_caller,'Stand on dry ground to request your mortar.'] call _fn_private;};
    // Support equipment uses the vanilla Mk6; no optional vehicle substitution.
    private _class = 'B_Mortar_01_F';
    if (!isClass (configFile >> 'CfgVehicles' >> _class) || {!(_class isKindOf 'StaticMortar')} ||
        {!isClass (configFile >> 'CfgMagazines' >> '8Rnd_82mm_Mo_shells')}) exitWith {[_caller,'Mk6 mortar support is unavailable.'] call _fn_private;};
    if (!(call _fn_takeAttempt)) exitWith {};
    private _mortar = createVehicle [_class,_caller modelToWorld [0,2,1],[],0,'CAN_COLLIDE'];
    if (isNull _mortar) exitWith {[_caller,'Mortar request failed. Try again.'] call _fn_private;};
    _mortar hideObjectGlobal TRUE;
    _mortar lock TRUE;
    _mortar allowDamage FALSE;
    { _mortar removeMagazineTurret [_x # 0,_x # 1]; } forEach (magazinesAllTurrets [_mortar,TRUE]);
    // Native carry placement can unhide the object before ACK. Keep it empty
    // until the server confirms debit, then arm it at the object's locality.
    _mortar setVariable ['QS_mortar_lite',TRUE,TRUE];
    [_mortar,_caller] call _fn_configureMortar;
    private _nonce = (_state get 'nonce') + 1;
    _state set ['nonce',_nonce];
    _mortar setVariable ['QS_mortarSupport_nonce',_nonce,TRUE];
    // Reserve a slot before transferring locality. Both request paths share
    // this HE-only creation path and cannot race past the three-mortar limit.
    (_row get 'mortars') pushBack [_mortar,_nonce,TRUE,diag_tickTime + 15,_kind,
        [objNull,backpackContainer _caller] select (_kind isEqualTo 'TUBE'),FALSE,FALSE,FALSE];
	// The next core sweep transfers the now-registered object and sends PLACE.
};
private _target = _this param [3,[],[[]]];
if (!(count _target in [2,3]) || {(_target findIf {!(_x isEqualType 0) || {!finite _x}}) >= 0}) exitWith {};
_target = [_target # 0,_target # 1,0];
if ((_target # 0) < 0 || {(_target # 1) < 0} || {(_target # 0) > worldSize} || {(_target # 1) > worldSize} ||
    {(_caller distance2D _target) > 500} || {surfaceIsWater _target}) exitWith {[_caller,'Choose dry ground within 500 m for mortar resupply.'] call _fn_private;};
private _crateClass = 'B_supplyCrate_F';
if ((['B_supplyCrate_F','B_Parachute_02_F','B_Mortar_01_weapon_F'] findIf {!isClass (configFile >> 'CfgVehicles' >> _x)}) >= 0) exitWith {[_caller,'Mortar resupply is unavailable.'] call _fn_private;};
private _landing = _target findEmptyPosition [0,15,_crateClass];
if (_landing isEqualTo [] || {surfaceIsWater _landing} || {(_caller distance2D _landing) > 500} ||
    {((surfaceNormal _landing) # 2) < 0.9} ||
    {(allPlayers findIf {alive _x && {(_x distance2D _landing) < 10}}) >= 0} ||
    {lineIntersects [ATLToASL (_landing vectorAdd [0,0,180]),ATLToASL (_landing vectorAdd [0,0,2])]} ) exitWith {
    [_caller,'Choose a clear landing area at least 10 m from players.'] call _fn_private;
};
([_landing,'SAFE'] call QS_fnc_inZone) params ['_inSafezone','_level','_safezoneActive'];
if (_inSafezone && {_safezoneActive} && {_level > 1}) exitWith {[_caller,'Mortar resupply is unavailable in this safe zone.'] call _fn_private;};
if (!(call _fn_takeAttempt)) exitWith {};
private _chute = createVehicle ['B_Parachute_02_F',_landing vectorAdd [0,0,180],[],0,'FLY'];
if (isNull _chute) exitWith {[_caller,'Resupply request failed. Try again.'] call _fn_private;};
private _crate = createVehicle [_crateClass,_landing vectorAdd [0,0,178],[],0,'CAN_COLLIDE'];
if (isNull _crate) exitWith {deleteVehicle _chute; [_caller,'Resupply request failed. Try again.'] call _fn_private;};
_crate allowDamage FALSE;
_crate lockInventory TRUE;
clearWeaponCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearItemCargoGlobal _crate; clearBackpackCargoGlobal _crate;
_crate setAmmoCargo 0;
_crate addBackpackCargoGlobal ['B_Mortar_01_weapon_F',5];
_crate setVariable ['QS_mortarSupport_owner',_caller,TRUE];
_crate setVariable ['QS_cleanup_protected',TRUE,TRUE];
_crate setVariable ['QS_logistics',TRUE,TRUE];
_crate setVariable ['QS_RD_draggable',TRUE,TRUE];
_chute setVariable ['QS_cleanup_protected',TRUE,TRUE];
[1,_crate,[_chute,[0,0,-1.5]]] call QS_fnc_eventAttach;
_row set ['crate',_crate]; _row set ['chute',_chute]; _row set ['dropTarget',_landing];
_row set ['dropState','INBOUND']; _row set ['dropDeadline',diag_tickTime + 120];
(_row get 'cooldowns') set [1,diag_tickTime + 600];
[_caller,'Mortar resupply inbound. Five HE mortar tubes.'] call _fn_private;
};
isNil {_serverArgs call _fn_serverDispatch;};
// End Updated Code
