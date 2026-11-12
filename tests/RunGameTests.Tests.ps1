# Tests for tools/run-game-tests.ps1 as a whole: how a run against a fake game ends and what it
# reports. The checks before the game starts are in RunGameTestsProfile.Tests.ps1, the runner's
# functions in GameTests.Tests.ps1; the files run in parallel under tests/run.sh.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $PSScriptRoot 'RunGameTestsSandbox.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
    # For Get-GameTestNames
    . $script:Runner
}

Describe 'run-game-tests.ps1' {
    BeforeEach { New-RunSandbox }
    AfterEach { Remove-RunSandbox }

    It 'passes a passing run, with the test extension installed only while the game runs' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*Game tests passed (4 of 4)*'
        # Each result as the run reports it live, not only in the summary
        $r.Output | Should -BeLike '*PASS fixture_test_a: 5 cases*'
        $r.Output | Should -BeLike '*PASS fixture_test_b: hull 100%, 4 equipment kept, pilot skill 38*'
        # The runner's own checks on the log, after the game's results
        $r.Output | Should -BeLike '*PASS load_order_after_swi: SWI read first for all 1 files both patch*'
        $r.Output | Should -BeLike '*PASS clean_log: no errors or warnings from our files in debuglog.txt*'
        $r.ExitCode | Should -Be 0
        Get-TestFile $env:FAKE_MARK | Should -Be 'installed'
        Test-Path "$x4/extensions/apirateslife_tests" | Should -BeFalse
        ([xml] (Get-Content $report -Raw)).testsuite.failures | Should -Be '0'
        (Get-Content $markdown)[0] | Should -Be '<!-- apirateslife-game-tests commit=0123456789abcdef0123456789abcdef01234567 dirty=false result=pass passed=4 total=4 -->'
    }

    It 'marks the report dirty with -Dirty' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner ($runArgs + @('-Dirty'))
        $r.ExitCode | Should -Be 0
        (Get-Content $markdown)[0] | Should -BeLike '* dirty=true result=pass *'
    }

    It 'fails a run with a failing test' {
        Set-Content $env:FAKE_SOURCE_LOG ($script:PassingLog -replace 'PASS fixture_test_a: 5 cases', 'FAIL fixture_test_a: 30 gave 30, expected 60;')
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*FAIL fixture_test_a: 30 gave 30, expected 60;*'
        $r.Output | Should -BeLike '*GAME TESTS FAILED (3 passed): 1 failed: fixture_test_a*'
        $r.ExitCode | Should -Be 1
    }

    It 'fails a run whose log has an error from the mod' {
        Set-Content $env:FAKE_SOURCE_LOG ($script:PassingLog + @("[=ERROR=] 50.00 No matching node for path '//do_if' in patch file 'extensions\apirateslife\aiscripts\move.claim.xml'. Skipping node."))
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*FAIL clean_log: 1 errors or warnings from our files in debuglog.txt*'
        $r.Output | Should -BeLike '*GAME TESTS FAILED (3 passed): 1 failed: clean_log*'
        $r.ExitCode | Should -Be 1
    }

    It 'runs only the selected tests, repeated, from a rewritten copy of the harness' {
        Set-Content $env:FAKE_SOURCE_LOG @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 3 tests'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS capture_wing_holds_fire: lowest hull 70%'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] FAIL capture_wing_holds_fire: lowest hull 54%'
            '[Scripts] 4.00 *** Context:x: [apirateslife-test] PASS capture_wing_holds_fire: lowest hull 71%'
            '[Scripts] 5.00 *** Context:x: [apirateslife-test] DONE passed=2 failed=1'
        )
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire', '-Repeat', '3', '-KeepExtension'))
        $r.Output | Should -BeLike '*Running 3 selected tests: CaptureWingHoldsFire x3*'
        $r.Output | Should -BeLike '*Repeated: capture_wing_holds_fire: 1 of 3 runs failed*'
        $r.Output | Should -BeLike '*failed: capture_wing_holds_fire, load_order_after_swi*'
        $r.ExitCode | Should -Be 1
        $installed = Get-Content "$x4/extensions/apirateslife_tests/md/apirateslife_tests.xml" -Raw
        Get-GameTestNames $installed | Should -Be @('CaptureWingHoldsFire', 'CaptureWingHoldsFire', 'CaptureWingHoldsFire')
        # The repo's harness is untouched
        Get-GameTestNames (Get-Content (Join-Path $script:RepoRoot 'tests/game/apirateslife_tests/md/apirateslife_tests.xml') -Raw) |
            Should -Contain 'BailRaisesBailed'
        (Get-Content $markdown)[0] | Should -BeLike '* selected=true -->'
    }

    It 'refuses an unknown test before anything changes, even with -PreflightOnly' {
        foreach ($extra in @(@('-Test', 'NoSuchTest'), @('-Test', 'NoSuchTest', '-PreflightOnly'))) {
            $r = Invoke-Script $script:Runner ($runArgs + $extra)
            $r.Output | Should -BeLike '*No game test named NoSuchTest*'
            $r.ExitCode | Should -Not -Be 0
            Test-Path $env:FAKE_ARGS | Should -BeFalse
            Test-Path "$x4/extensions/apirateslife_tests" | Should -BeFalse
        }
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
        Get-Content (Join-Path $profileDir 'debuglog.previous.txt') | Should -Be $script:PassingLog
    }

    It 'starts the game directly with the debug options and its own profile, and reads that profile''s log' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Be 0
        Get-TestFile $env:FAKE_ARGS | Should -Be '-skipintro -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid 90000301'
        $r.Output | Should -BeLike "*results go to $env:FAKE_LOGPATH*"
    }

    It 'fails when no log appears within the launch timeout' {
        $env:FAKE_HANG = '1'
        $r = Invoke-Script $script:Runner ($runArgs + @('-LaunchTimeoutSeconds', '1', '-TimeoutSeconds', '15'))
        $r.Output | Should -BeLike "*no $env:FAKE_LOGPATH within 1 s*"
        $r.ExitCode | Should -Be 1
    }
}
