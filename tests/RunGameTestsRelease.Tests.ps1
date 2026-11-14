# Tests for tools/run-game-tests.ps1 -Release as a whole: the release sessions against a fake game,
# what each session runs with, and what the run reports. The functions they use are tested in
# GameTestsRelease.Tests.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $PSScriptRoot 'RunGameTestsSandbox.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'

    # Session 1: a new game without the mod, saved
    $script:NewGameLog = @(
        '[=ERROR=] 2.50 [apirateslife-test] release: starting gamestart apirateslife_release_test'
        "[Init   ] 0.00 Starting new game using gamestart 'apirateslife_release_test' in 8.00 (600000)"
        "[FileIO ] 3.12 File I/O: Failed to verify the file signature for file '.\extensions\starwarsmod_m1\libraries\icons.xml' (error: 14)"
        "[FileIO ] 3.13 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife_release_tests\libraries\gamestarts.xml' (error: 14)"
        '[Scripts] 40.01 *** Context:x: [apirateslife-test] RUN START 0 tests'
        '[Scripts] 43.00 *** Context:x: [apirateslife-test] SAVED apirateslife_release_1'
        '[Scripts] 43.01 *** Context:x: [apirateslife-test] DONE passed=0 failed=0'
    )
    # Session 2: that save loaded with the mod, the harness's tests run on it, and saved again
    $script:LoadLog = @(
        '[=ERROR=] 2.50 [apirateslife-test] release: loading save apirateslife_release_1'
        "[FileIO ] 3.12 File I/O: Failed to verify the file signature for file '.\extensions\starwarsmod_m1\libraries\icons.xml' (error: 14)"
        "[FileIO ] 3.13 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife\libraries\icons.xml' (error: 14)"
        '[Scripts] 30.00 *** Context:x: [apirateslife-test] LOADED apirateslife_release_test'
        '[Scripts] 40.01 *** Context:x: [apirateslife-test] RUN START 3 tests'
        '[Scripts] 40.03 *** Context:x: [apirateslife-test] PASS config_applied_on_start: 8 settings at their config values'
        '[Scripts] 44.00 *** Context:x: [apirateslife-test] PASS capture_start_and_destroyed: started, refused twice, ended as destroyed'
        '[Scripts] 60.00 *** Context:x: [apirateslife-test] PASS release_leftovers: left 2 taken ships, a called-off and a running operation'
        '[Scripts] 60.01 *** Context:x: [apirateslife-test] DONE passed=3 failed=0'
        '[Scripts] 63.00 *** Context:x: [apirateslife-test] SAVED apirateslife_release_2'
    )
    # Session 3: the second save loaded without the mod, played, and the release extension's checks. X4
    # logs that it can't import the running operation's wingman's capture order, which session 3 allows
    $script:UnloadLog = @(
        '[=ERROR=] 2.50 [apirateslife-test] release: loading save apirateslife_release_2'
        "[FileIO ] 3.12 File I/O: Failed to verify the file signature for file '.\extensions\starwarsmod_m1\libraries\icons.xml' (error: 14)"
        "[=ERROR=] 14.06 Error importing AI order [0xc]: Order definition 'APiratesLife_Capture' not found"
        "[=ERROR=] 14.06 Error on AI director import: AI script name 'order.apirateslife.capture' not found"
        '[Scripts] 30.00 *** Context:x: [apirateslife-test] LOADED apirateslife_release_test'
        '[Scripts] 32.00 *** Context:x: [apirateslife-test] RUN START 1 tests'
        '[Scripts] 900.00 *** Context:x: [apirateslife-test] PASS uninstall_leftovers: everything stayed, played 600 s'
        '[Scripts] 900.01 *** Context:x: [apirateslife-test] DONE passed=1 failed=0'
    )

    # The extensions' entries in a profile content.xml, as id=enabled, in ordinal order
    function Get-ProfileStates([string] $Path) {
        [string[]] $states = ([xml] (Get-Content $Path -Raw)).content.extension | ForEach-Object { "$($_.id)=$($_.enabled)" }
        [Array]::Sort($states, [StringComparer]::Ordinal)
        $states
    }
}

