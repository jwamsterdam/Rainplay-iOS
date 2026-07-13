import Foundation

// Enige bron van waarheid voor de 0-10 outdoor score.
// 1:1 geport uit de PWA (src/lib/outdoorScore.ts).
//
// De neerslag-straf volgt weatherKind(): een uur is "regen" (regen-/motregen-
// icoon) zodra precip >= 0,2 mm OF het weather_code een motregen-/regen-code is.
// `kind == .rain` is dus het signaal "het regent/motregent", ook als er nog
// maar een spoortje neerslag (< 0,2 mm) gemeten wordt — typisch motregen.
//
// IJkpunten (bij ideale temp):
//   echt droog (<0,2 mm, geen regen-code) → telt als droog, score volgt icoon (sun/partly/cloud)
//   motregen-code, spoor (<0,2 mm)        → ~6  (consistent met regen-icoon, lichter dan echte regen)
//   lichte regen (~0,3 mm)                → ~5  (lichte onvoldoende)
//   bewolkt + aangenaam                   → 7-8
//   bewolkt + koud                        → ~6
//   zon met bewolking                     → 8-9
//   echt zonnig                           → 9-10

private nonisolated func precipitationPenalty(_ mm: Double, isRainCoded: Bool) -> Double {
    if mm < 0.2 {
        // Echt droog: geen regen-icoon → geen straf (sluit aan op kind sun/partly/cloud).
        // Motregen-code met spoortje neerslag → regen-icoon, dus een lichte straf zodat
        // de score onder een motregen-uur zakt. Lichter dan de 0,2-0,5 mm-band, zodat
        // motregen nooit lager scoort dan echte lichte regen.
        return isRainCoded ? 2.5 : 0
    }
    if mm <= 0.5 { return 3.5 }  // motregen/drizzle → ~4-5
    if mm <= 1 { return 6 }      // licht nat        → ~2-3
    if mm <= 2 { return 8 }      // matig            → ~1
    return 10                    // zwaar            → 0
}

private nonisolated func temperaturePenalty(_ c: Double) -> Double {
    if c >= 14 && c <= 22 { return 0 }  // ideaal
    if c > 22 && c <= 26 { return 0.5 }
    if c > 26 && c <= 30 { return 1.5 }
    if c > 30 { return 4 }
    if c >= 12 { return 1 }             // fris maar prima
    if c >= 8 { return 2 }              // koud voor wielrenner
    if c >= 4 { return 3 }              // erg koud
    return 4                            // <4°C of >30°C
}

private nonisolated func kindPenalty(_ kind: WeatherKind) -> Double {
    switch kind {
    case .sun: return 0     // ideaal
    case .partly: return 1  // zon met bewolking → 8-9
    case .cloud: return 2   // bewolkt           → 7-8
    case .rain: return 2    // regen-icoon: extra aftrek → regen altijd ≤5
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
    // Nacht: altijd maximaal 6 — het blijft donker, hoe droog of warm ook
    return isDay ? score : min(score, 6)
}
