import Foundation

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

/// Radiation (W/m²) above which the sky counts as full daylight. Just above civil
/// twilight (~5 W/m²), so only the minutes around actual sunrise/sunset are
/// blended while overcast daytime hours (typically 50–300 W/m²) keep their solid
/// day colour.
let defaultTwilightRadiationWm2 = 20.0

/// Shortwave radiation drops to 0 at sunset, but the sky stays visibly lit for
/// ~75 minutes (civil + nautical twilight). This bridges that gap so the gradient
/// fades gradually instead of snapping to night.
private let civilTwilightMs = 75.0 * 60 * 1000

/// Maps radiation to a [0, 1] sky brightness used to blend night and day colours.
/// Using radiation rather than the binary is-day flag yields a smooth,
/// time-consistent sunset: the same radiation value produces the same colour
/// regardless of which horizon window is shown.
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

/// Builds the colour stops for the sky/brightness gradient as one horizontal
/// linear gradient (offsets 0...1).
///
/// Each hour `i` spans the band `[i/n, (i+1)/n]`; its centre takes that hour's
/// `cellFill`, and every interior boundary takes the 50/50 blend of its two
/// neighbours. Runs of identical adjacent colours are collapsed to their first
/// and last stop, so flat stretches (e.g. night hours) render as a solid fill.
func buildSkyGradientStops(
    _ hours: [HourlyWeather],
    colors: CellColors,
    twilightWm2: Double = defaultTwilightRadiationWm2
) -> [SkyGradientStop] {
    let n = hours.count
    guard n > 0 else { return [] }

    let fills = hours.map { cellFill($0, colors: colors, twilightWm2: twilightWm2) }

    var raw: [SkyGradientStop] = []
    raw.append(SkyGradientStop(offset: 0, color: fills[0]))
    for i in 0..<n {
        raw.append(SkyGradientStop(offset: (Double(i) + 0.5) / Double(n), color: fills[i]))
        if i < n - 1 {
            raw.append(SkyGradientStop(offset: Double(i + 1) / Double(n), color: mixRgba(fills[i], fills[i + 1])))
        }
    }
    raw.append(SkyGradientStop(offset: 1, color: fills[n - 1]))

    var collapsed: [SkyGradientStop] = []
    for i in raw.indices {
        let isInterior = i > 0 && i < raw.count - 1
        if isInterior, raw[i - 1].color == raw[i].color, raw[i + 1].color == raw[i].color { continue }
        collapsed.append(raw[i])
    }

    return collapsed
}
