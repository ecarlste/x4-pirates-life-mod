<#
.SYNOPSIS
    Runs the in-game tests: plays scripted scenarios in the real game (X4 8.00 + SWI, started
    through NoSteam) and reports PASS/FAIL.

.DESCRIPTION
    1. Checks the test profile (<X4_PROFILE_ROOT>\<X4_PROFILE_ID>\) has SWI, A Pirate's Life and
       the test extension switched on in its content.xml (SWI's own content.xml says enabled="0",
       so a new profile starts with it off). -PrepareProfile makes the profile from the root
       profile's content.xml and config.xml and switches all three on.
    2. Installs the dev-only test extension (tests/game/apirateslife_tests) next to the deployed mod.
    3. Starts <X4_PATH>\<X4_EXE> directly (X4_nonsteam.exe, no Steam involved) with
       -skipintro -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid <id>.
       The test extension starts its own gamestart from the main menu, runs every test, logs
       "[apirateslife-test] ..." lines to debuglog.txt and quits the game.
    4. Watches the profile's debuglog.txt until the run finishes, the game exits, no log appears
       within -LaunchTimeoutSeconds, or the timeout passes (the game is then closed).
    5. Removes the test extension, prints a summary and writes a JUnit report plus a Markdown
       report (tests/game/report.md) that make game-test-report can post to the PR.

    The previous debuglog.txt is kept as debuglog.previous.txt. Deploy the mod first (make
    deploy-local). Holds the game lock (<X4_PATH>\game.lock, tools/game-lock.ps1) from the process
    check to the cleanup, waiting first for any other deploy or game run; make game-test hands
    down the lock it took for its deploy and run. Refuses to start while X4 or X4_nonsteam is
    running. -PreflightOnly runs the setup checks alone, before the deploy. Exits 1 if any test
    failed, the run didn't finish, or a log check failed: the runner checks that the mod loaded
    after SWI and that the log has no errors or warnings from our files.

    Settings come from the parameters, else environment variables of the same name, else
    deploy.config, the main checkout's for a worktree (tools/deploy-config.ps1, see
    deploy.config.example): X4_PATH, X4_EXE, X4_PROFILE_ID, X4_PROFILE_ROOT.

.PARAMETER X4Path
    The X4 8.00 install folder (X4_PATH), with SWI in extensions\starwarsmod_m1.

.PARAMETER ProfileId
    The numeric -personalfolderid of the test profile (X4_PROFILE_ID, default 90000301). Only a
    numeric ID gives a separate profile; anything else falls back to the root profile, the
    series playthrough's.

.PARAMETER TimeoutSeconds
    How long a whole run may take, including the game loading SWI. Default 1200.

.PARAMETER LaunchTimeoutSeconds
    How long to wait for the profile's debuglog.txt to appear after starting the game. Default 60.

.PARAMETER ReportPath
    Where to write the JUnit report. Default tests/game/results.xml.

.PARAMETER MarkdownPath
    Where to write the Markdown report. Default tests/game/report.md.

.PARAMETER GameExe
    Start this executable instead of <X4Path>\<X4_EXE>; the tests use a fake game. The preflight
    then only checks this executable isn't running, not X4 and X4_nonsteam.

.PARAMETER Commit
    The commit being tested, for the report. make game-test passes it (with -Branch and -Dirty)
    from WSL's git; otherwise the runner asks git itself.

.PARAMETER Branch
    The branch being tested, for the report.

.PARAMETER Dirty
    The deployed working tree had uncommitted changes, so the commit doesn't describe what ran.

.PARAMETER PrepareProfile
    Make the test profile if needed, copy the root profile's content.xml (extension on/off) and
    config.xml (graphics) into it if it has none, then switch SWI, A Pirate's Life and the test
    extension on in its content.xml. Only reads the root profile, never changes it.

.PARAMETER PreflightOnly
    Run only the setup checks and exit: the executable exists, X4_PROFILE_ID is numeric, SWI is
    installed, the test profile has SWI, A Pirate's Life and the test extension on (skipped with
    -PrepareProfile, which the run then does), and no X4 is running. Doesn't check the mod is
    deployed, changes nothing and doesn't take the game lock, so make game-test runs it (inside the
    lock it holds) before its deploy.

