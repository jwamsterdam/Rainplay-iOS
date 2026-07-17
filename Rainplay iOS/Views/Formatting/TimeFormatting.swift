import Foundation

// Pure presentation helpers for time and date. Canonical times stay local ISO time
// (isoTime); formatting happens only here, at the presentation boundary, so the rest
// of the app need not know about 12/24-hour or date ordering. The locale is
// injectable so tests do not depend on the device or its 12/24-hour setting.

// MARK: - Time

/// Converts a local ISO time ("2026-07-09T14:00") to a display string in the chosen
/// format. `.system` follows the device 12/24-hour setting via `Date.FormatStyle`;
/// `.twelveHour`/`.twentyFourHour` force the format with a fixed hourCycle while
/// keeping the locale's AM/PM symbols and separator.
func timeString(isoTime: String, format: TimeFormat, locale: Locale = .current) -> String {
    timeString(date: IsoTime.date(isoTime), format: format, locale: locale)
}

/// Date overload for times already available as a Date (such as the best moment from
/// `DecisionSummary`), avoiding an unnecessary round trip through isoTime.
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

/// Compact time for the chart x-axis: the same 12/24-hour choice but without the
/// AM/PM suffix, since axis labels are narrow and rotated ("2:00" instead of
/// "2:00 PM"). Visual axis labels only; VoiceOver keeps the full time.
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
    /// Forces the 12/24-hour cycle by supplying a locale with an explicit hourCycle,
    /// while keeping the given locale's language (AM/PM symbols, separator).
    func locale(forcedHourCycle base: Locale, use24Hour: Bool) -> Date.FormatStyle {
        var components = Locale.Components(locale: base)
        components.hourCycle = use24Hour ? .zeroToTwentyThree : .oneToTwelve
        return self.locale(Locale(components: components))
    }
}

// MARK: - Date

/// "za 1 jul" / "1 jul", locale-aware in order and language. `.system` falls back
/// to the explicit display style with weekday.
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

/// Date range for the week header, e.g. "wo 9 jul - di 15 jul".
func weekRangeLabel(from: Date, to: Date, style: DateStyle, locale: Locale = .current) -> String {
    "\(dateLabel(date: from, style: style, locale: locale)) - \(dateLabel(date: to, style: style, locale: locale))"
}

/// Abbreviated weekday for the week-carousel labels ("wo"), locale-aware.
func weekdayLabel(date: Date, locale: Locale = .current) -> String {
    date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
}

/// Full weekday name ("woensdag" / "Wednesday"), locale-aware. Used in the week
/// view where the header shows a day instead of a time.
func weekdayName(date: Date, locale: Locale = .current) -> String {
    date.formatted(.dateTime.weekday(.wide).locale(locale))
}
