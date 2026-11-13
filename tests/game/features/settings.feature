# Spec: docs/specs/capture-settings.md
Feature: Settings from the config file
  Players change the mod's settings by editing md/apirateslife_config.xml. It applies on every
  game start and load, and a typo never breaks captures silently: a bad value is brought into its
  range or reset to its default, and a file the game can't read gives every default, each with a
  warning in debuglog.txt.

  @config_applied_on_start
  Scenario: The config file's values apply when a game starts
    Given the config file, with any values set at deploy time
    When a game starts
    Then every setting has the value the config file gives it, brought into its range

  @settings_clamped
  Scenario: A value outside its range is brought into it, with one warning
    Given the config file sets the pressure cap to 150
    When the settings load
    Then the pressure cap is 100
    And there is one warning, naming the pressure cap and 100

  @settings_clamped
  Scenario: The floor stays at or below the hold line
    Given the config file sets the hold line to 40 and the floor to 50
    When the settings load
    Then the floor is 40, with one warning

  @settings_clamped
  Scenario: A value that isn't a number, or is missing, gets its default, with one warning
    Given the config file sets the pressure cap to 'high'
    When the settings load
    Then the pressure cap is its default, 80
    And there is one warning, naming the pressure cap and 80

  @settings_clamped
  Scenario: Values in range, at their limits too, load without warnings
    Given the config file sets every value in its range
    When the settings load
    Then every setting has the value the config file gives it, with no warning

  @settings_defaults_when_config_skipped
  Scenario: A config file the game skips gives the defaults, with one warning
    Given the game skipped the config file, leaving every value unset
    When the settings load
    Then every setting has the loader's built-in default
    And there is one warning, "config file not loaded, using defaults", not one per setting

  @manual
  Scenario: The warnings reach debuglog.txt
    Given I deploy with --set CapturePressureCap=150
    When I load a game
    Then debuglog.txt says "settings warning: CapturePressureCap = 150 is out of range, using 100"
    And the "config applied" line shows cap 100

  @manual
  Scenario: A config file with a typo the game won't read
    Given I break the XML of the deployed md/apirateslife_config.xml
    When I load a game
    Then debuglog.txt says "settings warning: config file not loaded, using defaults" once
    And the "config applied" line shows every default
