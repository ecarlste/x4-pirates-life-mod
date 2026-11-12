# Spec: docs/specs/capture-operation.md
Feature: Capture operations
  I start a capture operation on a capturable ship, alone or with my wing. My wingmen break its
  hull below the bail gate, then only keep its shields down, so the pilot bails instead of dying.
  Bail pressure and the checks the operation asks for are in bail-pressure.feature.

  @capture_start_and_destroyed
  Scenario: An operation starts on a capturable fighter
    Given a capturable Imperial fighter with a pilot
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

  @capture_wing_holds_fire
  Scenario: A wingman stops firing once the target is inside the bail gate
    Given a capture operation on a capturable fighter with 80% hull and its shields kept down until the hull is below 75%
    And my wingman flies an X-wing with four lasers and no missiles
    When the wingman breaks the fighter's hull below 75%
    Then the wingman stops firing
    And for 30 seconds the hull stays below 75% and above 55%
    And the hull never drops below the 35% floor
    And the wingman keeps moving while it holds fire, never sitting still for 5 seconds

  @no_missiles_in_sight
  Scenario: My wingmen fire no missiles or torpedoes at the target in my sight
    Given my wingman flies an X-wing with proton torpedoes, 1 km from me
    And its pilot is in a capture operation
    When it attacks a fighter for a minute
    Then it fires no missiles or torpedoes

  @no_missiles_out_of_sight
  Scenario: My wingmen fire no missiles or torpedoes at the target out of my sight
    Given my wingman flies an X-wing with proton torpedoes, 150 km from me
    And its pilot is in a capture operation
    When it attacks a fighter for a minute
    Then it spends no missiles or torpedoes

  @no_missiles_in_sight @no_missiles_out_of_sight
  Scenario: A ship outside an operation fires missiles as in vanilla
    Given an X-wing with proton torpedoes whose pilot is in no operation
    When it attacks a fighter, in my sight or out of it
    Then it fires missiles as vanilla does

  @pending
  Scenario: A formation follower of my wingman fires no missiles out of my sight
    Given my wingman in a capture operation leads a formation of its own, 150 km from me
    When a follower joins its attack on the target
    Then the follower spends no missiles or torpedoes and its missiles deal no damage

  @pending
  Scenario: My wing forces a pilot to bail without killing the ship
    Given a capture operation on a capturable fighter, with my wingman firing and me nearby
    When the wingman holds the fighter inside the bail gates
    Then the pilot bails within a few minutes
    And the operation ends as "abandoned" with the hull above the floor

  @capture_comm_choice
  Scenario: The comm choice starts an operation
    Given I'm flying a ship and hail the pilot of a capturable fighter
    When I choose "Heave to. We're taking your ship."
    Then a capture operation starts on that fighter

  @capture_abort_calls_wing_off
  Scenario: Aborting the mission calls the wing off
    Given a capture operation with my wingman attacking
    When I abort the capture mission
    Then the operation ends as "called off"
    And the wingman stops attacking and returns to formation

  @capture_readout
  Scenario: The mission readout shows the gates, the pilot's nerve and crew aboard
    Given a capture operation on a crewed ship with full shields and hull, out of the pressure tick's reach
    Then the mission shows "Knock shields below 20%" as step 1 of 3
    When its shields are down
    Then the mission shows "Damage hull below 75%" as step 1
    When its hull is at 50% for 10 seconds
    Then the mission shows "Pilot's nerve" as step 2, with a bar of about 72 of 80
    When one of its crew bails
    Then the mission shows "Crew aboard n/max" with the last check's chance as step 3, with a bar of the crew left
    And a capture operation on a crewless fighter has only the first 2 steps

  @manual
  Scenario: The comm choice and the mission's Abort work in SWI's menus
    Given I'm playing on SWI, flying a ship with a wingman
    When I hail a capturable fighter and click "Heave to. We're taking your ship."
    Then a capture operation starts and its mission shows
    When I click Abort on that mission in SWI's mission menu
    Then the operation ends as "called off" and the wingman returns to formation

  @capture_marked_as_hostile
  Scenario: The target turns hostile as with vanilla's "Mark as hostile"
    Given a capturable fighter
    When I start a capture operation on it, alone or with my wing
    Then it turns hostile to me with the same reason as vanilla's "Mark as hostile"

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
