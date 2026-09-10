// Called only by the fixture's independent local server loop, not as an RPC.
params ['_mode','_unit','_sequence'];
if (!isServer || {isRemoteExecuted}) exitWith {};
if (_mode in ['ART_SETUP_FO','ART_SETUP_JTAC','ART_REJOIN','ART_DUPLICATE_ROLE']) then {
    private _role = ['jtac','forward_observer'] select (_mode isEqualTo 'ART_SETUP_FO');
    private _registry = [[[_role],[[getPlayerUID _unit]]]];
    if (_mode isEqualTo 'ART_SETUP_FO') then {_registry pushBack [['jtac'],[]];};
    if (_mode isEqualTo 'ART_DUPLICATE_ROLE') then {_registry pushBack [['jtac_WL'],[[getPlayerUID _unit]]];};
    _unit setVariable ['QS_unit_role',_role,TRUE];
    missionNamespace setVariable ['QS_unit_roles',[[],_registry,[],[]]];
};
if (_mode isEqualTo 'ART_SETUP_FO') then {
    missionNamespace setVariable ['QS_classic_AI_active',TRUE];
    missionNamespace setVariable ['QS_defendActive',FALSE];
    ['START','PRIMARY','support-a'] call QS_fnc_artillerySupport;
};
if (_mode isEqualTo 'ART_SETUP_JTAC') then {['START','PRIMARY','support-jtac'] call QS_fnc_artillerySupport;};
if (_mode isEqualTo 'ART_REPEAT') then {['START','PRIMARY','support-a'] call QS_fnc_artillerySupport;};
if (_mode isEqualTo 'ART_NEXT') then {['START','PRIMARY','support-b'] call QS_fnc_artillerySupport;};
if (_mode isEqualTo 'ART_STALE_END') then {['END','PRIMARY','support-a'] call QS_fnc_artillerySupport;};
if (_mode isEqualTo 'ART_END') then {['END','PRIMARY','support-b'] call QS_fnc_artillerySupport;};
if (_mode isEqualTo 'ART_LEAVE') then {
    _unit setVariable ['QS_unit_role','rifleman',TRUE];
    missionNamespace setVariable ['QS_unit_roles',[[],[[['jtac'],[]]],[],[]]];
};
if (_mode isEqualTo 'ART_FINISH') then {['END','PRIMARY','support-jtac'] call QS_fnc_artillerySupport;};
['WATCHDOG'] call QS_fnc_artillerySupport;
private _state = serverNamespace getVariable ['QS_artillerySupport_state',createHashMap];
if (_mode isEqualTo 'ART_SETUP_FO') then {
    {
        _x params ['_index','_magazine'];
        private _carrier = getText (configFile >> 'CfgMagazines' >> _magazine >> 'ammo');
        private _child = getText (configFile >> 'CfgAmmo' >> _carrier >> 'submunitionAmmo');
        private _resolved = (_state get 'ammo') # _index;
        ['support_activity_resolves_guided_child_' + str _index,
            _resolved isEqualTo _child && {_resolved isNotEqualTo _carrier} &&
            {(toLowerANSI getText (configFile >> 'CfgAmmo' >> _resolved >> 'simulation')) isEqualTo 'shotmissile'} &&
            {_index in (_state get 'available')},[_carrier,_resolved]] call IA_fnc_assert;
    } forEach [[1,'2Rnd_155mm_Mo_LG'],[2,'4Rnd_155mm_Mo_guided']];
};
private _jobs = _state getOrDefault ['jobs',createHashMap];
private _pending = (keys _jobs) apply {private _job = _jobs get _x; [_x,_job # 6,scriptDone (_job # 1)]};
private _used = (_state getOrDefault ['uidDebits',createHashMap]) getOrDefault [getPlayerUID _unit,[0,0,0]];
_unit setVariable ['IA_support_artillerySnapshot',[_sequence,_state getOrDefault ['epoch',-1],
    +(_state getOrDefault ['foStock',[]]),_pending,+_used,_state getOrDefault ['kind',''],
    ((_state getOrDefault ['published',createHashMap]) getOrDefault [netId _unit,[0,[]]]) # 1,
    +(_state getOrDefault ['jtacIssued',[]])],owner _unit];
