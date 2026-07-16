# Lessons Learned

Carried over from the Rainplay PWA project and reframed for the native SwiftUI
app. React/PWA-specific lessons (jsdom mocking, Recharts, CSS viewport fill)
were dropped as they no longer apply; the architectural lessons below transfer
directly and remain binding.

## Accepted lessons
These are binding project rules.

### Keep chart state outside visual components
When adding chart interactions, keep visibility/filter/selection state in
`AppModel` or a screen-level parent. Chart views should receive derived values
and not own cross-widget state.

### Derived domain logic belongs in Logic/, not in presentation views
Score formulas, best-window calculations, chart geometry, and other decision
logic must live in `Logic/`, never recomputed inside a chart or UI view. A view
that re-derives a score creates a silent second source of truth that can diverge
from the one driving hero copy and advice text. When a view needs a derived
value, pass it in or read it from the normalized data layer.

### Chart/marker decision logic must be pure, clock-injected, and unit-tested
Any chart decision logic that depends on time or on point geometry (marker
position, best-window, band math) must be a pure function in `Logic/` with
`now: Date` injected — never `Date()` inside — returning a presentation-agnostic
value (e.g. a [0,1] fraction). The view only projects that value to points.
Then the clamp/band-centre/off-by-one behavior is unit-tested at the right
altitude (see `Logic/NowMarker.swift` + `NowMarkerTests`). Watch clamp
boundaries: assert the renderable contract (non-null, in range), not an
over-specified exact value.

## Candidate lessons
These are proposals. Do not treat them as binding until accepted.

_None yet. When a recurring iOS/SwiftUI issue is found, propose it here with a
short status note (e.g. "Status: pending review") before promoting it above._

## Rejected or superseded lessons
Keep short notes here when an earlier lesson is no longer valid.
