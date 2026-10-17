<#
.SYNOPSIS
    Unpacks X4: Foundations game catalogs (base game + DLCs) into a versioned reference folder.

.DESCRIPTION
    Finds XRCatTool.exe (from Egosoft's X Tools on Steam), then unpacks:
      - the base game's numbered catalogs (01.cat, 02.cat, ...) into <OutRoot>\x4-<Version>\base
      - each DLC's ext_*.cat into <OutRoot>\x4-<Version>\<dlc>
      - each DLC's subst_*.cat (replacements for base files) into <OutRoot>\x4-<Version>\<dlc>\_subst
    Catalogs are passed in numeric order, so later ones override earlier ones, as in the game.
    The output is reference data only and must never be committed to the repo.

.PARAMETER Version
    X4 version label for the output folder, e.g. 9.00. Shown in the game's main menu.

.PARAMETER X4Path
    X4 install folder.

.PARAMETER OutRoot
    Folder that will hold the x4-<Version> reference folder.

.PARAMETER ToolPath
    Full path to XRCatTool.exe. If omitted, the Steam library containing X4 is searched.

.PARAMETER Force
    Unpack even if the target folder already exists.

.EXAMPLE
    .\tools\unpack-x4.ps1 -Version 9.00

.EXAMPLE
    # From WSL:
    powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w tools/unpack-x4.ps1)" -Version 9.00
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Version,
    [string] $X4Path   = 'E:\SteamLibrary\steamapps\common\X4 Foundations',
    [string] $OutRoot  = 'E:\x4-dev\reference',
    [string] $ToolPath,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path (Join-Path $X4Path 'X4.exe'))) {
    throw "X4.exe not found in '$X4Path'. Pass -X4Path with your install folder."
}

if (-not $ToolPath) {
    $steamCommon = Split-Path $X4Path -Parent
    $ToolPath = Join-Path $steamCommon 'X Tools\XRCatTool.exe'
    if (-not (Test-Path $ToolPath)) {
        # Not in the usual place: search the whole Steam library, which can be slow
        $ToolPath = Get-ChildItem $steamCommon -Recurse -Filter XRCatTool.exe -ErrorAction SilentlyContinue |
                    Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $ToolPath -or -not (Test-Path $ToolPath)) {
    throw 'XRCatTool.exe not found. Install "X Tools" from your Steam library (Tools section) or pass -ToolPath.'
}

$out = Join-Path $OutRoot "x4-$Version"
if ((Test-Path $out) -and -not $Force) {
    throw "'$out' already exists. Use -Force to unpack over it, or pick another -Version."
}
New-Item -ItemType Directory -Force -Path $out | Out-Null

Write-Host "XRCatTool: $ToolPath"
Write-Host "Output:    $out"

function Invoke-Unpack {
    param([string] $Dir, [string] $Pattern, [string] $Dest)

    $cats = Get-ChildItem $Dir -Filter *.cat |
            Where-Object Name -match $Pattern |
            Sort-Object { [int]([regex]::Match($_.Name, '\d+').Value) }
    if (-not $cats) { return }

    $toolArgs = @()
    foreach ($c in $cats) { $toolArgs += '-in', $c.FullName }
    $toolArgs += '-out', $Dest

    Write-Host "Unpacking $($cats.Count) catalog(s) from $Dir -> $Dest"
    # XRCatTool refuses to write to an output folder that doesn't exist yet
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Push-Location $X4Path
    try {
        & $ToolPath @toolArgs
        if ($LASTEXITCODE -ne 0) { throw "XRCatTool exited with code $LASTEXITCODE for $Dir" }
    }
    finally { Pop-Location }
}

$sw = [Diagnostics.Stopwatch]::StartNew()

# Base game
Invoke-Unpack -Dir $X4Path -Pattern '^\d+\.cat$' -Dest (Join-Path $out 'base')

# DLCs
$extDir = Join-Path $X4Path 'extensions'
if (Test-Path $extDir) {
    Get-ChildItem $extDir -Directory -Filter 'ego_dlc_*' | ForEach-Object {
        $dest = Join-Path $out $_.Name
        Invoke-Unpack -Dir $_.FullName -Pattern '^ext_\d+\.cat$'   -Dest $dest
        Invoke-Unpack -Dir $_.FullName -Pattern '^subst_\d+\.cat$' -Dest (Join-Path $dest '_subst')
        $content = Join-Path $_.FullName 'content.xml'
        if (Test-Path $content) {
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item $content $dest
        }
    }
}

$sw.Stop()
Write-Host ("Done in {0:N1} min: {1}" -f $sw.Elapsed.TotalMinutes, $out)
Get-ChildItem $out -Directory | Select-Object Name | Format-Table -HideTableHeaders
