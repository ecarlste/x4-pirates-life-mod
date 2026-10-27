# Spec: docs/specs/booty.md
Feature: Booty
  I hand prizes to the Vigor Syndicate for credits and booty. Booty raises my standing with them,
  which opens bigger turn-ins, a lower fence cut and pirate variants I can unlock with booty.

  @booty_levels_and_cut
  Scenario: Levels and the fence cut follow the profile and the settings
    Given the vanilla profile's Vigor levels and a cut from 40% to 10%
    Then standing 0 is level 0, 1M is level 1, 6M is level 4 and 320M is the top level, 20
    And M, L and XL turn-ins open at levels 4, 8 and 15
    And the cut is 40% at level 0, 25% at level 10 and 10% at level 20

  @booty_lists_docked_ships
  Scenario: My ships docked at a Vigor station are found for the list
    Given a fighter of mine docked at the Vigor wharf
    When the handover list looks for my ships docked there
    Then the fighter is among them

  @manual
  Scenario: Talking to a Vigor station's staff lists my docked ships
    Given ships of mine docked at the Vigor wharf, one too big for my level
    When I talk to its manager or its ship trader, in person or by comm from the map once 60% of the station is known, and choose "Hand over booty"
    Then my docked ships are listed four to a page, pirated ones marked
    And the one too big can't be chosen, saying why
    And choosing a ship asks me to confirm before it's handed over

  @booty_handover_pays @test_booty_sells_the_requested_ship_like_a_sale_and_answers_with_the_price
  Scenario: A handover pays credits minus the fence cut, and booty
    Given a pirated fighter of mine docked at the Vigor wharf
    When I hand it over
    Then the fighter is gone, as if sold
    And I'm paid what a sale there would pay, minus the cut for my level
    And I get booty and standing for Vigor, with the stolen bonus and Vigor's taste for its maker

  @booty_donation
  Scenario: A donation earns no stolen bonus
    Given a fighter I bought, docked at the Vigor wharf
    When I hand it over
    Then I get booty and standing without the stolen bonus

  @pending
  Scenario: The order docks the prize and hands it over
    Given a pirated fighter of mine away from Vigor's stations
    When I give it the "Hand over as booty" order
    Then it docks at the nearest Vigor station that can take it and is handed over

  @booty_too_big
  Scenario: Ships too big for my level aren't taken
    Given standing below the level that opens M turn-ins
    When I try to hand over an M ship docked at the Vigor wharf
    Then it's refused, saying the Vigor Syndicate don't take ships that size from me yet

  @pending
  Scenario: The pilot moves to a free marine slot
    Given a prize with a pilot, and another of my ships with a free marine slot
    When I hand the prize over
    Then the pilot is moving to that ship as a marine

  @pending
  Scenario: The pilot skips ships with no free marine slot
    Given a prize with a pilot, my nearest ship with every marine slot full, and a ship in another sector with a free one
    When I hand the prize over
    Then the pilot is moving to the ship in the other sector as a marine

  @booty_level_up
  Scenario: Enough standing raises my level and lowers the cut
    Given standing just below the next level
    When a handover takes it past the threshold
    Then my level goes up, I'm told so, and the next handover's cut is that level's

  @booty_handover_pays
  Scenario: A handover raises rep with Vigor
    Given a relation with Vigor that isn't locked
    When I hand a prize over
    Then my relation with Vigor goes up

  @pending
  Scenario: A locked variant shows what it needs
    Given a variant I haven't unlocked
    When I look at it in the Vigor wharf's build menu
    Then it shows in red, naming the standing level and that it's bought with booty

  @pending
  Scenario: Buying an unlock with booty
    Given enough booty and the standing level an unlock needs
    When I buy it in the station manager conversation
    Then the booty is taken and the variant can be bought at the Vigor wharf

  @pending
  Scenario: Unlocks above my level aren't offered
    Given standing below an unlock's level
    When I open the unlock list
    Then that unlock isn't offered

  @pending
  Scenario: A blueprint unlock lets me build the variant at my own wharf
    Given an unlocked variant
    When I buy its blueprint unlock with booty
    Then I have its blueprint and my own wharf can build it

  @pending
  Scenario: Unlocks are kept at war with Vigor
    Given an unlocked variant and its blueprint
    When my relation with Vigor drops to enemy
    Then my own wharf can still build it

  @pending
  Scenario: The generated variants match the list
    Given the variant list and the committed generated files
    When the tests run the generator in check mode
    Then it finds no difference
