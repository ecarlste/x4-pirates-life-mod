<#
.SYNOPSIS
    Runs the in-game tests: plays scripted scenarios in the real game and reports PASS/FAIL.

.DESCRIPTION
    1. Installs the dev-only test extension (tests/game/apirateslife_tests) next to the deployed mod.
    2. Starts X4 through Steam, so with your Steam launch options: they must write the log
       (-logfile debuglog.txt; -debug all -scriptlogfiles recommended). Started directly, X4.exe
       hands over to Steam and drops its arguments. The test extension starts its own gamestart from the main menu, runs every
       test, logs "[apirateslife-test] ..." lines to debuglog.txt and quits the game.
    3. Watches debuglog.txt until the run finishes, the game exits, or the timeout passes (the
       game is then closed).
    4. Removes the test extension, prints a summary and writes a JUnit report plus a Markdown
       report (tests/game/report.md) that make game-test-report can post to the PR.

    The previous debuglog.txt is kept as debuglog.previous.txt. Deploy the mod first (make deploy-local). Exits 1 if any test failed, the run didn't finish,
    or the log has errors from the mod.

    X4_PATH comes from -X4Path, the X4_PATH environment variable, or deploy.config.

.PARAMETER X4Path
    The X4 install folder.

.PARAMETER LogPath
    The debuglog.txt the game writes (launch option -logfile). Defaults to the one in the only
    numbered profile folder under Documents\Egosoft\X4, or the most recently written one.

.PARAMETER TimeoutSeconds
    How long a whole run may take, including the game loading. Default 900.

.PARAMETER ReportPath
    Where to write the JUnit report. Default tests/game/results.xml.

.PARAMETER GameExe
    Start this executable directly instead of starting X4 through Steam; the tests use a fake game.

.PARAMETER SteamAppId
    X4's Steam app ID. Default 392160.

.PARAMETER LaunchTimeoutSeconds
    How long to wait for the X4 process to appear after asking Steam to start it. Default 120.

.PARAMETER MarkdownPath
    Where to write the Markdown report. Default tests/game/report.md.

.PARAMETER Commit
    The commit being tested, for the report. make game-test passes it (with -Branch and -Dirty)
    from WSL's git; otherwise the runner asks git itself.

.PARAMETER Branch
    The branch being tested, for the report.

.PARAMETER Dirty
    The deployed working tree had uncommitted changes, so the commit doesn't describe what ran.

.PARAMETER KeepExtension
    Leave the test extension installed afterwards (X4 then starts the tests on every launch).

.EXAMPLE
    .\tools\run-game-tests.ps1
#>
[CmdletBinding()]
param(
    [string] $X4Path,
    [string] $LogPath,
    [int] $TimeoutSeconds = 900,
    [string] $ReportPath,
    [string] $GameExe,
    [string] $SteamAppId = '392160',
    [int] $LaunchTimeoutSeconds = 120,
    [double] $PollSeconds = 2,
    [string] $MarkdownPath,
    [string] $Commit,
    [string] $Branch,
    [switch] $Dirty,
    [switch] $KeepExtension
)

$ErrorActionPreference = 'Stop'

$TestExtensionId = 'apirateslife_tests'

