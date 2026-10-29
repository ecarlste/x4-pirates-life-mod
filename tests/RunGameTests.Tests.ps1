# Tests for tools/run-game-tests.ps1 as a whole: runs against a fake game that writes a prepared
# debuglog.txt instead of playing the tests. The runner's functions are tested in
# GameTests.Tests.ps1; the two files run in parallel under tests/run.sh.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
    . $script:Runner

    # Lines as X4 writes them: MD debug_text under [Scripts], Lua DebugError under [=ERROR=]
    $script:PassingLog = @(
        '[General] 0.00 ======================================'
        '[=ERROR=] 2.50 [apirateslife-test] autostart: starting gamestart apirateslife_test'
        "[Init   ] 0.00 Starting new game using gamestart 'apirateslife_test' in 9.00 (611726)"
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
if defined FAKE_COPY copy /y "%FAKE_X4%\extensions\apirateslife_tests\md\apirateslife_tests.xml" "%FAKE_COPY%" >nul
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
[ -n "$FAKE_COPY" ] && cp "$FAKE_X4/extensions/apirateslife_tests/md/apirateslife_tests.xml" "$FAKE_COPY"
# exec, so closing the game kills the sleep too and nothing keeps the output open
[ -n "$FAKE_HANG" ] && exec sleep 20
cp "$FAKE_SOURCE_LOG" "$FAKE_LOGPATH"
'@
            & chmod +x $game
        }
        $game
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
        $markdown = Join-Path $root 'report.md'
        $runArgs = @('-X4Path', $x4, '-GameExe', $game, '-LogPath', $env:FAKE_LOGPATH, '-ReportPath', $report, '-MarkdownPath', $markdown,
                     '-PollSeconds', '0.2', '-Commit', '0123456789abcdef0123456789abcdef01234567', '-Branch', 'feature/x')
    }

    AfterEach {
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($v in 'FAKE_X4', 'FAKE_MARK', 'FAKE_SOURCE_LOG', 'FAKE_LOGPATH', 'FAKE_HANG', 'FAKE_COPY') { Remove-Item "env:$v" -ErrorAction SilentlyContinue }
    }

    It 'passes a passing run, with the test extension installed only while the game runs' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*Game tests passed (2 of 2)*'
        $r.ExitCode | Should -Be 0
        Get-TestFile $env:FAKE_MARK | Should -Be 'installed'
        Test-Path "$x4/extensions/apirateslife_tests" | Should -BeFalse
        ([xml] (Get-Content $report -Raw)).testsuite.failures | Should -Be '0'
        (Get-Content $markdown)[0] | Should -Be '<!-- apirateslife-game-tests commit=0123456789abcdef0123456789abcdef01234567 dirty=false result=pass passed=2 total=2 -->'
    }

    It 'marks the report dirty with -Dirty' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner ($runArgs + @('-Dirty'))
        $r.ExitCode | Should -Be 0
        (Get-Content $markdown)[0] | Should -BeLike '* dirty=true result=pass *'
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

    It 'moves a stale log from an earlier run aside' {
        Set-Content $env:FAKE_LOGPATH $script:PassingLog
        Set-Content $env:FAKE_SOURCE_LOG @('[General] 0.00 nothing here')
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*never started*'
        $r.ExitCode | Should -Be 1
        Get-Content (Join-Path $root 'debuglog.previous.txt') | Should -Be $script:PassingLog
    }

    It 'runs only the tests given with -Tests, and reports the rest as not needed' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $env:FAKE_COPY = Join-Path $root 'installed-tests.xml'
        $r = Invoke-Script $script:Runner ($runArgs + @('-Tests', 'pilot_bail_intact,eject_chance_doubled'))
        $r.ExitCode | Should -Be 0
        @(Get-GameTests $env:FAKE_COPY).Cue | Should -Be @('EjectChanceDoubled', 'PilotBailIntact')
        $all = @(Get-GameTests (Join-Path $script:RepoRoot 'tests/game/apirateslife_tests/md/apirateslife_tests.xml')).Count
        (Get-Content $markdown)[0] | Should -BeLike "* passed=2 total=2 of=$all -->"
        (Get-Content $markdown -Raw).Contains("**Not needed for this change** ($($all - 2) of $all)") | Should -BeTrue
    }

    It 'refuses a test name nothing reports, before starting the game' {
        $r = Invoke-Script $script:Runner ($runArgs + @('-Tests', 'no_such_test'))
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -BeLike '*No game test reports no_such_test*'
        Test-Path $env:FAKE_MARK | Should -BeFalse
    }

    It 'writes a passing report without starting the game when no test is needed' {
        Remove-Item "$x4/extensions/apirateslife" -Recurse
        $r = Invoke-Script $script:Runner ($runArgs + @('-NoneNeeded'))
        $r.ExitCode | Should -Be 0
        $r.Output | Should -BeLike "*No game tests needed for this change; the game wasn't started*"
        Test-Path $env:FAKE_MARK | Should -BeFalse
        (Get-Content $markdown)[0] | Should -BeLike '* result=pass passed=0 total=0 of=*'
        ([xml] (Get-Content $report -Raw)).testsuite.failures | Should -Be '0'
    }

    It 'refuses to run when the mod is not deployed' {
        Remove-Item "$x4/extensions/apirateslife" -Recurse
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike "*isn't deployed*"
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_MARK | Should -BeFalse
    }
}
