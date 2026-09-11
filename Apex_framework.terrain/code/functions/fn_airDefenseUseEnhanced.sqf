/* Population gates new ground-AA spawns; targeting/base protection stays enabled in both modes. */
params [['_playerCount',-1,[0]]];
if (_playerCount < 0) then {_playerCount = count (allPlayers - (entities 'HeadlessClient_F'));};
_playerCount >= (missionNamespace getVariable ['QS_missionConfig_priorityAA_minPlayers',40])
