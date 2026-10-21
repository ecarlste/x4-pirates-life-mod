# Spec: docs/specs/in-game-settings.md
Feature: In-game settings
  With kuertee's UI Extensions installed, I change the mod's settings in game. A choice stays with
  my save, whatever the config file says. I can keep my favourite values as my defaults, which
  start every new game. The config file fills in anything else. Without UI Extensions the mod
  runs on the config file alone.

  @pending
  Scenario: A setting changed in game survives a load
    Given "intact when the pilot ejects" is on in the config file
    When I switch it off in game
    Then it is off at once
    And it is still off after the game is loaded again

  @pending
  Scenario: Settings not changed in game follow the config file
    Given I switched "intact when the pilot ejects" off in game
    When the game is loaded with a different capture hold line in the config file
    Then the hold line is the config file's value

  @pending
  Scenario: A new game starts from my defaults
    Given my defaults have "intact when marines claim" off
    And the config file has it on
    When I start a new game
    Then it is off in that game

  @pending
  Scenario: Changing my defaults leaves a seeded save alone until it loads them
    Given a save that started from my defaults, with a capture floor of 35%
    When my defaults change to a floor of 20%
    Then that save's floor is still 35% after it is loaded again
    And after I load my defaults in it, its floor is 20%

  @pending
  Scenario: Reset brings back the config file's values
    Given I changed settings in game
    When I reset them on the settings page
    Then every setting has the config file's value again
    And it keeps it after the game is loaded again

  @pending
  Scenario: Values that would break captures are clamped
    When the page sends a capture hold line of 90%
    Then the hold line is 75%
    When the page sends a floor of 75%
    Then the floor is 70%, 5 points under the hold line
    When the page then sends a hold line of 40%
    Then the floor drops to 35%

  @pending
  Scenario: Unknown settings are ignored
    When the page sends a setting the mod doesn't have
    Then no setting changes
    And the log says the setting is unknown

  @pending
  Scenario: Without UI Extensions the mod runs on the config file
    Given kuertee's UI Extensions is not installed
    When the game starts
    Then our settings script reports in and logs "config file only"
    And every setting has the config file's value
