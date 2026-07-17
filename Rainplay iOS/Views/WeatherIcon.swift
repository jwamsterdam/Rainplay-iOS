import SwiftUI

/// Weather icons rendered with multicolor SF Symbols for a native, Apple Weather-like look.
struct WeatherIcon: View {
    let kind: WeatherKind
    var size: CGFloat = 22

    /// Explicit per-layer colors instead of `.multicolor`, which renders the cloud
    /// near-white and makes overcast hours invisible on the light row.
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

/// Icon for the settings color rows (including "Night").
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
}
