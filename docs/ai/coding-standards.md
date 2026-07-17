# Coding Standards

These standards define how Rainplay code should be written, reviewed, and
evolved. They are intentionally practical: code should be simple to read, safe
to change, and resilient as the app grows.

## Core principles

- Optimize for correctness, clarity, and small safe changes before cleverness.
- Make code read from intent to detail: names should explain what the code is
  for, not just what it mechanically does.
- Keep domain logic independent from presentation and framework details.
- Prefer explicit data shapes and pure functions at boundaries where behavior
  matters.
- Treat every abstraction as a cost. Add one only when it removes real
  duplication, clarifies ownership, or protects a stable boundary.
- Preserve the product direction: iPhone-first, calm, fast, Dutch, and focused
  on outdoor decisions rather than meteorological completeness.

## File and module boundaries

- `Services/` owns external service integration, request construction, response
  decoding/validation, and normalization into app-specific types
  (`OpenMeteoClient`, `GeocodingClient`, `LocationService`, `NetworkMonitor`,
  `AppLog`). Service seams for testing live in `ServiceProtocols.swift`.
- `Logic/` owns pure domain logic such as scoring, best-window selection, chart
  geometry, sky-gradient derivation, weather classification, decision summary,
  now-marker math, and the composed weather-view logic. No I/O, no framework
  dependencies beyond Foundation.
- `Models/` owns app-specific weather types.
- `State/` owns `AppModel` (an `@Observable`) and app-wide state.
- `Views/` owns SwiftUI screens and reusable/screen-local components. Views may
  coordinate UI behavior but must not duplicate domain decisions already owned
  by `Logic/` or `Services/`.
- `Views/DesignTokens.swift` owns design tokens and low-level styling primitives.

When adding a file, choose the layer by responsibility, not by convenience. If a
function is hard to place, that is usually a signal to clarify its inputs,
outputs, or ownership before writing more code.

## Naming

- PascalCase for types; camelCase for properties and methods.
- Use names that encode business meaning: `outdoorScore`, `bestWindow`,
  `precipitationMm`, `apparentTemperatureC`, `windGustKmh`.
- Include units in names for measured values where confusion is plausible:
  `rainMm`, `durationMinutes`, `windSpeedKmh`, `radiationWm2`.
- Avoid vague names such as `data`, `item`, `info`, `value`, or `result` outside
  very small local scopes.
- Name booleans as predicates: `isDaylight`, `hasRain`, `canUseLocation`.
- Name event handlers/actions after user intent: `selectDay`, `retryForecast`.

## Swift

- Leverage Swift's strong type system. Avoid force-unwrapping (`!`) and
  force-casts; handle optionals and failures explicitly.
- Prefer exact domain types over loose dictionaries. Convert external API shapes
  into app-owned types before they reach views.
- Use enums (with associated values where useful) for state that has distinct
  modes such as loading, denied, unavailable, success, or error.
- Keep public function parameters and return values explicit when they are part
  of a module boundary.
- Keep nullable/missing values close to the boundary. Normalize missing data
  into a clear fallback, optional field, or explicit state before rendering.
- Prefer `let` over `var`; keep mutability local and intentional.

## Functions and domain logic

- Functions should do one coherent thing at one level of abstraction.
- Prefer pure functions for scoring, weather normalization, chart geometry, and
  time-window decisions — this is what `Logic/` is for.
- Inject time into domain logic with a `Date` parameter instead of calling
  `Date()` inside logic that needs tests.
- Keep formulas named and decomposed enough that a reviewer can understand the
  trade-offs without reverse-engineering arithmetic.
- Do not duplicate decision logic in views. If hero advice, chart markers, and
  summary text depend on the same concept, derive it once in `Logic/`.
- Make edge cases visible in code: empty hourly ranges, night hours, missing
  probability, bad coordinates, network timeout, and out-of-range forecast
  windows.

## SwiftUI views

- Conform views to `View`; define UI in the `body` property.
- Views should primarily render data and coordinate local interaction.
- Keep shared/cross-widget state in `AppModel` or a screen-level parent, not in
  leaf visual components.
- Do not hold server/derived state in view-local `@State` when `AppModel` or
  `Logic/` should own it.
- Keep effects (`task`, `onChange`, `onAppear`) small and tied to external
  systems: network, location, connectivity, timers, lifecycle. Prefer values
  derived during render over effects.
- Keep accessibility part of the view contract: meaningful labels, Dynamic Type
  support, VoiceOver traits, and adequate touch targets.
- Prefer stable, boring parameters over highly configurable option bags.
- Split views when responsibilities, state ownership, or test setup become
  unclear — not to make files look symmetrical. A view that grows past roughly
  150-200 lines should trigger a design check: is it mixing layout, state
  coordination, domain decisions, data transformation, and rendering details?
- Prefer extracting cohesive subviews or pure helper functions over letting a
  view become a vertical slice of the whole feature.
- Consult the `xcode-integration:swiftui-specialist` skill for current SwiftUI
  best practices, and `DocumentationSearch` for unfamiliar or new APIs.

