# Testing Conventions

## General
- Test behavior, not implementation details.
- Prefer tests that fail for real user-visible regressions.
- Keep tests readable; a future developer should understand the scenario quickly.
- Do not delete or weaken tests without explaining why the previous assertion was wrong.
- Use the Swift Testing framework (`@Test`, `#expect`, `#require`) for unit tests
  and XCUIAutomation for UI tests.

## Pure domain logic (Logic/)
- This is the primary place for fast, deterministic unit tests: scoring,
  best-window selection, chart geometry, sky gradient, classification, decision
  summary, now-marker math.
- Inject `Date` and other inputs; never read the clock inside the function under
  test.
- Cover edge cases: empty hourly ranges, night hours, missing probability, bad
  coordinates, out-of-range windows, and clamp boundaries.

## Services (Services/)
- Test response decoding and normalization (Open-Meteo → app types) as pure
  transformations against fixture JSON.
- Mock at the boundary using the protocols in `ServiceProtocols.swift`
  (network, location, connectivity) — do not over-mock the unit under test.
- Verify error mapping: transport/decoding failures become a plain, readable app
  `Error`, not leaked internals.

## SwiftUI views
- Test user-visible output and interaction, preferring XCUIAutomation for real
  UI behavior and unit tests for the logic that feeds the view.
- Test loading, empty, error, and success states when relevant.
- For toggle/segmented-control-driven UI, verify both initial state and changed
  state.
- Keep accessibility in scope: labels and traits for interactive elements.

## Charts and visual UI
- Do not assert pixel-perfect chart output.
- Test the data transformation and geometry contract (from `Logic/`),
  visibility, empty data, and disabled/edge states.
- Assert renderable contracts (non-null, in-range fractions) rather than
  over-specified exact pixel values.

## Required commands
- Build and run tests via the `BuildProject` MCP command.
- Use `XcodeRefreshCodeIssuesInFile` for fast diagnostics while iterating.
- The agent must report which commands were run and their result.
