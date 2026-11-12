# Tests for deploy.ps1 and the game lock (tools/game-lock.ps1). Run with tests/run.ps1 (or tests/run.sh).
# Mirrors the "Game lock" section of tests/deploy.bats, so both deploys share the lock's behavior.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # A file another process still has open for writing (Windows won't share it with ReadAllText)
    function Read-SharedText([string] $Path) {
        if (-not (Test-Path $Path)) { return '' }
        $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
        try { (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
    }
}

Describe 'deploy.ps1 and the game lock' {
    BeforeEach { $s = New-DeploySandbox; $lock = Join-Path $s.X4 'game.lock' }
    AfterEach { Clear-GameLockEnv; Remove-DeploySandbox $s }

    It 'refuses while another run holds the game lock, naming it' {
        Write-TestGameLock $s.X4
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -BeLike '*game-test (x4-swi-bounty-hunter, feature/other)*'
        $s.Target | Should -Not -Exist
    }

    It 'waits for the holder to finish, then deploys and frees the lock' {
        Write-TestGameLock $s.X4
        Set-GameLockEnv @{ X4_GAME_LOCK_POLL = 0.2 }
        $out = Join-Path $s.Root 'deploy.out'
        $deploy = Start-Process $script:PowerShellExe -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError "$out.err" `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $s.Repo 'deploy.ps1'), '-WorkingTree')
        $null = $deploy.Handle  # Windows PowerShell 5.1 only reports ExitCode if the handle was read while it ran
        # The holder finishes once the deploy is waiting for it
        for ($i = 0; $i -lt 300 -and -not $deploy.HasExited; $i++) {
            if ((Read-SharedText $out) -like '*Waiting for the game lock*') { break }
            Start-Sleep -Milliseconds 100
        }
        Remove-Item $lock
        $deploy.WaitForExit()

        $deploy.ExitCode | Should -Be 0
        Get-TestFile $out | Should -BeLike '*held by game-test (x4-swi-bounty-hunter, feature/other)*'
        "$($s.Target)/content.xml" | Should -Exist
        $lock | Should -Not -Exist
    }

    It 'takes over a lock that stopped changing, as from a crashed run' {
        Write-TestGameLock $s.X4
        Set-GameLockEnv @{ X4_GAME_LOCK_STALE = 1; X4_GAME_LOCK_POLL = 0.2 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Be 0
        $r.Output | Should -BeLike '*looks crashed*'
        "$($s.Target)/content.xml" | Should -Exist
        $lock | Should -Not -Exist
    }

    It "doesn't need the game lock for a dry run" {
        Write-TestGameLock $s.X4
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0 }

        (Invoke-Deploy $s @('-WorkingTree', '-DryRun')).ExitCode | Should -Be 0
        $lock | Should -Exist
    }

    It 'deploys under a lock its caller holds and leaves it to the caller' {
        Write-TestGameLock $s.X4
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0; X4_GAME_LOCK_TOKEN = 'other' }

        (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
        "$($s.Target)/content.xml" | Should -Exist
        Get-TestFile $lock | Should -BeLike 'token=other*'
    }

    It 'frees the game lock when the deploy fails after taking it' {
        # A file where the extension folder should be: the mirror fails, after the lock is taken
        Write-LfFile $s.Target 'not a folder'

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -BeLike '*Deploying working tree*'
        $lock | Should -Not -Exist
    }
}
