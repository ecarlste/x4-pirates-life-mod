# The game lock, PowerShell twin of tools/game-lock.sh: only one game run (or deploy
# into the game) at a time, across this repo and the bounty hunter's. The lock is the file
# <X4_PATH>\game.lock; its format and rules are in tools/README.md ("The game lock").
#
# Dot-source it, then:
#   $lock = Enter-GameLock <file> <what> <repo root>   # joins the line, takes the lock in turn; throws if it can't
#   Update-GameLock $lock                              # the heartbeat: call it in every loop while held
#   Exit-GameLock $lock                                # in a finally
#
# A caller that holds the lock hands it down in X4_GAME_LOCK_TOKEN (make game-test does); then
# Enter-GameLock uses it instead of waiting, and Exit-GameLock leaves it to that caller.
#
# Waiters take the lock in the order they arrived: each joins the line, a numbered ticket in
# <X4_PATH>\game.queue, and only the first in line takes the lock (tools/README.md, "The line").
#
# Environment: X4_GAME_LOCK_WAIT  seconds to wait in line (unset: no limit; 0 refuses at once if
#                                 the lock is held or anyone is in line)
#              X4_GAME_LOCK_STALE seconds a lock or ticket may go unchanged before it counts as
#                                 crashed: the first in line takes over such a lock, and a waiter
#                                 drops such a ticket ahead of it (default 60)
#              X4_GAME_LOCK_POLL  seconds between checks while waiting (default 5)

# A setting from the environment, or $Default ($null: none) when it's unset or empty
function Get-GameLockSetting([string] $Name, $Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { [double] $value } else { $Default }
}

# The lock file's text, or '' if it's gone or being rewritten right now
function Read-GameLockText([string] $File) {
    try { [IO.File]::ReadAllText($File) } catch { '' }
}

# The lock file's text as a waiter watches it: $null if it's gone or can't be read right now, so
# neither is taken for an empty lock
function Read-GameLockWatch([string] $File) {
    try { [IO.File]::ReadAllText($File) } catch { $null }
}

# One value from the lock file's KEY=value lines
function Get-GameLockField([string] $Text, [string] $Key) {
    $m = [regex]::Match($Text, "(?m)^$Key=(.*?)\r?$")
    if ($m.Success) { $m.Groups[1].Value } else { '' }
}

# Who holds the lock, for messages
function Get-GameLockHolder([string] $Text) {
    $f = @{}
    foreach ($k in 'what', 'repo', 'branch', 'pid', 'host', 'started') { $f[$k] = Get-GameLockField $Text $k }
    "$($f.what) ($($f.repo), $($f.branch)), pid $($f.pid) on $($f.host), since $($f.started)"
}

# Who holds the lock with text $Text, for messages; for one with no token in it (a crashed or
# interrupted write), "an empty lock file" or "an unreadable lock file"
function Get-GameLockWho([string] $Text) {
    if (Get-GameLockField $Text 'token') { Get-GameLockHolder $Text }
    elseif ($Text) { 'an unreadable lock file' }
    else { 'an empty lock file' }
}

# Writes the lock's lines to $File (default: the lock itself; a waiter's ticket has the same lines)
function Write-GameLockFile($Lock, [string] $File = $Lock.File) {
    $now = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $text = "token=$($Lock.Token)`nwhat=$($Lock.What)`nrepo=$($Lock.Repo)`nbranch=$($Lock.Branch)`npid=$PID`nhost=$($Lock.Host)`nstarted=$($Lock.Started)`nheartbeat=$($Lock.Beat) $now`n"
    [IO.File]::WriteAllText($File, $text)
}

