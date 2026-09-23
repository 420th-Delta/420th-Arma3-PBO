/* Capture the unique AA task context before its markers are removed. Rewards are queued. */
if (!isServer) exitWith {};
params [['_result',0],['_position',[]],['_context',[]]];
_context params ['_taskId','_markerId','_circleId','_instanceId'];
private _markerText = markerText _markerId;
private _debriefContext = [_taskId,_markerText,'QS_priorityAA_evacPosition',TRUE,_instanceId];
[_result,_position,-1,_debriefContext] call QS_fnc_smDebrief;
deleteMarker _markerId;
deleteMarker _circleId;
