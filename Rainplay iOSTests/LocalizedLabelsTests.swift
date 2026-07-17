import Foundation
@testable import Rainplay_iOS
import Testing

// Bewaakt dat elke presentatie-token een echte (opgeloste) vertaling heeft in de
// String Catalog: als een key ontbreekt geeft String(localized:) de ruwe key
// terug (bijv. "weather.rain"), en dan faalt de assertie.
struct LocalizedLabelsTests {
    @Test func weatherKindsResolveToRealText() {
        for kind in [WeatherKind.rain, .cloud, .partly, .sun] {
            let text = kind.localizedText
            #expect(!text.isEmpty)
            #expect(!text.contains("weather."))
        }
    }

    @Test func dayPeriodsResolveToRealText() {
        for period in [DayPeriod.morning, .afternoon, .evening] {
            let text = period.localizedText
            #expect(!text.isEmpty)
            #expect(!text.contains("period."))
        }
    }

    @Test func weekSummaryKeysResolveToRealText() {
        let keys: [String.LocalizationValue] = [
            "summary.week.clear", "summary.week.afterRain", "summary.week.clearThenRain",
            "summary.week.betweenShowers", "summary.week.none",
        ]
        for key in keys {
            let text = String(localized: key)
            #expect(!text.isEmpty)
            #expect(!text.contains("summary.week."))
        }
    }
}
