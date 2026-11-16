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
        '[Scripts] 40.03 *** Context:md.APiratesLife_Tests.Report<inst:2a1c>: [apirateslife-test] PASS fixture_test_a: 5 cases'
        '[Scripts] 44.00 *** Context:md.APiratesLife_Tests.Report<inst:2a1d>: [apirateslife-test] PASS fixture_test_b: hull 100%, 4 equipment kept, pilot skill 38'
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
        $run.Results[1].Name | Should -Be 'fixture_test_b'
        $run.Results[1].Passed | Should -BeTrue
        $run.Results[1].Detail | Should -Be 'hull 100%, 4 equipment kept, pilot skill 38'
        $run.GameVersion | Should -Be '9.00 (611726)'
    }

    It 'reads a failure and its detail' {
        $run = Read-GameTestLog @('[Scripts] 1.00 *** Context:x: [apirateslife-test] FAIL fixture_test_c: hull 72%, expected 100%;')
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

    It 'reads a split verdict''s outcome apart from its invariants' {
        $run = Read-GameTestLog @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] PASS fixture_test_a outcome=missed: lowest hull 60%'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] FAIL fixture_test_a outcome=met: destroyed'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] PASS fixture_test_b: 5 cases'
        )
        $run.Results[0].Name | Should -Be 'fixture_test_a'
        $run.Results[0].Passed | Should -BeTrue
        $run.Results[0].Outcome | Should -Be 'missed'
        $run.Results[0].Detail | Should -Be 'lowest hull 60%'
        $run.Results[1].Passed | Should -BeFalse
        $run.Results[1].Outcome | Should -Be 'met'
        $run.Results[2].Outcome | Should -Be ''
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

Describe 'Get-LogChecks' {
    # X4 checks each file's signature as it reads it, in load order: a file both SWI and the mod
    # patch is read from SWI first only when the mod loads after SWI
    BeforeAll {
        $script:SwiFirst = @(
            "[=ERROR=] 0.00 File I/O: Could not find signature file '.\extensions\starwarsmod_m1\libraries\colors.xml.sig' (there will be no more errors for missing signatures)"
            "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file '.\extensions\starwarsmod_m1\libraries\icons.xml' (error: 14)"
            "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife\libraries\icons.xml' (error: 14)"
            "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife_tests\libraries\icons.xml' (error: 14)"
            "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file 'extensions\starwarsmod_m1\md\conversations.xml' (error: 14)"
            "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file 'extensions\apirateslife\md\conversations.xml' (error: 14)"
        )
        function Get-Check($Lines, [string] $Name) { Get-LogChecks (Read-GameTestLog $Lines) | Where-Object { $_.Name -eq $Name } }
    }

    It 'passes the load order when SWI''s copy of every shared file is read first' {
        $check = Get-Check $script:SwiFirst 'load_order_after_swi'
        $check.Passed | Should -BeTrue
        $check.Detail | Should -Be 'SWI read first for all 2 files both patch'
    }

    It 'fails the load order, naming the files the mod read first' {
        $check = Get-Check ($script:SwiFirst[0], $script:SwiFirst[2], $script:SwiFirst[1], $script:SwiFirst[4], $script:SwiFirst[5]) 'load_order_after_swi'
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be 'apirateslife read before SWI: libraries\icons.xml'
    }

    It 'fails the load order when no file was read from both' {
        $check = Get-Check $script:PassingLog 'load_order_after_swi'
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be 'no file read from both SWI and apirateslife, so the order is unknown'
    }

    It 'passes a clean log, ignoring the unsigned-file warnings every mod gets' {
        $check = Get-Check ($script:PassingLog + $script:SwiFirst) 'clean_log'
        $check.Passed | Should -BeTrue
        $check.Detail | Should -Be 'no errors or warnings from our files in debuglog.txt'
    }

    It 'fails the clean log on errors and warnings from our files' {
        $check = Get-Check ($script:PassingLog + @(
            "[=ERROR=] 0.00 No matching node for path '//do_if' in patch file 'extensions\apirateslife\aiscripts\fight.attack.object.fighter.xml'. Skipping node."
            "[General] 0.00 extensions\apirateslife\md\apirateslife_bail.xml(12): Warning while parsing expression: Property lookup failed"
            "[General] 0.00 extensions\starwarsmod_m1\md\kuertee_emergent_missions_rescue.xml(2672): Warning while parsing expression"
        )) 'clean_log'
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be '2 errors or warnings from our files in debuglog.txt'
    }

    It 'passes the SWI-only run when only Egosoft DLCs, SWI and our extensions were read' {
        $check = Get-Check ($script:SwiFirst + "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file '.\extensions\ego_dlc_pirate\md\x.xml' (error: 14)") 'swi_only_run'
        $check.Passed | Should -BeTrue
        $check.Detail | Should -Be 'files read only from Egosoft DLCs and apirateslife, apirateslife_tests, starwarsmod_m1'
    }

    It 'fails the SWI-only run, naming any other extension whose files were read' {
        $check = Get-Check ($script:SwiFirst + @(
            "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file '.\extensions\starwars_rsp\t\0001.xml' (error: 14)"
            "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file '.\extensions\Mycu_Equipment_Tooltips\t\0001.xml' (error: 14)"
        "[FileIO ] 0.00 File I/O: Failed to verify the file signature for file '.\extensions\My Mod\t\0001.xml' (error: 14)"
        )) 'swi_only_run'
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be 'files read from other extensions: my mod, mycu_equipment_tooltips, starwars_rsp'
    }

    It 'fails the SWI-only run when no SWI file was read' {
        $check = Get-Check $script:PassingLog 'swi_only_run'
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be 'no file read from SWI (starwarsmod_m1)'
    }
}

