/*
Function: TGC_fnc_isFriendlyAI

Description:
    Return whether an entity is currently AI on BLUFOR or a side BLUFOR
    considers friendly. Civilian-side units are always excluded.

*/
params [["_unit", objNull, [objNull]]];

if (
    (isNull _unit) ||
    {isPlayer _unit} ||
    {
        !(_unit isKindOf "CAManBase") &&
        {!(_unit isKindOf "B_UAV_AI")} &&
        {!(_unit isKindOf "O_UAV_AI")} &&
        {!(_unit isKindOf "I_UAV_AI")} &&
        {!(_unit isKindOf "C_UAV_AI_F")}
    }
) exitWith {false};

private _unitSide = side (group _unit);
if (_unitSide isEqualTo sideUnknown) then {
    _unitSide = side _unit;
};

(_unitSide isNotEqualTo sideUnknown) &&
{_unitSide isNotEqualTo CIVILIAN} &&
{(_unitSide isEqualTo WEST) || {(WEST getFriend _unitSide) >= 0.6}}