Describe 'run-game-tests.ps1 -Release' {
    BeforeEach {
        New-RunSandbox
        Set-Content "$env:FAKE_SOURCE_LOG.new" $script:NewGameLog
        Set-Content "$env:FAKE_SOURCE_LOG.load" $script:LoadLog
        Set-Content "$env:FAKE_SOURCE_LOG.unload" $script:UnloadLog
        Write-LfFile $contentXml @'
<?xml version="1.0" encoding="utf-8"?>
<content>
  <extension id="SW Interworlds" enabled="true"/>
  <extension id="apirateslife" enabled="true"/>
  <extension id="apirateslife_tests" enabled="true"/>
</content>
'@
    }
    AfterEach { Remove-RunSandbox }

    It 'saves a game without the mod, loads it with the mod and runs the capture tests on it, then loads that save without the mod' {
        $r = Invoke-Script $script:Runner ($runArgs + @('-Release'))
        $r.Output | Should -BeLike '*PASS existing_save_loads: saved apirateslife_release_1 without the mod, loaded it with the mod: 3 tests passed*'
        $r.Output | Should -BeLike '*PASS save_plays_without_mod: saved apirateslife_release_2 with the mod, loaded it without: 1 checks passed*'
        $r.Output | Should -BeLike '*PASS clean_log (session 1):*'
        $r.Output | Should -BeLike '*PASS load_order_after_swi (session 2):*'
        $r.Output | Should -BeLike '*PASS clean_log (session 3): no errors or warnings from our files in debuglog.txt (2 allowed in this session)*'
        $r.Output | Should -Not -BeLike '*load_order_after_swi (session 1)*'
        $r.Output | Should -Not -BeLike '*load_order_after_swi (session 3)*'
        # 4 tests, 7 log checks across the sessions and the 2 release checks
        $r.Output | Should -BeLike '*Game tests passed (13 of 13)*'
        $r.ExitCode | Should -Be 0
        # Session 1: the mod and the game tests off, only the release extension installed
        Get-ProfileStates "$env:FAKE_ARGS.new.xml" | Should -Be @('SW Interworlds=true', 'apirateslife=false', 'apirateslife_release_tests=true', 'apirateslife_tests=false')
        Test-Path "$env:FAKE_MARK.new" | Should -BeFalse
        # Session 2: both on, the harness's autostart starting nothing and its list set to the release tests
        Get-ProfileStates "$env:FAKE_ARGS.load.xml" | Should -Be @('SW Interworlds=true', 'apirateslife=true', 'apirateslife_release_tests=true', 'apirateslife_tests=true')
        Get-Content "$env:FAKE_MARK.load" | Should -Be 'installed'
        Get-Content "$env:FAKE_ARGS.load.autostart" | Should -Contain 'local gamestart = nil'
        . $script:Runner
        Get-GameTestNames (Get-Content "$env:FAKE_ARGS.load.harness" -Raw) | Should -Be @('ConfigAppliedOnStart', 'CaptureStartAndDestroyed', 'ReleaseLeftovers')
        # Session 3: the mod and the game tests off again, the release extension loading session 2's save
        Get-ProfileStates "$env:FAKE_ARGS.unload.xml" | Should -Be @('SW Interworlds=true', 'apirateslife=false', 'apirateslife_release_tests=true', 'apirateslife_tests=false')
        # Afterwards: the profile as a game test run needs it, nothing left installed, each session's log kept
        Get-ProfileStates $contentXml | Should -Contain 'apirateslife=true'
        Get-ProfileStates $contentXml | Should -Contain 'apirateslife_tests=true'
        Test-Path "$x4/extensions/apirateslife_tests" | Should -BeFalse
        Test-Path "$x4/extensions/apirateslife_release_tests" | Should -BeFalse
        Get-Content (Join-Path $profileDir 'debuglog.release-1.txt') | Should -Contain '[Scripts] 43.00 *** Context:x: [apirateslife-test] SAVED apirateslife_release_1'
        Get-Content (Join-Path $profileDir 'debuglog.release-2.txt') | Should -Contain '[Scripts] 63.00 *** Context:x: [apirateslife-test] SAVED apirateslife_release_2'
        Get-Content (Join-Path $profileDir 'debuglog.release-3.txt') | Should -Contain '[Scripts] 32.00 *** Context:x: [apirateslife-test] RUN START 1 tests'
        (Get-Content $markdown)[0] | Should -Be '<!-- apirateslife-game-tests commit=0123456789abcdef0123456789abcdef01234567 dirty=false result=pass passed=13 total=13 release=true -->'
        Get-Content $markdown | Should -Contain 'Release sessions (`-Release`): a save made without the mod, loaded with it, then saved and loaded without it. Not the game test suite.'
    }

    It 'removes old release saves before session 1, so a later session can''t load them' {
        Write-LfFile (Join-Path $profileDir 'save/apirateslife_release_1.xml.gz') 'old'
        Write-LfFile (Join-Path $profileDir 'save/apirateslife_release_2.xml.gz') 'old'
        $r = Invoke-Script $script:Runner ($runArgs + @('-Release'))
        $r.ExitCode | Should -Be 0
        Test-Path (Join-Path $profileDir 'save/apirateslife_release_1.xml.gz') | Should -BeFalse
        Test-Path (Join-Path $profileDir 'save/apirateslife_release_2.xml.gz') | Should -BeFalse
    }

    It 'skips session 3 when session 2 saved nothing, and fails the uninstall check' {
        Set-Content "$env:FAKE_SOURCE_LOG.load" ($script:LoadLog -replace 'SAVED apirateslife_release_2', 'SAVE FAILED: the game reported a failed save')
        $r = Invoke-Script $script:Runner ($runArgs + @('-Release'))
        $r.Output | Should -BeLike '*PASS existing_save_loads:*'
        $r.Output | Should -BeLike '*FAIL save_plays_without_mod: session 2 saved nothing (the game reported a failed save); session 3 loaded no save;*'
        $r.ExitCode | Should -Be 1
        Test-Path "$env:FAKE_ARGS.unload.xml" | Should -BeFalse
    }

    It 'stops after a session that saved nothing, and fails the release check' {
        Set-Content "$env:FAKE_SOURCE_LOG.new" ($script:NewGameLog -replace 'SAVED apirateslife_release_1', 'SAVE FAILED: no save within 60s')
        $r = Invoke-Script $script:Runner ($runArgs + @('-Release'))
        $r.Output | Should -BeLike '*FAIL existing_save_loads: session 1 saved nothing (no save within 60s)*'
        $r.Output | Should -BeLike '*GAME TESTS FAILED*'
        $r.ExitCode | Should -Be 1
        Test-Path "$env:FAKE_ARGS.load.xml" | Should -BeFalse
        Get-ProfileStates $contentXml | Should -Contain 'apirateslife=true'
    }

    It 'refuses -Release with <_>, before anything changes' -ForEach @('-Test', '-Repeat', '-KeepExtension') {
        $extra = switch ($_) { '-Test' { @('-Test', 'capture_wing_holds_fire') } '-Repeat' { @('-Repeat', '2') } default { @($_) } }
        $r = Invoke-Script $script:Runner ($runArgs + @('-Release') + $extra)
        $r.Output | Should -BeLike '*-Release runs its own sessions*'
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
    }
}
