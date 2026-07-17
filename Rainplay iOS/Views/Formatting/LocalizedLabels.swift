import SwiftUI

// Presentation boundary between the presentation-free Logic/Models tokens and the UI.
// Domain logic supplies enum tokens; here — and only here — they are mapped to
// localized text (English source keys in Localizable.xcstrings, with a Dutch
// translation). This keeps logic from assembling sentences and keeps all
// translatable copy in the String Catalog.

extension DayPeriod {
    /// `LocalizedStringResource` so the period word can be resolved to a String and
    /// used as a placeholder inside the summary sentence.
    var resource: LocalizedStringResource {
        switch self {
        case .morning: return "period.morning"
        case .afternoon: return "period.afternoon"
        case .evening: return "period.evening"
        }
    }

    /// Resolved, localized period text ("ochtend"/"morning").
    var localizedText: String { String(localized: resource) }
}

extension OutdoorSummary {
    /// One localized sentence per token. The period word is localized separately and
    /// inserted as a %@ placeholder so words are never concatenated and each language
    /// can decide its own word order.
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

    /// Week view: day-oriented summary without a day-period word, since the header
    /// already shows the day. Same rain-nuance cases, different copy.
    var weekTitleKey: LocalizedStringKey {
        switch self {
        case .none: return "summary.week.none"
        case .clear: return "summary.week.clear"
        case .afterRain: return "summary.week.afterRain"
        case .clearThenRain: return "summary.week.clearThenRain"
        case .betweenShowers: return "summary.week.betweenShowers"
        }
    }

    /// The day period of this token (nil for `.none`).
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
    /// VoiceOver label per weather type (WeatherIcon, DayChart).
    var resource: LocalizedStringResource {
        switch self {
        case .rain: return "weather.rain"
        case .cloud: return "weather.cloud"
        case .partly: return "weather.partly"
        case .sun: return "weather.sun"
        }
    }

    /// Resolved, localized weather-type text — for labels assembled from multiple
    /// parts (such as the VoiceOver text in DayChart).
    var localizedText: String { String(localized: resource) }
}

extension DayOption {
    /// Full localized display title (hero header). `rawValue` stays the stable
    /// identity/storage key; only the display is translated.
    var titleKey: LocalizedStringKey {
        switch self {
        case .vandaag: return "day.today"
        case .morgen: return "day.tomorrow"
        case .overmorgen: return "day.dayAfterTomorrow"
        case .week: return "day.week"
        }
    }

    /// Compact title for the day selector: abbreviates "Day after tomorrow".
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
