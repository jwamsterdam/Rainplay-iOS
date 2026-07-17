import Foundation

/// Derived header info for the main screen, computed once from the forecast and
/// selection instead of scattered (and repeated) across the view. Gives a single
/// source of truth for temperature, best window and advice text, and keeps
/// bestOutdoorWindow from running three times per render.
struct DecisionSummary: Equatable {
    var temperature: Int?
    /// Header date and best start; the view formats these via TimeFormatting per
    /// the chosen time/date notation. `bestStart` is nil when there is no clear
    /// outdoor moment (the view then shows no "outside from …").
    var headerDate: HeaderDate
    var bestStart: Date?
    /// Presentation-free token; the view maps it to localized text.
    var summary: OutdoorSummary
}

func decisionSummary(
    forecast: Forecast?,
    day: DayOption,
    horizon: HorizonOption,
    now: Date
) -> DecisionSummary {
    let hours = visiblePoints(forecast: forecast, day: day, horizon: horizon, now: now)
    let window = bestOutdoorWindow(hours)

    // Today shows the live current temperature; other days the daily average.
    // nil means no data yet, so the view shows a placeholder rather than a
    // plausible-looking but invented number.
    let temperature: Int?
    if day == .vandaag {
        temperature = forecast?.currentTemperature
    } else {
        temperature = averageTemperature(hours) ?? forecast?.currentTemperature
    }

    return DecisionSummary(
        temperature: temperature,
        headerDate: headerDate(forecast?.hourly ?? [], day: day),
        bestStart: window?.start,
        summary: outdoorSummary(hours, bestWindow: window)
    )
}
