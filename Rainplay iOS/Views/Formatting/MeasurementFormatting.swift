import Foundation

// Pure presentation helpers for temperature. Canonical data stays Celsius;
// conversion and formatting happen only here, at the presentation boundary, so
// the rest of the app need not know about units. The locale is injectable so
// tests do not depend on the device.

/// Whether temperatures should be shown in Fahrenheit. `.system` derives this from
/// the locale (US measurement system means Fahrenheit); otherwise the choice is explicit.
func usesFahrenheit(_ unit: TemperatureUnit, locale: Locale = .current) -> Bool {
    switch unit {
    case .system: return locale.measurementSystem == .us
    case .celsius: return false
    case .fahrenheit: return true
    }
}

/// Converts Celsius to the chosen unit and rounds to a whole degree, matching the
/// existing "21°" UI style. Computes C→F as `c * 9 / 5 + 32`.
func temperatureValue(celsius: Double, unit: TemperatureUnit, locale: Locale = .current) -> Int {
    let converted = usesFahrenheit(unit, locale: locale) ? celsius * 9 / 5 + 32 : celsius
    return Int(converted.rounded())
}

/// Same as `temperatureValue` but for an already-rounded Celsius Int (as supplied
/// by `DecisionSummary.temperature`). A ±1° rounding difference is acceptable.
func temperatureValue(celsius: Int, unit: TemperatureUnit, locale: Locale = .current) -> Int {
    temperatureValue(celsius: Double(celsius), unit: unit, locale: locale)
}

/// Bare degrees string in the existing UI style, e.g. "21°".
func temperatureString(celsius: Double, unit: TemperatureUnit, locale: Locale = .current) -> String {
    "\(temperatureValue(celsius: celsius, unit: unit, locale: locale))°"
}

func temperatureString(celsius: Int, unit: TemperatureUnit, locale: Locale = .current) -> String {
    "\(temperatureValue(celsius: celsius, unit: unit, locale: locale))°"
}