# Parses debuglog.txt lines into the run's results. Errors are lines that mention the mod and an
# error, apart from our own markers and the harmless "unsigned file" warnings every mod gets.
function Read-GameTestLog([string[]] $Lines) {
    $run = [pscustomobject]@{ Started = $false; Expected = 0; Done = $false; Results = @(); Errors = @(); GameVersion = ''; MenuReady = $false; SetaDrops = 0 }
    $results = New-Object System.Collections.ArrayList
    $errors = New-Object System.Collections.ArrayList
    foreach ($line in $Lines) {
        # X4 follows each script error with "* Expression: ..." and "* Action: ..." lines, which
        # can quote our markers; only the error's own line counts
        if ($line -like '`* *') { continue }
        if ($line -match 'Game initialisation time until start menu|\[apirateslife-test\] autostart: starting gamestart') {
            $run.MenuReady = $true
        }
        elseif ($line -match '\[apirateslife-test\] SETA was off') {
            $run.SetaDrops++
        }
        elseif ($line -match "Starting new game using gamestart '[^']*' in (\S+) \((\d+)\)") {
            $run.GameVersion = "$($Matches[1]) ($($Matches[2]))"
        }
        elseif ($line -match '\[apirateslife-test\] RUN START (\d+)') {
            $run.Started = $true
            $run.Expected = [int] $Matches[1]
        }
        elseif ($line -match '\[apirateslife-test\] (PASS|FAIL) ([^:\s]+):? ?(.*)$') {
            [void] $results.Add([pscustomobject]@{ Name = $Matches[2]; Passed = ($Matches[1] -eq 'PASS'); Detail = $Matches[3].Trim() })
        }
        elseif ($line -match '\[apirateslife-test\] DONE' -and $run.Started) {
            $run.Done = $true
        }
        elseif ($line -match '(?i)apirateslife' -and $line -match '(?i)error' -and
                $line -notmatch '\[apirateslife-test\]' -and $line -notmatch '(?i)signature') {
            [void] $errors.Add($line.Trim())
        }
    }
    $run.Results = @($results)
    $run.Errors = @($errors)
    $run
}

# Every way a run can fail, as messages; empty means it passed
function Get-RunProblems($Run, [string] $Ending) {
    $problems = @()
    if (-not $Run.Started) { $problems += "the tests never started ($Ending)" }
    elseif (-not $Run.Done) { $problems += "the run didn't finish ($Ending)" }
    if ($Run.Started -and $Run.Results.Count -lt $Run.Expected) {
        $problems += "$($Run.Results.Count) of $($Run.Expected) tests reported"
    }
    $failed = @($Run.Results | Where-Object { -not $_.Passed })
    if ($failed.Count) { $problems += "$($failed.Count) failed: $(($failed | ForEach-Object { $_.Name }) -join ', ')" }
    if ($Run.Errors.Count) { $problems += "$($Run.Errors.Count) errors from the mod in debuglog.txt" }
    $problems
}

