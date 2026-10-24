#!/usr/bin/env bats
# Tests for tools/check_test_plan.py: the game-test plan (tests/game/features/*.feature) and the
# game tests must cover each other. Fixtures are written into a temporary folder per test.

setup() {
    command -v python3 >/dev/null || skip "python3 is not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    CHECK="$REPO_ROOT/tools/check_test_plan.py"
    FEATURES="$BATS_TEST_TMPDIR/features"
    HARNESS="$BATS_TEST_TMPDIR/tests.xml"
    SPECS="$BATS_TEST_TMPDIR/specs"
    UNITS="$BATS_TEST_TMPDIR/lua"
    mkdir -p "$FEATURES" "$SPECS" "$UNITS"
    # One unit test file, written the way tests/lua/test_*.lua are
    printf 'TestThings = {}\nfunction TestThings:test_gamma_rules()\nend\n' > "$UNITS/test_things.lua"
    # One spec, linking the feature file most tests write; the template and README are skipped
    echo 'Scenarios: [a](../../tests/game/features/a.feature)' > "$SPECS/example.md"
    echo 'No link here' > "$SPECS/_template.md"
    echo 'No link here' > "$SPECS/README.md"
    # Two game tests, reported the way the harness reports them
    cat > "$HARNESS" <<'XML'
<mdscript><cues>
  <signal_cue_instantly cue="Report" param="table[$name = 'alpha_works', $ok = true, $detail = '']"/>
  <signal_cue_instantly cue="Report" param="table[$name = 'beta_works', $ok = true, $detail = '']"/>
</cues></mdscript>
XML
}

# feature <file> <content>: writes a feature file into the fixture folder
feature() { printf '%s\n' "$2" > "$FEATURES/$1"; }

check() { run python3 "$CHECK" "$FEATURES" "$HARNESS" "$SPECS" "$UNITS"; }

GOOD='Feature: Example
  A description line.

  @alpha_works
  Scenario: Alpha works
    Given a thing
    When it happens
    Then alpha works
    And nothing breaks

  @beta_works
  Scenario Outline: Beta works for <n>
    Given <n> things
    Then beta works

    Examples:
      | n |
      | 1 |

  @pending
  Scenario: Gamma, not tested yet
    Given gamma
    Then it would work'

@test "the real test plan covers every game test" {
    run python3 "$CHECK"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "passes when every scenario is tagged with a test and every test has a scenario" {
    feature a.feature "$GOOD"
    check
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 scenarios (1 pending, 0 manual) cover all 2 game tests"* ]]
}

@test "fails when a game test has no scenario" {
    feature a.feature "${GOOD//@beta_works/@pending}"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"game test beta_works has no scenario"* ]]
}

@test "fails when a tag names no game test" {
    feature a.feature "$GOOD
  @alpha_typo
  Scenario: Misspelt
    Given a typo
    Then it is caught"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"@alpha_typo is not a game test or unit test"* ]]
}

@test "fails when a scenario has no tag" {
    feature a.feature "$GOOD
  Scenario: Untagged
    Given nothing
    Then it is caught"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"scenario has no tag"* ]]
}

@test "fails on a step without a Gherkin keyword" {
    feature a.feature "${GOOD//    And nothing breaks/    Or nothing breaks}"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"a.feature:9: step must start with Given, When, Then, And or But"* ]]
}

@test "reads scenarios across several feature files" {
    feature a.feature "Feature: A
  @alpha_works
  Scenario: Alpha
    Given a
    Then alpha works"
    feature b.feature "Feature: B
  @beta_works
  Scenario: Beta
    Given b
    Then beta works"
    check
    [ "$status" -eq 0 ]
}

@test "fails when there are no feature files" {
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"no .feature files"* ]]
}

@test "fails when a spec links no feature file" {
    feature a.feature "$GOOD"
    echo 'A spec with no scenarios' > "$SPECS/other.md"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec other.md links no feature file"* ]]
}

@test "fails when a spec links a feature file that doesn't exist" {
    feature a.feature "$GOOD"
    echo 'Scenarios: tests/game/features/missing.feature' > "$SPECS/other.md"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec other.md links tests/game/features/missing.feature, which doesn't exist"* ]]
}

@test "counts @manual scenarios separately from @pending" {
    feature a.feature "$GOOD
  @manual
  Scenario: Delta, checked by hand
    Given delta
    Then it looks right"
    check
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 scenarios (1 pending, 1 manual) cover all 2 game tests"* ]]
}

@test "fails when a scenario is both @pending and @manual" {
    feature a.feature "$GOOD
  @pending @manual
  Scenario: Undecided
    Given indecision
    Then it is caught"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"tests, @pending and @manual can't be mixed (scenario: Undecided)"* ]]
}

@test "accepts a unit test's name as a scenario's tag, and counts it" {
    feature a.feature "${GOOD//@pending/@test_gamma_rules}"
    check
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 scenarios (0 pending, 0 manual) cover all 2 game tests; 1 covered by unit tests"* ]]
}

@test "fails when a scenario mixes a test with @manual" {
    feature a.feature "$GOOD
  @alpha_works @manual
  Scenario: Half and half
    Given both
    Then it is caught"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"can't be mixed (scenario: Half and half)"* ]]
}

@test "fails when two unit tests share a name" {
    feature a.feature "$GOOD"
    printf 'TestOther = {}\nfunction TestOther:test_gamma_rules()\nend\n' > "$UNITS/test_other.lua"
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"unit test test_gamma_rules is defined twice (test_other.lua, test_things.lua)"* ]]
}
