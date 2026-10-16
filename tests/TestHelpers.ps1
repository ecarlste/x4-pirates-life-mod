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
           ForEach-Object { "$_" }
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($out -join "`n") }
}

function Invoke-Deploy($s, [string[]] $Arguments = @()) {
    Invoke-Script (Join-Path $s.Repo 'deploy.ps1') $Arguments
}

function Get-TestFile([string] $Path) {
    if (Test-Path $Path) { [IO.File]::ReadAllText($Path).TrimEnd("`r", "`n") }
}
