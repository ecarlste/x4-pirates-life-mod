# Tests for tools/run-game-tests.ps1's release sessions (-Release): reading their logs, the
# existing_save_loads check, and the rewrites of the installed test extensions. Whole -Release runs
# against a fake game are in RunGameTestsRelease.Tests.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
    . $script:Runner
}

Describe 'Read-GameTestLog in a release session' {
    It 'reads the save a session wrote' {
        $run = Read-GameTestLog @(
            '[=ERROR=] 2.50 [apirateslife-test] release: starting gamestart apirateslife_release_test'
            '[Scripts] 40.01 *** Context:md.APiratesLife_ReleaseTests.NewGame: [apirateslife-test] RUN START 0 tests'
            '[Scripts] 43.00 *** Context:md.APiratesLife_ReleaseTests.Finish: [apirateslife-test] SAVED apirateslife_release_1'
            '[Scripts] 43.01 *** Context:md.APiratesLife_ReleaseTests.Finish: [apirateslife-test] DONE passed=0 failed=0'
        )
        $run.Saved | Should -Be 'apirateslife_release_1'
        $run.MenuReady | Should -BeTrue
        $run.Done | Should -BeTrue
        $run.Results.Count | Should -Be 0
    }

    It 'reads why a save failed' {
        $run = Read-GameTestLog @('[Scripts] 43.00 *** Context:x: [apirateslife-test] SAVE FAILED: no save within 60s')
        $run.Saved | Should -Be ''
        $run.SaveFailed | Should -Be 'no save within 60s'
    }

    It 'reads a loaded game, and the main menu it was loaded from' {
        $run = Read-GameTestLog @(
            '[=ERROR=] 2.50 [apirateslife-test] release: loading save apirateslife_release_1'
            '[Scripts] 30.00 *** Context:md.APiratesLife_ReleaseTests.Loaded: [apirateslife-test] LOADED apirateslife_release_test'
        )
        $run.Loaded | Should -Be 'apirateslife_release_test'
        $run.MenuReady | Should -BeTrue
    }

    It 'has no save or load in a plain run' {
        $run = Read-GameTestLog @('[Scripts] 40.01 *** Context:x: [apirateslife-test] RUN START 2 tests')
        $run.Saved | Should -Be ''
        $run.Loaded | Should -Be ''
    }
}

