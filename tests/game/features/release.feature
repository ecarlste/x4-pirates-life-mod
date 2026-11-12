Feature: Release
  The SWI build installs and loads cleanly next to Star Wars Interworlds on X4 8.00. These are its
  release gates (spec: the SWI build, issue 109, Testing Decisions). The game test runner checks
  them on the log of every game test run, which starts a fresh game on the SWI test gamestart.

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
