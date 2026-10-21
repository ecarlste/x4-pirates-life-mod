# Spec: docs/specs/bail-hook.md
Feature: Bail hook
  Every bail check in the game runs through our code, which can change the chance, and every
  bail raises our own signal. For now the hook doubles vanilla's chance.

  @eject_chance_doubled
  Scenario Outline: The hook doubles vanilla's final eject chance, capped at 100
    Given vanilla has worked out an eject chance of <vanilla>%
    When the bail hook adjusts it
    Then the pilot rolls at <final>%

    Examples:
      | vanilla | final |
      | 0       | 0     |
      | 10      | 20    |
      | 30      | 60    |
      | 50      | 100   |
      | 70      | 100   |

  @pilot_bail_intact
  Scenario: A pilot bail raises our Bailed signal
    Given a crewless Argon fighter attacked by one of my ships
    When the pilot bails
    Then our Bailed signal fires with the pilot marked as bailed
    And the fighter is ownerless

  @pending
  Scenario: Bail checks between NPC ships run through the hook
    Given two NPC ships of different factions fighting
    When one of them gets a bail check
    Then the bail hook adjusts its chance
