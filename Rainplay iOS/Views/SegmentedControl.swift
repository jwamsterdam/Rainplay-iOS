import SwiftUI

// Capsule-segmented-control in PWA-stijl (src/components/SegmentedControl.tsx +
// .segmented in styles.css): lichtgrijs spoor, witte thumb met schaduw die met
// matchedGeometryEffect naar de actieve optie animeert.

struct SegmentedControl<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> LocalizedStringKey
    var disabled: Bool = false

    @Namespace private var indicator
    // Schaalt mee met de Dynamic Type-voorkeur (t.o.v. .body).
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let isActive = option == selection
                Button {
                    guard !disabled else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        // label is een LocalizedStringKey; unit-symbolen (°C/°F)
                        // en enkele afkortingen zijn taal-neutraal en staan als
                        // key == waarde in de catalog.
                        .font(.system(size: fontSize, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(isActive ? Tokens.ink : Color(hex: "#4b5565"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: Tokens.radiusControlInner)
                                    .fill(Tokens.surface)
                                    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                                    .shadow(color: .black.opacity(0.08), radius: 9, y: 4)
                                    .matchedGeometryEffect(id: "thumb", in: indicator)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                // Exposes the active segment to VoiceOver and UI tests.
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Tokens.radiusControl)
                .fill(Tokens.control)
                .stroke(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255, opacity: 0.74), lineWidth: 1)
        )
        .opacity(disabled ? 0.62 : 1)
    }
}