Describe 'Get-RunProblems' {
    It 'finds none in a passing run' {
        @(Get-RunProblems (Read-GameTestLog $script:PassingLog) 'finished').Count | Should -Be 0
    }

    It 'names failed tests' {
        $log = $script:PassingLog -replace 'PASS fixture_test_b', 'FAIL fixture_test_b'
        Get-RunProblems (Read-GameTestLog $log) 'finished' | Should -Contain '1 failed: fixture_test_b'
    }

    It 'reports a run that never started' {
        Get-RunProblems (Read-GameTestLog @()) 'timed out after 5 s' | Should -Contain 'the tests never started (timed out after 5 s)'
    }

    It 'reports an unfinished run and missing results' {
        $problems = Get-RunProblems (Read-GameTestLog $script:PassingLog[0..7]) 'the game exited early'
        $problems | Should -Contain "the run didn't finish (the game exited early)"
        $problems | Should -Contain '1 of 2 tests reported'
    }

    It 'reports errors from the mod as the failed clean_log check' {
        $run = Read-GameTestLog ($script:PassingLog + @('[=ERROR=] 9.00 Error in MD cue md.APiratesLife_Bail.Bailed'))
        Add-LogChecks $run | Out-Null
        Get-RunProblems $run 'finished' | Should -Contain '3 failed: load_order_after_swi, clean_log, swi_only_run'
    }

    It 'counts the log checks among the results a run expects' {
        $run = Read-GameTestLog $script:PassingLog[0..7]
        Add-LogChecks $run | Out-Null
        Get-RunProblems $run 'the game exited early' | Should -Contain '4 of 5 tests reported'
    }
}

Describe 'Get-RunProblems with repeated tests' {
    It 'names a repeated test once, with how often it failed' {
        $run = Read-GameTestLog @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] FAIL fixture_test_a: hull 54%'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS fixture_test_a: hull 70%'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] FAIL fixture_test_a: hull 52%'
            '[Scripts] 4.00 *** Context:x: [apirateslife-test] FAIL fixture_test_b: no'
        )
        Get-RunProblems $run 'finished' | Should -Contain '3 failed: fixture_test_a (2 times), fixture_test_b'
    }
}

