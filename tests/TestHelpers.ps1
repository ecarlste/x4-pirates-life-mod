# Shared setup for the Pester suites. Dot-source it from BeforeAll.

$script:RepoRoot = Split-Path $PSScriptRoot -Parent
$script:OnWindows = $env:OS -eq 'Windows_NT'
# Run scripts in the same PowerShell edition that is running the tests
$script:PowerShellExe = (Get-Process -Id $PID).Path

function New-TestDir {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("x4test-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $dir | Out-Null
    (Get-Item $dir).FullName
}

function Write-LfFile([string] $Path, [string] $Value) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
    [IO.File]::WriteAllText($Path, $Value.Replace("`r`n", "`n"))
}

function Invoke-TestGit {
    & git @args 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed" }
}

# Creates a sandbox like tests/helpers.bash: a bare origin, a clone holding the real deploy
# script plus a small test mod (id "testmod"), and a fake X4 install.
function New-DeploySandbox {
    $s = @{ Root = New-TestDir }
    $s.Origin = Join-Path $s.Root 'origin.git'
    $s.Repo = Join-Path $s.Root 'repo'
    $s.X4 = Join-Path $s.Root 'x4'
    $s.Target = Join-Path $s.X4 'extensions/testmod'
    New-Item -ItemType Directory -Force -Path (Join-Path $s.X4 'extensions') | Out-Null

    # Isolate git from the developer's own config (signing, hooks, autocrlf)
    $emptyConfig = Join-Path $s.Root 'gitconfig'
    Write-LfFile $emptyConfig ''
    $env:GIT_CONFIG_GLOBAL = $emptyConfig
    $env:GIT_CONFIG_NOSYSTEM = '1'
    $env:GIT_AUTHOR_NAME = 'Test'; $env:GIT_AUTHOR_EMAIL = 'test@example.com'
    $env:GIT_COMMITTER_NAME = 'Test'; $env:GIT_COMMITTER_EMAIL = 'test@example.com'
    $env:X4_PATH = $s.X4

    Invoke-TestGit init -q --bare -b main $s.Origin
    Invoke-TestGit init -q -b main $s.Repo
    foreach ($f in 'deploy.ps1', 'deploy.include') {
        Copy-Item (Join-Path $script:RepoRoot $f) $s.Repo
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $s.Repo 'tools') | Out-Null
    foreach ($f in 'tools/game-lock.ps1', 'tools/deploy-config.ps1') {
        Copy-Item (Join-Path $script:RepoRoot $f) (Join-Path $s.Repo 'tools')
    }
    Set-TestModId $s 'testmod'
    Write-LfFile (Join-Path $s.Repo 'libraries/god.xml') '<diff/>'
    Write-LfFile (Join-Path $s.Repo 'md/sub/nested.xml') '<mdscript/>'
    Write-LfFile (Join-Path $s.Repo 'docs/notes.md') 'not part of the mod'
    Save-TestCommit $s 'initial'
    Invoke-TestGit -C $s.Repo remote add origin $s.Origin
    Invoke-TestGit -C $s.Repo push -q -u origin main
    $s
}

function Remove-DeploySandbox($s) {
    foreach ($v in 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM', 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL',
                   'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'X4_PATH') {
        Remove-Item "env:$v" -ErrorAction SilentlyContinue
    }
    if ($s -and (Test-Path $s.Root)) { Remove-Item $s.Root -Recurse -Force }
}

function Set-TestModId($s, [string] $Id) {
    Write-LfFile (Join-Path $s.Repo 'content.xml') "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<content id=`"$Id`" name=`"Test`" version=`"100`" save=`"false`"/>`n"
}

function Save-TestCommit($s, [string] $Message) {
    Invoke-TestGit -C $s.Repo add -A
    Invoke-TestGit -C $s.Repo commit -q -m $Message
}

# Simulate another developer merging to main on the remote
function Push-FromOtherClone($s, [string] $Path, [string] $Value) {
    $other = Join-Path $s.Root 'other'
    if (-not (Test-Path $other)) { Invoke-TestGit clone -q $s.Origin $other }
    Invoke-TestGit -C $other pull -q
    Write-LfFile (Join-Path $other $Path) $Value
    Invoke-TestGit -C $other add -A
    Invoke-TestGit -C $other commit -q -m "change $Path"
    Invoke-TestGit -C $other push -q origin main
}

# Runs a script in a child PowerShell, like a developer would, and captures everything it prints
function Invoke-Script([string] $Script, [string[]] $Arguments) {
    $ErrorActionPreference = 'Continue'
    $out = & $script:PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1 |
           ForEach-Object { "$_" -replace "\x1b\[[0-9;]*m", '' }  # pwsh 7 colors errors; ANSI codes break the JUnit XML
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($out -join "`n") }
}

function Invoke-Deploy($s, [string[]] $Arguments = @()) {
    Invoke-Script (Join-Path $s.Repo 'deploy.ps1') $Arguments
}

function Get-TestFile([string] $Path) {
    if (Test-Path $Path) { [IO.File]::ReadAllText($Path).TrimEnd("`r", "`n") }
}

