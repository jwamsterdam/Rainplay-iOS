import Foundation
@testable import Rainplay_iOS
import Testing

struct NowMarkerTests {
    /// Deterministic clock in local time — the same time zone IsoTime uses to
    /// parse isoTime strings.
    private func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(
            year: 2026, month: 6, day: 11 + dayOffset, hour: hour, minute: minute
        ))!
    }

    /// Builds isoTime strings from "HH:mm", advancing the day on a midnight wrap.
    private func pts(_ times: String...) -> [String] {
        var dayOffset = 0
        var prevMinutes = Int.min
        return times.map { time in
            let parts = time.split(separator: ":")
            let h = Int(parts[0])!
            let m = parts.count > 1 ? Int(parts[1])! : 0
            let minutes = h * 60 + m
            if minutes < prevMinutes { dayOffset += 1 }
            prevMinutes = minutes
            return String(format: "2026-06-%02dT%02d:%02d", 11 + dayOffset, h, m)
        }
    }

    private func close(_ a: Double?, _ b: Double, tol: Double = 1e-9) -> Bool {
        guard let a else { return false }
        return abs(a - b) < tol
    }

    @Test func interiorNowMapsToBandCentres() {
        #expect(close(nowFraction(isoTimes: pts("12:00", "13:00", "14:00"), now: at(13)), 0.5))
        #expect(close(nowFraction(isoTimes: pts("12:00", "13:00", "14:00"), now: at(12, 30)), 1.0 / 3.0))
        #expect(close(nowFraction(isoTimes: pts("12:00", "13:00", "14:00"), now: at(12, 15)), 0.25))
    }

    @Test func endpointsUseBandCentreNotEdges() {
        let four = pts("06:00", "07:00", "08:00", "09:00")
        #expect(close(nowFraction(isoTimes: four, now: at(6)), 0.5 / 4))
        #expect(close(nowFraction(isoTimes: four, now: at(9)), 3.5 / 4))
    }

    @Test func clampsLeftWhenNowBeforeFirstPoint() {
        let window = pts("09:00", "09:15", "09:30", "09:45", "10:00")
        #expect(nowFraction(isoTimes: window, now: at(8, 46)) == 0)
    }

    @Test func clampsRightWhenNowAfterLastPoint() {
        #expect(nowFraction(isoTimes: pts("09:00", "10:00", "11:00"), now: at(15)) == 1)
    }

    @Test func returnsNilForFewerThanTwoPoints() {
        #expect(nowFraction(isoTimes: [], now: at(12)) == nil)
        #expect(nowFraction(isoTimes: pts("12:00"), now: at(12)) == nil)
        #expect(close(nowFraction(isoTimes: pts("12:00", "13:00"), now: at(12, 30)), 0.5))
    }

    @Test func heleDagMiddayIsInterior() {
        let times = (0..<24).map { String(format: "2026-06-11T%02d:00", $0) }
        let f = nowFraction(isoTimes: times, now: at(12))
        #expect(close(f, 12.5 / 24))
        #expect(f! > 0 && f! < 1)
    }

    @Test func midnightCrossingDoesNotPinToRightEdge() {
        let window = pts(
            "23:00", "23:30",
            "0:00", "0:30", "1:00", "1:30",
            "2:00", "2:30", "3:00", "3:30",
            "4:00", "4:30"
        )
        #expect(close(nowFraction(isoTimes: window, now: at(23, 20)), (0.5 + 20.0 / 30.0) / 12, tol: 1e-5))
        let afterMidnight = nowFraction(isoTimes: window, now: at(0, 30, dayOffset: 1))
        #expect(afterMidnight != 1)
        #expect(close(afterMidnight, 3.5 / 12, tol: 1e-5))
        #expect(close(nowFraction(isoTimes: window, now: at(4, 30, dayOffset: 1)), 11.5 / 12, tol: 1e-5))
    }
}