Describe 'Game test selection (-Test, -Repeat)' {
    BeforeAll {
        $script:Harness = @'
<cue name="Run">
        <set_value name="$QuitWhenDone" exact="true"/>
        <set_value name="$Tests" exact="[
          ConfigAppliedOnStart,
          CaptureWingHoldsFire,
          BailRaisesBailed
        ]"/>
        <set_value name="$Index" exact="0"/>
'@
    }

    It 'reads the cue names from the harness''s $Tests list' {
        Get-GameTestNames $script:Harness | Should -Be @('ConfigAppliedOnStart', 'CaptureWingHoldsFire', 'BailRaisesBailed')
    }

    It 'reads the real harness''s list' {
        $text = Get-Content (Join-Path $script:RepoRoot 'tests/game/apirateslife_tests/md/apirateslife_tests.xml') -Raw
        Get-GameTestNames $text | Should -Contain 'CaptureWingHoldsFire'
    }

    It 'fails on a harness without the list' {
        { Get-GameTestNames '<cue name="Run"/>' } | Should -Throw '*no $Tests list*'
    }

    It 'reads the $ReleaseOnly list, empty or not' {
        $text = $script:Harness -replace '<set_value name="\$Index"', "<set_value name=`"`$ReleaseOnly`" exact=`"[`n          CaptureWingHoldsFire`n        ]`"/>`n        `$0"
        Get-GameTestNames $text 'ReleaseOnly' | Should -Be @('CaptureWingHoldsFire')
        Get-GameTestNames $text | Should -Be @('ConfigAppliedOnStart', 'CaptureWingHoldsFire', 'BailRaisesBailed')
        @(Get-GameTestNames ($script:Harness + '<set_value name="$ReleaseOnly" exact="[]"/>') 'ReleaseOnly').Count | Should -Be 0
        { Get-GameTestNames $script:Harness 'ReleaseOnly' } | Should -Throw '*no $ReleaseOnly list*'
    }

    It 'reads the $ReleaseRuns list: each test''s runs and the passes it needs' {
        $text = $script:Harness -replace '<set_value name="\$Index"', "<set_value name=`"`$ReleaseRuns`" exact=`"[`n          [CaptureWingHoldsFire, 10, 8],`n          [BailRaisesBailed, 40, 34]`n        ]`"/>`n        `$0"
        $runs = Get-ReleaseRuns $text
        $runs.Keys.Count | Should -Be 2
        $runs['CaptureWingHoldsFire'].Runs | Should -Be 10
        $runs['CaptureWingHoldsFire'].Needed | Should -Be 8
        $runs['BailRaisesBailed'].Runs | Should -Be 40
        (Get-ReleaseRuns ($script:Harness + '<set_value name="$ReleaseRuns" exact="[]"/>')).Keys.Count | Should -Be 0
        { Get-ReleaseRuns $script:Harness } | Should -Throw '*no $ReleaseRuns list*'
        # A test of the game as it starts runs once, so it can't meet a bar of more runs
        { Get-ReleaseRuns ($script:Harness + '<set_value name="$ReleaseRuns" exact="[[ConfigAppliedOnStart, 10, 8]]"/>') } | Should -Throw '*lists ConfigAppliedOnStart, which runs once, first*'
    }

    It 'runs each $ReleaseRuns test its runs, one after another, where it stands in the list' {
        $bar = { param($n) [pscustomobject]@{ Runs = $n; Needed = 1 } }
        Resolve-GameTestSelection @('A', 'B', 'C') @() 1 -Runs @{ B = & $bar 3 } | Should -Be @('A', 'B', 'B', 'B', 'C')
        Resolve-GameTestSelection @('A', 'Slow', 'B') @() 1 @('Slow') @{ Slow = & $bar 2; A = & $bar 2 } | Should -Be @('A', 'A', 'B')
    }

    It 'selects a test by its cue name or the name it reports, in rounds of -Repeat' {
        $names = @('ConfigAppliedOnStart', 'CaptureWingHoldsFire', 'BailRaisesBailed')
        Resolve-GameTestSelection $names @('capture_wing_holds_fire') 3 | Should -Be @('CaptureWingHoldsFire', 'CaptureWingHoldsFire', 'CaptureWingHoldsFire')
        # As powershell -File passes it: one comma-separated string
        Resolve-GameTestSelection $names @('bailraisesbailed,CaptureWingHoldsFire') 2 |
            Should -Be @('BailRaisesBailed', 'CaptureWingHoldsFire', 'BailRaisesBailed', 'CaptureWingHoldsFire')
    }

    It 'repeats every test without -Test' {
        Resolve-GameTestSelection @('A', 'B') @() 2 | Should -Be @('A', 'B', 'A', 'B')
    }

    It 'leaves out the tests it''s told to skip (the PR tier''s release-only ones), unless -Test names them' {
        Resolve-GameTestSelection @('A', 'Slow', 'B') @() 1 @('Slow') | Should -Be @('A', 'B')
        Resolve-GameTestSelection @('A', 'Slow', 'B') @() 2 @('Slow') | Should -Be @('A', 'B', 'A', 'B')
        Resolve-GameTestSelection @('A', 'Slow', 'B') @('slow,A') 1 @('Slow') | Should -Be @('Slow', 'A')
    }

    It 'runs a test of the game as it starts once, first' {
        Resolve-GameTestSelection @('ConfigAppliedOnStart', 'A', 'B') @() 2 | Should -Be @('ConfigAppliedOnStart', 'A', 'B', 'A', 'B')
        Resolve-GameTestSelection @('ConfigAppliedOnStart', 'A', 'B') @('B,config_applied_on_start') 2 | Should -Be @('ConfigAppliedOnStart', 'B', 'B')
    }

    It 'refuses an unknown test, naming the ones there are, and a -Repeat under 1' {
        { Resolve-GameTestSelection @('A', 'B') @('A,Nope') 1 } | Should -Throw 'No game test named Nope. The tests: A, B'
        { Resolve-GameTestSelection @('A') @() 0 } | Should -Throw '*-Repeat must be 1 or more*'
    }

    It 'rewrites the list, one name per line, leaving the rest of the harness alone' {
        $text = Set-GameTestList $script:Harness @('CaptureWingHoldsFire', 'CaptureWingHoldsFire')
        Get-GameTestNames $text | Should -Be @('CaptureWingHoldsFire', 'CaptureWingHoldsFire')
        $text.Contains("exact=`"[`n          CaptureWingHoldsFire,`n          CaptureWingHoldsFire`n        ]`"/>") | Should -BeTrue
        $text | Should -BeLike '*<set_value name="$QuitWhenDone" exact="true"/>*<set_value name="$Index" exact="0"/>*'
    }

    It 'tallies each repeated test''s runs and failures, in the order first seen' {
        $run = Read-GameTestLog @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] PASS fixture_test_b: ok'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] FAIL fixture_test_a: hull 54%'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] PASS fixture_test_a: hull 70%'
            '[Scripts] 4.00 *** Context:x: [apirateslife-test] PASS fixture_test_b: ok'
            '[Scripts] 5.00 *** Context:x: [apirateslife-test] PASS fixture_test_c: once'
        )
        $tally = @(Get-RepeatTally $run.Results)
        $tally.Count | Should -Be 2
        $tally[0].Name | Should -Be 'fixture_test_b'
        $tally[0].Runs | Should -Be 2
        $tally[0].Failed | Should -Be 0
        $tally[1].Name | Should -Be 'fixture_test_a'
        $tally[1].Failed | Should -Be 1
    }
}

