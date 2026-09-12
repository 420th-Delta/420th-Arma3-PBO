/*
File: fn_serverDetector.sqf
Author:

	Quiksilver
	
Last modified:

	21/10/2023 A3 2.14 by Quiksilver
	
Description:

	Detect units in area
____________________________________________________________*/

params ['_origin','_rad','_sides','_pool','_type'];
/* Legacy Code as of 9.9.2026 */
//|if (_type isEqualTo 0) exitWith {
//|	((_pool select {((side _x) in _sides)}) inAreaArray [_origin,_rad,_rad,0,FALSE,-1]);
//|};
// Updated Code
// End Updated Code
if (_type isEqualTo -1) exitWith {
	(count ((units EAST) inAreaArray [_origin,_rad,_rad,0,FALSE,-1]))
};
/* Legacy Code as of 9.9.2026 */
//|(count ((_pool select {((side _x) in _sides)}) inAreaArray [_origin,_rad,_rad,0,FALSE,-1]));
// Source has no final newline
// Updated Code
// Narrow the supplied pool in the engine before testing sides in SQF.
// Keep current positions, the original area and the original result order.
private _near = _pool inAreaArray [_origin,_rad,_rad,0,FALSE,-1];
if (_type isEqualTo 0) exitWith {
	(_near select {((side _x) in _sides)})
};
{((side _x) in _sides)} count _near;
// End Updated Code
