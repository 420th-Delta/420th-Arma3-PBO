/* Vehicle Access VA-5.4.9: staged ejection, saved controls and owner seat locks.
   Helper names stay distinct from data locals: SQF uses dynamic scope. */
params ['_mode',['_a',objNull],['_b',[]],['_c',[]],['_d',[]]];
if (isRemoteExecutedJIP) exitWith {};
// SP remote execution reports sender 0. Do not apply MP machine IDs to Eden preview.
private _serverAuthority = (!isMultiplayer && {isServer}) || {isRemoteExecuted && {remoteExecutedOwner isEqualTo 2}} || {!isRemoteExecuted && {isServer}};
if (isMultiplayer && {isRemoteExecuted} && {remoteExecutedOwner isNotEqualTo 2} && {_mode isNotEqualTo 'SERVER'}) exitWith {};
private _deliver = {
 params ['_message','_targets'];
 if (!isMultiplayer) exitWith {_message call QS_fnc_clientVehicleAccess;};
 _message remoteExecCall ['QS_fnc_clientVehicleAccess',_targets,false];
};
private _groups = ['driver','gunner','commander','passenger'];
private _seatGroup = {
 params ['_vehicle','_seat'];
 _seat params ['','_role','','_path','_ffv'];
 if (_path isNotEqualTo [] && {_path isNotEqualTo [-1]} && {getNumber (([_vehicle,_path] call BIS_fnc_turretConfig) >> 'isCopilot') isEqualTo 1}) exitWith {'driver'};
 if (_role isEqualTo 'driver') exitWith {'driver'};
 if (_role isEqualTo 'commander') exitWith {'commander'};
 if (_role isEqualTo 'cargo' || {_ffv}) exitWith {'passenger'};
 'gunner'
};
private _supportedUGV = {
 params ['_vehicle'];
 // Exact classes deliberately exclude IDAP/demining, UGV-02, aircraft and mod derivatives.
 (toLower typeOf _vehicle) in [
  'b_ugv_01_f','b_ugv_01_rcws_f','o_ugv_01_f','o_ugv_01_rcws_f','i_ugv_01_f','i_ugv_01_rcws_f',
  'b_t_ugv_01_olive_f','b_t_ugv_01_rcws_olive_f','o_t_ugv_01_ghex_f','o_t_ugv_01_rcws_ghex_f',
  'i_e_ugv_01_f','i_e_ugv_01_rcws_f'
 ]
};
private _terminalControl = {
 params ['_vehicle','_actor'];
 private _control = UAVControl _vehicle;
 ((_control param [0,objNull]) isEqualTo _actor && {toUpper (_control param [1,'']) in ['DRIVER','GUNNER']}) ||
 {(_control param [2,objNull]) isEqualTo _actor && {toUpper (_control param [3,'']) in ['DRIVER','GUNNER']}}
};
private _inputVehicle = {
 private _uav = getConnectedUAV player;
 if (!isNull _uav && {[_uav,player] call _terminalControl}) exitWith {
  if ([_uav] call _supportedUGV) then {_uav} else {objNull}
 };
 private _vehicle = objectParent player;
 if (!isNull _vehicle && {unitIsUAV _vehicle} && {!([_vehicle] call _supportedUGV)}) exitWith {objNull};
 _vehicle
};
private _access = {
 params ['_vehicle'];
 private _state = _vehicle getVariable ['QS_VA_access',[
  0,_vehicle getVariable ['QS_vehicleAccess_ownerUID',''],
  ['driver','gunner','commander','passenger'] apply {_vehicle getVariable [format ['QS_vehicleAccess_%1Locked',_x],false]}
 ]];
 // A native ownership transfer invalidates cached access and the former owner's locks.
 private _uid = _vehicle getVariable ['QS_spawnMenu_spawnedBy',_vehicle getVariable ['QS_vehicleAccess_ownerUID',_state # 1]];
 if (_uid isNotEqualTo (_state # 1)) exitWith {[(_state # 0) + 1,_uid,[false,false,false,false]]};
 _state
};
// Drone connection ownership already belongs to the mission's TGC drone system.
// An explicit empty/ALL native owner must not fall back to an obsolete vehicle-access owner.
private _ejectOwnerUID = {
 params ['_vehicle'];
 if (unitIsUAV _vehicle && {!isNil {_vehicle getVariable 'TGC_drones_owner'}}) exitWith {
  _vehicle getVariable ['TGC_drones_owner','']
 };
 ([_vehicle] call _access) # 1
};
private _driverValid = {
 params ['_vehicle','_actor'];
 !isNull _vehicle && {alive _vehicle} && {!isNull _actor} && {isPlayer _actor} &&
 {(lifeState _actor) in ['HEALTHY','INJURED']} && {objectParent _actor isEqualTo _vehicle} &&
 {_actor isEqualTo driver _vehicle} && {currentPilot _vehicle in [objNull,_actor]}
};
private _lockAllowed = {
 params ['_vehicle','_actor'];
 !unitIsUAV _vehicle && {[_vehicle,_actor] call _driverValid} &&
 {getPlayerUID _actor isNotEqualTo ''} && {(([_vehicle] call _access) # 1) in ['',getPlayerUID _actor]}
};
private _pilotValid = {
 params ['_vehicle','_pilot'];
 if (isNull _vehicle || {!alive _vehicle} || {isNull _pilot} || {!isPlayer _pilot} || {!((lifeState _pilot) in ['HEALTHY','INJURED'])}) exitWith {false};
 private _uid = getPlayerUID _pilot;
 if (_uid isEqualTo '' || {([_vehicle] call _ejectOwnerUID) isNotEqualTo _uid}) exitWith {false};
 if (unitIsUAV _vehicle) exitWith {([_vehicle] call _supportedUGV) && {[_vehicle,_pilot] call _terminalControl}};
 [_vehicle,_pilot] call _driverValid
};
// Self-release is a physical owner-driver capability; the terminal exception is not inherited.
private _selfOwnerUID = {
 params ['_vehicle'];
 _vehicle getVariable ['QS_spawnMenu_spawnedBy',([_vehicle] call _access) # 1]
};
private _selfDriverValid = {
 params ['_vehicle','_actor'];
 !isNull _vehicle && {alive _vehicle} && {!unitIsUAV _vehicle} &&
 {!isNull _actor} && {isPlayer _actor} && {(lifeState _actor) in ['HEALTHY','INJURED']} &&
 {getPlayerUID _actor isNotEqualTo ''} && {([_vehicle] call _selfOwnerUID) isEqualTo getPlayerUID _actor} &&
 {objectParent _actor isEqualTo _vehicle} && {_actor isEqualTo driver _vehicle} &&
 {currentPilot _vehicle in [objNull,_actor]} && {isNull isVehicleCargo _vehicle}
};
private _selfCarriers = {
 params ['_cargo'];
 // ropesAttachedTo returns transports, NOT individual rope objects (Arma 3 2.10+).
 if (isNull _cargo) exitWith {[]};
 (ropesAttachedTo _cargo) arrayIntersect (ropesAttachedTo _cargo)
};
private _selfSnapshot = {
 params ['_cargo','_actor'];
 if (!([_cargo,_actor] call _selfDriverValid)) exitWith {[]};
 private _carriers = [_cargo] call _selfCarriers; private _entries = []; private _valid = _carriers isNotEqualTo [];
 {
  private _carrier = _x;
  private _links = _carrier getVariable ['QS_VA_selfRopeLinks',[]];
  private _allRopes = ropes _carrier;
  // Require provenance for the entire carrier graph. Never guess a rope target by position,
  // array order, a sole native slingload, or by calling ropeAttachedObjects on a rope.
  if (isNull _carrier || {!(_carrier isKindOf 'Helicopter')} || {unitIsUAV _carrier} ||
   {_allRopes isEqualTo []} || {count _links isNotEqualTo count _allRopes} ||
   {(_allRopes - (_links apply {_x # 0})) isNotEqualTo []} ||
   {(_links findIf {isNull (_x # 0) || {!((_x # 1) in ropeAttachedObjects _carrier)}}) >= 0} ||
   {(_links findIf {_x # 1 isEqualTo _cargo}) < 0}) then {_valid = false;};
  _entries pushBack [_carrier,_carrier getVariable ['QS_VA_selfRopeEpoch',0],+_links];
 } forEach _carriers;
 if (!_valid) exitWith {[]};
 [[_cargo] call _selfOwnerUID,_actor getVariable ['QS_VA_boardEpoch',0],_entries]
};
private _selfTicketValid = {
 params ['_ticket'];
 _ticket params ['_cargo','_carrier','_actor','','_sender','_uid','_board','_epoch','_links','_expires'];
 !isNull _carrier && {alive _carrier} && {serverTime < _expires} &&
 {[_cargo,_actor] call _selfDriverValid} && {owner _actor isEqualTo _sender} &&
 {([_cargo] call _selfOwnerUID) isEqualTo _uid} &&
 {(_actor getVariable ['QS_VA_boardEpoch',0]) isEqualTo _board} &&
 {_carrier in ([_cargo] call _selfCarriers)} &&
 {(_carrier getVariable ['QS_VA_selfRopeEpoch',0]) isEqualTo _epoch} &&
 {(_carrier getVariable ['QS_VA_selfRopeLinks',[]]) isEqualTo _links} &&
 {count (ropes _carrier) isEqualTo count _links} &&
 {((ropes _carrier) - (_links apply {_x # 0})) isEqualTo []}
};
private _groundClaimAllowed = {
 params ['_vehicle','_actor'];
 !isNull _vehicle && {alive _vehicle} && {unitIsUAV _vehicle} && {[_vehicle] call _supportedUGV} &&
 {!isNull _actor} && {isPlayer _actor} && {(lifeState _actor) in ['HEALTHY','INJURED']} &&
 {isNull objectParent _actor} && {_actor distance _vehicle <= 6} &&
 {([_vehicle] call _ejectOwnerUID) isEqualTo ''}
};
private _getOwnerGroup = {
 params ['_vehicle',['_fallback',objNull]];
 private _uid = [_vehicle] call _ejectOwnerUID;
 private _index = allPlayers findIf {getPlayerUID _x isEqualTo _uid};
 if (_uid isNotEqualTo '' && {_index >= 0}) exitWith {group (allPlayers # _index)};
 group _fallback
};
private _droneCrew = {
 params ['_unit'];
 unitIsUAV _unit || {(toLower typeOf _unit) in ['b_uav_ai','o_uav_ai','i_uav_ai','c_uav_ai']}
};
private _eligible = {
 params ['_vehicle','_seat','_stage','_ownerGroup'];
 _seat params ['_unit','_role','_cargo','','_ffv'];
 // This guard precedes BOTH stages: B_UAV_AI and other drone crew are never ejected.
 if (isNull _unit || {[_unit] call _droneCrew} || {_unit in [driver _vehicle,currentPilot _vehicle]}) exitWith {false};
 if (unitIsUAV _vehicle) exitWith {
  ([_vehicle] call _supportedUGV) && {_cargo >= 0 || {_ffv}}
 };
 if (_stage isEqualTo 2) exitWith {true};
 // Seat role, never AI group membership, separates the two stages.
 _role isEqualTo 'cargo' && {!_ffv} &&
 {([_vehicle,_seat] call _seatGroup) isEqualTo 'passenger'} &&
 {!(_unit in [gunner _vehicle,commander _vehicle])}
};
private _internalCargo = {
 params ['_vehicle'];
 if (isNull _vehicle || {unitIsUAV _vehicle}) exitWith {[]};
 (getVehicleCargo _vehicle) select {!isNull _x && {isVehicleCargo _x isEqualTo _vehicle}}
};
private _slingCargo = {
 params ['_vehicle'];
 if (isNull _vehicle || {!(_vehicle isKindOf 'Helicopter')} || {unitIsUAV _vehicle}) exitWith {[]};
 private _loads = ropeAttachedObjects _vehicle;
 private _native = getSlingLoad _vehicle;
 if (!isNull _native) then {_loads pushBackUnique _native;};
 _loads select {!isNull _x && {!(_x isKindOf 'Man')}}
};
private _hasRopes = {
 params ['_vehicle'];
 !isNull _vehicle && {_vehicle isKindOf 'Helicopter'} && {!unitIsUAV _vehicle} &&
 {ropes _vehicle isNotEqualTo [] || {([_vehicle] call _slingCargo) isNotEqualTo []}}
};
private _slingHeight = {
 params ['_vehicle',['_pilot',objNull]];
 if (isNull _pilot) then {_pilot = currentPilot _vehicle;};
 if (isNull _pilot) then {_pilot = driver _vehicle;};
 private _height = _vehicle getVariable ['QS_VA_slingHeight',65];
 if (!isNull _pilot) then {_height = (getUnitFreefallInfo _pilot) # 2;};
 if (!finite _height || {_height < 0}) then {_height = 65;};
 _vehicle setVariable ['QS_VA_slingHeight',_height];
 _height
};
private _queueDrop = {
 params ['_cargo','_vehicle'];
 if (isNull _cargo || {_cargo isKindOf 'Man'}) exitWith {};
 private _drops = missionNamespace getVariable ['QS_VA_slingDrops',[]];
 if ((_drops findIf {_x # 0 isEqualTo _cargo}) < 0) then {
  _drops pushBack [_cargo,_vehicle,serverTime + 2,serverTime + 0.1,objNull,[_vehicle] call _slingHeight,-1];
  missionNamespace setVariable ['QS_VA_slingDrops',_drops];
 };
};
private _hasTargets = {
 params ['_vehicle','_ownerGroup'];
 ((fullCrew [_vehicle,'',false]) findIf {[_vehicle,_x,2,_ownerGroup] call _eligible}) >= 0 ||
 {([_vehicle] call _internalCargo) isNotEqualTo []} || {[_vehicle] call _hasRopes}
};
private _noticeVehicle = {
 private _vehicle = call _inputVehicle;
 if (!isNull _vehicle && {!isNull isVehicleCargo _vehicle}) then {_vehicle = isVehicleCargo _vehicle;};
 _vehicle
};
private _signature = {params ['_seat']; _seat select [1,4]};
private _privileged = {
 params ['_vehicle','_unit','_state',['_ownerGroup',grpNull]];
 if (isPlayer _unit) exitWith {getPlayerUID _unit isEqualTo (_state # 1)};
 if (count _this < 4) then {_ownerGroup = [_vehicle] call _getOwnerGroup;};
 !isNull _ownerGroup && {group _unit isEqualTo _ownerGroup}
};
private _duration = {
 params ['_value',['_default',3]];
 if (!(_value isEqualType 0) || {!finite _value}) exitWith {_default};
 (round (((_value max 1) min 5) * 100)) / 100
};
private _checkpoints = {
 params ['_seconds',['_allSeconds',3]];
 private _out = [];
 for '_i' from 1 to (floor _seconds) do {_out pushBack _i;};
 _out pushBackUnique _seconds;
 for '_i' from 1 to (floor _allSeconds) do {_out pushBackUnique (_seconds + _i);};
 _out pushBackUnique (_seconds + _allSeconds);
 _out
};
private _barPosition = {
 params ['_progress','_seconds',['_allSeconds',3],['_stage',0]];
 if (_stage isEqualTo 0) exitWith {((_progress / (_seconds max 0.01)) max 0) min 1};
 (((_progress - _seconds) / (_allSeconds max 0.01)) max 0) min 1
};
private _stageTarget = {
 params ['_seconds','_allSeconds','_stage'];
 _seconds + (if (_stage > 0) then {_allSeconds} else {0})
};
private _cargoOnly = {
 params ['_vehicle','_ownerGroup'];
 (([_vehicle] call _internalCargo) isNotEqualTo [] || {[_vehicle] call _hasRopes}) &&
 {((fullCrew [_vehicle,'',false]) findIf {[_vehicle,_x,1,_ownerGroup] call _eligible}) < 0}
};
private _despawnOwner = {
 params ['_vehicle'];
 if (unitIsUAV _vehicle && {!isNil {_vehicle getVariable 'TGC_drones_owner'}}) exitWith {_vehicle getVariable ['TGC_drones_owner','']};
 private _uid = ([_vehicle] call _access) # 1;
 if (_uid isEqualTo '') then {_vehicle getVariable ['QS_spawnMenu_spawnedBy','']} else {_uid}
};
private _despawnBusy = {
 params ['_vehicle'];
 ((crew _vehicle) findIf {!([_x] call _droneCrew)}) >= 0 ||
 {(getVehicleCargo _vehicle) isNotEqualTo []} || {!isNull isVehicleCargo _vehicle} ||
 {!isNull getSlingLoad _vehicle} || {!isNull attachedTo _vehicle} ||
 {attachedObjects _vehicle isNotEqualTo []} || {ropes _vehicle isNotEqualTo []} ||
 {(allPlayers findIf {getConnectedUAV _x isEqualTo _vehicle}) >= 0} ||
 {(vehicles findIf {getSlingLoad _x isEqualTo _vehicle}) >= 0}
};
private _holdExpired = {
 params ['_hold','_clockTime'];
 // Cleanup counts only the server's advancing, healthy simulation clock.
 (_clockTime - (_hold # 17) > 30) || {_clockTime - (_hold # 18) > 120}
};
private _serverLoop = {
 if (isNil {missionNamespace getVariable 'QS_VA_disconnectEH'}) then {
  missionNamespace setVariable ['QS_VA_disconnectEH',addMissionEventHandler ['PlayerDisconnected',{
   params ['','_uid','','','_owner']; ['DISCONNECT',_uid,_owner] call QS_fnc_clientVehicleAccess;
  }]];
 };
 if ((missionNamespace getVariable ['QS_VA_serverEH',-1]) >= 0) exitWith {};
 missionNamespace setVariable ['QS_VA_serverNext',0];
 missionNamespace setVariable ['QS_VA_serverEH',addMissionEventHandler ['EachFrame',{
  ['SERVER_CLOCK'] call QS_fnc_clientVehicleAccess;
  if (diag_tickTime >= (missionNamespace getVariable ['QS_VA_serverNext',0])) then {
   missionNamespace setVariable ['QS_VA_serverNext',diag_tickTime + 0.1]; ['SERVER_TICK'] call QS_fnc_clientVehicleAccess;
  };
 }]];
};
private _publishAccess = {
 params ['_vehicle','_state'];
 _vehicle setVariable ['QS_VA_access',_state,true];
 _vehicle setVariable ['QS_vehicleAccess_ownerUID',_state # 1,true];
 {_vehicle setVariable [format ['QS_vehicleAccess_%1Locked',_x],(_state # 2) # _forEachIndex,true];} forEach _groups;
};
private _selfWatchRopes = {
 params ['_carrier'];
 if (isNull _carrier || {!(_carrier isKindOf 'Helicopter')} || {unitIsUAV _carrier} ||
  {!isNil {_carrier getVariable 'QS_VA_selfLocalRopeEH'}}) exitWith {};
 // No inference/bootstrap for pre-existing ropes. A new attach must be observed.
 // Seed only the event counter. Existing endpoint identities remain untrusted.
 _carrier setVariable ['QS_VA_selfLocalRopeEpoch',_carrier getVariable ['QS_VA_selfRopeEpoch',0]];
 _carrier setVariable ['QS_VA_selfLocalRopeLinks',[]];
 private _attach = _carrier addEventHandler ['RopeAttach',{
  params ['_carrier','_rope','_cargo'];
  // Mutate directly in the native event: recursive function calls inherit RPC context.
  private _epoch = (_carrier getVariable ['QS_VA_selfLocalRopeEpoch',0]) + 1;
  private _links = (_carrier getVariable ['QS_VA_selfLocalRopeLinks',[]]) select {_x # 0 isNotEqualTo _rope};
  if (!isNull _rope && {!isNull _cargo}) then {_links pushBack [_rope,_cargo,_epoch];};
  _carrier setVariable ['QS_VA_selfLocalRopeEpoch',_epoch];
  _carrier setVariable ['QS_VA_selfLocalRopeLinks',_links];
  if (isServer) then {
   _carrier setVariable ['QS_VA_selfRopeEpoch',_epoch,true];
   _carrier setVariable ['QS_VA_selfRopeLinks',_links,true];
  };
 }];
 private _break = _carrier addEventHandler ['RopeBreak',{
  params ['_carrier','_rope','_cargo'];
  private _epoch = (_carrier getVariable ['QS_VA_selfLocalRopeEpoch',0]) + 1;
  private _links = (_carrier getVariable ['QS_VA_selfLocalRopeLinks',[]]) select {_x # 0 isNotEqualTo _rope};
  _carrier setVariable ['QS_VA_selfLocalRopeEpoch',_epoch];
  _carrier setVariable ['QS_VA_selfLocalRopeLinks',_links];
  if (isServer) then {
   _carrier setVariable ['QS_VA_selfRopeEpoch',_epoch,true];
   _carrier setVariable ['QS_VA_selfRopeLinks',_links,true];
  };
 }];
 _carrier setVariable ['QS_VA_selfLocalRopeEH',[_attach,_break]];
};
if (_mode isEqualTo 'SELF_WATCH_LOCAL') exitWith {
 if (!_serverAuthority || {!(_a isEqualType objNull)}) exitWith {};
 [_a] call _selfWatchRopes;
};
private _watchVehicle = {
 params ['_vehicle'];
 if (_vehicle isKindOf 'Helicopter' && {!unitIsUAV _vehicle} && {isNil {_vehicle getVariable 'QS_VA_selfLocalRopeEH'}}) then {
  [_vehicle] call _selfWatchRopes;
  // Non-JIP setup on current machines. A joining/migrated executor without native
  // rope provenance fails closed rather than trusting a stale server-only mapping.
  [['SELF_WATCH_LOCAL',_vehicle],0] call _deliver;
 };
 if (isNil {_vehicle getVariable 'QS_VA_accessEH'}) then {
  private _getIn = _vehicle addEventHandler ['GetIn',{['ACCESS_SCAN',_this # 0] call QS_fnc_clientVehicleAccess;}];
  private _getOut = _vehicle addEventHandler ['GetOut',{
   params ['_vehicle','','_unit']; ['ACCESS_SCAN',_vehicle,_unit] call QS_fnc_clientVehicleAccess;
  }];
  private _switch = _vehicle addEventHandler ['SeatSwitched',{['ACCESS_SCAN',_this # 0] call QS_fnc_clientVehicleAccess;}];
  private _loaded = _vehicle addEventHandler ['CargoLoaded',{
   params ['_vehicle','_cargo'];
   _cargo setVariable ['QS_VA_cargoEpoch',(_cargo getVariable ['QS_VA_cargoEpoch',0]) + 1,true];
  }];
  private _unloaded = _vehicle addEventHandler ['CargoUnloaded',{
   params ['_vehicle','_cargo'];
   _cargo setVariable ['QS_VA_cargoEpoch',(_cargo getVariable ['QS_VA_cargoEpoch',0]) + 1,true];
  }];
  private _ropeBreak = _vehicle addEventHandler ['RopeBreak',{
   ['SLING_BROKEN',_this # 0,_this # 2] call QS_fnc_clientVehicleAccess;
  }];
  private _ropeAttach = _vehicle addEventHandler ['RopeAttach',{
   private _carrier = _this # 0;
   _carrier setVariable ['QS_VA_slingEpoch',(_carrier getVariable ['QS_VA_slingEpoch',0]) + 1,true];
  }];
  _vehicle setVariable ['QS_VA_slingSeen',[_vehicle] call _slingCargo];
  _vehicle setVariable ['QS_VA_accessEH',[_getIn,_getOut,_switch,_loaded,_unloaded,_ropeBreak,_ropeAttach]];
  private _occupants = (fullCrew [_vehicle,'',false]) apply {
   private _unit = _x # 0; private _epoch = (_unit getVariable ['QS_VA_boardEpoch',0]) + 1;
   _unit setVariable ['QS_VA_boardEpoch',_epoch,true];
   [_unit,[_x] call _signature,_epoch,true,0]
  };
  _vehicle setVariable ['QS_VA_occupants',_occupants];
 };
 private _watched = missionNamespace getVariable ['QS_VA_watched',[]]; _watched pushBackUnique _vehicle;
 missionNamespace setVariable ['QS_VA_watched',_watched]; call _serverLoop;
};
if (_mode isEqualTo 'ACCESS') exitWith {[_a] call _access};
if (_mode isEqualTo 'LOCKED_FOR') exitWith {
 private _state = [_a] call _access; private _index = _groups find _c;
 !unitIsUAV _a && {_index >= 0} && {(_state # 1) isNotEqualTo ''} && {!([_a,_b,_state] call _privileged)} && {(_state # 2) # _index}
};
if (_mode isEqualTo 'INPUT_VEHICLE') exitWith {if (hasInterface) then {call _inputVehicle} else {objNull}};
if (_mode isEqualTo 'NOTICE_VEHICLE') exitWith {if (hasInterface) then {call _noticeVehicle} else {objNull}};
if (_mode isEqualTo 'GROUND_CLAIM_ALLOWED') exitWith {[_a,_b] call _groundClaimAllowed};
if (_mode isEqualTo 'DURATION') exitWith {[profileNamespace getVariable ['QS_VA5_ejectSeconds',3]] call _duration};
if (_mode isEqualTo 'ALL_DURATION') exitWith {[profileNamespace getVariable ['QS_VA5_allSeconds',3],3] call _duration};
private _controlDefaults = [
 ['LOCK',[35,false,false,false],'PRESS',0.75],
 ['ROPE',[57,false,false,false],'DOUBLE',3],
 ['EJECT',[57,false,false,false],'HOLD',3],
 ['ALL',[57,false,false,false],'ADDITIONAL',3]
];
private _controlVars = [
 ['QS_VA_lockKey','QS_VA5_lockMode','QS_VA6_lockSeconds'],
 ['QS_VA6_ropeKey','QS_VA6_ropeMode','QS_VA6_ropeSeconds'],
 ['QS_vehicleAccess_ejectKey','QS_VA6_ejectMode','QS_VA5_ejectSeconds'],
 ['QS_VA6_allKey','QS_VA6_allMode','QS_VA5_allSeconds']
];
private _controlIndex = {params ['_kind']; ['LOCK','ROPE','EJECT','ALL'] find _kind};
private _readControls = {
 _controlDefaults apply {
  private _default = _x; private _index = [_default # 0] call _controlIndex;
  private _vars = _controlVars # _index;
  private _bind = profileNamespace getVariable [_vars # 0,+(_default # 1)];
  private _activation = profileNamespace getVariable [_vars # 1,_default # 2];
  private _allowed = if (_index isEqualTo 3) then {['PRESS','DOUBLE','HOLD','ADDITIONAL']} else {['PRESS','DOUBLE','HOLD']};
  if (!(_activation in _allowed)) then {_activation = _default # 2;};
  private _seconds = profileNamespace getVariable [_vars # 2,_default # 3];
  if (!(_seconds isEqualType 0) || {!finite _seconds}) then {_seconds = _default # 3;};
  _seconds = (_seconds max (if (_index isEqualTo 0) then {0.25} else {1})) min 5;
  [_default # 0,_bind,_activation,_seconds]
 }
};
if (_mode isEqualTo 'CONTROLS') exitWith {call _readControls};
if (_mode isEqualTo 'INPUT_MODE') exitWith {((call _readControls) # ([_a] call _controlIndex)) # 2};
if (_mode isEqualTo 'KEY_BINDING') exitWith {
 private _controls = call _readControls; private _index = [_a] call _controlIndex;
 if (_index isEqualTo 3 && {(_controls # 3) # 2 isEqualTo 'ADDITIONAL'}) then {_index=2;};
 +((_controls # _index) # 1)
};
// Both complete taps must belong to the same actor, vehicle, chord and load epoch.
private _tapPair = {
 params ['_tap','_previous','_now'];
 _tap isNotEqualTo [] && {_previous isNotEqualTo []} &&
 {_now - (_tap # 1) >= 0} && {_now - (_tap # 1) <= 0.3} &&
 {(_tap # 1) - (_previous # 1) >= 0} && {(_tap # 1) - (_previous # 1) <= 0.4} &&
 {(_tap select [0,1]) isEqualTo (_previous select [0,1])} &&
 {(_tap select [2]) isEqualTo (_previous select [2])}
};

// No frame gap, paused simulation or network outage contributes hold time.
private _clock = {
 private _now = diag_tickTime;
 private _old = missionNamespace getVariable ['QS_VA_clock',[_now,time,0,0,-1,false]];
 _old params ['_wall','_sim','_total','_steady','_lastFrame',['_advanced',false]];
 private _dw = _now - _wall; private _ds = time - _sim;
 private _epoch = missionNamespace getVariable ['QS_VA_clockEpoch',0];
 if (diag_frameNo isNotEqualTo _lastFrame) then {
  _advanced = _ds > 0 && {_ds <= 0.25} && {_dw <= 0.25} && {!isGamePaused};
  if (_dw <= 0.25 && {_ds >= 0} && {_ds <= 0.25} && {!isGamePaused}) then {
   _total = _total + (_dw min _ds); _steady = _steady + (_dw min _ds);
  } else {_steady = 0; _epoch = _epoch + 1; missionNamespace setVariable ['QS_VA_clockEpoch',_epoch];};
  missionNamespace setVariable ['QS_VA_clock',[_now,time,_total,_steady,diag_frameNo,_advanced]];
 };
 [_total,_steady >= 0.25 && {_advanced},_epoch]
};
if (_mode isEqualTo 'SERVER_CLOCK') exitWith {if (isServer && {!isRemoteExecuted}) then {call _clock;};};
// Hold: serial, actor, connection, start, heartbeat, reserved, progress, nonce,
// clock, checkpoints, reserved, paused, clockEpoch, seconds, ownerGroup, stage, ownerUID,
// lastContactClock, beginClock, groupLeader, allSeconds, cargoOnly, plan.
// Public state: revision, phase, serial, actor, start, sent, expires, reason,
// progress, checkpoints, seconds, committedStage, ownerGroup, ownerUID, allSeconds, cargoOnly.
private _stateFor = {
 params ['_hold','_phase','_reason',['_ttl',120]];
 [0,_phase,_hold # 0,_hold # 1,_hold # 3,serverTime,serverTime + _ttl,_reason,_hold # 6,_hold # 9,_hold # 13,_hold # 15,_hold # 14,_hold # 16,_hold # 20,_hold # 21]
};
private _publishState = {
 params ['_vehicle','_state'];
 private _revision = (_vehicle getVariable ['QS_VA_revision',0]) + 1;
 _vehicle setVariable ['QS_VA_revision',_revision]; _state set [0,_revision];
 _vehicle setVariable ['QS_VA_eject',_state,true];
 private _targets = (crew _vehicle) select {isPlayer _x};
 { {if (isPlayer _x) then {_targets pushBackUnique _x;};} forEach crew _x; } forEach ([_vehicle] call _internalCargo);
 private _pilot = _state # 3;
 if (!isNull _pilot && {isPlayer _pilot}) then {_targets pushBackUnique _pilot;};
 if (unitIsUAV _vehicle) then {
  private _control = UAVControl _vehicle;
  {if (!isNull _x && {isPlayer _x}) then {_targets pushBackUnique _x;};} forEach [_control param [0,objNull],_control param [2,objNull]];
 };
 if (_targets isNotEqualTo []) then {[['NOTICE',_vehicle,_state],_targets] call _deliver;};
 private _active = missionNamespace getVariable ['QS_VA_active',[]]; _active pushBackUnique _vehicle;
 missionNamespace setVariable ['QS_VA_active',_active]; call _serverLoop;
 _state
};
private _ack = {
 params ['_vehicle','_hold'];
 [['HOLD_ACK',_vehicle,[_hold # 0,_hold # 7,_hold # 6,_hold # 9,_hold # 13,_hold # 15,_hold # 20]],_hold # 1] call _deliver;
};
private _cargoTicketValid = {
 params ['_cargo','_vehicle','_serial','_ticket'];
 _ticket params ['_state','_stage','_epoch'];
 if (isNull _cargo || {isNull _vehicle} || {unitIsUAV _vehicle} || {isVehicleCargo _cargo isNotEqualTo _vehicle}) exitWith {false};
 if ((_cargo getVariable ['QS_VA_cargoEpoch',0]) isNotEqualTo _epoch || {serverTime >= (_state # 6)} || {_state # 2 isNotEqualTo _serial} || {_state # 11 < _stage} || {_state # 8 < ([_state # 10,_state # 14,_stage - 1] call _stageTarget)}) exitWith {false};
 ([_vehicle,_state # 3] call _pilotValid) &&
 {([_vehicle,_state # 3] call _getOwnerGroup) isEqualTo (_state # 12)} &&
 {([_vehicle] call _ejectOwnerUID) isEqualTo (_state # 13)}
};
private _scanAccess = {
 params ['_vehicle',['_departed',objNull]];
 if (!isServer || {isNull _vehicle}) exitWith {};
 private _state = [_vehicle] call _access;
 if (_state isNotEqualTo (_vehicle getVariable ['QS_VA_access',[]])) then {[_vehicle,_state] call _publishAccess;};
 private _old = _vehicle getVariable ['QS_VA_occupants',[]];
 if (_departed isEqualType objNull && {!isNull _departed}) then {
  _departed setVariable ['QS_VA_boardEpoch',(_departed getVariable ['QS_VA_boardEpoch',0]) + 1,true];
  _old = _old select {_x # 0 isNotEqualTo _departed};
 };
 if (!isNull _departed) exitWith {_vehicle setVariable ['QS_VA_occupants',_old];};
 private _ownerGroup = grpNull; private _ownerGroupReady = false;
 private _checkAIGroups = !unitIsUAV _vehicle && {(_state # 1) isNotEqualTo ''} && {true in (_state # 2)};
 private _next = [];
 {
  private _unit = _x # 0; private _sig = [_x] call _signature;
  if (_checkAIGroups && {!isPlayer _unit} && {!_ownerGroupReady}) then {_ownerGroup = [_vehicle] call _getOwnerGroup; _ownerGroupReady = true;};
  private _index = _old findIf {_x # 0 isEqualTo _unit};
  private _entry = if (_index >= 0) then {+(_old # _index)} else {[]};
  private _changed = _entry isEqualTo [] || {_entry # 1 isNotEqualTo _sig};
  private _locked = !unitIsUAV _vehicle && {(_state # 1) isNotEqualTo ''} && {(_state # 2) # (_groups find ([_vehicle,_x] call _seatGroup))} && {!([_vehicle,_unit,_state,_ownerGroup] call _privileged)};
  if (_changed) then {
   private _epoch = (_unit getVariable ['QS_VA_boardEpoch',0]) + 1; _unit setVariable ['QS_VA_boardEpoch',_epoch,true];
   _entry = [_unit,_sig,_epoch,!_locked,0];
  };
  if (!_locked) then {_entry set [3,true];};
  if (!(_entry # 3) && {diag_tickTime >= (_entry # 4)}) then {
   [['ACCESS_LOCAL',_unit,_vehicle,[_state # 0,_sig,_entry # 2]],_unit] call _deliver;
   _entry set [4,diag_tickTime + 0.3];
  };
  _next pushBack _entry;
 } forEach (fullCrew [_vehicle,'',false]);
 _vehicle setVariable ['QS_VA_occupants',_next];
};
private _queueSling = {
 params ['_vehicle','_pilot','_serial'];
 if (!([_vehicle] call _hasRopes)) exitWith {};
 [_vehicle,_pilot] call _slingHeight;
 private _loads = [_vehicle] call _slingCargo;
 private _snapshot = [_loads,_vehicle getVariable ['QS_VA_slingEpoch',0]];
 {[_x,_vehicle] call _queueDrop;} forEach _loads;
 // An old request must not release a replaced or reattached load.
 [['CARGO_LOCAL',_vehicle,_snapshot,[_pilot,_serial,serverTime + 2]],_vehicle] call _deliver;
};
private _queueStage = {
 params ['_vehicle','_state','_stage'];
 // This runs inside a validated SERVER request; a recursive RPC entry retains
 // isRemoteExecuted and would reject its own internal scan.
 [_vehicle] call _scanAccess;
 private _pending = missionNamespace getVariable ['QS_VA_pending',[]];
 private _seats = (fullCrew [_vehicle,'',false]) select {[_vehicle,_x,_stage,_state # 12] call _eligible};
 private _ttl = 3 + ((count _pending + count _seats) * 0.2);
 private _replacedUnits = _seats apply {_x # 0};
 // Filter the old queue once; new tickets cannot contain duplicate occupied units.
 _pending = _pending select {(_x # 1) isNotEqualTo _vehicle || {!((_x # 0) in _replacedUnits)}};
 {
  private _unit = _x # 0;
  private _ticketState = +_state; _ticketState set [6,serverTime + _ttl];
  private _ticket = [_ticketState,_stage,[_x] call _signature,_unit getVariable ['QS_VA_boardEpoch',-1],_forEachIndex];
  _pending pushBack [_unit,_vehicle,_state # 2,_ticket,serverTime,0];
 } forEach _seats;
 missionNamespace setVariable ['QS_VA_pending',_pending];
 private _cargoPending = missionNamespace getVariable ['QS_VA_cargoPending',[]];
 {
  private _cargo = _x;
  private _ticketState = +_state; _ticketState set [6,serverTime + 2];
  private _ticket = [_ticketState,_stage,_cargo getVariable ['QS_VA_cargoEpoch',0]];
  _cargoPending = _cargoPending select {_x # 0 isNotEqualTo _cargo};
  if ([_cargo,_vehicle,_state # 2,_ticket] call _cargoTicketValid) then {
   // Unload this object only. Native ViV supplies its normal airborne paradrop.
   // Seated crew inside the cargo vehicle remain in it.
   if (!(objNull setVehicleCargo _cargo)) then {
    _cargoPending pushBack [_cargo,_vehicle,_state # 2,_ticket,serverTime + 0.3,1];
   };
  };
 } forEach ([_vehicle] call _internalCargo);
 missionNamespace setVariable ['QS_VA_cargoPending',_cargoPending];
 [_vehicle,_state # 3,_state # 2] call _queueSling;
};
private _finish = {
 params ['_vehicle','_phase','_reason'];
 private _hold = _vehicle getVariable ['QS_VA_hold',[]];
 if (_hold isEqualTo []) exitWith {};
 if (_phase isEqualTo 'ABORT' && {_hold # 15 isEqualTo 1} && {_hold param [22,'CHAIN'] isNotEqualTo 'ALL'}) then {_reason = 'Passenger stage confirmed. Full eject cancelled.';};
 _vehicle setVariable ['QS_VA_hold',[]];
 private _state = [_vehicle,[_hold,_phase,_reason,2] call _stateFor] call _publishState;
 if (_phase isEqualTo 'COMPLETE') then {[_vehicle,_state,2] call _queueStage;};
};
if (_mode isEqualTo 'SERVER') exitWith {
 if (!isServer) exitWith {};
 private _operation = _a; private _vehicle = _b; private _actor = _c; private _payload = _d;
 if (!(_operation isEqualType '') || {!(_vehicle isEqualType objNull)} || {!(_actor isEqualType objNull)} || {!(_payload isEqualType [])}) exitWith {};
 if (isNull _actor || {!isPlayer _actor}) exitWith {};
 private _sender = if (isMultiplayer && {isRemoteExecuted}) then {remoteExecutedOwner} else {owner _actor};
 if (_sender isNotEqualTo owner _actor) exitWith {
 };
 if ((_actor getVariable ['QS_VA_serialOwner',-1]) isNotEqualTo _sender) then {
  _actor setVariable ['QS_VA_serialOwner',_sender]; _actor setVariable ['QS_VA_serialFloor',-1];
 };
 if (_operation isEqualTo 'ABORT') exitWith {
  private _serial = _payload param [0,-1,[0]];
  if (_serial < 0 || {!finite _serial}) exitWith {};
  _actor setVariable ['QS_VA_serialFloor',(_actor getVariable ['QS_VA_serialFloor',-1]) max _serial];
  if (isNull _vehicle) exitWith {};
  private _hold = _vehicle getVariable ['QS_VA_hold',[]];
  if (_hold isNotEqualTo [] && {_hold # 0 isEqualTo _serial} && {_hold # 1 isEqualTo _actor} && {_hold # 2 isEqualTo _sender}) then {[_vehicle,'ABORT','Pilot cancelled'] call _finish;};
 };
 if (_operation isEqualTo 'DESPAWN') exitWith {
  if (!((lifeState _actor) in ['HEALTHY','INJURED']) || {serverTime < (_actor getVariable ['QS_VA_despawnNext',-1])}) exitWith {};
  _actor setVariable ['QS_VA_despawnNext',serverTime + 2];
  private _uid = getPlayerUID _actor;
  if (_uid isEqualTo '') exitWith {};
  private _owned = vehicles select {
   private _v = _x;
   (['LandVehicle','Air','Ship'] findIf {_v isKindOf _x}) >= 0 && {([_v] call _despawnOwner) isEqualTo _uid}
  };
  private _busy = _owned select {[_x] call _despawnBusy};
  if (_busy isNotEqualTo []) exitWith {
   [['RESULT_NOTE',format ['Nothing despawned: %1 owned vehicle(s) still occupied, loaded, attached or connected to a terminal.',count _busy]],_actor] call _deliver;
  };
  {
   [_x,'ABORT','Vehicle despawned'] call _finish;
   {if ([_x] call _droneCrew) then {deleteVehicle _x;};} forEach crew _x;
   deleteVehicle _x;
  } forEach _owned;
  missionNamespace setVariable ['QS_spawnMenu_spawnedEntities',(missionNamespace getVariable ['QS_spawnMenu_spawnedEntities',[]]) select {!isNull _x}];
  _actor setVariable ['QS_spawnMenu_nextSpawn',0];
  [['RESULT_NOTE',format ['Despawned %1 owned vehicle(s). Their vehicle allowance slots are available.',count _owned]],_actor] call _deliver;
 };
 if (isNull _vehicle || {!alive _vehicle}) exitWith {};
 if (_operation isEqualTo 'SELF_RELEASE') exitWith {
  if (!([_vehicle,_actor] call _selfDriverValid)) exitWith {};
  _payload params [['_serial',-1,[0]],['_sent',-100,[0]],['_snapshot',[],[[]]]];
  if (!finite _serial || {!finite _sent} || {_serial < 0} || {_serial isNotEqualTo floor _serial} ||
   {_serial <= (_actor getVariable ['QS_VA_serialFloor',-1])} || {abs (serverTime - _sent) > 2}) exitWith {};
  _actor setVariable ['QS_VA_serialFloor',_serial];
  if (serverTime < (_actor getVariable ['QS_VA_selfNext',-1])) exitWith {};
  _actor setVariable ['QS_VA_selfNext',serverTime + 1];
  private _carriers = [_vehicle] call _selfCarriers;
  if (_carriers isEqualTo []) exitWith {};
  {[_x] call _watchVehicle;} forEach _carriers;
  private _current = [_vehicle,_actor] call _selfSnapshot;
  if (_current isEqualTo [] || {_snapshot isNotEqualTo _current}) exitWith {
   [['NOTE',_vehicle,'Self-release unavailable: rope identity changed or was not observed. Ask the carrier to reattach the load, then try again.'],_actor] call _deliver;
  };
  private _pending = missionNamespace getVariable ['QS_VA_selfPending',[]];
  _pending = _pending select {_x # 0 isNotEqualTo _vehicle};
  {
   _x params ['_carrier','_epoch','_links'];
   private _ticket = [_vehicle,_carrier,_actor,_serial,_sender,_current # 0,_current # 1,_epoch,_links,serverTime + 2,serverTime];
   _pending pushBack _ticket;
  } forEach (_current # 2);
  missionNamespace setVariable ['QS_VA_selfPending',_pending];
  // Only this cargo receives the existing separation + one-second chute handling.
  [_vehicle,_carriers # 0] call _queueDrop;
  call _serverLoop;
 };
 if (_operation isEqualTo 'CLAIM_UGV') exitWith {
  if (!([_vehicle,_actor] call _groundClaimAllowed) || {isNil 'TGC_fnc_lockDroneByUID'}) exitWith {};
  private _uid = getPlayerUID _actor;
  if (_uid isEqualTo '') exitWith {};
  // Reserve synchronously so simultaneous physical claims cannot both succeed.
  _vehicle setVariable ['TGC_drones_owner',_uid,true];
  if ((_vehicle getVariable ['QS_spawnMenu_spawnedBy','']) isNotEqualTo '') then {_vehicle setVariable ['QS_spawnMenu_spawnedBy',_uid,true];};
  [_vehicle,_uid] remoteExecCall ['TGC_fnc_lockDroneByUID',0,false];
  [['NOTE',_vehicle,'UGV claimed. Use terminal Driver/Gunner control to eject its passenger.'],_actor] call _deliver;
 };
 if (unitIsUAV _vehicle) then {
  if (!([_vehicle,_actor] call _pilotValid)) then {_operation = '';};
 } else {if (objectParent _actor isNotEqualTo _vehicle) then {_operation = '';};};
 if (_operation isEqualTo '') exitWith {};
 private _accessState = [_vehicle] call _access;
 if (!unitIsUAV _vehicle && {_accessState isNotEqualTo (_vehicle getVariable ['QS_VA_access',[]])}) then {[_vehicle,_accessState] call _publishAccess;};
 if (_operation isEqualTo 'HELLO') exitWith {
  if (!unitIsUAV _vehicle && {(_accessState # 1) isNotEqualTo ''}) then {
   private _owned = missionNamespace getVariable ['QS_VA_owned',[]]; _owned pushBackUnique _vehicle;
   missionNamespace setVariable ['QS_VA_owned',_owned]; [_vehicle] call _watchVehicle;
  };
 };
 if (_operation in ['CLAIM','LOCK_ALL','LOCK_GROUP']) exitWith {
  if (unitIsUAV _vehicle || {!((lifeState _actor) in ['HEALTHY','INJURED'])} || {serverTime < (_actor getVariable ['QS_VA_lockNext',-1])}) exitWith {};
  private _uid = getPlayerUID _actor; private _ownerUID = _accessState # 1;
  if (_uid isEqualTo '') exitWith {};
  if (_ownerUID isNotEqualTo '' && {_ownerUID isNotEqualTo _uid}) exitWith {
   [['NOTE',_vehicle,'Only the vehicle owner can change its locks.'],_actor] call _deliver;
  };
  if (!([_vehicle,_actor] call _driverValid)) exitWith {
   [['NOTE',_vehicle,'Only the current owner in the driver/pilot seat can change locks.'],_actor] call _deliver;
  };
  private _expected = _payload param [0,-1,[0]];
  if (_operation isNotEqualTo 'CLAIM' && {_expected isNotEqualTo (_accessState # 0)}) exitWith {
   [['NOTE',_vehicle,'Access changed. Check the current state and try again.'],_actor] call _deliver;
  };
  private _flags = +(_accessState # 2); private _message = 'Vehicle claimed. Existing access settings retained.';
  if (_operation isEqualTo 'CLAIM' && {_ownerUID isEqualTo ''} && {!(true in _flags)}) then {_message = 'Vehicle claimed - unlocked.';};
  if (_operation isEqualTo 'LOCK_ALL') then {
   private _value = _payload param [1,false,[true]]; _flags = [_value,_value,_value,_value];
   _message = ['Vehicle unlocked.','Vehicle locked. Current occupants can remain or leave.'] select _value;
  };
  if (_operation isEqualTo 'LOCK_GROUP') then {
   private _index = _groups find (_payload param [1,'',['']]);
   if (_index < 0) exitWith {};
   _flags set [_index,_payload param [2,false,[true]]]; _message = 'Vehicle seat access updated.';
  };
  // Seed occupants BEFORE locking; a lock change does not expel existing crew.
  [_vehicle] call _watchVehicle;
  _actor setVariable ['QS_VA_lockNext',serverTime + 0.25]; _vehicle setVariable ['QS_VA_ownerNetId',_sender];
  [_vehicle,[(_accessState # 0) + 1,_uid,_flags]] call _publishAccess;
  if (_ownerUID isEqualTo '' && {!isNil {_vehicle getVariable 'QS_spawnMenu_spawnedBy'}}) then {_vehicle setVariable ['QS_spawnMenu_spawnedBy',_uid,true];};
  private _owned = missionNamespace getVariable ['QS_VA_owned',[]]; _owned pushBackUnique _vehicle;
  missionNamespace setVariable ['QS_VA_owned',_owned];
  [['NOTE',_vehicle,_message],(crew _vehicle) select {isPlayer _x}] call _deliver;
 };
 if (!([_vehicle,_actor] call _pilotValid)) exitWith {};
 (call _clock) params ['_clockTime','_clockReady'];
 // Rope gestures cut sling ropes only; ejection stages own cargo and occupants.
 if (_operation isEqualTo 'SLING') exitWith {
  _payload params [['_serial',-1,[0]],['_sent',-100,[0]],['_loads',[],[[]]],['_epoch',-1,[0]]];
  if (!finite _serial || {!finite _sent} || {!finite _epoch} || {_serial <= (_actor getVariable ['QS_VA_serialFloor',-1])} || {abs (serverTime - _sent) > 2}) exitWith {};
  _actor setVariable ['QS_VA_serialFloor',_serial];
  if ((_vehicle getVariable ['QS_VA_hold',[]]) isNotEqualTo [] || {serverTime < (_actor getVariable ['QS_VA_cargoNext',-1])}) exitWith {};
  _actor setVariable ['QS_VA_cargoNext',serverTime + 1];
  private _currentLoads = [_vehicle] call _slingCargo;
  if (_epoch isNotEqualTo (_vehicle getVariable ['QS_VA_slingEpoch',0]) || {(_currentLoads - _loads) isNotEqualTo []} || {(_loads - _currentLoads) isNotEqualTo []}) exitWith {};
  if ([_vehicle] call _hasRopes) then {
   [_vehicle] call _watchVehicle;
   [_vehicle,_actor,_serial] call _queueSling;
  } else {
   [['NOTE',_vehicle,'No sling ropes to cut. Internal cargo uses Eject Passengers & Cargo.'],_actor] call _deliver;
  };
 };
 if (_operation isEqualTo 'ACTIVATE') exitWith {
  _payload params [['_serial',-1,[0]],['_sent',-100,[0]],['_stage',0,[0]]];
  if (!finite _serial || {!finite _sent} || {!(_stage in [1,2])} || {_serial <= (_actor getVariable ['QS_VA_serialFloor',-1])} || {abs (serverTime - _sent) > 2}) exitWith {};
  _actor setVariable ['QS_VA_serialFloor',_serial];
  if ((_vehicle getVariable ['QS_VA_hold',[]]) isNotEqualTo [] || {serverTime < (_actor getVariable ['QS_VA_activateNext',-1])}) exitWith {};
  _actor setVariable ['QS_VA_activateNext',serverTime + 0.5];
  private _ownerGroup = [_vehicle,_actor] call _getOwnerGroup;
  if (!([_vehicle,_ownerGroup] call _hasTargets)) exitWith {};
  [_vehicle] call _watchVehicle;
  private _state = [0,['PASSENGERS','COMPLETE'] select (_stage - 1),_serial,_actor,serverTime,serverTime,serverTime + 2,'Custom shortcut confirmed',0,0,0,_stage,_ownerGroup,[_vehicle] call _ejectOwnerUID,0,[_vehicle,_ownerGroup] call _cargoOnly];
  _state = [_vehicle,_state] call _publishState;
  [_vehicle,_state,_stage] call _queueStage;
 };
 if (_operation isEqualTo 'BEGIN') exitWith {
  private _serial = _payload param [0,-1,[0]];
  if (!(finite _serial) || {_serial <= (_actor getVariable ['QS_VA_serialFloor',-1])}) exitWith {};
  _actor setVariable ['QS_VA_serialFloor',_serial];
  private _ownerGroup = [_vehicle,_actor] call _getOwnerGroup;
  if (!([_vehicle,_ownerGroup] call _hasTargets)) exitWith {};
  private _old = _vehicle getVariable ['QS_VA_hold',[]];
  if (_old isNotEqualTo [] && {!([_vehicle,_old # 1] call _pilotValid) || {[_old,_clockTime] call _holdExpired}}) then {
   [_vehicle,'ABORT','Previous operator is no longer authorized'] call _finish; _old = [];
  };
  // Two terminal operators cannot replace one another's in-progress request.
  if (_old isNotEqualTo [] && {_old # 1 isNotEqualTo _actor}) exitWith {
   [['NOTE',_vehicle,'Another operator is already holding eject.'],_actor] call _deliver;
  };
  if (_old isNotEqualTo []) then {[_vehicle,'ABORT','Replaced by a new request'] call _finish;};
  [_vehicle] call _watchVehicle;
  private _seconds = [_payload param [1,3,[0]]] call _duration;
  private _allSeconds = [_payload param [2,3,[0]],3] call _duration;
  private _plan = _payload param [3,'CHAIN',['']];
  if (!(_plan in ['CHAIN','PASSENGERS','ALL'])) exitWith {};
  if (_plan isEqualTo 'ALL') then {_seconds=0;};
  private _hold = [_serial,_actor,_sender,serverTime,diag_tickTime,false,0,1,_clockTime,0,diag_tickTime,false,missionNamespace getVariable ['QS_VA_clockEpoch',0],_seconds,_ownerGroup,0,[_vehicle] call _ejectOwnerUID,_clockTime,_clockTime,leader _ownerGroup,_allSeconds,[_vehicle,_ownerGroup] call _cargoOnly,_plan];
  if (_plan isEqualTo 'ALL') then {_hold set [15,1];};
  _vehicle setVariable ['QS_VA_hold',_hold];
  [_vehicle,[_hold,'HOLD',''] call _stateFor] call _publishState; [_vehicle,_hold] call _ack;
 };
 if (_operation in ['BEAT','SYNC','CONFIRM']) then {
  private _hold = _vehicle getVariable ['QS_VA_hold',[]]; private _serial = _payload param [0,-1,[0]];
  if (_hold isEqualTo [] || {_hold # 0 isNotEqualTo _serial} || {_hold # 1 isNotEqualTo _actor} || {_hold # 2 isNotEqualTo _sender}) exitWith {};
  if (([_vehicle,_actor] call _getOwnerGroup) isNotEqualTo (_hold # 14) || {([_vehicle] call _ejectOwnerUID) isNotEqualTo (_hold # 16)} || {leader (_hold # 14) isNotEqualTo (_hold # 19)}) exitWith {[_vehicle,'ABORT','Vehicle owner or group changed'] call _finish;};
  if ([_hold,_clockTime] call _holdExpired) exitWith {[_vehicle,'ABORT','Eject timed out. Release and press again.'] call _finish;};
  if ((_hold # 12) isNotEqualTo (missionNamespace getVariable ['QS_VA_clockEpoch',0])) exitWith {
   _hold set [12,missionNamespace getVariable ['QS_VA_clockEpoch',0]];
   _hold set [7,(_hold # 7) + 1]; _hold set [8,_clockTime]; _hold set [4,diag_tickTime]; _hold set [11,true];
   _vehicle setVariable ['QS_VA_hold',_hold];
   [_vehicle,[_hold,'PAUSED','Simulation resumed - reconfirming input'] call _stateFor] call _publishState; [_vehicle,_hold] call _ack;
  };
  private _nonce = _payload param [1,-1,[0]];
  if (_operation isNotEqualTo 'SYNC' && {_nonce isNotEqualTo (_hold # 7)}) exitWith {};
  private _ready = _clockReady && {diag_tickTime - (_hold # 4) <= 1.25} && {_payload param [3,false,[true]]};
  private _points = [_hold # 13,_hold # 20] call _checkpoints;
  private _target = [_hold # 13,_hold # 20,_hold # 15] call _stageTarget;
  if (_operation isEqualTo 'CONFIRM' && {_ready} && {_hold # 6 >= _target}) then {
   if (_hold # 15 isEqualTo 0) then {
    _hold set [15,1]; _vehicle setVariable ['QS_VA_hold',_hold];
    private _state = [_vehicle,[_hold,'HOLD','Passengers/cargo committed; release to cancel All'] call _stateFor] call _publishState;
    [_vehicle,_state,1] call _queueStage;
    if (_hold # 22 isEqualTo 'PASSENGERS') then {[_vehicle,'PASSENGERS','Passengers/cargo confirmed'] call _finish;};
   } else {_hold set [15,2]; _vehicle setVariable ['QS_VA_hold',_hold]; [_vehicle,'COMPLETE','Full eject confirmed'] call _finish;};
  };
  if ((_vehicle getVariable ['QS_VA_hold',[]]) isEqualTo []) exitWith {};
  if (_operation isEqualTo 'BEAT' && {_ready}) then {
   private _credit = _payload param [2,0,[0]];
   if (!finite _credit) then {_credit = 0;};
   _credit = ((_credit max 0) min 0.25) min ((_clockTime - (_hold # 8)) max 0);
   private _boundary = (_points # ((_hold # 9) min ((count _points) - 1))) min ([_hold # 13,_hold # 20,_hold # 15] call _stageTarget);
   private _progress = ((_hold # 6) + _credit) min _boundary;
   if (_progress >= _boundary - 0.0001) then {
    _progress = _boundary;
    if ((_hold # 9) < count _points && {_boundary isEqualTo (_points # (_hold # 9))}) then {_hold set [9,(_hold # 9) + 1];};
   };
   _hold set [6,_progress];
  };
  _hold set [17,_clockTime];
  _hold set [4,diag_tickTime]; _hold set [7,(_hold # 7) + 1]; _hold set [8,_clockTime]; _hold set [11,!_ready];
  _vehicle setVariable ['QS_VA_hold',_hold];
  [_vehicle,[_hold,['PAUSED','HOLD'] select _ready,if (_ready) then {''} else {'Waiting for simulation / input'}] call _stateFor] call _publishState;
  [_vehicle,_hold] call _ack;
 };
};
if (_mode isEqualTo 'ACCESS_SCAN') exitWith {
 if (!isServer || {isRemoteExecuted} || {isNull _a}) exitWith {};
 [_a,if (_b isEqualType objNull) then {_b} else {objNull}] call _scanAccess;
};
if (_mode isEqualTo 'DISCONNECT') exitWith {
 if (!isServer || {isRemoteExecuted}) exitWith {};
 {
  private _hold = _x getVariable ['QS_VA_hold',[]];
  if (_hold isNotEqualTo [] && {_hold # 2 isEqualTo _b}) then {[_x,'ABORT','Operator disconnected'] call _finish;};
 } forEach (missionNamespace getVariable ['QS_VA_active',[]]);
 {
  private _state = [_x] call _access;
  if ((_state # 1) isEqualTo _a && {(_x getVariable ['QS_VA_ownerNetId',-1]) in [-1,_b]}) then {
   [_x,[(_state # 0) + 1,_state # 1,[false,false,false,false]]] call _publishAccess;
   [['NOTE',_x,'Vehicle unlocked: its owner disconnected.'],(crew _x) select {isPlayer _x}] call _deliver;
  };
 } forEach (missionNamespace getVariable ['QS_VA_owned',[]]);
};
if (_mode isEqualTo 'SLING_BROKEN') exitWith {
 if (!isServer || {isRemoteExecuted} || {isNull _a} || {!(_a isKindOf 'Helicopter')} || {unitIsUAV _a} || {isNil {_a getVariable 'QS_VA_accessEH'}}) exitWith {};
 [_b,_a] call _queueDrop;
};
if (_mode isEqualTo 'SERVER_TICK') exitWith {
 if (!isServer || {isRemoteExecuted}) exitWith {};
 private _serverClock = call _clock; private _active = missionNamespace getVariable ['QS_VA_active',[]];
 {
  private _vehicle = _x; private _hold = _vehicle getVariable ['QS_VA_hold',[]];
  if (_hold isNotEqualTo []) then {
   private _pilot = _hold # 1;
   if (!([_vehicle,_pilot] call _pilotValid) || {owner _pilot isNotEqualTo (_hold # 2)} || {([_vehicle,_pilot] call _getOwnerGroup) isNotEqualTo (_hold # 14)} || {([_vehicle] call _ejectOwnerUID) isNotEqualTo (_hold # 16)} || {leader (_hold # 14) isNotEqualTo (_hold # 19)}) then {
    [_vehicle,'ABORT','Operator, owner or group changed'] call _finish;
   } else {
    if ([_hold,_serverClock # 0] call _holdExpired) exitWith {[_vehicle,'ABORT','Eject timed out. Release and press again.'] call _finish;};
    if (!([_vehicle,_hold # 14] call _hasTargets)) exitWith {
     [_vehicle,['ABORT','PASSENGERS'] select ((_hold # 15) >= 1),'No eligible occupants or cargo remain'] call _finish;
    };
    if ((_hold # 12) isNotEqualTo (_serverClock # 2)) then {
     _hold set [12,_serverClock # 2]; _hold set [7,(_hold # 7) + 1]; _hold set [8,_serverClock # 0];
     _hold set [4,diag_tickTime]; _hold set [11,false]; _vehicle setVariable ['QS_VA_hold',_hold]; [_vehicle,_hold] call _ack;
    };
    if ((diag_tickTime - (_hold # 4) > 1.25 || {!(_serverClock # 1)}) && {!(_hold # 11)}) then {
     _hold set [11,true]; _vehicle setVariable ['QS_VA_hold',_hold];
     [_vehicle,[_hold,'PAUSED','Waiting for simulation / input'] call _stateFor] call _publishState;
    };
    private _live = _vehicle getVariable ['QS_VA_eject',[]];
    if (count _live isEqualTo 16 && {serverTime > (_live # 6) - 30}) then {
     _live set [6,serverTime + 120]; [_vehicle,_live] call _publishState;
    };
   };
  };
 } forEach _active;
 _active = _active select {
  private _state = _x getVariable ['QS_VA_eject',[]];
  private _keep = !isNull _x && {_state isNotEqualTo []} && {serverTime < (_state # 6)};
  if (!_keep && {!isNull _x}) then {_x setVariable ['QS_VA_eject',[],true];}; _keep
 };
 missionNamespace setVariable ['QS_VA_active',_active];
 private _pending = missionNamespace getVariable ['QS_VA_pending',[]];
 private _budget = 2;
 private _failed = [];
 private _ordered = (_pending select {(_x # 5) isEqualTo 0}) + (_pending select {(_x # 5) > 0});
 _pending = _ordered select {
  _x params ['_unit','_vehicle','_serial','_ticket','_next','_tries']; private _state = _ticket # 0;
  private _keep = !isNull _vehicle && {!isNull _unit} && {objectParent _unit isEqualTo _vehicle} && {serverTime < (_state # 6)} && {_tries < 4} && {(_unit getVariable ['QS_VA_boardEpoch',-1]) isEqualTo (_ticket # 3)};
  if (!_keep && {!isNull _vehicle} && {!isNull _unit} && {objectParent _unit isEqualTo _vehicle} && {(_unit getVariable ['QS_VA_boardEpoch',-1]) isEqualTo (_ticket # 3)}) then {_failed pushBackUnique [_vehicle,_serial,_state # 3];};
  if (_keep && {_budget > 0} && {serverTime >= _next}) then {
   _budget = _budget - 1;
   _x set [4,serverTime + 0.3]; _x set [5,_tries + 1];
   [['EJECT_LOCAL',_unit,_vehicle,_serial,_ticket],_unit] call _deliver;
   _keep = objectParent _unit isEqualTo _vehicle;
  }; _keep
 };
 missionNamespace setVariable ['QS_VA_pending',_pending];
 {
  _x params ['_vehicle','_serial','_pilot'];
  if ((_vehicle getVariable ['QS_VA_reportedFailure',-1]) isNotEqualTo _serial) then {
   _vehicle setVariable ['QS_VA_reportedFailure',_serial];
   [['NOTE',_vehicle,'Ejection incomplete: some occupants stayed aboard. Check altitude/health, then retry.'],_pilot] call _deliver;
  };
 } forEach _failed;
 private _cargoPending = missionNamespace getVariable ['QS_VA_cargoPending',[]];
 _cargoPending = _cargoPending select {
  _x params ['_cargo','_vehicle','_serial','_ticket','_next','_tries'];
  private _keep = [_cargo,_vehicle,_serial,_ticket] call _cargoTicketValid;
  if (_keep && {serverTime >= _next}) then {
   if (objNull setVehicleCargo _cargo) then {_keep = false;} else {
    _tries = _tries + 1; _x set [4,serverTime + 0.3]; _x set [5,_tries];
    if (_tries >= 4) then {
     _keep = false;
     [['NOTE',_vehicle,'Internal cargo could not unload. Reposition and try again.'],(_ticket # 0) # 3] call _deliver;
    };
   };
  }; _keep
 };
 missionNamespace setVariable ['QS_VA_cargoPending',_cargoPending];
 private _selfPending = missionNamespace getVariable ['QS_VA_selfPending',[]];
 _selfPending = _selfPending select {
  private _ticket = _x;
  private _keep = [_ticket] call _selfTicketValid;
  if (_keep && {serverTime >= (_ticket # 10)}) then {
   _ticket set [10,serverTime + 0.2];
   [['SELF_RELEASE_LOCAL',_ticket],_ticket # 1] call _deliver;
  };
  if (!_keep && {serverTime >= (_ticket # 9)} && {[_ticket # 0,_ticket # 2] call _selfDriverValid} &&
   {(_ticket # 1) in ([_ticket # 0] call _selfCarriers)}) then {
   [['NOTE',_ticket # 0,'Self-release was not confirmed. Rope provenance or vehicle locality changed; ask the carrier to reattach the load.'],_ticket # 2] call _deliver;
  };
  _keep
 };
 missionNamespace setVariable ['QS_VA_selfPending',_selfPending];
 private _owned = missionNamespace getVariable ['QS_VA_owned',[]];
 if (serverTime >= (missionNamespace getVariable ['QS_VA_ownerNext',0])) then {
  missionNamespace setVariable ['QS_VA_ownerNext',serverTime + 1]; private _uids = allPlayers apply {getPlayerUID _x};
  _owned = _owned select {
   private _state = [_x] call _access; private _uid = _state # 1;
   private _keep = !isNull _x && {alive _x} && {_uid isNotEqualTo ''} && {_uid in _uids};
   if (!isNull _x) then {
    if (!_keep && {_uid isNotEqualTo ''}) then {_state = [(_state # 0) + 1,_uid,[false,false,false,false]];};
    if (_state isNotEqualTo (_x getVariable ['QS_VA_access',[]])) then {[_x,_state] call _publishAccess;};
   }; _keep
  };
  missionNamespace setVariable ['QS_VA_owned',_owned];
 };
 private _watched = missionNamespace getVariable ['QS_VA_watched',[]];
 if (diag_tickTime >= (missionNamespace getVariable ['QS_VA_scanNext',0])) then {
  missionNamespace setVariable ['QS_VA_scanNext',diag_tickTime + 0.25];
  _watched = _watched select {
   private _keep = !isNull _x && {alive _x} && {_x in _owned || {_x in _active}};
   // Also detect manual cuts if a remote RopeBreak event is delayed or absent.
   private _loads = [_x] call _slingCargo;
   private _carrier = _x;
   {if (!(_x in _loads)) then {[_x,_carrier] call _queueDrop;};} forEach (_carrier getVariable ['QS_VA_slingSeen',[]]);
   _carrier setVariable ['QS_VA_slingSeen',_loads];
   if (_keep) then {['ACCESS_SCAN',_x] call QS_fnc_clientVehicleAccess;} else {
    if (!isNull _x) then {
     private _handlers = _x getVariable ['QS_VA_accessEH',[]]; private _vehicle = _x;
     {_vehicle removeEventHandler [_x,_handlers # _forEachIndex];} forEach (['GetIn','GetOut','SeatSwitched','CargoLoaded','CargoUnloaded','RopeBreak','RopeAttach'] select [0,count _handlers]);
     _x setVariable ['QS_VA_slingSeen',nil];
     _x setVariable ['QS_VA_accessEH',nil]; _x setVariable ['QS_VA_occupants',nil];
    };
   }; _keep
  };
  missionNamespace setVariable ['QS_VA_watched',_watched];
 };
 private _drops = missionNamespace getVariable ['QS_VA_slingDrops',[]];
 _drops = _drops select {
  _x params ['_cargo','_carrier','_expires','_next','_canopy','_openHeight',['_openAfter',-1]];
  private _keep = true;
  if (serverTime >= _next) then {
   _x set [3,serverTime + 0.2];
   private _parent = attachedTo _cargo;
   if (isNull _cargo || {!alive _cargo}) then {_keep = false;} else {
    private _bottom = _cargo modelToWorldWorld [0,0,(boundingBoxReal _cargo # 0) # 2];
    private _clearance = if (surfaceIsWater _bottom) then {_bottom # 2} else {(ASLToATL _bottom) # 2};
    if (isNull _canopy) then {
     private _free = isNull ropeAttachedTo _cargo && {isNull isVehicleCargo _cargo} &&
      {isNull _parent} && {isNull _carrier || {getSlingLoad _carrier isNotEqualTo _cargo}};
     if (_free) then {
      // Start the delay only after full separation; keep the canopy below the pilot's view.
      if (_openAfter < 0) then {_openAfter = serverTime + 1; _x set [6,_openAfter];};
      if (serverTime >= _openAfter) then {
       if (isTouchingGround _cargo || {(getPos _cargo # 2) <= _openHeight}) then {_keep = false;} else {
        // Keep the load in place; never snap a falling vehicle down to terrain.
        _canopy = createVehicle [missionNamespace getVariable ['QS_core_classNames_vehicleParachute','B_Parachute_02_F'],[0,0,1000],[],0,'FLY'];
        if (isNull _canopy) then {_keep = false; diag_log '[VA549] cargo parachute creation failed';} else {
         if (!isNull _carrier) then {_canopy disableCollisionWith _carrier;};
         // Initialise parachute placement through attachment before hanging the load.
         _canopy attachTo [_cargo,[0,0,3]];
         detach _canopy;
         _canopy setDir getDir _cargo;
         private _velocity = velocity _cargo;
         _canopy setVelocity [(_velocity # 0) max -10 min 10,(_velocity # 1) max -10 min 10,-3];
         _cargo attachTo [_canopy,[0,0,-3]];
         _x set [4,_canopy];
        };
       };
      };
     } else {
      _x set [6,-1];
      // Another chute/delivery system owns this load, or some ropes remain.
      if ((!isNull _parent && {_parent isKindOf 'ParachuteBase'}) || {serverTime >= _expires}) then {_keep = false;};
     };
    } else {
     private _surface = lineIntersectsSurfaces [_bottom vectorAdd [0,0,0.5],_bottom vectorAdd [0,0,-1],_cargo,_canopy,true,1,'GEOM','NONE'];
     _keep = alive _canopy && {_parent isEqualTo _canopy} &&
      {isNull ropeAttachedTo _cargo} && {isNull isVehicleCargo _cargo} &&
      {!isTouchingGround _cargo} && {_clearance > 1} && {_surface isEqualTo []};
    };
   };
   if (!_keep && {!isNull _canopy}) then {
    if (!isNull _cargo && {attachedTo _cargo isEqualTo _canopy}) then {detach _cargo;};
    deleteVehicle _canopy;
   };
  };
  _keep
 };
 missionNamespace setVariable ['QS_VA_slingDrops',_drops];
 if (_active isEqualTo [] && {_pending isEqualTo []} && {_cargoPending isEqualTo []} && {_drops isEqualTo []} && {_selfPending isEqualTo []} && {_owned isEqualTo []} && {_watched isEqualTo []}) then {
  removeMissionEventHandler ['EachFrame',missionNamespace getVariable ['QS_VA_serverEH',-1]]; missionNamespace setVariable ['QS_VA_serverEH',-1];
 };
};
if (_mode isEqualTo 'SELF_RELEASE_LOCAL') exitWith {
 if (!_serverAuthority || {!(_a isEqualType [])} || {count _a isNotEqualTo 11}) exitWith {};
 private _ticket = _a;
 _ticket params ['_cargo','_carrier','_actor','_serial','_sender','_uid','_board','_epoch','_links','_expires'];
 if (!(_cargo isEqualType objNull) || {!(_carrier isEqualType objNull)} || {!(_actor isEqualType objNull)} ||
  {!(_links isEqualType [])} || {!(_expires isEqualType 0)} || {!local _carrier}) exitWith {};
 // Install missing JIP/locality-migration observation now; never bootstrap live ropes.
 // This request still fails below until the complete current graph is observed.
 [_carrier] call _selfWatchRopes;
 if (!([_ticket] call _selfTicketValid)) exitWith {};
 // Native event provenance on the carrier's CURRENT executor is mandatory too.
 // A late/JIP server snapshot alone cannot establish a rope's current endpoint.
 if ((_carrier getVariable ['QS_VA_selfLocalRopeEpoch',-1]) isNotEqualTo _epoch ||
  {(_carrier getVariable ['QS_VA_selfLocalRopeLinks',[]]) isNotEqualTo _links}) exitWith {};
 private _identity = [_cargo,_actor,_serial,_sender,_epoch];
 if ((_carrier getVariable ['QS_VA_selfLast',[]]) isEqualTo _identity) exitWith {};
 private _targets = _links select {_x # 1 isEqualTo _cargo};
 if (_targets isEqualTo []) exitWith {};
 _carrier setVariable ['QS_VA_selfLast',_identity];
 if (attachedTo _cargo isEqualTo _carrier) then {detach _cargo;};
 if ((_carrier getVariable ['QS_sling_attached',objNull]) isEqualTo _cargo) then {_carrier setVariable ['QS_sling_attached',objNull,true];};
 {
  // The loop contains ONLY observed incoming edges ending on the owned cargo.
  // Do not call carrier-wide CARGO_LOCAL, setSlingLoad, or destroy ropes _carrier.
  if (_x in (_carrier getVariable ['QS_VA_selfLocalRopeLinks',[]]) && {(_x # 0) in ropes _carrier}) then {ropeDestroy (_x # 0);};
 } forEach _targets;
};
if (_mode isEqualTo 'CARGO_LOCAL') exitWith {
 if (!_serverAuthority || {!(_a isEqualType objNull)} || {!(_b isEqualType [])} || {count _b isNotEqualTo 2} || {!(_c isEqualType [])} || {count _c isNotEqualTo 3}) exitWith {};
 _c params ['_pilot','_serial','_expires'];
 _b params ['_loads','_epoch'];
 if (isNull _a || {!local _a} || {serverTime >= _expires} || {!([_a,_pilot] call _pilotValid)}) exitWith {};
 if ((_a getVariable ['QS_VA_slingEpoch',0]) isNotEqualTo _epoch) exitWith {};
 private _currentLoads = [_a] call _slingCargo;
 if ((_currentLoads - _loads) isNotEqualTo [] || {(_loads - _currentLoads) isNotEqualTo []}) exitWith {};
 if ((_a getVariable ['QS_VA_lastCargo',[]]) isEqualTo [_pilot,_serial,_b]) exitWith {};
 _a setVariable ['QS_VA_lastCargo',[_pilot,_serial,_b]];
 private _ropes = ropes _a;
 // Release only verified rope loads, including an I&A load cinched to its carrier.
 {
  if (attachedTo _x isEqualTo _a) then {detach _x;};
  if ((_a getVariable ['QS_sling_attached',objNull]) isEqualTo _x) then {_a setVariable ['QS_sling_attached',objNull,true];};
 } forEach _loads;
 if (!isNull getSlingLoad _a) then {_a setSlingLoad objNull;};
 {if (_x in ropes _a) then {ropeDestroy _x;};} forEach _ropes;
};
if (_mode in ['EJECT_LOCAL','ACCESS_LOCAL']) exitWith {
 if (!_serverAuthority) exitWith {};
 private _unit = _a; private _vehicle = _b;
 if (!(_unit isEqualType objNull) || {!(_vehicle isEqualType objNull)} || {isNull _unit} || {!local _unit} || {objectParent _unit isNotEqualTo _vehicle} || {[_unit] call _droneCrew}) exitWith {};
 private _seats = (fullCrew [_vehicle,'',false]) select {_x # 0 isEqualTo _unit};
 if (_seats isEqualTo []) exitWith {};
 private _seat = _seats # 0; private _sig = [_seat] call _signature; private _token = [];
 if (_mode isEqualTo 'ACCESS_LOCAL') then {
  private _state = [_vehicle] call _access;
  if (!(_c isEqualType []) || {count _c isNotEqualTo 3}) exitWith {};
  if (unitIsUAV _vehicle || {_c # 0 isNotEqualTo (_state # 0)} || {_c # 1 isNotEqualTo _sig} || {_c # 2 isNotEqualTo (_unit getVariable ['QS_VA_boardEpoch',-1])}) exitWith {};
  if ((['LOCKED_FOR',_vehicle,_unit,[_vehicle,_seat] call _seatGroup] call QS_fnc_clientVehicleAccess)) then {_token = ['ACCESS',_vehicle,_c # 2];};
 } else {
  if (!(_d isEqualType []) || {count _d isNotEqualTo 5}) exitWith {};
  _d params ['_state','_stage','_expectedSeat','_epoch'];
  if (!(_state isEqualType []) || {count _state isNotEqualTo 16} || {!(_stage in [1,2])} || {_state # 2 isNotEqualTo _c} || {serverTime >= (_state # 6)} || {_state # 11 < _stage} || {_state # 8 < ([_state # 10,_state # 14,_stage - 1] call _stageTarget)}) exitWith {};
  if (_expectedSeat isNotEqualTo _sig || {_epoch isNotEqualTo (_unit getVariable ['QS_VA_boardEpoch',-1])}) exitWith {};
  if (!([_vehicle,_state # 3] call _pilotValid) || {([_vehicle,_state # 3] call _getOwnerGroup) isNotEqualTo (_state # 12)} || {([_vehicle] call _ejectOwnerUID) isNotEqualTo (_state # 13)}) exitWith {};
  if (!([_vehicle,_seat,_stage,_state # 12] call _eligible)) exitWith {};
  _token = ['EJECT',_vehicle,_c,_state # 3,_stage,_epoch];
  if (hasInterface && {_unit isEqualTo player}) then {['UI_STATE',_vehicle,_state,true] call QS_fnc_clientVehicleAccess;};
 };
 if (_token isEqualTo [] || {(_unit getVariable ['QS_VA_lastExit',[]]) isEqualTo _token}) exitWith {};
 if (!isPlayer _unit && {alive _unit}) then {[_unit] orderGetIn false;};
 unassignVehicle _unit; _unit moveOut _vehicle;
 if (objectParent _unit isNotEqualTo _vehicle) then {
  _unit setVariable ['QS_VA_lastExit',_token];
 };
 if (_mode isEqualTo 'ACCESS_LOCAL' && {hasInterface} && {_unit isEqualTo player}) then {systemChat 'This seat is owner-locked.';};
 // Player GetOutMan continues through I&A's existing fall/parachute handling.
};

if (!hasInterface) exitWith {};
private _context = {
 !isNull player && {(lifeState player) in ['HEALTHY','INJURED']} && {isGameFocused} && {!isGamePaused} && {!userInputDisabled} && {!dialog} && {!visibleMap} && {commandingMenu isEqualTo ''} && {isNull curatorCamera} && {!isNull findDisplay 46} && {isNull displayChild findDisplay 46} && {isNull findDisplay 24} && {!(missionNamespace getVariable ['QS_targetBoundingBox_placementMode',false])} && {!(player call QS_fnc_isBusyAttached)}
};
// Owned-vehicle shortcuts also consume their keys while the scroll menu is visible.
private _lockContext = {
 !isNull player && {(lifeState player) in ['HEALTHY','INJURED']} && {isGameFocused} && {!isGamePaused} && {!userInputDisabled} && {!dialog} && {!visibleMap} && {commandingMenu isEqualTo ''} && {isNull curatorCamera} && {!isNull findDisplay 46} && {isNull displayChild findDisplay 46} && {isNull findDisplay 24} && {!(missionNamespace getVariable ['QS_targetBoundingBox_placementMode',false])} && {!(player call QS_fnc_isBusyAttached)}
};
if (_mode isEqualTo 'SEND') exitWith {
 [['SERVER',_a,_b,player,_c],2] call _deliver;
};

if (_mode isEqualTo 'HOLD_ALLOWED') exitWith {
 (call _context) && {(call _inputVehicle) isEqualTo _a} && {[_a,player] call _pilotValid} && {((localNamespace getVariable ['QS_VA_localHold',[]]) isNotEqualTo []) || {[_a,[_a,player] call _getOwnerGroup] call _hasTargets}}
};
if (_mode isEqualTo 'CHECK') exitWith {
 private _unit = _a; private _vehicle = _c;
 if (!local _unit || {isNull _vehicle} || {unitIsUAV _vehicle} || {objectParent _unit isNotEqualTo _vehicle}) exitWith {false};
 private _state = [_vehicle] call _access;
 if ((_state # 1) in ['',getPlayerUID _unit]) exitWith {false};
 private _seat = (fullCrew [_vehicle,'',false]) select {(_x # 0) isEqualTo _unit};
 if (_seat isEqualTo []) exitWith {false};
 private _index = _groups find ([_vehicle,_seat # 0] call _seatGroup);
 if (_index < 0 || {!((_state # 2) # _index)}) exitWith {false};
 _unit moveOut _vehicle;
 systemChat 'This seat is owner-locked.';
 true
};
if (_mode isEqualTo 'RESULT_NOTE') exitWith {
 if (isRemoteExecuted && {!_serverAuthority}) exitWith {};
 systemChat _a;
};
if (_mode isEqualTo 'NOTE') exitWith {
 if (isRemoteExecuted && {!_serverAuthority}) exitWith {};
 if ((call _inputVehicle) isEqualTo _a || {isNull objectParent player && {player distance _a <= 6} && {[_a] call _supportedUGV}}) then {systemChat _b; ['REFRESH'] call QS_fnc_clientVehicleAccess;};
};

if (_mode isEqualTo 'UI_CLEAR') exitWith {
 {if (!isNull _x) then {ctrlDelete _x;};} forEach (uiNamespace getVariable ['QS_VA_controls',[]]);
 uiNamespace setVariable ['QS_VA_controls',[]];
 localNamespace setVariable ['QS_VA_ui',[]];
 private _eh = localNamespace getVariable ['QS_VA_uiEH',-1];
 if (_eh >= 0) then {removeMissionEventHandler ['EachFrame',_eh];};
 localNamespace setVariable ['QS_VA_uiEH',-1];
};
if (_mode isEqualTo 'HOLD_ACK') exitWith {
 if (!_serverAuthority) exitWith {};
 private _hold = localNamespace getVariable ['QS_VA_localHold',[]];
 if (_hold isEqualTo [] || {_hold # 1 isNotEqualTo _a} || {_hold # 2 isNotEqualTo (_b param [0,-1])}) exitWith {};
 private _old = localNamespace getVariable ['QS_VA_ack',[-1,-1,0,0,0,-1]];
 if ((_b # 1) <= (_old # 1)) exitWith {};
 localNamespace setVariable ['QS_VA_ack',[_b # 0,_b # 1,_b # 2,_b # 3,diag_tickTime,diag_frameNo,_b # 4,_b # 5,_b # 6]];
 localNamespace setVariable ['QS_VA_waitAck',false];
};
if (_mode isEqualTo 'NOTICE') exitWith {
 if (isRemoteExecuted && {!_serverAuthority}) exitWith {};
 ['UI_STATE',_a,_b,false] call QS_fnc_clientVehicleAccess;
};
if (_mode isEqualTo 'UI_STATE') exitWith {
 private _vehicle = _a; private _state = _b;
 if (!(_state isEqualType []) || {count _state isNotEqualTo 16} || {isNull findDisplay 46} || {!alive player}) exitWith {};
 _state params ['_revision','_phase','_serial','_pilot','','','_expires','_reason'];
 if (serverTime >= _expires || {!(_phase in ['HOLD','PAUSED','COMPLETE','ABORT','PASSENGERS'])}) exitWith {};
 private _old = localNamespace getVariable ['QS_VA_ui',[]];
 private _following = _old isNotEqualTo [] && {_old # 0 isEqualTo _vehicle} && {((_old # 1) # 2) isEqualTo _serial} && {((_old # 1) # 3) isEqualTo _pilot};
 if ((call _noticeVehicle) isNotEqualTo _vehicle && {!_following} && {!(_c isEqualTo true)}) exitWith {};
 if (_following && {((_old # 1) # 1) isEqualTo 'PASSENGERS'}) exitWith {};
 private _seen = _vehicle getVariable ['QS_VA_seenRevision',-1];
 // Re-entry may resume the same active countdown; older/terminal replays stay suppressed.
 if (_revision < _seen || {_revision isEqualTo _seen && {!(_phase in ['HOLD','PAUSED'] && {_old isEqualTo []})}}) exitWith {};
 if (_phase in ['HOLD','PAUSED'] && {_pilot isEqualTo player} && {_serial <= (localNamespace getVariable ['QS_VA_cancelledSerial',-1])}) exitWith {};
 _vehicle setVariable ['QS_VA_seenRevision',_revision];
 private _controls = uiNamespace getVariable ['QS_VA_controls',[]];
 if (_controls isEqualTo [] || {isNull (_controls # 0)}) then {
  ['UI_CLEAR'] call QS_fnc_clientVehicleAccess;
  private _display = findDisplay 46;
  private _x = safeZoneX + safeZoneW * 0.34;
  private _y = safeZoneY + safeZoneH * 0.80;
  private _w = safeZoneW * 0.32;
  private _h = safeZoneH * 0.052;
  private _back = _display ctrlCreate ['RscText',-1];
  _back ctrlSetPosition [_x,_y,_w,_h]; _back ctrlSetBackgroundColor [0.015,0.02,0.025,0.88];
  private _bar = _display ctrlCreate ['RscProgress',-1];
  _bar ctrlSetPosition [_x,_y,_w,_h];
  _bar ctrlSetTextColor [0.30,0.52,0.65,0.60];
  private _icon = _display ctrlCreate ['RscPicture',-1];
  _icon ctrlSetPosition [_x + _w * 0.02,_y + _h * 0.16,_h * 0.68,_h * 0.68];
  private _title = _display ctrlCreate ['RscStructuredText',-1];
  _title ctrlSetPosition [_x + _w * 0.10,_y + _h * 0.14,_w * 0.82,_h * 0.70];
  private _body = _display ctrlCreate ['RscText',-1];
  _body ctrlSetPosition [_x,_y + _h,_w,_h * 0.50];
  _body ctrlSetFontHeight (safeZoneH * 0.015);
  _controls = [_back,_icon,_title,_body,_bar];
  { _x ctrlSetFade 1; _x ctrlCommit 0; _x ctrlSetFade 0; _x ctrlCommit 0.12; } forEach _controls;
  uiNamespace setVariable ['QS_VA_controls',_controls];
 } else {
  { _x ctrlSetFade 0; _x ctrlCommit 0.12; } forEach _controls;
 };
 private _color = switch _phase do {case 'COMPLETE'; case 'PASSENGERS': {[0.35,1,0.55,1]}; case 'ABORT': {[1,0.45,0.30,1]}; default {[1,0.8,0.25,1]};};
 private _iconPath = switch _phase do {
  case 'ABORT': {'\A3\ui_f\data\map\mapcontrol\taskIconCanceled_ca.paa'};
  case 'COMPLETE'; case 'PASSENGERS': {'\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa'};
  default {'\a3\Missions_F_Orange\Data\Img\Showcase_LawsOfWar\action_exit_CA.paa'};
 };
 (_controls # 1) ctrlSetText _iconPath;
 (_controls # 1) ctrlSetTextColor _color;
 (_controls # 2) ctrlSetTextColor _color;
 (_controls # 4) ctrlSetTextColor [_color # 0,_color # 1,_color # 2,0.50];
 private _stage = _state # 11;
 private _stageChanged = _following && {_stage isEqualTo 1} && {((_old # 1) # 11) isEqualTo 0};
 if (_phase in ['COMPLETE','PASSENGERS'] || {_stageChanged}) then {playSound 'HintExpand';};
 if (_phase isEqualTo 'ABORT') then {playSound 'HintCollapse';};
 // JIP seeds the current checkpoint. It never replays earlier cues.
 private _lastTick = if (_stage isEqualTo 0) then {(ceil (_state # 10)) - 1} else {(count ([_state # 10,_state # 14] call _checkpoints)) - 1};
 private _checkpoint = ((_state # 9) min _lastTick) max 0;
 private _previous = if (_following) then {_old # 2} else {_checkpoint};
 if (_following && {!_stageChanged} && {_checkpoint > _previous} && {_phase in ['HOLD','PAUSED']}) then {playSound 'Beep_Target';};
 private _target = ([_state # 8,_state # 10,_state # 14,_stage] call _barPosition) min 0.99;
 private _displayed = if (_following && {!_stageChanged}) then {_old param [5,0]} else {_target};
 private _flashUntil = if (_stageChanged) then {diag_tickTime + 0.18} else {if (_following) then {_old param [7,0]} else {0}};
 localNamespace setVariable ['QS_VA_ui',[_vehicle,_state,_checkpoint,false,player,_displayed,diag_tickTime,_flashUntil]];
 if ((localNamespace getVariable ['QS_VA_uiEH',-1]) < 0) then {
  localNamespace setVariable ['QS_VA_uiEH',addMissionEventHandler ['EachFrame',{['UI_FRAME'] call QS_fnc_clientVehicleAccess;}]];
 };
};
if (_mode isEqualTo 'UI_FRAME') exitWith {
 private _ui = localNamespace getVariable ['QS_VA_ui',[]];
 private _controls = uiNamespace getVariable ['QS_VA_controls',[]];
 if (_ui isEqualTo [] || {_controls isEqualTo []} || {isNull (_controls # 0)}) exitWith {['UI_CLEAR'] call QS_fnc_clientVehicleAccess;};
 _ui params ['_vehicle','_state','','_fading','_shownPlayer'];
 _state params ['','_phase','','','','','_expires'];
 if (player isNotEqualTo _shownPlayer || {!alive player} || {serverTime >= _expires}) exitWith {['UI_CLEAR'] call QS_fnc_clientVehicleAccess;};
 if (_phase in ['HOLD','PAUSED'] && {(call _noticeVehicle) isNotEqualTo _vehicle || {!alive _vehicle}}) then {
  if ((_state # 11) >= 1 && {_state # 10 > 0} && {alive _vehicle}) then {
   _state = +_state; _state set [1,'PASSENGERS']; _state set [6,serverTime + 2]; _ui set [1,_state];
   _phase = 'PASSENGERS'; _expires = _state # 6;
   (_controls # 1) ctrlSetText '\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa';
   (_controls # 3) ctrlSetText 'Passenger stage confirmed';
  } else {_phase = 'CLEAR';};
 };
 if (_phase isEqualTo 'CLEAR') exitWith {['UI_CLEAR'] call QS_fnc_clientVehicleAccess;};
 if (_phase in ['HOLD','PAUSED']) then {
  private _target = ([_state # 8,_state # 10,_state # 14,_state # 11] call _barPosition) min 0.99;
  private _displayed = _ui # 5; private _dt = (diag_tickTime - (_ui # 6)) max 0;
  if (_dt <= 0.25 && {_phase isEqualTo 'HOLD'}) then {_displayed = _displayed + ((_target - _displayed) * ((12 * _dt) min 1));};
  _ui set [5,_displayed]; _ui set [6,diag_tickTime];
  private _paused = _phase isEqualTo 'PAUSED' || {serverTime - (_state # 5) > 1.25};
  if ((_state # 3) isEqualTo player && {localNamespace getVariable ['QS_VA_needsInput',false]}) then {_paused = true;};
  private _flash = diag_tickTime < (_ui param [7,0]);
  (_controls # 1) ctrlSetText (if (_flash) then {'\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa'} else {'\a3\Missions_F_Orange\Data\Img\Showcase_LawsOfWar\action_exit_CA.paa'});
  private _label = if (_flash) then {'Auto-Eject Complete'} else {
   if ((_state # 11) isEqualTo 0) then {if (_state # 15) then {'Auto Eject Cargo'} else {'Auto-Eject Initiated'}} else {'Auto-Ejecting All'}
  };
  (_controls # 2) ctrlSetStructuredText parseText format ["<t align='center'>%1</t>",_label];
  (_controls # 3) ctrlSetText (if (_paused) then {'Paused - keep holding; release to cancel'} else {''});
  (_controls # 4) progressSetPosition (if (_flash) then {1} else {_displayed min 1});
 } else {
  private _stage = _state # 11;
  private _label = switch _phase do {
   case 'COMPLETE': {'Eject All committed'};
   case 'PASSENGERS': {if (_state # 15) then {'Cargo Ejected'} else {'Auto-Eject Complete'}};
   default {if (_stage >= 1) then {'Auto-Eject All Cancelled'} else {'Auto-Eject Cancelled'}};
  };
  (_controls # 2) ctrlSetStructuredText parseText format ["<t align='center'>%1</t>",_label];
  (_controls # 3) ctrlSetText (if (_phase isEqualTo 'ABORT' && {_stage >= 1} && {_state # 10 > 0}) then {'Passengers/cargo already ejected'} else {''});
  (_controls # 4) progressSetPosition (if (_phase in ['COMPLETE','PASSENGERS']) then {1} else {0});
  if (!_fading && {serverTime >= _expires - 0.35}) then {{_x ctrlSetFade 1; _x ctrlCommit 0.35;} forEach _controls; _ui set [3,true];};
 };
 localNamespace setVariable ['QS_VA_ui',_ui];
};

if (_mode isEqualTo 'KEY_LABEL') exitWith {
 private _bind = if (_b isEqualType [] && {count _b isEqualTo 4}) then {_b} else {['KEY_BINDING',_a] call QS_fnc_clientVehicleAccess};
 _bind params ['_key','_shift','_ctrl','_alt'];
 format ['%1%2%3%4',['','Ctrl+'] select _ctrl,['','Shift+'] select _shift,['','Alt+'] select _alt,keyName _key]
};
if (_mode isEqualTo 'KEY_CONFLICTS') exitWith {
 private _bind = _a;
 private _conflicts = [];
 {
  private _action = _x;
  if (!(_action isEqualTo 'HeliRopeAction' && {_b isEqualTo 'ROPE'}) && {((actionKeysEx _action) findIf {((_x # 0) # 1) isEqualTo 'KEYBOARD' && {((_x # 0) # 0) isEqualTo (_bind # 0)}}) >= 0}) then {_conflicts pushBack _action;};
 } forEach ['HeliCollectiveRaise','HeliCollectiveLower','HeliUp','HeliDown','AutoHover','AutoHoverCancel','HeliRudderLeft','HeliRudderRight','HeliCyclicForward','HeliCyclicBack','HeliCyclicLeft','HeliCyclicRight','LaunchCM','HeliRopeAction','Turbo','CarFastForward','PushToTalk'];
 _conflicts
};
if (_mode isEqualTo 'NATIVE_ACTION') exitWith {
 if ((_a param [3,'']) isNotEqualTo 'UnhookCargo') exitWith {false};
 private _vehicle = cameraOn;
 private _target = _a param [0,objNull,[objNull]];
 if (isNull _vehicle || {!(_vehicle isKindOf 'Helicopter')}) then {_vehicle = _target;};
 // Native UnhookCargo follows cameraOn, including remote/curator cameras.
 if (isNull _vehicle || {!(_vehicle isKindOf 'Helicopter')}) exitWith {false};
 if (_vehicle isNotEqualTo (call _inputVehicle) || {!([_vehicle,player] call _pilotValid)} || {_target isKindOf 'Helicopter' && {_target isNotEqualTo _vehicle}}) exitWith {true};
 if (!([_vehicle] call _hasRopes)) exitWith {false};
 private _controls = call _readControls;
 private _keys = localNamespace getVariable ['QS_VA_keysDown',[]];
 private _blocked = diag_tickTime <= (localNamespace getVariable ['QS_VA_consumeUntil',-1]);
 {
  private _bind = _x # 1; private _key = _bind # 0;
  private _modifiers = [
   (42 in _keys || {54 in _keys}) && {!(_key in [42,54])},
   (29 in _keys || {157 in _keys}) && {!(_key in [29,157])},
   (56 in _keys || {184 in _keys}) && {!(_key in [56,184])}
  ];
  if ((_bind select [1]) isEqualTo _modifiers) then {
   if (_key in _keys) then {_blocked=true;};
   {
    if (inputAction _x > 0 && {((actionKeysEx _x) findIf {((_x # 0) # 1) isEqualTo 'KEYBOARD' && {((_x # 0) # 0) isEqualTo _key}}) >= 0}) then {_blocked=true;};
   } forEach ['DefaultAction','Action','HeliRopeAction'];
  };
 } forEach (_controls select {_x # 2 isNotEqualTo 'ADDITIONAL'});
 _blocked
};
if (_mode isEqualTo 'TRACK_DISPLAY') exitWith {
 if (isNull _a || {_a getVariable ['QS_VA_tracksKeys',false]}) exitWith {};
 _a setVariable ['QS_VA_tracksKeys',true];
 _a displayAddEventHandler ['KeyDown',{
  private _keys = localNamespace getVariable ['QS_VA_keysDown',[]];
  _keys pushBackUnique (_this # 1); localNamespace setVariable ['QS_VA_keysDown',_keys]; false
 }];
 _a displayAddEventHandler ['KeyUp',{
  private _key = _this # 1;
  localNamespace setVariable ['QS_VA_keysDown',(localNamespace getVariable ['QS_VA_keysDown',[]]) - [_key]];
  if (_key isEqualTo (localNamespace getVariable ['QS_VA_ejectDown',-1])) then {
   localNamespace setVariable ['QS_VA_ejectDown',-1]; localNamespace setVariable ['QS_VA_ejectConsumed',false];
  }; false
 }];
};
if (_mode isEqualTo 'KEY_CANCEL') exitWith {
 if (!(call _context)) then {['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;};
 private _hold = localNamespace getVariable ['QS_VA_localHold',[]];
 if (_hold isNotEqualTo []) then {
  _hold params ['','_vehicle','_serial'];
  ['SEND','ABORT',_vehicle,[_serial]] call QS_fnc_clientVehicleAccess;
  localNamespace setVariable ['QS_VA_cancelledSerial',_serial];
 };
 localNamespace setVariable ['QS_VA_localHold',[]];
 localNamespace setVariable ['QS_VA_ack',[-1,-1,0,0,0,-1]];
 localNamespace setVariable ['QS_VA_needsInput',false];
 private _eh = localNamespace getVariable ['QS_VA_holdEH',-1];
 if (_eh >= 0) then {removeMissionEventHandler ['EachFrame',_eh];};
 localNamespace setVariable ['QS_VA_holdEH',-1];
 // Keep the key latched until a KeyUp. After lost focus one press/release rearms safely.
};
if (_mode isEqualTo 'KEY_INIT') exitWith {
 private _display = findDisplay 46;
 if (isNull _display || {(uiNamespace getVariable ['QS_VA_keyDisplay',displayNull]) isEqualTo _display}) exitWith {};
 ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
 ['UI_CLEAR'] call QS_fnc_clientVehicleAccess;
 uiNamespace setVariable ['QS_VA_keyDisplay',_display];
 localNamespace setVariable ['QS_VA_keysDown',[]];
 localNamespace setVariable ['QS_VA_lockTap',[]];
 localNamespace setVariable ['QS_VA_lockPrevious',[]];
 ['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;
 private _downEH = _display displayAddEventHandler ['KeyDown',{['KEY_DOWN',_this] call QS_fnc_clientVehicleAccess}];
 private _upEH = _display displayAddEventHandler ['KeyUp',{['KEY_UP',_this] call QS_fnc_clientVehicleAccess}];
 private _unloadEH = _display displayAddEventHandler ['Unload',{['KEY_CANCEL'] call QS_fnc_clientVehicleAccess; ['UI_CLEAR'] call QS_fnc_clientVehicleAccess;}];
 uiNamespace setVariable ['QS_VA_keyHandlers',[_display,_downEH,_upEH,_unloadEH]];
};
if (_mode isEqualTo 'LOCK_FIRE') exitWith {
 if (!(call _lockContext) || {!([call _inputVehicle,player] call _lockAllowed)}) exitWith {};
 private _bind = profileNamespace getVariable ['QS_VA_lockKey',[35,false,false,false]];
 private _conflicts = ['KEY_CONFLICTS',_bind] call QS_fnc_clientVehicleAccess;
 if (_conflicts isEqualTo []) then {['LOCK_ALL'] call QS_fnc_clientVehicleAccess;} else {systemChat format ['Lock key conflicts with %1. Rebind it in Vehicle Controls.',_conflicts joinString ', '];};
};
if (_mode isEqualTo 'LOCK_HOLD_CLEAR') exitWith {
 localNamespace setVariable ['QS_VA_lockHold',[]];
 private _eh = localNamespace getVariable ['QS_VA_lockHoldEH',-1];
 if (_eh >= 0) then {removeMissionEventHandler ['EachFrame',_eh];};
 localNamespace setVariable ['QS_VA_lockHoldEH',-1];
};
if (_mode isEqualTo 'LOCK_FRAME') exitWith {
 private _hold = localNamespace getVariable ['QS_VA_lockHold',[]];
 if (_hold isEqualTo []) exitWith {['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;};
 _hold params ['_actor','_vehicle','_key','_elapsed','_wall','_sim'];
 private _dw = diag_tickTime - _wall; private _ds = time - _sim;
 if (!(call _lockContext) || {!([_vehicle,player] call _lockAllowed)} || {player isNotEqualTo _actor} || {objectParent player isNotEqualTo _vehicle} || {!(_key in (localNamespace getVariable ['QS_VA_keysDown',[]]))} || {_dw > 0.25} || {_ds < 0} || {_ds > 0.25}) exitWith {['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;};
 _elapsed = _elapsed + ((_dw max 0) min _ds);
 if (_elapsed >= (((call _readControls) # 0) # 3)) exitWith {['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess; ['LOCK_FIRE'] call QS_fnc_clientVehicleAccess;};
 localNamespace setVariable ['QS_VA_lockHold',[_actor,_vehicle,_key,_elapsed,diag_tickTime,time]];
};
if (_mode isEqualTo 'ROPE_HOLD_CLEAR') exitWith {
 localNamespace setVariable ['QS_VA_ropeHold',[]];
 private _eh = localNamespace getVariable ['QS_VA_ropeHoldEH',-1];
 if (_eh >= 0) then {removeMissionEventHandler ['EachFrame',_eh];};
 localNamespace setVariable ['QS_VA_ropeHoldEH',-1];
};
if (_mode isEqualTo 'GESTURE_CLEAR') exitWith {
 localNamespace setVariable ['QS_VA_taps',[]]; localNamespace setVariable ['QS_VA_previousTaps',[]];
 ['ROPE_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;
};
if (_mode isEqualTo 'GESTURE_FIRE') exitWith {
 _a params ['_kind','','_actor','_vehicle','_bind','_epoch','_loads'];
 private _selfRelease = _kind isEqualTo 'ROPE' && {_epoch isEqualTo -2};
 private _authorized = if (_selfRelease) then {[_vehicle,player] call _selfDriverValid} else {[_vehicle,player] call _pilotValid};
 if (!(call _context) || {player isNotEqualTo _actor} || {(call _inputVehicle) isNotEqualTo _vehicle} || {!_authorized}) exitWith {};
 if (_selfRelease && {_loads isNotEqualTo ([_vehicle,player] call _selfSnapshot)}) exitWith {['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;};
 ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
 private _serial = (localNamespace getVariable ['QS_VA_serial',0]) + 1;
 localNamespace setVariable ['QS_VA_serial',_serial];
 if (_kind isEqualTo 'ROPE') then {
  if (_selfRelease) then {
   ['SEND','SELF_RELEASE',_vehicle,[_serial,serverTime,_loads]] call QS_fnc_clientVehicleAccess;
  } else {['SEND','SLING',_vehicle,[_serial,serverTime,_loads,_epoch]] call QS_fnc_clientVehicleAccess;};
 } else {
  ['SEND','ACTIVATE',_vehicle,[_serial,serverTime,if (_kind isEqualTo 'ALL') then {2} else {1}]] call QS_fnc_clientVehicleAccess;
 };
};
if (_mode isEqualTo 'HOLD_START') exitWith {
 _a params ['_kind','','','_vehicle','_bind'];
 if (!(['HOLD_ALLOWED',_vehicle] call QS_fnc_clientVehicleAccess)) exitWith {};
 ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
 private _settings = call _readControls;
 private _plan = if (_kind isEqualTo 'ALL') then {'ALL'} else {if ((_settings # 3) # 2 isEqualTo 'ADDITIONAL') then {'CHAIN'} else {'PASSENGERS'}};
 private _serial = (localNamespace getVariable ['QS_VA_serial',0]) + 1;
 localNamespace setVariable ['QS_VA_serial',_serial];
 localNamespace setVariable ['QS_VA_ejectDown',_bind # 0];
 localNamespace setVariable ['QS_VA_ejectConsumed',true];
 localNamespace setVariable ['QS_VA_localHold',[player,_vehicle,_serial,0,diag_tickTime,diag_tickTime,false]];
 localNamespace setVariable ['QS_VA_clientClock',[time,0,0,diag_frameNo]];
 localNamespace setVariable ['QS_VA_needsInput',false]; localNamespace setVariable ['QS_VA_waitAck',true];
 localNamespace setVariable ['QS_VA_ack',[_serial,-1,0,0,diag_tickTime,-1]];
 ['SEND','BEGIN',_vehicle,[_serial,(_settings # 2) # 3,(_settings # 3) # 3,_plan]] call QS_fnc_clientVehicleAccess;
 localNamespace setVariable ['QS_VA_holdEH',addMissionEventHandler ['EachFrame',{['KEY_FRAME'] call QS_fnc_clientVehicleAccess;}]];
};
if (_mode isEqualTo 'ROPE_FRAME') exitWith {
 private _hold = localNamespace getVariable ['QS_VA_ropeHold',[]];
 if (_hold isEqualTo []) exitWith {['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;};
 _hold params ['_tap','_elapsed','_wall','_sim','_seconds'];
 _tap params ['','','_actor','_vehicle','_bind'];
 private _authorized = if ((_tap # 5) isEqualTo -2) then {
  [_vehicle,player] call _selfDriverValid && {(_tap # 6) isEqualTo ([_vehicle,player] call _selfSnapshot)}
 } else {[_vehicle,player] call _pilotValid};
 private _dw = diag_tickTime - _wall; private _ds = time - _sim;
 if (!(call _context) || {player isNotEqualTo _actor} || {(call _inputVehicle) isNotEqualTo _vehicle} || {!_authorized} || {!((_bind # 0) in (localNamespace getVariable ['QS_VA_keysDown',[]]))} || {_dw > 0.25} || {_ds < 0} || {_ds > 0.25}) exitWith {['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;};
 _elapsed = _elapsed + ((_dw max 0) min _ds);
 if (_elapsed >= _seconds) exitWith {['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess; ['GESTURE_FIRE',_tap] call QS_fnc_clientVehicleAccess;};
 localNamespace setVariable ['QS_VA_ropeHold',[_tap,_elapsed,diag_tickTime,time,_seconds]];
};
if (_mode isEqualTo 'KEY_DOWN') exitWith {
 _a params ['','_key','_shift','_ctrl','_alt'];
 private _keys = localNamespace getVariable ['QS_VA_keysDown',[]];
 private _repeat = _key in _keys;
 _keys pushBackUnique _key; localNamespace setVariable ['QS_VA_keysDown',_keys];
 private _keyBind = [_key,_shift && {!(_key in [42,54])},_ctrl && {!(_key in [29,157])},_alt && {!(_key in [56,184])}];
 private _lockBind = profileNamespace getVariable ['QS_VA_lockKey',[35,false,false,false]];
 private _lockConsumed = false;
 if (_keyBind isEqualTo _lockBind && {!_repeat} && {call _lockContext} && {!isNull objectParent player} && {(call _inputVehicle) isEqualTo objectParent player} && {[objectParent player,player] call _lockAllowed}) then {
   // The event already verifies the modifier chord. Movement keys and stale
   // unrelated entries in the shared key tracker must not suppress locking.
   _lockConsumed = true;
   switch (['INPUT_MODE','LOCK'] call QS_fnc_clientVehicleAccess) do {
    case 'PRESS': {['LOCK_FIRE'] call QS_fnc_clientVehicleAccess;};
    case 'DOUBLE': {localNamespace setVariable ['QS_VA_lockTap',[diag_tickTime,player,objectParent player]];};
    case 'HOLD': {
     ['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;
     ['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;
     localNamespace setVariable ['QS_VA_lockHold',[player,objectParent player,_key,0,diag_tickTime,time]];
     localNamespace setVariable ['QS_VA_lockHoldEH',addMissionEventHandler ['EachFrame',{['LOCK_FRAME'] call QS_fnc_clientVehicleAccess;}]];
    };
   };
 } else {
  if (!_repeat && {_key in [29,157,42,54,56,184]}) then {
   localNamespace setVariable ['QS_VA_lockTap',[]]; localNamespace setVariable ['QS_VA_lockPrevious',[]];
   ['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;
  };
 };
 if (_key isEqualTo (localNamespace getVariable ['QS_VA_ejectDown',-1])) then {localNamespace setVariable ['QS_VA_inputFrame',diag_frameNo];};
 if (!_repeat && {_key in [29,157,42,54,56,184]}) then {
  ['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;
  if (_key isNotEqualTo (localNamespace getVariable ['QS_VA_ejectDown',-1])) then {['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;};
 };
 private _vehicle = call _inputVehicle;
 private _settings = call _readControls;
 private _incoming = ([_vehicle] call _selfCarriers) isNotEqualTo [];
 private _selfAllowed = _incoming && {[_vehicle,player] call _selfDriverValid};
 private _matches = _settings select {
  (_x # 0) isNotEqualTo 'LOCK' && {(_x # 2) isNotEqualTo 'ADDITIONAL'} &&
  {(_x # 1) isEqualTo _keyBind} && {(_x # 0) isNotEqualTo 'ROPE' || {_selfAllowed} || {!_incoming && {[_vehicle] call _hasRopes}}}
 };
 private _consumed = _matches isNotEqualTo [] && {call _context} && {[_vehicle,player] call _pilotValid || {_selfAllowed}};
 if (!_repeat && {_matches isEqualTo []}) then {localNamespace setVariable ['QS_VA_previousTaps',[]];};
 if (!_consumed) exitWith {_lockConsumed || {_repeat && {_keyBind isEqualTo _lockBind} && {call _lockContext} && {(call _inputVehicle) isEqualTo objectParent player} && {[objectParent player,player] call _lockAllowed}}};
 localNamespace setVariable ['QS_VA_consumeUntil',diag_tickTime + 0.2];
 if (_repeat) exitWith {true};
 localNamespace setVariable ['QS_VA_previousTaps',(localNamespace getVariable ['QS_VA_previousTaps',[]]) select {(_x # 4) isEqualTo _keyBind}];
 {
  _x params ['_kind','_bind','_activation','_seconds'];
  private _conflicts = ['KEY_CONFLICTS',_bind,_kind] call QS_fnc_clientVehicleAccess;
  if (_conflicts isEqualTo []) then {
   private _tap = [_kind,diag_tickTime,player,_vehicle,_bind,_vehicle getVariable ['QS_VA_slingEpoch',0],[_vehicle] call _slingCargo];
   if (_kind isEqualTo 'ROPE' && {_incoming}) then {_tap set [5,-2]; _tap set [6,[_vehicle,player] call _selfSnapshot];};
   // Seat ejection does not depend on which sling load is attached.
   if (_kind isNotEqualTo 'ROPE') then {_tap set [5,-1]; _tap set [6,[]];};
   switch _activation do {
    case 'PRESS': {['GESTURE_FIRE',_tap] call QS_fnc_clientVehicleAccess;};
    case 'DOUBLE': {
     private _taps = (localNamespace getVariable ['QS_VA_taps',[]]) select {_x # 0 isNotEqualTo _kind};
     _taps pushBack _tap; localNamespace setVariable ['QS_VA_taps',_taps];
    };
    case 'HOLD': {
     if (_kind isEqualTo 'ROPE') then {
      localNamespace setVariable ['QS_VA_ropeHold',[_tap,0,diag_tickTime,time,_seconds]];
      if ((localNamespace getVariable ['QS_VA_ropeHoldEH',-1]) < 0) then {localNamespace setVariable ['QS_VA_ropeHoldEH',addMissionEventHandler ['EachFrame',{['ROPE_FRAME'] call QS_fnc_clientVehicleAccess;}]];};
     } else {['HOLD_START',_tap] call QS_fnc_clientVehicleAccess;};
    };
   };
  } else {systemChat format ['%1 key conflicts with %2. Change it in Vehicle Controls.',_kind,_conflicts joinString ', '];};
 } forEach _matches;
 true
};
if (_mode isEqualTo 'KEY_UP') exitWith {
 _a params ['','_key'];
 private _keys = localNamespace getVariable ['QS_VA_keysDown',[]];
 localNamespace setVariable ['QS_VA_keysDown',_keys - [_key]];
 private _consumed = false;
 if (_key isEqualTo (localNamespace getVariable ['QS_VA_ejectDown',-1])) then {
  _consumed = localNamespace getVariable ['QS_VA_ejectConsumed',false];
  ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
  localNamespace setVariable ['QS_VA_ejectDown',-1]; localNamespace setVariable ['QS_VA_ejectConsumed',false];
 };
 private _ropeHold = localNamespace getVariable ['QS_VA_ropeHold',[]];
 if (_ropeHold isNotEqualTo [] && {((_ropeHold # 0) # 4) # 0 isEqualTo _key}) then {['ROPE_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess; _consumed=true;};
 private _taps = localNamespace getVariable ['QS_VA_taps',[]];
 private _released = _taps select {(_x # 4) # 0 isEqualTo _key};
 localNamespace setVariable ['QS_VA_taps',_taps - _released];
 {
  private _tap = _x; private _kind = _tap # 0;
  private _previousTaps = localNamespace getVariable ['QS_VA_previousTaps',[]];
  private _index = _previousTaps findIf {_x # 0 isEqualTo _kind};
  private _previous = if (_index >= 0) then {_previousTaps # _index} else {[]};
  _previousTaps = _previousTaps select {_x # 0 isNotEqualTo _kind};
  _consumed=true;
  if (call _context && {player isEqualTo (_tap # 2)} && {(call _inputVehicle) isEqualTo (_tap # 3)} && {diag_tickTime - (_tap # 1) <= 0.3}) then {
   if ([_tap,_previous,diag_tickTime] call _tapPair) then {
    ['GESTURE_FIRE',_tap] call QS_fnc_clientVehicleAccess;
   } else {_tap set [1,diag_tickTime]; _previousTaps pushBack _tap;};
  };
  localNamespace setVariable ['QS_VA_previousTaps',_previousTaps];
 } forEach _released;
 if (_key in [29,157,42,54,56,184]) then {['KEY_CANCEL'] call QS_fnc_clientVehicleAccess; ['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;};
 private _lockBind = profileNamespace getVariable ['QS_VA_lockKey',[35,false,false,false]];
 if (_key isEqualTo (_lockBind # 0) || {_key in [29,157,42,54,56,184]}) then {['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;};
 private _tap = localNamespace getVariable ['QS_VA_lockTap',[]];
 if (_key isEqualTo (_lockBind # 0) && {_tap isNotEqualTo []}) then {
  localNamespace setVariable ['QS_VA_lockTap',[]];
  if (diag_tickTime - (_tap # 0) <= 0.3 && {call _lockContext} && {_tap # 1 isEqualTo player} && {_tap # 2 isEqualTo objectParent player}) then {
   private _previous = localNamespace getVariable ['QS_VA_lockPrevious',[]];
   if (_previous isNotEqualTo [] && {diag_tickTime - (_previous # 0) <= 0.4} && {_previous # 1 isEqualTo player} && {_previous # 2 isEqualTo objectParent player}) then {
    localNamespace setVariable ['QS_VA_lockPrevious',[]]; ['LOCK_FIRE'] call QS_fnc_clientVehicleAccess;
   } else {localNamespace setVariable ['QS_VA_lockPrevious',[diag_tickTime,player,objectParent player]];};
  } else {localNamespace setVariable ['QS_VA_lockPrevious',[]];};
 };
 _consumed
};
if (_mode isEqualTo 'KEY_FRAME') exitWith {
 private _hold = localNamespace getVariable ['QS_VA_localHold',[]];
 if (_hold isEqualTo []) exitWith {['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;};
 _hold params ['_pilot','_vehicle','_serial','_pressed','_frame','_sent'];
 private _state = _vehicle getVariable ['QS_VA_eject',[]];
 private _matched = count _state isEqualTo 16 && {_state # 2 isEqualTo _serial} && {_state # 3 isEqualTo _pilot};
 if (_matched && {(_state # 1) in ['COMPLETE','ABORT','PASSENGERS']}) exitWith {['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;};
 if (!_matched && {count _state isEqualTo 16} && {(_state # 1) in ['HOLD','PAUSED']}) exitWith {['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;};
 if (!_matched && {_pressed > 5}) exitWith {['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;};
 if (player isNotEqualTo _pilot || {_pressed > 120} || {!(['HOLD_ALLOWED',_vehicle] call QS_fnc_clientVehicleAccess)} || {(localNamespace getVariable ['QS_VA_ejectDown',-1]) < 0}) exitWith {['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;};
 private _clock = localNamespace getVariable ['QS_VA_clientClock',[time,0,0,diag_frameNo]];
 _clock params ['_sim','_credit','_steady','_pauseFrame'];
 private _dw = diag_tickTime - _frame; private _ds = time - _sim;
 private _healthy = _dw >= 0 && {_dw <= 0.25} && {_ds >= 0} && {_ds <= 0.25} && {simulationEnabled player};
 if (!_healthy) then {
  _credit=0; _steady=0; _pauseFrame=diag_frameNo;
  localNamespace setVariable ['QS_VA_needsInput',true];
 } else {
  _steady = _steady + (_dw min _ds);
  _hold set [3,_pressed + (_dw min _ds)]; // cleanup age excludes frozen frames
 };
 private _needsInput = localNamespace getVariable ['QS_VA_needsInput',false];
 // Ignore buffered key repeats in the recovery frames. A fresh repeat after
 // simulation stabilizes proves continued input; KeyUp always cancels.
 if (_needsInput && {_steady >= 0.25} && {(localNamespace getVariable ['QS_VA_inputFrame',-1]) > _pauseFrame + 2} && {(localNamespace getVariable ['QS_VA_inputFrame',-1]) >= diag_frameNo - 1}) then {
  _needsInput=false; localNamespace setVariable ['QS_VA_needsInput',false];
 };
 private _ack = localNamespace getVariable ['QS_VA_ack',[_serial,-1,0,0,0,-1]];
 private _fresh = diag_tickTime - (_ack # 4) <= 1.25;
 private _ready = _healthy && {_ds > 0} && {_steady >= 0.25} && {!_needsInput} && {_fresh};
 if (_ready) then {_credit = (_credit + (_dw min _ds)) min 0.25;} else {_credit=0;};
 private _waiting = localNamespace getVariable ['QS_VA_waitAck',true];
 private _request = [];
 if (diag_tickTime - _sent > 1.25) then {
  _request = ['SEND','SYNC',_vehicle,[_serial,-1,0,false]];
 } else {
  if (!_waiting && {diag_frameNo > (_ack # 5) + 1} && {diag_tickTime - _sent >= 0.1}) then {
   private _target = [_ack param [6,3],_ack param [8,3],_ack param [7,0]] call _stageTarget;
   private _op = if (_ready && {_ack # 2 >= _target}) then {'CONFIRM'} else {'BEAT'};
   _request = ['SEND',_op,_vehicle,[_serial,_ack # 1,_credit,_ready]];
  };
 };
 if (_request isNotEqualTo []) then {
  _hold set [5,diag_tickTime]; localNamespace setVariable ['QS_VA_waitAck',true]; _credit=0;
 };
 _hold set [4,diag_tickTime];
 localNamespace setVariable ['QS_VA_localHold',_hold];
 localNamespace setVariable ['QS_VA_clientClock',[time,_credit,_steady,_pauseFrame]];
 // Final operation: never overwrite an immediate acknowledgement after sending.
 if (_request isNotEqualTo []) then {_request call QS_fnc_clientVehicleAccess;};
};

if (_mode isEqualTo 'INIT') exitWith {
 // Apply the H-binding migration once; later custom edits persist.
 if (!(profileNamespace getVariable ['QS_VA54_H_toggle',false])) then {
  profileNamespace setVariable ['QS_VA_lockKey',[35,false,false,false]];
  profileNamespace setVariable ['QS_VA5_lockMode','PRESS'];
  if ((profileNamespace getVariable ['QS_vehicleAccess_ejectKey',[57,false,false,false]]) isEqualTo [35,false,false,false]) then {profileNamespace setVariable ['QS_vehicleAccess_ejectKey',[57,false,false,false]];};
  profileNamespace setVariable ['QS_VA54_H_toggle',true]; saveProfileNamespace;
 };
 if (!(profileNamespace getVariable ['QS_VA546_defaults',false])) then {
  if ((profileNamespace getVariable ['QS_VA5_ejectSeconds',3]) isEqualTo 5) then {profileNamespace setVariable ['QS_VA5_ejectSeconds',3];};
  profileNamespace setVariable ['QS_VA546_defaults',true]; saveProfileNamespace;
 };
 ['KEY_INIT'] call QS_fnc_clientVehicleAccess;
 private _loop = missionNamespace getVariable ['QS_VA_clientLoop',scriptNull];
 if (!scriptDone _loop) exitWith {};
 missionNamespace setVariable ['QS_VA_clientLoop',[] spawn {
  while {true} do {
   if (!isNull player && {!isNull findDisplay 46}) then {
    ['KEY_INIT'] call QS_fnc_clientVehicleAccess;
    private _vehicle = ['INPUT_VEHICLE'] call QS_fnc_clientVehicleAccess;
    if (player isNotEqualTo (localNamespace getVariable ['QS_VA_seenPlayer',objNull]) || {_vehicle isNotEqualTo (localNamespace getVariable ['QS_VA_seenVehicle',objNull])}) then {
     ['ACTIONS',_vehicle] call QS_fnc_clientVehicleAccess;
    };
    if (!isGameFocused || {isGamePaused} || {userInputDisabled} || {dialog} || {visibleMap} || {!isNull displayChild findDisplay 46}) then {
     ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
     ['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;
     ['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;
     localNamespace setVariable ['QS_VA_lockTap',[]];localNamespace setVariable ['QS_VA_lockPrevious',[]];
    };
    private _noticeVehicle = ['NOTICE_VEHICLE'] call QS_fnc_clientVehicleAccess;
    if (!isNull _noticeVehicle) then {
     private _vehicle = _noticeVehicle;
     private _state = _vehicle getVariable ['QS_VA_eject',[]];
     if (_state isNotEqualTo []) then {
      private _ui = localNamespace getVariable ['QS_VA_ui',[]];
      // JIP can join an active hold. Terminal snapshots never start a new notification.
      if ((_state # 1) in ['HOLD','PAUSED'] || {_ui isNotEqualTo [] && {_ui # 0 isEqualTo _vehicle} && {((_ui # 1) # 2) isEqualTo (_state # 2)}}) then {
       ['UI_STATE',_vehicle,_state,false] call QS_fnc_clientVehicleAccess;
      };
     };
    };
    if (!isNull (uiNamespace getVariable ['QS_vehicleAccess_display',displayNull])) then {['REFRESH'] call QS_fnc_clientVehicleAccess;};
   };
   uiSleep 0.1;
  };
 }];
};
if (_mode isEqualTo 'REMOVE_ACTIONS') exitWith {
 private _holder = localNamespace getVariable ['QS_vehicleAccess_actionOwner',player];
 {if (!isNull _holder) then {_holder removeAction _x;};} forEach (localNamespace getVariable ['QS_vehicleAccess_actions',[]]);
 localNamespace setVariable ['QS_vehicleAccess_actions',[]];
 private _claim = localNamespace getVariable ['QS_VA_groundClaim',[]];
 if (_claim isNotEqualTo [] && {!isNull (_claim # 0)}) then {(_claim # 0) removeAction (_claim # 1);};
 localNamespace setVariable ['QS_VA_groundClaim',[]];
 ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
 ['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;
 localNamespace setVariable ['QS_VA_lockTap',[]];localNamespace setVariable ['QS_VA_lockPrevious',[]];
};
if (_mode isEqualTo 'ACTIONS') exitWith {
 ['REMOVE_ACTIONS'] call QS_fnc_clientVehicleAccess;
 private _vehicle = call _inputVehicle;
 localNamespace setVariable ['QS_VA_seenPlayer',player]; localNamespace setVariable ['QS_VA_seenVehicle',_vehicle];
 ['INIT'] call QS_fnc_clientVehicleAccess;
 private _claim = player addAction ['Take Ownership',{
  ['SEND','CLAIM_UGV',cursorObject,[]] call QS_fnc_clientVehicleAccess;
 },nil,5.1,false,true,'','[''GROUND_CLAIM_ALLOWED'',cursorObject,player] call QS_fnc_clientVehicleAccess',6];
 localNamespace setVariable ['QS_VA_groundClaim',[player,_claim]];
 private _titles = missionNamespace getVariable ['QS_client_dynamicActionText',[]];
 _titles pushBackUnique 'Take Ownership'; missionNamespace setVariable ['QS_client_dynamicActionText',_titles];
 if (isNull _vehicle) exitWith {};
 ['SEND','HELLO',_vehicle,[]] call QS_fnc_clientVehicleAccess;
 private _holder = if (unitIsUAV _vehicle) then {_vehicle} else {player}; private _actions = [];
 if (!unitIsUAV _vehicle) then {
  _actions pushBack (_holder addAction ['Take Ownership',{
   ['SEND','CLAIM',objectParent player,[]] call QS_fnc_clientVehicleAccess;
  },nil,5.1,false,true,'','private _v=objectParent player; !isNull _v && {!unitIsUAV _v} && {player isEqualTo driver _v} && {(([''ACCESS'',_v] call QS_fnc_clientVehicleAccess) # 1) isEqualTo ''''}']);
 };
 localNamespace setVariable ['QS_vehicleAccess_actionOwner',_holder]; localNamespace setVariable ['QS_vehicleAccess_actions',_actions];
 {_titles pushBackUnique ((_holder actionParams _x) # 0);} forEach _actions;
 missionNamespace setVariable ['QS_client_dynamicActionText',_titles];
};

if (_mode isEqualTo 'LOAD') exitWith {
 private _display = _a;
 ['TRACK_DISPLAY',_display] call QS_fnc_clientVehicleAccess;
 uiNamespace setVariable ['QS_vehicleAccess_display',_display];
 // Replace obsolete dialog buttons, including both immediate-eject callbacks.
 {ctrlDelete _x;} forEach (allControls _display);
 private _x = safeZoneX + safeZoneW * 0.35;
 private _y = safeZoneY + safeZoneH * 0.19;
 private _w = safeZoneW * 0.30;
 private _h = safeZoneH * 0.62;
 private _back = _display ctrlCreate ['RscText',42010];
 _back ctrlSetPosition [_x,_y,_w,_h];_back ctrlSetBackgroundColor [0.025,0.03,0.04,0.98];_back ctrlCommit 0;
 private _title = _display ctrlCreate ['RscText',42011];
 _title ctrlSetPosition [_x + _w * 0.05,_y + _h * 0.025,_w * 0.90,_h * 0.065];_title ctrlSetText 'VEHICLE ACCESS';_title ctrlCommit 0;
 {
  private _control = _display ctrlCreate ['RscButton',_x];
  _control ctrlSetPosition [safeZoneX + safeZoneW * 0.365,_y + _h * (0.115 + _forEachIndex * 0.10),_w * 0.90,_h * 0.075];
  _control ctrlSetFontHeight (0.028 * safeZoneH);
  _control ctrlCommit 0;
  _control ctrlAddEventHandler ['ButtonClick',{
   params ['_control'];
   switch (ctrlIDC _control) do {
    case 42012: {['TOGGLE','driver'] call QS_fnc_clientVehicleAccess;};
    case 42013: {['TOGGLE','gunner'] call QS_fnc_clientVehicleAccess;};
    case 42014: {['TOGGLE','commander'] call QS_fnc_clientVehicleAccess;};
    case 42015: {['TOGGLE','passenger'] call QS_fnc_clientVehicleAccess;};
    case 42016: {['SETTINGS'] call QS_fnc_clientVehicleAccess;};
    case 42017: {['LOCK_ALL'] call QS_fnc_clientVehicleAccess;};
    case 42019: {['DESPAWN_CONFIRM'] call QS_fnc_clientVehicleAccess;};
    case 42018: {closeDialog 2;};
   };
  }];
 } forEach [42012,42013,42014,42015,42016,42017,42019,42018];
 ['REFRESH'] call QS_fnc_clientVehicleAccess;
};
if (_mode isEqualTo 'INPUT_RESET') exitWith {
 ['LOCK_HOLD_CLEAR'] call QS_fnc_clientVehicleAccess;
 ['GESTURE_CLEAR'] call QS_fnc_clientVehicleAccess;
 ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
 localNamespace setVariable ['QS_VA_lockTap',[]]; localNamespace setVariable ['QS_VA_lockPrevious',[]];
 private _key = (profileNamespace getVariable ['QS_vehicleAccess_ejectKey',[57,false,false,false]]) # 0;
 private _down = if (_a isEqualType 0 && {_a >= 0}) then {_a} else {if (_key in (localNamespace getVariable ['QS_VA_keysDown',[]])) then {_key} else {-1}};
 localNamespace setVariable ['QS_VA_ejectDown',_down]; localNamespace setVariable ['QS_VA_ejectConsumed',false];
};
if (_mode isEqualTo 'OPEN') exitWith {
 ['INPUT_RESET'] call QS_fnc_clientVehicleAccess;
 uiNamespace setVariable ['QS_vehicleAccess_vehicle',call _inputVehicle];
 createDialog 'QS_RD_client_dialog_vehicle_access';
};
if (_mode isEqualTo 'MAIN_BUTTON') exitWith {
 disableSerialization;
 private _display = _a;
 ['TRACK_DISPLAY',_display] call QS_fnc_clientVehicleAccess;
 if (isNull _display || {!isNull (_display displayCtrl 1611)}) exitWith {};
 private _last = _display displayCtrl 1610;
 if (isNull _last) exitWith {};
 private _position = ctrlPosition _last;
 private _shift = 0.0375 * safeZoneH;
 {
  if ((ctrlIDC _x) isNotEqualTo 1604) then {
   private _pos = ctrlPosition _x; _pos set [1,(_pos # 1) - _shift];
   if ((ctrlIDC _x) in [1800,1801]) then {_pos set [3,(_pos # 3) + _shift];};
   _x ctrlSetPosition _pos; _x ctrlCommit 0;
  };
 } forEach allControls _display;
 private _button = _display ctrlCreate ['RscButton',1611];
 _button ctrlSetPosition _position; _button ctrlSetText 'Vehicle Access'; _button ctrlCommit 0;
 _button ctrlAddEventHandler ['ButtonClick',{
  [ctrlParent (_this # 0)] spawn {
   disableSerialization; params ['_display']; _display closeDisplay 2;
   uiSleep 0.15; waitUntil {!dialog}; ['OPEN'] call QS_fnc_clientVehicleAccess;
  };
 }];
};
if (_mode isEqualTo 'RESTORE') exitWith {
 private _draft = uiNamespace getVariable ['QS_VA_controlDraft',call _readControls];
 if (_a isEqualTo 'DEFAULTS') then {_draft = _controlDefaults apply {+_x};} else {
  private _index = [_a] call _controlIndex; if (_index >= 0) then {_draft set [_index,+(_controlDefaults # _index)];};
 };
 uiNamespace setVariable ['QS_VA_controlDraft',_draft];
 ['SETTINGS_REFRESH'] call QS_fnc_clientVehicleAccess;
};
if (_mode in ['SETTINGS','EDIT']) exitWith {
 disableSerialization; ['INPUT_RESET'] call QS_fnc_clientVehicleAccess;
 private _parent = uiNamespace getVariable ['QS_vehicleAccess_display',displayNull];
 if (isNull _parent) exitWith {};
 private _display = _parent createDisplay 'RscDisplayEmpty';
 ['TRACK_DISPLAY',_display] call QS_fnc_clientVehicleAccess;
 uiNamespace setVariable ['QS_VA_editDisplay',_display];
 uiNamespace setVariable ['QS_VA_controlDraft',call _readControls];
 _display displayAddEventHandler ['Unload',{
  uiNamespace setVariable ['QS_VA_editDisplay',displayNull]; uiNamespace setVariable ['QS_VA_controlDraft',nil];
  ['INPUT_RESET'] call QS_fnc_clientVehicleAccess;
 }];
 private _make = {
  params ['_class','_id','_pos','_text']; private _control = _display ctrlCreate [_class,_id];
  _control ctrlSetPosition _pos; _control ctrlSetText _text; _control ctrlCommit 0; _control
 };
 private _back = ['RscText',-1,[0.01,0.03,0.98,0.94],''] call _make; _back ctrlSetBackgroundColor [0.02,0.025,0.03,0.98];
 ['RscText',-1,[0.04,0.055,0.90,0.06],'Vehicle Controls'] call _make;
 {['RscText',-1,[_x # 1,0.13,_x # 2,0.04],_x # 0] call _make;} forEach [['Action',0.04,0.26],['Button',0.31,0.18],['Activation',0.51,0.27],['Seconds',0.81,0.13]];
 {
  _x params ['_kind','_label']; private _row = _forEachIndex; private _id=42110 + 10 * _row; private _y=0.19 + 0.12 * _row;
  ['RscText',-1,[0.04,_y,0.26,0.06],_label] call _make;
  private _key = ['RscButton',_id,[0.31,_y,0.18,0.055],''] call _make;
  _key setVariable ['QS_VA_bindKind',_kind];
  _key ctrlAddEventHandler ['ButtonClick',{['SETTINGS_CAPTURE'] call QS_fnc_clientVehicleAccess; ['BIND',(_this # 0) getVariable 'QS_VA_bindKind'] call QS_fnc_clientVehicleAccess;}];
  private _combo = ['RscCombo',_id+1,[0.51,_y,0.27,0.055],''] call _make;
  {_combo lbAdd _x;} forEach (if (_kind isEqualTo 'ALL') then {['Single press','Double tap','Hold','Additional hold']} else {['Single press','Double tap','Hold']});
  _combo ctrlAddEventHandler ['LBSelChanged',{['SETTINGS_CAPTURE'] call QS_fnc_clientVehicleAccess; ['SETTINGS_HINT'] call QS_fnc_clientVehicleAccess;}];
  ['RscEdit',_id+2,[0.81,_y,0.13,0.055],''] call _make;
  private _reset = ['RscButton',_id+3,[0.31,_y+0.06,0.18,0.035],'Default'] call _make;
  _reset setVariable ['QS_VA_restoreKind',_kind];
  _reset ctrlAddEventHandler ['ButtonClick',{['SETTINGS_CAPTURE'] call QS_fnc_clientVehicleAccess; ['RESTORE',(_this # 0) getVariable 'QS_VA_restoreKind'] call QS_fnc_clientVehicleAccess;}];
 } forEach [['LOCK','Lock / unlock'],['ROPE','Cut ropes'],['EJECT','Passengers / cargo'],['ALL','Eject All']];
 ['RscStructuredText',42107,[0.04,0.68,0.90,0.14],''] call _make;
 private _defaults = ['RscButton',-1,[0.04,0.85,0.27,0.065],'Restore defaults'] call _make;
 _defaults ctrlAddEventHandler ['ButtonClick',{['RESTORE','DEFAULTS'] call QS_fnc_clientVehicleAccess;}];
 private _save = ['RscButton',42108,[0.36,0.85,0.27,0.065],'Save & Close'] call _make;
 _save ctrlAddEventHandler ['ButtonClick',{['SETTINGS_SAVE'] call QS_fnc_clientVehicleAccess;}];
 private _backButton = ['RscButton',2,[0.68,0.85,0.26,0.065],'Cancel'] call _make;
 _backButton ctrlAddEventHandler ['ButtonClick',{(ctrlParent (_this # 0)) closeDisplay 2;}];
 ['SETTINGS_REFRESH'] call QS_fnc_clientVehicleAccess;
};
if (_mode isEqualTo 'SETTINGS_CAPTURE') exitWith {
 if (uiNamespace getVariable ['QS_VA_refreshing',false]) exitWith {};
 private _display = uiNamespace getVariable ['QS_VA_editDisplay',displayNull]; if (isNull _display) exitWith {};
 private _draft = uiNamespace getVariable ['QS_VA_controlDraft',call _readControls];
 {
  private _id=42110 + 10 * _forEachIndex;
  _x set [2,['PRESS','DOUBLE','HOLD','ADDITIONAL'] # ((lbCurSel (_display displayCtrl (_id+1))) max 0)];
  _x set [3,parseNumber ctrlText (_display displayCtrl (_id+2))];
 } forEach _draft;
 uiNamespace setVariable ['QS_VA_controlDraft',_draft];
};
if (_mode in ['SETTINGS_REFRESH','EDIT_REFRESH']) exitWith {
 private _display = uiNamespace getVariable ['QS_VA_editDisplay',displayNull]; if (isNull _display) exitWith {};
 uiNamespace setVariable ['QS_VA_refreshing',true];
 {
  private _id=42110 + 10 * _forEachIndex;
  (_display displayCtrl _id) ctrlSetText (['KEY_LABEL',_x # 0,_x # 1] call QS_fnc_clientVehicleAccess);
  (_display displayCtrl (_id+1)) lbSetCurSel (['PRESS','DOUBLE','HOLD','ADDITIONAL'] find (_x # 2));
  (_display displayCtrl (_id+2)) ctrlSetText str (_x # 3);
 } forEach (uiNamespace getVariable ['QS_VA_controlDraft',call _readControls]);
 uiNamespace setVariable ['QS_VA_refreshing',false];
 ['SETTINGS_HINT'] call QS_fnc_clientVehicleAccess;
};
if (_mode isEqualTo 'SETTINGS_HINT') exitWith {
 private _display = uiNamespace getVariable ['QS_VA_editDisplay',displayNull]; if (isNull _display) exitWith {};
 private _draft=uiNamespace getVariable ['QS_VA_controlDraft',call _readControls];
 private _additional=(_draft # 3) # 2 isEqualTo 'ADDITIONAL';
 (_display displayCtrl 42140) ctrlEnable (!_additional);
 (_display displayCtrl 42140) ctrlSetText (if (_additional) then {'Same as passengers'} else {['KEY_LABEL','ALL',(_draft # 3) # 1] call QS_fnc_clientVehicleAccess});
 {(_display displayCtrl (42112 + 10 * _forEachIndex)) ctrlEnable ((_x # 2) in ['HOLD','ADDITIONAL']);} forEach _draft;
 (_display displayCtrl 42107) ctrlSetStructuredText parseText 'Defaults: H once locks; Space double-tap cuts ropes (own incoming ropes when carried); hold 3 s ejects passengers/cargo, then 3 s more ejects All. Additional hold uses the passengers key. Other activations use their own button. Pilot stays aboard.';
};
if (_mode isEqualTo 'SETTINGS_VALIDATE') exitWith {
 private _draft=_a; private _error='';
 {
  _x params ['_kind','_bind','_activation','_seconds'];
  private _min=if (_kind isEqualTo 'LOCK') then {0.25} else {1};
  if (!finite _seconds || {_seconds < _min} || {_seconds > 5}) exitWith {_error=format ['%1: hold seconds must be %2-5.',_kind,_min];};
  private _conflicts=['KEY_CONFLICTS',_bind,_kind] call QS_fnc_clientVehicleAccess;
  if (_activation isNotEqualTo 'ADDITIONAL' && {_conflicts isNotEqualTo []}) exitWith {_error=format ['%1 key conflicts with %2.',_kind,_conflicts joinString ', '];};
  private _row=_forEachIndex;
  {
   if (_forEachIndex > _row && {_activation isNotEqualTo 'ADDITIONAL'} && {_x # 2 isNotEqualTo 'ADDITIONAL'} && {_x # 1 isEqualTo _bind}) then {
    if (_activation isEqualTo (_x # 2) || {'PRESS' in [_activation,_x # 2]} || {_activation isEqualTo 'HOLD' && {_seconds <= 0.3}} || {_x # 2 isEqualTo 'HOLD' && {_x # 3 <= 0.3}}) then {_error='Shared buttons need distinct double-tap/hold actions, with holds longer than 0.3 s. Use another button or Additional hold for All.';};
   };
  } forEach _draft;
 } forEach _draft;
 if ((_draft # 3) # 2 isEqualTo 'ADDITIONAL' && {(_draft # 2) # 2 isNotEqualTo 'HOLD'}) then {_error='Additional hold requires Passengers / cargo to use Hold. Otherwise select a separate Eject All activation.';};
 _error
};
if (_mode isEqualTo 'SETTINGS_SAVE') exitWith {
 private _display = uiNamespace getVariable ['QS_VA_editDisplay',displayNull]; if (isNull _display) exitWith {};
 ['SETTINGS_CAPTURE'] call QS_fnc_clientVehicleAccess;
 private _draft=uiNamespace getVariable ['QS_VA_controlDraft',call _readControls];
 private _error=['SETTINGS_VALIDATE',_draft] call QS_fnc_clientVehicleAccess;
 if (_error isNotEqualTo '') exitWith {(_display displayCtrl 42107) ctrlSetStructuredText parseText _error;};
 {
  private _vars=_controlVars # _forEachIndex;
  profileNamespace setVariable [_vars # 0,_x # 1]; profileNamespace setVariable [_vars # 1,_x # 2]; profileNamespace setVariable [_vars # 2,_x # 3];
 } forEach _draft;
 saveProfileNamespace; ['INPUT_RESET'] call QS_fnc_clientVehicleAccess; _display closeDisplay 2;
};

if (_mode isEqualTo 'DESPAWN_CONFIRM') exitWith {
 disableSerialization;
 ['INPUT_RESET'] call QS_fnc_clientVehicleAccess;
 private _parent = uiNamespace getVariable ['QS_vehicleAccess_display',displayNull];
 if (isNull _parent) exitWith {};
 private _display = _parent createDisplay 'RscDisplayEmpty';
 ['TRACK_DISPLAY',_display] call QS_fnc_clientVehicleAccess;
 private _back = _display ctrlCreate ['RscText',-1];
 _back ctrlSetPosition [0.14,0.27,0.72,0.46]; _back ctrlSetBackgroundColor [0.02,0.025,0.03,0.98]; _back ctrlCommit 0;
 private _text = _display ctrlCreate ['RscStructuredText',-1];
 _text ctrlSetPosition [0.18,0.30,0.64,0.27];
 _text ctrlSetStructuredText parseText '<t size="1.15">Despawn all your owned vehicles?</t><br/><br/>Their allowance slots become available. Empty them, unload cargo, detach ropes and disconnect UAV terminals first.'; _text ctrlCommit 0;
 private _button = _display ctrlCreate ['RscButton',-1];
 _button ctrlSetPosition [0.18,0.62,0.30,0.06]; _button ctrlSetText 'Despawn Vehicles'; _button ctrlCommit 0;
 _button ctrlAddEventHandler ['ButtonClick',{
  ['SEND','DESPAWN',objNull,[]] call QS_fnc_clientVehicleAccess; (ctrlParent (_this # 0)) closeDisplay 2;
 }];
 private _cancel = _display ctrlCreate ['RscButton',2];
 _cancel ctrlSetPosition [0.52,0.62,0.30,0.06]; _cancel ctrlSetText 'Cancel'; _cancel ctrlCommit 0;
 _cancel ctrlAddEventHandler ['ButtonClick',{(ctrlParent (_this # 0)) closeDisplay 2;}];
};

if (_mode in ['EJECT','EJECT_HELP','KEY_BIND','BIND']) exitWith {
 ['KEY_CANCEL'] call QS_fnc_clientVehicleAccess;
 private _kind = if (_mode isEqualTo 'BIND') then {_a} else {'EJECT'};
 private _parent = uiNamespace getVariable ['QS_VA_editDisplay',displayNull];
 if (isNull _parent) then {_parent = uiNamespace getVariable ['QS_vehicleAccess_display',findDisplay 46];};
 private _display = _parent createDisplay 'RscDisplayEmpty';
 ['TRACK_DISPLAY',_display] call QS_fnc_clientVehicleAccess;
 _display setVariable ['QS_VA_bindKind',_kind];
 _display displayAddEventHandler ['Unload',{params ['_display']; ['INPUT_RESET',_display getVariable ['QS_VA_releaseKey',-1]] call QS_fnc_clientVehicleAccess;}];
 private _text = _display ctrlCreate ['RscStructuredText',-1];
 _text ctrlSetPosition [0.12,0.27,0.76,0.47];_text ctrlSetBackgroundColor [0.02,0.025,0.03,0.98];
 _text ctrlSetStructuredText parseText format ["<t size='1.25'>%1 key</t><br/><br/>Current: %2<br/>Press a key, optionally with Ctrl, Shift or Alt.<br/>For a Shift-only lock key, tap and release Shift.<br/>Backspace: restore default. Escape: cancel.<br/><br/>Known flight/control conflicts are rejected.<br/>Custom mod bindings must also be checked in your mod controls.",_kind,['KEY_LABEL',_kind,((uiNamespace getVariable ['QS_VA_controlDraft',call _readControls]) # ([_kind] call _controlIndex)) # 1] call QS_fnc_clientVehicleAccess];
 _text ctrlCommit 0;
 _display displayAddEventHandler ['KeyDown',{
  params ['_display','_key','_shift','_ctrl','_alt'];
  if (_key isEqualTo 1) exitWith {_display closeDisplay 2;true};
  if (_key in [29,157,42,54,56,184]) exitWith {true};
  private _kind = _display getVariable ['QS_VA_bindKind','EJECT'];
  private _bind = if (_key isEqualTo 14) then {if (_kind isEqualTo 'LOCK') then {[35,false,false,false]} else {[57,false,false,false]}} else {[_key,_shift,_ctrl,_alt]};
  _display setVariable ['QS_VA_releaseKey',_key];
  ['BIND_SAVE',_display,_bind] call QS_fnc_clientVehicleAccess;
  true
 }];
 _display displayAddEventHandler ['KeyUp',{
  params ['_display','_key','_shift','_ctrl','_alt'];
  if (_key in [42,54,29,157,56,184]) then {
   ['BIND_SAVE',_display,[_key,_shift && {!(_key in [42,54])},_ctrl && {!(_key in [29,157])},_alt && {!(_key in [56,184])}]] call QS_fnc_clientVehicleAccess;
  };
  true
 }];
};
if (_mode isEqualTo 'BIND_SAVE') exitWith {
 private _kind = _a getVariable ['QS_VA_bindKind','EJECT'];
 private _conflicts = ['KEY_CONFLICTS',_b,_kind] call QS_fnc_clientVehicleAccess;
 if (_conflicts isNotEqualTo []) exitWith {systemChat format ['Key conflicts with %1. Choose another key.',_conflicts joinString ', '];};
 private _draft = uiNamespace getVariable ['QS_VA_controlDraft',call _readControls];
 (_draft # ([_kind] call _controlIndex)) set [1,+_b]; uiNamespace setVariable ['QS_VA_controlDraft',_draft];
 private _keys = localNamespace getVariable ['QS_VA_keysDown',[]]; private _releaseKey = _a getVariable ['QS_VA_releaseKey',-1];
 if (_releaseKey >= 0) then {_keys pushBackUnique _releaseKey;}; localNamespace setVariable ['QS_VA_keysDown',_keys];
 _a closeDisplay 2; ['SETTINGS_REFRESH'] call QS_fnc_clientVehicleAccess;
};

if (_mode in ['REFRESH','TOGGLE','LOCK_ALL']) exitWith {
 private _vehicle = call _inputVehicle;
 private _display = uiNamespace getVariable ['QS_vehicleAccess_display',displayNull];
 if (_mode isNotEqualTo 'REFRESH' && {isNull _vehicle || {!alive _vehicle}}) exitWith {};
 private _state = [_vehicle] call _access;
 private _owner = _state # 1;
 private _canChange = [_vehicle,player] call _lockAllowed;
 if (_mode isEqualTo 'LOCK_ALL') exitWith {
  if (!_canChange) exitWith {systemChat 'Only the current owner in the driver/pilot seat can change locks. Unclaimed drivers may take ownership.';};
  ['SEND','LOCK_ALL',_vehicle,[_state # 0,false in (_state # 2)]] call QS_fnc_clientVehicleAccess;
 };
 if (_mode isEqualTo 'TOGGLE') exitWith {
  private _index = _groups find _a;
  if (_canChange && {_index >= 0}) then {['SEND','LOCK_GROUP',_vehicle,[_state # 0,_a,!((_state # 2) # _index)]] call QS_fnc_clientVehicleAccess;};
 };
 if (isNull _display) exitWith {};
 {
  private _control = _display displayCtrl (42012 + _forEachIndex);
  private _group = _x;
  private _exists = ((fullCrew [_vehicle,'',true]) findIf {([_vehicle,_x] call _seatGroup) isEqualTo _group}) >= 0;
  _control ctrlEnable (_exists && _canChange);
  _control ctrlSetText format ['%1: %2',['Pilot / copilot','Gunners','Commander','Passengers'] # _forEachIndex,['Unlocked','LOCKED'] select ((_state # 2) # _forEachIndex)];
 } forEach _groups;
 (_display displayCtrl 42016) ctrlSetText 'Vehicle Controls';
 (_display displayCtrl 42016) ctrlEnable true;
 private _allLocked = !(false in (_state # 2));
 (_display displayCtrl 42017) ctrlSetText (['LOCK VEHICLE','UNLOCK VEHICLE'] select _allLocked);
 (_display displayCtrl 42017) ctrlEnable _canChange;
 (_display displayCtrl 42017) ctrlSetTooltip 'Fresh vehicles are unlocked. Lock changes do not eject current occupants. First use claims an unowned vehicle. Owner disconnect releases these locks.';
 (_display displayCtrl 42019) ctrlSetText 'Despawn Vehicles';
 (_display displayCtrl 42019) ctrlEnable true;
 (_display displayCtrl 42018) ctrlSetText 'Close';
};
