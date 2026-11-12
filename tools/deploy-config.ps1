# deploy.config's settings for the PowerShell tools, dot-sourced by deploy.ps1 and
# tools/run-game-tests.ps1. A setting comes from the environment, else the checkout's own
# deploy.config, else, in a linked worktree, the main checkout's, so worktrees need no copy.
# tools/deploy-config.sh and tools/diff-patches/config.ts are its bash and TypeScript twins; keep
# the three in step.

# A worktree's gitdir as this machine can open it. Relative to the worktree, or absolute; a WSL
# worktree's is a Linux path (/home/...), which Windows reaches through the \\wsl.localhost\<distro>
# (or \\wsl$\<distro>) share the worktree itself was opened through.
function Resolve-GitDir([string] $Root, [string] $GitDir) {
    if ($GitDir.StartsWith('/') -and $Root -match '^(\\\\wsl(\.localhost|\$)\\[^\\]+)\\') {
        return $Matches[1] + ($GitDir -replace '/', '\')
    }
    if ([IO.Path]::IsPathRooted($GitDir)) { return $GitDir }
    [IO.Path]::GetFullPath((Join-Path $Root $GitDir))
}

# The main checkout of the worktree at $Root, from its .git file (gitdir: <main>/.git/worktrees/<name>)
# and that folder's commondir (../..); '' for a main checkout, or anything else
function Get-MainCheckout([string] $Root) {
    $dotGit = Join-Path $Root '.git'
    if (-not (Test-Path $dotGit -PathType Leaf)) { return '' }
    $line = Get-Content $dotGit | Where-Object { $_ -match '^gitdir:\s*(.+?)\s*$' } | Select-Object -First 1
    if (-not $line) { return '' }
    $gitDir = Resolve-GitDir $Root ($line -replace '^gitdir:\s*', '').Trim()
    $common = $gitDir
    $commondirFile = Join-Path $gitDir 'commondir'
    if (Test-Path $commondirFile -PathType Leaf) {
        $common = Join-Path $gitDir ((Get-Content $commondirFile | Select-Object -First 1).Trim())
    }
    if (-not (Test-Path $common -PathType Container)) { return '' }
    $common = [IO.Path]::GetFullPath($common).TrimEnd('\', '/')
    if ((Split-Path $common -Leaf) -ne '.git') { return '' }
    Split-Path $common -Parent
}

# The deploy.config files to read, in order: the checkout's own, then the main checkout's
function Get-DeployConfigFiles([string] $Root) {
    $main = Get-MainCheckout $Root
    foreach ($dir in @($Root, $main)) {
        if (-not $dir) { continue }
        $file = Join-Path $dir 'deploy.config'
        if (Test-Path $file -PathType Leaf) { $file }
    }
}

# A KEY="value" line, read and never run: the last one in a file wins, quotes optional, and an empty
# value counts as not set. '' if no file sets the key.
function Get-ConfigValue([string] $Root, [string] $Key) {
    foreach ($file in Get-DeployConfigFiles $Root) {
        $line = Get-Content $file | Where-Object { $_ -match "^\s*$Key\s*=" } | Select-Object -Last 1
        if (-not $line) { continue }
        $value = ($line -replace "^\s*$Key\s*=", '').Trim().Trim('"').Trim("'")
        if ($value) { return $value }
    }
    ''
}

# A setting from the environment, else deploy.config, else the default
function Resolve-Setting([string] $Root, [string] $Key, [string] $Default) {
    $value = [Environment]::GetEnvironmentVariable($Key)
    if (-not $value) { $value = Get-ConfigValue $Root $Key }
    if (-not $value) { $value = $Default }
    $value
}
