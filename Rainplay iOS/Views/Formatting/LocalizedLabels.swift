import SwiftUI

// Presentatie-grens tussen de presentatievrije Logic/Models-tokens en de UI.
// Domeinlogica levert enum-tokens; hier — en alleen hier — worden die naar
// gelokaliseerde tekst gemapt (English source keys in Localizable.xcstrings,
// met een Nederlandse vertaling). Zo bouwt de logica geen zinnen op en blijft
// alle vertaalbare copy in de String Catalog.

extension DayPeriod {
    // Gebruikt in de kop-samenvatting; keys komen uit Localizable.xcstrings.
    // LocalizedStringResource zodat het periode-woord tot een String opgelost
    // kan worden en als placeholder in de samenvattingszin past.
    var resource: LocalizedStringResource {
        switch self {
        case .morning: return "period.morning"
        case .afternoon: return "period.afternoon"
        case .evening: return "period.evening"
        }
    }

    // Opgeloste, gelokaliseerde periodetekst ("ochtend"/"morning").
    var localizedText: String { String(localized: resource) }
}

extension OutdoorSummary {
    // Eén gelokaliseerde zin per token. Het periode-woord wordt eerst apart
    // gelokaliseerd en als %@-placeholder in de zin gezet — zo plakken we geen
    // woorden aan elkaar en kan elke taal de zinsvolgorde zelf bepalen.
    var titleKey: LocalizedStringKey {
        guard let period else { return "summary.none" }
        let localizedPeriod = period.localizedText
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

    // De dagperiode van dit token (nil voor .none).
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
    var resource: LocalizedStringResource {
        switch self {
        case .rain: return "weather.rain"
        case .cloud: return "weather.cloud"
        case .partly: return "weather.partly"
        case .sun: return "weather.sun"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .rain: return "weather.rain"
        case .cloud: return "weather.cloud"
        case .partly: return "weather.partly"
        case .sun: return "weather.sun"
        }
    }

    // Opgeloste, gelokaliseerde weertype-tekst — voor labels die uit meerdere
    // stukken worden samengesteld (bijv. de VoiceOver-tekst in DayChart).
    var localizedText: String { String(localized: resource) }
}

extension DayOption {
    // Volledige gelokaliseerde weergavetitel (hero-kop). rawValue blijft de
    // (Nederlandse) stabiele identiteit/opslagsleutel; alleen weergave vertaalt.
    var titleKey: LocalizedStringKey {
        switch self {
        case .vandaag: return "day.today"
        case .morgen: return "day.tomorrow"
        case .overmorgen: return "day.dayAfterTomorrow"
        case .week: return "day.week"
        }
    }

    // Compacte titel voor de dag-selector: kort "Overmorgen" af, zoals de PWA.
    var segmentTitleKey: LocalizedStringKey {
        self == .overmorgen ? "day.dayAfterTomorrow.short" : titleKey
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
