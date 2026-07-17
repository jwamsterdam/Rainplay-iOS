import SwiftUI
import UIKit

// Ontwerp-tokens geport uit de PWA (src/design/tokens.css). Kleuren, radii en
// spacing die door de views gedeeld worden. SF Pro (het systeemfont) vervangt
// Inter — dat is de native, meegeleverde variant.
//
// Kleuren zijn dynamisch: ze lossen per interface-stijl (licht/donker) op, zodat
// de views automatisch meebewegen met de systeem-instelling. De luchtfoto in de
// hero blijft in beide modi gelijk; alleen de overlay/tekst/oppervlakken wisselen.

extension Color {
    // Dynamische kleur die licht/donker oplost via de trait-collectie.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // Zelfde, maar direct vanuit twee hex-strings voor beknopte token-definities.
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
    // Tekstkleuren (donker op licht ↔ licht op donker).
    static let ink = Color(lightHex: "#101828", darkHex: "#E6EAF1")
    static let inkStrong = Color(lightHex: "#091526", darkHex: "#F4F7FB")
    static let inkMuted = Color(lightHex: "#697586", darkHex: "#9AA4B2")
    static let inkSoft = Color(lightHex: "#8a95a4", darkHex: "#7C8695")

    // Hero-tekstkleuren. Licht: donkerblauw over de heldere luchtfoto. Donker:
    // wit over het donkere scrim dat diezelfde foto dimt (zie WeatherScreen).
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

    // Oppervlakken. surface = de grote "decision sheet" + panelen; control = de
    // lichte besturingsvlakken (segmented-track, knoppen, kaartjes).
    static let surface = Color(lightHex: "#ffffff", darkHex: "#1B1E25")
    static let control = Color(lightHex: "#f3f6f9", darkHex: "#23262E")
    // De actieve thumb in de segmented control: net lichter dan de track zodat
    // hij in beide modi "opduikt" (in donker mag surface niet dezelfde tint zijn).
    static let segmentThumb = Color(lightHex: "#ffffff", darkHex: "#363B45")
    static let accent = Color(lightHex: "#1d7eea", darkHex: "#4A9BF5")
    static let rain = Color(hex: "#78b4f8")
    static let temperature = Color(hex: "#f97316")
    static let best = Color(lightHex: "#fff1c9", darkHex: "#3E3620")
    static let border = Color(
        light: Color(red: 220 / 255, green: 228 / 255, blue: 236 / 255, opacity: 0.88),
        dark: Color(white: 1, opacity: 0.14)
    )

    // Inactieve segment-tekst en de subtiele rand rond de segmented-track.
    static let segmentInactive = Color(lightHex: "#4b5565", darkHex: "#AEB6C2")
    static let segmentTrackStroke = Color(
        light: Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255, opacity: 0.74),
        dark: Color(white: 1, opacity: 0.10)
    )

    // Score-kleuren (chartHelpers.ts) — semantisch, gelijk in beide modi.
    static let scoreGood = Color(hex: "#93bf00")
    static let scoreOk = Color(hex: "#f58a1f")
    static let scoreLow = Color(hex: "#f3b329")
    static let scoreBad = Color(hex: "#e15d4f")

    // Grafiek-lijnkleuren. `grid` ligt binnen de plot (over de vaste witte basis
    // van de grafiek) en blijft daarom in beide modi gelijk; alleen de aslabels
    // eromheen — op de sheet — worden adaptief zodat ze op donker leesbaar zijn.
    static let grid = Color(hex: "#dce3ea")
    static let axisLabel = Color(lightHex: "#697586", darkHex: "#9AA4B2")

    // Vaste lichte basis áchter de lucht-gradient in de grafiek. De celkleuren
    // zijn semi-transparant en werden ontworpen om over wit te liggen; zonder
    // deze basis zouden ze in dark mode over het donkere oppervlak vertroebelen
    // en zou je de zon-/luchtkleuren niet meer zien.
    static let chartPlotBase = Color(hex: "#ffffff")
    static let tempAxisLabel = Color(hex: "#ff8a3d")
    static let nowMarker = Color(hex: "#ff3b30")

    // Radii
    static let radiusControl: CGFloat = 16
    static let radiusControlInner: CGFloat = 13
    static let radiusPanel: CGFloat = 18
    static let radiusSheet: CGFloat = 28
}

// Score → badge-kleur (chartHelpers.ts scoreColor).
func scoreColor(_ score: Int) -> Color {
    if score >= 8 { return Tokens.scoreGood }
    if score >= 6 { return Tokens.scoreOk }
    if score >= 4 { return Tokens.scoreLow }
    return Tokens.scoreBad
}
