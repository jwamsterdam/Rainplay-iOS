import Foundation

/// Canonical start/end of a window. `start` is always the begin time; `end` is
/// nil for week summaries (which have no time within the day). Views format
/// these via TimeFormatting; the logic never reads a pre-rendered time string.
struct OutdoorWindow: Equatable {
    var startIndex: Int
    var endIndex: Int
    var start: Date
    var end: Date?
}

/// Presentation-free day-period token; the view maps it to localized text (see
/// OutdoorSummary+Localized) so the logic never assembles sentences.
enum DayPeriod: Equatable {
    case morning
    case afternoon
    case evening
}

/// Presentation-free token for the nuance line under the verdict: names the best
/// day period and whether rain falls before/after the window. The view maps it
/// to a single localized sentence (including the period word).
enum OutdoorSummary: Equatable {
    case none
    case clear(period: DayPeriod)
    case afterRain(period: DayPeriod)
    case clearThenRain(period: DayPeriod)
    case betweenShowers(period: DayPeriod)
}

/// Nuance line under the verdict: names the best day period and warns about rain
/// before or after the window.
func outdoorSummary(_ hours: [HourlyWeather], bestWindow: OutdoorWindow?) -> OutdoorSummary {
    guard let bestWindow else { return .none }

    let period = dayPeriod(bestWindow.start)
    let rainBefore = hours.prefix(bestWindow.startIndex).contains(where: hasMeaningfulRain)
    let rainAfter = hours.dropFirst(bestWindow.endIndex + 1).contains(where: hasMeaningfulRain)

    if rainBefore && rainAfter { return .betweenShowers(period: period) }
    if rainBefore { return .afterRain(period: period) }
    if rainAfter { return .clearThenRain(period: period) }

    return .clear(period: period)
}

func bestOutdoorWindow(_ hours: [HourlyWeather]) -> OutdoorWindow? {
    guard !hours.isEmpty else { return nil }

    let bestScore = hours.map(\.score).max() ?? 0
    let minimumGoodScore = max(7, bestScore - 1)
    let dryLimitMm = 0.2
    let maxRainProbability = 60.0
    func hasNoMeasuredRain(_ hour: HourlyWeather) -> Bool {
        hour.precipitationMm <= dryLimitMm && hour.kind != .rain
    }
    func isDry(_ hour: HourlyWeather) -> Bool {
        hasNoMeasuredRain(hour) && hour.precipitationProbability <= maxRainProbability
    }
    func isPracticalOutdoorHour(_ hour: HourlyWeather) -> Bool {
        let hourOfDay = hourOfDayFor(hour)
        return hourOfDay >= 6 && hourOfDay < 20
    }
    func feelsBright(_ hour: HourlyWeather) -> Bool {
        (hour.kind == .sun || hour.kind == .partly)
            && hour.radiation >= 80
            && isPracticalOutdoorHour(hour)
    }

    let brightWindows = contiguousWindows(hours) { hour in
        hour.isDay && hour.score >= 7 && hasNoMeasuredRain(hour) && feelsBright(hour)
    }
    let practicalPreferredWindows = contiguousWindows(hours) { hour in
        hour.isDay && hour.score >= 7 && hasNoMeasuredRain(hour) && isPracticalOutdoorHour(hour)
    }
    let preferredWindows = contiguousWindows(hours) { hour in
        hour.isDay && hour.score >= minimumGoodScore && isDry(hour)
    }
    // Int.min acts as -infinity: if every hour is rain, the fallback predicate
    // matches nothing and the chain falls through to score-only.
    let bestNonRainScore = hours.filter { $0.kind != .rain }.map(\.score).max() ?? Int.min
    let fallbackWindows = contiguousWindows(hours) { hour in
        hour.score >= bestNonRainScore && hour.kind != .rain
    }
    let scoreOnlyWindows = contiguousWindows(hours) { hour in hour.score >= bestScore }

    // Pick the first non-empty candidate list in priority order; fall back to
    // score-only when all preferred lists are empty.
    let windows = [brightWindows, practicalPreferredWindows, preferredWindows, fallbackWindows]
        .first { !$0.isEmpty } ?? scoreOnlyWindows

    guard let first = windows.first else { return nil }

    return windows.dropFirst().reduce(first) { best, current in
        let bestLength = best.endIndex - best.startIndex
        let currentLength = current.endIndex - current.startIndex
        let bestAverage = averageScore(hours, best)
        let currentAverage = averageScore(hours, current)

        if currentLength > bestLength { return current }
        if currentLength == bestLength && currentAverage > bestAverage { return current }
        return best
    }
}

private func contiguousWindows(
    _ hours: [HourlyWeather],
    _ predicate: (HourlyWeather) -> Bool
) -> [OutdoorWindow] {
    var windows: [OutdoorWindow] = []
    var startIndex: Int?

    for index in hours.indices {
        if predicate(hours[index]) {
            if startIndex == nil { startIndex = index }
            continue
        }

        if let start = startIndex {
            windows.append(windowFromIndexes(hours, start, index - 1))
            startIndex = nil
        }
    }

    if let start = startIndex {
        windows.append(windowFromIndexes(hours, start, hours.count - 1))
    }

    return windows
}

private func windowFromIndexes(_ hours: [HourlyWeather], _ startIndex: Int, _ endIndex: Int) -> OutdoorWindow {
    OutdoorWindow(
        startIndex: startIndex,
        endIndex: endIndex,
        start: IsoTime.date(hours[startIndex].isoTime),
        end: endDateForWindow(hours, endIndex)
    )
}

/// Window end time as a Date. Week summaries use day keys with no time within
/// the day, so there is no intra-day end time and this returns nil.
private func endDateForWindow(_ hours: [HourlyWeather], _ endIndex: Int) -> Date? {
    if endIndex + 1 < hours.count { return IsoTime.date(hours[endIndex + 1].isoTime) }

    // Week view: the identity `time` is a day key without ":".
    if !hours[endIndex].time.contains(":") { return nil }

    let stepMs = inferStepMs(hours.map { IsoTime.ms($0.isoTime) })
    return IsoTime.date(hours[endIndex].isoTime).addingTimeInterval(stepMs / 1000)
}

private func hourOfDayFor(_ hour: HourlyWeather) -> Int {
    Calendar.current.component(.hour, from: IsoTime.date(hour.isoTime))
}

private func inferStepMs(_ times: [Double]) -> Double {
    var minDiff = 60.0 * 60 * 1000
    for i in times.indices.dropFirst() {
        let diff = times[i] - times[i - 1]
        if diff > 0 { minDiff = min(minDiff, diff) }
    }
    return minDiff
}

private func averageScore(_ hours: [HourlyWeather], _ window: OutdoorWindow) -> Double {
    let windowHours = hours[window.startIndex...window.endIndex]
    return windowHours.reduce(0.0) { $0 + Double($1.score) } / Double(windowHours.count)
}

private func hasMeaningfulRain(_ hour: HourlyWeather) -> Bool {
    hour.kind == .rain || hour.precipitationMm >= 0.2
}

private func dayPeriod(_ start: Date) -> DayPeriod {
    let hour = Calendar.current.component(.hour, from: start)
    if hour < 12 { return .morning }
    if hour < 18 { return .afternoon }
    return .evening
}
