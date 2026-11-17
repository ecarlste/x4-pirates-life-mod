<#
.SYNOPSIS
    Runs the in-game tests: plays scripted scenarios in the real game (X4 8.00 + SWI, started
    through NoSteam) and reports PASS/FAIL.

.DESCRIPTION
    1. Checks the test profile (<X4_PROFILE_ROOT>\<X4_PROFILE_ID>\) has SWI, A Pirate's Life and
       the test extension switched on in its content.xml (SWI's own content.xml says enabled="0",
       so a new profile starts with it off). -PrepareProfile makes the profile from the root
       profile's content.xml and config.xml and switches all three on. Every run then switches
       off, in the test profile, every other extension installed in the game folder apart from
       Egosoft's DLCs, so each run is SWI-only.
    2. Installs the dev-only test extension (tests/game/apirateslife_tests) next to the deployed mod.
    3. Starts <X4_PATH>\<X4_EXE> directly (X4_nonsteam.exe, no Steam involved) with
       -skipintro -disablesound -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid <id>
       (-disablesound mutes the run without changing the profile's sound settings).
       The test extension starts its own gamestart from the main menu, runs every test, logs
       "[apirateslife-test] ..." lines to debuglog.txt and quits the game.
    4. Watches the profile's debuglog.txt until the run finishes, the game exits, no log appears
       within -LaunchTimeoutSeconds, or the timeout passes (the game is then closed).
    5. Removes the test extension, prints a summary and writes a JUnit report plus a Markdown
       report (tests/game/report.md) that make game-test-report can post to the PR. Each test
       run's mod lines go to <report folder>\runs\<test>-<n>.log (runs\<label>\ with -RunsLabel),
       replacing the last run's .log files there (not for -Release); node
       tools/summarize-game-runs.ts sums them up.

    The previous debuglog.txt is kept as debuglog.previous.txt. Deploy the mod first (make
    deploy-local). Holds the game lock (<X4_PATH>\game.lock, tools/game-lock.ps1) from the process
    check to the cleanup, waiting first for any other deploy or game run; make game-test hands
    down the lock it took for its deploy and run. Refuses to start while X4 or X4_nonsteam is
    running. -PreflightOnly runs the setup checks alone, before the deploy. Exits 1 if any test
    failed, the run didn't finish, or a log check failed: the runner checks that the mod loaded
    after SWI, that the log has no errors or warnings from our files, and that no files were read
    from extensions other than Egosoft's DLCs, SWI and ours.

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
    its report, and make game-test-report won't post it. A selection whose worst case could hold
    the game lock over the PR tier's 5 minutes is refused, unless -LongHold (see -LongHold).

.PARAMETER LongHold
    Run a -Test or -Repeat selection even if its worst case could hold the game lock over the PR
    tier's 5 minutes. Without it the runner refuses such a selection before it takes the lock
    (docs/testing.md, Keep each hold short): the worst case is about 55 s of game start plus
    each test run's timeout cue, at 1x for a combat test and a sixth of it under SETA otherwise,
    or the whole 5 minutes for a test with no timeout cue. One test run is never refused, and
    whole tiers and -Release aren't checked.

.PARAMETER HoldCheckOnly
    Only check the selection's hold (see -LongHold) and stop: make game-test runs it before it
    queues for the game lock. Needs no X4 settings.

.PARAMETER HoldEstimateOnly
    Only print the -Test tests' hold estimates (see -LongHold) as one line of JSON and stop:
    {"budget": <s>, "gameStart": <s>, "tests": [{"name": <as given>, "seconds": <one run's worst
    case>}]}. make game-proof sizes its chunks from it (tools/game-proof.ts). Needs no X4 settings.

.PARAMETER RunsLabel
    Keep this batch's run traces in <report folder>\runs\<label>\ instead of runs\, so batches
    (an order variant each, say) sit side by side for node tools/summarize-game-runs.ts --totals.
    It replaces only that label's last traces (see -RunsAppend). A folder name: letters, digits,
    '.', '_' and '-'.

.PARAMETER RunsAppend
    Add this run's traces to the -RunsLabel folder's instead of replacing them, numbering each
    test's runs on from its highest there, so a batch split into runs within the hold budget adds
    up as one batch. Needs -RunsLabel; the batch's first run goes without it, to clear the
    label's last traces.

.PARAMETER Release
    Run the release sessions instead of the game tests: X4 starts once per session, with the
    mod switched on or off in the test profile, and the release test extension
    (tests/game/apirateslife_release_tests) starts or loads the game. Session 1 starts a new game
    without the mod and saves it (<profile>\save\apirateslife_release_1); session 2 loads that save
    with the mod, runs ConfigAppliedOnStart, CaptureStartAndDestroyed and ReleaseLeftovers on it
    and saves it again (apirateslife_release_2); session 3 loads that save without the mod, plays
    10 minutes and checks what the mod left in it. The existing_save_loads and
    save_plays_without_mod checks read the logs, kept as debuglog.release-<n>.txt, and each session
    gets the log checks. A session that saves nothing stops the run. The profile is left with the
    mod and the game tests on. Takes no -Test, -Repeat, -KeepExtension or -ReleaseTier.

.PARAMETER ReleaseTier
    Run the release tier (make game-test RELEASE=1): every test in $Tests, the ones in the
    harness's $ReleaseOnly list too, which a plain run (the PR tier) leaves out, and each test in its
    $ReleaseRuns list its runs in a row, failing a test whose passes with the outcome met fall
    below the passes it needs (a plain run runs it once, and only logs its outcome). The report names
    the tier and warns, without failing, when the run is over the tier's budget: 5 minutes for the
    PR tier, 30 for the release tier, from launch to quit. Raises the default -TimeoutSeconds to
    2400. Not the release sessions (-Release).

.PARAMETER KeepExtension
    Leave the test extension installed afterwards (X4 then starts the tests on every launch, in
    every profile where it's on).

.EXAMPLE
    .\tools\run-game-tests.ps1 -PrepareProfile

.EXAMPLE
    .\tools\run-game-tests.ps1 -Test capture_wing_holds_fire -Repeat 20 -LongHold

.EXAMPLE
    .\tools\run-game-tests.ps1 -Release
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
    [int] $Repeat = 1,
    [string] $RunsLabel,
    [switch] $RunsAppend,
    [switch] $Release,
    [switch] $ReleaseTier,
    [switch] $LongHold,
    [switch] $HoldCheckOnly,
    [switch] $HoldEstimateOnly
)

$ErrorActionPreference = 'Stop'

$TestExtensionId = 'apirateslife_tests'
$ReleaseExtensionId = 'apirateslife_release_tests'
$ModId = 'apirateslife'
$SwiId = 'SW Interworlds'
$SwiFolder = 'starwarsmod_m1'

# Parses debuglog.txt lines into the run's results. Errors are lines that mention the mod and an
# error or a warning, apart from our own markers and the harmless "unsigned file" warnings every
# mod gets. A result's Outcome is 'met' or 'missed' for a test with a split verdict (its PASS or FAIL
# is then its invariants), else empty. FirstRead holds the line each file of SWI's and the mod's was first read on
# ("<folder>|<path>"): X4 checks a file's signature as it reads it, in load order. Extensions holds
# the extension folders any file was read from, lowercased. A release session (-Release) logs the
# save it wrote (Saved, or SaveFailed with why), the save it asked to load (LoadingSave) and the
# module of the game it loaded (Loaded).
function Read-GameTestLog([string[]] $Lines) {
    $run = [pscustomobject]@{ Started = $false; Expected = 0; Done = $false; Results = @(); Errors = @(); GameVersion = ''; MenuReady = $false; SetaDrops = 0; FirstRead = @{}; Extensions = @(); Saved = ''; SaveFailed = ''; LoadingSave = ''; Loaded = ''; Allowed = @() }
    $extensions = @{}
    $results = New-Object System.Collections.ArrayList
    $errors = New-Object System.Collections.ArrayList
    $lineNumber = 0
    foreach ($line in $Lines) {
        $lineNumber++
        # X4 follows each script error with "* Expression: ..." and "* Action: ..." lines, which
        # can quote our markers; only the error's own line counts
        if ($line -like '`* *') { continue }
        if ($line -match "(?i)extensions\\([^\\'`"]+)\\") { $extensions[$Matches[1].ToLower()] = $true }
        if ($line -match "(?i)extensions\\($ModId|$SwiFolder)\\([^'\s]+)") {
            $key = "$($Matches[1].ToLower())|$($Matches[2].ToLower() -replace '\.sig$', '')"
            if (-not $run.FirstRead.ContainsKey($key)) { $run.FirstRead[$key] = $lineNumber }
        }
        if ($line -match 'Game initialisation time until start menu|\[apirateslife-test\] (autostart: starting gamestart|release: (starting gamestart|loading save))') {
            $run.MenuReady = $true
            if ($line -match 'release: loading save (\S+)') { $run.LoadingSave = $Matches[1] }
        }
        elseif ($line -match '\[apirateslife-test\] SAVED (\S+)') {
            $run.Saved = $Matches[1]
        }
        elseif ($line -match '\[apirateslife-test\] SAVE FAILED: (.*)$') {
            $run.SaveFailed = $Matches[1].Trim()
        }
        elseif ($line -match '\[apirateslife-test\] LOADED (\S+)') {
            $run.Loaded = $Matches[1]
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
        elseif ($line -match '\[apirateslife-test\] (PASS|FAIL) ([^:\s]+)(?: outcome=(met|missed))?:? ?(.*)$') {
            [void] $results.Add([pscustomobject]@{ Name = $Matches[2]; Passed = ($Matches[1] -eq 'PASS'); Outcome = [string] $Matches[3]; Detail = $Matches[4].Trim() })
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
    $run.Extensions = @($extensions.Keys | Sort-Object)
    $run
}

# The mod's lines in a game test log ([apirateslife] and [apirateslife-test], whole), split into one
# run per test result, for the per-run traces (Write-GameTestRunLogs). A run starts after RUN START
# or the previous result and ends on its own PASS or FAIL line, so a line logged after a test's
# result (its cleanup) goes with the next test. Name is the name the test reports, Number counts
# its runs from 1. Lines after the last result, with no DONE, are a run named 'unfinished'.
function Split-GameTestRuns([string[]] $Lines) {
    $runs = New-Object System.Collections.ArrayList
    $numbers = @{}
    $current = New-Object System.Collections.ArrayList
    $started = $false
    $done = $false
    foreach ($line in $Lines) {
        if ($line -like '`* *' -or $line -notmatch '\[apirateslife(-test)?\]') { continue }
        if ($line -match '\[apirateslife-test\] RUN START ') { $started = $true; continue }
        if (-not $started) { continue }
        if ($line -match '\[apirateslife-test\] DONE') { $done = $true; break }
        [void] $current.Add($line)
        if ($line -match '\[apirateslife-test\] (PASS|FAIL) ([^:\s]+)') {
            $name = $Matches[2]
            $numbers[$name] = 1 + [int] $numbers[$name]
            [void] $runs.Add([pscustomobject]@{ Name = $name; Number = $numbers[$name]; Lines = @($current) })
            $current.Clear()
        }
    }
    if ($current.Count -and -not $done) { [void] $runs.Add([pscustomobject]@{ Name = 'unfinished'; Number = 1; Lines = @($current) }) }
    @($runs)
}

# Writes each run's lines to <Dir>/<name>-<number>.log, after removing the .log files already
# there, so it holds only the last run's traces (tools/summarize-game-runs.ts reads them). With
# -Append it keeps them and numbers each test's runs on from its highest there instead, so a batch
# split into several runs adds up as one. Returns how many files it wrote.
function Write-GameTestRunLogs($Runs, [string] $Dir, [switch] $Append) {
    # A log with no runs comes in as $null
    $Runs = @($Runs | Where-Object { $_ })
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $highest = @{}
    if ($Append) {
        foreach ($file in @(Get-ChildItem (Join-Path $Dir '*.log'))) {
            if ($file.Name -match '^(.+)-(\d+)\.log$' -and [int] $Matches[2] -gt [int] $highest[$Matches[1]]) { $highest[$Matches[1]] = [int] $Matches[2] }
        }
    }
    else { Remove-Item (Join-Path $Dir '*.log') -Force }
    foreach ($run in $Runs) {
        $number = [int] $highest[$run.Name] + $run.Number
        [IO.File]::WriteAllText((Join-Path $Dir "$($run.Name)-$number.log"), (@($run.Lines) -join "`n") + "`n")
    }
    $Runs.Count
}

# The $Tests list in the harness (the Run cue of the test extension's md file): "[", one cue name
# per line, "]" (tests/python/test_game_tests_list.py keeps it that way)
$TestsListPattern = '(<set_value name="\$Tests" exact="\[)([^"\]]*)(\]")'

# The cue names in one of the harness's lists: $Tests (every test) or $ReleaseOnly (the tests only
# the release tier runs, -ReleaseTier)
function Get-GameTestNames([string] $HarnessText, [string] $List = 'Tests') {
    if ($HarnessText -notmatch "<set_value name=`"\`$$List`" exact=`"\[([^`"\]]*)\]`"") { throw "no `$$List list found in the game-test harness" }
    @($Matches[1] -split '[,\s]+' | Where-Object { $_ })
}

# The harness's $ReleaseRuns list: the tests the release tier runs more than once, each as
# [<cue name>, <runs>, <passes needed>]; returns cue name -> @{ Runs; Needed }
# (tests/python/test_game_tests_list.py checks the list). Refuses a $FirstOnlyTests test, which a
# run can't repeat.
function Get-ReleaseRuns([string] $HarnessText) {
    if ($HarnessText -notmatch '<set_value name="\$ReleaseRuns" exact="([^"]*)"') { throw 'no $ReleaseRuns list found in the game-test harness' }
    $runs = @{}
    foreach ($m in [regex]::Matches($Matches[1], '\[\s*(\w+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]')) {
        if ($FirstOnlyTests -contains $m.Groups[1].Value) { throw "`$ReleaseRuns lists $($m.Groups[1].Value), which runs once, first, in any run; take it out" }
        $runs[$m.Groups[1].Value] = [pscustomobject]@{ Runs = [int] $m.Groups[2].Value; Needed = [int] $m.Groups[3].Value }
    }
    $runs
}

# A test's name as -Test and the bars match it: the cue name and the name it reports
# (CaptureWingHoldsFire, capture_wing_holds_fire) are the same key
function Get-TestKey([string] $Name) { ($Name -replace '_', '').ToLowerInvariant() }

# Tests that check the game as it starts, so they only pass before any other test has run: a
# selection runs them once, first
$FirstOnlyTests = @('ConfigAppliedOnStart')

# The cue names to run: each test -Test names, by cue name or the name it reports
# (capture_wing_holds_fire is CaptureWingHoldsFire), or without -Test every test but the $Skip ones
# (the release-only tests, on a PR-tier run); in rounds of the selection, in the order given,
# $Repeat times ($FirstOnlyTests once, first). A test in $Runs (cue name -> count: the release
# tier's pass bars, from Get-ReleaseRuns) runs its bar's Runs times in a row where it stands. -Test can arrive as one
# comma-separated string (powershell -File passes "a,b" as is), so names are split on commas too.
function Resolve-GameTestSelection([string[]] $Available, [string[]] $Test, [int] $Repeat, [string[]] $Skip = @(), [hashtable] $Runs = @{}) {
    if ($Repeat -lt 1) { throw "-Repeat must be 1 or more (got $Repeat)" }
    $requested = @($Test | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $selected = @($Available | Where-Object { $Skip -notcontains $_ })
    if ($requested.Count) {
        $selected = @()
        $unknown = @()
        foreach ($name in $requested) {
            $match = @($Available | Where-Object { (Get-TestKey $_) -eq (Get-TestKey $name) })
            if ($match.Count) { $selected += $match[0] } else { $unknown += $name }
        }
        if ($unknown.Count) { throw "No game test named $($unknown -join ', '). The tests: $($Available -join ', ')" }
    }
    $first = @($selected | Where-Object { $FirstOnlyTests -contains $_ } | Select-Object -Unique)
    $rest = @($selected | Where-Object { $FirstOnlyTests -notcontains $_ })
    $round = @(foreach ($name in $rest) { $count = if ($Runs.ContainsKey($name)) { $Runs[$name].Runs } else { 1 }; for ($j = 0; $j -lt $count; $j++) { $name } })
    @($first) + @(for ($i = 0; $i -lt $Repeat; $i++) { $round })
}

# The harness text with its $Tests list replaced by these cue names, one per line
function Set-GameTestList([string] $HarnessText, [string[]] $Names) {
    $list = "`n          " + ($Names -join ",`n          ") + "`n        "
    [regex]::Replace($HarnessText, $TestsListPattern, { param($m) $m.Groups[1].Value + $list + $m.Groups[3].Value })
}

# The release extension's Lua with its session line set: the gamestart to start (New) or the save
# to load (Load), and the save to write when MD asks (Save); empty ones are left out
function Set-ReleaseSession([string] $LuaText, $Session) {
    $pattern = '(?m)^local session = [^\r\n]*'
    if ($LuaText -notmatch $pattern) { throw 'no session line (local session = ...) in the release extension''s Lua' }
    $fields = @(foreach ($key in 'New', 'Load', 'Save') { if ($Session.$key) { "$($key.ToLower()) = `"$($Session.$key)`"" } })
    $line = "local session = { $($fields -join ', ') }"
    [regex]::Replace($LuaText, $pattern, { param($m) $line })
}

# The game tests' autostart Lua with its gamestart set to nil, so it starts nothing: a release
# session loads a save instead
function Disable-TestAutostart([string] $LuaText) {
    $pattern = '(?m)^local gamestart = "[^"]*"'
    if ($LuaText -notmatch $pattern) { throw 'no gamestart line (local gamestart = "...") in the game tests'' autostart' }
    [regex]::Replace($LuaText, $pattern, 'local gamestart = nil')
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

# Each release-run test's tally against its pass bar ($Bars: cue name -> @{ Runs; Needed }, from
# Get-ReleaseRuns), in the order first seen: Met counts its runs that held their invariants (PASS)
# and didn't miss their outcome, of the Runs the bar asks for, so runs that never reported count
# against it. A test with no result at all has no tally (the run's own problems name it).
function Get-BarTally($Results, [hashtable] $Bars) {
    if (-not $Bars -or -not $Bars.Count) { return }
    $byKey = @{}
    foreach ($name in $Bars.Keys) { $byKey[(Get-TestKey $name)] = $Bars[$name] }
    foreach ($t in @(Get-TestTally $Results)) {
        $bar = $byKey[(Get-TestKey $t.Name)]
        if (-not $bar) { continue }
        $met = @($Results | Where-Object { $_.Name -eq $t.Name -and $_.Passed -and $_.Outcome -ne 'missed' }).Count
        [pscustomobject]@{ Name = $t.Name; Met = $met; Runs = $bar.Runs; Needed = $bar.Needed; Passed = ($met -ge $bar.Needed) }
    }
}

# A pass bar's tally as the reports show it
function Format-BarTally($Tally) { "$($Tally.Met) of $($Tally.Runs), needs $($Tally.Needed)" }

# The runner's own checks on the log, reported like game tests (tools/check_test_plan.py reads
# their names from the New-LogCheck calls): the mod loads after SWI, nothing in the log is an
# error or warning from our files, and no extension's files were read but the Egosoft DLCs', SWI's
# and ours (the runner switches the others off)
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
    $allowed = if ($Run.Allowed.Count) { " ($($Run.Allowed.Count) allowed in this session)" } else { '' }
    New-LogCheck 'clean_log' (-not $Run.Errors.Count) "$count errors or warnings from our files in debuglog.txt$allowed" $Run.Errors
    $others = @($Run.Extensions | Where-Object { -not (Test-AllowedInSwiOnlyRun $_) })
    $swiRead = $Run.Extensions -contains $SwiFolder
    $detail = if ($others.Count) { "files read from other extensions: $($others -join ', ')" }
              elseif (-not $swiRead) { "no file read from SWI ($SwiFolder)" }
              else { "files read only from Egosoft DLCs and $(@($Run.Extensions | Where-Object { $_ -notlike 'ego_dlc_*' }) -join ', ')" }
    New-LogCheck 'swi_only_run' ($swiRead -and -not $others.Count) $detail
}

# A release check of a save handed from one session to the next (-Release): the earlier session
# saved, with the mod on or off; the later one loaded that save with it the other way, finished,
# ran at least one of its $What ('tests' or 'checks'), all passing, with no errors or warnings
# from our files in its log. Returns whether it passed and the check's detail; each caller names
# its check in New-LogCheck, where tools/check_test_plan.py reads the name
function Get-SaveHandoff($Saver, [int] $SaverSession, [bool] $ModInSaver, $Loader, [string] $What) {
    $loaderSession = $SaverSession + 1
    $modProblem = {
        param($Run, $Session, $On)
        if ($On -and $Run.Extensions -notcontains $ModId) { "session $Session read no files from $ModId, so the mod was off" }
        elseif (-not $On -and $Run.Extensions -contains $ModId) { "session $Session read files from $ModId, so the mod was on" }
    }
    $problems = @()
    if (-not $Saver.Saved) { $problems += "session $SaverSession saved nothing ($(if ($Saver.SaveFailed) { $Saver.SaveFailed } else { 'no SAVED line' }))" }
    $problems += @(& $modProblem $Saver $SaverSession $ModInSaver)
    if (-not $Loader.Loaded) { $problems += "session $loaderSession loaded no save" }
    elseif ($Saver.Saved -and $Loader.LoadingSave -ne $Saver.Saved) { $problems += "session $loaderSession loaded $($Loader.LoadingSave), not $($Saver.Saved)" }
    $problems += @(& $modProblem $Loader $loaderSession (-not $ModInSaver))
    if (-not $Loader.Done) { $problems += "session $loaderSession's $What didn't finish" }
    if (-not $Loader.Results.Count) { $problems += "session $loaderSession ran no $What" }
    $failed = @($Loader.Results | Where-Object { -not $_.Passed })
    if ($failed.Count) { $problems += "$($failed.Count) of session $loaderSession's $What failed: $(($failed | ForEach-Object { $_.Name }) -join ', ')" }
    if ($Loader.Errors.Count) { $problems += "$($Loader.Errors.Count) errors or warnings from our files in session $loaderSession's log" }
    $saved = if ($ModInSaver) { 'with the mod, loaded it without' } else { 'without the mod, loaded it with the mod' }
    $detail = if ($problems.Count) { ($problems -join '; ') + ';' }
              else { "saved $($Saver.Saved) $($saved): $($Loader.Results.Count) $What passed, no errors or warnings from our files" }
    [pscustomobject]@{ Passed = -not $problems.Count; Detail = $detail }
}

# The release check for an existing save (-Release): session 1 started a game without the mod and
# saved it, and session 2 loaded that save with the mod and ran the harness's tests on it
function Get-ExistingSaveCheck($Without, $With) {
    $handoff = Get-SaveHandoff -Saver $Without -SaverSession 1 -ModInSaver $false -Loader $With -What 'tests'
    New-LogCheck 'existing_save_loads' $handoff.Passed $handoff.Detail
}

# The release check for an uninstall (-Release): session 2 saved a game with the mod, and session
# 3 loaded that save without it and ran the release extension's checks on it
function Get-UninstallCheck($With, $Without) {
    $handoff = Get-SaveHandoff -Saver $With -SaverSession 2 -ModInSaver $true -Loader $Without -What 'checks'
    New-LogCheck 'save_plays_without_mod' $handoff.Passed $handoff.Detail
}

# Whether an extension folder belongs in an SWI-only run: an Egosoft DLC, SWI, the mod or a test
# extension
function Test-AllowedInSwiOnlyRun([string] $Folder) {
    $Folder -like 'ego_dlc_*' -or @($SwiFolder, $ModId, $TestExtensionId, $ReleaseExtensionId) -contains $Folder.ToLower()
}

# The ids of the extensions installed in an extensions folder that don't belong in an SWI-only run
# (each one's id is in its content.xml, and the profile's content.xml switches them by id). One
# whose content.xml can't be read is skipped with a warning; if X4 loads it anyway, swi_only_run fails
function Get-OtherExtensions([string] $ExtensionsDir) {
    foreach ($dir in @(Get-ChildItem $ExtensionsDir -Directory | Where-Object { -not (Test-AllowedInSwiOnlyRun $_.Name) })) {
        $file = Join-Path $dir.FullName 'content.xml'
        if (-not (Test-Path $file)) { continue }
        $id = try { ([xml] (Get-Content $file -Raw)).content.id } catch { $null }
        if ($id) { $id } else { Write-Warning "Can't read the extension id in $file; leaving it as the profile has it" }
    }
}

# Adds the log checks to a run read from the finished log, as results it expects; returns them
function Add-LogChecks($Run) {
    $checks = @(Get-LogChecks $Run)
    $Run.Results = @($Run.Results) + $checks
    $Run.Expected += $checks.Count
    $checks
}

# Every way a run can fail, as messages; empty means it passed. $Bars: the release tier's pass bars
# (Get-BarTally), each failing the run when its test falls below it
function Get-RunProblems($Run, [string] $Ending, [hashtable] $Bars = @{}) {
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
    foreach ($t in @(Get-BarTally $Run.Results $Bars | Where-Object { -not $_.Passed })) {
        $problems += "$($t.Name) below its pass bar: $(Format-BarTally $t)"
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

# The game test tiers and each one's time budget, for the run from the game's launch to its quit
# (docs/testing.md, Game test tiers): make game-test is the PR tier, and -ReleaseTier
# (make game-test RELEASE=1) the release tier
$Tiers = [ordered]@{
    pr = [pscustomobject]@{ Name = 'PR'; Seconds = 300; Command = 'make game-test'; Advice = 'move a slow test to `$ReleaseOnly` in the harness (docs/testing.md, Game test tiers)' }
    release = [pscustomobject]@{ Name = 'release'; Seconds = 1800; Command = 'make game-test RELEASE=1'; Advice = 'speed up the slowest tests (docs/testing.md, Game test tiers)' }
}

# The report's lines on a tier run's tier, the release-only tests it skipped, and its budget, with a
# warning when the run was over it (a warning only: the run still passes). None for selections and
# release sessions, which have no tier.
function Get-TierLines($Info) {
    if (-not $Info.Tier) { return }
    $tier = $Tiers[$Info.Tier]
    $budget = "budget $($tier.Seconds / 60) minutes"
    $skipped = @($Info.Skipped)
    $names = @($skipped | ForEach-Object { '`' + $_ + '`' }) -join ', '
    if ($Info.Tier -eq 'release') { "Release tier (``$($tier.Command)``): every test, $budget." }
    elseif ($skipped.Count) { "PR tier (``$($tier.Command)``), $budget. Skipped $($skipped.Count) release-only tests, which ``$($Tiers.release.Command)`` runs: $names." }
    else { "PR tier (``$($tier.Command)``), $budget." }
    $warning = Get-BudgetWarning $Info
    if ($warning) { ''; $warning }
}

# The warning for a tier run over its tier's budget, in Markdown; nothing within it, or with no tier
function Get-BudgetWarning($Info) {
    if (-not $Info.Tier) { return }
    $tier = $Tiers[$Info.Tier]
    if ($Info.DurationSeconds -gt $tier.Seconds) {
        "**Over the $($tier.Name) tier's $($tier.Seconds / 60)-minute budget** ($(Format-Seconds $Info.DurationSeconds)): $($tier.Advice)."
    }
}

# Seconds from the game's launch to the first test, about (#195)
$GameStartSeconds = 55
# A selection may hold the game lock for about one PR-tier run (docs/testing.md, Keep each hold
# short)
$HoldBudgetSeconds = $Tiers.pr.Seconds

# Seconds from a delay's exact="<n>s", the only form the harness's timeouts take; anything else
# stops the check rather than guess
function ConvertFrom-Delay([string] $Exact, [string] $What) {
    if ($Exact -notmatch '^(\d+(\.\d+)?)s$') { throw "Can't read $What's delay, $Exact, for the hold check: give it in seconds, as exact=""<n>s""" }
    [double] $Matches[1]
}

# A test run's worst case in seconds of real time. A test that reports from its own actions (no
# sub-cues) takes none. Otherwise it's its <Name>_Timeout cue's delay, which counts from the test's
# start whatever cue it sits under (a sub-cue's delay counts from its parent's activation, not after
# the parent's delay: docs/research/automated-game-testing.md), in game time: a combat test
# (MarkCombatTest first) runs at 1x, every other test at $Seta, the harness's SETA factor. A test
# with no timeout cue counts as the whole hold budget, since nothing bounds it.
function Get-TestCeiling([xml] $Harness, [string] $Name, [double] $Seta) {
    $cue = $Harness.SelectSingleNode("//cue[@name='$Name']")
    if (-not $cue.SelectSingleNode('./cues')) { return 0 }
    $delay = $cue.SelectSingleNode(".//cue[@name='$($Name)_Timeout']/delay")
    if (-not $delay) { return $HoldBudgetSeconds }
    $seconds = ConvertFrom-Delay $delay.exact "$($Name)_Timeout"
    $first = $cue.SelectSingleNode('./actions/*[1]')
    $combat = $first.LocalName -eq 'run_actions' -and $first.ref -eq 'MarkCombatTest'
    if ($combat) { $seconds } else { $seconds / $Seta }
}

# The SETA factor the harness's Begin cue sets, or 1x without one
function Get-SetaFactor([xml] $Harness) {
    $factor = $Harness.SelectSingleNode("//cue[@name='Begin']//set_timewarp_factor")
    if ($factor) { ConvertFrom-Delay $factor.factor 'the SETA factor' } else { 1 }
}

# The hold estimates make game-proof sizes its chunks from (-HoldEstimateOnly): the budget, the
# game's start and each named test's worst case for one run, by the name given ($Test, as -Test
# takes it). A $FirstOnlyTests test is refused, since a run can't repeat it.
function Get-HoldEstimates([string] $HarnessText, [string[]] $Test) {
    $harness = [xml] $HarnessText
    $seta = Get-SetaFactor $harness
    $available = @(Get-GameTestNames $HarnessText)
    $names = @($Test | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $tests = @(foreach ($name in $names) {
        $cue = @(Resolve-GameTestSelection $available @($name) 1)[0]
        if ($FirstOnlyTests -contains $cue) { throw "$cue runs once, first, in any run, so a proof can't repeat it" }
        [ordered]@{ name = $name; seconds = Get-TestCeiling $harness $cue $seta }
    })
    [ordered]@{ budget = $HoldBudgetSeconds; gameStart = $GameStartSeconds; tests = $tests }
}

# Why this selection ($TestList, the cue names in run order) can't hold the game lock, or nothing:
# its worst case, the game's start and each run's ceiling, is over the hold budget (docs/testing.md,
# Keep each hold short). A single test run (besides $FirstOnlyTests) passes, since it can't be
# split.
function Get-HoldRefusal([string] $HarnessText, [string[]] $TestList) {
    $harness = [xml] $HarnessText
    $runs = @($TestList | Where-Object { $FirstOnlyTests -notcontains $_ })
    if ($runs.Count -le 1) { return }
    $seta = Get-SetaFactor $harness
    $total = $GameStartSeconds
    $parts = @("$(Format-Seconds $GameStartSeconds) game start")
    foreach ($group in ($TestList | Group-Object -NoElement)) {
        $ceiling = Get-TestCeiling $harness $group.Name $seta
        if (-not $ceiling) { continue }
        $total += $group.Count * $ceiling
        $parts += "$($group.Name) $($group.Count) x $(Format-Seconds $ceiling)"
    }
    if ($total -le $HoldBudgetSeconds) { return }
    "This selection could hold the game for up to $(Format-Seconds $total), over the $($HoldBudgetSeconds / 60)-minute hold budget ($($parts -join ', ')). " +
    'Split the batch into smaller runs (make game-proof TEST=<tests> RUNS=<n> LABEL=<batch> does it for you), each rejoining the back of the line, so others get the game between them (docs/testing.md, Keep each hold short), ' +
    'with -RunsLabel <batch> on each and -RunsAppend on each after the first so their traces add up as one batch, or pass -LongHold if the long hold is meant.'
}

# The Markdown report for a PR comment. Its first line is a hidden marker that
# tools/post-game-test-report.sh reads to check the report matches the PR's commit.
# $Info: Commit, Branch, Dirty, StartedAt (datetime), DurationSeconds, and optionally Phases
# (an ordered list of @{ Name; Seconds }, from Get-RunPhases), Selected (a -Test or -Repeat run,
# marked so tools/post-game-test-report.sh won't post it as the whole suite), Tier ('pr' or
# 'release', for a run of the whole tier), Skipped (the release-only tests a PR-tier run left out)
# and Bars (the release tier's pass bars, from Get-ReleaseRuns).
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
        "<!-- apirateslife-game-tests commit=$commit dirty=$dirty result=$(if ($ok) { 'pass' } else { 'fail' }) passed=$passed total=$total$(if ($Info.Selected) { ' selected=true' })$(if ($Info.Release) { ' release=true' }) -->"
        "### Game tests: $(if ($ok) { 'passed' } else { 'FAILED' }), $passed of $total"
        ''
        if ($Info.Selected) { 'Selected tests only (`-Test`, `-Repeat`), not the whole suite.'; '' }
        if ($Info.Release) { 'Release sessions (`-Release`): a save made without the mod, loaded with it, then saved and loaded without it. Not the game test suite.'; '' }
        "Commit ``$short`` on ``$($Info.Branch)``$(if ($Info.Dirty) { ' **plus uncommitted changes**' }), X4 $(if ($Run.GameVersion) { $Run.GameVersion } else { 'version unknown' }), ${minutes} min ${seconds} s, $($Info.StartedAt.ToString('yyyy-MM-dd HH:mm'))"
        ''
        if ($Info.Tier) { Get-TierLines $Info; '' }
        '| Test | Result | Detail |'
        '| --- | --- | --- |'
    )
    foreach ($r in $Run.Results) {
        $detail = ($r.Detail -replace '\|', '\|')
        $outcome = if ($r.Outcome) { ", outcome $($r.Outcome)" } else { '' }
        $lines += "| ``$($r.Name)`` | $(if ($r.Passed) { 'PASS' } else { '**FAIL**' })$outcome | $detail |"
    }
    $bars = @(Get-BarTally $Run.Results $Info.Bars)
    if ($bars.Count) {
        $lines += ''
        $lines += '| Release-run test | Passes | Result |'
        $lines += '| --- | --- | --- |'
        foreach ($t in $bars) { $lines += "| ``$($t.Name)`` | $(Format-BarTally $t) | $(if ($t.Passed) { 'pass' } else { '**FAIL**' }) |" }
    }
    $barred = @($bars | ForEach-Object { $_.Name })
    $tallies = @(Get-RepeatTally $Run.Results | Where-Object { $barred -notcontains $_.Name })
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
        $lines += $(if ($Run.SetaDrops) { "SETA dropped $($Run.SetaDrops) times during the run (switched back on each time)." } else { 'SETA never dropped outside the combat tests, which switch it off on purpose.' })
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
    # -disablesound: the runs play no sound. It changes only this launch, not the profile's config.xml
    "-skipintro -disablesound -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid $ProfileId"
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
    Set-ExtensionsEnabled $ContentXml $Ids 'true'
}

# Switches these extensions off in a profile's content.xml (made if missing), keeping other entries
function Disable-Extensions([string] $ContentXml, [string[]] $Ids) {
    Set-ExtensionsEnabled $ContentXml $Ids 'false'
}

# Sets enabled="<$Enabled>" on these extensions' entries in a profile's content.xml, adding any missing
function Set-ExtensionsEnabled([string] $ContentXml, [string[]] $Ids, [string] $Enabled) {
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
        $entry.SetAttribute('enabled', $Enabled)
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
            Write-Host ("  {0} {1}{2}: {3}" -f $(if ($r.Passed) { 'PASS' } else { 'FAIL' }), $r.Name, $(if ($r.Outcome) { " (outcome $($r.Outcome))" }), $r.Detail)
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

# The release sessions (-Release), one game session each, in order: whether the mod is on (Mod; the
# game tests' extension needs it, so it's on with it), what the release extension starts (New),
# loads (Load) and saves (Save), the harness's tests to run with the mod (Tests), and the errors
# from our files its log may hold (AllowedErrors, as X4 logs them after the channel and time).
# Without the mod, the release extension runs its own checks on a loaded save that holds the
# harness's leftovers (ReleaseLeftovers); X4 logs that it can't import the running operation's
# wingman's capture order. Every save is named apirateslife_release_<n>.
function Get-ReleaseSessions {
    @(
        [pscustomobject]@{ Number = 1; Name = 'a new game without the mod, saved'; Mod = $false
                           New = 'apirateslife_release_test'; Load = ''; Save = 'apirateslife_release_1'; Tests = @(); AllowedErrors = @() }
        [pscustomobject]@{ Number = 2; Name = 'that save loaded with the mod, capture tests run on it, saved again'; Mod = $true
                           New = ''; Load = 'apirateslife_release_1'; Save = 'apirateslife_release_2'
                           Tests = @('ConfigAppliedOnStart', 'CaptureStartAndDestroyed', 'ReleaseLeftovers'); AllowedErrors = @() }
        [pscustomobject]@{ Number = 3; Name = 'the second save loaded without the mod, and played'; Mod = $false
                           New = ''; Load = 'apirateslife_release_2'; Save = ''; Tests = @()
                           AllowedErrors = @(
                               "Error importing AI order [0xc]: Order definition 'APiratesLife_Capture' not found"
                               "Error on AI director import: AI script name 'order.apirateslife.capture' not found") }
    )
}

# The run with the errors its session allows moved out of Errors, into Allowed: lines whose text
# after the log channel and time is exactly one of the session's AllowedErrors
function Remove-AllowedErrors($Run, $Session) {
    $allowed = @($Session.AllowedErrors)
    $isAllowed = { param($line) $allowed -ccontains ($line -replace '^\[[^\]]*\]\s+[\d.]+\s+', '') }
    $Run.Allowed = @($Run.Errors | Where-Object { & $isAllowed $_ })
    $Run.Errors = @($Run.Errors | Where-Object { -not (& $isAllowed $_) })
    $Run
}

# A session's log checks, named for the session; the load order only where the mod was on
function Get-SessionLogChecks($Run, $Session) {
    foreach ($check in @(Get-LogChecks $Run)) {
        if (-not $Session.Mod -and $check.Name -eq 'load_order_after_swi') { continue }
        $check.Name = "$($check.Name) (session $($Session.Number))"
        $check
    }
}

# The release sessions' runs as one: started and done only if every session was, their results and
# errors in session order
function Join-SessionRuns($Runs) {
    $Runs = @($Runs)
    $all = { param($property) -not @($Runs | Where-Object { -not $_.$property }).Count }
    [pscustomobject]@{
        Started = & $all 'Started'
        Expected = ($Runs | Measure-Object -Property Expected -Sum).Sum
        Done = & $all 'Done'
        Results = @($Runs | ForEach-Object { $_.Results })
        Errors = @($Runs | ForEach-Object { $_.Errors })
        GameVersion = @($Runs | Where-Object { $_.GameVersion } | ForEach-Object { $_.GameVersion }) | Select-Object -First 1
        MenuReady = & $all 'MenuReady'
        SetaDrops = ($Runs | Measure-Object -Property SetaDrops -Sum).Sum
    }
}

# Dot-sourced by the tests for the functions above
if ($MyInvocation.InvocationName -eq '.') { return }

. (Join-Path $PSScriptRoot 'game-lock.ps1')

if ($Release -and ($Test -or $Repeat -ne 1 -or $KeepExtension -or $ReleaseTier -or $RunsLabel)) {
    throw '-Release runs its own sessions, so it takes no -Test, -Repeat, -KeepExtension, -ReleaseTier or -RunsLabel'
}
if ($RunsAppend -and -not $RunsLabel) {
    throw '-RunsAppend adds to a labelled batch, so it needs -RunsLabel'
}
if ($RunsLabel -and ($RunsLabel -notmatch '^[A-Za-z0-9._-]+$' -or $RunsLabel -match '^\.+$')) {
    throw "-RunsLabel must be a folder name: letters, digits, '.', '_' and '-' (got '$RunsLabel')"
}
# The release tier's budget is longer than the default timeout: allow it, and 10 minutes over it
if ($ReleaseTier -and -not $PSBoundParameters.ContainsKey('TimeoutSeconds')) { $TimeoutSeconds = $Tiers.release.Seconds + 600 }

$root = Split-Path $PSScriptRoot -Parent
# The tests to run, checked first, so an unknown -Test name or a hold over the budget stops make
# game-test before it queues for the game lock: a PR-tier run leaves out the release-only tests, a
# -ReleaseTier run doesn't, and -Test and -Repeat pick from them. $testList is $null when the
# harness's own list runs as it is.
$harnessPath = "md/$TestExtensionId.xml"
$harnessText = Get-Content (Join-Path $root "tests/game/$TestExtensionId/$harnessPath") -Raw
$available = @(Get-GameTestNames $harnessText)
$skipped = if ($ReleaseTier -or $Release) { @() } else { @(Get-GameTestNames $harnessText 'ReleaseOnly') }
$isSelection = [bool] ($Test -or $Repeat -ne 1)
$tier = if ($isSelection -or $Release) { $null } elseif ($ReleaseTier) { 'release' } else { 'pr' }
# The release tier runs each $ReleaseRuns test its runs and holds it to its pass bar
$bars = if ($tier -eq 'release') { Get-ReleaseRuns $harnessText } else { @{} }
$testList = $null
if ($isSelection -or $skipped.Count -or $bars.Count) { $testList = @(Resolve-GameTestSelection $available $Test $Repeat $skipped $bars) }
# make game-proof's estimates: each test's one run, whatever the selection adds up to
if ($HoldEstimateOnly) {
    if (-not $Test) { throw '-HoldEstimateOnly estimates the -Test tests, so it needs -Test' }
    ConvertTo-Json -Compress -Depth 4 (Get-HoldEstimates $harnessText $Test)
    exit 0
}
# A selection mustn't hold the game lock for long unless it says so (docs/testing.md, Keep each
# hold short); a whole tier and the release sessions have their own budgets
if ($isSelection -and -not $LongHold) {
    $refusal = Get-HoldRefusal $harnessText $testList
    if ($refusal) { throw $refusal }
}
if ($HoldCheckOnly) { exit 0 }
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

$extensionsDir = Join-Path $X4Path 'extensions'
$arguments = Get-LaunchArguments $ProfileId
$seen = @{}

# Writes an installed file back through $Transform (its text in, the new text out)
function Edit-InstalledFile([string] $Path, [scriptblock] $Transform) {
    [IO.File]::WriteAllText($Path, (& $Transform (Get-Content $Path -Raw)))
}

# One game session: switches the extensions it needs on and off in the test profile (a release
# session), installs and rewrites the test extensions, starts the game and watches the log until
# the session ends, then removes the extensions again. $Session is $null for a plain run. Returns
# the session's Run (read from its log), how it ended and how long it took.
function Invoke-GameSession($Session) {
    # The game tests' extension needs the mod, so a release session without it runs without them
    $harness = -not $Session -or $Session.Mod
    $ids = @()
    if ($harness) { $ids += $TestExtensionId }
    $sessionSeen = $seen
    if ($Session) {
        $ids += $ReleaseExtensionId
        $sessionSeen = @{}
        Write-Host "Release session $($Session.Number): $($Session.Name)"
        Enable-Extensions $contentXml @($ReleaseExtensionId)
        if ($Session.Mod) { Enable-Extensions $contentXml @($ModId, $TestExtensionId) }
        else { Disable-Extensions $contentXml @($ModId, $TestExtensionId) }
    }
    $sessionStart = Get-Date
    $game = $null
    $installed = @()
    $ending = ''
    try {
        Update-GameLock $gameLock
        foreach ($id in $ids) {
            $dir = Join-Path $extensionsDir $id
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
            $installed += $dir
            Copy-Item (Join-Path $root "tests/game/$id") $dir -Recurse
        }
        $tests = Join-Path $extensionsDir $TestExtensionId
        if ($null -ne $testList) {
            Edit-InstalledFile (Join-Path $tests $harnessPath) { param($t) Set-GameTestList $t $testList }
            if ($isSelection) { Write-Host "Running $($testList.Count) selected tests: $(($testList | Select-Object -Unique) -join ', '), $Repeat times" }
        }
        if ($bars.Count) { Write-Host "Release tier: running $(@($bars.Keys | Sort-Object | ForEach-Object { "$_ $($bars[$_].Runs) times" }) -join ', ')" }
        if ($tier -eq 'pr' -and $skipped.Count) { Write-Host "PR tier: skipping $($skipped.Count) release-only tests ($($skipped -join ', ')); RELEASE=1 runs them" }
        if ($Session) {
            Edit-InstalledFile (Join-Path $extensionsDir "$ReleaseExtensionId/ui/$ReleaseExtensionId.lua") { param($t) Set-ReleaseSession $t $Session }
            if ($harness) {
                Edit-InstalledFile (Join-Path $tests $harnessPath) { param($t) Set-GameTestList $t $Session.Tests }
                Edit-InstalledFile (Join-Path $tests 'ui/apirateslife_tests_autostart.lua') { param($t) Disable-TestAutostart $t }
            }
        }
        # A stale log would report the previous run; keep it out of the way instead
        if (Test-Path $LogPath) { Move-Item $LogPath (Join-Path $profileDir 'debuglog.previous.txt') -Force }

        Write-Host "Starting $GameExe $arguments; results go to $LogPath"
        $game = Start-Process -FilePath $GameExe -ArgumentList $arguments -WorkingDirectory $X4Path -PassThru
        $ending = Watch-GameRun $game $LogPath $PollSeconds $TimeoutSeconds $LaunchTimeoutSeconds $ProfileId $gameLock $sessionStart $sessionSeen
        # The tests quit the game themselves; give it a moment, then close it
        if (-not $game.HasExited -and ($ending -ne 'finished' -or -not $game.WaitForExit(30000))) {
            Write-Host "Closing the game"
            Stop-Process -Id $game.Id -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        if ($game -and -not $game.HasExited) { Stop-Process -Id $game.Id -Force -ErrorAction SilentlyContinue }
        foreach ($dir in @($installed | Where-Object { -not $KeepExtension })) {
            # The game may still hold files for a moment after exiting
            for ($i = 0; $i -lt 10 -and (Test-Path $dir); $i++) {
                Update-GameLock $gameLock
                try { Remove-Item $dir -Recurse -Force } catch { Start-Sleep -Seconds 1 }
            }
        }
    }
    # Each release session's log is kept: the next session's start moves debuglog.txt away
    if ($Session -and (Test-Path $LogPath)) { Copy-Item $LogPath (Join-Path $profileDir "debuglog.release-$($Session.Number).txt") -Force }
    [pscustomobject]@{ Run = Read-GameTestLog (Read-SharedFile $LogPath); Ending = $ending; Seconds = ((Get-Date) - $sessionStart).TotalSeconds }
}

# A plain run is one session, $null (an if statement would unroll @($null) to nothing)
$sessions = [object[]]::new(1)
if ($Release) { $sessions = @(Get-ReleaseSessions) }
$sessionResults = @()
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
    # Every run is SWI-only: other mods installed in the game folder start on in a profile that
    # doesn't list them, so switch them off in the test profile (the swi_only_run log check)
    $others = @(Get-OtherExtensions $extensionsDir)
    if ($others.Count) {
        Disable-Extensions $contentXml $others
        Write-Host "Off in the test profile, so the run is SWI-only: $($others -join ', ')"
    }
    # A save left by an earlier release run would let a session load it after its own save failed
    if ($Release) { Remove-Item (Join-Path $profileDir 'save/apirateslife_release_*') -Force -ErrorAction SilentlyContinue }

    $startedAt = Get-Date
    foreach ($session in $sessions) {
        $result = Invoke-GameSession $session
        $sessionResults += $result
        if ($session -and $session.Save -and -not $result.Run.Saved) {
            Write-Host "Session $($session.Number) saved nothing, so the sessions after it can't run"
            break
        }
    }
}
finally {
    # The test profile as a plain game test run needs it
    if ($Release -and (Test-Path $contentXml)) {
        Enable-Extensions $contentXml @($ModId, $TestExtensionId)
        Disable-Extensions $contentXml @($ReleaseExtensionId)
    }
    Exit-GameLock $gameLock
}

$total = ((Get-Date) - $startedAt).TotalSeconds
if ($Release) {
    $runs = @(for ($i = 0; $i -lt $sessionResults.Count; $i++) { Remove-AllowedErrors $sessionResults[$i].Run $sessions[$i] })
    $run = Join-SessionRuns $runs
    $checks = @(for ($i = 0; $i -lt $runs.Count; $i++) { Get-SessionLogChecks $runs[$i] $sessions[$i] })
    # A session that didn't run (the one before it saved nothing) reads as an empty log
    $runOrEmpty = { param($i) if ($runs.Count -gt $i) { $runs[$i] } else { Read-GameTestLog @() } }
    $checks += Get-ExistingSaveCheck $runs[0] (& $runOrEmpty 1)
    $checks += Get-UninstallCheck (& $runOrEmpty 1) (& $runOrEmpty 2)
    $run.Results = @($run.Results) + $checks
    $run.Expected += $checks.Count
    $ending = @(for ($i = 0; $i -lt $sessionResults.Count; $i++) { "session $($i + 1): $($sessionResults[$i].Ending)" }) -join ', '
    $phases = @(for ($i = 0; $i -lt $sessionResults.Count; $i++) {
        [pscustomobject]@{ Name = "Session $($i + 1): $($sessions[$i].Name)"; Seconds = $sessionResults[$i].Seconds }
    }) + @([pscustomobject]@{ Name = '**Total**'; Seconds = $total })
}
else {
    $run = $sessionResults[0].Run
    $ending = $sessionResults[0].Ending
    $checks = @(Add-LogChecks $run)
    $phases = if ($seen.Count) { @(Get-RunPhases $seen $total) } else { @() }
    # Each test run's trace, next to the report (a release run keeps its sessions' whole logs instead)
    $runsDir = Join-Path (Split-Path $MarkdownPath -Parent) 'runs'
    if ($RunsLabel) { $runsDir = Join-Path $runsDir $RunsLabel }
    $written = Write-GameTestRunLogs (Split-GameTestRuns (Read-SharedFile $LogPath)) $runsDir -Append:$RunsAppend
}
foreach ($c in $checks) {
    Write-Host ("  {0} {1}: {2}" -f $(if ($c.Passed) { 'PASS' } else { 'FAIL' }), $c.Name, $c.Detail)
}
$problems = @(Get-RunProblems $run $ending $bars)
New-Item -ItemType Directory -Force -Path (Split-Path $ReportPath -Parent) | Out-Null
[IO.File]::WriteAllText($ReportPath, (ConvertTo-JUnitXml $run $problems))
$info = @{ Commit = $Commit; Branch = $Branch; Dirty = [bool] $Dirty; StartedAt = $startedAt; DurationSeconds = $total; Phases = $phases; Selected = $isSelection; Release = [bool] $Release; Tier = $tier; Skipped = $skipped; Bars = $bars }
New-Item -ItemType Directory -Force -Path (Split-Path $MarkdownPath -Parent) | Out-Null
[IO.File]::WriteAllText($MarkdownPath, (ConvertTo-MarkdownReport $run $problems $info) + "`n")

$passed = @($run.Results | Where-Object { $_.Passed }).Count
foreach ($e in $run.Errors) { Write-Host "  log error: $e" }
if ($phases) { Write-Host ("Timings: " + (($phases | ForEach-Object { "$($_.Name -replace '\*', '') $(Format-Seconds $_.Seconds)" }) -join '; ')) }
foreach ($t in @(Get-BarTally $run.Results $bars)) { Write-Host "Release runs: $($t.Name): $(Format-BarTally $t)" }
foreach ($t in (Get-RepeatTally $run.Results)) { Write-Host "Repeated: $($t.Name): $($t.Failed) of $($t.Runs) runs failed" }
if ($run.Started -and $run.SetaDrops) { Write-Host "SETA dropped $($run.SetaDrops) times during the run" }
$warning = Get-BudgetWarning $info
if ($warning) { Write-Host "WARNING: $($warning -replace '\*\*', '')" }
if (-not $Release) { Write-Host "Run traces: $written files $(if ($RunsAppend) { 'added to' } else { 'in' }) $runsDir (summary: node tools/summarize-game-runs.ts [--totals] <folder>)" }
if ($problems.Count) {
    Write-Host "GAME TESTS FAILED ($passed passed): $($problems -join '; ')"
    Write-Host "Report: $MarkdownPath"
    exit 1
}
Write-Host "Game tests passed ($passed of $($run.Expected)). Report: $MarkdownPath"
