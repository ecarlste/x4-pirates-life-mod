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

    It 'takes over an empty lock that stopped changing, as from an interrupted write' {
        New-Item -ItemType File -Path $lock | Out-Null
        Set-GameLockEnv @{ X4_GAME_LOCK_STALE = 1; X4_GAME_LOCK_POLL = 0.2 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Be 0
        $r.Output | Should -BeLike '*Taking over the game lock: an empty lock file*looks crashed*'
        "$($s.Target)/content.xml" | Should -Exist
        $lock | Should -Not -Exist
    }

    It 'names an empty lock as such while waiting for it' {
        New-Item -ItemType File -Path $lock | Out-Null
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 0 }

        $r = Invoke-Deploy $s @('-WorkingTree')
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -BeLike '*held by an empty lock file*'
        $lock | Should -Exist
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

# The twin of deploy.bats's torn-ticket test, on game-lock.ps1 directly: deploy.ps1 can't slow its
# writes, as the text is built before each one
Describe "the game lock's rewrites" {
    BeforeAll { . (Join-Path $script:RepoRoot 'tools/game-lock.ps1') }
    BeforeEach { $dir = New-TestDir }
    AfterEach { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }

    It "a waiter's ticket stays whole while it rewrites it, so others can read its name" {
        # deploy.bats slows its writes with a slow git; here the text is built before the write, so a
        # long branch name slows each write instead, enough that a torn read would show. A second
        # runspace rewrites the ticket while this one reads it as the waiters behind do
        $ticket = Join-GameLockLine (Join-Path $dir 'game.queue')
        $lock = [pscustomobject]@{
            Token = 't'; What = 'deploy'; Repo = 'repo'; Branch = 'b' * 4MB
            Host = 'linux'; Started = 'now'; Beat = 0
        }
        Write-GameLockFile $lock $ticket
        $writer = [powershell]::Create().AddScript({
            param($Script, $Lock, $Ticket)
            . $Script
            for ($i = 1; $i -le 60; $i++) {
                $Lock.Beat = $i
                try { Write-GameLockFile $Lock $Ticket } catch { }  # a reader holding it open (Windows): as its callers do
            }
        }).AddArgument((Join-Path $script:RepoRoot 'tools/game-lock.ps1')).AddArgument($lock).AddArgument($ticket)
        $run = $writer.BeginInvoke()

        $torn = 0; $beats = @{}
        while (-not $run.IsCompleted) {
            $text = Read-GameLockText $ticket
            if ($text -match '(?m)^heartbeat=(\d+) \S+\n\z') { $beats[$Matches[1]] = $true } else { $torn++ }
        }
        $writer.EndInvoke($run); $writer.Dispose()

        # It read the ticket across rewrites, and every read was whole
        $beats.Count | Should -BeGreaterOrEqual 3
        $torn | Should -Be 0
    }
}

# A waiter watching the lock may have a newly taken one open while its taker writes the first lines;
# on Windows that blocks the rename. Only Windows shows the failure (tests/run.sh --windows-powershell)
Describe 'taking the game lock while a waiter reads it' {
    BeforeAll {
        . (Join-Path $script:RepoRoot 'tools/game-lock.ps1')
        # Opens the lock as soon as it exists, as a waiter's read does, and holds it $HoldMs. Returns
        # the length it found, so 0 shows it opened the lock before its first lines were written
        function Start-TestLockReader([string] $File, [int] $HoldMs) {
            $ready = [hashtable]::Synchronized(@{ Spinning = $false })
            $reader = [powershell]::Create().AddScript({
                param($File, $HoldMs, $Ready)
                $Ready.Spinning = $true
                $deadline = [DateTime]::UtcNow.AddSeconds(10)
                while ([DateTime]::UtcNow -lt $deadline) {
                    try { $stream = [IO.File]::Open($File, 'Open', 'Read', 'Read') } catch { continue }
                    try { $length = $stream.Length; Start-Sleep -Milliseconds $HoldMs; return $length }
                    finally { $stream.Dispose() }
                }
                -1
            }).AddArgument($File).AddArgument($HoldMs).AddArgument($ready)
            $run = $reader.BeginInvoke()
            while (-not $ready.Spinning) { Start-Sleep -Milliseconds 10 }
            [pscustomobject]@{ PowerShell = $reader; Run = $run }
        }
        function Stop-TestLockReader($Reader) {
            $length = $Reader.PowerShell.EndInvoke($Reader.Run)
            $Reader.PowerShell.Dispose()
            "$length"
        }
    }
    BeforeEach { $dir = New-TestDir; $file = Join-Path $dir 'game.lock' }
    AfterEach { Clear-GameLockEnv; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }

    It 'writes its first lines once the waiter lets go, not waiting on its own empty lock' {
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 2; X4_GAME_LOCK_POLL = 0.2 }
        $reader = Start-TestLockReader $file 300

        $lock = Enter-GameLock $file 'deploy' $script:RepoRoot
        try {
            Stop-TestLockReader $reader | Should -Be '0'  # it held the lock open while still empty
            $lock.Owned | Should -BeTrue
            Get-GameLockField (Read-GameLockText $file) 'token' | Should -Be $lock.Token
        }
        finally { Exit-GameLock $lock }
    }

    It 'fails, leaving the empty lock to go stale, if the waiter never lets go' -Skip:($env:OS -ne 'Windows_NT') {
        Set-GameLockEnv @{ X4_GAME_LOCK_WAIT = 2; X4_GAME_LOCK_POLL = 0.2 }
        $reader = Start-TestLockReader $file 3000

        { Enter-GameLock $file 'deploy' $script:RepoRoot } | Should -Throw "*couldn't write its first lines*"
        Stop-TestLockReader $reader | Should -Be '0'
        Get-TestFile $file | Should -Be ''
        Get-TestGameTickets $dir | Should -Be ''
    }
}
