Feature: Release
  The SWI build installs and loads cleanly next to Star Wars Interworlds on X4 8.00. These are its
  release gates (spec: the SWI build, issue 109, Testing Decisions). The game test runner checks
  the first two on the log of every game test run, which starts a fresh game on the SWI test
  gamestart; the zip make release builds is checked by hand (docs/releasing.md).

  @load_order_after_swi
  Scenario: The mod loads after SWI
    Given SWI and A Pirate's Life are both switched on
    And A Pirate's Life lists SWI as an optional dependency
    When X4 reads a file that both of them patch
    Then it reads SWI's copy first, so SWI's changes are in place before our patches

  @clean_log
  Scenario: A fresh SWI start logs no errors or warnings from our files
    Given SWI, Tides of Avarice and A Pirate's Life are switched on
    When I start a new game on SWI and play
    Then debuglog.txt has no error or warning about our files or scripts

  @manual
  Scenario: make release builds a zip that installs and loads
    Given make release built dist/apirateslife-<version>.zip from the version's tag
    When I unzip it into the extensions folder of a clean X4 8.00 install with SWI and Tides of Avarice
    Then extensions/apirateslife/ holds content.xml, README.txt, CREDITS.txt, LICENSE and CHANGELOG.md
    And X4 lists A Pirate's Life with that version under Extensions, switched on
    And a fresh SWI start logs no errors or warnings from our files

  @swi_only_run
  Scenario: A run with only SWI and Tides of Avarice passes
    Given only Egosoft's DLCs (SWI needs all five, Tides of Avarice among them), SWI and A Pirate's Life are switched on, with no other mods
    When I start a new game on SWI and play
    Then no other extension's files are read

  @manual
  Scenario: An existing save loads with the mod added
    Given a save from a game started on SWI without A Pirate's Life
    When I switch A Pirate's Life on and load that save
    Then it loads, and debuglog.txt has no error or warning about our files or scripts
    And a capture operation started in it runs and ends as in a new game

  @manual
  Scenario: A save loads and plays with the mod removed
    Given a save with A Pirate's Life on, a capture operation running and ships I've taken
    When I switch A Pirate's Life off and load that save
    Then it loads and plays for 10 minutes, with no error or warning about our files or scripts apart from the mission's missing texts
    And the ships I took stay mine, as they are
    And the global.$APiratesLife_ tables and settings stay: operations, metrics, pirated ships, bails and boardings to the player, and the config values
    And a running operation's target keeps its relation boost, with vanilla's markedashostile reason, until it decays in 600 s
    And its pilot keeps $nextcapturechance, as the game's own checks leave it, and $APiratesLife_Fear if the operation was called off or it escaped
    And a wingman's pilot keeps $APiratesLife_NoMissiles
    And the operation's mission stays in the mission list, with its texts gone, and its cue keeps $CrewStart
    And nothing else of ours stays behind, and nothing reads any of it without the mod
