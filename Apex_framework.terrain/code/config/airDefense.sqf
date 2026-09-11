// Defaults; server @Apex_cfg\parameters.sqf may override these mission variables.
// Distances are metres, intervals are seconds. See docs/priority-aa.md.
[
    ['QS_missionConfig_priorityAA_enabled',TRUE],
    ['QS_missionConfig_priorityAA_minPlayers',40,0,200],
    ['QS_missionConfig_priorityAA_onNewAO',FALSE],
    ['QS_missionConfig_priorityAA_interval',[600,1800],1,86400],
    ['QS_missionConfig_priorityAA_aoDistance',[1200,3500],100,20000],
    ['QS_missionConfig_priorityAA_baseDistance',5000,100,30000],
    ['QS_missionConfig_priorityAA_satelliteCount',2,0,2],
    ['QS_missionConfig_priorityAA_satelliteDistance',[50,200],40,500],
    ['QS_missionConfig_airDefense_enabled',TRUE],
    ['QS_missionConfig_airDefense_baseExclusionRadius',2000,0,10000],
    ['QS_missionConfig_airDefense_interval',3,1,30],
    ['QS_missionConfig_airDefense_reinforcementWeight',2,0,10]
]
