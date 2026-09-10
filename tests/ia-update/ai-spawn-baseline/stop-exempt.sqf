/* Frozen equivalent of the dec9787 Primary STOP exemption predicate. */
_this getVariable ['QS_primaryAO_exempt',FALSE] ||
{(group _this) getVariable ['QS_primaryAO_exempt',FALSE]} ||
{_this getVariable ['QS_RD_missionObjective',FALSE]} ||
{_this getVariable ['QS_aoTask_medevac_unit',FALSE]} ||
{isPlayer _this} || {captive _this} ||
{!isNull (remoteControlled _this)} ||
{!isNull (_this getVariable ['bis_fnc_moduleRemoteControl_owner',objNull])}
