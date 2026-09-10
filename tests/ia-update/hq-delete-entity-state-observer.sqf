// Fixture-only transport observer. Calls the frozen production receiver with
// inherited native remote/JIP context; it does not emulate that receiver.
private _wasRemote = isRemoteExecuted;
private _sender = remoteExecutedOwner;
private _wasJip = isRemoteExecutedJIP;
if (isNil 'IA_hq_actualEntityStateReceiver') then {
    IA_hq_actualEntityStateReceiver = compile preprocessFileLineNumbers 'production\code\functions\fn_clientApplyEntityState.sqf';
};
_this call IA_hq_actualEntityStateReceiver;
if (_wasRemote && {_sender isEqualTo 2}) then {
    _this params [['_entity',objNull],['_feature',-1],['_face',''],['_handlers',FALSE],['_vectors',[]]];
    if (!isNull _entity) then {
        _entity setVariable ['IA_hq_receivedState',[_feature,_face,_handlers,_vectors,_wasJip],FALSE];
    };
};