Describe 'Get-ExistingSaveCheck' {
    BeforeAll {
        # Session 1: a new game without the mod, saved. Session 2: that save loaded with the mod, and
        # the harness's tests run on it
        $script:WithoutMod = @(
            "[FileIO ] 3.12 File I/O: Failed to verify the file signature for file '.\extensions\starwarsmod_m1\libraries\icons.xml' (error: 14)"
            "[FileIO ] 3.13 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife_release_tests\libraries\gamestarts.xml' (error: 14)"
            '[Scripts] 40.01 *** Context:x: [apirateslife-test] RUN START 0 tests'
            '[Scripts] 43.00 *** Context:x: [apirateslife-test] SAVED apirateslife_release_1'
            '[Scripts] 43.01 *** Context:x: [apirateslife-test] DONE passed=0 failed=0'
        )
        $script:WithMod = @(
            "[FileIO ] 3.13 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife\libraries\icons.xml' (error: 14)"
            '[Scripts] 30.00 *** Context:x: [apirateslife-test] LOADED apirateslife_release_test'
            '[Scripts] 40.01 *** Context:x: [apirateslife-test] RUN START 2 tests'
            '[Scripts] 40.03 *** Context:x: [apirateslife-test] PASS config_applied_on_start: 8 settings at their config values'
            '[Scripts] 44.00 *** Context:x: [apirateslife-test] PASS capture_start_and_destroyed: started, refused twice, ended as destroyed'
            '[Scripts] 44.01 *** Context:x: [apirateslife-test] DONE passed=2 failed=0'
        )
    }

    It 'passes a save made without the mod that loads with it, its tests passing and its log clean' {
        $check = Get-ExistingSaveCheck (Read-GameTestLog $script:WithoutMod) (Read-GameTestLog $script:WithMod)
        $check.Name | Should -Be 'existing_save_loads'
        $check.Passed | Should -BeTrue
        $check.Detail | Should -Be 'saved apirateslife_release_1 without the mod, loaded it with the mod: 2 tests passed, no errors or warnings from our files'
    }

    It 'fails when session 1 saved nothing, with why' {
        $without = $script:WithoutMod -replace 'SAVED apirateslife_release_1', 'SAVE FAILED: no save within 60s'
        $check = Get-ExistingSaveCheck (Read-GameTestLog $without) (Read-GameTestLog $script:WithMod)
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be 'session 1 saved nothing (no save within 60s);'
    }

    It 'fails when session 1 read files from the mod, so it was on' {
        $without = $script:WithoutMod + @("[FileIO ] 3.14 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife\md\apirateslife_bail.xml' (error: 14)")
        $check = Get-ExistingSaveCheck (Read-GameTestLog $without) (Read-GameTestLog $script:WithMod)
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be 'session 1 read files from apirateslife, so the mod was on;'
    }

    It 'fails when session 2 started a game instead of loading one, and read nothing from the mod' {
        $with = @($script:WithMod | Where-Object { $_ -notmatch 'LOADED|extensions' })
        $check = Get-ExistingSaveCheck (Read-GameTestLog $script:WithoutMod) (Read-GameTestLog $with)
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be 'session 2 loaded no save; session 2 read no files from apirateslife, so the mod was off;'
    }

    It 'fails when session 2''s tests failed or didn''t finish, or its log has errors from our files' {
        $with = @($script:WithMod -replace 'PASS capture_start', 'FAIL capture_start' | Where-Object { $_ -notmatch 'DONE' }) +
            @("[=ERROR=] 50.00 No matching node for path '//do_if' in patch file 'extensions\apirateslife\aiscripts\move.claim.xml'. Skipping node.")
        $check = Get-ExistingSaveCheck (Read-GameTestLog $script:WithoutMod) (Read-GameTestLog $with)
        $check.Passed | Should -BeFalse
        $check.Detail | Should -Be "session 2's tests didn't finish; 1 of session 2's tests failed: capture_start_and_destroyed; 1 errors or warnings from our files in session 2's log;"
    }
}

Describe 'Rewriting the installed test extensions for a release session' {
    BeforeAll {
        $script:ReleaseLua = Get-Content (Join-Path $script:RepoRoot 'tests/game/apirateslife_release_tests/ui/apirateslife_release_tests.lua') -Raw
        $script:AutostartLua = Get-Content (Join-Path $script:RepoRoot 'tests/game/apirateslife_tests/ui/apirateslife_tests_autostart.lua') -Raw
    }

    It 'sets what the release extension starts, loads and saves, on its session line' {
        $text = Set-ReleaseSession $script:ReleaseLua ([pscustomobject]@{ New = 'apirateslife_release_test'; Load = ''; Save = 'apirateslife_release_1' })
        $text | Should -Match '(?m)^local session = \{ new = "apirateslife_release_test", save = "apirateslife_release_1" \}\r?$'
        ([regex]::Matches($text, '(?m)^local session = ')).Count | Should -Be 1
        $text = Set-ReleaseSession $script:ReleaseLua ([pscustomobject]@{ New = ''; Load = 'apirateslife_release_1'; Save = '' })
        $text | Should -Match '(?m)^local session = \{ load = "apirateslife_release_1" \}\r?$'
    }

    It 'fails on a release extension without the session line' {
        { Set-ReleaseSession 'local x = 1' ([pscustomobject]@{ New = 'a'; Load = ''; Save = '' }) } | Should -Throw '*no session line*'
    }

    It 'stops the game tests'' autostart from starting its gamestart' {
        $text = Disable-TestAutostart $script:AutostartLua
        $text | Should -Match '(?m)^local gamestart = nil\r?$'
        $text | Should -Not -Match 'local gamestart = "'
    }

    It 'fails on an autostart without the gamestart line' {
        { Disable-TestAutostart 'local x = 1' } | Should -Throw '*no gamestart line*'
    }

    It 'counts the release extension as one of ours in an SWI-only run' {
        Test-AllowedInSwiOnlyRun 'apirateslife_release_tests' | Should -BeTrue
    }
}
