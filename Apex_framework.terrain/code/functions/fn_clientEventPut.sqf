/*
File: fn_clientEventPut.sqf
Author: 

	Quiksilver
	
Last modified:

	20/01/20167 A3 1.66 by Quiksilver
	
Description:

	Client Event Put
___________________________________________________________________*/

/* Legacy Code as of 9.9.2026 */
//|params ['_unit','_container','_item'];
// Source has no final newline
// Updated Code
params ['_unit','_container','_item'];

// A private notice on actual ground drops; depositing into a crate or another
// player's inventory is not an arsenal litter event. Reuse the existing Put EH.
if (_unit isEqualTo player && {!isNull _container} && {
    (_container isKindOf 'WeaponHolder') || {_container isKindOf 'GroundWeaponHolder'} ||
    {_container isKindOf 'WeaponHolderSimulated'}
} && {
    ((missionNamespace getVariable ['QS_arsenals',[]]) findIf {
        !isNull _x && {alive _x} && {!isObjectHidden _x} && {(_container distance2D _x) <= 30}
    }) >= 0
} && {diag_tickTime >= (localNamespace getVariable ['QS_cleanup_dropNoticeAfter',-1])}) then {
    localNamespace setVariable ['QS_cleanup_dropNoticeAfter',diag_tickTime + 15];
    systemChat 'Dropped gear near arsenals expires after 30 seconds without inventory changes.';
};
// End Updated Code
