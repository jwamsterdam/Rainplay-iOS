@testable import Rainplay_iOS
import Testing

/// Boundaries of the hourly classification (drives score, gradient, and icons).
struct WeatherClassificationTests {
    private func kind(precip: Double = 0, code: Double = 0, cloud: Double = 0, rad: Double = 300, day: Bool = true) -> WeatherKind {
        weatherKind(weatherCode: code, precipitationMm: precip, cloudCover: cloud, radiation: rad, isDay: day)
    }

    @Test func rainByPrecipitationOrCode() {
        #expect(kind(precip: 0.2) == .rain)          // exactly on the threshold
        #expect(kind(precip: 0.5) == .rain)
        #expect(kind(precip: 0.1, code: 61) == .rain) // trace + rain code (drizzle)
        #expect(kind(precip: 0.1, code: 3) != .rain)  // trace without a rain code isn't rain
    }

    @Test func nightOrLowRadiationIsCloud() {
        #expect(kind(cloud: 0, rad: 500, day: false) == .cloud) // night, regardless of radiation
        #expect(kind(cloud: 0, rad: 79, day: true) == .cloud)   // too little radiation
    }

    @Test func daytimeCloudCoverThresholds() {
        #expect(kind(cloud: 27, rad: 300) == .sun)     // < 28
        #expect(kind(cloud: 28, rad: 300) == .partly)  // 28..<72
        #expect(kind(cloud: 71, rad: 300) == .partly)
        #expect(kind(cloud: 72, rad: 300) == .cloud)   // >= 72
    }
}
