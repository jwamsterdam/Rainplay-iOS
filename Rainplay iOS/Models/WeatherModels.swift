import Foundation

/// Core presentation-free data models. Display names and formatting live at the
/// presentation boundary (Views/Formatting).
enum WeatherKind: String, Codable {
    case rain
    case cloud
    case partly
    case sun
}

enum DayOption: String, CaseIterable, Identifiable {
    case vandaag = "Vandaag"
    case morgen = "Morgen"
    case overmorgen = "Overmorgen"
    case week = "Week"

    /// `rawValue` is the stable identity and storage key; the localized display
    /// title lives at the presentation boundary (`DayOption.titleKey`).
    var id: String { rawValue }
}

enum HorizonOption: String, CaseIterable, Identifiable {
    case heleDag = "Hele dag"
    case plus6 = "+6 uur"
    case plus2 = "+2 uur"

    var id: String { rawValue }
}

/// Preferred temperature unit for the UI. Canonical data stays in Celsius; this
/// applies only at the presentation boundary. `.system` derives the unit from the locale.
enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case system
    case celsius
    case fahrenheit

    var id: String { rawValue }
}

/// Preferred time notation for the UI. Canonical times stay as local ISO time
/// (`isoTime`); this applies only at the presentation boundary. `.system` follows
/// the device's 12/24-hour setting.
enum TimeFormat: String, Codable, CaseIterable, Identifiable {
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }
}

/// Preferred date notation for the UI. `.system` follows the locale ordering; the
/// explicit styles choose whether to include the weekday.
enum DateStyle: String, Codable, CaseIterable, Identifiable {
    case system
    case dayMonth
    case weekdayDayMonth

    var id: String { rawValue }
}

struct HourlyWeather: Equatable {
    /// Location-local time as delivered by Open-Meteo ("2026-07-09T14:00").
    /// Kept as a string so date filters can match on the string prefix.
    var isoTime: String
    /// Canonical 24-hour identity string ("14:00"), or a day key ("2026-07-09")
    /// in the week view. Serves as the stable chart axis category and day/hour
    /// grouping key — not for display. Views format from `isoTime` instead.
    var time: String
    var temperatureC: Double
    var score: Int
    var precipitationMm: Double
    var precipitationProbability: Double = 0
    var cloudCover: Double = 0
    var radiation: Double = 0
    var isDay: Bool = true
    var kind: WeatherKind = .cloud
    /// Unix timestamp (ms) of sunset on the same calendar day, for the civil
    /// twilight falloff in the sky gradient. Optional to keep test fixtures compact.
    var sunsetMs: Double? = nil
}

typealias ForecastPoint = HourlyWeather

enum LocationSource: String, Codable {
    /// Raw value stays "default" so already-stored locations keep decoding.
    case fallback = "default"
    case gps
    case manual
}

struct ForecastLocation: Codable, Equatable {
    var id: String?
    var name: String
    /// Only used to disambiguate search results — never shown in the header.
    var country: String?
    var latitude: Double
    var longitude: Double
    var source: LocationSource
    var updatedAt: Double?

    /// Stable key for lists and equality.
    var key: String { id ?? "\(name)-\(latitude)-\(longitude)" }

    static func isSame(_ a: ForecastLocation, _ b: ForecastLocation) -> Bool {
        if let aID = a.id, let bID = b.id { return aID == bID }
        return a.name == b.name && a.latitude == b.latitude && a.longitude == b.longitude
    }

    static let defaultLocation = ForecastLocation(
        id: "haarlem-default",
        name: "Haarlem",
        latitude: 52.3948,
        longitude: 4.6382,
        source: .fallback
    )
}

struct Forecast: Equatable {
    var currentTemperature: Int
    var hourly: [HourlyWeather]
    var minutely15: [ForecastPoint]
    /// Date ("yyyy-MM-dd") → time ("HH:mm").
    var sunriseTimes: [String: String]
    var sunsetTimes: [String: String]
}

// MARK: - Chart colors

struct RGBAColor: Codable, Equatable {
    var r: Int
    var g: Int
    var b: Int
    var a: Double

    var css: String {
        "rgba(\(r), \(g), \(b), \(Self.formatAlpha(a)))"
    }

    private static func formatAlpha(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        var text = String(format: "%.2f", rounded)
        if text.hasSuffix("0") { text.removeLast() }
        return text
    }
}

struct CellColors: Codable, Equatable {
    var sun: RGBAColor
    var partly: RGBAColor
    var cloud: RGBAColor
    var rain: RGBAColor
    var night: RGBAColor

    func color(for kind: WeatherKind) -> RGBAColor {
        switch kind {
        case .sun: return sun
        case .partly: return partly
        case .cloud: return cloud
        case .rain: return rain
        }
    }

    static let defaults = CellColors(
        sun: RGBAColor(r: 255, g: 196, b: 0, a: 0.33),
        partly: RGBAColor(r: 243, g: 204, b: 73, a: 0.15),
        cloud: RGBAColor(r: 88, g: 154, b: 253, a: 0.14),
        rain: RGBAColor(r: 139, g: 149, b: 156, a: 0.37),
        night: RGBAColor(r: 10, g: 10, b: 10, a: 0.6)
    )
}

// MARK: - Local ISO time

/// With `timezone=auto`, Open-Meteo delivers local times without a zone suffix.
/// These are interpreted in the device's time zone.
enum IsoTime {
    /// Manually parses "yyyy-MM-dd'T'HH:mm" using `Calendar.current` (a value type,
    /// so thread-safe). Deliberately avoids a shared `DateFormatter`, which is not
    /// thread-safe and slower. `nonisolated` so decoding can run off the main actor.
    nonisolated static func date(_ isoTime: String) -> Date {
        let halves = isoTime.split(separator: "T", maxSplits: 1)
        guard halves.count == 2 else { return .distantPast }
        let day = halves[0].split(separator: "-")
        let time = halves[1].split(separator: ":")
        guard day.count == 3, time.count >= 2,
              let year = Int(day[0]), let month = Int(day[1]), let dayOfMonth = Int(day[2]),
              let hour = Int(time[0]), let minute = Int(time[1]) else {
            return .distantPast
        }
        let components = DateComponents(year: year, month: month, day: dayOfMonth, hour: hour, minute: minute)
        return Calendar.current.date(from: components) ?? .distantPast
    }

    /// Unix timestamp in milliseconds.
    nonisolated static func ms(_ isoTime: String) -> Double {
        date(isoTime).timeIntervalSince1970 * 1000
    }

    /// Back to "yyyy-MM-dd'T'HH:mm" (for interpolated timestamps).
    nonisolated static func iso(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02dT%02d:%02d",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}
