# Download helper for tests/run.ps1, kept separate so tests/Download.Tests.ps1 can test it.

# Downloads the first of $Urls that works into $OutFile, trying each a few times, and accepts it
# only if its SHA-256 matches $Sha256, so a corrupt or tampered download is never used. $Fetch
# does the actual download (url, file); the tests replace it.
function Save-VerifiedDownload {
    param(
        [Parameter(Mandatory)] [string[]] $Urls,
        [Parameter(Mandatory)] [string] $OutFile,
        [Parameter(Mandatory)] [string] $Sha256,
        [int] $Attempts = 3,
        [double] $DelaySeconds = 2,
        [scriptblock] $Fetch = { param($Url, $File) Invoke-WebRequest $Url -OutFile $File -UseBasicParsing }
    )
    $failures = @()
    foreach ($url in $Urls) {
        for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
            try {
                if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
                & $Fetch $url $OutFile
                $hash = (Get-FileHash $OutFile -Algorithm SHA256).Hash
                if ($hash -eq $Sha256) { return $url }
                throw "SHA-256 is $hash, expected $Sha256"
            }
            catch {
                $failures += "$url (attempt $attempt): $($_.Exception.Message)"
                if ($attempt -lt $Attempts) { Start-Sleep -Milliseconds ([int] ($DelaySeconds * 1000 * $attempt)) }
            }
        }
    }
    if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
    throw "Download failed:`n  $($failures -join "`n  ")"
}
