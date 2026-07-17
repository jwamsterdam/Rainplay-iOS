import Foundation

/// Horizontal position of `now` as a fraction in [0,1] across the plot, using the
/// band-center model: the center of point i sits at (i + 0.5)/n (the same model as
/// the sky gradient, see SkyGradient.swift). The view projects this to pixels:
/// x = plotX + fraction * plotWidth.
///
/// Interpolates in time between the two enclosing points, so the result is
/// ((i + 0.5) + t)/n where t is the time fraction between point i and i+1.
///
/// The result is clamped to [0,1]: if `now` falls before the first point (e.g. a
/// +2/+6-hour window starting just after now) it pins to the left edge; after the
/// last point it pins to the right edge.
///
/// Returns nil only for degenerate input (fewer than 2 points, nothing to
/// interpolate); the caller then renders nothing.
///
/// Compares on full isoTime (date + time) so windows crossing midnight (e.g.
/// +6h: 23:00 → 04:30 next day) work correctly. A bare minutes-since-midnight
/// comparison breaks here because 0:00 sorts before 23:00, jumping the marker to
/// the right edge at midnight.
func nowFraction(isoTimes: [String], now: Date) -> Double? {
    let n = isoTimes.count
    guard n >= 2 else { return nil }

    let nowMs = now.timeIntervalSince1970 * 1000
    let timestamps = isoTimes.map { IsoTime.ms($0) }

    // Find the last bracket i where timestamps[i] <= nowMs. timestamps is
    // monotonically increasing (midnight-safe via isoTime dates).
    var i = 0
    while i < n - 2 && timestamps[i + 1] <= nowMs { i += 1 }
    var span = timestamps[i + 1] - timestamps[i]
    if span == 0 { span = 1 }
    let t = (nowMs - timestamps[i]) / span

    let fraction = (Double(i) + 0.5 + t) / Double(n)
    return min(1, max(0, fraction))
}
