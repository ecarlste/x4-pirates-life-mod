# Spec: docs/specs/pirated-ships.md
Feature: Pirated ships
  Every ship that becomes mine is marked pirated if I took it in combat, by boarding or by its
  crew bailing, and is a donation otherwise, so booty pays the stolen bonus only for piracy.

  @pirated_bail_then_claim
  Scenario: A ship that bailed to me and that I claim is pirated
    Given a capturable Argon fighter whose pilot bails while one of my ships attacks it
    When I claim the abandoned fighter
    Then it's marked pirated, by bail, from the Argon

  @pirated_boarding
  Scenario: A ship I board is pirated
    Given my boarding operation on an Argon frigate
    When the frigate becomes mine
    Then it's marked pirated, by boarding, from the Argon

  @manual
  Scenario: A ship docked at a ship I board is pirated
    Given a capturable ship docked at a carrier
    When my boarding operation takes the carrier
    Then the docked ship becomes mine too, marked pirated by boarding

  @pirated_claim_without_bail
  Scenario: Claiming a ship abandoned without me is a donation
    Given an abandoned fighter that never bailed to me
    When I claim it
    Then it isn't marked pirated
