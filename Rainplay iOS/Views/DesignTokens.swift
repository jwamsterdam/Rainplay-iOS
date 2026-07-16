import SwiftUI

// Ontwerp-tokens geport uit de PWA (src/design/tokens.css). Kleuren, radii en
// spacing die door de views gedeeld worden. SF Pro (het systeemfont) vervangt
// Inter — dat is de native, meegeleverde variant.

extension Color {
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
    // Kleuren
    static let ink = Color(hex: "#101828")
    static let inkStrong = Color(hex: "#091526")
    static let inkMuted = Color(hex: "#697586")
    static let inkSoft = Color(hex: "#8a95a4")

    // Hero-tekstkleuren (donkerblauw met afnemende dekking), voorheen inline.
    static let heroDayLabel = Color(red: 15 / 255, green: 30 / 255, blue: 52 / 255, opacity: 0.76)
    static let heroDateLabel = Color(red: 15 / 255, green: 30 / 255, blue: 52 / 255, opacity: 0.62)
    static let heroSubtitle = Color(red: 14 / 255, green: 31 / 255, blue: 52 / 255, opacity: 0.68)

    static let surface = Color(hex: "#ffffff")
    static let control = Color(hex: "#f3f6f9")
    static let accent = Color(hex: "#1d7eea")
    static let rain = Color(hex: "#78b4f8")
    static let temperature = Color(hex: "#f97316")
    static let best = Color(hex: "#fff1c9")
    static let border = Color(red: 220 / 255, green: 228 / 255, blue: 236 / 255, opacity: 0.88)

    // Score-kleuren (chartHelpers.ts)
    static let scoreGood = Color(hex: "#93bf00")
    static let scoreOk = Color(hex: "#f58a1f")
    static let scoreLow = Color(hex: "#f3b329")
    static let scoreBad = Color(hex: "#e15d4f")

    // Grafiek-lijnkleuren
    static let grid = Color(hex: "#dce3ea")
    static let axisLabel = Color(hex: "#697586")
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

// "08:00" → "8:00" (chartHelpers.ts formatTick); dagnamen blijven ongewijzigd.
func formatTick(_ t: String) -> String {
    guard t.contains(":") else { return t }
    let parts = t.split(separator: ":")
    let hh = Int(parts.first ?? "0") ?? 0
    let mm = parts.count > 1 ? String(parts[1]) : "00"
    return "\(hh):\(mm)"
}
