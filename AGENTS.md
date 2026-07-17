# AGENTS.md

This file captures the project intent and working agreements for future AI-assisted sessions.

## Project Summary

Rainplay is an iPhone-first vacation/outdoor weather app. It should help the user quickly decide:

- go outside now;
- wait a few hours;
- choose tomorrow or another day.

It is not a full meteorological dashboard. It should feel calm, useful, and Apple-like.

## User Goal

Rainplay combines the useful parts of several weather apps (rain amount, simplicity, some detail) into one much simpler app for vacation/outdoor decisions.

The core use case:

> We are on vacation. Should we go outside this morning, wait until the afternoon, or do it tomorrow?

Avoid framing the app around a specific activity. The direction is broad: `buiten`, `op pad`, or `beste moment`.

## Platform

This is a **native SwiftUI app for iOS/iPhone**, ported from an earlier React/TypeScript PWA prototype. Build and run with Xcode.

- Language: Swift, SwiftUI.
- Concurrency: prefer Swift `async`/`await`. Avoid Combine.
- Testing: Swift Testing framework (`@Test`) for unit tests; XCUIAutomation for UI tests.
- Tooling: build with the `BuildProject` MCP command; use `XcodeRefreshCodeIssuesInFile` for fast diagnostics and `DocumentationSearch` for up-to-date Apple API docs.

## Source of truth

Before making changes, read:
- docs/ai/definition-of-done.md
- docs/ai/coding-standards.md
- docs/ai/testing-conventions.md
- docs/ai/architecture-principles.md
- docs/ai/review-rubric.md
- docs/ai/lessons-learned.md

## Agent workflow

Use three roles when the task is more than a trivial one-line change:
1. Software Architect Agent: assess architecture, type/view boundaries, dependency choices, clean code, maintainability.
2. Developer Agent: implement the smallest correct change.
3. Test Engineer Agent: test the behavior, add/adjust tests, look for edge cases and regressions.

## Quality gate

A change is not done until every applicable item in docs/ai/definition-of-done.md
is satisfied. In summary:
- relevant tests pass;
- the project builds cleanly via `BuildProject`;
- the Test Engineer gives no blocking issues;
- the Software Architect gives no blocking issues;
- SonarCloud: quality gate is green, the change adds no new issues, and all
  issues are resolved in code or explicitly accepted/won't-fixed with a reason;
- any new dependency is justified and accepted;
- the final response lists changed files, commands run, SonarCloud status, known risks, and remaining follow-ups.

## Dependency policy

Do not add a new production Swift Package unless the Software Architect confirms:
- the platform (SwiftUI, Foundation, CoreLocation, etc.) or existing project utilities are insufficient;
- the library is maintained;
- binary size / runtime / launch-time impact is acceptable;
- iOS/iPhone behavior is acceptable;
- accessibility (Dynamic Type, VoiceOver) and testability are not degraded.

## Testing policy

Prefer behavior-oriented tests over implementation-detail tests.
Tests should prove user-visible behavior, data transformations, edge cases, and regression risks.
Avoid pixel-perfect chart/layout assertions; test the underlying geometry/data contract instead.

## Lessons learned policy

Do not silently rewrite docs/ai/lessons-learned.md.
When a recurring issue is found, propose a lesson under "Candidate lessons".
Only move it to "Accepted lessons" after explicit user or reviewer approval.

## Architecture (current)

The app is organised by responsibility:

- `Logic/` owns pure domain logic: outdoor scoring, best-window selection, chart geometry, sky-gradient derivation, weather classification, decision summary, now-marker math, and the composed weather-view logic.
- `Models/` owns app-specific weather types (`WeatherModels.swift`).
- `Services/` owns external I/O and system integration: `OpenMeteoClient` (weather API + normalization), `GeocodingClient`, `LocationService`, `NetworkMonitor`, `AppLog`, and the `ServiceProtocols` seams for testing.
- `State/` owns app state (`AppModel`, an `@Observable`).
- `Views/` owns SwiftUI screens and components (`WeatherScreen`, `DayChart`, `DayCarousel`, `SegmentedControl`, `SettingsSheet`, `LocationSelectorMenu`, `WeatherIcon`, `OfflineBanner`, etc.) plus `DesignTokens.swift` for the design-token layer.

Rules of thumb:
- Pure decision logic lives in `Logic/`, never re-derived inside views.
- External field names (Open-Meteo) stay inside `Services/`; the rest of the app reads normalized app types.
- Inject `Date` and service protocols into logic so it stays testable.

## Design North Star

- Top of the screen conveys a real weather feeling: sky, clouds, sun, temperature, and advice.
- Bottom of the screen is the practical decision area.
- No bottom tab bar. No activity selector.
- Location selector with default GPS/current location.
- Day selectors: `Vandaag`, `Morgen`, `Overmorgen`, `Week`.
- Horizon selectors: `Hele dag`, `+6 uur`, `+2 uur`.
- The chart is the main decision visualization.

## Localization & locale preferences

The app is localized: **English (source) + Dutch** via `Localizable.xcstrings`,
development region English (device language if available, else English). All
user-facing text is localizable — no hardcoded strings; the domain layer emits
semantic tokens localized in `Views/Formatting/LocalizedLabels.swift`. The
Settings sheet exposes temperature unit (°C/°F), time format (12/24h), date
format, and a Language row that opens the iOS per-app language screen; each
`System` option follows the device/region. See docs/ai/coding-standards.md
(Localization & locale) and docs/ai/definition-of-done.md. Copy stays direct and
calm; Dutch examples below.

## UI Copy Direction

Use direct, calm copy (English source + Dutch translation). Examples:
- `Buiten vanaf 14:00`
- `Wacht tot de middag`
- `Nu goed naar buiten`
- `Morgen beter`
- `Ochtend nat - middag bijna droog`
- `Weather data by Open-Meteo`

## Chart Requirements

One combined chart:
- background blocks show sky/brightness over time;
- rain bars show precipitation amount in mm;
- score informs the outdoor decision per hour;
- y-axis shows precipitation in millimeters;
- x-axis shows detailed times.

Keep it airy: very subtle grid lines, pale background blocks, no heavy card/dashboard feel, rain bars in soft iOS blue with a thin white halo. The sky/brightness background is derived from cloud cover, shortwave radiation, sunshine duration, daylight, and weather code where useful.

## Data Source

Use **Open-Meteo**. Docs: https://open-meteo.com/en/docs and https://open-meteo.com/en/docs/knmi-api

Reasons: no API account needed, worldwide coordinates, simple JSON, hourly data, rain amount and probability, cloud/solar data, wind and temperature, KNMI models available. Do not parse raw KNMI GRIB/HDF5/NetCDF unless explicitly asked.

## Outdoor Score

Expose a simple 0-10 score in the UI, but keep the formula invisible. It considers precipitation amount and probability, apparent temperature, wind speed and gusts, cloud cover, sunshine/shortwave radiation, and daylight. The score is a decision aid, not a scientific claim — tune it for human usefulness. The formula lives in `Logic/OutdoorScore.swift` and is unit-tested.

## Non-Goals

- Complex weather maps or radar.
- Activity-specific recommendations.
- Multi-page dashboard.
