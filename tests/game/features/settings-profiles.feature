# Spec: docs/specs/settings-profiles.md
Feature: Settings profiles
  On the settings page I pick a profile for my game: Default (the config file) or one I saved.
  My game follows that profile until I change a setting in it. Profiles are kept in my X4
  profile, so every save sees the same list. Flows: docs/specs/settings-profiles-flows.md.

  @settings_seed_from_defaults
  Scenario: A new game is on the profile for new games
    Given my profile for new games is "Hard mode", with "intact when marines claim" off
    And the config file has it on
    When I start a new game
    Then the game is on "Hard mode"
    And "intact when marines claim" is off

  @settings_change_marks_modified
  Scenario: Changing a setting stops the game following its profile
    Given a game on "Hard mode"
    When I turn a setting on in it
    Then the game uses the new value at once
    And it is marked as changed
    And the "Hard mode" profile is unchanged
    When I save the changes into "Hard mode"
    Then the game is no longer marked as changed

  @settings_linked_follows_profile
  Scenario: A game on a profile picks up changes saved into it from another game
    Given game B is on "Hard mode" with no changes, and was saved
    And in game C I saved changes into "Hard mode"
    When I load game B
    Then it uses Hard mode's new values

  @settings_saved_modified_loads_as_none
  Scenario: A game saved with changes is on its own settings when loaded again
    Given a game on "Hard mode" with a changed setting, saved
    When I load it
    Then it is on "None (custom settings)"
    And it uses the values it had when it was saved, whatever "Hard mode" holds now

  @settings_linked_profile_gone
  Scenario: A game whose profile is gone keeps its values
    Given a game on "Hard mode", saved
    And "Hard mode" no longer exists (deleted, or the save is on another PC)
    When I load the game
    Then it is on "None (custom settings)"
    And it uses the values it had when it was saved

  @settings_choose_profile_clears_changes
  Scenario: Choosing a profile loads it and clears changes
    Given a game on "Hard mode" with a changed setting
    When I choose "Easy mode" and confirm
    Then the game is on "Easy mode" with no changes
    And it uses the config file's values with Easy mode's on top

  @settings_choose_default
  Scenario: Choosing Default brings back the config file's values
    Given a game on "Hard mode" with a changed setting
    When I choose "Default" and confirm
    Then the game is on "Default" with no changes
    And it uses the config file's values

  @settings_profile_invalid_values
  Scenario: An unknown or invalid setting in a profile keeps its config value
    Given "Hard mode" has "intact when marines claim" set to "never" and a setting the mod doesn't have
    When a game loads "Hard mode"
    Then "intact when marines claim" has its config value
    And the unknown setting is ignored
    And the "Hard mode" profile is not changed

  @test_toggling_marks_a_profile_modified_but_not_none
  @test_profile_dropdown_marks_unsaved_changes_and_offers_none_only_when_on_it
  @test_save_changes_only_into_a_saved_profile_with_changes
  Scenario: A changed game shows the profile with a star, and can save into it
    Given a game on "Hard mode"
    When I change a setting
    Then the Profile dropdown shows "Hard mode *"
    And "Save changes to 'Hard mode'" is enabled
    When I press it
    Then "Hard mode" has the game's values
    And the dropdown shows "Hard mode" and the button is disabled again

  @test_save_changes_only_into_a_saved_profile_with_changes
  Scenario: Save changes isn't offered for Default or None
    Given a game on "Default" or on "None (custom settings)" with a changed setting
    Then there is no enabled "Save changes to …" button

  @manual
  Scenario: The star stays for the whole session
    Given a game on "Hard mode *"
    When I save the game, keep playing and open the settings page again
    Then it still shows "Hard mode *" with "Save changes to 'Hard mode'" enabled

  @test_save_as_new_leaves_the_old_profile_alone
  Scenario: Save as new profile leaves the old profile alone
    Given a game on "Hard mode *"
    When I save as a new profile named "Hard mode lite"
    Then "Hard mode lite" has the game's values and the game is on it, with no star
    And "Hard mode" is unchanged

  @test_saving_under_an_existing_name_asks_first
  Scenario: Saving under an existing name asks first
    Given profiles "Hard mode" and "Easy mode"
    When I save as a new profile named "Easy mode"
    Then I am asked whether to replace "Easy mode"
    And if I cancel, "Easy mode" keeps its settings

  @test_a_refused_name_saves_nothing_and_says_why
  @test_refuses_an_empty_name
  @test_allows_40_characters_counting_utf8_characters_not_bytes
  @test_refuses_default_in_any_case
  Scenario: Some profile names are refused
    When I save as a new profile with an empty name, a name over 40 characters, or "Default"
    Then no profile is saved
    And the page says why

  @test_switching_away_from_a_changed_game_asks_first
  @test_switching_from_an_unchanged_profile_doesnt_ask
  Scenario: Switching away from a changed game asks first
    Given a game on "Hard mode *"
    When I choose "Easy mode" in the Profile dropdown
    Then I am asked whether to discard this game's changes
    And if I answer No, nothing changes

  @test_deleting_a_profile_asks_to_confirm
  @test_delete_moves_the_game_to_none_and_clears_the_new_game_profile
  Scenario: Delete a profile
    Given "Hard mode" is the profile for new games and this game is on it
    When I delete "Hard mode" and confirm
    Then it is gone from the list
    And this game is on "None (custom settings)" with the same values
    And new games start on "Default"

  @test_choosing_the_profile_for_new_games
  Scenario: Change the profile for new games
    When I choose "Easy mode" in "Profile for new games"
    Then the next new game starts on "Easy mode"
    And games I already have keep their profiles

  @manual
  Scenario: Profiles are shared by every save and survive restarting X4
    Given I saved the profile "Hard mode" in one game
    When I restart X4 and load another game
    Then "Hard mode" is in its Profile dropdown

  @test_the_old_defaults_become_a_profile_for_new_games
  @test_migration_never_overwrites_an_existing_profile
  Scenario: The defaults from the first version become a profile
    Given defaults saved with the first version of the settings page
    When the settings page loads
    Then they are a profile named "My defaults", used for new games
