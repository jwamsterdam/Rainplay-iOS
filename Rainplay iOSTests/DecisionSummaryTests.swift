import Foundation
@testable import Rainplay_iOS
import Testing

/// Exercises the derived header information (temperature, best moment, advice text).
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

    /// 12 points every 2 hours on 2026-06-11; midday hours score high and dry.
    @Test func vandaagUsesCurrentTemperatureAndDerivesWindow() {
        let hourly = stride(from: 0, through: 22, by: 2).map { h -> HourlyWeather in
            let iso = String(format: "2026-06-11T%02d:00", h)
            let daytime = h >= 6 && h <= 20
            return hour(iso, temp: 18, score: daytime ? 9 : 5, kind: daytime ? .sun : .cloud, rad: daytime ? 300 : 0)
        }
        let forecast = Forecast(currentTemperature: 21, hourly: hourly, minutely15: [], sunriseTimes: [:], sunsetTimes: [:])

        let summary = decisionSummary(forecast: forecast, day: .vandaag, horizon: .heleDag, now: Date())
        #expect(summary.temperature == 21)                       // live temp, not the average
        // Header date is the canonical day (June 11); the view formats it.
        #expect(summary.headerDate == .single(IsoTime.date("2026-06-11T12:00")))
        #expect(summary.bestStart != nil)                        // a window exists
        #expect(summary.summary != .none)                        // a nuance line is present
    }
}
