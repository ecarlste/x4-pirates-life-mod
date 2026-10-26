# Tests for deploy.ps1: which source gets deployed (origin/main, the working tree, -Ref). Run with tests/run.ps1 (or tests/run.sh, which calls it).
# The deploy tests are split over Deploy*.Tests.ps1 so tests/run.sh can run them in parallel.
# Mirrors tests/deploy.bats so both scripts are held to the same behavior.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'deploy.ps1' {
    BeforeEach { $s = New-DeploySandbox }
    AfterEach { Remove-DeploySandbox $s }

    Context 'sources' {
        It 'ships uncommitted changes with -WorkingTree' {
            Write-LfFile "$($s.Repo)/libraries/god.xml" '<diff>uncommitted</diff>'

            (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
            Get-TestFile "$($s.Target)/libraries/god.xml" | Should -Be '<diff>uncommitted</diff>'
        }

        It 'deploys the branch given with -Ref' {
            Invoke-TestGit -C $s.Repo switch -q -c feature/x
            Write-LfFile "$($s.Repo)/libraries/god.xml" '<diff>branch</diff>'
            Save-TestCommit $s 'branch change'
            Invoke-TestGit -C $s.Repo switch -q main

            (Invoke-Deploy $s @('-Ref', 'feature/x')).ExitCode | Should -Be 0
            Get-TestFile "$($s.Target)/libraries/god.xml" | Should -Be '<diff>branch</diff>'
        }

        It 'does not fetch with -Ref' {
            Invoke-TestGit -C $s.Repo remote set-url origin (Join-Path $s.Root 'missing.git')

            $r = Invoke-Deploy $s @('-Ref', 'main')
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Not -Match "Couldn't fetch"
        }

        It 'fails on an unknown ref without touching the target' {
            $r = Invoke-Deploy $s @('-Ref', 'does-not-exist')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'unknown git ref: does-not-exist'
            $s.Target | Should -Not -Exist
        }

        It 'fails on a ref without deploy.include' {
            Invoke-TestGit -C $s.Repo rm -q deploy.include
            Save-TestCommit $s 'drop include'

            $r = Invoke-Deploy $s @('-Ref', 'HEAD')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'has no deploy\.include'
        }

        It 'fails on a ref without content.xml' {
            Invoke-TestGit -C $s.Repo rm -q content.xml
            Save-TestCommit $s 'drop content'

            $r = Invoke-Deploy $s @('-Ref', 'HEAD')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'content\.xml missing'
        }

        It 'falls back to the last fetched origin/main when origin is unreachable' {
            Invoke-TestGit -C $s.Repo remote set-url origin (Join-Path $s.Root 'missing.git')

            $r = Invoke-Deploy $s
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match "Couldn't fetch origin"
            "$($s.Target)/content.xml" | Should -Exist
        }

        It 'rejects -Ref combined with -WorkingTree' {
            $r = Invoke-Deploy $s @('-Ref', 'main', '-WorkingTree')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match "can't be combined"
        }
    }
}
