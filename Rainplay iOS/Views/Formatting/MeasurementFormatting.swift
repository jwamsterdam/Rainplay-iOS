import Foundation

// Pure presentatie-helpers voor temperatuur. Canonieke data blijft Celsius;
// conversie en formatting gebeuren alleen hier, op de presentatiegrens, zodat
// de rest van de app niets over eenheden hoeft te weten. Framework-licht
// (alleen Foundation) en deterministisch, dus makkelijk te testen — de locale
// is injecteerbaar zodat tests niet van het apparaat afhangen.

// Bepaalt of temperaturen in Fahrenheit getoond moeten worden. `.system` leidt
// dit af uit de locale (US-maatsysteem → Fahrenheit), verder is de keuze expliciet.
func usesFahrenheit(_ unit: TemperatureUnit, locale: Locale = .current) -> Bool {
    switch unit {
    case .system: return locale.measurementSystem == .us
    case .celsius: return false
    case .fahrenheit: return true
    }
}

// Zet Celsius om naar de gekozen eenheid en rondt af op een hele graad, zoals
// de bestaande "21°"-stijl in de UI. Rekent C→F als c * 9/5 + 32.
func temperatureValue(celsius: Double, unit: TemperatureUnit, locale: Locale = .current) -> Int {
    let converted = usesFahrenheit(unit, locale: locale) ? celsius * 9 / 5 + 32 : celsius
    return Int(converted.rounded())
}

// Zelfde als temperatureValue maar voor een reeds afgeronde Celsius-Int (zoals
// DecisionSummary.temperature levert). Houdt ±1° afronding acceptabel voor Fase 1.
func temperatureValue(celsius: Int, unit: TemperatureUnit, locale: Locale = .current) -> Int {
    temperatureValue(celsius: Double(celsius), unit: unit, locale: locale)
}

// Kale graden-string in de bestaande UI-stijl, bijv. "21°".
func temperatureString(celsius: Double, unit: TemperatureUnit, locale: Locale = .current) -> String {
    "\(temperatureValue(celsius: celsius, unit: unit, locale: locale))°"
}

func temperatureString(celsius: Int, unit: TemperatureUnit, locale: Locale = .current) -> String {
    "\(temperatureValue(celsius: celsius, unit: unit, locale: locale))°"
}