Describe 'Get-BarTally' {
    BeforeAll {
        function New-Results([string[]] $Marks) {
            # One result per mark: + passed with the outcome met, - passed with it missed, x failed
            Read-GameTestLog (@("[Scripts] 0.00 *** Context:x: [apirateslife-test] RUN START $($Marks.Count) tests") + @(foreach ($m in $Marks) {
                switch ($m) {
                    '+' { '[Scripts] 1.00 *** Context:x: [apirateslife-test] PASS wing_bails outcome=met: bailed' }
                    '-' { '[Scripts] 1.00 *** Context:x: [apirateslife-test] PASS wing_bails outcome=missed: lowest hull 40%' }
                    'x' { '[Scripts] 1.00 *** Context:x: [apirateslife-test] FAIL wing_bails outcome=met: destroyed' }
                    'p' { '[Scripts] 1.00 *** Context:x: [apirateslife-test] PASS plain: ok' }
                }
            }) + @('[Scripts] 2.00 *** Context:x: [apirateslife-test] DONE'))
        }
        $script:Bars = @{ WingBails = [pscustomobject]@{ Runs = 10; Needed = 8 }; Plain = [pscustomobject]@{ Runs = 3; Needed = 3 } }
    }

    It 'counts the runs that held their invariants and met their outcome, against the bar' {
        $run = New-Results @('+', '+', '-', '+', '+', '+', '+', '+', '-', '+')
        $tally = @(Get-BarTally $run.Results $script:Bars)
        $tally.Count | Should -Be 1
        $tally[0].Name | Should -Be 'wing_bails'
        $tally[0].Met | Should -Be 8
        $tally[0].Runs | Should -Be 10
        $tally[0].Needed | Should -Be 8
        $tally[0].Passed | Should -BeTrue
    }

    It 'fails a test below its bar, and counts a failed invariant against it' {
        $run = New-Results @('+', '+', '-', '+', 'x', '+', '+', '+', '-', '+')
        $tally = @(Get-BarTally $run.Results $script:Bars)
        $tally[0].Met | Should -Be 7
        $tally[0].Passed | Should -BeFalse
        Get-RunProblems $run 'finished' $script:Bars | Should -Contain 'wing_bails below its pass bar: 7 of 10, needs 8'
    }

    It 'counts a run with no outcome by its result alone' {
        $run = New-Results @('p', 'p', 'p')
        $tally = @(Get-BarTally $run.Results $script:Bars)
        $tally[0].Name | Should -Be 'plain'
        $tally[0].Met | Should -Be 3
        $tally[0].Passed | Should -BeTrue
    }

    It 'counts the runs the bar asks for, so an unfinished run falls short' {
        $run = New-Results @('+', '+', '+', '+', '+', '+', '+')
        $tally = @(Get-BarTally $run.Results $script:Bars)
        $tally[0].Met | Should -Be 7
        $tally[0].Runs | Should -Be 10
        $tally[0].Passed | Should -BeFalse
    }

    It 'has no bars without $ReleaseRuns, and a missed outcome alone fails nothing' {
        $run = New-Results @('-', '-')
        @(Get-BarTally $run.Results @{}).Count | Should -Be 0
        @(Get-RunProblems $run 'finished').Count | Should -Be 0
    }
}

Describe 'Split-GameTestRuns' {
    It 'splits the mod''s lines into one run per result, numbered per test' {
        $runs = @(Split-GameTestRuns @(
            '[Scripts] 0.00 *** Context:md.APiratesLife_Settings.OnLoad: [apirateslife] settings: config applied'
            '[General] 1.01 *** Context:md.APiratesLife_Tests.Begin: [apirateslife-test] RUN START 3 tests'
            '[General] 1.01 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 0, hull 100%, shields 100%'
            '[General] 1.50 Some other line from the game'
            '[Scripts] 3.02 *** Context:md.APiratesLife_Capture.Operation: [apirateslife] capture: started on IMP TIE/LN (ZSX-457)'
            '[General] 9.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] PASS fixture_test_a: after 8 s'
            '[Scripts] 9.00 *** aicontext<order.apirateslife.capture,0x9d3f>: [apirateslife] capture order: X-wing T65B ends on IMP TIE/LN'
            '[General] 20.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] FAIL fixture_test_a: target destroyed'
            '[General] 25.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] PASS fixture_test_b: ok'
            '[General] 25.01 *** Context:md.APiratesLife_Tests.NextTest: [apirateslife-test] DONE passed=2 failed=1'
        ))
        $runs.Count | Should -Be 3
        @($runs | ForEach-Object { "$($_.Name)-$($_.Number)" }) | Should -Be @('fixture_test_a-1', 'fixture_test_a-2', 'fixture_test_b-1')
        # Only the mod's lines, from RUN START on, each run ending on its own result line
        $runs[0].Lines | Should -Be @(
            '[General] 1.01 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 0, hull 100%, shields 100%'
            '[Scripts] 3.02 *** Context:md.APiratesLife_Capture.Operation: [apirateslife] capture: started on IMP TIE/LN (ZSX-457)'
            '[General] 9.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] PASS fixture_test_a: after 8 s'
        )
        # A line logged after a test's result goes with the next test
        $runs[1].Lines[0] | Should -BeLike '*capture order: X-wing T65B ends on*'
        $runs[2].Lines | Should -Be @('[General] 25.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] PASS fixture_test_b: ok')
    }

    It 'keeps the lines of a test that never reported as an unfinished run' {
        $runs = @(Split-GameTestRuns @(
            '[General] 1.00 *** Context:x: [apirateslife-test] RUN START 2 tests'
            '[General] 2.00 *** Context:x: [apirateslife-test] PASS fixture_test_a: ok'
            '[General] 3.00 *** Context:x: [apirateslife-test] trace: t 0, hull 100%, shields 100%'
        ))
        $runs.Count | Should -Be 2
        $runs[1].Name | Should -Be 'unfinished'
        $runs[1].Lines | Should -Be @('[General] 3.00 *** Context:x: [apirateslife-test] trace: t 0, hull 100%, shields 100%')
    }

    It 'skips the markers quoted in script error details, and a run with no lines left after the last result' {
        $runs = @(Split-GameTestRuns @(
            '[General] 1.00 *** Context:x: [apirateslife-test] RUN START 1 tests'
            "* Expression: '[apirateslife-test] PASS fake: x'"
            '[General] 2.00 *** Context:x: [apirateslife-test] PASS fixture_test_a: ok'
            '[General] 2.01 *** Context:x: [apirateslife-test] DONE passed=1 failed=0'
        ))
        $runs.Count | Should -Be 1
        $runs[0].Lines.Count | Should -Be 1
    }

    It 'returns no runs for a log where the tests never started' {
        @(Split-GameTestRuns @('[Scripts] 0.00 *** Context:x: [apirateslife] settings: config applied')).Count | Should -Be 0
    }
}