## State and data fetching

- `AppModel` owns app/UI state such as selected day, horizon, location choice,
  and presentation preferences.
- `Services/` own network and geocoding lifecycles using `async`/`await`
  (not Combine); keep requests cancellable or timeout-bounded.
- Normalize API responses in `Services/` before the UI reads them. Views should
  not know Open-Meteo field names unless rendering raw diagnostics.
- Preserve useful error information for UI copy and debugging, but keep user
  messages calm and actionable.

## Styling and UI code

- Use design tokens from `Views/DesignTokens.swift` for repeated color, spacing,
  radius, shadow, and typography decisions.
- Design for iPhone first: safe areas, touch targets, reduced motion, Dynamic
  Type, and readable type.
- Avoid layout that depends on exact text length. Dutch copy must fit on narrow
  screens without overlap or truncation.
- Keep visual density calm. Rainplay should feel like a decision aid, not an
  operations dashboard.
- Consult `xcode-integration:swiftui-specialist` and, where the new design
  system is involved, search `DocumentationSearch` for Liquid Glass.

## Charts and visualizations

- Chart code must separate data preparation, geometry decisions, and rendering.
- Chart math belongs in pure helpers in `Logic/` (e.g. `ChartGeometry.swift`,
  `NowMarker.swift`) with focused tests.
- Views may project normalized chart data to SwiftUI/Charts primitives but must
  not reimplement weather scoring or best-window logic.
- Avoid pixel-perfect unit tests. Test transformation contracts, visibility,
  empty states, and edge cases (see docs/ai/testing-conventions.md).

## Localization & locale

- **No hardcoded user-facing strings.** Use `LocalizedStringKey` in views
  (`Text("some.key")`) and `LocalizedStringResource` for text produced outside a
  view. Every key has an entry in `Localizable.xcstrings` with an English source
  value, a Dutch translation, and a translator comment.
- Keys are symbolic and dotted (e.g. `settings.title`, `hero.outsideFrom %@`).
  Interpolate with placeholders (`%@`, `%lld`) — never assemble sentences by
  string concatenation, so word order and capitalization are the translation's job.
- The domain layer (`Logic/`, `Models/`) must not emit localized sentences. It
  returns semantic tokens (enums like `OutdoorSummary`, `DayPeriod`,
  `WeatherKind`); those are mapped to localized text only in
  `Views/Formatting/LocalizedLabels.swift`.
- Units, times, and dates are formatted at the presentation boundary
  (`Views/Formatting/`) driven by the user's Settings choice; `.system` resolves
  from the locale (e.g. US → °F / 12-hour). Keep locale-specific formatting out
  of `Logic/`.
- Enum `rawValue`s used for persistence/identity (`DayOption`, `HorizonOption`,
  `LocationSource`) are never shown to the user — display goes through a
  localized `titleKey`. Do not change those rawValues to localize a label.
- Development region is English; Dutch is an added localization, so the app uses
  the device language when available and otherwise falls back to English.

## Dependencies

- Do not add a production dependency until platform APIs and current project
  utilities have been considered.
- New dependencies must be maintained, well-typed, accessible where relevant,
  and compatible with iOS/iPhone constraints.
- Consider binary size, launch time, and runtime behavior before adding or
  expanding a dependency in the user-facing path.
- If a dependency is temporary, document the exit criteria or migration path.

## Error handling

- Handle expected failures explicitly: denied/unavailable location, failed
  forecast fetches, empty search results, malformed API data, and offline or
  slow network states.
- Do not let low-level errors leak directly into user-facing copy.
- Prefer recoverable UI states with retry paths over hard failures.
- Preserve enough technical detail at boundaries for debugging and tests
  (`AppLog`).

## Comments and documentation

- Write code that usually does not need comments.
- Add comments for non-obvious domain choices, platform quirks, formula tuning,
  and dependency trade-offs.
- Do not comment obvious mechanics.
- When a recurring issue is discovered, propose a lesson in
  docs/ai/lessons-learned.md under "Candidate lessons"; do not promote it to
  accepted without explicit approval.

## Testing expectations

- Every meaningful domain helper in `Logic/` should have behavior-oriented tests
  using the Swift Testing framework.
- New logic that affects advice, scores, chart visibility, location, or API
  normalization needs tests unless the change is purely cosmetic.
- Prefer tests that describe user-visible behavior or stable data contracts.
- Mock at system boundaries via the protocols in `ServiceProtocols.swift`:
  network, location, connectivity, timers.
- Do not weaken tests to fit an implementation. If a test is wrong, explain the
  corrected behavior in the change.
- Build and run tests via the `BuildProject` MCP command and report exactly
  what was run.

## Change discipline

- Keep diffs focused on the requested behavior.
- Avoid broad rewrites, formatting churn, or opportunistic refactors.
- When touching code with nearby issues, fix only what is needed unless the
  issue directly affects the requested change.
- Preserve user or teammate edits already present in the worktree.
- Prefer one clear improvement over several half-finished improvements.
- A change is complete only when architecture, implementation, and tests all
  agree on the same behavior.
