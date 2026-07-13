import Testing
@testable import Rainplay_iOS

// Port van src/lib/chart.gradient.test.ts uit de PWA.
struct SkyGradientTests {
    private let colors = CellColors(
        sun: RGBAColor(r: 255, g: 196, b: 0, a: 0.24),
        partly: RGBAColor(r: 243, g: 204, b: 73, a: 0.15),
        cloud: RGBAColor(r: 148, g: 191, b: 255, a: 0.15),
        rain: RGBAColor(r: 139, g: 149, b: 156, a: 0.37),
        night: RGBAColor(r: 10, g: 10, b: 10, a: 0.72)
    )

    private func hour(_ kind: WeatherKind, isDay: Bool = true, radiation: Double? = nil, iso: String = "2026-06-10T00:00", sunsetMs: Double? = nil) -> HourlyWeather {
        HourlyWeather(
            isoTime: iso,
            time: "00:00",
            temperatureC: 15,
            score: 5,
            precipitationMm: 0,
            precipitationProbability: 0,
            cloudCover: 0,
            radiation: radiation ?? (isDay ? 500 : 0),
            isDay: isDay,
            kind: kind,
            sunsetMs: sunsetMs
        )
    }

    private func close(_ a: Double, _ b: Double, tol: Double = 1e-6) -> Bool { abs(a - b) < tol }

    // MARK: - skyBrightness

    @Test func nightHasZeroBrightness() {
        #expect(skyBrightness(hour(.cloud, isDay: false, radiation: 0)) == 0)
    }

    @Test func meaningfulDaylightIsFullBrightness() {
        #expect(skyBrightness(hour(.sun, radiation: 20)) == 1)
        #expect(skyBrightness(hour(.sun, radiation: 100)) == 1)
        #expect(skyBrightness(hour(.sun, radiation: 800)) == 1)
    }

    @Test func scalesLinearlyInTwilightZone() {
        #expect(close(skyBrightness(hour(.sun, radiation: 10)), 0.5))
        #expect(close(skyBrightness(hour(.cloud, isDay: false, radiation: 5)), 0.25))
    }

    @Test func sameBrightnessRegardlessOfIsDay() {
        #expect(skyBrightness(hour(.sun, radiation: 30)) == skyBrightness(hour(.cloud, isDay: false, radiation: 30)))
    }

    @Test func civilTwilightFalloffFromSunset() {
        let sunsetMs = IsoTime.ms("2026-06-14T20:00")
        func atOffset(_ iso: String) -> HourlyWeather {
            hour(.cloud, isDay: false, radiation: 0, iso: iso, sunsetMs: sunsetMs)
        }
        #expect(close(skyBrightness(atOffset("2026-06-14T20:00")), 1))       // 0 min na zonsondergang
        #expect(close(skyBrightness(atOffset("2026-06-14T20:15")), 0.8))     // 15/75
        #expect(close(skyBrightness(atOffset("2026-06-14T20:45")), 0.4))     // 45/75
        #expect(close(skyBrightness(atOffset("2026-06-14T21:15")), 0))       // 75 min
        #expect(skyBrightness(atOffset("2026-06-14T21:30")) == 0)            // > 75 min
    }

    // MARK: - lerp / mix

    @Test func lerpReturnsEndpoints() {
        let c1 = RGBAColor(r: 0, g: 0, b: 0, a: 1)
        let c2 = RGBAColor(r: 100, g: 200, b: 50, a: 0.5)
        #expect(lerpRgba(c1, c2, 0) == c1)
        #expect(lerpRgba(c1, c2, 1) == c2)
        #expect(lerpRgba(colors.night, colors.sun, 0.5) == mixRgba(colors.night, colors.sun))
    }

    // MARK: - buildSkyGradientStops

    @Test func emptyInputYieldsNoStops() {
        #expect(buildSkyGradientStops([], colors: colors).isEmpty)
    }

    @Test func spansFullRangeWithCellColoursAtEdges() {
        let hours = [hour(.sun), hour(.rain)]
        let stops = buildSkyGradientStops(hours, colors: colors)
        #expect(stops.first?.offset == 0)
        #expect(stops.first?.color == cellFill(hours[0], colors: colors))
        #expect(stops.last?.offset == 1)
        #expect(stops.last?.color == cellFill(hours[1], colors: colors))
    }

    @Test func offsetsAreNonDecreasingWithinRange() {
        let hours = [hour(.sun), hour(.partly), hour(.cloud), hour(.rain)]
        let stops = buildSkyGradientStops(hours, colors: colors)
        for i in stops.indices {
            #expect(stops[i].offset >= 0 && stops[i].offset <= 1)
            if i > 0 { #expect(stops[i].offset >= stops[i - 1].offset) }
        }
    }

    @Test func blends50at50BoundaryBetweenTwoCells() {
        let hours = [hour(.sun), hour(.rain)]
        let stops = buildSkyGradientStops(hours, colors: colors)
        let boundary = stops.first { abs($0.offset - 0.5) < 1e-9 }
        #expect(boundary?.color == mixRgba(cellFill(hours[0], colors: colors), cellFill(hours[1], colors: colors)))
    }

    @Test func collapsesFlatRunOfIdenticalColours() {
        let hours = [hour(.cloud, isDay: false), hour(.cloud, isDay: false), hour(.cloud, isDay: false)]
        let stops = buildSkyGradientStops(hours, colors: colors)
        #expect(stops.count == 2)
        #expect(stops[0] == SkyGradientStop(offset: 0, color: colors.night))
        #expect(stops[1] == SkyGradientStop(offset: 1, color: colors.night))
    }

    @Test func singleHourProducesTwoFlatStops() {
        let hours = [hour(.sun)]
        let stops = buildSkyGradientStops(hours, colors: colors)
        #expect(stops.count == 2)
        #expect(stops[0] == SkyGradientStop(offset: 0, color: cellFill(hours[0], colors: colors)))
        #expect(stops[1] == SkyGradientStop(offset: 1, color: cellFill(hours[0], colors: colors)))
    }

    @Test func keepsTransitionBetweenTwoDifferentRuns() {
        let hours = [hour(.cloud, isDay: false), hour(.cloud, isDay: false), hour(.sun), hour(.sun)]
        let stops = buildSkyGradientStops(hours, colors: colors)
        let sun = cellFill(hours[2], colors: colors)
        let blend = mixRgba(colors.night, sun)
        #expect(stops.first == SkyGradientStop(offset: 0, color: colors.night))
        #expect(stops.last == SkyGradientStop(offset: 1, color: sun))
        let boundary = stops.first { abs($0.offset - 0.5) < 1e-9 }
        #expect(boundary?.color == blend)
        let nightCount = stops.filter { $0.color == colors.night }.count
        let sunCount = stops.filter { $0.color == sun }.count
        #expect(nightCount >= 1 && nightCount <= 2)
        #expect(sunCount >= 1 && sunCount <= 2)
    }
}
