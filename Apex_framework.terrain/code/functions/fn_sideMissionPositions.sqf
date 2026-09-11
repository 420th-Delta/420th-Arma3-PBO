/* Side objective positions shared by the ordinary and Priority AA channels. */
params [['_includeEvac',FALSE]];
private _positions = [markerPos 'QS_marker_sideMarker',missionNamespace getVariable ['QS_priorityAA_position',[]]];
if (_includeEvac) then {
	_positions append [
		missionNamespace getVariable ['QS_evacPosition_2',[]],
		missionNamespace getVariable ['QS_priorityAA_evacPosition',[]]
	];
};
_positions select {
	(_x isEqualType []) &&
	{(count _x) >= 2} &&
	{((_x # 0) isEqualType 0) && ((_x # 1) isEqualType 0)} &&
	{(_x # 0) > 0 || {(_x # 1) > 0}}
}
