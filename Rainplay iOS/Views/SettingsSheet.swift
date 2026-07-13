import SwiftUI

// Instellingen (src/components/SettingsPanel.tsx), zonder het diagnostiek-blok.
// Lagen aan/uit, schemering-drempel en de vijf grafiekkleuren met native
// ColorPicker + intensiteit-slider.
struct SettingsSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    // Versie + build uit de app-bundle (MARKETING_VERSION / CURRENT_PROJECT_VERSION),
    // zodat gebruikers bij een issue kunnen doorgeven op welke versie ze zitten.
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
                    layersSection
                    twilightSection
                    Text("Tik op het kleurvlak om de kleur te kiezen. Sleep de schuifregelaar voor de intensiteit.")
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.inkMuted)
                    colorList
                    Button {
                        dismiss()
                    } label: {
                        Text("Klaar")
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
            .navigationTitle("Grafiekkleuren")
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

    private var layersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grafiek lagen").font(.system(size: 15, weight: .semibold))
            HStack(spacing: 8) {
                LayerToggle(label: "Temperatuur", color: Tokens.temperature, isOn: $model.showTemp)
                LayerToggle(label: "Neerslag", color: Tokens.rain, isOn: $model.showRain)
                LayerToggle(label: "Iconen", color: Color(hex: "#64748b"), isOn: $model.showIcons)
            }
        }
    }

    private var twilightSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schemering drempel").font(.system(size: 15, weight: .semibold))
            HStack(spacing: 12) {
                Slider(value: $model.twilightRadiation, in: 1...200, step: 1)
                    .tint(Tokens.accent)
                Text("\(Int(model.twilightRadiation)) W/m²")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tokens.inkMuted)
                    .frame(width: 64, alignment: .trailing)
            }
            Text("Lager = scherpere overgang · standaard 20")
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
    let label: String
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
                Text(key.label).font(.system(size: 15, weight: .medium))
                Spacer()
                ColorPicker("", selection: swatchBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            HStack(spacing: 10) {
                Slider(value: alphaBinding, in: 0...1)
                    .tint(Tokens.accent)
                Text("\(Int((color.a * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.inkMuted)
                    .frame(width: 36, alignment: .trailing)
            }
            Text(color.css)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Tokens.control, in: RoundedRectangle(cornerRadius: 14))
    }

    // Kleurvlak wijzigt r/g/b maar behoudt de alpha (zoals de PWA).
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
