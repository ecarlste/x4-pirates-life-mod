# Tests for tools/run-game-tests.ps1's functions: log parsing and the reports. Whole runs against a
# fake game are in RunGameTests.Tests.ps1.

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
        $run.GameVersion | Should -Be '9.00 (611726)'
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

    It 'ignores markers quoted in script error details, and a DONE before RUN START' {
        $run = Read-GameTestLog @(
            '[=ERROR=] 0.00 Error in MD cue md.APiratesLife_Tests.NextTest<inst:14461>: Property lookup failed: $Passed'
            "* Expression: '[apirateslife-test] DONE passed=%s failed=%s'.[`$Passed, `$Failed]"
            '* Action: <debug_text>, line 53'
            '[General] 0.00 *** Context:md.APiratesLife_Tests.NextTest<inst:14461>: [apirateslife-test] DONE passed=null failed=null'
            "* Expression: '[apirateslife-test] PASS fake: x'"
        )
        $run.Done | Should -BeFalse
        $run.Results.Count | Should -Be 0
        $run.Errors.Count | Should -Be 1
    }

    It 'returns an empty run for an empty log' {
        $run = Read-GameTestLog @()
        $run.Started | Should -BeFalse
        $run.Results.Count | Should -Be 0
    }
}

Describe 'Read-GameTestLog milestones' {
    It 'sees the main menu and counts SETA drops' {
        $run = Read-GameTestLog ($script:PassingLog + @(
            '[Init   ] 6.48 Game initialisation time until start menu fade-in (because of skipped intro video): 32 seconds'
            '[Scripts] 50.00 *** Context:md.APiratesLife_Tests.KeepSeta<inst:1>: [apirateslife-test] SETA was off; switched back on (now active: 1)'
            '[Scripts] 60.00 *** Context:md.APiratesLife_Tests.KeepSeta<inst:2>: [apirateslife-test] SETA was off; switched back on (now active: 1)'
        ))
        $run.MenuReady | Should -BeTrue
        $run.SetaDrops | Should -Be 2
        $run.Errors.Count | Should -Be 0
    }

    It 'counts the autostart as reaching the main menu' {
        (Read-GameTestLog @('[=ERROR=] 8.53 [apirateslife-test] autostart: starting gamestart apirateslife_test')).MenuReady | Should -BeTrue
        (Read-GameTestLog @('[General] 0.00 nothing yet')).MenuReady | Should -BeFalse
    }
}

Describe 'Get-RunPhases' {
    It 'splits a run into its phases and totals it' {
        $phases = @(Get-RunPhases @{ menu = 34.0; tests = 80.0; done = 150.0 } 160.0)
        ($phases | ForEach-Object { $_.Seconds }) | Should -Be @(34.0, 46.0, 70.0, 10.0, 160.0)
        $phases[0].Name | Should -Be 'X4 starts, to the main menu'
        $phases[3].Name | Should -Be 'X4 quits, cleanup'
        $phases[4].Name | Should -Be '**Total**'
    }

    It 'stops at the last milestone reached' {
        $phases = @(Get-RunPhases @{ menu = 34.0 } 900.0)
        ($phases | ForEach-Object { $_.Name }) | Should -Be @('X4 starts, to the main menu', 'Until the run ended', '**Total**')
        $phases[1].Seconds | Should -Be 866.0
    }

    It 'formats seconds and minutes' {
        Format-Seconds 34.4 | Should -Be '34 s'
        Format-Seconds 161 | Should -Be '2 min 41 s'
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
        $problems = Get-RunProblems (Read-GameTestLog $script:PassingLog[0..7]) 'the game exited early'
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

Describe 'ConvertTo-MarkdownReport' {
    BeforeAll {
        $script:Info = @{ Commit = '0123456789abcdef0123456789abcdef01234567'; Branch = 'feature/x'; Dirty = $false
                          StartedAt = [datetime] '2026-10-20 15:24'; DurationSeconds = 141 }
    }

    It 'starts with the marker the poster checks, then a summary and a row per test' {
        $run = Read-GameTestLog $script:PassingLog
        $lines = (ConvertTo-MarkdownReport $run (Get-RunProblems $run 'finished') $script:Info) -split "`n"
        $lines[0] | Should -Be '<!-- apirateslife-game-tests commit=0123456789abcdef0123456789abcdef01234567 dirty=false result=pass passed=2 total=2 -->'
        $lines[1] | Should -Be '### Game tests: passed, 2 of 2'
        $lines[3] | Should -Be 'Commit `0123456` on `feature/x`, X4 9.00 (611726), 2 min 21 s, 2026-10-20 15:24'
        $lines | Should -Contain '| `pilot_bail_intact` | PASS | hull 100%, 4 equipment kept, pilot skill 38 |'
    }

    It 'marks a failing, dirty run, and lists run problems and mod errors' {
        $log = ($script:PassingLog -replace 'PASS pilot_bail_intact: hull 100%', 'FAIL pilot_bail_intact: hull 72% | worse') +
               @('[=ERROR=] 9.00 Error in MD cue md.APiratesLife_Bail.Bailed')
        $run = Read-GameTestLog $log
        $info = $script:Info.Clone(); $info.Dirty = $true
        $md = ConvertTo-MarkdownReport $run (Get-RunProblems $run 'finished') $info
        $md | Should -BeLike '<!-- apirateslife-game-tests * dirty=true result=fail passed=1 total=2 -->*'
        $md | Should -BeLike '*### Game tests: FAILED, 1 of 2*'
        # Contains, not -BeLike: backticks are escape characters in wildcard patterns
        $md.Contains('on `feature/x` **plus uncommitted changes**,') | Should -BeTrue
        $md.Contains('| `pilot_bail_intact` | **FAIL** | hull 72% \| worse, 4 equipment kept, pilot skill 38 |') | Should -BeTrue
        $md | Should -BeLike '*- 1 errors from the mod in debuglog.txt*'
        $md | Should -BeLike '*Error in MD cue md.APiratesLife_Bail.Bailed*'
    }

    It 'says whether SETA stayed on, and shows the phase timings' {
        $run = Read-GameTestLog $script:PassingLog
        $info = $script:Info.Clone()
        $info.Phases = @(Get-RunPhases @{ menu = 34.0; tests = 80.0; done = 150.0 } 160.0)
        $md = ConvertTo-MarkdownReport $run (Get-RunProblems $run 'finished') $info
        $md | Should -BeLike '*SETA stayed on for the whole run.*'
        $md.Contains('| X4 starts, to the main menu | 34 s |') | Should -BeTrue
        $md.Contains('| **Total** | 2 min 40 s |') | Should -BeTrue

        $dropped = Read-GameTestLog ($script:PassingLog + @('[Scripts] 9.00 *** Context:x: [apirateslife-test] SETA was off; switched back on'))
        ConvertTo-MarkdownReport $dropped @() $script:Info | Should -BeLike '*SETA dropped 1 times during the run*'
    }
}
