<#
.SYNOPSIS
    Runs the Pester suites (tests/*.Tests.ps1).

.DESCRIPTION
    Works in Windows PowerShell 5.1 and PowerShell 7. Pester 5 is downloaded into .tools/
    on first run, so nothing is installed machine-wide (Windows ships the incompatible Pester 3).

.PARAMETER CI
    Exit non-zero on failure and write a JUnit report to tests/results.xml.

.PARAMETER SetupOnly
    Fetch Pester if needed, then stop. tests/run.sh does this once before starting its parallel runs.

.PARAMETER Path
    Run only these test files (default: every tests/*.Tests.ps1); commas separate several in one
    argument. tests/run.sh runs each file in its own process, in parallel.

.PARAMETER Name
    Run only the tests whose full name ("<Describe> <It>") matches this wildcard pattern.

.PARAMETER Repeat
    Run the selected tests this many times and report how many runs failed, to measure a flaky
    test's failure rate (docs/testing.md, Flaky tests). Fails if any run failed.

.EXAMPLE
    .\tests\run.ps1

.EXAMPLE
    .\tests\run.ps1 -Path tests/RunGameTests.Tests.ps1 -Name '*fails a run with a failing test' -Repeat 50
#>
[CmdletBinding()]
param([switch] $CI, [switch] $SetupOnly, [string[]] $Path, [string] $Name, [int] $Repeat = 0)

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

if ($SetupOnly) { return }

Import-Module $manifest -Force

$config = New-PesterConfiguration
# tests/run.sh and CI pass several files as one comma-separated argument
$Path = @($Path | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$config.Run.Path = if ($Path) { $Path } else { $PSScriptRoot }
$config.Output.Verbosity = 'Detailed'
if ($Name) { $config.Filter.FullName = $Name }

if ($Repeat -gt 0) {
    if ($CI) { throw '-Repeat is for measuring a flaky test locally; it writes no JUnit report, so it does not go with -CI' }
    # Quiet runs; each failed run prints its first failure, then one count at the end
    $config.Output.Verbosity = 'None'
    $config.Run.PassThru = $true
    $failed = 0
    for ($i = 1; $i -le $Repeat; $i++) {
        $result = Invoke-Pester -Configuration $config
        if ($result.TotalCount -eq $result.NotRunCount) {
            Write-Host "no test matches $(if ($Name) { "'$Name'" } else { 'in these files' })"
            exit 1
        }
        if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
            $failed++
            $first = if ($result.Failed.Count) { $result.Failed[0] } else { $result.FailedContainers[0] }
            $where = if ($first.ExpandedPath) { $first.ExpandedPath } else { $first.Item }
            # A setup block that throws fails its tests with the error on the block, not the test
            $errors = $first.ErrorRecord
            for ($block = $first.Block; -not $errors.Count -and $block; $block = $block.Parent) { $errors = $block.ErrorRecord }
            Write-Host "Run $i failed: ${where}: $(if ($errors.Count) { $errors[0].Exception.Message })"
        }
    }
    Write-Host "$failed of $Repeat runs failed ($($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion))"
    if ($failed) { exit 1 }
    exit 0
}
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
