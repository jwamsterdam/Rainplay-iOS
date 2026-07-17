import Foundation

// Kern-datamodellen, 1:1 geport uit de Rainplay PWA (src/types.ts,
// src/api/openMeteo.ts en src/components/cellColors.ts).

enum WeatherKind: String, Codable {
    case rain
    case cloud
    case partly
    case sun

    // Nederlandse naam voor VoiceOver-labels e.d.
    var displayName: String {
        switch self {
        case .rain: return "Regen"
        case .cloud: return "Bewolkt"
        case .partly: return "Zon met bewolking"
        case .sun: return "Zon"
        }
    }
}

enum DayOption: String, CaseIterable, Identifiable {
    case vandaag = "Vandaag"
    case morgen = "Morgen"
    case overmorgen = "Overmorgen"
    case week = "Week"

    var id: String { rawValue }

    // De dag-selector kort "Overmorgen" af tot "Overm.", zoals de PWA.
    var displayLabel: String { self == .overmorgen ? "Overm." : rawValue }
}

enum HorizonOption: String, CaseIterable, Identifiable {
    case heleDag = "Hele dag"
    case plus6 = "+6 uur"
    case plus2 = "+2 uur"

    var id: String { rawValue }
}

// Voorkeur voor de temperatuureenheid in de UI. Canonieke data blijft altijd
// Celsius; deze keuze werkt alleen op de presentatiegrens (zie
// MeasurementFormatting). `.system` leidt de eenheid af uit de locale.
enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case system
    case celsius
    case fahrenheit

    var id: String { rawValue }
}

// Voorkeur voor de tijdnotatie in de UI. Canonieke tijden blijven altijd de
// lokale ISO-tijd (isoTime); deze keuze werkt alleen op de presentatiegrens
// (zie TimeFormatting). `.system` volgt de 12/24-uurs-instelling van het apparaat.
enum TimeFormat: String, Codable, CaseIterable, Identifiable {
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }
}

// Voorkeur voor de datumnotatie in de UI. `.system` volgt de locale-volgorde;
// de expliciete stijlen kiezen tussen wel/geen weekdag. Zie TimeFormatting.
enum DateStyle: String, Codable, CaseIterable, Identifiable {
    case system
    case dayMonth
    case weekdayDayMonth

    var id: String { rawValue }
}

struct HourlyWeather: Equatable {
    // Lokale tijd van de locatie zoals Open-Meteo die levert ("2026-07-09T14:00").
    // Bewust een string (net als de PWA) zodat datumfilters op stringprefix werken.
    var isoTime: String
    // Canonieke 24-uurs identiteitsstring ("14:00"), of een dagsleutel
    // ("2026-07-09") in de week-weergave. Dient als stabiele grafiek-as-categorie
    // en dag/uur-groepering — NIET om aan de gebruiker te tonen. Voor weergave
    // formatteren views op basis van isoTime via TimeFormatting.
    var time: String
    var temperatureC: Double
    var score: Int
    var precipitationMm: Double
    // Defaults op de properties zelf, zodat de gesynthetiseerde memberwise-init
    // deze velden optioneel maakt zonder een handgeschreven initializer.
    var precipitationProbability: Double = 0
    var cloudCover: Double = 0
    var radiation: Double = 0
    var isDay: Bool = true
    var kind: WeatherKind = .cloud
    // Unix-timestamp (ms) van zonsondergang op dezelfde kalenderdag, voor de
    // civiele-schemering-falloff in de lucht-gradient. Optioneel zodat
    // testfixtures compact blijven.
    var sunsetMs: Double? = nil
}

typealias ForecastPoint = HourlyWeather

enum LocationSource: String, Codable {
    // Raw value blijft "default" zodat reeds opgeslagen locaties blijven decoderen.
    case fallback = "default"
    case gps
    case manual
}

struct ForecastLocation: Codable, Equatable {
    var id: String?
    var name: String
    // Alleen gebruikt om zoekresultaten te onderscheiden — nooit in de header.
    var country: String?
    var latitude: Double
    var longitude: Double
    var source: LocationSource
    var updatedAt: Double?

    // Stabiele sleutel voor lijsten en gelijkheid, zoals locationKey() in de PWA.
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
    // datum ("yyyy-MM-dd") → tijd ("HH:mm")
    var sunriseTimes: [String: String]
    var sunsetTimes: [String: String]
}

// MARK: - Grafiekkleuren

struct RGBAColor: Codable, Equatable {
    var r: Int
    var g: Int
    var b: Int
    var a: Double

    // Weergave zoals de PWA: "rgba(255, 196, 0, 0.33)".
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

// MARK: - Lokale ISO-tijd

// Open-Meteo levert met timezone=auto lokale tijden zonder zone-suffix.
// Net als `new Date(isoTime)` in de PWA interpreteren we die in de
// tijdzone van het apparaat.
enum IsoTime {
    // Handmatige parse van "yyyy-MM-dd'T'HH:mm" met Calendar.current (een
    // waardetype, dus thread-safe). Bewust géén gedeelde DateFormatter: die is
    // niet thread-safe (blokkeert veilig off-main draaien) en trager. nonisolated
    // zodat de decode buiten de main actor kan lopen.
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

    // Unix-timestamp in milliseconden, zodat geporte JS-berekeningen
    // (getTime()-semantiek) letterlijk overgenomen kunnen worden.
    nonisolated static func ms(_ isoTime: String) -> Double {
        date(isoTime).timeIntervalSince1970 * 1000
    }

    // Terug naar "yyyy-MM-dd'T'HH:mm" (voor geïnterpoleerde tijdstippen).
    nonisolated static func iso(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02dT%02d:%02d",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}
