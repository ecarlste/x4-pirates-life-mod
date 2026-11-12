# Spec: docs/specs/bail-pressure.md
Feature: Bail pressure
  In a capture operation, the target's pilot gets likelier to bail the longer it is held inside
  the bail gates (shields under 20% or none, hull under 75%), so a capture comes within about
  30-50 s. A pressure tick asks for bail checks, so a wing that only keeps the shields down gets
  them as fast as a player who keeps firing. A pilot who gets away keeps what's left as fear,
  which decays over time, and a new operation on that pilot starts from it.

  @bail_pressure_first_check_plain
  Scenario: The first check of a fresh operation rolls at the game's chance
    Given a target already inside the bail gates
    When I start a capture operation on it
    And it gets a bail check at once
    Then the pilot rolls at the game's own chance

  @bail_pressure_builds_with_time
  Scenario: Pressure builds with time inside the gates, not with checks
    Given a capture operation on a target inside the bail gates
    When it has been inside the gates for 10 s
    Then its bail chance is 8 points above the game's
    And a second check at the same moment gets the same chance
    When its hull is repaired above 75% for 10 s
    Then the pressure stays where it was
    When it is back inside the gates for 10 s
    Then the pressure is 8 points higher again

  @bail_pressure_capped
  Scenario Outline: The adjusted chance stays between the game's chance and the cap
    Given a capture operation whose target has built up more pressure than the cap
    And the game has worked out a bail chance of <chance>%
    When the bail hook adjusts it
    Then the pilot rolls at <rolled>%

    Examples:
      | chance | rolled |
      | 0      | 80     |
      | 0.5    | 80     |
      | 30     | 80     |
      | 79.5   | 80     |
      | 80     | 80     |
      | 90     | 90     |
      | 100    | 100    |

  @bail_pressure_tick
  Scenario: Checks come every 5 s while the target is held, without hits
    Given I lead a capture operation within 10 km of its target
    And the target is inside the bail gates
    And nobody fires at it
    Then it gets a bail check every 5 s, with my ship as the attacker
    And each check goes through the game's own bail path

  @bail_pressure_tick_keeps_cooldown
  Scenario: Hits and the pressure tick together roll no more often than every 5 s
    Given a crewed target inside the bail gates, hit every second by one of my ships
    And SWI's 5 s cooldown is running from a check 2.5 s ago
    When I start a capture operation on it
    Then the pressure tick waits for the cooldown instead of clearing it
    And the target's checks stay about 5 s apart

  @bail_pressure_through_partial_bail
  Scenario: Pressure keeps building through a partial crew bail
    Given a capture operation on a crewed ship inside the bail gates
    When some of its crew bail but the pilot stays
    Then the operation goes on
    And 10 s later the pressure is 8 points higher

  @fear_carries_over
  Scenario: A pilot who got away stays shaken
    Given a capture operation on a target that has built up bail pressure
    When I call the operation off, or the target escapes
    Then the pressure left stays on its pilot as fear
    When I start a new operation on it
    Then its pressure starts from that fear

  @fear_decays
  Scenario Outline: Fear decays when it's read
    Given a pilot left with 40 points of fear <age> ago
    And fear decays by x<factor> per <interval> s
    When the fear is read
    Then <left> points are left

    Examples:
      | age   | factor | interval | left  |
      | 0 s   | 0.5    | 300      | 40    |
      | 150 s | 0.5    | 300      | 28.28 |
      | 300 s | 0.5    | 300      | 20    |
      | 600 s | 0.5    | 300      | 10    |
      | 100 s | 0.25   | 100      | 10    |
      | 50 s  | 0.25   | 100      | 20    |
      | 600 s | 1      | 300      | 40    |
      | 300 s | 0      | 300      | 0     |

  @fear_decays
  Scenario: A new operation starts from the fear left
    Given a pilot left with 40 points of fear 300 s ago
    When I start a capture operation on its ship
    Then its pressure starts at 20

  @fear_cleared
  Scenario: Capture or destruction clears fear
    Given three pilots with fear, each in a capture operation that started from it
    When one ship becomes mine, one's pilot bails, and one is destroyed
    Then none of the three pilots keeps any fear

  @pending
  Scenario: The pressure tick waits while the player is away
    Given a capture operation on a target inside the bail gates
    When I fly another ship, or am more than 10 km from the target
    Then the operation asks for no bail checks
    But the pressure keeps building with time
