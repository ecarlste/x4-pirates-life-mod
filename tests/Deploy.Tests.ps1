# Tests for deploy.ps1: what ships, mirroring and the extension id. Run with tests/run.ps1 (or tests/run.sh, which calls it).
# The deploy tests are split over Deploy*.Tests.ps1 so tests/run.sh can run them in parallel.
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
}
