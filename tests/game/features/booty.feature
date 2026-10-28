# Spec: docs/specs/booty.md
Feature: Booty
  I hand prizes to the Vigor Syndicate for credits and booty. Booty raises my standing with them,
  which opens bigger turn-ins, a lower fence cut and pirate variants to buy, and booty buys their blueprints.

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

  @booty_order_hands_over
  Scenario: The order flies the prize to the nearest Vigor station, docks and hands it over
    Given a fighter of mine flying away from Vigor's stations
    When I give it the "Hand over as booty" order without choosing a station
    Then it flies to the nearest Vigor station I know that can take it, docks and is handed over

  @booty_order_refuses_too_big
  Scenario: The order refuses a ship too big for my level before it flies
    Given standing below the level that opens M turn-ins
    When I give an M ship the "Hand over as booty" order
    Then the order ends without flying, and I'm told the Vigor Syndicate don't take ships that size from me yet

  @booty_too_big
  Scenario: Ships too big for my level aren't taken
    Given standing below the level that opens M turn-ins
    When I try to hand over an M ship docked at the Vigor wharf
    Then it's refused, saying the Vigor Syndicate don't take ships that size from me yet

  @booty_pilot_moves
  Scenario: The pilot moves to a free marine slot
    Given a prize with a pilot, and another of my ships with a free marine slot
    When I hand the prize over
    Then the pilot is moving to that ship as a marine
    And they're still there after the prize is sold

  @booty_pilot_skips_full
  Scenario: The pilot skips ships with no free marine slot
    Given a prize with a pilot, my nearest ship with every crew slot full, and a farther one with room
    When I hand the prize over
    Then the pilot is moving to the farther ship as a marine

  @manual
  Scenario: The pilot goes to another sector only when this one has no room
    Given a prize with a pilot, no ship with room in its sector, and ships with room one and two gates away
    When I hand the prize over
    Then the pilot is moving to the ship one gate away

  @booty_level_up
  Scenario: Enough standing raises my level and lowers the cut
    Given standing just below the next level
    When a handover takes it past the threshold
    Then my level goes up (one level or more, as the prize's price varies), I'm told so, and the next handover's cut is that level's

  @booty_handover_pays
  Scenario: A handover raises rep with Vigor
    Given a relation with Vigor that isn't locked
    When I hand a prize over
    Then my relation with Vigor goes up

  @variant_gear
  Scenario: The pirate gear loads and fits
    Given the pirate gear generated from the list
    When a Nova is fitted with pirate combat engines, a pirate shield and a Stripper, and another with the vanilla gear they're rigs of
    Then the pirate Nova is about 10% faster and boosts faster still, and its shield holds 15% less
    And every gear ware and its unlock research exist, named as generated, and I don't have the research yet

  @variant_turret
  Scenario: The Stripper turret and the pirate M shield fit M and L hulls
    Given the Stripper turret generated from the list, built on the Teladi muon blaster turret
    When a Gorgon and a Barbarossa are fitted with two each, and the Barbarossa with two pirate M shields
    Then both carry two working Stripper turrets, the Barbarossa's as their destructible twin
    And the Barbarossa carries the pirate M shield's destructible twin
    And the twins' wares have their gear's names

  @test_variants_stripper_turret_rigs_its_bullet_and_destructible_twin @test_variants_shield_twin_gets_the_same_rig
  Scenario: Gear with a destructible twin gets a rigged twin
    Given gear in the list whose vanilla macro has a destructible twin (alias), as M turrets and shields do
    When the variants are generated
    Then the twin is copied and rigged the same: the Stripper turret's twin fires its bullet, which does about 8 times more shield than hull damage, and the pirate shield's twin holds less and recharges sooner
    And the twin carries the gear's name and is a ware of its own under the same unlock
    And the stamp check without game files notices a missing twin, or a variant still pointing at vanilla's twin

  @test_variants_engine_rig_burst_boost_and_weak_reverse @test_variants_shield_rig_scales_capacity_and_recharge_delay @test_variants_stripper_copies_the_bullet_with_shield_up_and_hull_down @test_variants_missile_copies_its_effect_list_with_longer_shutdowns @test_variants_gear_is_named_pirate_or_given_its_fun_name @test_variants_stamp_check_knows_the_gear_files_without_game_files
  Scenario: A rig changes a copy of the vanilla gear
    Given a vanilla engine, shield, weapon or missile and a rig in the list
    When the generator runs
    Then pirate engines have the rig's thrust, a bigger, shorter, slower-to-recharge boost and a weak reverse
    And pirate shields hold less and start recharging sooner
    And a Stripper fires a copy of its bullet with more shield damage and less hull damage
    And a pirate missile has a copy of its effect list with the shutdowns lasting longer
    And each is named "Pirate" for the maker, or by its fun name for its base name ("S Stripper Mk1", "Cold Feet Mk1")

  @manual
  Scenario: Locked pirate gear shows what it needs
    Given pirate gear I haven't unlocked
    When I look at it in the Vigor wharf's equipment or upgrade menu
    Then it shows in red with the beaker, naming the standing level and that it's bought with booty

  @manual
  Scenario: A locked variant shows what it needs
    Given a variant I haven't unlocked
    When I look at it in the Vigor wharf's build menu
    Then it shows in red, naming the standing level and that it's bought with booty

  @variant_ships
  Scenario: Every listed variant loads with its rig, name and locked unlock
    Given the variants generated from the list
    When each is spawned beside its vanilla ship
    Then it has the rig's hull, and more crew where the rig adds crew
    And it's named "Pirate" and the vanilla name
    And its ware and its own unlock research exist, and I don't have the research yet

  @test_variants_rig_scales_hull_drag_and_travel_and_names_the_variant @test_variants_cargo_rig_copies_the_storage_macro @test_variants_crew_rises_by_at_least_one @test_variants_ware_needs_its_hidden_research_and_belongs_to_the_group
  Scenario: A rig changes a copy of the vanilla ship
    Given a vanilla ship and a rig in the list
    When the generator runs
    Then the variant is a copy on the same model with the rig's hull, crew, drag, travel acceleration and cargo
    And its ware costs the vanilla price times the price multiplier, belongs to the group and needs a hidden research

  @pending
  Scenario: Reaching a level unlocks its variants for buying
    Given standing just below the level a variant needs
    When a handover takes me to that level
    Then I have the variant's unlock, with no booty taken, and it can be bought at the Vigor wharf
    And I'm told what the level unlocked

  @pending
  Scenario: Unlocks are granted to a game already past their level
    Given a game whose standing is past a variant's level, saved before that variant was in the list
    When the game loads with the mod
    Then I have the variant's unlock

  @pending
  Scenario: Buying a blueprint with booty
    Given an unlocked variant and enough booty for its blueprint
    When I buy it in the station manager conversation
    Then the booty is taken, I have its blueprint and my own wharf can build it

  @pending
  Scenario: Blueprints cost the multiplier, with a floor
    Given a variant whose vanilla blueprint price times the multiplier is below the floor
    Then its blueprint costs the floor, and an expensive one costs its price times the multiplier

  @pending
  Scenario: Blueprints of variants above my level aren't offered
    Given standing below a variant's level
    When I open the blueprint list
    Then that blueprint isn't offered

  @pending
  Scenario: Unlocks are kept at war with Vigor
    Given an unlocked variant and its blueprint
    When my relation with Vigor drops to enemy
    Then my own wharf can still build it

  @test_variants_check_passes_when_up_to_date_and_fails_when_the_list_changes @test_variants_stamp_check_without_game_files @test_variants_a_ship_dropped_from_the_list_is_left_over_then_removed
  Scenario: The generated variants match the list
    Given the variant list and the committed generated files
    When the tests run the generator in check mode (in full with the game files, by their stamps without them)
    Then it finds no difference, nothing missing and nothing left over
