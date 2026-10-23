# Tests for tests/Download.ps1 (how tests/run.ps1 fetches Pester), with a fake fetch instead of
# real downloads.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    . (Join-Path $PSScriptRoot 'Download.ps1')

    $script:Content = 'package bytes'
    $bytes = [Text.Encoding]::UTF8.GetBytes($script:Content)
    $script:GoodHash = -join ([Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })

    # A fake fetch: logs each url to $script:Calls, then for each url in order takes the next
    # planned outcome: 'ok' writes the package, 'bad' writes other bytes, 'fail' throws
    function New-FakeFetch([hashtable] $Plan) {
        $script:Calls = New-Object System.Collections.ArrayList
        $script:Plan = $Plan
        {
            param($Url, $File)
            [void] $script:Calls.Add($Url)
            $outcome, $rest = $script:Plan[$Url]
            $script:Plan[$Url] = @($rest)
            switch ($outcome) {
                'ok' { [IO.File]::WriteAllText($File, $script:Content) }
                'bad' { [IO.File]::WriteAllText($File, 'something else') }
                default { throw "404 Not Found" }
            }
        }
    }

    function Save-Test([string[]] $Urls, [scriptblock] $Fetch) {
        Save-VerifiedDownload -Urls $Urls -OutFile $script:Out -Sha256 $script:GoodHash -DelaySeconds 0 -Fetch $Fetch
    }
}

Describe 'Save-VerifiedDownload' {
    BeforeEach {
        $dir = New-TestDir
        $script:Out = Join-Path $dir 'package.zip'
    }
    AfterEach { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'downloads from the first url when it works' {
        $fetch = New-FakeFetch @{ cdn = @('ok'); api = @('ok') }
        Save-Test @('cdn', 'api') $fetch | Should -Be 'cdn'
        $script:Calls | Should -Be @('cdn')
        Get-Content $script:Out | Should -Be $script:Content
    }

    It 'retries a failing url before moving on' {
        $fetch = New-FakeFetch @{ cdn = @('fail', 'ok'); api = @('ok') }
        Save-Test @('cdn', 'api') $fetch | Should -Be 'cdn'
        $script:Calls | Should -Be @('cdn', 'cdn')
    }

    It 'falls back to the next url when one keeps failing' {
        $fetch = New-FakeFetch @{ cdn = @('fail', 'fail', 'fail'); api = @('ok') }
        Save-Test @('cdn', 'api') $fetch | Should -Be 'api'
        $script:Calls | Should -Be @('cdn', 'cdn', 'cdn', 'api')
    }

    It 'rejects a download whose SHA-256 does not match' {
        $fetch = New-FakeFetch @{ cdn = @('bad', 'bad', 'bad'); api = @('ok') }
        Save-Test @('cdn', 'api') $fetch | Should -Be 'api'
        Get-Content $script:Out | Should -Be $script:Content
    }

    It 'fails with every attempt listed, and leaves no file, when nothing works' {
        $fetch = New-FakeFetch @{ cdn = @('fail', 'fail', 'fail'); api = @('bad', 'bad', 'bad') }
        { Save-Test @('cdn', 'api') $fetch } | Should -Throw '*cdn (attempt 3): 404 Not Found*api (attempt 1): SHA-256 is *'
        Test-Path $script:Out | Should -BeFalse
    }
}