function ConvertTo-JUnitXml($Run, [string[]] $Problems) {
    $esc = { param($s) [Security.SecurityElement]::Escape([string] $s) }
    $cases = @()
    foreach ($r in $Run.Results) {
        $body = if ($r.Passed) { '' } else { "<failure message=`"$(& $esc $r.Detail)`"/>" }
        $cases += "    <testcase classname=`"game`" name=`"$(& $esc $r.Name)`">$body</testcase>"
    }
    # The run itself is a test case too, so an unfinished run or log errors show up as failures
    $runProblems = @($Problems | Where-Object { $_ -notmatch '^\d+ failed: ' })
    $body = ''
    if ($runProblems.Count) {
        $details = (@($runProblems) + @($Run.Errors)) -join "`n"
        $body = "<failure message=`"$(& $esc ($runProblems -join '; '))`">$(& $esc $details)</failure>"
    }
    $cases += "    <testcase classname=`"game`" name=`"run`">$body</testcase>"
    $failures = @($Run.Results | Where-Object { -not $_.Passed }).Count + [int] [bool] $runProblems.Count
    @(
        '<?xml version="1.0" encoding="utf-8"?>'
        "<testsuite name=`"x4-game-tests`" tests=`"$($cases.Count)`" failures=`"$failures`">"
        $cases
        '</testsuite>'
    ) -join "`n"
}

# The Markdown report for a PR comment. Its first line is a hidden marker that
# tools/post-game-test-report.sh reads to check the report matches the PR's commit.
# $Info: Commit, Branch, Dirty, StartedAt (datetime), DurationSeconds, and optionally Phases
# (an ordered list of @{ Name; Seconds }, from Get-RunPhases).
function ConvertTo-MarkdownReport($Run, [string[]] $Problems, $Info) {
    $passed = @($Run.Results | Where-Object { $_.Passed }).Count
    $total = [Math]::Max($Run.Expected, $Run.Results.Count)
    $ok = -not @($Problems | Where-Object { $_ }).Count  # PowerShell 7 binds no problems as $null, not an empty array
    $commit = if ($Info.Commit) { $Info.Commit } else { 'unknown' }
    $short = if ($commit.Length -ge 7 -and $commit -ne 'unknown') { $commit.Substring(0, 7) } else { $commit }
    $dirty = ([bool] $Info.Dirty).ToString().ToLower()
    $minutes = [int] [Math]::Floor($Info.DurationSeconds / 60)
    $seconds = [int] $Info.DurationSeconds % 60
    $lines = @(
        "<!-- apirateslife-game-tests commit=$commit dirty=$dirty result=$(if ($ok) { 'pass' } else { 'fail' }) passed=$passed total=$total -->"
        "### Game tests: $(if ($ok) { 'passed' } else { 'FAILED' }), $passed of $total"
        ''
        "Commit ``$short`` on ``$($Info.Branch)``$(if ($Info.Dirty) { ' **plus uncommitted changes**' }), X4 $(if ($Run.GameVersion) { $Run.GameVersion } else { 'version unknown' }), ${minutes} min ${seconds} s, $($Info.StartedAt.ToString('yyyy-MM-dd HH:mm'))"
        ''
        '| Test | Result | Detail |'
        '| --- | --- | --- |'
    )
    foreach ($r in $Run.Results) {
        $detail = ($r.Detail -replace '\|', '\|')
        $lines += "| ``$($r.Name)`` | $(if ($r.Passed) { 'PASS' } else { '**FAIL**' }) | $detail |"
    }
    if ($Run.Started) {
        $lines += ''
        $lines += $(if ($Run.SetaDrops) { "SETA dropped $($Run.SetaDrops) times during the run (switched back on each time)." } else { 'SETA stayed on for the whole run.' })
    }
    if ($Info.Phases) {
        $lines += ''
        $lines += '| Phase | Time |'
        $lines += '| --- | --- |'
        foreach ($phase in $Info.Phases) { $lines += "| $($phase.Name) | $(Format-Seconds $phase.Seconds) |" }
    }
    $runProblems = @($Problems | Where-Object { $_ -notmatch '^\d+ failed: ' })
    if ($runProblems.Count) {
        $lines += ''
        $lines += '**Run problems:**'
        $lines += ''
        $lines += @($runProblems | ForEach-Object { "- $_" })
    }
    if ($Run.Errors.Count) {
        $lines += ''
        $lines += '**Errors from the mod in `debuglog.txt`:**'
        $lines += ''
        $lines += '```'
        $lines += $Run.Errors
        $lines += '```'
    }
    $lines += ''
    $lines += '<sub>Local run of <code>make game-test</code>, posted with <code>make game-test-report</code>.</sub>'
    $lines -join "`n"
}

function Format-Seconds([double] $Seconds) {
    $total = [int] [Math]::Round($Seconds)
    if ($total -lt 60) { return "$total s" }
    "$([int] [Math]::Floor($total / 60)) min $($total % 60) s"
}

# How long each phase of a run took, from the moments the runner first saw each milestone
# ($Seen: milestone name to seconds since launch; missing ones were never reached)
function Get-RunPhases([hashtable] $Seen, [double] $TotalSeconds) {
    $steps = @(
        @{ Key = 'menu'; Name = 'X4 starts, to the main menu' }
        @{ Key = 'tests'; Name = 'Test game loads, to the first test' }
        @{ Key = 'done'; Name = 'Tests run' }
    )
    $phases = @()
    $last = 0.0
    foreach ($step in $steps) {
        if (-not $Seen.ContainsKey($step.Key)) { break }
        $phases += [pscustomobject]@{ Name = $step.Name; Seconds = $Seen[$step.Key] - $last }
        $last = $Seen[$step.Key]
    }
    $phases += [pscustomobject]@{ Name = $(if ($Seen.ContainsKey('done')) { 'X4 quits, cleanup' } else { 'Until the run ended' }); Seconds = $TotalSeconds - $last }
    $phases += [pscustomobject]@{ Name = '**Total**'; Seconds = $TotalSeconds }
    $phases
}

# Commit, branch and dirty state from git, for runs not started by make game-test
function Get-GitState([string] $Root) {
    $state = @{ Commit = ''; Branch = ''; Dirty = $false }
    $ErrorActionPreference = 'Continue'
    try {
        $state.Commit = (& git -c 'safe.directory=*' -C $Root rev-parse HEAD 2>$null | Out-String).Trim()
        $state.Branch = (& git -c 'safe.directory=*' -C $Root rev-parse --abbrev-ref HEAD 2>$null | Out-String).Trim()
        $state.Dirty = [bool] (& git -c 'safe.directory=*' -C $Root status --porcelain 2>$null | Out-String).Trim()
    }
    catch { }
    $state
}

function Resolve-X4Path([string] $Root) {
    if ($env:X4_PATH) { return $env:X4_PATH }
    $config = Join-Path $Root 'deploy.config'
    if (-not (Test-Path $config)) {
        throw "deploy.config not found. Pass -X4Path, set X4_PATH, or run make setup"
    }
    $line = Get-Content $config | Where-Object { $_ -match '^\s*X4_PATH\s*=' } | Select-Object -Last 1
    if (-not $line) { throw "X4_PATH not set in deploy.config" }
    ($line -replace '^\s*X4_PATH\s*=', '').Trim().Trim('"').Trim("'")
}

# Steam profiles are folders named after the account ID under Documents\Egosoft\X4
function Resolve-LogPath {
    $egosoft = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Egosoft\X4'
    $profiles = @(Get-ChildItem $egosoft -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+$' })
    if (-not $profiles.Count) { throw "No X4 profile folder found under $egosoft; pass -LogPath" }
    $newest = $profiles | Sort-Object { $log = Join-Path $_.FullName 'debuglog.txt'; if (Test-Path $log) { (Get-Item $log).LastWriteTime } else { [datetime]::MinValue } } |
              Select-Object -Last 1
    Join-Path $newest.FullName 'debuglog.txt'
}

# Reads the log while the game still has it open for writing
function Read-SharedFile([string] $Path) {
    if (-not (Test-Path $Path)) { return @() }
    $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try { $text = (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
    $text -split "`r?`n"
}

# Dot-sourced by the tests for the functions above
if ($MyInvocation.InvocationName -eq '.') { return }

$root = Split-Path $PSScriptRoot -Parent
if (-not $X4Path) { $X4Path = Resolve-X4Path $root }
if (-not $LogPath) { $LogPath = Resolve-LogPath }
if (-not $ReportPath) { $ReportPath = Join-Path $root 'tests/game/results.xml' }
if (-not $MarkdownPath) { $MarkdownPath = Join-Path $root 'tests/game/report.md' }
if (-not $Commit) {
    $git = Get-GitState $root
    $Commit = $git.Commit
    if (-not $Branch) { $Branch = $git.Branch }
    if ($git.Dirty) { $Dirty = [switch] $true }
}

if (-not (Test-Path (Join-Path $X4Path 'extensions/apirateslife/content.xml'))) {
    throw "A Pirate's Life isn't deployed to $X4Path. Run make deploy-local (or .\deploy.ps1 -WorkingTree) first"
}
$gameName = if ($GameExe) { [IO.Path]::GetFileNameWithoutExtension($GameExe) } else { 'X4' }
if (Get-Process -Name $gameName -ErrorAction SilentlyContinue) {
    throw "$gameName is already running; close it first"
}

$extension = Join-Path $X4Path "extensions/$TestExtensionId"
$startedAt = Get-Date
$game = $null
$ending = ''
try {
    if (Test-Path $extension) { Remove-Item $extension -Recurse -Force }
    Copy-Item (Join-Path $root "tests/game/$TestExtensionId") $extension -Recurse
    # A stale log would report the previous run; keep it out of the way instead
    if (Test-Path $LogPath) { Move-Item $LogPath (Join-Path (Split-Path $LogPath -Parent) 'debuglog.previous.txt') -Force }

    if ($GameExe) {
        Write-Host "Starting $GameExe; results go to $LogPath"
        $game = Start-Process -FilePath $GameExe -WorkingDirectory $X4Path -PassThru
    }
    else {
        Write-Host "Starting X4 through Steam; results go to $LogPath"
        Start-Process "steam://rungameid/$SteamAppId"
        $launchDeadline = (Get-Date).AddSeconds($LaunchTimeoutSeconds)
        while (-not ($game = Get-Process -Name X4 -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            if ((Get-Date) -gt $launchDeadline) { throw "X4 didn't start within $LaunchTimeoutSeconds s. Check Steam is running and isn't waiting on a prompt to allow the launch (accept it and run again)" }
            Start-Sleep -Seconds 1
        }
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $reported = 0
    $seen = @{}
    while ($true) {
        Start-Sleep -Milliseconds ([int] ($PollSeconds * 1000))
        $run = Read-GameTestLog (Read-SharedFile $LogPath)
        for ($i = $reported; $i -lt $run.Results.Count; $i++) {
            $r = $run.Results[$i]
            Write-Host ("  {0} {1}: {2}" -f $(if ($r.Passed) { 'PASS' } else { 'FAIL' }), $r.Name, $r.Detail)
        }
        $reported = $run.Results.Count
        $now = ((Get-Date) - $startedAt).TotalSeconds
        if ($run.MenuReady -and -not $seen.ContainsKey('menu')) { $seen.menu = $now }
        if ($run.Started -and -not $seen.ContainsKey('tests')) { $seen.tests = $now }
        if ($run.Done -and -not $seen.ContainsKey('done')) { $seen.done = $now }
        if ($run.Done) { $ending = 'finished'; break }
        if ($game.HasExited) { $ending = 'the game exited early'; break }
        if ((Get-Date) -gt $deadline) { $ending = "timed out after $TimeoutSeconds s"; break }
    }
    # The tests quit the game themselves; give it a moment, then close it
    if ($ending -like 'timed out*' -or -not $game.WaitForExit(30000)) {
        Write-Host "Closing the game"
        Stop-Process -Id $game.Id -Force -ErrorAction SilentlyContinue
    }
}
finally {
    if ($game -and -not $game.HasExited) { Stop-Process -Id $game.Id -Force -ErrorAction SilentlyContinue }
    if (-not $KeepExtension -and (Test-Path $extension)) {
        # The game may still hold files for a moment after exiting
        for ($i = 0; $i -lt 10 -and (Test-Path $extension); $i++) {
            try { Remove-Item $extension -Recurse -Force } catch { Start-Sleep -Seconds 1 }
        }
    }
}

$run = Read-GameTestLog (Read-SharedFile $LogPath)
$problems = @(Get-RunProblems $run $ending)
New-Item -ItemType Directory -Force -Path (Split-Path $ReportPath -Parent) | Out-Null
[IO.File]::WriteAllText($ReportPath, (ConvertTo-JUnitXml $run $problems))
$total = ((Get-Date) - $startedAt).TotalSeconds
$phases = if ($seen) { @(Get-RunPhases $seen $total) } else { @() }
$info = @{ Commit = $Commit; Branch = $Branch; Dirty = [bool] $Dirty; StartedAt = $startedAt; DurationSeconds = $total; Phases = $phases }
New-Item -ItemType Directory -Force -Path (Split-Path $MarkdownPath -Parent) | Out-Null
[IO.File]::WriteAllText($MarkdownPath, (ConvertTo-MarkdownReport $run $problems $info) + "`n")

$passed = @($run.Results | Where-Object { $_.Passed }).Count
foreach ($e in $run.Errors) { Write-Host "  log error: $e" }
if ($phases) { Write-Host ("Timings: " + (($phases | ForEach-Object { "$($_.Name -replace '\*', '') $(Format-Seconds $_.Seconds)" }) -join '; ')) }
if ($run.Started -and $run.SetaDrops) { Write-Host "SETA dropped $($run.SetaDrops) times during the run" }
if ($problems.Count) {
    Write-Host "GAME TESTS FAILED ($passed passed): $($problems -join '; ')"
    Write-Host "Report: $MarkdownPath"
    exit 1
}
Write-Host "Game tests passed ($passed of $($run.Expected)). Report: $MarkdownPath"
