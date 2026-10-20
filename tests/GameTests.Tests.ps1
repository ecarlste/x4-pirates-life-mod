# Tests for tools/run-game-tests.ps1: its log parsing and report, plus whole runs against a fake
# game that writes a prepared debuglog.txt instead of playing the tests.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
    . $script:Runner

    # Lines as X4 writes them: MD debug_text under [Scripts], Lua DebugError under [=ERROR=]
    $script:PassingLog = @(
        '[General] 0.00 ======================================'
        '[=ERROR=] 2.50 [apirateslife-test] autostart: starting gamestart apirateslife_test'
        '[General] 3.10 Could not find signature file extensions\apirateslife\md\apirateslife_bail.xml.sig'
        '[General] 3.11 Failed to verify the file signature for file extensions\apirateslife\md\apirateslife_bail.xml (error: 14)'
        '[Scripts] 40.01 *** Context:md.APiratesLife_Tests.Run<inst:2a1b>: [apirateslife-test] RUN START 2 tests'
        '[Scripts] 40.02 *** Context:md.APiratesLife_Bail.AdjustEjectChance: [apirateslife] bail check: null attacking null: chance 30 -> 60'
        '[Scripts] 40.03 *** Context:md.APiratesLife_Tests.Report<inst:2a1c>: [apirateslife-test] PASS eject_chance_doubled: 5 cases'
        '[Scripts] 44.00 *** Context:md.APiratesLife_Tests.Report<inst:2a1d>: [apirateslife-test] PASS pilot_bail_intact: hull 100%, 4 equipment kept, pilot skill 38'
        '[Scripts] 44.01 *** Context:md.APiratesLife_Tests.NextTest<inst:2a1e>: [apirateslife-test] DONE passed=2 failed=0'
    )

    function New-FakeGame([string] $Dir) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        if ($script:OnWindows) {
            $game = Join-Path $Dir 'fakegame.cmd'
            $body = @'
@echo off
if exist "%FAKE_X4%\extensions\apirateslife_tests\content.xml" echo installed>"%FAKE_MARK%"
if defined FAKE_HANG ping -n 20 127.0.0.1 >nul
copy /y "%FAKE_SOURCE_LOG%" "%FAKE_LOGPATH%" >nul
'@
            Set-Content $game ($body -replace "`r?`n", "`r`n") -Encoding Ascii
        }
        else {
            $game = Join-Path $Dir 'fakegame'
            Write-LfFile $game @'
#!/bin/sh
[ -f "$FAKE_X4/extensions/apirateslife_tests/content.xml" ] && echo installed > "$FAKE_MARK"
[ -n "$FAKE_HANG" ] && sleep 20
cp "$FAKE_SOURCE_LOG" "$FAKE_LOGPATH"
'@
            & chmod +x $game
        }
        $game
    }
}

Describe 'Read-GameTestLog' {
    It 'reads the start, every result and the end of a run' {
        $run = Read-GameTestLog $script:PassingLog
        $run.Started | Should -BeTrue
        $run.Expected | Should -Be 2
        $run.Done | Should -BeTrue
        $run.Results.Count | Should -Be 2
        $run.Results[1].Name | Should -Be 'pilot_bail_intact'
        $run.Results[1].Passed | Should -BeTrue
        $run.Results[1].Detail | Should -Be 'hull 100%, 4 equipment kept, pilot skill 38'
    }

    It 'reads a failure and its detail' {
        $run = Read-GameTestLog @('[Scripts] 1.00 *** Context:x: [apirateslife-test] FAIL claim_intact: hull 72%, expected 100%;')
        $run.Results[0].Passed | Should -BeFalse
        $run.Results[0].Detail | Should -Be 'hull 72%, expected 100%;'
    }

    It 'ignores signature warnings and its own markers, but not errors from the mod' {
        $run = Read-GameTestLog ($script:PassingLog + @(
            '[=ERROR=] 3.20 Error while applying patch to md/notifications.xml from extensions\apirateslife: selector matched no node'
            '[=ERROR=] 50.00 Error in MD cue md.APiratesLife_Tests.ClaimIntact: property lookup failed'
            '[=ERROR=] 51.00 Error in some other mod'
        ))
        $run.Errors.Count | Should -Be 2
        $run.Errors[0] | Should -BeLike '*applying patch*'
    }

    It 'returns an empty run for an empty log' {
        $run = Read-GameTestLog @()
        $run.Started | Should -BeFalse
        $run.Results.Count | Should -Be 0
    }
}

