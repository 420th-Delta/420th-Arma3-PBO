"""Stage this checkout as a full mission; diagnostic additions stay in artifacts."""
import shutil


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Integration staging anchor changed: {old[:100]}")
    return text.replace(old, new)


def stage(source, mission, tests, headless, players, observe, cycle=False):
    for path in source.iterdir():
        target = mission / path.name
        if path.is_dir():
            shutil.copytree(path, target, dirs_exist_ok=True)
        else:
            shutil.copy2(path, target)
    # Root tests are deliberately separate from the production mission's tests.
    shutil.copytree(tests, mission / "ia-tests", ignore=shutil.ignore_patterns("__pycache__"))
    if players:
        description = mission / "description.ext"
        text = description.read_text(encoding="utf-8-sig")
        text = once(text, "skipLobby = 0;", "skipLobby = 1;")
        text = once(text, "joinUnassigned = 1;", "joinUnassigned = 0;")
        description.write_text(text, encoding="utf-8")
    common = (tests / "harness-init.sqf").read_text(encoding="utf-8").split("// HARNESS_DISPATCH_BEGIN", 1)[0]
    init = common + (tests / "integration-init.sqf").read_text(encoding="utf-8")
    if cycle:
        opening = "        _until = diag_tickTime + __OBSERVE__;"
        closing = "        // INTEGRATION_EXECUTION_END"
        if init.count(opening) != 1 or init.count(closing) != 1:
            raise ValueError("Integration observation block changed")
        start, end = init.index(opening), init.index(closing)
        cycle_code = r'''        private _cycleConnections = call _fn_connections;
        private _cycleReady = missionNamespace getVariable ['QS_mission_init',FALSE] &&
            {(missionNamespace getVariable ['QS_mission_aoType','']) isEqualTo 'CLASSIC'} &&
            {_cycleConnections # 0} && {_cycleConnections # 1} &&
            {!(missionNamespace getVariable ['IA_abort',FALSE])};
        if (_cycleReady) then {
            missionNamespace setVariable ['IA_integrationCycle_allowed',TRUE,FALSE];
            private _cyclePassed = [660,90] call compile preprocessFileLineNumbers 'ia-tests\integration-cycle.sqf';
            missionNamespace setVariable ['IA_integrationCycle_allowed',FALSE,FALSE];
            ['cycle_driver_completed',!isNil '_cyclePassed' && {_cyclePassed isEqualTo TRUE}] call IA_fnc_assert;
        } else {
            ['cycle_prerequisites_ready',FALSE] call IA_fnc_assert;
        };
'''
        init = init[:start] + cycle_code + init[end:]
    init = init.replace("__HEADLESS__", str(headless)).replace("__PLAYERS__", str(players)).replace("__OBSERVE__", str(observe))
    (mission / "init.sqf").write_text(init, encoding="utf-8")


def runner(text, headless):
    text = once(text, "    New-Item -ItemType Directory -Path $profile | Out-Null", r'''    New-Item -ItemType Directory -Path $profile | Out-Null
    if($role -eq 'server') {
        $userProfile=Join-Path $profile 'Users\server'
        New-Item -ItemType Directory -Path $userProfile | Out-Null
        $difficulty='version=1; difficulty="Custom"; class DifficultyPresets { class CustomDifficulty { class Options { mapContent=0; mapContentEnemy=0; mapContentFriendly=0; deathMessages=0; autoReport=0; enemyTags=0; friendlyTags=0; groupIndicators=0; waypoints=0; }; aiLevelPreset=1; }; };'
        [IO.File]::WriteAllText((Join-Path $userProfile 'server.Arma3Profile'),$difficulty,$utf8)
    }''')
    text = once(text, "        $evidenceBytes=0L", """        $rptBytes=0L
        foreach($entry in $owned) {
            Get-ChildItem -LiteralPath $entry.profile -Filter '*.rpt' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {$rptBytes += $_.Length}
        }
        if($rptBytes -gt 64MB) {throw 'Bounded RPT evidence cap exceeded.'}
        $evidenceBytes=0L""")
    opening = "    $sqmPath=Join-Path $mission 'mission.sqm'"
    closing = "    if(@($spec.extra_compile_sources).Count) {"
    start, end = text.index(opening), text.index(closing)
    text = text[:start] + text[end:]
    text = once(text, "difficulty=`\"Regular`\";", "difficulty=`\"Custom`\";")
    text = once(text, "loopback=true; class Missions", 'loopback=true; headlessClients[]={ `"127.0.0.1`" }; localClient[]={ `"127.0.0.1`" }; class Missions')
    text = once(text, "    $server=Start-Owned 'server' $false", r'''
    foreach($folder in @('@Apex','@Apex_cfg')) {
        Copy-Item -LiteralPath (Join-Path $lab ('runtime\seed\home\'+$folder)) -Destination $homeRoot -Recurse
    }
    [IO.File]::AppendAllText((Join-Path $homeRoot '@Apex_cfg\parameters.sqf'),"`nQS_missionConfig_aoType='CLASSIC'; QS_missionConfig_restartHours=[]; QS_missionConfig_restartDynamic=FALSE;`n",$utf8)
    $server=Start-Owned 'server' $false''')
    text = once(text, "    } else {\n        $exe=Join-Path $homeRoot 'arma3server_x64.exe'", r'''
    } elseif($role -like 'HC*') {
        $exe=Join-Path $homeRoot 'arma3server_x64.exe'
        $arguments += @('-client',('-connect=127.0.0.1:'+$spec.port),('-password='+$joinPassword),'-noSound')
    } else {
        $arguments += '-serverMod=@Apex'
        $exe=Join-Path $homeRoot 'arma3server_x64.exe' ''')
    text = once(text, "    $startedClients=0", "    $startedHCs=$false\n    $startedClients=0")
    roles = "    foreach($role in @('server') + @(0..([Math]::Max(0,$spec.players-1)) | ForEach-Object {'client'+$_})) {"
    hc_roles = "".join(" + @('HC" + str(i) + "')" for i in range(1, headless + 1))
    text = once(text, roles, roles.replace(") {", hc_roles + ") {"))
    text = once(text, "$selected=@(if($role -eq 'server'){$spec.server_mods}else{$spec.client_mods})",
                "$selected=@(if($role -eq 'server' -or $role -like 'HC*'){$spec.server_mods}else{$spec.client_mods})")
    text = once(text, "            while($startedClients -lt $spec.players) {", f"""
            if(!$startedHCs) {{
                for($hcIndex=1;$hcIndex -le {headless};$hcIndex++) {{$null=Start-Owned ('HC'+$hcIndex) $false}}
                $startedHCs=$true
            }}
            while($startedClients -lt $spec.players) {{""")
    return text


def cleanup(text, headless):
    roles = "foreach($role in @('server')+@(0..([Math]::Max(0,$spec.players-1)) | ForEach-Object {'client'+$_})){"
    hc_roles = "".join(" + @('HC" + str(i) + "')" for i in range(1, headless + 1))
    text = once(text, roles, roles.replace("){", hc_roles + "){"))
    return once(text, "$selected=@(if($role -eq 'server'){$spec.server_mods}else{$spec.client_mods})",
                "$selected=@(if($role -eq 'server' -or $role -like 'HC*'){$spec.server_mods}else{$spec.client_mods})")
