/*
Update local artillery computer access. Existing permission requests are retained
while the occupied-vehicle base restriction temporarily disables the computer.
Call with [BOOL] to request access, or [] to refresh the current request.
*/
if (!hasInterface) exitWith {};
params [['_requested',localNamespace getVariable ['QS_artilleryAccess_requested',FALSE],[TRUE]]];
localNamespace setVariable ['QS_artilleryAccess_requested',_requested];

private _blockedAtBase = FALSE;
if (!isNull player && {!isNull (objectParent player)}) then {
	// Query the physical player against the main base only, without cached zones
	// or the remote-controlled entity used by the general client zone system.
	private _baseZones = (missionNamespace getVariable ['QS_system_zones',[]]) select {
		(_x # 0) isEqualTo 'BASE_HIGHSEC_0'
	};
	_blockedAtBase = (['GET',player,_baseZones] call QS_fnc_zoneManager) isNotEqualTo [];
};
private _enabled = _requested && {!_blockedAtBase} && {
	!(localNamespace getVariable ['QS_artilleryAccess_enforcementBlocked',FALSE])
};
if (_enabled isNotEqualTo (localNamespace getVariable ['QS_artilleryAccess_enabled',!_enabled])) then {
	enableEngineArtillery _enabled;
	localNamespace setVariable ['QS_artilleryAccess_enabled',_enabled];
};
