# Tests for tools/run-game-tests.ps1's hold check (docs/testing.md, Keep each hold short): a
# selection whose worst case holds the game lock over the PR tier's 5 minutes is refused, unless
# -LongHold.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:Runner = Join-Path $script:RepoRoot 'tools/run-game-tests.ps1'
    . $script:Runner

    # Test cues shaped like the harness's: Fight a combat test with a 120 s timeout, Travel a SETA
    # test whose 60 s timeout sits under a 6 s setup cue, Instant one that reports from its own
    # actions, Unbounded one that waits with no timeout
    $script:Harness = @'
<?xml version="1.0" encoding="utf-8"?>
<mdscript name="Fixture">
  <cues>
    <cue name="Fight">
      <conditions><event_cue_signalled/></conditions>
      <actions>
        <run_actions ref="MarkCombatTest"/>
        <set_value name="$X" exact="1"/>
      </actions>
      <cues>
        <cue name="Fight_Timeout">
          <delay exact="120s"/>
          <actions><signal_cue_instantly cue="Report"/></actions>
        </cue>
      </cues>
    </cue>
    <cue name="Travel">
      <conditions><event_cue_signalled/></conditions>
      <actions><set_value name="$X" exact="1"/></actions>
      <cues>
        <cue name="Travel_Setup">
          <delay exact="6s"/>
          <actions><set_value name="$X" exact="2"/></actions>
          <cues>
            <cue name="Travel_Timeout">
              <delay exact="60s"/>
              <actions><signal_cue_instantly cue="Report"/></actions>
            </cue>
          </cues>
        </cue>
      </cues>
    </cue>
    <cue name="Instant">
      <conditions><event_cue_signalled/></conditions>
      <actions><signal_cue_instantly cue="Report"/></actions>
    </cue>
    <cue name="ConfigAppliedOnStart">
      <conditions><event_cue_signalled/></conditions>
      <actions><signal_cue_instantly cue="Report"/></actions>
    </cue>
    <cue name="Unbounded">
      <conditions><event_cue_signalled/></conditions>
      <actions><set_value name="$X" exact="1"/></actions>
      <cues>
        <cue name="Unbounded_Watch" checkinterval="1s">
          <actions><signal_cue_instantly cue="Report"/></actions>
        </cue>
      </cues>
    </cue>
  </cues>
</mdscript>
'@
    $script:Times = { param([string] $Name, [int] $Count) @(for ($i = 0; $i -lt $Count; $i++) { $Name }) }
}

Describe 'Get-HoldRefusal' {
    It 'refuses a combat test repeated past the budget, at 1x, with the worst case' {
        # 55 s start + 3 x 120 s = 415 s
        $refusal = Get-HoldRefusal $script:Harness (& $script:Times 'Fight' 3)
        $refusal | Should -BeLike '*up to 6 min 55 s*'
        $refusal | Should -BeLike '*-LongHold*'
    }

    It 'lets a combat test through while the worst case fits the budget' {
        # 55 s start + 2 x 120 s = 295 s
        Get-HoldRefusal $script:Harness (& $script:Times 'Fight' 2) | Should -BeNullOrEmpty
    }

    It 'counts a test under SETA at a sixth of its delays, the setup cue its timeout sits under included' {
        # (6 s + 60 s) / 6 = 11 s a run: 55 s + 20 x 11 s = 275 s, and 23 runs 308 s
        Get-HoldRefusal $script:Harness (& $script:Times 'Travel' 20) | Should -BeNullOrEmpty
        Get-HoldRefusal $script:Harness (& $script:Times 'Travel' 23) | Should -BeLike '*up to 5 min 8 s*'
    }

    It 'counts a test that reports from its own actions as no time' {
        Get-HoldRefusal $script:Harness (& $script:Times 'Instant' 100) | Should -BeNullOrEmpty
    }

    It 'counts a test with no timeout as the whole budget, since nothing bounds it' {
        # 55 s + 2 x 300 s
        Get-HoldRefusal $script:Harness (& $script:Times 'Unbounded' 2) | Should -BeLike '*up to 10 min 55 s*'
    }

    It 'lets one test run through, however long, since it cannot be split' {
        # ConfigAppliedOnStart runs once, first, in any selection
        Get-HoldRefusal $script:Harness @('ConfigAppliedOnStart', 'Unbounded') | Should -BeNullOrEmpty
    }

    It 'says how the worst case adds up and to split the batch' {
        $refusal = Get-HoldRefusal $script:Harness (@('ConfigAppliedOnStart') + (& $script:Times 'Fight' 2) + (& $script:Times 'Travel' 2) + @('Instant'))
        # 55 s + 2 x 120 s + 2 x 11 s = 317 s
        $refusal | Should -BeLike '*up to 5 min 17 s, over the 5-minute hold budget*'
        $refusal | Should -BeLike '*55 s game start, Fight 2 x 2 min 0 s, Travel 2 x 11 s*'
        $refusal | Should -Not -BeLike '*Instant*'
        $refusal | Should -BeLike '*Split the batch into smaller runs*'
        $refusal | Should -BeLike '*or pass -LongHold*'
    }
}

# Against the real harness: CaptureWingHoldsFire is a combat test whose 180 s timeout sits under a
# 2 s cue, so two runs could hold the game for 55 s + 364 s. pwsh wraps an error's lines.
Describe 'run-game-tests.ps1 and the hold budget' {
    BeforeAll { . (Join-Path $PSScriptRoot 'RunGameTestsSandbox.ps1') }
    BeforeEach { New-RunSandbox }
    AfterEach { Remove-RunSandbox }

    It 'refuses a selection over the budget before it takes the game lock or starts the game' {
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire', '-Repeat', '2'))
        $r.Output | Should -Match 'up\s+to\s+6\s+min\s+59\s+s'
        $r.ExitCode | Should -Not -Be 0
        Test-Path $env:FAKE_ARGS | Should -BeFalse
        Test-Path "$x4/game.lock" | Should -BeFalse
    }

    It 'runs a selection over the budget with -LongHold' {
        $r = Invoke-Script $script:Runner ($runArgs + @('-Test', 'capture_wing_holds_fire', '-Repeat', '2', '-LongHold', '-PreflightOnly'))
        $r.Output | Should -BeLike '*Game test setup OK*'
        $r.ExitCode | Should -Be 0
    }

    It 'checks only the hold with -HoldCheckOnly, so make game-test can refuse before it queues' {
        $over = Invoke-Script $script:Runner @('-HoldCheckOnly', '-Test', 'capture_wing_holds_fire', '-Repeat', '2')
        $over.Output | Should -Match 'up\s+to\s+6\s+min\s+59\s+s'
        $over.ExitCode | Should -Not -Be 0
        $within = Invoke-Script $script:Runner @('-HoldCheckOnly', '-Test', 'capture_wing_holds_fire')
        $within.ExitCode | Should -Be 0
        $tier = Invoke-Script $script:Runner @('-HoldCheckOnly', '-ReleaseTier')
        $tier.ExitCode | Should -Be 0
    }
}
