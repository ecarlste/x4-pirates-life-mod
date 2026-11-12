# Spec: docs/specs/bail-hook.md
Feature: Bail hook
  Every bail check in the game runs through our code, which can change the chance, and every
  bail raises our own signal. Under SWI the hook sits in SWI's Enhanced Bailing block, and outside
  capture operations it leaves the game's chance alone. Inside them it adds bail pressure
  (bail-pressure.feature).

  @bail_hook_in_swi_block
  Scenario: The hook runs inside SWI's Enhanced Bailing block
    Given SWI is loaded
    And a crewless Imperial fighter attacked by one of my ships, with no capture operation
    When the fighter gets a bail check
    Then the bail hook adjusts the chance SWI's Enhanced Bailing worked out
    And the pilot rolls at the chance the hook returned, which is SWI's own

  @bail_raises_bailed
  Scenario: An SWI bail raises our Bailed signal
    Given a crewless Imperial fighter attacked by one of my ships
    When the pilot bails
    Then our Bailed signal fires with the pilot marked as bailed
    And the fighter is ownerless

  @bail_chance_game_own
  Scenario Outline: Outside a capture operation the chance is the game's own
    Given no capture operation on the target
    And the game has worked out an eject chance of <chance>%
    When the bail hook adjusts it
    Then the pilot rolls at <chance>%, fractions included

    Examples:
      | chance |
      | 0      |
      | 0.5    |
      | 1.75   |
      | 30     |
      | 100    |

  @pending
  Scenario: Bail checks between NPC ships run through the hook
    Given two NPC ships of different factions fighting
    When one of them gets a bail check
    Then the bail hook adjusts its chance
