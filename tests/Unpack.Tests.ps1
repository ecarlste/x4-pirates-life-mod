# Tests for tools/unpack-x4.ps1, using a fake XRCatTool that logs each call instead of unpacking.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:Unpack = Join-Path $script:RepoRoot 'tools/unpack-x4.ps1'

    # A fake XRCatTool: appends its arguments (one call per line) to $env:FAKE_LOG and exits $env:FAKE_EXIT
    function New-FakeTool([string] $Dir, [string] $Name = 'fakecat') {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        if ($script:OnWindows) {
            $tool = Join-Path $Dir "$Name.cmd"
            Set-Content $tool "@echo off`r`necho %*>>`"%FAKE_LOG%`"`r`nexit /b %FAKE_EXIT%`r`n" -Encoding Ascii
        }
        else {
            $tool = Join-Path $Dir $Name
            Write-LfFile $tool "#!/bin/sh`necho `"`$*`" >> `"`$FAKE_LOG`"`nexit `"`${FAKE_EXIT:-0}`"`n"
            & chmod +x $tool
        }
        $tool
    }

    function Get-ToolCalls { if (Test-Path $env:FAKE_LOG) { @(Get-Content $env:FAKE_LOG) } else { @() } }

    function Invoke-Unpack([string[]] $Arguments) { Invoke-Script $script:Unpack $Arguments }
}

Describe 'unpack-x4.ps1' {
    BeforeEach {
        $root = New-TestDir
        $x4 = Join-Path $root 'steamapps/common/X4 Foundations'
        $outRoot = Join-Path $root 'reference'
        $out = Join-Path $outRoot 'x4-9.00'
        New-Item -ItemType Directory -Force -Path $x4 | Out-Null
        Write-LfFile "$x4/X4.exe" 'game'
        foreach ($c in '01.cat', '02.cat', '10.cat', 'ext_01.cat', 'notes.cat') { Write-LfFile "$x4/$c" '' }

        $env:FAKE_LOG = Join-Path $root 'calls.log'
        $env:FAKE_EXIT = '0'
        $tool = New-FakeTool (Join-Path $root 'faketool')
        $base = @('-Version', '9.00', '-X4Path', $x4, '-OutRoot', $outRoot)
    }
    AfterEach {
        Remove-Item env:FAKE_LOG, env:FAKE_EXIT -ErrorAction SilentlyContinue
        Remove-Item $root -Recurse -Force
    }

    It 'fails when X4.exe is not in the install folder' {
        Remove-Item "$x4/X4.exe"
        $r = Invoke-Unpack ($base + @('-ToolPath', $tool))
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'X4\.exe not found'
    }

    It 'fails when XRCatTool cannot be found' {
        $r = Invoke-Unpack $base
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'XRCatTool\.exe not found'
    }

    It 'fails when -ToolPath does not exist' {
        $r = Invoke-Unpack ($base + @('-ToolPath', (Join-Path $root 'missing.exe')))
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'XRCatTool\.exe not found'
    }

    It 'finds XRCatTool.exe elsewhere in the Steam library' {
        $found = Join-Path $root 'steamapps/common/X Tools/XRCatTool.exe'
        Write-LfFile $found ''
        # The fake .exe can't run, so only check which tool was picked
        (Invoke-Unpack $base).Output | Should -Match ([regex]::Escape("XRCatTool: $found"))
    }

    It 'unpacks base catalogs in numeric order into base/' {
        $r = Invoke-Unpack ($base + @('-ToolPath', $tool))
        $r.ExitCode | Should -Be 0 -Because $r.Output

        $calls = @(Get-ToolCalls)
        $calls.Count | Should -Be 1
        $call = $calls[0]
        $call | Should -Match ([regex]::Escape((Join-Path $out 'base')))
        $call.IndexOf('01.cat') | Should -BeLessThan $call.IndexOf('02.cat')
        $call.IndexOf('02.cat') | Should -BeLessThan $call.IndexOf('10.cat')
        $call | Should -Not -Match 'ext_01\.cat|notes\.cat'
    }

    It 'unpacks each DLC, its substitutions and its content.xml' {
        $dlc = Join-Path $x4 'extensions/ego_dlc_pirate'
        foreach ($c in 'ext_01.cat', 'ext_02.cat', 'subst_01.cat') { Write-LfFile "$dlc/$c" '' }
        Write-LfFile "$dlc/content.xml" '<content id="ego_dlc_pirate"/>'
        Write-LfFile "$x4/extensions/someones_mod/ext_01.cat" ''

        $r = Invoke-Unpack ($base + @('-ToolPath', $tool))
        $r.ExitCode | Should -Be 0 -Because $r.Output

        $calls = @(Get-ToolCalls)
        $calls.Count | Should -Be 3
        $ext = $calls | Where-Object { $_ -match 'ext_02\.cat' }
        $ext | Should -Match 'ext_01\.cat'
        $ext | Should -Match ([regex]::Escape((Join-Path $out 'ego_dlc_pirate')))
        $calls | Where-Object { $_ -match 'subst_01\.cat' } |
            Should -Match ([regex]::Escape((Join-Path (Join-Path $out 'ego_dlc_pirate') '_subst')))
        $calls -join "`n" | Should -Not -Match 'someones_mod'
        Get-TestFile "$out/ego_dlc_pirate/content.xml" | Should -Be '<content id="ego_dlc_pirate"/>'
    }

    It 'refuses to unpack over an existing folder without -Force' {
        New-Item -ItemType Directory -Force -Path $out | Out-Null
        $r = Invoke-Unpack ($base + @('-ToolPath', $tool))
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'already exists'
        Get-ToolCalls | Should -BeNullOrEmpty

        $r = Invoke-Unpack ($base + @('-ToolPath', $tool, '-Force'))
        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'fails when XRCatTool fails' {
        $env:FAKE_EXIT = '3'
        $r = Invoke-Unpack ($base + @('-ToolPath', $tool))
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'exited with code 3'
    }
}
