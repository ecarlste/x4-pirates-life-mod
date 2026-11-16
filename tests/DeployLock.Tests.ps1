# Tests for deploy.ps1 and the game lock (tools/game-lock.ps1). Run with tests/run.ps1 (or tests/run.sh).
# Mirrors the "Game lock" section of tests/deploy.bats, so both deploys share the lock's behavior.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
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

Describe "deploy.ps1 and the game lock's line" {
    BeforeEach { $s = New-DeploySandbox; $lock = Join-Path $s.X4 'game.lock'; $keeper = $null }
    AfterEach {
        if ($keeper) { Stop-Process -Id $keeper.Id -Force -ErrorAction SilentlyContinue }
        Clear-GameLockEnv; Remove-DeploySandbox $s
    }

    It 'leaves no ticket in the line once it has the lock' {
        (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
        Join-Path $s.X4 'game.queue' | Should -Exist
        Get-TestGameTickets $s.X4 | Should -Be ''
    }

    It 'refuses at once when someone is in line, even with the lock free, naming them' {
        Write-TestGameTicket $s.X4 1
        $keeper = Start-TestTicketKeeper $s.X4 1
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Not -Be 0
        (Get-FlatText $r.Output) | Should -BeLike '*deploy (x4-swi-bounty-hunter, feature/waiter1)*'
        $s.Target | Should -Not -Exist
        # Its own ticket is gone; the other waiter's stays
        Get-TestGameTickets $s.X4 | Should -Be '000001'
    }

    It 'refuses at once naming both the holder and the line' {
        Write-TestGameLock $s.X4
        Write-TestGameTicket $s.X4 1
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Not -Be 0
        (Get-FlatText $r.Output) | Should -BeLike '*held by game-test (x4-swi-bounty-hunter, feature/other)*'
        (Get-FlatText $r.Output) | Should -BeLike '*deploy (x4-swi-bounty-hunter, feature/waiter1)*'
    }

    It 'waits behind an earlier ticket even with the lock free, saying its place' {
        Write-TestGameTicket $s.X4 1
        $keeper = Start-TestTicketKeeper $s.X4 1
        Set-GameLockEnv @{ X4_GAME_LOCK_POLL = 0.2 }
        $out = Join-Path $s.Root 'deploy.out'
        $deploy = Start-TestScript (Join-Path $s.Repo 'deploy.ps1') @('-WorkingTree') $out
        Wait-TestText $out '*Waiting for the game lock*' $deploy
        $s.Target | Should -Not -Exist
        # The waiter ahead takes its turn and leaves
        Remove-Item (Join-Path $s.X4 'game.queue/000001')
        $deploy.WaitForExit()

        $deploy.ExitCode | Should -Be 0
        Get-TestFile $out | Should -BeLike '*2nd in line, behind deploy (x4-swi-bounty-hunter, feature/waiter1)*'
        "$($s.Target)/content.xml" | Should -Exist
        Get-TestGameTickets $s.X4 | Should -Be ''
    }

    It 'drops a ticket ahead of it that stopped changing, as from a crashed waiter' {
        Write-TestGameTicket $s.X4 1
        Set-GameLockEnv @{ X4_GAME_LOCK_STALE = 1; X4_GAME_LOCK_POLL = 0.2 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Be 0
        $r.Output | Should -BeLike '*feature/waiter1*looks crashed*'
        "$($s.Target)/content.xml" | Should -Exist
        Get-TestGameTickets $s.X4 | Should -Be ''
    }

    It "only the first in line takes over a crashed holder's lock" {
        Write-TestGameLock $s.X4
        Write-TestGameTicket $s.X4 1
        $keeper = Start-TestTicketKeeper $s.X4 1
        Set-GameLockEnv @{ X4_GAME_LOCK_STALE = 1; X4_GAME_LOCK_POLL = 0.2; X4_GAME_LOCK_WAIT = 3 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Not -BeLike '*Taking over*'
        Get-TestFile $lock | Should -BeLike 'token=other*'
        $s.Target | Should -Not -Exist
    }

    It 'gives up after X4_GAME_LOCK_WAIT seconds in line and leaves the line' {
        Write-TestGameLock $s.X4
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 1; X4_GAME_LOCK_POLL = 0.2 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Not -Be 0
        (Get-FlatText $r.Output) | Should -BeLike '*Waiting for the game lock: 1st in line; held by game-test (x4-swi-bounty-hunter, feature/other)*'
        (Get-FlatText $r.Output) | Should -BeLike '*held by game-test*Try again*'
        Get-TestGameTickets $s.X4 | Should -Be ''
    }

    It 'two waiting deploys take the lock in the order they joined' {
        Write-TestGameLock $s.X4
        Set-GameLockEnv @{ X4_GAME_LOCK_POLL = 0.2 }
        $first = Start-TestScript (Join-Path $s.Repo 'deploy.ps1') @('-WorkingTree') (Join-Path $s.Root 'first')
        Wait-TestText (Join-Path $s.Root 'first') '*Waiting for the game lock*' $first
        $second = Start-TestScript (Join-Path $s.Repo 'deploy.ps1') @('-WorkingTree') (Join-Path $s.Root 'second')
        Wait-TestText (Join-Path $s.Root 'second') '*Waiting for the game lock*' $second
        Remove-Item $lock
        $first.WaitForExit()
        $second.WaitForExit()

        $first.ExitCode | Should -Be 0
        $second.ExitCode | Should -Be 0
        Get-TestFile (Join-Path $s.Root 'second') | Should -BeLike '*2nd in line, behind deploy*'
        # The first takes the lock while the second still waits behind it
        Get-TestFile (Join-Path $s.Root 'first') | Should -BeLike '*1 waiting behind you; keep this run short*'
        Get-TestFile (Join-Path $s.Root 'second') | Should -Not -BeLike '*waiting behind you*'
        Get-TestGameTickets $s.X4 | Should -Be ''
        $lock | Should -Not -Exist
    }

    It 'a lock its caller hands down skips the line' {
        Write-TestGameLock $s.X4
        Write-TestGameTicket $s.X4 1
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0; X4_GAME_LOCK_TOKEN = 'other' }

        (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
        "$($s.Target)/content.xml" | Should -Exist
        Get-TestGameTickets $s.X4 | Should -Be '000001'
    }

    It 'leaves the line when the deploy fails after taking the lock' {
        Write-LfFile $s.Target 'not a folder'

        (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Not -Be 0
        Get-TestGameTickets $s.X4 | Should -Be ''
        $lock | Should -Not -Exist
    }
}
