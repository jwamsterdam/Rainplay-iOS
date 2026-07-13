import Testing
@testable import Rainplay_iOS

// Port van src/lib/chart.windows.test.ts uit de PWA.
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

    @Test func emptySeriesReturnsFallbacks() {
        #expect(bestOutdoorWindow([]) == nil)
        #expect(bestStartTime([]) == "--:--")
        #expect(bestWindowLabel([]) == "--:--")
        #expect(outdoorSummaryLabel([], bestWindow: nil) == "Geen duidelijk buitenmoment")
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
        #expect(best?.startTime == "06:00")
        #expect(best?.endTime == "08:00")
        #expect(bestStartTime(hours) == "06:00")
        #expect(bestWindowLabel(hours) == "06:00 - 08:00")
    }

    @Test func breaksEqualLengthTiesByAverageScore() {
        let hours = [
            hour("06:00", score: 8, kind: .sun),
            hour("07:00", score: 5, rad: 20, kind: .cloud),
            hour("08:00", score: 9, kind: .sun),
        ]
        #expect(bestOutdoorWindow(hours)?.startTime == "08:00")
    }

    @Test func fallsBackToHighestNonRainScore() {
        let hours = [
            hour("06:00", score: 5, prob: 90, kind: .cloud),
            hour("07:00", score: 6, prob: 90, kind: .cloud),
            hour("08:00", score: 9, prob: 90, kind: .rain),
        ]
        #expect(bestOutdoorWindow(hours)?.startTime == "07:00")
    }

    @Test func infersEndTimeForFinalPointFromStep() {
        let hours = [
            hour("10:00", iso: "2026-06-11T10:00"),
            hour("10:30", iso: "2026-06-11T10:30"),
        ]
        #expect(bestOutdoorWindow(hours)?.endTime == "11:00")
    }

    @Test func selectsPracticalPreferredTierWhenCloudDisqualifiesBright() {
        let hours = [hour("10:00", score: 8, rad: 40, kind: .cloud)]
        #expect(bestOutdoorWindow(hours)?.startTime == "10:00")
    }

    @Test func selectsPreferredTierForEveningOutsidePracticalRange() {
        let hours = [hour("20:00", score: 9, rad: 200, kind: .sun, iso: "2026-06-11T20:00")]
        #expect(bestOutdoorWindow(hours)?.startTime == "20:00")
    }

    @Test func keepsNonTimeLabelsForWeekSummaries() {
        let hours = [
            hour("ma", iso: "2026-06-11T12:00"),
            hour("di", iso: "2026-06-12T12:00"),
        ]
        #expect(bestOutdoorWindow(hours)?.endTime == "di")
    }

    // MARK: - outdoorSummaryLabel

    @Test func describesWindowBetweenRainyPeriods() {
        let hours = [
            hour("10:00", precip: 0.4, kind: .rain),
            hour("14:00", score: 9, kind: .sun),
            hour("18:00", precip: 0.4, kind: .rain),
        ]
        #expect(outdoorSummaryLabel(hours, bestWindow: bestOutdoorWindow(hours)) == "Tussen buien door - middag beste")
    }

    @Test func describesDryMorningBeforeLaterRain() {
        let hours = [
            hour("09:00", score: 9, kind: .sun),
            hour("12:00", precip: 0.4, kind: .rain),
        ]
        #expect(outdoorSummaryLabel(hours, bestWindow: bestOutdoorWindow(hours)) == "Ochtend beste - later regen")
    }

    @Test func describesClearAfternoonAfterMorningRain() {
        let hours = [
            hour("06:00", precip: 0.4, kind: .rain),
            hour("14:00", score: 9, kind: .sun),
        ]
        #expect(outdoorSummaryLabel(hours, bestWindow: bestOutdoorWindow(hours)) == "Na regen - middag beste")
    }

    @Test func describesFullyClearPeriod() {
        let hours = [hour("09:00", score: 9, kind: .sun)]
        #expect(outdoorSummaryLabel(hours, bestWindow: bestOutdoorWindow(hours)) == "Ochtend beste buitenmoment")
    }

    @Test func usesEveningLabelForWindowsStartingAt18OrLater() {
        let evening = OutdoorWindow(startIndex: 0, endIndex: 0, startTime: "19:00", endTime: "20:00")
        #expect(outdoorSummaryLabel([], bestWindow: evening) == "Avond beste buitenmoment")
    }
}
