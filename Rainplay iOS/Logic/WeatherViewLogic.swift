import Foundation

enum WeatherViewSettings {
    static let dayChartStartHour = 0
    static let dayChartEndHour = 24
    static let dayChartHourStep = 2
}

func visibleHoursForHorizon(_ hours: [HourlyWeather], _ horizon: HorizonOption) -> [HourlyWeather] {
    switch horizon {
    case .plus2: return Array(hours.prefix(3))
    case .plus6: return Array(hours.prefix(7))
    case .heleDag: return hours
    }
}

func visiblePointsForTodayHorizon(
    hourly: [HourlyWeather],
    minutely15: [ForecastPoint],
    horizon: HorizonOption,
    now: Date = Date()
) -> [ForecastPoint] {
    if horizon == .heleDag { return visibleHoursForHorizon(hoursForDay(hourly, .vandaag), horizon) }
    if minutely15.isEmpty { return visibleHoursForHorizon(hoursForDay(hourly, .vandaag), horizon) }

    let start = niceStartIndex(minutely15, now: now)

    // +6h: every 30 min (every other 15-min point) → 12 points.
    let plus6 = Array(minutely15.dropFirst(start).prefix(24))
        .enumerated()
        .filter { $0.offset % 2 == 0 }
        .map(\.element)

    if horizon == .plus6 { return plus6 }

    // +2h: the ~2-hour window resampled to the same point count as +6 (12) so the
    // chart can morph one-to-one when switching horizon or swiping.
    let plus2Window = Array(minutely15.dropFirst(start).prefix(8))
    return resampled(plus2Window, to: plus6.count)
}

/// Resamples a time series to `count` points spread evenly over time. Plotted
/// measurements (temp, precip, probability, cloud, radiation) are linearly
/// interpolated; categorical fields (kind, isDay, score, sunset) come from the
/// nearest source point.
func resampled(_ points: [ForecastPoint], to count: Int) -> [ForecastPoint] {
    guard points.count >= 2, count >= 2 else { return points }
    let times = points.map { IsoTime.ms($0.isoTime) }
    let startMs = times.first!
    let span = times.last! - startMs
    guard span > 0 else { return points }

    return (0..<count).map { i in
        let target = startMs + span * Double(i) / Double(count - 1)
        return interpolatedPoint(atMs: target, times: times, points: points)
    }
}

private func interpolatedPoint(atMs target: Double, times: [Double], points: [ForecastPoint]) -> ForecastPoint {
    var hi = times.firstIndex(where: { $0 >= target }) ?? times.count - 1
    if hi == 0 { hi = 1 }
    let lo = hi - 1
    let bracket = times[hi] - times[lo]
    let f = bracket > 0 ? (target - times[lo]) / bracket : 0
    let a = points[lo]
    let b = points[hi]
    func lerp(_ x: Double, _ y: Double) -> Double { x + (y - x) * f }
    let nearest = f < 0.5 ? a : b
    let iso = IsoTime.iso(from: Date(timeIntervalSince1970: target / 1000))

    return ForecastPoint(
        isoTime: iso,
        time: String(iso.suffix(5)),
        temperatureC: lerp(a.temperatureC, b.temperatureC),
        score: nearest.score,
        precipitationMm: lerp(a.precipitationMm, b.precipitationMm),
        precipitationProbability: lerp(a.precipitationProbability, b.precipitationProbability),
        cloudCover: lerp(a.cloudCover, b.cloudCover),
        radiation: lerp(a.radiation, b.radiation),
        isDay: nearest.isDay,
        kind: nearest.kind,
        sunsetMs: nearest.sunsetMs
    )
}

/// Finds the last :00/:30 point at or before now, so the window always starts in
/// the recent past and the now-line falls inside the chart rather than pinned to
/// the left edge. Points are chronological, so we scan forward and keep the
/// highest match. Falls back to index 0 (current quarter) when no :00/:30 lies at
/// or before now, e.g. data starting in a :15/:45 period.
///
/// Compares on isoTime (including date) so data crossing midnight (e.g. 23:45 →
/// 00:00 next day) does not disturb the :00/:30 minute check.
private func niceStartIndex(_ points: [ForecastPoint], now: Date) -> Int {
    let nowMs = now.timeIntervalSince1970 * 1000
    var last = -1
    for (i, point) in points.enumerated() {
        let minute = Calendar.current.component(.minute, from: IsoTime.date(point.isoTime))
        guard minute == 0 || minute == 30 else { continue }
        if IsoTime.ms(point.isoTime) > nowMs { break }
        last = i
    }
    return last != -1 ? last : 0
}

func visibleHoursForSelection(
    _ hours: [HourlyWeather],
    day: DayOption,
    horizon: HorizonOption
) -> [HourlyWeather] {
    let dayHours = hoursForDay(hours, day)
    if day != .vandaag { return dayHours }

    return visibleHoursForHorizon(dayHours, horizon)
}

/// Single source of truth for which points the screen shows for a given
/// day/horizon. Both the header (WeatherScreen) and each carousel panel
/// (DayCarousel) read from this, so there are not two slightly different
/// pipelines. `now` is injected rather than read internally via Date().
func visiblePoints(
    forecast: Forecast?,
    day: DayOption,
    horizon: HorizonOption,
    now: Date
) -> [ForecastPoint] {
    let hourly = forecast?.hourly ?? []
    if day == .vandaag {
        return visiblePointsForTodayHorizon(
            hourly: hourly,
            minutely15: forecast?.minutely15 ?? [],
            horizon: horizon,
            now: now
        )
    }
    return visibleHoursForSelection(hourly, day: day, horizon: horizon)
}

