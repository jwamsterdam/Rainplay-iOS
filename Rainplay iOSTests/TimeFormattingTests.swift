import Foundation
@testable import Rainplay_iOS
import Testing

/// Pure time/date presentation helpers: forced 12/24-hour, `.system` resolution
/// via the locale, and locale-aware date notation. Locale is injected so the tests
/// don't depend on the device or its 12/24-hour setting.
struct TimeFormattingTests {
    private let us = Locale(identifier: "en_US")
    private let nl = Locale(identifier: "nl_NL")
    private let gb = Locale(identifier: "en_GB")

    /// Fixed calendar date, built independent of time zone so the test yields the
    /// same hour in any environment.
    private func iso(_ hour: Int, _ minute: Int = 0) -> String {
        String(format: "2026-07-11T%02d:%02d", hour, minute)
    }

    /// Date.FormatStyle separates the time and AM/PM with a narrow no-break space
    /// (U+202F); normalize to a regular space so assertions stay readable and stable.
    private func normalized(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    // MARK: - Forced 24-hour

    @Test func twentyFourHourForcesZeroPaddedClock() {
        #expect(timeString(isoTime: iso(13), format: .twentyFourHour, locale: us) == "13:00")
        #expect(timeString(isoTime: iso(0), format: .twentyFourHour, locale: us) == "00:00")
        #expect(timeString(isoTime: iso(9, 30), format: .twentyFourHour, locale: nl) == "09:30")
    }

    // MARK: - Forced 12-hour

    /// 13:00 → "1:00 PM", midnight → "12:00 AM", noon → "12:00 PM".
    @Test func twelveHourForcesAmPm() {
        #expect(normalized(timeString(isoTime: iso(13), format: .twelveHour, locale: us)) == "1:00 PM")
        #expect(normalized(timeString(isoTime: iso(0), format: .twelveHour, locale: us)) == "12:00 AM")
        #expect(normalized(timeString(isoTime: iso(12), format: .twelveHour, locale: us)) == "12:00 PM")
    }

    // MARK: - Axis labels without AM/PM

    /// Compact x-axis: 12-hour without AM/PM, 24-hour stays HH:mm.
    @Test func axisTimeOmitsAmPm() {
        let twelve = normalized(axisTimeString(isoTime: iso(13), format: .twelveHour, locale: us))
        #expect(twelve == "1:00")
        #expect(!twelve.contains("PM") && !twelve.contains("AM"))
        #expect(axisTimeString(isoTime: iso(13), format: .twentyFourHour, locale: us) == "13:00")
    }

    // MARK: - .system follows the locale

    /// nl_NL is a 24-hour locale.
    @Test func systemUses24HourInNL() {
        #expect(timeString(isoTime: iso(13), format: .system, locale: nl) == "13:00")
    }

    /// en_US is a 12-hour locale → AM/PM.
    @Test func systemUses12HourInUS() {
        let midday = timeString(isoTime: iso(13), format: .system, locale: us)
        #expect(midday.contains("1"))
        #expect(midday.uppercased().contains("PM"))
    }

    @Test func systemUses24HourInGB() {
        #expect(timeString(isoTime: iso(13), format: .system, locale: gb) == "13:00")
    }

    // MARK: - Date

    @Test func dateLabelIsLocaleAwareInOrderAndLanguage() {
        let date = IsoTime.date("2026-07-01T12:00")
        // Dutch: day before month, short weekday.
        let nlLabel = dateLabel(date: date, style: .weekdayDayMonth, locale: nl)
        #expect(nlLabel.contains("1"))
        #expect(nlLabel.lowercased().contains("jul"))

        // US puts the month first.
        let usLabel = dateLabel(date: date, style: .dayMonth, locale: us)
        #expect(usLabel.contains("Jul"))
        #expect(usLabel.contains("1"))
    }

    @Test func dayMonthStyleOmitsWeekday() {
        let date = IsoTime.date("2026-07-01T12:00")
        let withWeekday = dateLabel(date: date, style: .weekdayDayMonth, locale: nl)
        let withoutWeekday = dateLabel(date: date, style: .dayMonth, locale: nl)
        #expect(withWeekday.count > withoutWeekday.count)
    }

    @Test func systemStyleIncludesWeekday() {
        let date = IsoTime.date("2026-07-01T12:00")
        #expect(dateLabel(date: date, style: .system, locale: nl)
            == dateLabel(date: date, style: .weekdayDayMonth, locale: nl))
    }

    @Test func weekRangeJoinsTwoDatesWithDash() {
        let from = IsoTime.date("2026-07-01T12:00")
        let to = IsoTime.date("2026-07-07T12:00")
        let label = weekRangeLabel(from: from, to: to, style: .dayMonth, locale: nl)
        #expect(label.contains(" - "))
        #expect(label.hasPrefix(dateLabel(date: from, style: .dayMonth, locale: nl)))
    }

    /// 2026-07-01 is a Wednesday.
    @Test func weekdayLabelIsLocaleAware() {
        let date = IsoTime.date("2026-07-01T12:00")
        #expect(weekdayLabel(date: date, locale: nl).lowercased().hasPrefix("wo"))
        #expect(weekdayLabel(date: date, locale: us).lowercased().hasPrefix("wed"))
    }

    // MARK: - Date overload consistent with isoTime overload

    @Test func dateOverloadMatchesIsoOverload() {
        let isoTime = iso(15, 45)
        #expect(timeString(date: IsoTime.date(isoTime), format: .twentyFourHour, locale: nl)
            == timeString(isoTime: isoTime, format: .twentyFourHour, locale: nl))
    }
}
