if (!isServer) exitWith {};
for '_slot' from 1 to 11 do {
    if (!((radioChannelInfo _slot) param [5,FALSE])) then {
        private _created = radioChannelCreate [[0,0.8,1,1],format ['IA test channel %1',_slot],'%UNIT_NAME',[],TRUE];
        ['radio.server.channelAllocated',_created isEqualTo _slot,[_slot,_created]] call IA_fnc_assert;
    };
};
missionNamespace setVariable ['QS_radioChannels',[1,2,3,4,5,6,7,8,9,10],TRUE];
missionNamespace setVariable ['IA_radioSideChannel',11,TRUE];
missionNamespace setVariable ['IA_radioReady',TRUE,TRUE];
if (isNil 'QS_hashmap_classLists') then {QS_hashmap_classLists = createHashMap;};
QS_data_listVehicles = compile preprocessFileLineNumbers 'production\code\config\QS_data_listVehicles.sqf';
private _helpers = preprocessFileLineNumbers 'tests\radio-cleanup-extracted\helpers.sqf';
private _tick = preprocessFileLineNumbers 'tests\radio-cleanup-extracted\tick.sqf';
['cleanup.production.helpersFound',_helpers isNotEqualTo ''] call IA_fnc_assert;
['cleanup.production.tickFound',_tick isNotEqualTo ''] call IA_fnc_assert;
if (_helpers isEqualTo '' || {_tick isEqualTo ''}) exitWith {[] call IA_fnc_finish;};
private _productionTick = compile _tick;
private _body = preprocessFileLineNumbers 'tests\radio-cleanup-server-body.sqf';
call compile (_helpers + toString [10] + _body);
[] call IA_fnc_finish;