func averageTemperature(_ hours: [HourlyWeather]) -> Int? {
    guard !hours.isEmpty else { return nil }
    return Int(average(hours.map(\.temperatureC)).rounded())
}

/// Header date for the selected day: a single date, or a week range. The view
/// formats this via TimeFormatting (locale-aware) rather than a pre-rendered
/// string. `.none` means no data.
enum HeaderDate: Equatable {
    case none
    case single(Date)
    case range(Date, Date)
}

func headerDate(_ hours: [HourlyWeather], day: DayOption) -> HeaderDate {
    if day == .week {
        guard let first = hours.first.map({ String($0.isoTime.prefix(10)) }),
              let last = hours.last.map({ String($0.isoTime.prefix(10)) }) else {
            return .none
        }
        return .range(IsoTime.date("\(first)T12:00"), IsoTime.date("\(last)T12:00"))
    }

    guard let targetDate = dateForDayOption(hours, day) else { return .none }

    return .single(IsoTime.date("\(targetDate)T12:00"))
}

func hoursForDay(_ hours: [HourlyWeather], _ day: DayOption) -> [HourlyWeather] {
    if day == .week { return weekDaySummaries(hours) }

    guard let targetDate = dateForDayOption(hours, day) else { return hours }

    return configuredDayHours(hours.filter { $0.isoTime.hasPrefix(targetDate) })
}

private func dateForDayOption(_ hours: [HourlyWeather], _ day: DayOption) -> String? {
    guard day != .week, let firstDate = hours.first.map({ String($0.isoTime.prefix(10)) }) else {
        return nil
    }

    let parts = firstDate.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }

    let calendar = Calendar.current
    let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
    guard let base = calendar.date(from: components) else { return nil }

    let offset: Int
    switch day {
    case .morgen: offset = 1
    case .overmorgen: offset = 2
    default: offset = 0
    }
    guard let date = calendar.date(byAdding: .day, value: offset, to: base) else { return nil }

    let result = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = result.year, let month = result.month, let dayOfMonth = result.day else {
        return nil
    }
    return String(format: "%04d-%02d-%02d", year, month, dayOfMonth)
}

private func configuredDayHours(_ hours: [HourlyWeather]) -> [HourlyWeather] {
    let startHour = WeatherViewSettings.dayChartStartHour
    let endHour = WeatherViewSettings.dayChartEndHour
    let hourStep = WeatherViewSettings.dayChartHourStep

    return hours.filter { hour in
        let numericHour = Calendar.current.component(.hour, from: IsoTime.date(hour.isoTime))
        let inRange = endHour >= 24
            ? numericHour >= startHour && numericHour < 24
            : numericHour >= startHour && numericHour <= endHour
        let matchesStep = (numericHour - startHour) % hourStep == 0

        return inRange && matchesStep
    }
}

private func weekDaySummaries(_ hours: [HourlyWeather]) -> [HourlyWeather] {
    // Group by date while preserving order.
    var order: [String] = []
    var groups: [String: [HourlyWeather]] = [:]

    for hour in configuredDayHours(hours) {
        let date = String(hour.isoTime.prefix(10))
        if groups[date] == nil { order.append(date) }
        groups[date, default: []].append(hour)
    }

    return order.prefix(7).map { summarizeDay($0, groups[$0] ?? []) }
}

private func summarizeDay(_ date: String, _ dayHours: [HourlyWeather]) -> HourlyWeather {
    let bestHour = dayHours.reduce(dayHours[0]) { best, hour in hour.score > best.score ? hour : best }
    let precipitationSum = dayHours.reduce(0.0) { $0 + $1.precipitationMm }
    let averageCloudCover = average(dayHours.map(\.cloudCover))
    let averageRadiation = average(dayHours.map(\.radiation))
    let daytimeHours = dayHours.filter(\.isDay).count
    let rainyHours = dayHours.filter { $0.kind == .rain }.count
    let sunnyHours = dayHours.filter { $0.kind == .sun }.count
    let partlyHours = dayHours.filter { $0.kind == .partly }.count

    var summary = bestHour
    summary.isoTime = "\(date)T12:00"
    // Identity `time` is the day key: unique per day and a stable chart-axis
    // category. The view formats the weekday locale-aware from isoTime.
    summary.time = date
    summary.temperatureC = average(dayHours.map(\.temperatureC)).rounded()
    summary.score = Int(average(dayHours.map { Double($0.score) }).rounded())
    summary.precipitationMm = min(3, precipitationSum)
    summary.precipitationProbability = dayHours.map(\.precipitationProbability).max() ?? 0
    summary.cloudCover = averageCloudCover
    summary.radiation = averageRadiation
    summary.isDay = Double(daytimeHours) >= Double(dayHours.count) / 2
    summary.kind = dominantKind(rainyHours: rainyHours, sunnyHours: sunnyHours, partlyHours: partlyHours)
    return summary
}

/// Picks the day icon from the per-kind hour counts, in priority order.
private func dominantKind(rainyHours: Int, sunnyHours: Int, partlyHours: Int) -> WeatherKind {
    if rainyHours >= 3 { return .rain }
    if sunnyHours >= partlyHours && sunnyHours > 0 { return .sun }
    if partlyHours > 0 { return .partly }
    return .cloud
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}
