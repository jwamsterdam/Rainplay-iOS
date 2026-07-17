# Rainplay iOS

[![Quality gate status](https://sonarcloud.io/api/project_badges/measure?project=jwamsterdam_Rainplay-iOS&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=jwamsterdam_Rainplay-iOS)

An iPhone-first, calm outdoor-weather app. Rainplay answers one question:

> Should we go outside now, wait a few hours, or pick tomorrow?

It is not a meteorological dashboard — it turns an Open-Meteo forecast into a
single clear decision: a best-time-to-go-outside window, an outdoor score, and a
combined chart (sky/brightness background, rain bars, temperature line).

Native SwiftUI, ported from an earlier React/TypeScript PWA prototype.

## Requirements

- Xcode (the project is developed on Xcode 27; see the note on project format below)
- iOS Simulator or device
- No third-party dependencies — everything is Apple platform frameworks
  (SwiftUI, Swift Charts, CoreLocation, Foundation, os)

## Getting started

```sh
open "Rainplay iOS.xcodeproj"
```

Build & run the **Rainplay iOS** scheme (⌘R). Run tests with ⌘U.

From the command line:

```sh
xcodebuild build -project "Rainplay iOS.xcodeproj" -scheme "Rainplay iOS" \
  -destination 'generic/platform=iOS Simulator'

xcodebuild test  -project "Rainplay iOS.xcodeproj" -scheme "Rainplay iOS" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

Organised strictly by responsibility. Presentation concerns (strings, units,
date/time formatting) live only at the view boundary; the domain layer is pure.

| Layer | Folder | Responsibility |
|---|---|---|
| Logic | `Rainplay iOS/Logic/` | Pure, framework-free domain logic: outdoor score, best-window selection, chart geometry, sky gradient, weather classification, now-marker math. Returns raw values and semantic tokens, never formatted UI strings. |
| Models | `Rainplay iOS/Models/` | App data types (`HourlyWeather`, `Forecast`, `ForecastLocation`) and UI enums. |
| Services | `Rainplay iOS/Services/` | All external I/O: `OpenMeteoClient`, `GeocodingClient`, `LocationService`, `NetworkMonitor`, `AppLog`. Only place that knows Open-Meteo field names. |
| State | `Rainplay iOS/State/` | `AppModel` — an `@Observable`, `@MainActor` store; persists settings in `UserDefaults`. |
| Views | `Rainplay iOS/Views/` | SwiftUI screens + components; `Views/Formatting/` holds the presentation helpers (units, time/date, localized labels). |

Key principles (full detail in `docs/ai/`):

- Canonical data stays in base units (temperature in °C, times as ISO strings /
  `Date`); conversion & formatting happen only in `Views/Formatting/`.
- Domain logic takes an injected `now: Date` and service protocols
  (`ServiceProtocols.swift`) so it is deterministic and testable.
- Prefer Swift `async`/`await`; no Combine. No new production dependencies
  without an architecture decision.

## Localization & locale preferences

- **Languages:** English (source) + Dutch, via a String Catalog
  (`Localizable.xcstrings`). Development region is English, so the app uses the
  device language when available (Dutch) and otherwise falls back to English.
- **In-app settings** (Settings sheet): temperature unit (System / °C / °F),
  time format (System / 12h / 24h), date format, and a **Language** row that
  opens the iOS per-app language screen. Each `System` option follows the
  device/region automatically (e.g. US → °F / 12-hour, Europe → °C / 24-hour).
- All user-facing text is localizable; the domain layer emits semantic tokens
  that are localized in `Views/Formatting/LocalizedLabels.swift`.

To add another language: open `Localizable.xcstrings` in Xcode, add the language,
and fill in the translations (see the `xcode-integration:translation-coordinator`
workflow).

## Data

Weather and geocoding come from [Open-Meteo](https://open-meteo.com) (free,
key-less tier). Coordinates are rounded before sending. No account or backend is
required today; see `docs/ai/` notes on when a proxy would become worthwhile.

## Quality & CI

- **Tests:** Swift Testing (`@Test`) for unit tests, XCUITest for a UI smoke
  suite (`Rainplay iOSUITests`). Run locally with ⌘U.
- **Linting/formatting:** SwiftLint (`.swiftlint.yml`) and SwiftFormat
  (`.swiftformat`). Autofix: `swiftlint --fix`, `swiftformat .`.
- **CI:** `.github/workflows/ci.yml` runs SwiftLint (`--strict`) + SwiftFormat on
  every push/PR to `main`. It is **lint-only** — build/test are run locally —
  because GitHub-hosted runners (Xcode 26.x) cannot open the Xcode 27 project
  format. Restore the build/test job (git history) once runners ship Xcode 27.
- **Static analysis:** SonarCloud (`sonar-project.properties`).
- **Definition of Done:** `docs/ai/definition-of-done.md`.

## AI agents

`.claude/agents/` defines three roles used for non-trivial changes —
`software-architect`, `developer`, `test-engineer` — with shared guidance in
`AGENTS.md` and `docs/ai/`.

## Project docs

- `AGENTS.md` — project intent and working agreements
- `docs/ai/` — architecture principles, coding standards, testing conventions,
  review rubric, Definition of Done, lessons learned

## Privacy

The app sends coarse coordinates to Open-Meteo to fetch the local forecast; this
is disclosed in `PrivacyInfo.xcprivacy` (not linked to identity, not used for
tracking). Location is optional — without it the app falls back to a default city.

## Known constraints

- **Project format:** the project is kept readable by older Xcode where possible,
  but Xcode 27 re-bumps `objectVersion` to 110 whenever it rewrites the project.
  This is why CI is lint-only for now.
- **Deployment target** is currently high (`IPHONEOS_DEPLOYMENT_TARGET = 27.0`) —
  lower it (e.g. to 17.0) before release to reach more devices.
