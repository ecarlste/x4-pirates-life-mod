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
        $r.Output | Should -BeLike '*Game tests passed (5 of 5)*'
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
        (Get-Content $markdown)[0] | Should -Be '<!-- apirateslife-game-tests commit=0123456789abcdef0123456789abcdef01234567 dirty=false result=pass passed=5 total=5 -->'
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
        $r.Output | Should -BeLike '*GAME TESTS FAILED (4 passed): 1 failed: fixture_test_a*'
        $r.ExitCode | Should -Be 1
    }

    It 'fails a run whose log has an error from the mod' {
        Set-Content $env:FAKE_SOURCE_LOG ($script:PassingLog + @("[=ERROR=] 50.00 No matching node for path '//do_if' in patch file 'extensions\apirateslife\aiscripts\move.claim.xml'. Skipping node."))
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike '*FAIL clean_log: 1 errors or warnings from our files in debuglog.txt*'
        $r.Output | Should -BeLike '*GAME TESTS FAILED (4 passed): 1 failed: clean_log*'
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
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire', '-Repeat', '3', '-KeepExtension', '-LongHold'))
        $r.Output | Should -BeLike '*Running 3 selected tests: CaptureWingHoldsFire, 3 times*'
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

    It 'runs the PR tier by default and the release tier with -ReleaseTier, and says which' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Be 0
        # The line goes on to name the skipped tests when the repo's $ReleaseOnly lists any
        (Get-Content $markdown) | Where-Object { $_.StartsWith('PR tier (`make game-test`), budget 5 minutes.') } |
            Should -Not -BeNullOrEmpty
        $r = Invoke-Script $script:Runner ($runArgs + @('-ReleaseTier', '-KeepExtension'))
        $r.ExitCode | Should -Be 0
        (Get-Content $markdown) | Should -Contain 'Release tier (`make game-test RELEASE=1`): every test, budget 30 minutes.'
        $harness = Join-Path $script:RepoRoot 'tests/game/apirateslife_tests/md/apirateslife_tests.xml'
        # Every test, each once here: a $ReleaseRuns test runs its runs in a row (the next test)
        Get-GameTestNames (Get-Content "$x4/extensions/apirateslife_tests/md/apirateslife_tests.xml" -Raw) | Select-Object -Unique |
            Should -Be (Get-GameTestNames (Get-Content $harness -Raw))
        # A selection is no tier's run
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire'))
        (Get-Content $markdown -Raw) | Should -Not -BeLike '*tier*'
    }

    It 'runs a $ReleaseRuns test its runs on the release tier, once on the PR tier, and holds it to its bar' {
        # A copy of the runner with a harness whose $ReleaseRuns lists this test alone, whatever the repo's lists
        $copy = Join-Path $root 'repo'
        foreach ($file in 'run-game-tests.ps1', 'deploy-config.ps1', 'game-lock.ps1') {
            Write-LfFile "$copy/tools/$file" (Get-Content (Join-Path $script:RepoRoot "tools/$file") -Raw)
        }
        Copy-Item (Join-Path $script:RepoRoot 'tests/game/apirateslife_tests') "$copy/tests/game/apirateslife_tests" -Recurse
        $harness = "$copy/tests/game/apirateslife_tests/md/apirateslife_tests.xml"
        Write-LfFile $harness ((Get-Content $harness -Raw) -replace '<set_value name="\$ReleaseRuns" exact="[^"]*"/>', "<set_value name=`"`$ReleaseRuns`" exact=`"[`n          [CaptureWingHoldsFire, 3, 2]`n        ]`"/>")
        $runner = "$copy/tools/run-game-tests.ps1"
        $installed = "$x4/extensions/apirateslife_tests/md/apirateslife_tests.xml"
        $wing = { param($outcome) "[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS capture_wing_holds_fire outcome=$($outcome): lowest hull 60%" }

        # PR tier: once, and a missed outcome passes
        Set-Content $env:FAKE_SOURCE_LOG ($script:PassingLog[0..6] + @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 1 tests'
            (& $wing 'missed')
            '[Scripts] 5.00 *** Context:x: [apirateslife-test] DONE passed=1 failed=0'
        ))
        $r = Invoke-Script $runner ($runArgs + @('-KeepExtension'))
        $r.ExitCode | Should -Be 0
        $r.Output | Should -BeLike '*PASS capture_wing_holds_fire (outcome missed): lowest hull 60%*'
        $r.Output | Should -Not -BeLike '*pass bar*'
        @(Get-GameTestNames (Get-Content $installed -Raw) | Where-Object { $_ -eq 'CaptureWingHoldsFire' }).Count | Should -Be 1

        # Release tier: three runs in a row, two met passes the bar
        $lines = { param([string[]] $outcomes) $script:PassingLog[0..6] + @('[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 3 tests') + @($outcomes | ForEach-Object { & $wing $_ }) + @('[Scripts] 5.00 *** Context:x: [apirateslife-test] DONE passed=3 failed=0') }
        Set-Content $env:FAKE_SOURCE_LOG (& $lines @('met', 'missed', 'met'))
        $r = Invoke-Script $runner ($runArgs + @('-ReleaseTier', '-KeepExtension'))
        $r.ExitCode | Should -Be 0
        $names = @(Get-GameTestNames (Get-Content $installed -Raw))
        $at = [array]::IndexOf($names, 'CaptureWingHoldsFire')
        $names[$at..($at + 3)] | Should -Be @('CaptureWingHoldsFire', 'CaptureWingHoldsFire', 'CaptureWingHoldsFire', $names[$at + 3])
        $names[$at + 3] | Should -Not -Be 'CaptureWingHoldsFire'
        $r.Output | Should -BeLike '*Release runs: capture_wing_holds_fire: 2 of 3, needs 2*'
        (Get-Content $markdown) | Should -Contain '| `capture_wing_holds_fire` | 2 of 3, needs 2 | pass |'
        $r.Output | Should -Not -BeLike '*below its pass bar*'

        # Below the bar fails the release run
        Set-Content $env:FAKE_SOURCE_LOG (& $lines @('met', 'missed', 'missed'))
        $r = Invoke-Script $runner ($runArgs + @('-ReleaseTier'))
        $r.Output | Should -BeLike '*GAME TESTS FAILED*: capture_wing_holds_fire below its pass bar: 1 of 3, needs 2*'
        $r.Output | Should -Not -BeLike '*failed: capture_wing_holds_fire*'
        $r.ExitCode | Should -Be 1
    }

    It 'refuses -ReleaseTier with -Release, which runs its own sessions' {
        $r = Invoke-Script $script:Runner ($runArgs + @('-Release', '-ReleaseTier'))
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -BeLike '*-Release runs its own sessions*-ReleaseTier*'
    }

    It 'keeps each run''s mod lines in a file per run next to the report, replacing the last run''s' {
        $runs = Join-Path $root 'runs'
        Write-LfFile (Join-Path $runs 'stale_test-1.log') 'from an earlier run'
        Set-Content $env:FAKE_SOURCE_LOG @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 2 tests'
            '[Scripts] 1.50 *** Context:x: [apirateslife] capture pass: starts at 390m, shields 100%, hull 100%'
            '[General] 1.60 Not a line of ours'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS capture_wing_holds_fire: lowest hull 70%'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] FAIL capture_wing_holds_fire: lowest hull 54%'
            '[Scripts] 5.00 *** Context:x: [apirateslife-test] DONE passed=1 failed=1'
        )
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire', '-Repeat', '2', '-LongHold'))
        $r.Output | Should -BeLike "*Run traces: 2 files in $runs*"
        @(Get-ChildItem $runs | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @('capture_wing_holds_fire-1.log', 'capture_wing_holds_fire-2.log')
        Get-Content (Join-Path $runs 'capture_wing_holds_fire-1.log') | Should -Be @(
            '[Scripts] 1.50 *** Context:x: [apirateslife] capture pass: starts at 390m, shields 100%, hull 100%'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS capture_wing_holds_fire: lowest hull 70%'
        )
    }

    It 'keeps a labelled batch''s traces in a folder of their own, replacing only that label''s' {
        $runs = Join-Path $root 'runs'
        Write-LfFile (Join-Path $runs 'capture_wing_holds_fire-1.log') 'the last unlabelled batch'
        Write-LfFile (Join-Path $runs 'base-b/stale_test-1.log') 'the label''s last batch'
        Write-LfFile (Join-Path $runs 'base-a/capture_wing_holds_fire-1.log') 'another label''s batch'
        Set-Content $env:FAKE_SOURCE_LOG @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 1 tests'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS capture_wing_holds_fire: lowest hull 70%'
            '[Scripts] 5.00 *** Context:x: [apirateslife-test] DONE passed=1 failed=0'
        )
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire', '-RunsLabel', 'base-b'))
        $r.Output | Should -BeLike "*Run traces: 1 files in $(Join-Path $runs 'base-b')*"
        @(Get-ChildItem (Join-Path $runs 'base-b') | ForEach-Object { $_.Name }) | Should -Be @('capture_wing_holds_fire-1.log')
        Get-Content (Join-Path $runs 'capture_wing_holds_fire-1.log') | Should -Be 'the last unlabelled batch'
        Get-Content (Join-Path $runs 'base-a/capture_wing_holds_fire-1.log') | Should -Be 'another label''s batch'
    }

    It 'adds a labelled batch''s traces to the label''s with -RunsAppend, numbering each test''s runs on' {
        $runs = Join-Path $root 'runs/base-b'
        Write-LfFile (Join-Path $runs 'capture_wing_holds_fire-1.log') 'split 1, run 1'
        Write-LfFile (Join-Path $runs 'capture_wing_holds_fire-9.log') 'split 1, run 9'
        Write-LfFile (Join-Path $runs 'capture_wing_holds_fire-10.log') 'split 1, run 10'
        # Another test whose name starts the same doesn't count towards its numbers
        Write-LfFile (Join-Path $runs 'capture_wing_holds_fire_three-20.log') 'another test''s run'
        Set-Content $env:FAKE_SOURCE_LOG @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 3 tests'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS config_applied_on_start: ok'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] PASS capture_wing_holds_fire: lowest hull 70%'
            '[Scripts] 4.00 *** Context:x: [apirateslife-test] FAIL capture_wing_holds_fire: lowest hull 54%'
            '[Scripts] 5.00 *** Context:x: [apirateslife-test] DONE passed=2 failed=1'
        )
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire', '-Repeat', '2', '-LongHold', '-RunsLabel', 'base-b', '-RunsAppend'))
        $r.Output | Should -BeLike "*Run traces: 3 files added to $runs*"
        @(Get-ChildItem $runs | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @(@(
            'capture_wing_holds_fire-1.log', 'capture_wing_holds_fire-9.log', 'capture_wing_holds_fire-10.log',
            'capture_wing_holds_fire-11.log', 'capture_wing_holds_fire-12.log', 'capture_wing_holds_fire_three-20.log',
            'config_applied_on_start-1.log') | Sort-Object)
        Get-Content (Join-Path $runs 'capture_wing_holds_fire-1.log') | Should -Be 'split 1, run 1'
        Get-Content (Join-Path $runs 'capture_wing_holds_fire-12.log') | Should -Be '[Scripts] 4.00 *** Context:x: [apirateslife-test] FAIL capture_wing_holds_fire: lowest hull 54%'
    }

    It 'refuses -RunsAppend without -RunsLabel, before anything changes' {
        $r = Invoke-Script $script:Runner ($runArgs + @('-RunsAppend'))
        $r.Output | Should -BeLike '*-RunsAppend adds to a labelled batch, so it needs -RunsLabel*'
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
    }

    It 'refuses a -RunsLabel that isn''t a plain folder name, before anything changes' {
        foreach ($label in @('../elsewhere', 'a/b', 'a\b', '..', '.')) {
            $r = Invoke-Script $script:Runner ($runArgs + @('-RunsLabel', $label))
            $r.Output | Should -BeLike '*-RunsLabel must be a folder name*'
            $r.ExitCode | Should -Not -Be 0
            Test-Path $env:FAKE_ARGS | Should -BeFalse
        }
    }

    It 'refuses -RunsLabel with -Release, which writes no run traces' {
        $r = Invoke-Script $script:Runner ($runArgs + @('-Release', '-RunsLabel', 'base-b'))
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -BeLike '*-Release runs its own sessions*-RunsLabel*'
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

    It 'starts the game directly, muted, with the debug options and its own profile, and reads that profile''s log' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Be 0
        Get-TestFile $env:FAKE_ARGS | Should -Be '-skipintro -disablesound -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid 90000301'
        $r.Output | Should -BeLike "*results go to $env:FAKE_LOGPATH*"
    }

    It 'fails when no log appears within the launch timeout' {
        $env:FAKE_HANG = '1'
        $r = Invoke-Script $script:Runner ($runArgs + @('-LaunchTimeoutSeconds', '1', '-TimeoutSeconds', '15'))
        $r.Output | Should -BeLike "*no $env:FAKE_LOGPATH within 1 s*"
        $r.ExitCode | Should -Be 1
    }
}
