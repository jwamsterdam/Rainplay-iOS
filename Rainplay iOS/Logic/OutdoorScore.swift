import Foundation

/// Single source of truth for the 0-10 outdoor score.
///
/// The precipitation penalty follows weatherKind(): an hour is "rain" once precip
/// >= 0.2 mm OR the weather_code is a drizzle/rain code. So `kind == .rain` is the
/// "it's raining/drizzling" signal, even with only a trace (< 0.2 mm) measured.
///
/// Reference points (at ideal temperature):
///   truly dry (<0.2 mm, no rain code) → dry, score follows icon (sun/partly/cloud)
///   drizzle code, trace (<0.2 mm)     → ~6  (matches rain icon, lighter than real rain)
///   light rain (~0.3 mm)              → ~5  (mild fail)
///   cloudy + pleasant                 → 7-8
///   cloudy + cold                     → ~6
///   sun with cloud                    → 8-9
///   truly sunny                       → 9-10

private nonisolated func precipitationPenalty(_ mm: Double, isRainCoded: Bool) -> Double {
    if mm < 0.2 {
        // Drizzle code with a trace of precip still shows the rain icon, so apply a
        // light penalty to drop the score below a drizzle hour. Lighter than the
        // 0.2-0.5 mm band so drizzle never scores lower than real light rain.
        return isRainCoded ? 2.5 : 0
    }
    if mm <= 0.5 { return 3.5 }  // drizzle
    if mm <= 1 { return 6 }      // lightly wet
    if mm <= 2 { return 8 }      // moderate
    return 10                    // heavy
}

private nonisolated func temperaturePenalty(_ c: Double) -> Double {
    if c >= 14 && c <= 22 { return 0 }  // ideal
    if c > 22 && c <= 26 { return 0.5 }
    if c > 26 && c <= 30 { return 1.5 }
    if c > 30 { return 4 }
    if c >= 12 { return 1 }             // crisp but fine
    if c >= 8 { return 2 }              // cold
    if c >= 4 { return 3 }              // very cold
    return 4                            // <4°C
}

private nonisolated func kindPenalty(_ kind: WeatherKind) -> Double {
    switch kind {
    case .sun: return 0
    case .partly: return 1
    case .cloud: return 2
    case .rain: return 2  // extra deduction so rain always scores ≤5
    }
}

nonisolated func outdoorScore(
    precipitationMm: Double,
    temperatureC: Double,
    kind: WeatherKind,
    isDay: Bool
) -> Int {
    let raw = 10
        - precipitationPenalty(precipitationMm, isRainCoded: kind == .rain)
        - temperaturePenalty(temperatureC)
        - kindPenalty(kind)
    let score = Int(max(0, min(10, raw.rounded())))
    // Night caps at 6: it stays dark however dry or warm it is.
    return isDay ? score : min(score, 6)
}
