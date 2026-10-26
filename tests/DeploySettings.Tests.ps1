# Tests for deploy.ps1: -Set overrides and deploy.config. Run with tests/run.ps1 (or tests/run.sh, which calls it).
# The deploy tests are split over Deploy*.Tests.ps1 so tests/run.sh can run them in parallel.
# Mirrors tests/deploy.bats so both scripts are held to the same behavior.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'deploy.ps1' {
    BeforeEach { $s = New-DeploySandbox }
    AfterEach { Remove-DeploySandbox $s }

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