Describe 'Get-RunProblems' {
    It 'finds none in a passing run' {
        @(Get-RunProblems (Read-GameTestLog $script:PassingLog) 'finished').Count | Should -Be 0
    }

    It 'names failed tests' {
        $log = $script:PassingLog -replace 'PASS pilot_bail_intact', 'FAIL pilot_bail_intact'
        Get-RunProblems (Read-GameTestLog $log) 'finished' | Should -Contain '1 failed: pilot_bail_intact'
    }

    It 'reports a run that never started' {
        Get-RunProblems (Read-GameTestLog @()) 'timed out after 5 s' | Should -Contain 'the tests never started (timed out after 5 s)'
    }

    It 'reports an unfinished run and missing results' {
        $problems = Get-RunProblems (Read-GameTestLog $script:PassingLog[0..6]) 'the game exited early'
        $problems | Should -Contain "the run didn't finish (the game exited early)"
        $problems | Should -Contain '1 of 2 tests reported'
    }

    It 'reports errors from the mod' {
        $log = $script:PassingLog + @('[=ERROR=] 9.00 Error in MD cue md.APiratesLife_Bail.Bailed')
        Get-RunProblems (Read-GameTestLog $log) 'finished' | Should -Contain '1 errors from the mod in debuglog.txt'
    }
}

Describe 'ConvertTo-JUnitXml' {
    It 'writes one case per test plus the run, with failures escaped' {
        $log = $script:PassingLog -replace 'PASS pilot_bail_intact: hull 100%', 'FAIL pilot_bail_intact: hull <72%> & "worse"'
        $run = Read-GameTestLog $log
        $xml = [xml] (ConvertTo-JUnitXml $run (Get-RunProblems $run 'finished'))
        $xml.testsuite.tests | Should -Be '3'
        $xml.testsuite.failures | Should -Be '1'
        $case = $xml.testsuite.testcase | Where-Object { $_.name -eq 'pilot_bail_intact' }
        $case.failure.message | Should -BeLike 'hull <72%> & "worse"*'
    }

    It 'fails the run case when the run has problems' {
        $run = Read-GameTestLog @()
        $xml = [xml] (ConvertTo-JUnitXml $run (Get-RunProblems $run 'timed out after 5 s'))
        $xml.testsuite.failures | Should -Be '1'
        ($xml.testsuite.testcase | Where-Object { $_.name -eq 'run' }).failure.message | Should -BeLike '*never started*'
    }
}

Describe 'run-game-tests.ps1' {
    BeforeEach {
        $root = New-TestDir
        $x4 = Join-Path $root 'x4'
        Write-LfFile "$x4/extensions/apirateslife/content.xml" '<content id="apirateslife"/>'
        $env:FAKE_X4 = $x4
        $env:FAKE_MARK = Join-Path $root 'installed.txt'
        $env:FAKE_SOURCE_LOG = Join-Path $root 'source.log'
        $env:FAKE_LOGPATH = Join-Path $root 'debuglog.txt'
        $env:FAKE_HANG = $null
        $report = Join-Path $root 'results.xml'
        $game = New-FakeGame (Join-Path $root 'bin')
        $runArgs = @('-X4Path', $x4, '-GameExe', $game, '-LogPath', $env:FAKE_LOGPATH, '-ReportPath', $report, '-PollSeconds', '0.2')
    }

    AfterEach {
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($v in 'FAKE_X4', 'FAKE_MARK', 'FAKE_SOURCE_LOG', 'FAKE_LOGPATH', 'FAKE_HANG') { Remove-Item "env:$v" -ErrorAction SilentlyContinue }
    }

    It 'passes a passing run, with the test extension installed only while the game runs' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*Game tests passed (2 of 2)*'
        $r.ExitCode | Should -Be 0
        Get-TestFile $env:FAKE_MARK | Should -Be 'installed'
        Test-Path "$x4/extensions/apirateslife_tests" | Should -BeFalse
        ([xml] (Get-Content $report -Raw)).testsuite.failures | Should -Be '0'
    }

    It 'fails a run with a failing test' {
        Set-Content $env:FAKE_SOURCE_LOG ($script:PassingLog -replace 'PASS eject_chance_doubled: 5 cases', 'FAIL eject_chance_doubled: 30 gave 30, expected 60;')
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*FAIL eject_chance_doubled: 30 gave 30, expected 60;*'
        $r.Output | Should -BeLike '*GAME TESTS FAILED (1 passed): 1 failed: eject_chance_doubled*'
        $r.ExitCode | Should -Be 1
    }

    It 'fails when the game exits without finishing' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog[0..3]
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*the tests never started (the game exited early)*'
        $r.ExitCode | Should -Be 1
    }

    It 'closes the game and fails after the timeout' {
        $env:FAKE_HANG = '1'
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner ($runArgs + @('-TimeoutSeconds', '2'))
        $r.Output | Should -BeLike '*the tests never started (timed out after 2 s)*'
        $r.ExitCode | Should -Be 1
        Test-Path "$x4/extensions/apirateslife_tests" | Should -BeFalse
    }

    It 'replaces a stale log from an earlier run' {
        Set-Content $env:FAKE_LOGPATH $script:PassingLog
        Set-Content $env:FAKE_SOURCE_LOG @('[General] 0.00 nothing here')
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*never started*'
        $r.ExitCode | Should -Be 1
    }

    It 'refuses to run when the mod is not deployed' {
        Remove-Item "$x4/extensions/apirateslife" -Recurse
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike "*isn't deployed*"
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_MARK | Should -BeFalse
    }
}