Describe 'ConvertTo-JUnitXml' {
    It 'writes one case per test plus the run, with failures escaped' {
        $log = $script:PassingLog -replace 'PASS fixture_test_b: hull 100%', 'FAIL fixture_test_b: hull <72%> & "worse"'
        $run = Read-GameTestLog $log
        $xml = [xml] (ConvertTo-JUnitXml $run (Get-RunProblems $run 'finished'))
        $xml.testsuite.tests | Should -Be '3'
        $xml.testsuite.failures | Should -Be '1'
        $case = $xml.testsuite.testcase | Where-Object { $_.name -eq 'fixture_test_b' }
        $case.failure.message | Should -BeLike 'hull <72%> & "worse"*'
    }

    It 'lists the mod''s log errors under the failed clean_log case, not the run' {
        $run = Read-GameTestLog ($script:PassingLog + @('[=ERROR=] 9.00 Error in MD cue md.APiratesLife_Bail.Bailed'))
        Add-LogChecks $run | Out-Null
        $xml = [xml] (ConvertTo-JUnitXml $run (Get-RunProblems $run 'finished'))
        ($xml.testsuite.testcase | Where-Object { $_.name -eq 'clean_log' }).failure.InnerText | Should -Be '[=ERROR=] 9.00 Error in MD cue md.APiratesLife_Bail.Bailed'
        ($xml.testsuite.testcase | Where-Object { $_.name -eq 'run' }).failure | Should -BeNullOrEmpty
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
        $lines | Should -Contain '| `fixture_test_b` | PASS | hull 100%, 4 equipment kept, pilot skill 38 |'
    }

    It 'marks a failing, dirty run, and lists run problems and mod errors' {
        $log = ($script:PassingLog -replace 'PASS fixture_test_b: hull 100%', 'FAIL fixture_test_b: hull 72% | worse') +
               @('[=ERROR=] 9.00 Error in MD cue md.APiratesLife_Bail.Bailed')
        $run = Read-GameTestLog $log
        $info = $script:Info.Clone(); $info.Dirty = $true
        $md = ConvertTo-MarkdownReport $run (Get-RunProblems $run 'finished') $info
        $md | Should -BeLike '<!-- apirateslife-game-tests * dirty=true result=fail passed=1 total=2 -->*'
        $md | Should -BeLike '*### Game tests: FAILED, 1 of 2*'
        # Contains, not -BeLike: backticks are escape characters in wildcard patterns
        $md.Contains('on `feature/x` **plus uncommitted changes**,') | Should -BeTrue
        $md.Contains('| `fixture_test_b` | **FAIL** | hull 72% \| worse, 4 equipment kept, pilot skill 38 |') | Should -BeTrue
        $md | Should -BeLike '*Error in MD cue md.APiratesLife_Bail.Bailed*'
    }

    It 'marks a selected run, and tallies its repeated tests' {
        $run = Read-GameTestLog @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 4 tests'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] FAIL fixture_test_a: hull 54%'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] PASS fixture_test_a: hull 70%'
            '[Scripts] 4.00 *** Context:x: [apirateslife-test] PASS fixture_test_a: hull 71%'
            '[Scripts] 5.00 *** Context:x: [apirateslife-test] PASS fixture_test_a: hull 72%'
            '[Scripts] 6.00 *** Context:x: [apirateslife-test] DONE passed=3 failed=1'
        )
        $info = $script:Info.Clone(); $info.Selected = $true
        $lines = (ConvertTo-MarkdownReport $run (Get-RunProblems $run 'finished') $info) -split "`n"
        $lines[0] | Should -BeLike '* result=fail passed=3 total=4 selected=true -->'
        $lines | Should -Contain 'Selected tests only (`-Test`, `-Repeat`), not the whole suite.'
        $lines | Should -Contain '| `fixture_test_a` | 4 | 1 (25%) |'
        # A whole-suite run has neither
        $plain = ConvertTo-MarkdownReport (Read-GameTestLog $script:PassingLog) @() $script:Info
        $plain | Should -Not -BeLike '*selected*'
        $plain | Should -Not -BeLike '*Repeated test*'
    }

    It 'shows each repeated release test as k of N, needs M, and a missed outcome on its row' {
        $run = Read-GameTestLog @(
            '[Scripts] 1.00 *** Context:x: [apirateslife-test] RUN START 3 tests'
            '[Scripts] 2.00 *** Context:x: [apirateslife-test] PASS wing_bails outcome=met: bailed at 41%'
            '[Scripts] 3.00 *** Context:x: [apirateslife-test] PASS wing_bails outcome=missed: lowest hull 40%'
            '[Scripts] 4.00 *** Context:x: [apirateslife-test] PASS wing_bails outcome=met: bailed at 38%'
            '[Scripts] 6.00 *** Context:x: [apirateslife-test] DONE passed=3 failed=0'
        )
        $info = $script:Info.Clone(); $info.Tier = 'release'
        $info.Bars = @{ WingBails = [pscustomobject]@{ Runs = 3; Needed = 3 } }
        $problems = Get-RunProblems $run 'finished' $info.Bars
        $lines = (ConvertTo-MarkdownReport $run $problems $info) -split "`n"
        $lines[0] | Should -BeLike '* result=fail passed=3 total=3 -->'
        $lines | Should -Contain '| `wing_bails` | PASS, outcome missed | lowest hull 40% |'
        $lines | Should -Contain '| `wing_bails` | PASS, outcome met | bailed at 41% |'
        $lines | Should -Contain '| Release-run test | Passes | Result |'
        $lines | Should -Contain '| `wing_bails` | 2 of 3, needs 3 | **FAIL** |'
        $lines | Should -Contain '- wing_bails below its pass bar: 2 of 3, needs 3'
        # Its runs are in the pass bar table, not the repeat tally
        $lines | Should -Not -Contain '| Repeated test | Runs | Failed |'
    }

    It 'names the tier, the release-only tests a PR-tier run skipped, and the budget' {
        $run = Read-GameTestLog $script:PassingLog
        $info = $script:Info.Clone(); $info.Tier = 'pr'; $info.Skipped = @('SlowA', 'SlowB')
        $lines = (ConvertTo-MarkdownReport $run @() $info) -split "`n"
        $lines | Should -Contain 'PR tier (`make game-test`), budget 5 minutes. Skipped 2 release-only tests, which `make game-test RELEASE=1` runs: `SlowA`, `SlowB`.'
        $info = $script:Info.Clone(); $info.Tier = 'release'
        $lines = (ConvertTo-MarkdownReport $run @() $info) -split "`n"
        $lines | Should -Contain 'Release tier (`make game-test RELEASE=1`): every test, budget 30 minutes.'
        # Selections and release sessions have no tier
        ConvertTo-MarkdownReport $run @() $script:Info | Should -Not -BeLike '*tier*'
    }

    It 'warns, without failing, when a run is over its tier''s budget' {
        $run = Read-GameTestLog $script:PassingLog
        $info = $script:Info.Clone(); $info.Tier = 'pr'; $info.DurationSeconds = 301
        $md = ConvertTo-MarkdownReport $run @() $info
        $md | Should -BeLike '<!-- * result=pass *'
        $md.Contains('**Over the PR tier''s 5-minute budget** (5 min 1 s): move a slow test to `$ReleaseOnly` in the harness (docs/testing.md, Game test tiers).') | Should -BeTrue
        $info.Tier = 'release'; $info.DurationSeconds = 1801
        (ConvertTo-MarkdownReport $run @() $info).Contains('**Over the release tier''s 30-minute budget** (30 min 1 s)') | Should -BeTrue
        $info.DurationSeconds = 1800
        ConvertTo-MarkdownReport $run @() $info | Should -Not -BeLike '*Over the*'
    }

    It 'says whether SETA stayed on, and shows the phase timings' {
        $run = Read-GameTestLog $script:PassingLog
        $info = $script:Info.Clone()
        $info.Phases = @(Get-RunPhases @{ menu = 34.0; tests = 80.0; done = 150.0 } 160.0)
        $md = ConvertTo-MarkdownReport $run (Get-RunProblems $run 'finished') $info
        $md | Should -BeLike '*SETA never dropped outside the combat tests, which switch it off on purpose.*'
        $md.Contains('| X4 starts, to the main menu | 34 s |') | Should -BeTrue
        $md.Contains('| **Total** | 2 min 40 s |') | Should -BeTrue

        $dropped = Read-GameTestLog ($script:PassingLog + @('[Scripts] 9.00 *** Context:x: [apirateslife-test] SETA was off; switched back on'))
        ConvertTo-MarkdownReport $dropped @() $script:Info | Should -BeLike '*SETA dropped 1 times during the run*'
    }
}

