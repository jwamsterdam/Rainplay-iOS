import Foundation
@testable import Rainplay_iOS
import Testing

// Port van src/lib/chart.windows.test.ts uit de PWA. Vensters dragen nu
// canonieke Date-grenzen (start/end) i.p.v. vooraf gerenderde tijdstrings;
// de tests toetsen daarom op het uur/minuut van die Date.
struct BestWindowTests {
    private func hour(
        _ time: String,
        score: Int = 8,
        precip: Double = 0,
        prob: Double = 10,
        rad: Double = 300,
        isDay: Bool = true,
        kind: WeatherKind = .sun,
        iso: String? = nil
    ) -> HourlyWeather {
        HourlyWeather(
            isoTime: iso ?? "2026-06-11T\(time)",
            time: time,
            temperatureC: 18,
            score: score,
            precipitationMm: precip,
            precipitationProbability: prob,
            cloudCover: 20,
            radiation: rad,
            isDay: isDay,
            kind: kind
        )
    }

    // Uur/minuut van een canonieke venster-Date, in de apparaat-tijdzone.
    private func clock(_ date: Date?) -> String? {
        guard let date else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    @Test func emptySeriesReturnsFallbacks() {
        #expect(bestOutdoorWindow([]) == nil)
        #expect(outdoorSummary([], bestWindow: nil) == .none)
    }

    @Test func prefersLongestBrightDryPracticalWindow() {
        let hours = [
            hour("06:00", score: 8, rad: 300, kind: .sun),
            hour("07:00", score: 8, rad: 300, kind: .sun),
            hour("08:00", score: 6, rad: 40, kind: .cloud),
            hour("09:00", score: 9, rad: 350, kind: .sun),
        ]
        let best = bestOutdoorWindow(hours)
        #expect(best?.startIndex == 0)
        #expect(best?.endIndex == 1)
        #expect(clock(best?.start) == "06:00")
        #expect(clock(best?.end) == "08:00")
    }

    @Test func breaksEqualLengthTiesByAverageScore() {
        let hours = [
            hour("06:00", score: 8, kind: .sun),
            hour("07:00", score: 5, rad: 20, kind: .cloud),
            hour("08:00", score: 9, kind: .sun),
        ]
        #expect(clock(bestOutdoorWindow(hours)?.start) == "08:00")
    }

    @Test func fallsBackToHighestNonRainScore() {
        let hours = [
            hour("06:00", score: 5, prob: 90, kind: .cloud),
            hour("07:00", score: 6, prob: 90, kind: .cloud),
            hour("08:00", score: 9, prob: 90, kind: .rain),
        ]
        #expect(clock(bestOutdoorWindow(hours)?.start) == "07:00")
    }

    @Test func infersEndTimeForFinalPointFromStep() {
        let hours = [
            hour("10:00", iso: "2026-06-11T10:00"),
            hour("10:30", iso: "2026-06-11T10:30"),
        ]
        #expect(clock(bestOutdoorWindow(hours)?.end) == "11:00")
    }

    @Test func selectsPracticalPreferredTierWhenCloudDisqualifiesBright() {
        let hours = [hour("10:00", score: 8, rad: 40, kind: .cloud)]
        #expect(clock(bestOutdoorWindow(hours)?.start) == "10:00")
    }

    @Test func selectsPreferredTierForEveningOutsidePracticalRange() {
        let hours = [hour("20:00", score: 9, rad: 200, kind: .sun, iso: "2026-06-11T20:00")]
        #expect(clock(bestOutdoorWindow(hours)?.start) == "20:00")
    }

    // Week-samenvattingen dragen een dagsleutel als identiteit en hebben geen
    // intra-day eindtijd → end is nil (de view toont dan geen tijdbereik).
    @Test func hasNoEndTimeForWeekSummaries() {
        let hours = [
            hour("2026-06-11", iso: "2026-06-11T12:00"),
            hour("2026-06-12", iso: "2026-06-12T12:00"),
        ]
        let best = bestOutdoorWindow(hours)
        #expect(best?.endIndex == 1)
        #expect(best?.end == nil)
    }

    // MARK: - outdoorSummary (semantische tokens; de view lokaliseert ze)

    @Test func describesWindowBetweenRainyPeriods() {
        let hours = [
            hour("10:00", precip: 0.4, kind: .rain),
            hour("14:00", score: 9, kind: .sun),
            hour("18:00", precip: 0.4, kind: .rain),
        ]
        #expect(outdoorSummary(hours, bestWindow: bestOutdoorWindow(hours)) == .betweenShowers(period: .afternoon))
    }

    @Test func describesDryMorningBeforeLaterRain() {
        let hours = [
            hour("09:00", score: 9, kind: .sun),
            hour("12:00", precip: 0.4, kind: .rain),
        ]
        #expect(outdoorSummary(hours, bestWindow: bestOutdoorWindow(hours)) == .clearThenRain(period: .morning))
    }

    @Test func describesClearAfternoonAfterMorningRain() {
        let hours = [
            hour("06:00", precip: 0.4, kind: .rain),
            hour("14:00", score: 9, kind: .sun),
        ]
        #expect(outdoorSummary(hours, bestWindow: bestOutdoorWindow(hours)) == .afterRain(period: .afternoon))
    }

    @Test func describesFullyClearPeriod() {
        let hours = [hour("09:00", score: 9, kind: .sun)]
        #expect(outdoorSummary(hours, bestWindow: bestOutdoorWindow(hours)) == .clear(period: .morning))
    }

    @Test func usesEveningLabelForWindowsStartingAt18OrLater() {
        let evening = OutdoorWindow(
            startIndex: 0,
            endIndex: 0,
            start: IsoTime.date("2026-06-11T19:00"),
            end: IsoTime.date("2026-06-11T20:00")
        )
        #expect(outdoorSummary([], bestWindow: evening) == .clear(period: .evening))
    }
}
