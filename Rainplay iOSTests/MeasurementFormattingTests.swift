import Foundation
@testable import Rainplay_iOS
import Testing

// De pure temperatuur-presentatiehelpers: C→F conversie, afronding en
// locale-resolutie voor `.system`. Locale wordt geïnjecteerd zodat de tests
// niet van het apparaat afhangen.
struct MeasurementFormattingTests {
    private let us = Locale(identifier: "en_US")
    private let nl = Locale(identifier: "nl_NL")

    // MARK: - Expliciete eenheden

    @Test func celsiusPassesThroughUnchanged() {
        #expect(temperatureValue(celsius: 21.0, unit: .celsius, locale: us) == 21)
        #expect(temperatureString(celsius: 21.0, unit: .celsius, locale: us) == "21°")
    }

    @Test func fahrenheitConvertsAndRounds() {
        #expect(temperatureValue(celsius: 0.0, unit: .fahrenheit, locale: nl) == 32)
        #expect(temperatureValue(celsius: 20.0, unit: .fahrenheit, locale: nl) == 68)
        // 21°C = 69.8°F → afgerond 70°.
        #expect(temperatureString(celsius: 21.0, unit: .fahrenheit, locale: nl) == "70°")
    }

    @Test func negativeCelsiusToFahrenheit() {
        // -40 is het snijpunt van beide schalen.
        #expect(temperatureValue(celsius: -40.0, unit: .fahrenheit, locale: us) == -40)
    }

    // MARK: - .system-resolutie via locale

    @Test func systemResolvesToFahrenheitInUS() {
        #expect(usesFahrenheit(.system, locale: us))
        #expect(temperatureString(celsius: 21.0, unit: .system, locale: us) == "70°")
    }

    @Test func systemResolvesToCelsiusInNL() {
        #expect(!usesFahrenheit(.system, locale: nl))
        #expect(temperatureString(celsius: 21.0, unit: .system, locale: nl) == "21°")
    }

    // MARK: - Int-overload (DecisionSummary levert een afgeronde Celsius-Int)

    @Test func intOverloadMatchesDoubleOverload() {
        #expect(temperatureString(celsius: 20, unit: .fahrenheit, locale: nl) == "68°")
        #expect(temperatureString(celsius: 20, unit: .celsius, locale: nl) == "20°")
    }
}