# A config file shaped like md/apirateslife_config.xml, for the -Set tests
function Write-TestConfig($s) {
    Write-LfFile "$($s.Repo)/md/apirateslife_config.xml" @'
<?xml version="1.0" encoding="utf-8"?>
<mdscript name="APiratesLife_Config">
  <cues>
    <library name="Defaults" purpose="run_actions">
      <actions>
        <set_value name="global.$APiratesLife_CaptureFloorHull" exact="35"/>
        <set_value name="global.$APiratesLife_IntactOnClaim" exact="1"/>
      </actions>
    </library>
  </cues>
</mdscript>
'@
}

# The deployed value of one config setting
function Get-DeployedSetting($s, [string] $Name) {
    $text = [IO.File]::ReadAllText("$($s.Target)/md/apirateslife_config.xml")
    [regex]::Match($text, "APiratesLife_$Name"" exact=""([^""]*)""").Groups[1].Value
}

# A game lock held by another run, as tools/game-lock.ps1 and tools/game-lock.sh write it
function Write-TestGameLock([string] $X4) {
    Write-LfFile (Join-Path $X4 'game.lock') "token=other`nwhat=game-test`nrepo=x4-swi-bounty-hunter`nbranch=feature/other`npid=4242`nhost=windows`nstarted=2026-11-11T09:00:00Z`nheartbeat=1 2026-11-11T09:00:00Z`n"
}

# A ticket in the game lock's line (<X4>\game.queue), as another waiter writes it
function Write-TestGameTicket([string] $X4, [int] $Number, [string] $What = 'deploy') {
    $file = Join-Path (Join-Path $X4 'game.queue') ('{0:D6}' -f $Number)
    Write-LfFile $file "token=t$Number`nwhat=$What`nrepo=x4-swi-bounty-hunter`nbranch=feature/waiter$Number`npid=$Number`nhost=windows`nstarted=2026-11-11T09:00:00Z`nheartbeat=1 2026-11-11T09:00:00Z`n"
}

# Keeps a ticket changing, as a live waiter does, in a child process; stop it with Stop-Process
function Start-TestTicketKeeper([string] $X4, [int] $Number) {
    $file = Join-Path (Join-Path $X4 'game.queue') ('{0:D6}' -f $Number)
    # Open, not Append: it never recreates a ticket the test removed. Encoded, since Start-Process
    # would strip the quotes inside a plain -Command
    $loop = @"
`$n = 0
while (Test-Path '$file') {
    `$n++
    try {
        `$f = [IO.File]::Open('$file', 'Open', 'Write', 'ReadWrite, Delete')
        `$null = `$f.Seek(0, 'End')
        `$b = [Text.Encoding]::UTF8.GetBytes("beat=`$n``n")
        `$f.Write(`$b, 0, `$b.Length)
        `$f.Dispose()
    }
    catch { }
    Start-Sleep -Milliseconds 200
}
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($loop))
    Start-Process $script:PowerShellExe -PassThru -NoNewWindow -ArgumentList @('-NoProfile', '-EncodedCommand', $encoded)
}

# The tickets in the game lock's line, by file name, in line order
function Get-TestGameTickets([string] $X4) {
    $queue = Join-Path $X4 'game.queue'
    if (-not (Test-Path $queue)) { return '' }
    (@(Get-ChildItem $queue | Sort-Object Name | ForEach-Object Name)) -join ' '
}

# Starts a script in a child PowerShell without waiting; its output goes to $Out
function Start-TestScript([string] $Script, [string[]] $Arguments, [string] $Out) {
    $p = Start-Process $script:PowerShellExe -PassThru -NoNewWindow -RedirectStandardOutput $Out -RedirectStandardError "$Out.err" `
        -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script) + $Arguments)
    $null = $p.Handle  # Windows PowerShell 5.1 only reports ExitCode if the handle was read while it ran
    $p
}

# Waits up to 30 s for a wildcard pattern in a file another process is writing
function Wait-TestText([string] $Path, [string] $Pattern, $Process) {
    for ($i = 0; $i -lt 300; $i++) {
        if ((Read-SharedText $Path) -like $Pattern) { return }
        if ($Process -and $Process.HasExited) { break }
        Start-Sleep -Milliseconds 100
    }
    throw "Never saw '$Pattern' in ${Path}: $(Read-SharedText $Path)"
}

# A file another process still has open for writing (Windows won't share it with ReadAllText)
function Read-SharedText([string] $Path) {
    if (-not (Test-Path $Path)) { return '' }
    $stream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try { (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
}

# Output with pwsh 7's error layout undone: it wraps an error's text to the console width behind a
# "|" gutter. Squeezes each line break, with its gutter, to one space
function Get-FlatText([string] $Text) {
    ($Text -replace '\s*\n\s*(\|\s+)?', ' ')
}

# Sets the lock's environment variables for one test; Clear-GameLockEnv undoes it
function Set-GameLockEnv([hashtable] $Values) {
    foreach ($k in $Values.Keys) { [Environment]::SetEnvironmentVariable($k, [string] $Values[$k]) }
}

function Clear-GameLockEnv {
    foreach ($k in 'X4_GAME_LOCK_WAIT', 'X4_GAME_LOCK_STALE', 'X4_GAME_LOCK_POLL', 'X4_GAME_LOCK_TOKEN') {
        [Environment]::SetEnvironmentVariable($k, $null)
    }
}
