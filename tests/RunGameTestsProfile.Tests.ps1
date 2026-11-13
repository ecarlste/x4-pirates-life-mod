# Tests for tools/run-game-tests.ps1 as a whole: the checks before the game starts (the mod and
# SWI installed, a numeric profile ID, the test profile's extensions) and -PrepareProfile. How runs
# end is in RunGameTests.Tests.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $PSScriptRoot 'RunGameTestsSandbox.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
}

Describe 'run-game-tests.ps1 before the game starts' {
    BeforeEach { New-RunSandbox }
    AfterEach { Remove-RunSandbox }

    It 'refuses to run when the mod is not deployed' {
        Remove-Item "$x4/extensions/apirateslife" -Recurse
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike "*isn't deployed*"
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_MARK | Should -BeFalse
    }

    It 'refuses a profile ID that is not numeric, before starting anything' {
        $r = Invoke-Script $script:Runner ($runArgs -replace '^90000301$', 'tests')
        $r.Output | Should -BeLike '*X4_PROFILE_ID must be numeric*'
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
    }

    It 'refuses to start when SWI is off in the test profile' {
        Write-LfFile $contentXml '<content><extension id="apirateslife" enabled="true"/></content>'
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike "*'SW Interworlds' isn't switched on*-PrepareProfile*"
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
    }

    It 'refuses to start when the mod or the test extension is switched off in the test profile' -ForEach @('apirateslife', 'apirateslife_tests') {
        Write-LfFile $contentXml "<content><extension id=`"SW Interworlds`" enabled=`"true`"/><extension id=`"$_`" enabled=`"false`"/></content>"
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike "*'$_' isn't switched on*"
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
    }

    It 'prepares a new test profile from the root profile with -PrepareProfile, leaving the root profile alone' {
        Remove-Item $profileDir -Recurse
        $rootContent = '<content><extension id="SW Interworlds" enabled="false"/><extension id="apirateslife" enabled="false"/><extension id="other" enabled="true"/></content>'
        Write-LfFile "$profiles/content.xml" $rootContent
        Write-LfFile "$profiles/config.xml" '<config/>'
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner ($runArgs + @('-PrepareProfile'))
        $r.ExitCode | Should -Be 0
        $on = @(([xml] (Get-Content $contentXml -Raw)).content.extension | Where-Object { $_.enabled -eq 'true' } | ForEach-Object { $_.id })
        $on | Sort-Object | Should -Be @('apirateslife', 'apirateslife_tests', 'other', 'SW Interworlds')
        Get-TestFile "$profileDir/config.xml" | Should -Be '<config/>'
        Get-TestFile "$profiles/content.xml" | Should -Be $rootContent
    }

    It 'switches off every installed extension but the Egosoft DLCs, SWI and ours, so the run is SWI-only' {
        Write-LfFile "$x4/extensions/ego_dlc_pirate/content.xml" '<content id="ego_dlc_pirate"/>'
        Write-LfFile "$x4/extensions/starwars_rsp/content.xml" '<content id="starwars_rsp_id" enabled="1"/>'
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Be 0
        $r.Output | Should -BeLike '*Off in the test profile, so the run is SWI-only: starwars_rsp_id*'
        @(([xml] (Get-Content $contentXml -Raw)).content.extension | ForEach-Object { "$($_.id)=$($_.enabled)" }) |
            Should -Be @('SW Interworlds=true', 'apirateslife=true', 'starwars_rsp_id=false')
    }

    It 'refuses to run when SWI is not installed' {
        Remove-Item "$x4/extensions/starwarsmod_m1" -Recurse
        $r = Invoke-Script $script:Runner $runArgs
        $r.Output | Should -BeLike "*SWI isn't installed*"
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
    }
}

# make game-test runs these before its deploy, so a bad setup stops before the game folder changes
Describe 'run-game-tests.ps1 -PreflightOnly' {
    BeforeEach { New-RunSandbox }
    AfterEach { Remove-RunSandbox }

    It 'passes a good setup before the mod is deployed, then stops without touching the game' {
        Remove-Item "$x4/extensions/apirateslife" -Recurse
        $r = Invoke-Script $script:Runner ($runArgs + @('-PreflightOnly'))
        $r.Output | Should -BeLike '*Game test setup OK*'
        $r.ExitCode | Should -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
        Test-Path "$x4/extensions/apirateslife_tests" | Should -BeFalse
        Test-Path "$x4/game.lock" | Should -BeFalse
        Test-Path $report | Should -BeFalse
    }

    It 'fails when the game executable is missing' {
        $r = Invoke-Script $script:Runner (($runArgs -replace '^.*fakegame(\.cmd)?$', (Join-Path $root 'nope.exe')) + @('-PreflightOnly'))
        $r.Output | Should -BeLike '*nope.exe not found*'
        $r.ExitCode | Should -Not -Be 0
    }

    It 'fails a profile ID that is not numeric' {
        $r = Invoke-Script $script:Runner (($runArgs -replace '^90000301$', 'tests') + @('-PreflightOnly'))
        $r.Output | Should -BeLike '*X4_PROFILE_ID must be numeric*'
        $r.ExitCode | Should -Not -Be 0
    }

    It 'fails when the test profile is not ready' {
        Write-LfFile $contentXml '<content><extension id="apirateslife" enabled="true"/></content>'
        $r = Invoke-Script $script:Runner ($runArgs + @('-PreflightOnly'))
        $r.Output | Should -BeLike "*'SW Interworlds' isn't switched on*-PrepareProfile*"
        $r.ExitCode | Should -Not -Be 0
    }

    It 'leaves the profile to the run with -PrepareProfile, making nothing itself' {
        Remove-Item $profileDir -Recurse
        $r = Invoke-Script $script:Runner ($runArgs + @('-PreflightOnly', '-PrepareProfile'))
        $r.ExitCode | Should -Be 0
        Test-Path $profileDir | Should -BeFalse
    }
}
