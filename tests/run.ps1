<#
.SYNOPSIS
    Runs the Pester suites (tests/*.Tests.ps1).

.DESCRIPTION
    Works in Windows PowerShell 5.1 and PowerShell 7. Pester 5 is downloaded into .tools/
    on first run, so nothing is installed machine-wide (Windows ships the incompatible Pester 3).

.PARAMETER CI
    Exit non-zero on failure and write a JUnit report to tests/results.xml.

.EXAMPLE
    .\tests\run.ps1
#>
[CmdletBinding()]
param([switch] $CI)

$ErrorActionPreference = 'Stop'
$PesterVersion = '5.7.1'
# SHA-256 of that version's package; update both together
$PesterSha256 = '4a27904c6814a5fbe4758f8e49861f6a1994aee77b71165a5c43c0371ba6c580'
# The PowerShell Gallery's CDN first, then its API (which returned 404 for a while on 2026-10-22)
$PesterUrls = @(
    "https://cdn.powershellgallery.com/packages/pester.$PesterVersion.nupkg"
    "https://www.powershellgallery.com/api/v2/package/Pester/$PesterVersion"
)

$root = Split-Path $PSScriptRoot -Parent
$toolsDir = Join-Path $root '.tools'
if ($root.StartsWith('\\') -and $env:LOCALAPPDATA) {
    # .NET Framework won't load Pester's DLL from a network path such as \\wsl.localhost\...
    $toolsDir = Join-Path $env:LOCALAPPDATA 'x4-pirates-life-mod\tools'
}
$pesterDir = Join-Path $toolsDir "pester-$PesterVersion"
$manifest = Join-Path $pesterDir 'Pester.psd1'

if (-not (Test-Path $manifest)) {
    Write-Host "Fetching Pester $PesterVersion into .tools/"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    . (Join-Path $PSScriptRoot 'Download.ps1')
    $zip = Join-Path ([IO.Path]::GetTempPath()) "pester-$PesterVersion.zip"
    $from = Save-VerifiedDownload -Urls $PesterUrls -OutFile $zip -Sha256 $PesterSha256
    Write-Host "Downloaded from $from"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # A failed earlier extraction leaves a folder without the manifest; start clean
    if (Test-Path $pesterDir) { Remove-Item $pesterDir -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $pesterDir)
    Remove-Item $zip
}

Import-Module $manifest -Force

$config = New-PesterConfiguration
$config.Run.Path = $PSScriptRoot
$config.Output.Verbosity = 'Detailed'
if ($CI) {
    $config.Run.Exit = $true
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'JUnitXml'
    $config.TestResult.OutputPath = Join-Path $PSScriptRoot 'results.xml'
}
else {
    $config.Run.PassThru = $true
}

$result = Invoke-Pester -Configuration $config
if ($result -and $result.FailedCount -gt 0) { exit 1 }
