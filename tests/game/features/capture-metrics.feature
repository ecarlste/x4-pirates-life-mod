# Spec: docs/specs/capture-metrics.md
Feature: Capture metrics
  Every capture attempt, with an operation or by just shooting, leaves one summary line in the
  log when it ends, so we can measure how long captures take.

  @capture_metrics_operation
  Scenario: A capture operation ends in one summary
    Given a capture operation on a capturable Argon fighter with no crew
    When the fighter's pilot bails
    Then one summary is logged for the fighter, as an operation that ended "abandoned"
    And it names the fighter's macro and size, its owner and its pilot's skill
    And it counts one check, one success and the pilot bailing

  @capture_metrics_plain_attack
  Scenario: A plain attack ends in one summary
    Given a capturable Argon fighter with no crew and no capture operation
    When the ship I fly gets a bail check on it and the fighter's pilot bails
    Then one summary is logged for the fighter, as a plain attack that ended "abandoned"
    And it lists the ship I fly as an attacker

  @capture_metrics_dropped
  Scenario: A plain attack I give up on ends as dropped
    Given the ship I fly hit a capturable fighter once
    When nobody hits it or gets a bail check for 120 seconds (shortened for the test)
    Then the summary for the fighter ends "dropped"

  @capture_metrics_fleet_ignored
  Scenario: Hits by the rest of my fleet start no record
    Given one of my ships that isn't in my wing
    When it attacks a capturable fighter
    Then no record starts for the fighter

  @capture_metrics_attack_becomes_operation
  Scenario: A plain attack that becomes an operation keeps one record
    Given I shot a capturable fighter
    When I start a capture operation on it
    Then its record keeps the time of my first shot
    And it ends in one summary, as an operation

  @manual
  Scenario: The CSV tool reads real logs
    Given a debuglog.txt from a session with captures
    When I run tools/capture_metrics.py on it
    Then I get one CSV row per summary line
