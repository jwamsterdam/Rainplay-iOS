import Foundation

// Pure presentatie-helpers voor tijd en datum. Canonieke tijden blijven de
// lokale ISO-tijd (isoTime); formattering gebeurt alleen hier, op de
// presentatiegrens, zodat de rest van de app niets over 12/24-uurs of
// datumvolgorde hoeft te weten. Framework-licht (alleen Foundation) en
// deterministisch — de locale is injecteerbaar zodat tests niet van het
// apparaat of zijn 12/24-uurs-instelling afhangen.

// MARK: - Tijd

// Zet een lokale ISO-tijd ("2026-07-09T14:00") om naar een weergavestring in de
// gekozen notatie. `.system` volgt de 12/24-uurs-instelling van het apparaat
// (via Date.FormatStyle); `.twelveHour`/`.twentyFourHour` forceren de notatie
// met een vaste hourCycle, maar houden AM/PM-symbolen en scheidingsteken van de
// locale aan.
func timeString(isoTime: String, format: TimeFormat, locale: Locale = .current) -> String {
    timeString(date: IsoTime.date(isoTime), format: format, locale: locale)
}

// Date-overload voor tijdstippen die al als Date beschikbaar zijn (bijv. het
// beste-moment uit DecisionSummary), zodat er niet onnodig via isoTime wordt
// heen-en-weer geconverteerd.
func timeString(date: Date, format: TimeFormat, locale: Locale = .current) -> String {
    switch format {
    case .system:
        return date.formatted(.dateTime.hour().minute().locale(locale))
    case .twelveHour:
        return date.formatted(.dateTime.hour().minute().locale(forcedHourCycle: locale, use24Hour: false))
    case .twentyFourHour:
        return date.formatted(.dateTime.hour().minute().locale(forcedHourCycle: locale, use24Hour: true))
    }
}

// Compacte tijd voor de grafiek-x-as: dezelfde 12/24-uurs-keuze, maar zónder
// AM/PM-achtervoegsel — de as-labels zijn smal en geroteerd, dus "2:00" i.p.v.
// "2:00 PM". Alleen voor visuele as-labels; VoiceOver houdt de volledige tijd.
func axisTimeString(isoTime: String, format: TimeFormat, locale: Locale = .current) -> String {
    let date = IsoTime.date(isoTime)
    let symbol = Date.FormatStyle.Symbol.Hour.defaultDigits(amPM: .omitted)
    switch format {
    case .system:
        return date.formatted(.dateTime.hour(symbol).minute().locale(locale))
    case .twelveHour:
        return date.formatted(.dateTime.hour(symbol).minute().locale(forcedHourCycle: locale, use24Hour: false))
    case .twentyFourHour:
        return date.formatted(.dateTime.hour(symbol).minute().locale(forcedHourCycle: locale, use24Hour: true))
    }
}

private extension Date.FormatStyle {
    // Dwingt de 12/24-uurs-cyclus af door een locale met een expliciete
    // hourCycle mee te geven; behoudt verder taal (AM/PM-symbolen, scheiding)
    // van de opgegeven locale.
    func locale(forcedHourCycle base: Locale, use24Hour: Bool) -> Date.FormatStyle {
        var components = Locale.Components(locale: base)
        components.hourCycle = use24Hour ? .zeroToTwentyThree : .oneToTwelve
        return self.locale(Locale(components: components))
    }
}

// MARK: - Datum

// "za 1 jul" / "1 jul", locale-aware in volgorde en taal. `.system` valt terug
// op de expliciete weergave-stijl met weekdag; de PWA toonde altijd de weekdag.
func dateLabel(date: Date, style: DateStyle, locale: Locale = .current) -> String {
    let format: Date.FormatStyle
    switch style {
    case .dayMonth:
        format = .dateTime.day().month(.abbreviated)
    case .system, .weekdayDayMonth:
        format = .dateTime.weekday(.abbreviated).day().month(.abbreviated)
    }
    return date.formatted(format.locale(locale))
}

// Datumbereik voor de week-kop, bijv. "wo 9 jul - di 15 jul".
func weekRangeLabel(from: Date, to: Date, style: DateStyle, locale: Locale = .current) -> String {
    "\(dateLabel(date: from, style: style, locale: locale)) - \(dateLabel(date: to, style: style, locale: locale))"
}

// Weekdag-afkorting voor de week-carousel-labels ("wo"), locale-aware.
func weekdayLabel(date: Date, locale: Locale = .current) -> String {
    date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
}

// Volledige weekdagnaam ("woensdag" / "Wednesday"), locale-aware. Gebruikt in de
// week-weergave waar de kop een dag toont i.p.v. een tijdstip.
func weekdayName(date: Date, locale: Locale = .current) -> String {
    date.formatted(.dateTime.weekday(.wide).locale(locale))
}
