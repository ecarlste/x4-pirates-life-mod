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
