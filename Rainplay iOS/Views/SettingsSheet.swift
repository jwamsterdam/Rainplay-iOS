import SwiftUI
import UIKit

/// Settings: layer toggles, the twilight threshold and the five chart colors
/// with a native ColorPicker and intensity slider.
struct SettingsSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Version and build from the app bundle, so users can report which version
    /// they're on when filing an issue.
    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Rainplay \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    temperatureSection
                    timeSection
                    dateSection
                    languageSection
                    layersSection
                    twilightSection
                    Text("settings.colorHelp")
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.inkMuted)
                    colorList
                    Button {
                        dismiss()
                    } label: {
                        Text("common.done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Tokens.accent, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
                    }
                    .buttonStyle(.plain)

                    Text(Self.versionString)
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("settings.chartColors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Tokens.inkMuted)
                    }
                }
            }
        }
    }

    /// Temperature unit: "System" derives the unit from the region (US → °F,
    /// elsewhere → °C); °C/°F force the choice. See MeasurementFormatting.
    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.temperature").font(.system(size: 15, weight: .semibold))
            SegmentedControl(
                options: TemperatureUnit.allCases,
                selection: $model.temperatureUnit,
                label: temperatureUnitLabel
            )
        }
    }

    private func temperatureUnitLabel(_ unit: TemperatureUnit) -> LocalizedStringKey {
        switch unit {
        case .system: return "common.system"
        case .celsius: return "unit.celsius"
        case .fahrenheit: return "unit.fahrenheit"
        }
    }

    /// Time format: "System" follows the device 12/24-hour setting; 12h/24h force
    /// the choice. Canonical times stay isoTime (TimeFormatting).
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.timeFormat").font(.system(size: 15, weight: .semibold))
            SegmentedControl(
                options: TimeFormat.allCases,
                selection: $model.timeFormat,
                label: timeFormatLabel
            )
        }
    }

    private func timeFormatLabel(_ format: TimeFormat) -> LocalizedStringKey {
        switch format {
        case .system: return "common.system"
        case .twelveHour: return "time.12h"
        case .twentyFourHour: return "time.24h"
        }
    }

    /// Date format: "System" follows the locale order including the weekday; the
    /// others choose whether to include the weekday, with an example for clarity.
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.dateFormat").font(.system(size: 15, weight: .semibold))
            SegmentedControl(
                options: DateStyle.allCases,
                selection: $model.dateFormat,
                label: dateStyleLabel
            )
        }
    }

    private func dateStyleLabel(_ style: DateStyle) -> LocalizedStringKey {
        switch style {
        case .system: return "common.system"
        case .dayMonth: return "date.example.dayMonth"
        case .weekdayDayMonth: return "date.example.weekdayDayMonth"
        }
    }

    /// Language selection goes through the iOS per-app language screen
    /// (Settings → App), which we open directly.
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.language").font(.system(size: 15, weight: .semibold))
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                HStack {
                    Text("settings.language.open")
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Tokens.accent)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Tokens.control, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
            }
            .buttonStyle(.plain)
            Text("settings.language.help")
                .font(.system(size: 13))
                .foregroundStyle(Tokens.inkMuted)
        }
    }

    private var layersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.chartLayers").font(.system(size: 15, weight: .semibold))
            HStack(spacing: 8) {
                LayerToggle(label: "layer.temperature", color: Tokens.temperature, isOn: $model.showTemp)
                LayerToggle(label: "layer.precipitation", color: Tokens.rain, isOn: $model.showRain)
                LayerToggle(label: "layer.icons", color: Color(hex: "#64748b"), isOn: $model.showIcons)
            }
        }
    }

    private var twilightSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.twilightThreshold").font(.system(size: 15, weight: .semibold))
            HStack(spacing: 12) {
                Slider(value: $model.twilightRadiation, in: 1...200, step: 1)
                    .tint(Tokens.accent)
                Text(verbatim: "\(Int(model.twilightRadiation)) W/m²")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tokens.inkMuted)
                    .frame(width: 64, alignment: .trailing)
            }
            Text("settings.twilightHelp")
                .font(.system(size: 13))
                .foregroundStyle(Tokens.inkMuted)
        }
    }

    private var colorList: some View {
        VStack(spacing: 10) {
            ForEach(SettingsColorKey.allCases) { key in
                ColorRow(
                    key: key,
                    color: binding(for: key)
                )
            }
        }
    }

    private func binding(for key: SettingsColorKey) -> Binding<RGBAColor> {
        Binding(
            get: { rgba(for: key) },
            set: { setRGBA($0, for: key) }
        )
    }

    private func rgba(for key: SettingsColorKey) -> RGBAColor {
        switch key {
        case .sun: return model.cellColors.sun
        case .partly: return model.cellColors.partly
        case .cloud: return model.cellColors.cloud
        case .rain: return model.cellColors.rain
        case .night: return model.cellColors.night
        }
    }

    private func setRGBA(_ value: RGBAColor, for key: SettingsColorKey) {
        switch key {
        case .sun: model.cellColors.sun = value
        case .partly: model.cellColors.partly = value
        case .cloud: model.cellColors.cloud = value
        case .rain: model.cellColors.rain = value
        case .night: model.cellColors.night = value
        }
    }
}

private struct LayerToggle: View {
    let label: LocalizedStringKey
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(isOn ? color.opacity(0.16) : Tokens.control, in: Capsule())
            .foregroundStyle(isOn ? Tokens.ink : Tokens.inkMuted)
            .overlay(Capsule().stroke(isOn ? color.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ColorRow: View {
    let key: SettingsColorKey
    @Binding var color: RGBAColor

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                SettingsColorIcon(key: key)
                Text(key.titleKey).font(.system(size: 15, weight: .medium))
                Spacer()
                ColorPicker("", selection: swatchBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            HStack(spacing: 10) {
                Slider(value: alphaBinding, in: 0...1)
                    .tint(Tokens.accent)
                Text(verbatim: "\(Int((color.a * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.inkMuted)
                    .frame(width: 36, alignment: .trailing)
            }
            Text(verbatim: color.css)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Tokens.control, in: RoundedRectangle(cornerRadius: 14))
    }

    /// The swatch changes r/g/b but preserves the alpha.
    private var swatchBinding: Binding<Color> {
        Binding(
            get: { Color(RGBAColor(r: color.r, g: color.g, b: color.b, a: 1)) },
            set: { newColor in
                let resolved = newColor.resolve(in: EnvironmentValues())
                color = RGBAColor(
                    r: Int((resolved.red * 255).rounded()),
                    g: Int((resolved.green * 255).rounded()),
                    b: Int((resolved.blue * 255).rounded()),
                    a: color.a
                )
            }
        )
    }

    private var alphaBinding: Binding<Double> {
        Binding(get: { color.a }, set: { color.a = ($0 * 100).rounded() / 100 })
    }
}
