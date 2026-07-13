import Foundation

// Lucht-gradient en kleurhelpers, 1:1 geport uit de PWA
// (kleur- en gradient-gedeelte van src/lib/chart.ts).

func lerpRgba(_ c1: RGBAColor, _ c2: RGBAColor, _ t: Double) -> RGBAColor {
    RGBAColor(
        r: Int((Double(c1.r) + (Double(c2.r) - Double(c1.r)) * t).rounded()),
        g: Int((Double(c1.g) + (Double(c2.g) - Double(c1.g)) * t).rounded()),
        b: Int((Double(c1.b) + (Double(c2.b) - Double(c1.b)) * t).rounded()),
        a: ((c1.a + (c2.a - c1.a) * t) * 100).rounded() / 100
    )
}

func mixRgba(_ c1: RGBAColor, _ c2: RGBAColor) -> RGBAColor {
    lerpRgba(c1, c2, 0.5)
}

// Straling (W/m²) waarboven de lucht als "volle dag" geldt. 20 W/m² ligt net
// boven civiele schemering (~5 W/m²), zodat alleen de korte minuten rond de
// feitelijke zonsopkomst/-ondergang geblend worden — bewolkte daguren
// (typisch 50–300 W/m²) houden hun strakke dag-kleur.
let defaultTwilightRadiationWm2 = 20.0

// Shortwave_radiation zakt naar 0 bij zonsondergang, maar de lucht blijft nog
// ~75 minuten zichtbaar licht (civiele + nautische schemering). Deze falloff
// overbrugt dat gat met de vooraf berekende sunsetMs, zodat de gradient
// geleidelijk vervaagt in plaats van abrupt naar nacht te knippen.
private let civilTwilightMs = 75.0 * 60 * 1000

// Zet straling om naar een [0, 1] lucht-helderheid waarmee tussen nacht- en
// dagkleuren geblend wordt. Straling in plaats van de binaire is_day-vlag geeft
// een vloeiende, tijd-consistente zonsondergang: dezelfde stralingswaarde geeft
// dezelfde kleur, welk horizonvenster ook getoond wordt. Alleen de smalle
// schemeringszone (0–20 W/m²) wordt geblend; al het echte daglicht bereikt
// direct helderheid 1.
func skyBrightness(_ hour: HourlyWeather, twilightWm2: Double = defaultTwilightRadiationWm2) -> Double {
    let radiationBrightness = min(hour.radiation / twilightWm2, 1)
    guard let sunsetMs = hour.sunsetMs else { return radiationBrightness }

    let afterSunset = IsoTime.ms(hour.isoTime) - sunsetMs
    if afterSunset >= 0 && afterSunset <= civilTwilightMs {
        let twilightBrightness = 1 - afterSunset / civilTwilightMs
        return max(radiationBrightness, twilightBrightness)
    }

    return radiationBrightness
}

func cellFill(_ hour: HourlyWeather, colors: CellColors, twilightWm2: Double = defaultTwilightRadiationWm2) -> RGBAColor {
    let t = skyBrightness(hour, twilightWm2: twilightWm2)
    if t <= 0 { return colors.night }
    if t >= 1 { return colors.color(for: hour.kind) }
    return lerpRgba(colors.night, colors.color(for: hour.kind), t)
}

struct SkyGradientStop: Equatable {
    var offset: Double
    var color: RGBAColor
}

/// Bouwt de kleurstops voor de lucht/helderheid-gradient als één horizontale
/// lineaire gradient (offsets 0..1), in één keer te schilderen.
///
/// Visueel model (spiegelt de per-cel-rect-gradient van vroeger, maar naadloos):
/// - Elk uur i beslaat de band [i/n, (i+1)/n]; zijn CENTRUM (offset (i+0.5)/n)
///   krijgt de kleur van dat uur = cellFill(hours[i]).
/// - Op de GRENS tussen uur i en i+1 (offset (i+1)/n) staat de 50/50-blend van
///   de twee aangrenzende celkleuren — dezelfde rand-mix als voorheen.
/// - De allereerste rand (offset 0) = kleur van het eerste uur; de laatste rand
///   (offset 1) = kleur van het laatste uur.
///
/// Optimalisatie: opeenvolgende stops met identieke kleur worden samengevouwen
/// tot de minimale set (de eerste en laatste van elke identieke-kleur-reeks),
/// zodat een vlakke reeks gelijke cellen (bijv. nachturen) als vlakke vulling
/// rendert in plaats van vele overbodige interpolatiepunten.
func buildSkyGradientStops(
    _ hours: [HourlyWeather],
    colors: CellColors,
    twilightWm2: Double = defaultTwilightRadiationWm2
) -> [SkyGradientStop] {
    let n = hours.count
    guard n > 0 else { return [] }

    let fills = hours.map { cellFill($0, colors: colors, twilightWm2: twilightWm2) }

    // Volledige centrum+grens-stoplijst, van links naar rechts.
    var raw: [SkyGradientStop] = []
    raw.append(SkyGradientStop(offset: 0, color: fills[0])) // eerste rand
    for i in 0..<n {
        raw.append(SkyGradientStop(offset: (Double(i) + 0.5) / Double(n), color: fills[i])) // band-centrum
        if i < n - 1 {
            raw.append(SkyGradientStop(offset: Double(i + 1) / Double(n), color: mixRgba(fills[i], fills[i + 1]))) // grens-blend
        }
    }
    raw.append(SkyGradientStop(offset: 1, color: fills[n - 1])) // laatste rand

    // Vouw reeksen met identieke kleur samen: houd alleen de eerste en laatste
    // van elke reeks.
    var collapsed: [SkyGradientStop] = []
    for i in raw.indices {
        let isFirst = i == 0
        let isLast = i == raw.count - 1
        let samePrev = !isFirst && raw[i - 1].color == raw[i].color
        let sameNext = !isLast && raw[i + 1].color == raw[i].color
        // Laat een stop alleen vallen als hij binnenin een identieke-kleur-reeks ligt.
        if samePrev && sameNext { continue }
        collapsed.append(raw[i])
    }

    return collapsed
}
