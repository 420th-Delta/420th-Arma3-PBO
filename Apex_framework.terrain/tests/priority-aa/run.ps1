param(
    [string]$ArmaRoot = 'D:\SteamLibrary\steamapps\common\Arma 3',
    [int]$Port = 24760,
    [int]$TimeoutSeconds = 360,
    [switch]$Headless,
    [ValidateSet('targeting','scheduler','battery','legacy','live','locality','datalink','datalink_camera','datalink_emitter')]
    [string[]]$Cases = @('targeting','scheduler','battery','legacy','live','locality')
)
$ErrorActionPreference = 'Stop'
$missionSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$repoRoot = Split-Path $missionSource -Parent
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$missionName = "T420_PriorityAA_$stamp.Altis"
$artifacts = Join-Path $PSScriptRoot "artifacts\$stamp"
$profiles = Join-Path $artifacts 'profiles'
$stage = Join-Path $artifacts $missionName
$mpRoot = [IO.Path]::GetFullPath((Join-Path $ArmaRoot 'MPMissions'))
$target = [IO.Path]::GetFullPath((Join-Path $mpRoot $missionName))
$expectedTarget = [IO.Path]::GetFullPath((Join-Path $mpRoot $missionName))
$exe = Join-Path $ArmaRoot 'arma3server_x64.exe'
if (!(Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Missing server executable: $exe" }
if (Test-Path -LiteralPath $target) { throw "Refusing existing mission target: $target" }
if (!$target.StartsWith($mpRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid mission target' }
$ports = Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -ge $Port -and $_.LocalPort -le ($Port + 4) }
if ($ports) { throw "Test ports $Port-$($Port + 4) are already in use" }
$process = $null
$headlessProcess = $null
$installed = $false
try {
    New-Item -ItemType Directory -Path $profiles,$stage -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'fixture.Altis') -Force | Copy-Item -Destination $stage -Recurse
    Copy-Item -LiteralPath (Join-Path $missionSource 'code') -Destination $stage -Recurse
    Copy-Item -LiteralPath (Join-Path $missionSource 'stringtable.xml') -Destination $stage
    # Exact, invocation-scoped trust for a worktree created by the sandbox account.
    $checkout = & git -c "safe.directory=$repoRoot" -C $repoRoot rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($checkout) -ne $repoRoot) { throw 'Unexpected source repository' }
    $tracked = @(& git -c "safe.directory=$repoRoot" -C $repoRoot diff --name-only a0a58e1 -- Apex_framework.terrain)
    if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate changed source' }
    $untracked = @(& git -c "safe.directory=$repoRoot" -C $repoRoot ls-files --others --exclude-standard -- Apex_framework.terrain)
    if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate new source' }
    $changed = @($tracked + $untracked | Sort-Object -Unique | Where-Object {
        $_ -match '\.sqf$' -and $_ -notmatch '/tests/'
    })
    $compilePaths = @()
    foreach ($path in $changed) {
        $relative = $path.Substring('Apex_framework.terrain/'.Length)
        $destination = Join-Path $stage $relative
        if (!(Test-Path -LiteralPath $destination)) {
            New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $repoRoot $path) -Destination $destination
        }
        $compilePaths += $relative.Replace('/','\')
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $compileText = '[' + (($compilePaths | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
    [IO.File]::WriteAllText((Join-Path $stage 'changed.sqf'),$compileText,$utf8)
    $caseText = '[' + (($Cases | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
    [IO.File]::WriteAllText((Join-Path $stage 'testConfig.sqf'),('T420_AA_headlessExpected = ' + $Headless.IsPresent.ToString().ToLowerInvariant() + '; T420_AA_cases = ' + $caseText + ';'),$utf8)
    $hashes = @(Get-ChildItem -LiteralPath $stage -File -Recurse | ForEach-Object {
        [ordered]@{path=$_.FullName.Substring($stage.Length + 1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
    $manifest = [ordered]@{
        baseCommit='a0a58e1caa0a4f66bbe02bd5f30a4eb5fd5ee4d7'
        engineVersion=(Get-Item -LiteralPath $exe).VersionInfo.FileVersion
        mods=@();port=$Port;headless=$Headless.IsPresent;cases=$Cases;changedSource=$compilePaths;files=$hashes
    }
    [IO.File]::WriteAllText((Join-Path $artifacts 'manifest.json'),($manifest | ConvertTo-Json -Depth 6),$utf8)
    $config = Join-Path $artifacts 'server.cfg'
    $configText = @"
hostname="420th Priority AA Test";
maxPlayers=2;
verifySignatures=0;
BattlEye=0;
persistent=1;
autoSelectMission=true;
headlessClients[]={"127.0.0.1"};
localClient[]={"127.0.0.1"};
class Missions { class Test { template="$missionName"; difficulty="Regular"; }; };
"@
    [IO.File]::WriteAllText($config,$configText,$utf8)
    Copy-Item -LiteralPath $stage -Destination $target -Recurse
    $installed = $true
    $arguments = @(
        ('-profiles="' + $profiles + '"'),('-config="' + $config + '"'),
        '-name=PriorityAAValidation','-world=empty','-autoInit','-missionsToShutdown=1',
        '-ip=127.0.0.1',"-port=$Port",'-noSound','-noSplash','-skipIntro','-noPause','-noBE'
    )
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $ArmaRoot -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $done = $false
    $rpt = $null
    while ((Get-Date) -lt $deadline -and !$done) {
        Start-Sleep -Milliseconds 500
        $rpt = Get-ChildItem -LiteralPath $profiles -Filter '*.rpt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($rpt) {
            $done = Select-String -LiteralPath $rpt.FullName -SimpleMatch 'T420_AA_TEST_DONE' -Quiet
            if ($Headless -and !$headlessProcess -and (Select-String -LiteralPath $rpt.FullName -SimpleMatch 'T420_AA_TEST_BEGIN' -Quiet)) {
                $hcProfiles = Join-Path $artifacts 'hc-profiles'
                New-Item -ItemType Directory -Path $hcProfiles | Out-Null
                $hcArgs = @('-client',('-profiles="' + $hcProfiles + '"'),'-name=PriorityAAHeadless',"-connect=127.0.0.1:$Port",'-world=empty','-noSound','-noSplash','-skipIntro','-noPause','-noBE')
                $headlessProcess = Start-Process -FilePath $exe -ArgumentList $hcArgs -WorkingDirectory $ArmaRoot -WindowStyle Hidden -PassThru
            }
        }
        $process.Refresh()
        if ($process.HasExited) { break }
    }
    if (!$rpt) { throw "No RPT: $artifacts" }
    $lines = @(Select-String -LiteralPath $rpt.FullName -SimpleMatch 'T420_AA_TEST' | ForEach-Object {$_.Line})
    [IO.File]::WriteAllLines((Join-Path $artifacts 'assertions.log'),[string[]]$lines,$utf8)
    $summary = $lines | Where-Object {$_ -match 'T420_AA_TEST_SUMMARY\|pass=true\|passes=\d+\|failures=0\|scriptErrors=0'} | Select-Object -Last 1
    if (!$done -or !$summary) { throw "Priority AA validation failed or timed out: $artifacts" }
    Write-Output $summary
    Write-Output "Evidence: $artifacts"
} finally {
    if ($headlessProcess) {
        $headlessProcess.Refresh()
        if (!$headlessProcess.HasExited) { Stop-Process -Id $headlessProcess.Id -Force; $headlessProcess.WaitForExit(10000) | Out-Null }
    }
    if ($process) {
        $process.Refresh()
        if (!$process.HasExited) { Stop-Process -Id $process.Id -Force; $process.WaitForExit(10000) | Out-Null }
    }
    if ($installed -and [IO.Path]::GetFullPath($target) -eq $expectedTarget -and $target.StartsWith($mpRoot + '\',[StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}
