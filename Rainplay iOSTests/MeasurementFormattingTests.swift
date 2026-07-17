import Foundation
@testable import Rainplay_iOS
import Testing

/// Pure temperature presentation helpers: C→F conversion, rounding, and locale
/// resolution for `.system`. Locale is injected so the tests don't depend on the device.
struct MeasurementFormattingTests {
    private let us = Locale(identifier: "en_US")
    private let nl = Locale(identifier: "nl_NL")

    // MARK: - Explicit units

    @Test func celsiusPassesThroughUnchanged() {
        #expect(temperatureValue(celsius: 21.0, unit: .celsius, locale: us) == 21)
        #expect(temperatureString(celsius: 21.0, unit: .celsius, locale: us) == "21°")
    }

    @Test func fahrenheitConvertsAndRounds() {
        #expect(temperatureValue(celsius: 0.0, unit: .fahrenheit, locale: nl) == 32)
        #expect(temperatureValue(celsius: 20.0, unit: .fahrenheit, locale: nl) == 68)
        // 21°C = 69.8°F → rounds to 70°.
        #expect(temperatureString(celsius: 21.0, unit: .fahrenheit, locale: nl) == "70°")
    }

    /// -40 is the point where both scales meet.
    @Test func negativeCelsiusToFahrenheit() {
        #expect(temperatureValue(celsius: -40.0, unit: .fahrenheit, locale: us) == -40)
    }

    // MARK: - .system resolved via locale

    @Test func systemResolvesToFahrenheitInUS() {
        #expect(usesFahrenheit(.system, locale: us))
        #expect(temperatureString(celsius: 21.0, unit: .system, locale: us) == "70°")
    }

    @Test func systemResolvesToCelsiusInNL() {
        #expect(!usesFahrenheit(.system, locale: nl))
        #expect(temperatureString(celsius: 21.0, unit: .system, locale: nl) == "21°")
    }

    // MARK: - Int overload (DecisionSummary yields a rounded Celsius Int)

    @Test func intOverloadMatchesDoubleOverload() {
        #expect(temperatureString(celsius: 20, unit: .fahrenheit, locale: nl) == "68°")
        #expect(temperatureString(celsius: 20, unit: .celsius, locale: nl) == "20°")
    }
}
