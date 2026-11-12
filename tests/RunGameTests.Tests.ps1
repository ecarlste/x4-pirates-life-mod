# Tests for tools/run-game-tests.ps1 as a whole: how a run against a fake game ends and what it
# reports. The checks before the game starts are in RunGameTestsProfile.Tests.ps1, the runner's
# functions in GameTests.Tests.ps1; the files run in parallel under tests/run.sh.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $PSScriptRoot 'RunGameTestsSandbox.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
}

Describe 'run-game-tests.ps1' {
    BeforeEach { New-RunSandbox }
    AfterEach { Remove-RunSandbox }

    It 'passes a passing run, with the test extension installed only while the game runs' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*Game tests passed (2 of 2)*'
        # Each result as the run reports it live, not only in the summary
        $r.Output | Should -BeLike '*PASS eject_chance_doubled: 5 cases*'
        $r.Output | Should -BeLike '*PASS pilot_bail_intact: hull 100%, 4 equipment kept, pilot skill 38*'
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
