import Foundation
@testable import Rainplay_iOS
import Testing

/// Guards that every presentation token has a real (resolved) translation in the
/// String Catalog: when a key is missing, String(localized:) returns the raw key
/// (e.g. "weather.rain") and the assertion fails.
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