# The tickets in the line $Queue, in line order (the zero-padded numbers sort)
function Get-GameLockTickets([string] $Queue) {
    @(Get-ChildItem -LiteralPath $Queue -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^\d{6}$' } | Sort-Object Name | ForEach-Object FullName)
}

# Joins the line $Queue: the next number, created exclusively, so two joiners never share one
function Join-GameLockLine([string] $Queue) {
    if (-not (Test-Path $Queue)) { New-Item -ItemType Directory -Force -Path $Queue | Out-Null }
    while ($true) {
        $last = Get-GameLockTickets $Queue | Select-Object -Last 1
        $next = 1 + $(if ($last) { [int] (Split-Path $last -Leaf) } else { 0 })
        $ticket = Join-Path $Queue ('{0:D6}' -f $next)
        try { [IO.File]::Open($ticket, 'CreateNew', 'Write', 'ReadWrite').Dispose(); return $ticket }
        catch [IO.IOException] { }  # taken just now: try the next number
    }
}

# 1st, 2nd, 3rd, 4th, ..., 11th, 12th, 13th, ..., 21st
function Get-GameLockOrdinal([int] $N) {
    $suffix = 'th'
    if (($N % 100) -notin 11, 12, 13) {
        switch ($N % 10) { 1 { $suffix = 'st' } 2 { $suffix = 'nd' } 3 { $suffix = 'rd' } }
    }
    "$N$suffix"
}

# Who holds the lock, or "free", for messages
function Get-GameLockHeld([string] $File) {
    if (Test-Path $File) { "held by $(Get-GameLockWho (Read-GameLockText $File))" } else { 'free' }
}

# The waiters named by ticket files, for messages: "A", "A and B", "A; B and C"
function Get-GameLockNames([string[]] $Tickets) {
    $names = @($Tickets | ForEach-Object { Get-GameLockHolder (Read-GameLockText $_) })
    if ($names.Count -le 1) { return "$names" }
    "$($names[0..($names.Count - 2)] -join '; ') and $($names[-1])"
}

function Enter-GameLock([string] $File, [string] $What, [string] $Root) {
    $wait = Get-GameLockSetting 'X4_GAME_LOCK_WAIT' $null
    $stale = Get-GameLockSetting 'X4_GAME_LOCK_STALE' 60
    if (($null -ne $wait -and $wait -ne [Math]::Floor($wait)) -or $stale -ne [Math]::Floor($stale)) { throw "X4_GAME_LOCK_WAIT and X4_GAME_LOCK_STALE take whole seconds" }
    $poll = Get-GameLockSetting 'X4_GAME_LOCK_POLL' 5

    # A lock handed down by a caller that holds it: use it, don't join the line
    $token = $env:X4_GAME_LOCK_TOKEN
    if ($token -and (Get-GameLockField (Read-GameLockText $File) 'token') -eq $token) {
        return [pscustomobject]@{ File = $File; Owned = $false }
    }

    $branch = ''
    try {
        $ErrorActionPreference = 'Continue'
        $branch = (& git -c 'safe.directory=*' -C $Root rev-parse --abbrev-ref HEAD 2>$null | Out-String).Trim()
    }
    catch { }
    $ErrorActionPreference = 'Stop'
    $lock = [pscustomobject]@{
        File = $File; Owned = $false; What = $What; Beat = 0
        Every = [Math]::Max(1, $stale / 6); Clock = [Diagnostics.Stopwatch]::StartNew()
        Token = "$PID-$([guid]::NewGuid().ToString('N'))"
        Repo = Split-Path $Root -Leaf
        Branch = $(if ($branch) { $branch } else { '-' })
        Host = $(if ($env:OS -eq 'Windows_NT') { 'windows' } else { 'linux' })
        Started = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    # Join the line, always, even when it's empty and the lock is free: one way in. The finally
    # leaves it however this ends: the lock taken, given up, failed or interrupted
    $parent = Split-Path $File -Parent
    if (-not (Test-Path $parent)) { throw "X4 install folder not found: $parent" }
    $queue = Join-Path $parent 'game.queue'
    $ticket = Join-GameLockLine $queue
    try {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $seen = $null
        $seenAt = 0.0
        $ticketSeen = @{}
        $shown = $null
        while ($true) {
            # Stay in line: rewrite the ticket, so the waiters behind can tell it from a crashed one
            try { Write-GameLockFile $lock $ticket } catch { }  # a waiter reading it right now; the next poll will do
            $lock.Beat++

            # The tickets ahead; drop one that stopped changing (its waiter crashed)
            $ahead = @()
            foreach ($t in Get-GameLockTickets $queue) {
                if ([string]::CompareOrdinal((Split-Path $t -Leaf), (Split-Path $ticket -Leaf)) -ge 0) { continue }
                $text = Read-GameLockText $t
                $now = $clock.Elapsed.TotalSeconds
                if (-not $ticketSeen.ContainsKey($t) -or $ticketSeen[$t].Text -ne $text) {
                    $ticketSeen[$t] = @{ Text = $text; At = $now }
                }
                elseif ($now - $ticketSeen[$t].At -ge $stale -and (Read-GameLockText $t) -eq $text) {
                    # Only if it's still the same text, as with the lock
                    Write-Host "Dropping $(Get-GameLockHolder $text) from the game lock's line: its ticket hasn't changed for $stale s, so it looks crashed"
                    Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue
                    continue
                }
                if (Test-Path -LiteralPath $t) { $ahead += $t }
            }

            # The lock: watched by every waiter, acted on only by the first in line. An empty lock (a
            # crashed or interrupted write) is text like any other, so it goes stale too; a missing
            # or unreadable one is $null, so a holder that has just created the file isn't taken for an
            # empty lock
            $text = Read-GameLockWatch $File
            if ($text -ne $seen) {
                $seen = $text
                $seenAt = $clock.Elapsed.TotalSeconds
            }
            if ($ahead.Count -eq 0) {
                try {
                    # CreateNew is exclusive: an old taker that skips the line may beat us
                    [IO.File]::Open($File, 'CreateNew', 'Write', 'ReadWrite').Dispose()
                    $lock.Owned = $true
                    $lock.Beat = 0
                    $lock.Started = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $lock.Clock.Restart()
                    Write-GameLockFile $lock
                    Remove-Item -LiteralPath $ticket -Force -ErrorAction SilentlyContinue
                    $behind = @(Get-GameLockTickets $queue).Count
                    if ($behind -gt 0) { Write-Host "Took the game lock; $behind waiting behind you; keep this run short" }
                    return $lock
                }
                catch [IO.IOException], [UnauthorizedAccessException] { }
                if ($null -ne $seen -and $clock.Elapsed.TotalSeconds - $seenAt -ge $stale -and
                    (Read-GameLockWatch $File) -eq $seen) {
                    # Only if it's still the same text: an old taker may have taken it over just now
                    Write-Host "Taking over the game lock: $(Get-GameLockWho $seen) hasn't updated it for $stale s, so it looks crashed"
                    Remove-Item -LiteralPath $File -Force -ErrorAction SilentlyContinue
                    continue
                }
                # Freed just now: try again at once
                if (-not (Test-Path -LiteralPath $File)) { continue }
            }

            $place = Get-GameLockOrdinal ($ahead.Count + 1)
            $place += $(if ($ahead.Count) { " in line, behind $(Get-GameLockNames $ahead)" } else { ' in line' })
            $held = Get-GameLockHeld $File
            if ($wait -eq 0 -or ($null -ne $wait -and $clock.Elapsed.TotalSeconds -ge $wait)) {
                $line = $(if ($ahead.Count) { ", with $($ahead.Count) in line ahead of you: $(Get-GameLockNames $ahead)" } else { '' })
                throw "The game lock ($File) isn't yours yet: $held$line. Try again when they're done (make game-queue shows the line); a crashed run's lock or ticket frees itself $stale s after its last update"
            }
            if ("$place; $held" -ne $shown) {
                $shown = "$place; $held"
                Write-Host "Waiting for the game lock: $shown"
            }
            Start-Sleep -Milliseconds ([int] ($poll * 1000))
        }
    }
    finally {
        Remove-Item -LiteralPath $ticket -Force -ErrorAction SilentlyContinue
    }
}

# The heartbeat: rewrites the lock so waiters can tell a long run from a crashed one. Call it as
# often as you like (in any loop); it writes every STALE/6 s at most, and only while the lock is
# still ours
function Update-GameLock($Lock) {
    if (-not $Lock -or -not $Lock.Owned -or $Lock.Clock.Elapsed.TotalSeconds -lt $Lock.Every) { return }
    $Lock.Clock.Restart()
    if ((Get-GameLockField (Read-GameLockText $Lock.File) 'token') -ne $Lock.Token) { return }
    $Lock.Beat++
    try { Write-GameLockFile $Lock } catch { }  # a waiter reading it right now; the next beat will do
}

function Exit-GameLock($Lock) {
    if (-not $Lock -or -not $Lock.Owned) { return }
    if ((Get-GameLockField (Read-GameLockText $Lock.File) 'token') -eq $Lock.Token) {
        Remove-Item $Lock.File -Force -ErrorAction SilentlyContinue
    }
    $Lock.Owned = $false
}
