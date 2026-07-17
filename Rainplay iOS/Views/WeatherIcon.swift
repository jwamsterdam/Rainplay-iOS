import SwiftUI

// Weericonen. De PWA tekent deze met inline-SVG's; hier gebruiken we native
// SF Symbols (multicolor) — dat sluit aan op de native-first-opzet en oogt
// consistent met Apple Weather. De symboolkeuze spiegelt de PWA-iconen.
struct WeatherIcon: View {
    let kind: WeatherKind
    var size: CGFloat = 22

    // Expliciete kleuren per laag i.p.v. .multicolor — die rendert de wolk
    // bijna wit, waardoor bewolkte uren onzichtbaar werden op de lichte rij.
    private let cloudGray = Color(hex: "#aab4c0")
    private let sunYellow = Color(hex: "#ffc93c")
    private let rainBlue = Color(hex: "#4f9cf4")

    var body: some View {
        icon
            .font(.system(size: size * 0.9))
            .frame(width: size, height: size)
            .accessibilityLabel(Text(kind.titleKey))
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .sun:
            Image(systemName: "sun.max.fill")
                .foregroundStyle(sunYellow)
        case .partly:
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(cloudGray, sunYellow)
        case .cloud:
            Image(systemName: "cloud.fill")
                .foregroundStyle(cloudGray)
        case .rain:
            Image(systemName: "cloud.rain.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(cloudGray, rainBlue)
        }
    }
}

// Icoon voor de instellingen-kleurenrijen (incl. "Nacht").
struct SettingsColorIcon: View {
    let key: SettingsColorKey

    private var symbol: String {
        switch key {
        case .sun: return "sun.max.fill"
        case .partly: return "cloud.sun.fill"
        case .cloud: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: 20))
            .frame(width: 24, height: 24)
    }
}

enum SettingsColorKey: String, CaseIterable, Identifiable {
    case sun, partly, cloud, rain, night
    var id: String { rawValue }

    // Gelokaliseerde weergavetitel leeft op de presentatiegrens:
    // SettingsColorKey.titleKey in LocalizedLabels.swift.
}
