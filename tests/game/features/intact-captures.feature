# Specs: docs/specs/claim-no-damage.md, docs/specs/capture-settings.md
Feature: Captured ships arrive intact
  Captured ships arrive as the player left them: the bailing pilot doesn't drop the hull or
  sabotage equipment, and the claiming marine doesn't damage the ship. Each part can be switched
  back to vanilla in the config file.

  @pilot_bail_intact
  Scenario: The bailing pilot leaves the ship intact
    Given "intact when the pilot ejects" is on
    And a crewless Argon fighter at full hull, with a pilot skilled enough to sabotage it
    When the pilot bails
    Then the fighter keeps its full hull
    And it keeps all its weapons, turrets and shields

  @pilot_bail_vanilla_when_off
  Scenario: With the setting off, the bailing pilot damages the ship as in vanilla
    Given "intact when the pilot ejects" is off
    And a crewless Argon fighter at full hull
    When the pilot bails
    Then the hull drops to about (100 - pilot skill)%
    And the pilot destroys as many parts as vanilla's sabotage rule allows

  @claim_intact
  Scenario: The claiming marine leaves the ship intact
    Given "intact when marines claim" is on
    And an ownerless fighter at full hull
    And one of my frigates with marines, set to claim abandoned ships
    When the marine claims the fighter
    Then the fighter becomes mine
    And it keeps its full hull and all its equipment

  @claim_vanilla_when_off
  Scenario: With the setting off, the claiming marine damages the ship as in vanilla
    Given "intact when marines claim" is off
    And an ownerless fighter at full hull
    And one of my frigates with marines, set to claim abandoned ships
    When the marine claims the fighter
    Then the fighter becomes mine
    And its hull drops to between 70% and 99%
