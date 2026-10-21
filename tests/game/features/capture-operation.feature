# Spec: docs/specs/capture-operation.md
Feature: Capture operations
  I start a capture operation on a capturable ship, alone or with my wing. My wingmen break its
  hull below the bail gate, then only keep its shields down, so the pilot bails instead of dying.

  @capture_start_and_destroyed
  Scenario: An operation starts on a capturable fighter
    Given a capturable Argon fighter with a pilot
    When I start a capture operation on it
    Then the operation starts

  @capture_start_and_destroyed
  Scenario: An operation can't start on my own ship or twice on the same target
    Given a capture operation on a capturable fighter
    When I try to start an operation on one of my own ships
    And I try to start a second operation on the same fighter
    Then neither starts

  @capture_start_and_destroyed
  Scenario: Losing the target ends the operation as destroyed
    Given a capture operation on a capturable fighter
    When the fighter is destroyed
    Then the operation ends as "destroyed"

  @capture_abandoned
  Scenario: The operation ends when the pilot bails
    Given a capture operation on a capturable fighter
    When the fighter's pilot bails
    Then the operation ends as "abandoned"
    And the fighter is no longer part of an operation
    And no new operation can start on the now ownerless fighter

  @capture_wing_full_chance
  Scenario Outline: My wingmen's hits get my bail chance during an operation
    Given a capture operation on a fighter, led by the ship I'm flying, in my sector
    And the attacker is <attacker>
    And "wing full chance" is <setting>
    When the attacker's hit gets a bail check at vanilla's <vanilla>%
    Then the pilot rolls at <final>%
    And the mission readout shows <final>% as the last check

    Examples:
      | attacker                   | setting | vanilla | final |
      | one of its wingmen         | on      | 5       | 40    |
      | one of its wingmen         | on      | 20      | 100   |
      | one of its wingmen         | off     | 5       | 10    |
      | a ship outside the wing    | on      | 5       | 10    |

  @capture_wing_holds_fire
  Scenario: A wingman stops firing once the target is inside the bail gate
    Given a capture operation on a capturable fighter
    And my wingman flies a Nova with two pulse lasers and no missiles
    When the wingman breaks the fighter's hull below 75%
    Then the wingman stops firing
    And for 30 seconds the hull stays below 75% and above 55%
    And the hull never drops below the 35% floor

  @pending
  Scenario: My wing forces a pilot to bail without killing the ship
    Given a capture operation on a capturable fighter, with my wingman firing and me nearby
    When the wingman holds the fighter inside the bail gates
    Then the pilot bails within a few minutes
    And the operation ends as "abandoned" with the hull above the floor

  @pending
  Scenario: The comm choice starts an operation
    Given I'm flying a ship and hail the pilot of a capturable fighter
    When I choose "Heave to. We're taking your ship."
    Then a capture operation starts on that fighter

  @pending
  Scenario: Aborting the mission calls the wing off
    Given a capture operation with my wingman attacking
    When I abort the capture mission
    Then the operation ends as "called off"
    And the wingman stops attacking and returns to formation

  @capture_escaped
  Scenario: The target escapes
    Given a capture operation on a capturable fighter, with me close to it
    When nobody in the operation is within 15 km of it for 30 seconds
    Then the operation ends as "escaped"

  @capture_escape_waits_for_engagement
  Scenario: Hailing from far away doesn't count as an escape
    Given I start a capture operation on a fighter 20 km away
    When nobody in the operation has been within 15 km of it yet
    Then the operation keeps running while we close in
