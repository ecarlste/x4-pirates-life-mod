# Tests for deploy.ps1. Run with tests/run.ps1 (or tests/run.sh, which calls it).
# Mirrors tests/deploy.bats so both scripts are held to the same behavior.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'deploy.ps1' {
    BeforeEach { $s = New-DeploySandbox }
    AfterEach { Remove-DeploySandbox $s }

    Context 'what gets deployed' {
        It 'fetches and ships the latest origin/main by default' {
            Push-FromOtherClone $s 'libraries/god.xml' '<diff>from remote</diff>'

            $r = Invoke-Deploy $s
            $r.ExitCode | Should -Be 0
            Get-TestFile "$($s.Target)/libraries/god.xml" | Should -Be '<diff>from remote</diff>'
            $r.Output | Should -Match 'Deploying origin/main @'
        }

        It 'ignores the checked-out branch and local changes by default' {
            Invoke-TestGit -C $s.Repo switch -q -c feature/wip
            Write-LfFile "$($s.Repo)/libraries/god.xml" '<diff>wip</diff>'
            Save-TestCommit $s 'wip'
            Write-LfFile "$($s.Repo)/libraries/god.xml" 'uncommitted'

            (Invoke-Deploy $s).ExitCode | Should -Be 0
            Get-TestFile "$($s.Target)/libraries/god.xml" | Should -Be '<diff/>'
        }

        It 'ships only the paths in deploy.include' {
            (Invoke-Deploy $s).ExitCode | Should -Be 0
            "$($s.Target)/content.xml" | Should -Exist
            "$($s.Target)/md/sub/nested.xml" | Should -Exist
            "$($s.Target)/docs" | Should -Not -Exist
            "$($s.Target)/deploy.ps1" | Should -Not -Exist
        }

        It 'tolerates comments, blank lines and missing entries in deploy.include' {
            Write-LfFile "$($s.Repo)/deploy.include" "# comment`n`ncontent.xml   # trailing`nlibraries`nnot-there`n"
            Save-TestCommit $s 'custom include'
            Invoke-TestGit -C $s.Repo push -q

            (Invoke-Deploy $s).ExitCode | Should -Be 0
            "$($s.Target)/libraries/god.xml" | Should -Exist
            "$($s.Target)/md" | Should -Not -Exist
        }

        It 'ships files byte-for-byte as committed, even with core.autocrlf on' {
            Invoke-TestGit -C $s.Repo config core.autocrlf true

            (Invoke-Deploy $s @('-Ref', 'main')).ExitCode | Should -Be 0
            [IO.File]::ReadAllText("$($s.Target)/libraries/god.xml") | Should -Be "<diff/>"
        }
    }

    Context 'mirroring' {
        It 'removes files and folders that left the mod' {
            Write-LfFile "$($s.Target)/old/deeper/stale.xml" 'stale'
            Write-LfFile "$($s.Target)/stale.xml" 'stale'

            (Invoke-Deploy $s).ExitCode | Should -Be 0
            "$($s.Target)/old" | Should -Not -Exist
            "$($s.Target)/stale.xml" | Should -Not -Exist
            "$($s.Target)/content.xml" | Should -Exist
        }

        It 'updates changed files and treats a repeat deploy as a no-op' {
            Invoke-Deploy $s | Out-Null
            Write-LfFile "$($s.Target)/libraries/god.xml" 'tampered'

            $r = Invoke-Deploy $s
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'god\.xml'
            Get-TestFile "$($s.Target)/libraries/god.xml" | Should -Be '<diff/>'

            (Invoke-Deploy $s).Output | Should -Match 'already up to date'
        }

        It 'touches nothing outside the mod folder' {
            Write-LfFile "$($s.X4)/X4.exe" 'game'
            Write-LfFile "$($s.X4)/extensions/othermod/content.xml" 'other'

            (Invoke-Deploy $s).ExitCode | Should -Be 0
            Get-TestFile "$($s.X4)/X4.exe" | Should -Be 'game'
            Get-TestFile "$($s.X4)/extensions/othermod/content.xml" | Should -Be 'other'
        }

        It 'lists changes but writes nothing on a dry run' {
            $r = Invoke-Deploy $s @('-DryRun')
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'Dry run'
            $r.Output | Should -Match 'content\.xml'
            $s.Target | Should -Not -Exist

            Write-LfFile "$($s.Target)/stale.xml" 'stale'
            (Invoke-Deploy $s @('-DryRun')).Output | Should -Match 'stale\.xml'
            "$($s.Target)/stale.xml" | Should -Exist
        }
    }

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

    Context 'extension id safety' {
        It 'rejects unsafe id <Id> before anything is deleted' -TestCases @(
            @{ Id = '..' }, @{ Id = '.' }, @{ Id = '../escape' }, @{ Id = 'a/b' }, @{ Id = 'a\b' }, @{ Id = '.hidden' }, @{ Id = '' }
        ) {
            Write-LfFile "$($s.X4)/X4.exe" 'game'
            Set-TestModId $s $Id

            $r = Invoke-Deploy $s @('-WorkingTree')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'valid extension id'
            Get-TestFile "$($s.X4)/X4.exe" | Should -Be 'game'
        }

        It 'names the target folder after the id in content.xml' {
            Set-TestModId $s 'other_mod-1.2'
            (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
            "$($s.X4)/extensions/other_mod-1.2/content.xml" | Should -Exist
        }
    }

    Context 'setting overrides (-Set)' {
        BeforeEach { Write-TestConfig $s }

        It 'overrides a setting in the deployed copy only' {
            $r = Invoke-Deploy $s @('-WorkingTree', '-Set', 'IntactOnEject=0')
            $r.ExitCode | Should -Be 0 -Because $r.Output
            $r.Output | Should -Match 'with settings: IntactOnEject=0'
            Get-DeployedSetting $s 'IntactOnEject' | Should -Be '0'
            Get-DeployedSetting $s 'IntactOnClaim' | Should -Be '1'
            [IO.File]::ReadAllText("$($s.Repo)/md/apirateslife_config.xml") | Should -Match 'APiratesLife_IntactOnEject" exact="1"'
        }

        It 'accepts comma lists' {
            (Invoke-Deploy $s @('-WorkingTree', '-Set', 'IntactOnEject=0,IntactOnClaim=0')).ExitCode | Should -Be 0
            Get-DeployedSetting $s 'IntactOnEject' | Should -Be '0'
            Get-DeployedSetting $s 'IntactOnClaim' | Should -Be '0'
        }

        It 'works when deploying a git ref' {
            Save-TestCommit $s 'add config'
            (Invoke-Deploy $s @('-Ref', 'HEAD', '-Set', 'IntactOnClaim=0')).ExitCode | Should -Be 0
            Get-DeployedSetting $s 'IntactOnClaim' | Should -Be '0'
        }

        It 'restores the committed values on a later deploy without -Set' {
            Invoke-Deploy $s @('-WorkingTree', '-Set', 'IntactOnEject=0') | Out-Null
            (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
            Get-DeployedSetting $s 'IntactOnEject' | Should -Be '1'
        }

        It 'rejects unknown settings before deploying anything' {
            $r = Invoke-Deploy $s @('-WorkingTree', '-Set', 'Bogus=0')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match "unknown setting 'Bogus' \(valid: IntactOnEject IntactOnClaim\)"
            $s.Target | Should -Not -Exist
        }

        It 'rejects values that could break the XML' {
            $r = Invoke-Deploy $s @('-WorkingTree', '-Set', 'IntactOnEject=1/><x')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'invalid value for IntactOnEject'
            $s.Target | Should -Not -Exist
        }

        It 'needs NAME=VALUE and a config file' {
            $r = Invoke-Deploy $s @('-WorkingTree', '-Set', 'IntactOnEject')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'needs NAME=VALUE'

            Remove-Item "$($s.Repo)/md/apirateslife_config.xml"
            $r = Invoke-Deploy $s @('-WorkingTree', '-Set', 'IntactOnEject=0')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'needs md/apirateslife_config.xml'
        }

        It 'reports the override on a dry run and writes nothing' {
            $r = Invoke-Deploy $s @('-WorkingTree', '-DryRun', '-Set', 'IntactOnEject=0')
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'with settings: IntactOnEject=0'
            $s.Target | Should -Not -Exist
        }
    }

    Context 'configuration' {
        BeforeEach { Remove-Item env:X4_PATH }

        It 'fails when deploy.config is missing' {
            $r = Invoke-Deploy $s
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'deploy\.config not found'
        }

        It 'reads a config path with spaces and parentheses: <Line>' -TestCases @(
            @{ Line = 'X4_PATH="{0}"' }, @{ Line = "X4_PATH='{0}'" }, @{ Line = 'X4_PATH={0}' }, @{ Line = '  X4_PATH = "{0}"  ' }
        ) {
            $x4 = Join-Path $s.Root 'Program Files (x86)/X4 Foundations'
            New-Item -ItemType Directory -Force -Path $x4 | Out-Null
            Write-LfFile "$($s.Repo)/deploy.config" ($Line -f $x4)

            $r = Invoke-Deploy $s @('-WorkingTree')
            $r.ExitCode | Should -Be 0 -Because $r.Output
            "$x4/extensions/testmod/content.xml" | Should -Exist
        }

        It 'ignores comments and uses the last X4_PATH' {
            Write-LfFile "$($s.Repo)/deploy.config" "# X4_PATH=/nope`nX4_PATH=/also/nope`nX4_PATH=`"$($s.X4)`"`n"

            (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
            "$($s.Target)/content.xml" | Should -Exist
        }

        It 'fails on an empty X4_PATH' {
            Write-LfFile "$($s.Repo)/deploy.config" 'X4_PATH='
            $r = Invoke-Deploy $s @('-WorkingTree')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'X4_PATH not set'
        }

        It 'lets the X4_PATH environment variable override deploy.config' {
            Write-LfFile "$($s.Repo)/deploy.config" 'X4_PATH=/does/not/exist'
            $env:X4_PATH = $s.X4

            (Invoke-Deploy $s @('-WorkingTree')).ExitCode | Should -Be 0
            "$($s.Target)/content.xml" | Should -Exist
        }

        It 'fails when the X4 folder does not exist' {
            $env:X4_PATH = Join-Path $s.Root 'nope'
            $r = Invoke-Deploy $s @('-WorkingTree')
            $r.ExitCode | Should -Not -Be 0
            $r.Output | Should -Match 'X4 install folder not found'
        }
    }
}
