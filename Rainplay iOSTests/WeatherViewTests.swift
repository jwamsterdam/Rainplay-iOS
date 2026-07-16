import Foundation
@testable import Rainplay_iOS
import Testing

// Port van src/lib/weatherView.test.ts + weatherView.todayHorizon.test.ts.
struct WeatherViewTests {
    private func hour(
        _ iso: String,
        temp: Double = 18,
        score: Int = 7,
        precip: Double = 0,
        prob: Double = 10,
        cloud: Double = 30,
        rad: Double = 200,
        isDay: Bool = true,
        kind: WeatherKind = .partly
    ) -> HourlyWeather {
        let start = iso.index(iso.startIndex, offsetBy: 11)
        let time = String(iso[start...].prefix(5))
        return HourlyWeather(
            isoTime: iso, time: time, temperatureC: temp, score: score,
            precipitationMm: precip, precipitationProbability: prob,
            cloudCover: cloud, radiation: rad, isDay: isDay, kind: kind
        )
    }

    private func day(_ date: String, score: Int = 7, kind: WeatherKind = .partly, rad: Double = 200, precip: Double = 0) -> [HourlyWeather] {
        (0..<24).map { i in
            hour(String(format: "%@T%02d:00", date, i), score: score, precip: precip, rad: rad, isDay: i >= 6 && i <= 21, kind: kind)
        }
    }

    private var hours: [HourlyWeather] {
        day("2026-06-11")
            + day("2026-06-12", score: 8, kind: .sun, rad: 500)
            + day("2026-06-13", score: 4, kind: .rain, precip: 0.7)
    }

    // MARK: - averageTemperature

    @Test func averageTemperatureRoundsMean() {
        let points = [
            hour("2026-06-11T10:00", temp: 16),
            hour("2026-06-11T11:00", temp: 19),
            hour("2026-06-11T12:00", temp: 22),
        ]
        #expect(averageTemperature(points) == 19)
        #expect(averageTemperature([]) == nil)
    }

    // MARK: - visibleHoursForHorizon / selection

    @Test func horizonLimitsShortWindows() {
        #expect(visibleHoursForHorizon(hours, .plus2).count == 3)
        #expect(visibleHoursForHorizon(hours, .plus6).count == 7)
        #expect(visibleHoursForHorizon(hours, .heleDag).count == hours.count)
    }

    @Test func selectionReturnsSteppedHoursForToday() {
        let selected = visibleHoursForSelection(hours, day: .vandaag, horizon: .plus6)
        #expect(selected.count == 7)
        #expect(selected[0].isoTime == "2026-06-11T00:00")
        #expect(selected[1].isoTime == "2026-06-11T02:00")
    }

    @Test func selectionIgnoresShortHorizonForOtherDays() {
        let selected = visibleHoursForSelection(hours, day: .morgen, horizon: .plus2)
        #expect(selected.count == 12)
        #expect(selected[0].isoTime == "2026-06-12T00:00")
        #expect(selected[1].isoTime == "2026-06-12T02:00")
    }

    @Test func weekSummarisesOnePointPerDay() {
        let selected = visibleHoursForSelection(hours, day: .week, horizon: .heleDag)
        #expect(selected.count == 3)
        #expect(selected.map(\.time) == ["do", "vr", "za"])
        #expect(selected[1].kind == .sun)
        #expect(selected[2].kind == .rain)
    }

    @Test func missingDayReturnsEmpty() {
        let todayOnly = day("2026-06-11")
        #expect(visibleHoursForSelection(todayOnly, day: .overmorgen, horizon: .heleDag).isEmpty)
    }

    // MARK: - visiblePointsForTodayHorizon

    @Test func heleDagUsesHourlyEvenWithMinutely() {
        let minutely = [hour("2026-06-11T10:15"), hour("2026-06-11T10:30")]
        let selected = visiblePointsForTodayHorizon(hourly: hours, minutely15: minutely, horizon: .heleDag)
        #expect(selected[0].time == "00:00")
        #expect(selected.count == 12)
    }

    @Test func minutelyWindowsStartAtLastNiceLabelBeforeNow() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10, minute: 35))!
        let minutely = ["10:15", "10:30", "10:45", "11:00", "11:15", "11:30", "11:45", "12:00", "12:15"]
            .map { hour("2026-06-11T\($0)") }

        let plus2 = visiblePointsForTodayHorizon(hourly: hours, minutely15: minutely, horizon: .plus2, now: now)
        let plus6 = visiblePointsForTodayHorizon(hourly: hours, minutely15: minutely, horizon: .plus6, now: now)

        // +6 begint op het laatste :00/:30 vóór nu (10:30), elke 30 min.
        #expect(plus6.map(\.time) == ["10:30", "11:00", "11:30", "12:00"])

        // +2 is geïnterpoleerd naar HETZELFDE aantal punten als +6 (voor het
        // morph-effect), start op dezelfde 10:30 en eindigt op het einde van het
        // 2-uursvenster.
        #expect(plus2.count == plus6.count)
        #expect(plus2.first?.time == "10:30")
        #expect(plus2.last?.time == "12:15")
    }

    @Test func plus2AndPlus6HaveEqualPointCount() {
        // Vol venster (24 kwartierpunten): +2 en +6 moeten evenveel punten hebben.
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10, minute: 0))!
        let minutely = (0..<24).map { i -> HourlyWeather in
            let total = 10 * 60 + i * 15
            return hour(String(format: "2026-06-11T%02d:%02d", total / 60, total % 60), temp: 18 + Double(i) * 0.1)
        }
        let plus2 = visiblePointsForTodayHorizon(hourly: hours, minutely15: minutely, horizon: .plus2, now: now)
        let plus6 = visiblePointsForTodayHorizon(hourly: hours, minutely15: minutely, horizon: .plus6, now: now)
        #expect(plus2.count == plus6.count)
    }

    @Test func fallsBackToIndexZeroWithoutNiceLabel() {
        let minutely = [hour("2026-06-11T10:15"), hour("2026-06-11T10:45")]
        #expect(visiblePointsForTodayHorizon(hourly: hours, minutely15: minutely, horizon: .plus2).first?.time == "10:15")
    }

    // MARK: - summarizeDay kind selection

    private func makeKindDay(_ date: String, kindFor: (Int) -> WeatherKind) -> [HourlyWeather] {
        (0..<24).map { i in
            hour(String(format: "%@T%02d:00", date, i), isDay: i >= 6 && i <= 21, kind: kindFor(i))
        }
    }

    @Test func weekKindCloudWhenNoSunPartlyOrRain() {
        let cloudHours = makeKindDay("2026-06-11") { _ in .cloud }
        #expect(visibleHoursForSelection(cloudHours, day: .week, horizon: .heleDag).first?.kind == .cloud)
    }

    @Test func weekKindPartlyWhenPartlyOutnumbersSun() {
        let mixed = makeKindDay("2026-06-11") { $0 == 10 ? .sun : .partly }
        #expect(visibleHoursForSelection(mixed, day: .week, horizon: .heleDag).first?.kind == .partly)
    }

    // MARK: - headerDateLabel

    @Test func headerLabelsForDaysAndWeek() {
        #expect(headerDateLabel(hours, day: .vandaag).contains("do"))
        #expect(headerDateLabel(hours, day: .morgen).contains("vr"))
        #expect(headerDateLabel(hours, day: .overmorgen).contains("za"))
        #expect(headerDateLabel(hours, day: .week).contains(" - "))
        #expect(headerDateLabel([], day: .vandaag) == "")
        #expect(headerDateLabel([], day: .week) == "")
    }
}
