import SwiftUI
import UIKit

// Design tokens shared across the views: colors, radii and spacing.
//
// Colors are dynamic: they resolve per interface style (light/dark) so the views
// follow the system setting automatically. The hero sky photo is identical in
// both modes; only the overlay, text and surfaces change.

extension Color {
    /// Dynamic color that resolves light/dark via the trait collection.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Same, but from two hex strings for concise token definitions.
    init(lightHex: String, darkHex: String) {
        self.init(light: Color(hex: lightHex), dark: Color(hex: darkHex))
    }

    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r: Double
        let g: Double
        let b: Double
        let a: Double
        if cleaned.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    init(_ rgba: RGBAColor) {
        self.init(.sRGB, red: Double(rgba.r) / 255, green: Double(rgba.g) / 255, blue: Double(rgba.b) / 255, opacity: rgba.a)
    }
}

enum Tokens {
    // Text colors (dark on light, light on dark).
    static let ink = Color(lightHex: "#101828", darkHex: "#E6EAF1")
    static let inkStrong = Color(lightHex: "#091526", darkHex: "#F4F7FB")
    static let inkMuted = Color(lightHex: "#697586", darkHex: "#9AA4B2")
    static let inkSoft = Color(lightHex: "#8a95a4", darkHex: "#7C8695")

    /// Hero text colors. Light: dark blue over the bright sky photo. Dark: white
    /// over the dark scrim that dims that same photo (see WeatherScreen).
    static let heroDayLabel = Color(
        light: Color(red: 15 / 255, green: 30 / 255, blue: 52 / 255, opacity: 0.76),
        dark: Color(white: 1, opacity: 0.88)
    )
    static let heroDateLabel = Color(
        light: Color(red: 15 / 255, green: 30 / 255, blue: 52 / 255, opacity: 0.62),
        dark: Color(white: 1, opacity: 0.70)
    )
    static let heroSubtitle = Color(
        light: Color(red: 14 / 255, green: 31 / 255, blue: 52 / 255, opacity: 0.68),
        dark: Color(white: 1, opacity: 0.78)
    )

    // Surfaces. surface = the large decision sheet and panels; control = the
    // light control surfaces (segmented track, buttons, cards).
    static let surface = Color(lightHex: "#ffffff", darkHex: "#1B1E25")
    static let control = Color(lightHex: "#f3f6f9", darkHex: "#23262E")
    /// Active thumb in the segmented control: slightly lighter than the track so
    /// it stands out in both modes (in dark it must differ from surface).
    static let segmentThumb = Color(lightHex: "#ffffff", darkHex: "#363B45")
    static let accent = Color(lightHex: "#1d7eea", darkHex: "#4A9BF5")
    static let rain = Color(hex: "#78b4f8")
    static let temperature = Color(hex: "#f97316")
    static let best = Color(lightHex: "#fff1c9", darkHex: "#3E3620")
    static let border = Color(
        light: Color(red: 220 / 255, green: 228 / 255, blue: 236 / 255, opacity: 0.88),
        dark: Color(white: 1, opacity: 0.14)
    )

    // Inactive segment text and the subtle border around the segmented track.
    static let segmentInactive = Color(lightHex: "#4b5565", darkHex: "#AEB6C2")
    static let segmentTrackStroke = Color(
        light: Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255, opacity: 0.74),
        dark: Color(white: 1, opacity: 0.10)
    )

    // Score colors — semantic, identical in both modes.
    static let scoreGood = Color(hex: "#93bf00")
    static let scoreOk = Color(hex: "#f58a1f")
    static let scoreLow = Color(hex: "#f3b329")
    static let scoreBad = Color(hex: "#e15d4f")

    // Chart line colors. `grid` sits inside the plot (over the fixed white chart
    // base) and stays identical in both modes; only the axis labels around it, on
    // the sheet, are adaptive so they stay legible on dark.
    static let grid = Color(hex: "#dce3ea")
    static let axisLabel = Color(lightHex: "#697586", darkHex: "#9AA4B2")

    /// Outer border of the chart plot. Darker in dark mode so the white chart
    /// area gets a clear edge against the dark sheet; the inner gridlines stay
    /// light (`grid`) because they sit over the white area.
    static let chartBorder = Color(lightHex: "#dce3ea", darkHex: "#3A414C")

    /// Fixed light base behind the sky gradient in the chart. The cell colors are
    /// semi-transparent and designed to sit over white; without this base they
    /// would muddy over the dark surface in dark mode and hide the sun/sky colors.
    static let chartPlotBase = Color(hex: "#ffffff")
    static let tempAxisLabel = Color(hex: "#ff8a3d")
    static let nowMarker = Color(hex: "#ff3b30")

    // Radii
    static let radiusControl: CGFloat = 16
    static let radiusControlInner: CGFloat = 13
    static let radiusPanel: CGFloat = 18
    static let radiusSheet: CGFloat = 28
}

/// Maps a score to its badge color.
func scoreColor(_ score: Int) -> Color {
    if score >= 8 { return Tokens.scoreGood }
    if score >= 6 { return Tokens.scoreOk }
    if score >= 4 { return Tokens.scoreLow }
    return Tokens.scoreBad
}
