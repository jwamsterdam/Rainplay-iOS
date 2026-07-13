import Foundation

// Pure classificatie van een uur naar een WeatherKind op basis van de Open-Meteo
// velden. Dit is domeinlogica (geen netwerk), dus hoort in Logic/ en niet in de
// Services-laag. Stuurt de score, de lucht-gradient én de weericonen aan, dus de
// grenzen zijn los testbaar gehouden.
//
// Volgorde van beslissen:
//   1. Neerslag ≥ 0,2 mm OF een regen-/motregen-/onweers-weathercode → regen.
//   2. Nacht of weinig straling (< 80 W/m²) → bewolkt (geen zon zichtbaar).
//   3. Anders op bewolkingsgraad: < 28% zon, < 72% half bewolkt, daarboven bewolkt.
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
