# The game lock, PowerShell twin of tools/game-lock.sh: only one game run (or deploy
# into the game) at a time, across this repo and the bounty hunter's. The lock is the file
# <X4_PATH>\game.lock; its format and rules are in tools/README.md ("The game lock").
#
# Dot-source it, then:
#   $lock = Enter-GameLock <file> <what> <repo root>   # waits for another holder; throws if it can't
#   Update-GameLock $lock                              # the heartbeat: call it in every loop while held
#   Exit-GameLock $lock                                # in a finally
#
# A caller that holds the lock hands it down in X4_GAME_LOCK_TOKEN (make game-test does); then
# Enter-GameLock uses it instead of waiting, and Exit-GameLock leaves it to that caller.
#
# Environment: X4_GAME_LOCK_WAIT  seconds to wait for another holder (default 1800; 0 refuses at once)
#              X4_GAME_LOCK_STALE seconds a holder's lock may go unchanged before it counts as
#                                 crashed and is taken over (default 60)
#              X4_GAME_LOCK_POLL  seconds between checks while waiting (default 5)

function Get-GameLockSetting([string] $Name, [double] $Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { [double] $value } else { $Default }
}

# The lock file's text, or '' if it's gone or being rewritten right now
function Read-GameLockText([string] $File) {
    try { [IO.File]::ReadAllText($File) } catch { '' }
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

function Write-GameLockFile($Lock) {
    $now = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $text = "token=$($Lock.Token)`nwhat=$($Lock.What)`nrepo=$($Lock.Repo)`nbranch=$($Lock.Branch)`npid=$PID`nhost=$($Lock.Host)`nstarted=$($Lock.Started)`nheartbeat=$($Lock.Beat) $now`n"
    [IO.File]::WriteAllText($Lock.File, $text)
}

function Enter-GameLock([string] $File, [string] $What, [string] $Root) {
    $wait = Get-GameLockSetting 'X4_GAME_LOCK_WAIT' 1800
    $stale = Get-GameLockSetting 'X4_GAME_LOCK_STALE' 60
    if ($wait -ne [Math]::Floor($wait) -or $stale -ne [Math]::Floor($stale)) { throw "X4_GAME_LOCK_WAIT and X4_GAME_LOCK_STALE take whole seconds" }
    $poll = Get-GameLockSetting 'X4_GAME_LOCK_POLL' 5

    # A lock handed down by a caller that holds it: use it, don't wait for it
    $token = $env:X4_GAME_LOCK_TOKEN
    if ($token -and (Get-GameLockField (Read-GameLockText $File) 'token') -eq $token) {
        return [pscustomobject]@{ File = $File; Owned = $false }
    }

    $clock = [Diagnostics.Stopwatch]::StartNew()
    $seen = $null
    $seenAt = 0.0
    $holder = $null
    while ($true) {
        try {
            # CreateNew is exclusive: only one taker wins
            [IO.File]::Open($File, 'CreateNew', 'Write', 'ReadWrite').Dispose()
            $branch = ''
            try {
                $ErrorActionPreference = 'Continue'
                $branch = (& git -c 'safe.directory=*' -C $Root rev-parse --abbrev-ref HEAD 2>$null | Out-String).Trim()
            }
            catch { }
            $lock = [pscustomobject]@{
                File = $File; Owned = $true; What = $What; Beat = 0
                Every = [Math]::Max(1, $stale / 6); Clock = [Diagnostics.Stopwatch]::StartNew()
                Token = "$PID-$([guid]::NewGuid().ToString('N'))"
                Repo = Split-Path $Root -Leaf
                Branch = $(if ($branch) { $branch } else { '-' })
                Host = $(if ($env:OS -eq 'Windows_NT') { 'windows' } else { 'linux' })
                Started = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            Write-GameLockFile $lock
            return $lock
        }
        catch [IO.IOException], [UnauthorizedAccessException] {
            if (-not (Test-Path $File)) {
                # Not a lock held by someone else (the folder is missing, say), unless it was
                # released this very moment
                if (-not (Test-Path (Split-Path $File -Parent))) { throw }
                continue
            }
        }

        $text = Read-GameLockText $File
        if ($text -ne $seen) {
            $seen = $text
            $seenAt = $clock.Elapsed.TotalSeconds
        }
        elseif ($clock.Elapsed.TotalSeconds - $seenAt -ge $stale) {
            # Only if it's still the same text: another waiter may have taken it over just now
            if ((Read-GameLockText $File) -eq $seen) {
                Write-Host "Taking over the game lock: $(Get-GameLockHolder $text) hasn't updated it for $stale s, so it looks crashed"
                Remove-Item $File -Force -ErrorAction SilentlyContinue
            }
            $seen = $null
            continue
        }

        $now = Get-GameLockHolder $text
        if ($now -ne $holder) {
            $holder = $now
            if ($wait -gt 0) { Write-Host "Waiting for the game lock ($File): held by $holder" }
        }
        if ($clock.Elapsed.TotalSeconds -ge $wait) {
            throw "The game lock ($File) is held by $holder. Try again when it's done; if that run crashed, the lock frees itself $stale s after its last update"
        }
        Start-Sleep -Milliseconds ([int] ($poll * 1000))
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
