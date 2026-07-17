import Foundation
@testable import Rainplay_iOS
import Testing

/// Dual-axis geometry (temperature ↔ rain domain).
struct ChartGeometryTests {
    private func hours(_ temps: [Double], precip: [Double] = []) -> [HourlyWeather] {
        temps.enumerated().map { i, t in
            HourlyWeather(isoTime: "2026-07-09T\(String(format: "%02d", i)):00",
                          time: "\(i):00", temperatureC: t, score: 5,
                          precipitationMm: i < precip.count ? precip[i] : 0)
        }
    }

    @Test func emptyHoursUsesDefaultRange() {
        let geo = ChartGeometry(hours: [])
        #expect(geo.tempMin == 0)
        #expect(geo.tempMax == 20)
    }

    @Test func bottomEvenTopTight() {
        let geo = ChartGeometry(hours: hours([16.3, 23.7]))
        #expect(geo.tempMin == 14)   // bottom: ≥1° (15.3) rounded to even degrees
        #expect(geo.tempMax == 25)   // top: tight ⌈23.7+1⌉ = 25 (not snapped to even)
    }

    /// Exactly on even degrees: without a margin the line would touch the edge.
    @Test func guaranteesAtLeastOneDegreeMargin() {
        let geo = ChartGeometry(hours: hours([16, 24]))
        #expect(geo.tempMin <= 16 - 1)   // at least 1° below the lowest temp
        #expect(geo.tempMax >= 24 + 1)   // at least 1° above the highest temp
    }

    /// On a hot day (max 32) the line may reach high: ~1° instead of up to ~3°.
    @Test func topMarginIsTighterThanEvenRounding() {
        let geo = ChartGeometry(hours: hours([18, 32]))
        #expect(geo.tempMax == 33)   // ⌈32+1⌉, i.e. 1° above the peak
    }

    @Test func topTickShowsMaxValue() {
        let geo = ChartGeometry(hours: hours([18, 32]))
        #expect(geo.tempTicks.last == geo.tempMax)   // top axis value (33) visible
    }

    @Test func flatTemperatureRangeExpands() {
        let geo = ChartGeometry(hours: hours([18, 18]))
        #expect(geo.tempMin <= 17)
        #expect(geo.tempMax >= 19)
        #expect(geo.tempMin < geo.tempMax)
    }

    /// Two days with different temperatures → one shared axis covering both.
    @Test func sharedRangeSpansAllGroups() {
        let range = ChartGeometry.temperatureRange(across: [hours([10, 15]), hours([20, 25])])
        let geo = ChartGeometry(temperatureRange: range, precipitationMax: nil)
        #expect(geo.tempMin <= 10 - 1)   // covers the lowest across all days
        #expect(geo.tempMax >= 25 + 1)   // covers the highest across all days
    }

    @Test func normalizeMapsBoundsToDomainEdges() {
        let geo = ChartGeometry(hours: hours([10, 20]))   // min 10, max 20
        #expect(geo.normalizedTemp(geo.tempMin) == 0)
        #expect(geo.normalizedTemp(geo.tempMax) == geo.rainMax)
    }

    // MARK: - Rain axis

    /// Little rain (max 1 mm) → axis stays at 3 mm so 1 mm doesn't look like "a lot".
    @Test func rainAxisFloorsAtThree() {
        let geo = ChartGeometry(hours: hours([18, 20], precip: [0.4, 1.0]))
        #expect(geo.rainMax == 3)
    }

    /// Heavy shower (5.4 mm) → axis grows so bars stay on screen.
    @Test func rainAxisGrowsAboveThree() {
        let geo = ChartGeometry(hours: hours([18, 20], precip: [5.4, 2.0]))
        #expect(geo.rainMax == 6)                 // ⌈5.4 + 0.5⌉
        #expect(geo.rainTicks.last == geo.rainMax) // top rain value visible
    }

    /// A peak landing exactly on a whole number (e.g. the week cap of 3 mm) gets
    /// headroom: the axis becomes 4 so the bar doesn't touch the top edge.
    @Test func rainAxisLeavesHeadroomAbovePeak() {
        let geo = ChartGeometry(hours: hours([18, 20], precip: [3.0, 0.0]))
        #expect(geo.rainMax == 4)                 // ⌈3.0 + 0.5⌉
        #expect(geo.rainMax > 3.0)                // strictly above the peak
    }

    @Test func temperatureIsInverseOfNormalize() {
        let geo = ChartGeometry(hours: hours([12, 26]))
        for celsius in stride(from: geo.tempMin, through: geo.tempMax, by: 2) {
            #expect(geo.temperature(atNormalized: geo.normalizedTemp(celsius)) == Int(celsius))
        }
    }

    @Test func ticksStayWithinBoundsAndStepAtLeastTwo() {
        let geo = ChartGeometry(hours: hours([5, 27]))
        let ticks = geo.tempTicks
        #expect(ticks.first == geo.tempMin)
        #expect(ticks.allSatisfy { $0 >= geo.tempMin && $0 <= geo.tempMax })
        if ticks.count >= 2 { #expect(ticks[1] - ticks[0] >= 2) }
    }
}
