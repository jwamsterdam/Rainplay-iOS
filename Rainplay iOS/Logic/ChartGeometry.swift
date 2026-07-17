import Foundation

/// Pure chart geometry: the dual-axis normalization that fits the temperature
/// line onto the same y-scale as the rain bars. Split out from the DayChart view
/// so the math (bounds, ticks, inverse mapping) is testable on its own.
struct ChartGeometry: Equatable {
    /// Top of the rain axis (mm). At least 3 mm so 1 mm never looks like "a lot",
    /// but grows once precipitation exceeds it so bars never overshoot the chart.
    let rainMax: Double
    let tempMin: Double
    let tempMax: Double

    /// Fixed lower bound of the rain axis.
    static let minimumRainMax: Double = 3

    /// Margin (mm) added above the tallest bar before rounding up, so a bar never
    /// touches the top edge (e.g. a week peak of exactly 3 mm yields an axis of 4).
    static let rainHeadroomMm: Double = 0.5

    /// Builds geometry from an explicit temperature range plus precipitation peak,
    /// so one shared geometry can span all day panels and keep charts comparable
    /// while swiping.
    ///
    /// Temp margins: lower bound rounded down to even degrees for tidy ticks; upper
    /// bound a tight ~1° (not rounded to even, which added up to ~3° of slack) so
    /// the line sits near the top and a warm day reads as genuinely high.
    init(temperatureRange range: ClosedRange<Double>?, precipitationMax: Double?) {
        rainMax = max(Self.minimumRainMax, ((precipitationMax ?? 0) + Self.rainHeadroomMm).rounded(.up))

        guard let range else {
            tempMin = 0
            tempMax = 20
            return
        }
        let lo = ((range.lowerBound - 1) / 2).rounded(.down) * 2
        let hi = (range.upperBound + 1).rounded(.up)
        tempMin = lo >= hi ? hi - 2 : lo         // flat series still yields a range
        tempMax = hi
    }

    /// Convenience: one chart from its own hours.
    init(hours: [HourlyWeather]) {
        self.init(
            temperatureRange: ChartGeometry.temperatureRange(in: hours),
            precipitationMax: ChartGeometry.precipitationMax(in: hours)
        )
    }

    // MARK: - Measured ranges

    static func temperatureRange(in hours: [HourlyWeather]) -> ClosedRange<Double>? {
        temperatureRange(across: [hours])
    }

    /// Combined temperature range across multiple hour sets (shared axis).
    static func temperatureRange(across groups: [[HourlyWeather]]) -> ClosedRange<Double>? {
        let temps = groups.flatMap { $0.map(\.temperatureC) }
        guard let lo = temps.min(), let hi = temps.max() else { return nil }
        return lo...hi
    }

    static func precipitationMax(in hours: [HourlyWeather]) -> Double? {
        precipitationMax(across: [hours])
    }

    /// Highest precipitation across multiple hour sets (shared axis).
    static func precipitationMax(across groups: [[HourlyWeather]]) -> Double? {
        groups.flatMap { $0.map(\.precipitationMm) }.max()
    }

    // MARK: - Temperature (right axis)

    /// Maps °C to a position on the rain domain (0...rainMax).
    func normalizedTemp(_ celsius: Double) -> Double {
        guard tempMax > tempMin else { return 0 }
        return (celsius - tempMin) / (tempMax - tempMin) * rainMax
    }

    /// Even steps from tempMin, always including tempMax so the highest
    /// temperature is visible. A tick just below the top is dropped to avoid
    /// overlapping labels.
    var tempTicks: [Double] {
        let step = max(2, ((tempMax - tempMin) / 4 / 2).rounded() * 2)
        var ticks = Array(stride(from: tempMin, to: tempMax, by: step))
        if let last = ticks.last, tempMax - last < 2 { ticks.removeLast() }
        ticks.append(tempMax)
        return ticks
    }

    /// Inverse mapping: a position on the rain domain back to rounded °C for the
    /// right-axis label.
    func temperature(atNormalized position: Double) -> Int {
        Int((tempMin + position / rainMax * (tempMax - tempMin)).rounded())
    }

    // MARK: - Precipitation (left axis)

    /// Tick values for the rain axis: 0..rainMax in tidy whole steps.
    var rainTicks: [Double] {
        let step = max(1, (rainMax / 3).rounded(.up))
        return Array(stride(from: 0, through: rainMax, by: step))
    }
}
