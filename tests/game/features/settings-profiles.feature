# Spec: docs/specs/settings-profiles.md
Feature: Named settings profiles
  On the settings page I save my settings as named profiles, kept in my X4 profile. Any save can
  load any of them from a list, and I choose which one new games start from.

  @settings_seed_from_defaults
  Scenario: A new game starts from the profile for new games
    Given my profile for new games has "intact when marines claim" off
    And the config file has it on
    When I start a new game
    Then it is off in that game

  @settings_seed_from_defaults
  Scenario: Changing profiles leaves a started save alone until it loads one
    Given a save that started from my profile for new games, with full wingman bail chance on
    When I change that profile to full wingman bail chance off
    Then it is still on in that save after it is loaded again
    And after I load that profile in it, it is off

  @pending
  Scenario: Save the current settings as a named profile
    Given I switched "intact when the pilot ejects" off in this save
    When I save the settings as a profile named "Hard mode"
    Then "Hard mode" is in the list of profiles, with "intact when the pilot ejects" off
    And it is still there after restarting X4

  @pending
  Scenario: Saving under an existing name replaces that profile
    Given a profile named "Hard mode"
    When I save different settings under the name "Hard mode"
    Then there is one "Hard mode", with the new settings

  @pending
  Scenario: A profile needs a name
    When I save the settings as a profile with an empty name
    Then no profile is saved
    And the page says the name is empty

  @pending
  Scenario: Any save can load any profile
    Given profiles "Hard mode" and "Easy mode" saved in another game
    When I load "Easy mode" in this save
    Then this save's settings are the ones in "Easy mode"

  @pending
  Scenario: Delete a profile
    Given "Hard mode" is the profile for new games
    When I delete "Hard mode" and confirm
    Then it is gone from the list
    And new games start from the config file again

  @pending
  Scenario: The defaults from the first version become a profile
    Given defaults saved with the first version of the settings page
    When the settings page loads
    Then they are a profile named "My defaults", used for new games