Describe 'Get-GameProcessNames' {
    It 'covers both X4 executables, so neither copy of the game can be running' {
        Get-GameProcessNames 'E:\X4 Foundations - 8.00\X4_nonsteam.exe' | Should -Be @('X4', 'X4_nonsteam')
    }

    It 'adds another executable''s name' {
        Get-GameProcessNames 'C:\bin\fakegame.cmd' | Should -Be @('X4', 'X4_nonsteam', 'fakegame')
    }
}

Describe 'Get-ProfileProblems' {
    BeforeEach {
        $dir = New-TestDir
        $xml = Join-Path $dir 'content.xml'
    }
    AfterEach { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'finds none when SWI is on and our extensions are on or not listed' {
        Write-LfFile $xml '<content><extension id="SW Interworlds" enabled="1"/><extension id="apirateslife" enabled="true"/></content>'
        Get-ProfileProblems $xml | Should -BeNullOrEmpty
    }

    It 'needs SWI listed as on, since its own content.xml starts it off' {
        Write-LfFile $xml '<content><extension id="apirateslife" enabled="true"/></content>'
        Get-ProfileProblems $xml | Should -Be @("'SW Interworlds' isn't switched on")
    }

    It 'names each of ours that is switched off' {
        Write-LfFile $xml '<content><extension id="SW Interworlds" enabled="true"/><extension id="apirateslife" enabled="0"/><extension id="apirateslife_tests" enabled="false"/></content>'
        Get-ProfileProblems $xml | Should -Be @("'apirateslife' isn't switched on", "'apirateslife_tests' isn't switched on")
    }

    It 'treats a missing content.xml as a new profile, with SWI off' {
        Get-ProfileProblems $xml | Should -Be @("'SW Interworlds' isn't switched on")
    }
}

Describe 'Enable-Extensions' {
    BeforeEach {
        $dir = New-TestDir
        $xml = Join-Path $dir 'content.xml'
    }
    AfterEach { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'switches listed extensions on, adds missing ones, and keeps the rest' {
        Write-LfFile $xml '<content><extension id="SW Interworlds" enabled="false"/><extension id="other" enabled="false"/></content>'
        Enable-Extensions $xml @('SW Interworlds', 'apirateslife')
        $doc = [xml] (Get-Content $xml -Raw)
        @($doc.content.extension | ForEach-Object { "$($_.id)=$($_.enabled)" }) | Should -Be @('SW Interworlds=true', 'other=false', 'apirateslife=true')
    }

    It 'makes the file when the profile has none' {
        Enable-Extensions $xml @('apirateslife')
        Get-EnabledExtensions $xml | Should -Be @('apirateslife')
    }
}

Describe 'Get-OtherExtensions' {
    BeforeEach { $dir = New-TestDir }
    AfterEach { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'lists the ids of installed extensions other than the Egosoft DLCs, SWI and ours' {
        Write-LfFile "$dir/ego_dlc_pirate/content.xml" '<content id="ego_dlc_pirate"/>'
        Write-LfFile "$dir/starwarsmod_m1/content.xml" '<content id="SW Interworlds" enabled="0"/>'
        Write-LfFile "$dir/apirateslife/content.xml" '<content id="apirateslife"/>'
        Write-LfFile "$dir/apirateslife_tests/content.xml" '<content id="apirateslife_tests"/>'
        Write-LfFile "$dir/starwars_rsp/content.xml" '<?xml version="1.0" encoding="utf-8"?><content id="Reaper''s Ship Pack (SWI)" enabled="1"/>'
        Write-LfFile "$dir/mycu_equipment_tooltips/content.xml" '<content id="EquipmentTooltips"/>'
        New-Item -ItemType Directory -Path "$dir/no_content_xml" | Out-Null
        Get-OtherExtensions $dir | Sort-Object | Should -Be @('EquipmentTooltips', "Reaper's Ship Pack (SWI)")
    }

    It 'skips, with a warning, an extension whose content.xml is broken or has no id' {
        Write-LfFile "$dir/broken/content.xml" '<content id="broken"'
        Write-LfFile "$dir/no_id/content.xml" '<content name="no id"/>'
        Write-LfFile "$dir/good/content.xml" '<content id="good"/>'
        $out = @(Get-OtherExtensions $dir 3>&1)
        @($out | Where-Object { $_ -is [string] }) | Should -Be @('good')
        @($out | Where-Object { $_ -is [Management.Automation.WarningRecord] }).Count | Should -Be 2
    }
}

Describe 'Disable-Extensions' {
    BeforeEach {
        $dir = New-TestDir
        $xml = Join-Path $dir 'content.xml'
    }
    AfterEach { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'switches listed extensions off, adds missing ones, and keeps the rest' {
        Write-LfFile $xml '<content><extension id="SW Interworlds" enabled="true"/><extension id="other" enabled="true"/></content>'
        Disable-Extensions $xml @('other', 'new one')
        $doc = [xml] (Get-Content $xml -Raw)
        @($doc.content.extension | ForEach-Object { "$($_.id)=$($_.enabled)" }) | Should -Be @('SW Interworlds=true', 'other=false', 'new one=false')
    }
}

Describe 'Resolve-Setting' {
    BeforeEach {
        $dir = New-TestDir
        Write-LfFile (Join-Path $dir 'deploy.config') "X4_PATH=`"E:\X4`"`n# X4_PROFILE_ROOT=`"C:\nope`"`nX4_PROFILE_ID='90000301'`n"
    }
    AfterEach {
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item env:X4_PROFILE_ID -ErrorAction SilentlyContinue
    }

    It 'reads deploy.config, without quotes, skipping commented-out settings' {
        Resolve-Setting $dir 'X4_PATH' '' | Should -Be 'E:\X4'
        Resolve-Setting $dir 'X4_PROFILE_ROOT' 'default' | Should -Be 'default'
    }

    It 'lets the environment override deploy.config' {
        $env:X4_PROFILE_ID = '123'
        Resolve-Setting $dir 'X4_PROFILE_ID' '90000301' | Should -Be '123'
    }

    It 'falls back to the default without a deploy.config' {
        Remove-Item (Join-Path $dir 'deploy.config')
        Resolve-Setting $dir 'X4_EXE' 'X4_nonsteam.exe' | Should -Be 'X4_nonsteam.exe'
    }
}

Describe 'Resolve-Setting in a worktree' {
    BeforeEach {
        # A main checkout and a linked worktree, laid out as git worktree add makes them
        $main = New-TestDir
        $gitdir = Join-Path $main '.git/worktrees/wt'
        Write-LfFile (Join-Path $gitdir 'commondir') "../..`n"
        $worktree = Join-Path $main '.claude/worktrees/wt'
        Write-LfFile (Join-Path $worktree '.git') "gitdir: $gitdir`n"
        Write-LfFile (Join-Path $main 'deploy.config') "X4_PATH=`"E:\X4 - 8.00`"`nX4_PROFILE_ID=90000301`n"
    }
    AfterEach {
        Remove-Item $main -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item env:X4_PROFILE_ID -ErrorAction SilentlyContinue
    }

    It "reads the main checkout's deploy.config when the worktree has none" {
        Resolve-Setting $worktree 'X4_PATH' '' | Should -Be 'E:\X4 - 8.00'
    }

    It "lets the worktree's own deploy.config win, setting by setting" {
        Write-LfFile (Join-Path $worktree 'deploy.config') "X4_PATH=`"E:\X4 - 9.00`"`n"
        Resolve-Setting $worktree 'X4_PATH' '' | Should -Be 'E:\X4 - 9.00'
        Resolve-Setting $worktree 'X4_PROFILE_ID' '' | Should -Be '90000301'
    }

    It 'lets the environment win over both' {
        $env:X4_PROFILE_ID = '123'
        Resolve-Setting $worktree 'X4_PROFILE_ID' '' | Should -Be '123'
    }
}

Describe 'Resolve-GitDir' {
    It "maps a WSL worktree's Linux gitdir onto its \\wsl.localhost path, as Windows sees it" {
        Resolve-GitDir '\\wsl.localhost\Ubuntu\home\me\repo\.claude\worktrees\wt' '/home/me/repo/.git/worktrees/wt' |
            Should -Be '\\wsl.localhost\Ubuntu\home\me\repo\.git\worktrees\wt'
        Resolve-GitDir '\\wsl$\Ubuntu\home\me\wt' '/home/me/repo/.git/worktrees/wt' |
            Should -Be '\\wsl$\Ubuntu\home\me\repo\.git\worktrees\wt'
    }

    It 'resolves a relative gitdir against the worktree, and keeps an absolute one' {
        $root = New-TestDir
        Resolve-GitDir $root '../repo/.git/worktrees/wt' | Should -Be ([IO.Path]::GetFullPath((Join-Path $root '../repo/.git/worktrees/wt')))
        $absolute = Join-Path $root 'repo/.git/worktrees/wt'
        Resolve-GitDir $root $absolute | Should -Be $absolute
        Remove-Item $root -Recurse -Force
    }
}

Describe 'ConvertFrom-WslPath' {
    It 'turns a WSL /mnt path into a Windows one, and leaves Windows paths alone' {
        ConvertFrom-WslPath '/mnt/e/SteamLibrary/X4 Foundations - 8.00' | Should -Be 'E:\SteamLibrary\X4 Foundations - 8.00'
        ConvertFrom-WslPath 'E:\X4' | Should -Be 'E:\X4'
    }
}

Describe 'Watch-GameRun' {
    BeforeEach {
        $script:dir = New-TestDir
        $script:log = Join-Path $dir 'debuglog.txt'
        $failingLog = $script:PassingLog -replace 'PASS fixture_test_a: 5 cases', 'FAIL fixture_test_a: 30 gave 30, expected 60;'
        # A game that writes its whole log and quits just before the runner asks whether it has
        # exited: the race that once lost the results from the live output (CI, PowerShell 5.1)
        $script:game = [pscustomobject]@{ Log = $log; Lines = $failingLog }
        $game | Add-Member ScriptProperty HasExited { [IO.File]::WriteAllLines($this.Log, [string[]] $this.Lines); $true }
    }
    AfterEach { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'reports every result a game wrote just before it exited' {
        $seen = @{}
        $out = Watch-GameRun $game $log 0 60 60 '90000301' $null (Get-Date) $seen 6>&1
        $ending = @($out | Where-Object { $_ -is [string] })
        $shown = ($out | Where-Object { $_ -is [Management.Automation.InformationRecord] } | ForEach-Object { "$_" }) -join "`n"
        $shown | Should -BeLike '*FAIL fixture_test_a: 30 gave 30, expected 60;*'
        $shown | Should -BeLike '*PASS fixture_test_b*'
        $ending | Should -Be @('finished')
        $seen.Keys | Sort-Object | Should -Be @('done', 'menu', 'tests')
    }
}
