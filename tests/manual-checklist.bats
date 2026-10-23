#!/usr/bin/env bats
# Tests for tools/manual-checklist.py: every @manual scenario of the game-test plan becomes a
# checkbox with its steps, grouped by feature. Fixtures are written into a temporary folder.

setup() {
    command -v python3 >/dev/null || skip "python3 is not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TOOL="$REPO_ROOT/tools/manual-checklist.py"
    FEATURES="$BATS_TEST_TMPDIR/features"
    mkdir -p "$FEATURES"
    cat > "$FEATURES/a.feature" <<'GHERKIN'
# Spec: docs/specs/a.md
Feature: Alpha things
  A description line.

  @alpha_works
  Scenario: Alpha works
    Given a thing
    Then alpha works

  @manual
  Scenario: The dialog looks right
    Given the settings page is open
    When I open the save dialog
    Then the name field has focus
    And the buttons line up

  @pending
  Scenario: Not tested yet
    Given gamma
    Then it would work
GHERKIN
    cat > "$FEATURES/b.feature" <<'GHERKIN'
Feature: Beta things

  @manual
  Scenario Outline: Profiles survive a restart with <count> profiles
    Given <count> saved profiles
    When I restart X4
    Then they're all still there

    Examples:
      | count |
      | 1     |
GHERKIN
}

checklist() { run python3 "$TOOL" "$@"; }

@test "lists only @manual scenarios, with their steps, grouped by feature" {
    checklist "$FEATURES"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Alpha things (\`a.feature\`)"* ]]
    [[ "$output" == *"- [ ] **The dialog looks right**"* ]]
    [[ "$output" == *"  - Given the settings page is open"* ]]
    [[ "$output" == *"  - And the buttons line up"* ]]
    [[ "$output" == *"## Beta things (\`b.feature\`)"* ]]
    [[ "$output" == *"  - Examples:"* ]]
    [[ "$output" == *"    | 1     |"* ]]
    [[ "$output" != *"Alpha works"* ]]
    [[ "$output" != *"Not tested yet"* ]]
}

@test "says so when there are no manual scenarios" {
    rm "$FEATURES/b.feature"
    sed -i.bak 's/@manual/@pending/' "$FEATURES/a.feature" && rm "$FEATURES/a.feature.bak"
    checklist "$FEATURES"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No manual scenarios."* ]]
}

@test "writes the checklist to a file with -o, creating its folder" {
    checklist -o "$BATS_TEST_TMPDIR/dist/manual-checklist.md" "$FEATURES"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Wrote 2 manual scenarios to"* ]]
    grep -q -- '- \[ \] \*\*The dialog looks right\*\*' "$BATS_TEST_TMPDIR/dist/manual-checklist.md"
}

@test "refuses a test plan the checker can't read" {
    printf 'Feature: Broken\n\n  Scenario: No tag\n    Given nothing\n' > "$FEATURES/c.feature"
    checklist "$FEATURES"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scenario has no tag"* ]]
}

@test "the real test plan produces a checklist" {
    run python3 "$TOOL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Manual release checklist"* ]]
}
