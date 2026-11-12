# Tests for tools/run-game-tests.ps1 and the game lock (tools/game-lock.ps1): the run holds the lock
# while it uses the game, against a fake game. The deploy's side is in DeployLock.Tests.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $PSScriptRoot 'RunGameTestsSandbox.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
}

Describe 'run-game-tests.ps1 and the game lock' {
    BeforeEach { New-RunSandbox; $lock = Join-Path $x4 'game.lock' }
    AfterEach { Clear-GameLockEnv; Remove-RunSandbox }

    It 'holds the game lock while the game runs, naming itself, and frees it after' {
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Be 0
        Get-TestFile $env:FAKE_LOCKSEEN | Should -Match '(?m)^what=game-test$'
        $lock | Should -Not -Exist
    }

    It 'refuses while another run holds the game lock, without starting the game' {
        Write-TestGameLock $x4
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0 }
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -BeLike '*game-test (x4-swi-bounty-hunter, feature/other)*'
        $env:FAKE_ARGS | Should -Not -Exist
    }

    It 'runs under a lock its caller holds and leaves it to the caller' {
        Write-TestGameLock $x4
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0; X4_GAME_LOCK_TOKEN = 'other' }
        Set-Content $env:FAKE_SOURCE_LOG $script:PassingLog
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Be 0
        Get-TestFile $lock | Should -BeLike 'token=other*'
    }

    It 'frees the game lock when a check before the game fails' {
        Write-LfFile $contentXml '<content><extension id="SW Interworlds" enabled="false"/></content>'
        $r = Invoke-Script $script:Runner $runArgs
        $r.ExitCode | Should -Not -Be 0
        $lock | Should -Not -Exist
    }
}
