<#
.SYNOPSIS
    Syncs the mod into the X4 extensions folder.

.DESCRIPTION
    PowerShell twin of deploy.sh (Windows PowerShell 5.1 or PowerShell 7 on any OS).
    Mirrors the paths listed in deploy.include into <X4_PATH>\extensions\<id from content.xml>,
    removing files that are no longer part of the mod. By default it deploys the latest
    origin/main, not your working tree.

    X4_PATH comes from the X4_PATH environment variable, else deploy.config (see deploy.config.example).

.PARAMETER Ref
    Git ref to deploy. Defaults to origin/main, which is fetched first.

.PARAMETER WorkingTree
    Deploy the files on disk instead, including uncommitted changes.

.PARAMETER Set
    Override settings from md/apirateslife_config.xml in the deployed copy only, as NAME=VALUE
    (e.g. -Set IntactOnEject=0, or -Set IntactOnEject=0,IntactOnClaim=0). The repo copy is untouched.

.PARAMETER DryRun
    Show what would change without touching the game folder.

.EXAMPLE
    .\deploy.ps1

.EXAMPLE
    .\deploy.ps1 -Ref feature/my-branch -DryRun

.EXAMPLE
    .\deploy.ps1 -WorkingTree -Set IntactOnEject=0
#>
[CmdletBinding()]
param(
    [string] $Ref,
    [switch] $WorkingTree,
    [string[]] $Set,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

if ($WorkingTree -and $Ref) { throw "-Ref and -WorkingTree can't be combined" }

# The repo may live in WSL (\\wsl.localhost\...), which Windows git treats as another
# user's folder; allow it for these calls only.
function Invoke-Git {
    & git -c 'safe.directory=*' @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

# Runs git just for its exit code. Windows PowerShell 5.1 turns redirected stderr into a
# terminating error under 'Stop', so relax it locally.
function Test-Git {
    $ErrorActionPreference = 'Continue'
    & git -c 'safe.directory=*' @args 2>$null | Out-Null
    $LASTEXITCODE -eq 0
}

function Read-Include([string[]] $Lines) {
    $Lines | ForEach-Object { ($_ -replace '#.*', '').Trim() } | Where-Object { $_ }
}

function Get-RelativeFiles([string] $Root) {
    $files = @{}
    if (Test-Path $Root) {
        $full = (Get-Item $Root).FullName.TrimEnd('\', '/')
        Get-ChildItem $full -Recurse -File -Force | ForEach-Object {
            $files[$_.FullName.Substring($full.Length + 1)] = $_.FullName
        }
    }
    $files
}

Push-Location $PSScriptRoot
$stage = Join-Path ([IO.Path]::GetTempPath()) ("x4deploy-" + [guid]::NewGuid())
try {
    # Resolve the X4 install folder: environment first, then deploy.config
    $x4Path = $env:X4_PATH
    if (-not $x4Path) {
        if (-not (Test-Path deploy.config)) {
            throw "deploy.config not found. Copy deploy.config.example to deploy.config and set X4_PATH"
        }
        $line = Get-Content deploy.config | Where-Object { $_ -match '^\s*X4_PATH\s*=' } | Select-Object -Last 1
        if ($line) { $x4Path = ($line -replace '^\s*X4_PATH\s*=', '').Trim().Trim('"').Trim("'") }
    }
    if (-not $x4Path) { throw "X4_PATH not set in deploy.config" }
    if (-not (Test-Path $x4Path -PathType Container)) { throw "X4 install folder not found: $x4Path" }

    $stageMod = Join-Path $stage 'mod'
    New-Item -ItemType Directory -Force -Path $stageMod | Out-Null

    # Stage the mod files
    if ($WorkingTree) {
        if (-not (Test-Path deploy.include)) { throw "deploy.include not found" }
        foreach ($p in Read-Include (Get-Content deploy.include)) {
            if (Test-Path $p) { Copy-Item $p $stageMod -Recurse }
        }
        $source = "working tree"
    }
    else {
        if (-not $Ref) {
            $Ref = 'origin/main'
            if (-not (Test-Git fetch --quiet origin main)) { Write-Warning "Couldn't fetch origin; deploying the last fetched origin/main" }
        }
        if (-not (Test-Git rev-parse --verify --quiet "$Ref^{commit}")) { throw "unknown git ref: $Ref" }
        if (-not (Test-Git cat-file -e "${Ref}:deploy.include")) { throw "$Ref has no deploy.include; deploy a newer ref or use -WorkingTree" }

        $paths = @(Read-Include (Invoke-Git show "${Ref}:deploy.include") |
                   Where-Object { Test-Git cat-file -e "${Ref}:$_" })
        if (-not $paths) { throw "nothing to deploy at $Ref" }

        $tarFile = Join-Path $stage 'mod.tar'
        # Ship files exactly as committed (Windows git may otherwise convert them to CRLF)
        Invoke-Git -c core.autocrlf=false archive --format=tar -o $tarFile $Ref -- @paths
        # Prefer Windows' own tar: Git's GNU tar, if first on PATH, reads "C:\..." as a remote host
        $tar = 'tar'
        if ($env:SystemRoot -and (Test-Path (Join-Path $env:SystemRoot 'System32\tar.exe'))) {
            $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
        }
        & $tar -xf $tarFile -C $stageMod
        if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
        $source = "$Ref @ $(Invoke-Git log -1 --format='%h %s' $Ref)"
    }

    $contentXml = Join-Path $stageMod 'content.xml'
    if (-not (Test-Path $contentXml)) { throw "content.xml missing from the deployed files" }
    $modId = ([xml](Get-Content $contentXml -Raw)).content.id
    # The id names a folder we mirror into with deletes, so it must not escape extensions\
    if ($modId -notmatch '^[A-Za-z0-9_-][A-Za-z0-9_.-]*$') { throw "couldn't read a valid extension id from content.xml" }
    $target = Join-Path (Join-Path $x4Path 'extensions') $modId

    # Apply -Set overrides to the staged config only; the repo copy is never touched
    $setSummary = @()
    if ($Set) {
        $config = Join-Path $stageMod 'md/apirateslife_config.xml'
        if (-not (Test-Path $config)) { throw "-Set needs md/apirateslife_config.xml in the deployed files" }
        $text = [IO.File]::ReadAllText($config)
        $valid = @([regex]::Matches($text, 'name="global\.\$APiratesLife_([A-Za-z0-9_]+)"') | ForEach-Object { $_.Groups[1].Value })
        # Comma lists arrive as one string when the script is run with -File, so split them here
        foreach ($s in @($Set | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
            if ($s -notmatch '^([^=]+)=(.*)$') { throw "-Set needs NAME=VALUE, got: $s" }
            $name = $Matches[1]; $value = $Matches[2]
            if ($name -notmatch '^[A-Za-z0-9_]+$' -or $valid -notcontains $name) { throw "unknown setting '$name' (valid: $($valid -join ' '))" }
            if ($value -notmatch '^[A-Za-z0-9_.-]+$') { throw "invalid value for ${name}: '$value' (letters, digits, '_', '.', '-' only)" }
            $text = [regex]::Replace($text, '(name="global\.\$APiratesLife_' + $name + '" exact=")[^"]*"', { param($m) $m.Groups[1].Value + $value + '"' })
            $setSummary += "$name=$value"
        }
        [IO.File]::WriteAllText($config, $text)
    }

    Write-Host "Deploying $source" -ForegroundColor Green
    Write-Host "  to $target"
    if ($setSummary) { Write-Host "  with settings: $($setSummary -join ', ')" }
    if ($DryRun) { Write-Host "Dry run: nothing will be changed" -ForegroundColor Yellow }

    # Mirror the staged files into the target, deleting anything that's no longer in the mod
    $src = Get-RelativeFiles $stageMod
    $dst = Get-RelativeFiles $target
    $changed = 0
    foreach ($rel in ($src.Keys | Sort-Object)) {
        if ($dst.ContainsKey($rel) -and
            (Get-FileHash $src[$rel]).Hash -eq (Get-FileHash $dst[$rel]).Hash) { continue }
        Write-Host "  send $rel"
        $changed++
        if (-not $DryRun) {
            $dest = Join-Path $target $rel
            New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
            Copy-Item $src[$rel] $dest -Force
        }
    }
    foreach ($rel in ($dst.Keys | Where-Object { -not $src.ContainsKey($_) } | Sort-Object)) {
        Write-Host "  del. $rel"
        $changed++
        if (-not $DryRun) { Remove-Item $dst[$rel] -Force }
    }
    if (-not $DryRun -and (Test-Path $target)) {
        # Remove folders left empty by deletions, deepest first
        Get-ChildItem $target -Recurse -Directory -Force |
            Sort-Object { $_.FullName.Length } -Descending |
            Where-Object { -not (Get-ChildItem $_.FullName -Force) } |
            Remove-Item -Force
    }
    if ($changed -eq 0) { Write-Host "  (already up to date)" }

    if (-not $DryRun) {
        Write-Host "Deployment successful! " -ForegroundColor Green -NoNewline
        Write-Host "Restart X4 to pick up changes."
    }
}
finally {
    Pop-Location
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
}
