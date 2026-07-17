import SwiftUI

// Presentatie-grens tussen de presentatievrije Logic/Models-tokens en de UI.
// Domeinlogica levert enum-tokens; hier — en alleen hier — worden die naar
// gelokaliseerde tekst gemapt (English source keys in Localizable.xcstrings,
// met een Nederlandse vertaling). Zo bouwt de logica geen zinnen op en blijft
// alle vertaalbare copy in de String Catalog.

extension DayPeriod {
    // Gebruikt in de kop-samenvatting; keys komen uit Localizable.xcstrings.
    var titleKey: LocalizedStringKey {
        switch self {
        case .morning: return "period.morning"
        case .afternoon: return "period.afternoon"
        case .evening: return "period.evening"
        }
    }
}

extension OutdoorSummary {
    // Eén gelokaliseerde zin per token. De periode wordt als vertaalde
    // %@-placeholder ingevuld zodat we geen woorden aan elkaar plakken.
    func titleKey(period localizedPeriod: String) -> LocalizedStringKey {
        switch self {
        case .none:
            return "summary.none"
        case .clear:
            return "summary.clear \(localizedPeriod)"
        case .afterRain:
            return "summary.afterRain \(localizedPeriod)"
        case .clearThenRain:
            return "summary.clearThenRain \(localizedPeriod)"
        case .betweenShowers:
            return "summary.betweenShowers \(localizedPeriod)"
        }
    }

    // De dagperiode van dit token (nil voor .none), zodat de view eerst het
    // periode-woord kan lokaliseren en dan de zin.
    var period: DayPeriod? {
        switch self {
        case .none: return nil
        case let .clear(period),
             let .afterRain(period),
             let .clearThenRain(period),
             let .betweenShowers(period):
            return period
        }
    }
}

extension WeatherKind {
    // VoiceOver-label per weertype (WeatherIcon, DayChart).
    var titleKey: LocalizedStringKey {
        switch self {
        case .rain: return "weather.rain"
        case .cloud: return "weather.cloud"
        case .partly: return "weather.partly"
        case .sun: return "weather.sun"
        }
    }
}

extension DayOption {
    // Gelokaliseerde weergavetitel. rawValue blijft de (Nederlandse) stabiele
    // identiteit/opslagsleutel; alleen de weergave is vertaalbaar.
    var titleKey: LocalizedStringKey {
        switch self {
        case .vandaag: return "day.today"
        case .morgen: return "day.tomorrow"
        case .overmorgen: return "day.dayAfterTomorrow"
        case .week: return "day.week"
        }
    }
}

extension HorizonOption {
    var titleKey: LocalizedStringKey {
        switch self {
        case .heleDag: return "horizon.allDay"
        case .plus6: return "horizon.plus6"
        case .plus2: return "horizon.plus2"
        }
    }
}

extension SettingsColorKey {
    var titleKey: LocalizedStringKey {
        switch self {
        case .sun: return "weather.sun"
        case .partly: return "weather.partly"
        case .cloud: return "weather.cloud"
        case .rain: return "weather.rain"
        case .night: return "color.night"
        }
    }
}
