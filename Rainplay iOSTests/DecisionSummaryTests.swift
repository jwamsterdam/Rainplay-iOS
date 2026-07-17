import Foundation
@testable import Rainplay_iOS
import Testing

// Tests voor de afgeleide kop-informatie (temperatuur, beste-moment, adviesteksten).
struct DecisionSummaryTests {
    private func hour(_ iso: String, temp: Double, score: Int, kind: WeatherKind = .sun, rad: Double = 300) -> HourlyWeather {
        let start = iso.index(iso.startIndex, offsetBy: 11)
        return HourlyWeather(
            isoTime: iso, time: String(iso[start...].prefix(5)),
            temperatureC: temp, score: score, precipitationMm: 0,
            precipitationProbability: 10, cloudCover: 20, radiation: rad,
            isDay: true, kind: kind
        )
    }

    @Test func emptyForecastGivesNilTemperatureAndFallbacks() {
        let summary = decisionSummary(forecast: nil, day: .vandaag, horizon: .heleDag, now: Date())
        #expect(summary.temperature == nil)
        #expect(summary.bestStart == nil)
        #expect(summary.summary == .none)
        #expect(summary.headerDate == .none)
    }

    @Test func vandaagUsesCurrentTemperatureAndDerivesWindow() {
        // 12 uren om de 2 uur op 2026-06-11; middaguren scoren hoog en droog.
        let hourly = stride(from: 0, through: 22, by: 2).map { h -> HourlyWeather in
            let iso = String(format: "2026-06-11T%02d:00", h)
            let daytime = h >= 6 && h <= 20
            return hour(iso, temp: 18, score: daytime ? 9 : 5, kind: daytime ? .sun : .cloud, rad: daytime ? 300 : 0)
        }
        let forecast = Forecast(currentTemperature: 21, hourly: hourly, minutely15: [], sunriseTimes: [:], sunsetTimes: [:])

        let summary = decisionSummary(forecast: forecast, day: .vandaag, horizon: .heleDag, now: Date())
        #expect(summary.temperature == 21)                       // live temp, niet het gemiddelde
        // Kop-datum is de canonieke dag (11 juni), de view formatteert die.
        #expect(summary.headerDate == .single(IsoTime.date("2026-06-11T12:00")))
        #expect(summary.bestStart != nil)                        // er is een venster
        #expect(summary.summary != .none)                        // vriendelijke nuance-regel
    }
}