.PARAMETER Test
    Run only these game tests, by cue name (CaptureWingHoldsFire) or the name they report
    (capture_wing_holds_fire), comma-separated. The runner rewrites the $Tests list in the
    installed copy of the test extension, never the repo's. An unknown name stops the run before
    anything changes, -PreflightOnly included.

.PARAMETER Repeat
    Run the selected tests (all of them without -Test) this many times in one game session, in
    rounds: A, B, A, B. The reports then add a tally per test of its runs and failures, for
    measuring a flaky test. Default 1. A run with -Test or -Repeat is marked as a selection in
    its report, and make game-test-report won't post it.

.PARAMETER KeepExtension
    Leave the test extension installed afterwards (X4 then starts the tests on every launch, in
    every profile where it's on).

.EXAMPLE
    .\tools\run-game-tests.ps1 -PrepareProfile

.EXAMPLE
    .\tools\run-game-tests.ps1 -Test capture_wing_holds_fire -Repeat 20
#>
[CmdletBinding()]
param(
    [string] $X4Path,
    [string] $ProfileId,
    [int] $TimeoutSeconds = 1200,
    [int] $LaunchTimeoutSeconds = 60,
    [string] $ReportPath,
    [string] $GameExe,
    [double] $PollSeconds = 2,
    [string] $MarkdownPath,
    [string] $Commit,
    [string] $Branch,
    [switch] $Dirty,
    [switch] $PrepareProfile,
    [switch] $KeepExtension,
    [switch] $PreflightOnly,
    [string[]] $Test,
    [int] $Repeat = 1
)

$ErrorActionPreference = 'Stop'

$TestExtensionId = 'apirateslife_tests'
$ModId = 'apirateslife'
$SwiId = 'SW Interworlds'
$SwiFolder = 'starwarsmod_m1'

# Parses debuglog.txt lines into the run's results. Errors are lines that mention the mod and an
# error or a warning, apart from our own markers and the harmless "unsigned file" warnings every
# mod gets. FirstRead holds the line each file of SWI's and the mod's was first read on
# ("<folder>|<path>"): X4 checks a file's signature as it reads it, in load order.
function Read-GameTestLog([string[]] $Lines) {
    $run = [pscustomobject]@{ Started = $false; Expected = 0; Done = $false; Results = @(); Errors = @(); GameVersion = ''; MenuReady = $false; SetaDrops = 0; FirstRead = @{} }
    $results = New-Object System.Collections.ArrayList
    $errors = New-Object System.Collections.ArrayList
    $lineNumber = 0
    foreach ($line in $Lines) {
        $lineNumber++
        # X4 follows each script error with "* Expression: ..." and "* Action: ..." lines, which
        # can quote our markers; only the error's own line counts
        if ($line -like '`* *') { continue }
        if ($line -match "(?i)extensions\\($ModId|$SwiFolder)\\([^'\s]+)") {
            $key = "$($Matches[1].ToLower())|$($Matches[2].ToLower() -replace '\.sig$', '')"
            if (-not $run.FirstRead.ContainsKey($key)) { $run.FirstRead[$key] = $lineNumber }
        }
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
        elseif ($line -match '(?i)apirateslife' -and $line -match '(?i)error|warning' -and
                $line -notmatch '\[apirateslife-test\]' -and $line -notmatch '(?i)signature') {
            [void] $errors.Add($line.Trim())
        }
    }
    $run.Results = @($results)
    $run.Errors = @($errors)
    $run
}

# The $Tests list in the harness (the Run cue of the test extension's md file): "[", one cue name
# per line, "]" (tests/python/test_game_tests_list.py keeps it that way)
$TestsListPattern = '(<set_value name="\$Tests" exact="\[)([^"\]]*)(\]")'

function Get-GameTestNames([string] $HarnessText) {
    if ($HarnessText -notmatch $TestsListPattern) { throw 'no $Tests list found in the game-test harness' }
    @($Matches[2] -split '[,\s]+' | Where-Object { $_ })
}

# Tests that check the game as it starts, so they only pass before any other test has run: a
# selection runs them once, first
$FirstOnlyTests = @('ConfigAppliedOnStart')

# The cue names to run for -Test and -Repeat: each named test, by cue name or the name it reports
# (capture_wing_holds_fire is CaptureWingHoldsFire), or every test without -Test; in rounds of the
# selection, in the order given, $Repeat times ($FirstOnlyTests once, first). -Test can arrive as
# one comma-separated string (powershell -File passes "a,b" as is), so names are split on commas too.
function Resolve-GameTestSelection([string[]] $Available, [string[]] $Test, [int] $Repeat) {
    if ($Repeat -lt 1) { throw "-Repeat must be 1 or more (got $Repeat)" }
    $key = { param($n) ($n -replace '_', '').ToLowerInvariant() }
    $requested = @($Test | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $selected = $Available
    if ($requested.Count) {
        $selected = @()
        $unknown = @()
        foreach ($name in $requested) {
            $match = @($Available | Where-Object { (& $key $_) -eq (& $key $name) })
            if ($match.Count) { $selected += $match[0] } else { $unknown += $name }
        }
        if ($unknown.Count) { throw "No game test named $($unknown -join ', '). The tests: $($Available -join ', ')" }
    }
    $first = @($selected | Where-Object { $FirstOnlyTests -contains $_ } | Select-Object -Unique)
    $rest = @($selected | Where-Object { $FirstOnlyTests -notcontains $_ })
    @($first) + @(for ($i = 0; $i -lt $Repeat; $i++) { $rest })
}

# The harness text with its $Tests list replaced by these cue names, one per line
function Set-GameTestList([string] $HarnessText, [string[]] $Names) {
    $list = "`n          " + ($Names -join ",`n          ") + "`n        "
    [regex]::Replace($HarnessText, $TestsListPattern, { param($m) $m.Groups[1].Value + $list + $m.Groups[3].Value })
}

# Each test's runs and failures, in the order first seen (Group-Object sorts its groups)
function Get-TestTally($Results) {
    $tally = [ordered]@{}
    foreach ($r in $Results) {
        if (-not $tally.Contains($r.Name)) { $tally[$r.Name] = [pscustomobject]@{ Name = $r.Name; Runs = 0; Failed = 0 } }
        $tally[$r.Name].Runs++
        if (-not $r.Passed) { $tally[$r.Name].Failed++ }
    }
    @($tally.Values)
}

# The tests that ran more than once (-Repeat)
function Get-RepeatTally($Results) {
    @(Get-TestTally $Results | Where-Object { $_.Runs -gt 1 })
}

# The runner's own checks on the log, reported like game tests (tools/check_test_plan.py reads
# their names from the New-LogCheck calls): the mod loads after SWI, and nothing in the log is an
# error or warning from our files
function New-LogCheck([string] $Name, [bool] $Passed, [string] $Detail, [string[]] $Lines = @()) {
    [pscustomobject]@{ Name = $Name; Passed = $Passed; Detail = $Detail; Lines = $Lines }
}

function Get-LogChecks($Run) {
    $shared = @($Run.FirstRead.Keys | Where-Object { $_ -like "$ModId|*" } | ForEach-Object { $_.Substring($ModId.Length + 1) } |
        Where-Object { $Run.FirstRead.ContainsKey("$SwiFolder|$_") } | Sort-Object)
    $early = @($shared | Where-Object { $Run.FirstRead["$ModId|$_"] -lt $Run.FirstRead["$SwiFolder|$_"] })
    $order = if (-not $shared.Count) { "no file read from both SWI and $ModId, so the order is unknown" }
             elseif ($early.Count) { "$ModId read before SWI: $($early -join ', ')" }
             else { "SWI read first for all $($shared.Count) files both patch" }
    New-LogCheck 'load_order_after_swi' ($shared.Count -and -not $early.Count) $order
    $count = if ($Run.Errors.Count) { $Run.Errors.Count } else { 'no' }
    New-LogCheck 'clean_log' (-not $Run.Errors.Count) "$count errors or warnings from our files in debuglog.txt" $Run.Errors
}

# Adds the log checks to a run read from the finished log, as results it expects; returns them
function Add-LogChecks($Run) {
    $checks = @(Get-LogChecks $Run)
    $Run.Results = @($Run.Results) + $checks
    $Run.Expected += $checks.Count
    $checks
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
    if ($failed.Count) {
        # A repeated test is named once, with how often it failed
        $names = Get-TestTally $failed | ForEach-Object { if ($_.Runs -gt 1) { "$($_.Name) ($($_.Runs) times)" } else { $_.Name } }
        $problems += "$($failed.Count) failed: $($names -join ', ')"
    }
    $problems
}

function ConvertTo-JUnitXml($Run, [string[]] $Problems) {
    $esc = { param($s) [Security.SecurityElement]::Escape([string] $s) }
    $cases = @()
    foreach ($r in $Run.Results) {
        # A failed log check carries the log lines it found
        $body = if ($r.Passed) { '' } else { "<failure message=`"$(& $esc $r.Detail)`">$(& $esc (@($r.Lines) -join "`n"))</failure>" }
        $cases += "    <testcase classname=`"game`" name=`"$(& $esc $r.Name)`">$body</testcase>"
    }
    # The run itself is a test case too, so an unfinished run shows up as a failure
    $runProblems = @($Problems | Where-Object { $_ -notmatch '^\d+ failed: ' })
    $body = ''
    if ($runProblems.Count) {
        $body = "<failure message=`"$(& $esc ($runProblems -join '; '))`">$(& $esc ($runProblems -join "`n"))</failure>"
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
# (an ordered list of @{ Name; Seconds }, from Get-RunPhases) and Selected (a -Test or -Repeat run,
# marked so tools/post-game-test-report.sh won't post it as the whole suite).
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
        "<!-- apirateslife-game-tests commit=$commit dirty=$dirty result=$(if ($ok) { 'pass' } else { 'fail' }) passed=$passed total=$total$(if ($Info.Selected) { ' selected=true' }) -->"
        "### Game tests: $(if ($ok) { 'passed' } else { 'FAILED' }), $passed of $total"
        ''
        if ($Info.Selected) { 'Selected tests only (`-Test`, `-Repeat`), not the whole suite.'; '' }
        "Commit ``$short`` on ``$($Info.Branch)``$(if ($Info.Dirty) { ' **plus uncommitted changes**' }), X4 $(if ($Run.GameVersion) { $Run.GameVersion } else { 'version unknown' }), ${minutes} min ${seconds} s, $($Info.StartedAt.ToString('yyyy-MM-dd HH:mm'))"
        ''
        '| Test | Result | Detail |'
        '| --- | --- | --- |'
    )
    foreach ($r in $Run.Results) {
        $detail = ($r.Detail -replace '\|', '\|')
        $lines += "| ``$($r.Name)`` | $(if ($r.Passed) { 'PASS' } else { '**FAIL**' }) | $detail |"
    }
    $tallies = @(Get-RepeatTally $Run.Results)
    if ($tallies.Count) {
        $lines += ''
        $lines += '| Repeated test | Runs | Failed |'
        $lines += '| --- | --- | --- |'
        foreach ($t in $tallies) {
            $lines += "| ``$($t.Name)`` | $($t.Runs) | $($t.Failed) ($([Math]::Round(100 * $t.Failed / $t.Runs))%) |"
        }
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

# Resolve-Setting: a setting from the environment, else deploy.config (the checkout's, else the
# main checkout's), else the default
. (Join-Path $PSScriptRoot 'deploy-config.ps1')

# /mnt/e/x -> E:\x, so deploy.config can hold either form
function ConvertFrom-WslPath([string] $Path) {
    if ($Path -match '^/mnt/([a-zA-Z])(/.*)?$') {
        return "$($Matches[1].ToUpper()):$(([string] $Matches[2]) -replace '/', '\')"
    }
    $Path
}

# The processes that mean a game is already running: either X4 executable (Steam's or NoSteam's,
# which may share the profile folders), and the one this run starts
function Get-GameProcessNames([string] $GameExe) {
    @(@('X4', 'X4_nonsteam', (Get-ProcessName $GameExe)) | Select-Object -Unique)
}

# An executable's process name. Splits on both separators: the tests also run on Linux, where a
# Windows path has no '/'
function Get-ProcessName([string] $Exe) {
    (($Exe -split '[\\/]')[-1]) -replace '\.[^.]*$', ''
}

function Get-LaunchArguments([string] $ProfileId) {
    "-skipintro -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid $ProfileId"
}

# The extension ids switched on in a profile's content.xml
function Get-EnabledExtensions([string] $ContentXml) {
    if (-not (Test-Path $ContentXml)) { return @() }
    [xml] $doc = Get-Content $ContentXml -Raw
    @($doc.content.extension | Where-Object { $_.enabled -eq 'true' -or $_.enabled -eq '1' } | ForEach-Object { $_.id })
}

# Why a test profile can't run the tests, as messages; empty means it can. SWI must be listed as
# on (its own content.xml starts it off); ours start on, so they only fail when listed as off
function Get-ProfileProblems([string] $ContentXml) {
    $problems = @()
    if (@(Get-EnabledExtensions $ContentXml) -notcontains $SwiId) { $problems += "'$SwiId' isn't switched on" }
    if (Test-Path $ContentXml) {
        [xml] $doc = Get-Content $ContentXml -Raw
        foreach ($id in $ModId, $TestExtensionId) {
            if (@($doc.content.extension | Where-Object { $_.id -eq $id -and ($_.enabled -eq 'false' -or $_.enabled -eq '0') }).Count) {
                $problems += "'$id' isn't switched on"
            }
        }
    }
    $problems
}

function Assert-NoGameRunning([string[]] $ProcessNames) {
    foreach ($name in $ProcessNames) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) { throw "$name is already running; close it first" }
    }
}

function Assert-ProfileReady([string] $ContentXml) {
    $ProfileDir = Split-Path $ContentXml -Parent
    $profileProblems = @(Get-ProfileProblems $ContentXml)
    if ($profileProblems.Count) {
        throw "Test profile $ProfileDir isn't ready: $($profileProblems -join '; '). Run with -PrepareProfile (make game-test RUNNER_ARGS=-PrepareProfile), or start X4 in that profile and switch them on in Extensions"
    }
}

# Switches these extensions on in a profile's content.xml (made if missing), keeping other entries
function Enable-Extensions([string] $ContentXml, [string[]] $Ids) {
    $doc = New-Object System.Xml.XmlDocument
    if (Test-Path $ContentXml) { $doc.Load($ContentXml) }
    else { $doc.LoadXml("<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<content>`n</content>") }
    foreach ($id in $Ids) {
        $entry = @($doc.DocumentElement.ChildNodes | Where-Object { $_.Name -eq 'extension' -and $_.id -eq $id }) | Select-Object -First 1
        if (-not $entry) {
            $entry = $doc.CreateElement('extension')
            $entry.SetAttribute('id', $id)
            [void] $doc.DocumentElement.AppendChild($entry)
        }
        $entry.SetAttribute('enabled', 'true')
    }
    $doc.Save($ContentXml)
}

# Reads the log while the game still has it open for writing
function Read-SharedFile([string] $Path) {
    if (-not (Test-Path $Path)) { return @() }
    $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try { $text = (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
    $text -split "`r?`n"
}

# Polls the log while the game runs, reporting each result as it appears and noting in $Seen when
# each phase began; returns how the run ended
function Watch-GameRun($Game, [string] $LogPath, [double] $PollSeconds, [int] $TimeoutSeconds, [int] $LaunchTimeoutSeconds,
                       [string] $ProfileId, $GameLock, [datetime] $StartedAt, [hashtable] $Seen) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $launchDeadline = (Get-Date).AddSeconds($LaunchTimeoutSeconds)
    $reported = 0
    while ($true) {
        Start-Sleep -Milliseconds ([int] ($PollSeconds * 1000))
        if ($GameLock) { Update-GameLock $GameLock }
        # Whether the game had exited before this read: if so, the read has all it wrote. Asked
        # after the read instead, a game that wrote its last lines and quit in between would end
        # the loop with those lines never reported
        $exited = $Game.HasExited
        $run = Read-GameTestLog (Read-SharedFile $LogPath)
        for ($i = $reported; $i -lt $run.Results.Count; $i++) {
            $r = $run.Results[$i]
            Write-Host ("  {0} {1}: {2}" -f $(if ($r.Passed) { 'PASS' } else { 'FAIL' }), $r.Name, $r.Detail)
        }
        $reported = $run.Results.Count
        $now = ((Get-Date) - $StartedAt).TotalSeconds
        if ($run.MenuReady -and -not $Seen.ContainsKey('menu')) { $Seen.menu = $now }
        if ($run.Started -and -not $Seen.ContainsKey('tests')) { $Seen.tests = $now }
        if ($run.Done -and -not $Seen.ContainsKey('done')) { $Seen.done = $now }
        if ($run.Done) { return 'finished' }
        if ($exited) { return 'the game exited early' }
        if (-not (Test-Path $LogPath) -and (Get-Date) -gt $launchDeadline) {
            return "no $LogPath within $LaunchTimeoutSeconds s (did -personalfolderid $ProfileId take?)"
        }
        if ((Get-Date) -gt $deadline) { return "timed out after $TimeoutSeconds s" }
    }
}

# Dot-sourced by the tests for the functions above
if ($MyInvocation.InvocationName -eq '.') { return }

. (Join-Path $PSScriptRoot 'game-lock.ps1')

$root = Split-Path $PSScriptRoot -Parent
if (-not $X4Path) { $X4Path = Resolve-Setting $root 'X4_PATH' '' }
if (-not $X4Path) { throw "X4_PATH not set: pass -X4Path, set X4_PATH, or run make setup and edit deploy.config" }
$X4Path = ConvertFrom-WslPath $X4Path
$exeName = Resolve-Setting $root 'X4_EXE' 'X4_nonsteam.exe'
if (-not $ProfileId) { $ProfileId = Resolve-Setting $root 'X4_PROFILE_ID' '90000301' }
if ($ProfileId -notmatch '^\d+$') { throw "X4_PROFILE_ID must be numeric (got '$ProfileId'): X4 falls back to the root profile, the series playthrough's, for anything else" }
$profileRoot = Resolve-Setting $root 'X4_PROFILE_ROOT' ''
if (-not $profileRoot) { $profileRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Egosoft\X4' }
$profileRoot = ConvertFrom-WslPath $profileRoot
$profileDir = Join-Path $profileRoot $ProfileId
$LogPath = Join-Path $profileDir 'debuglog.txt'
if (-not $ReportPath) { $ReportPath = Join-Path $root 'tests/game/results.xml' }
if (-not $MarkdownPath) { $MarkdownPath = Join-Path $root 'tests/game/report.md' }
# A -GameExe is a fake game (the tests): only its own process counts, so a real X4 left open on the
# machine doesn't stop the tests
$fakeGame = [bool] $GameExe
if (-not $GameExe) { $GameExe = Join-Path $X4Path $exeName }
if (-not (Test-Path $GameExe)) { throw "$GameExe not found; check X4_PATH and X4_EXE in deploy.config" }
if (-not (Test-Path (Join-Path $X4Path "extensions/$SwiFolder/content.xml"))) {
    throw "SWI isn't installed in $X4Path (no extensions\$SwiFolder)"
}
$contentXml = Join-Path $profileDir 'content.xml'
# -Test and -Repeat: checked here, so an unknown name stops make game-test before its deploy
$harnessPath = "md/$TestExtensionId.xml"
$selection = $null
if ($Test -or $Repeat -ne 1) {
    $available = Get-GameTestNames (Get-Content (Join-Path $root "tests/game/$TestExtensionId/$harnessPath") -Raw)
    $selection = @(Resolve-GameTestSelection $available $Test $Repeat)
}
$processNames = if ($fakeGame) { @(Get-ProcessName $GameExe) } else { Get-GameProcessNames $GameExe }
if ($PreflightOnly) {
    Assert-NoGameRunning $processNames
    if (-not $PrepareProfile) { Assert-ProfileReady $contentXml }
    Write-Host "Game test setup OK: $GameExe, test profile $profileDir"
    exit 0
}
if (-not (Test-Path (Join-Path $X4Path "extensions/$ModId/content.xml"))) {
    throw "A Pirate's Life isn't deployed to $X4Path. Run make deploy-local (or .\deploy.ps1 -WorkingTree) first"
}
if (-not $Commit) {
    $git = Get-GitState $root
    $Commit = $git.Commit
    if (-not $Branch) { $Branch = $git.Branch }
    if ($git.Dirty) { $Dirty = [switch] $true }
}

$extension = Join-Path $X4Path "extensions/$TestExtensionId"
$arguments = Get-LaunchArguments $ProfileId
$game = $null
$installed = $false
$ending = ''
$seen = @{}
# Only one run uses the game at a time (tools/game-lock.ps1): wait for any other deploy or game
# run, or use the lock make game-test hands down
$gameLock = Enter-GameLock (Join-Path $X4Path 'game.lock') 'game-test' $root
try {
    Assert-NoGameRunning $processNames

    if ($PrepareProfile) {
        New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
        # Start from the root profile's extension and graphics settings, read only
        foreach ($file in 'content.xml', 'config.xml') {
            $source = Join-Path $profileRoot $file
            if (-not (Test-Path (Join-Path $profileDir $file)) -and (Test-Path $source)) { Copy-Item $source $profileDir }
        }
        Enable-Extensions $contentXml @($SwiId, $ModId, $TestExtensionId)
        Write-Host "Test profile $profileDir ready: $((Get-EnabledExtensions $contentXml) -join ', ') on"
    }
    Assert-ProfileReady $contentXml

    Update-GameLock $gameLock
    $startedAt = Get-Date
    if (Test-Path $extension) { Remove-Item $extension -Recurse -Force }
    $installed = $true
    Copy-Item (Join-Path $root "tests/game/$TestExtensionId") $extension -Recurse
    if ($selection) {
        $installedHarness = Join-Path $extension $harnessPath
        [IO.File]::WriteAllText($installedHarness, (Set-GameTestList (Get-Content $installedHarness -Raw) $selection))
        Write-Host "Running $($selection.Count) selected tests: $(($selection | Select-Object -Unique) -join ', '), $Repeat times"
    }
    # A stale log would report the previous run; keep it out of the way instead
    if (Test-Path $LogPath) { Move-Item $LogPath (Join-Path $profileDir 'debuglog.previous.txt') -Force }

    Write-Host "Starting $GameExe $arguments; results go to $LogPath"
    $game = Start-Process -FilePath $GameExe -ArgumentList $arguments -WorkingDirectory $X4Path -PassThru
    $ending = Watch-GameRun $game $LogPath $PollSeconds $TimeoutSeconds $LaunchTimeoutSeconds $ProfileId $gameLock $startedAt $seen
    # The tests quit the game themselves; give it a moment, then close it
    if (-not $game.HasExited -and ($ending -ne 'finished' -or -not $game.WaitForExit(30000))) {
        Write-Host "Closing the game"
        Stop-Process -Id $game.Id -Force -ErrorAction SilentlyContinue
    }
}
finally {
    if ($game -and -not $game.HasExited) { Stop-Process -Id $game.Id -Force -ErrorAction SilentlyContinue }
    if ($installed -and -not $KeepExtension -and (Test-Path $extension)) {
        # The game may still hold files for a moment after exiting
        for ($i = 0; $i -lt 10 -and (Test-Path $extension); $i++) {
            Update-GameLock $gameLock
            try { Remove-Item $extension -Recurse -Force } catch { Start-Sleep -Seconds 1 }
        }
    }
    Exit-GameLock $gameLock
}

$run = Read-GameTestLog (Read-SharedFile $LogPath)
foreach ($c in (Add-LogChecks $run)) {
    Write-Host ("  {0} {1}: {2}" -f $(if ($c.Passed) { 'PASS' } else { 'FAIL' }), $c.Name, $c.Detail)
}
$problems = @(Get-RunProblems $run $ending)
New-Item -ItemType Directory -Force -Path (Split-Path $ReportPath -Parent) | Out-Null
[IO.File]::WriteAllText($ReportPath, (ConvertTo-JUnitXml $run $problems))
$total = ((Get-Date) - $startedAt).TotalSeconds
$phases = if ($seen.Count) { @(Get-RunPhases $seen $total) } else { @() }
$info = @{ Commit = $Commit; Branch = $Branch; Dirty = [bool] $Dirty; StartedAt = $startedAt; DurationSeconds = $total; Phases = $phases; Selected = [bool] $selection }
New-Item -ItemType Directory -Force -Path (Split-Path $MarkdownPath -Parent) | Out-Null
[IO.File]::WriteAllText($MarkdownPath, (ConvertTo-MarkdownReport $run $problems $info) + "`n")

$passed = @($run.Results | Where-Object { $_.Passed }).Count
foreach ($e in $run.Errors) { Write-Host "  log error: $e" }
if ($phases) { Write-Host ("Timings: " + (($phases | ForEach-Object { "$($_.Name -replace '\*', '') $(Format-Seconds $_.Seconds)" }) -join '; ')) }
foreach ($t in (Get-RepeatTally $run.Results)) { Write-Host "Repeated: $($t.Name): $($t.Failed) of $($t.Runs) runs failed" }
if ($run.Started -and $run.SetaDrops) { Write-Host "SETA dropped $($run.SetaDrops) times during the run" }
if ($problems.Count) {
    Write-Host "GAME TESTS FAILED ($passed passed): $($problems -join '; ')"
    Write-Host "Report: $MarkdownPath"
    exit 1
}
Write-Host "Game tests passed ($passed of $($run.Expected)). Report: $MarkdownPath"
