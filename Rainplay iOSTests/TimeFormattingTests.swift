import Foundation
@testable import Rainplay_iOS
import Testing

// De pure tijd/datum-presentatiehelpers: 12/24-uurs-forcering, `.system`-
// resolutie via de locale, en locale-aware datumnotatie. Locale wordt
// geïnjecteerd zodat de tests niet van het apparaat of zijn 12/24-uurs-
// instelling afhangen.
struct TimeFormattingTests {
    private let us = Locale(identifier: "en_US")
    private let nl = Locale(identifier: "nl_NL")
    private let gb = Locale(identifier: "en_GB")

    // Vaste kalenderdatum, tijdzone-onafhankelijk gebouwd zodat de test in elke
    // omgeving hetzelfde uur oplevert.
    private func iso(_ hour: Int, _ minute: Int = 0) -> String {
        String(format: "2026-07-11T%02d:%02d", hour, minute)
    }

    // Date.FormatStyle scheidt de tijd en AM/PM met een narrow no-break space
    // (U+202F); normaliseer naar een gewone spatie zodat de assertions leesbaar
    // en stabiel blijven.
    private func normalized(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    // MARK: - Geforceerde 24-uurs

    @Test func twentyFourHourForcesZeroPaddedClock() {
        #expect(timeString(isoTime: iso(13), format: .twentyFourHour, locale: us) == "13:00")
        #expect(timeString(isoTime: iso(0), format: .twentyFourHour, locale: us) == "00:00")
        #expect(timeString(isoTime: iso(9, 30), format: .twentyFourHour, locale: nl) == "09:30")
    }

    // MARK: - Geforceerde 12-uurs

    @Test func twelveHourForcesAmPm() {
        // 13:00 → "1:00 PM", middernacht → "12:00 AM", middag → "12:00 PM".
        #expect(normalized(timeString(isoTime: iso(13), format: .twelveHour, locale: us)) == "1:00 PM")
        #expect(normalized(timeString(isoTime: iso(0), format: .twelveHour, locale: us)) == "12:00 AM")
        #expect(normalized(timeString(isoTime: iso(12), format: .twelveHour, locale: us)) == "12:00 PM")
    }

    // MARK: - .system volgt de locale

    @Test func systemUses24HourInNL() {
        // nl_NL is een 24-uurs-locale.
        #expect(timeString(isoTime: iso(13), format: .system, locale: nl) == "13:00")
    }

    @Test func systemUses12HourInUS() {
        // en_US is een 12-uurs-locale → AM/PM.
        let midday = timeString(isoTime: iso(13), format: .system, locale: us)
        #expect(midday.contains("1"))
        #expect(midday.uppercased().contains("PM"))
    }

    @Test func systemUses24HourInGB() {
        #expect(timeString(isoTime: iso(13), format: .system, locale: gb) == "13:00")
    }

    // MARK: - Datum

    @Test func dateLabelIsLocaleAwareInOrderAndLanguage() {
        let date = IsoTime.date("2026-07-01T12:00")
        // Nederlands: dag vóór maand, korte weekdag.
        let nlLabel = dateLabel(date: date, style: .weekdayDayMonth, locale: nl)
        #expect(nlLabel.contains("1"))
        #expect(nlLabel.lowercased().contains("jul"))

        // US zet de maand vooraan.
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

    @Test func weekdayLabelIsLocaleAware() {
        // 2026-07-01 is een woensdag.
        let date = IsoTime.date("2026-07-01T12:00")
        #expect(weekdayLabel(date: date, locale: nl).lowercased().hasPrefix("wo"))
        #expect(weekdayLabel(date: date, locale: us).lowercased().hasPrefix("wed"))
    }

    // MARK: - Date-overload consistent met isoTime-overload

    @Test func dateOverloadMatchesIsoOverload() {
        let isoTime = iso(15, 45)
        #expect(timeString(date: IsoTime.date(isoTime), format: .twentyFourHour, locale: nl)
            == timeString(isoTime: isoTime, format: .twentyFourHour, locale: nl))
    }
}
