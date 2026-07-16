# Architecture Principles

## View and type boundaries

Split a view or type when:
- it owns multiple unrelated responsibilities;
- test setup becomes unnecessarily complex;
- a subpart is reused elsewhere;
- state ownership becomes unclear;
- rendering and data transformation are mixed heavily.

Do not split when:
- the view is still small and cohesive;
- the split creates prop-drilling of bindings without reuse;
- the new abstraction hides simple behavior;
- the separation is only aesthetic.

## State ownership

- Keep state at the lowest level that can still coordinate all consumers.
- Shared UI state should live in `AppModel` (the `@Observable`) or a screen-level parent, not in leaf visual components.
- Use `@State private var` for genuinely local, view-owned state; `let` for constants.
- Derived data should be computed close to where inputs are known — ideally in `Logic/`, not recomputed in a view.

## Layer responsibilities

- `Logic/` — pure, framework-free domain functions. No I/O, no `new Date()`/`Date()` reads inside logic that needs testing (inject the clock).
- `Services/` — all external I/O and system integration (network, CoreLocation, connectivity, logging). This is the only place that knows Open-Meteo field names.
- `State/` — `AppModel` and app-wide state wiring.
- `Views/` — SwiftUI presentation and local interaction only.

## API boundary validation

- Validate/normalize external API responses at the network boundary in `Services/` (`OpenMeteoClient`), using `Codable` decoding into DTOs and then mapping to app-owned model types.
- Keep DTO decoding separate from normalization so each is independently testable.
- Convert decoding/transport failures into a plain, readable app `Error` before they reach `AppModel` or the UI — never leak low-level decoding internals into user-facing copy.
- The rest of the app reads app-owned types (e.g. `HourlyWeather`, `ForecastLocation`), never raw Open-Meteo shapes.

## Dependencies

Before adding a Swift Package, check:
- can the platform (SwiftUI, Foundation, CoreLocation, Charts, etc.) or current project utilities solve this cleanly?
- is the library maintained?
- does it fit iOS/iPhone constraints?
- does it increase binary size, launch time, or runtime cost significantly?
- is it accessible (Dynamic Type, VoiceOver) and testable?
- does it reduce complexity enough to justify adoption?

## Concurrency

- Prefer Swift `async`/`await`. Avoid Combine.
- Keep long-running or cancellable network work abortable so the UI cannot hang on slow mobile networks.
- Do main-actor UI updates on the main actor; keep pure computation off it where it matters.

## Clean code

- Prefer explicit names over clever compact code.
- Keep side effects isolated in `Services/`.
- Avoid broad rewrites.
- Prefer stable interfaces (protocols in `ServiceProtocols.swift`) between layers so logic and views are testable with fakes.
