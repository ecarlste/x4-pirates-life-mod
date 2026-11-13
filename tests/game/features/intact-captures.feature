# Specs: docs/specs/claim-no-damage.md, docs/specs/capture-settings.md
Feature: Captured ships arrive intact
  Captured ships arrive as the player left them: the claiming marine doesn't damage the ship, which
  can be switched back to vanilla in the config file. SWI's bailing pilot already leaves the hull
  and equipment alone.

  @claim_intact
  Scenario: The claiming marine leaves the ship intact
    Given "intact when marines claim" is on
    And an ownerless fighter at full hull
    And one of my M ships with marines, set to claim abandoned ships
    When the marine claims the fighter
    Then the fighter becomes mine
    And it keeps its full hull and all its equipment

  @claim_vanilla_when_off
  Scenario: With the setting off, the claiming marine damages the ship as in vanilla
    Given "intact when marines claim" is off
    And an ownerless fighter at full hull
    And one of my M ships with marines, set to claim abandoned ships
    When the marine claims the fighter
    Then the fighter becomes mine
    And its hull drops to between 70% and 99%

  @manual
  Scenario: SWI destroys unclaimed bailed ships, and keeps claimed prizes
    Given two ships whose pilots bailed in my capture operations
    When I claim one and leave the other ownerless
    Then SWI destroys the ownerless one 30-70 minutes after its bail
    And the one I claimed is still mine after 70 minutes
