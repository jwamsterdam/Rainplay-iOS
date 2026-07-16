import Foundation
@testable import Rainplay_iOS
import Testing

// De dubbele-as-geometrie (temperatuur ↔ regen-domein).
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
        #expect(geo.tempMin == 14)   // onder: ≥1° (15.3) afgerond op even graden
        #expect(geo.tempMax == 25)   // boven: strak ⌈23.7+1⌉ = 25 (niet op even)
    }

    @Test func guaranteesAtLeastOneDegreeMargin() {
        // Precies op even graden: zonder marge zou de lijn de rand raken.
        let geo = ChartGeometry(hours: hours([16, 24]))
        #expect(geo.tempMin <= 16 - 1)   // minimaal 1° onder de laagste temp
        #expect(geo.tempMax >= 24 + 1)   // minimaal 1° boven de hoogste temp
    }

    @Test func topMarginIsTighterThanEvenRounding() {
        // Bij een hete dag (max 32) mag de lijn hoog komen: ~1° i.p.v. tot ~3°.
        let geo = ChartGeometry(hours: hours([18, 32]))
        #expect(geo.tempMax == 33)   // ⌈32+1⌉, dus 1° boven de piek
    }

    @Test func topTickShowsMaxValue() {
        let geo = ChartGeometry(hours: hours([18, 32]))
        #expect(geo.tempTicks.last == geo.tempMax)   // bovenste aswaarde (33) zichtbaar
    }

    @Test func flatTemperatureRangeExpands() {
        let geo = ChartGeometry(hours: hours([18, 18]))
        #expect(geo.tempMin <= 17)
        #expect(geo.tempMax >= 19)
        #expect(geo.tempMin < geo.tempMax)
    }

    @Test func sharedRangeSpansAllGroups() {
        // Twee dagen met verschillende temperaturen → één gedeelde as die beide dekt.
        let range = ChartGeometry.temperatureRange(across: [hours([10, 15]), hours([20, 25])])
        let geo = ChartGeometry(temperatureRange: range, precipitationMax: nil)
        #expect(geo.tempMin <= 10 - 1)   // dekt de laagste van alle dagen
        #expect(geo.tempMax >= 25 + 1)   // dekt de hoogste van alle dagen
    }

    @Test func normalizeMapsBoundsToDomainEdges() {
        let geo = ChartGeometry(hours: hours([10, 20]))   // min 10, max 20
        #expect(geo.normalizedTemp(geo.tempMin) == 0)
        #expect(geo.normalizedTemp(geo.tempMax) == geo.rainMax)
    }

    // MARK: - Regen-as

    @Test func rainAxisFloorsAtThree() {
        // Weinig regen (max 1 mm) → as blijft 3 mm, zodat 1 mm niet "veel" lijkt.
        let geo = ChartGeometry(hours: hours([18, 20], precip: [0.4, 1.0]))
        #expect(geo.rainMax == 3)
    }

    @Test func rainAxisGrowsAboveThree() {
        // Flinke bui (5,4 mm) → as groeit mee zodat balken niet buiten beeld lopen.
        let geo = ChartGeometry(hours: hours([18, 20], precip: [5.4, 2.0]))
        #expect(geo.rainMax == 6)                 // ⌈5,4⌉
        #expect(geo.rainTicks.last == geo.rainMax) // bovenste regenwaarde zichtbaar
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
