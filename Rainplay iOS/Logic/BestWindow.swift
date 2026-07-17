import Foundation

// Beste-buitenmoment-logica, 1:1 geport uit de PWA (src/lib/chart.ts).

// Canonieke start/eind van het venster. `start` is altijd het begintijdstip;
// `end` is nil voor week-samenvattingen (die hebben geen tijd binnen de dag).
// Views formatteren deze via TimeFormatting; de logica leest nooit een
// vooraf gerenderde tijdstring.
struct OutdoorWindow: Equatable {
    var startIndex: Int
    var endIndex: Int
    var start: Date
    var end: Date?
}

// Nuance-regel onder het verdict: benoemt de beste dagperiode en waarschuwt voor
// regen vóór of ná het venster.
func outdoorSummaryLabel(_ hours: [HourlyWeather], bestWindow: OutdoorWindow?) -> String {
    guard let bestWindow else { return "Geen duidelijk buitenmoment" }

    let period = dayPeriodLabel(bestWindow.start)
    let rainBefore = hours.prefix(bestWindow.startIndex).contains(where: hasMeaningfulRain)
    let rainAfter = hours.dropFirst(bestWindow.endIndex + 1).contains(where: hasMeaningfulRain)

    if rainBefore && rainAfter { return "Tussen buien door - \(period) beste" }
    if rainBefore { return "Na regen - \(period) beste" }
    if rainAfter { return "\(capitalize(period)) beste - later regen" }

    return "\(capitalize(period)) beste buitenmoment"
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
    // Int.min speelt de rol van -Infinity in de PWA: zijn álle uren regen, dan
    // matcht het fallback-predicaat niets en valt de keten door naar score-only.
    let bestNonRainScore = hours.filter { $0.kind != .rain }.map(\.score).max() ?? Int.min
    let fallbackWindows = contiguousWindows(hours) { hour in
        hour.score >= bestNonRainScore && hour.kind != .rain
    }
    let scoreOnlyWindows = contiguousWindows(hours) { hour in hour.score >= bestScore }

    // Kies de eerste niet-lege kandidatenlijst in prioriteitsvolgorde; valt
    // terug op score-only als alle voorkeurslijsten leeg zijn.
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

// Canonieke eindtijd van het venster als Date. Bij week-samenvattingen (dag-
// sleutels zonder tijd binnen de dag) is er geen intra-day eindtijd → nil.
private func endDateForWindow(_ hours: [HourlyWeather], _ endIndex: Int) -> Date? {
    if endIndex + 1 < hours.count { return IsoTime.date(hours[endIndex + 1].isoTime) }

    // Week-weergave: de identiteits-`time` is een dagsleutel zonder ":".
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

private func dayPeriodLabel(_ start: Date) -> String {
    let hour = Calendar.current.component(.hour, from: start)
    if hour < 12 { return "ochtend" }
    if hour < 18 { return "middag" }
    return "avond"
}

private func capitalize(_ value: String) -> String {
    guard let first = value.first else { return value }
    return String(first).uppercased() + value.dropFirst()
}
