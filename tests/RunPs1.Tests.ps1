# Tests for tests/run.ps1's -Repeat and -Name, which run one test many times to measure a flaky
# test's failure rate (docs/testing.md, Flaky tests). Runs tests/run.ps1 on a fixture suite.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:RunPs1 = Join-Path $PSScriptRoot 'run.ps1'
}

Describe 'run.ps1 -Repeat' {
    BeforeEach {
        $script:dir = New-TestDir
        $env:FIXTURE_COUNTER = Join-Path $dir 'count.txt'
        $script:suite = Join-Path $dir 'Fixture.Tests.ps1'
        # 'flaky one' fails on every other run; 'always fails' fails every time
        Write-LfFile $suite @'
Describe 'fixture' {
    It 'flaky one' {
        $n = 0
        if (Test-Path $env:FIXTURE_COUNTER) { $n = [int] (Get-Content $env:FIXTURE_COUNTER) }
        $n++
        Set-Content $env:FIXTURE_COUNTER $n
        $n % 2 | Should -Be 1 -Because "run $n"
    }
    It 'steady one' { 1 | Should -Be 1 }
    It 'always fails' { 1 | Should -Be 2 }
}
'@
    }
    AfterEach {
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item env:FIXTURE_COUNTER -ErrorAction SilentlyContinue
    }

    It 'runs only the named test, that many times, and counts the runs that failed' {
        $r = Invoke-Script $script:RunPs1 @('-Path', $suite, '-Name', '*flaky one', '-Repeat', '4')
        $r.Output | Should -BeLike '*2 of 4 runs failed*'
        $r.Output | Should -BeLike '*run 2*'
        $r.Output | Should -Not -BeLike '*always fails*'
        $r.ExitCode | Should -Be 1
        Get-Content $env:FIXTURE_COUNTER | Should -Be '4'
    }

    It 'passes when every run passes' {
        $r = Invoke-Script $script:RunPs1 @('-Path', $suite, '-Name', '*steady one', '-Repeat', '3')
        $r.Output | Should -BeLike '*0 of 3 runs failed*'
        $r.ExitCode | Should -Be 0
    }

    It 'counts a run whose test file breaks as a failed run' {
        Write-LfFile $suite "BeforeAll { throw 'setup broke' }`nDescribe 'fixture' { It 'steady one' { 1 | Should -Be 1 } }`n"
        $r = Invoke-Script $script:RunPs1 @('-Path', $suite, '-Repeat', '2')
        $r.Output | Should -BeLike '*setup broke*'
        $r.Output | Should -BeLike '*2 of 2 runs failed*'
        $r.ExitCode | Should -Be 1
    }

    It 'fails when the name matches no test, instead of counting empty runs as passes' {
        $r = Invoke-Script $script:RunPs1 @('-Path', $suite, '-Name', '*no such test', '-Repeat', '2')
        $r.Output | Should -BeLike '*no test matches*'
        $r.ExitCode | Should -Be 1
    }
}
