import Testing
@testable import Rainplay_iOS

// Port van src/lib/outdoorScore.test.ts uit de PWA.
struct OutdoorScoreTests {
    private func score(
        precip: Double = 0,
        temp: Double = 18,
        kind: WeatherKind = .sun,
        isDay: Bool = true
    ) -> Int {
        outdoorScore(precipitationMm: precip, temperatureC: temp, kind: kind, isDay: isDay)
    }

    @Test func dryBrightDaytimeGetsHighestBand() {
        #expect(score(kind: .sun) == 10)
        #expect(score(kind: .partly) == 9)
        #expect(score(kind: .cloud) == 8)
    }

    @Test func rainReducesScoreSharplyAsPrecipitationRises() {
        #expect(score(precip: 0.1, kind: .rain) == 6)
        #expect(score(precip: 0.3, kind: .rain) == 5)
        #expect(score(precip: 0.8, kind: .rain) == 2)
        #expect(score(precip: 1.5, kind: .rain) == 0)
        #expect(score(precip: 3, kind: .rain) == 0)
    }

    @Test func darknessIsAHardCapEvenWhenOtherwiseIdeal() {
        #expect(score(kind: .sun, isDay: false) == 6)
        #expect(score(kind: .partly, isDay: false) == 6)
    }

    @Test func temperatureIsASecondaryModifier() {
        #expect(score(temp: 18) == 10)
        #expect(score(temp: 12) == 9)
        #expect(score(temp: 8) == 8)
        #expect(score(temp: 4) == 7)
        #expect(score(temp: 0) == 6)
        #expect(score(temp: 28) == 9)
        #expect(score(temp: 35) == 6)
    }

    @Test func staysInside0to10ForEveryKind() {
        for kind in [WeatherKind.sun, .partly, .cloud, .rain] {
            let value = score(
                precip: kind == .rain ? 10 : 0,
                temp: kind == .rain ? -5 : 18,
                kind: kind
            )
            #expect(value >= 0 && value <= 10)
        }
    }
}
