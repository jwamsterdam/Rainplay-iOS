import Foundation

/// Pure classification of an hour into a WeatherKind from the Open-Meteo fields.
/// Drives the score, sky gradient and weather icons, so the thresholds are kept
/// testable on their own.
///
/// Decision order:
///   1. Precip ≥ 0.2 mm OR a drizzle/rain/thunderstorm weather code → rain.
///   2. Night or low radiation (< 80 W/m²) → cloud (no visible sun).
///   3. Otherwise by cloud cover: < 28% sun, < 72% partly, above that cloud.
nonisolated func weatherKind(
    weatherCode: Double,
    precipitationMm: Double,
    cloudCover: Double,
    radiation: Double,
    isDay: Bool
) -> WeatherKind {
    let rainCodes: Set<Double> = [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99]
    if precipitationMm >= 0.2 || rainCodes.contains(weatherCode) {
        return .rain
    }

    if !isDay || radiation < 80 { return .cloud }
    if cloudCover < 28 { return .sun }
    if cloudCover < 72 { return .partly }
    return .cloud
}
