import SwiftUI

/// Capsule segmented control: a light gray track with a shadowed thumb that
/// animates to the active option via matchedGeometryEffect.
struct SegmentedControl<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> LocalizedStringKey
    var disabled: Bool = false

    @Namespace private var indicator
    /// Scales with the Dynamic Type preference, relative to .body.
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
                        // label is a LocalizedStringKey; unit symbols (°C/°F) and
                        // some abbreviations are language-neutral and stored as
                        // key == value in the catalog.
                        .font(.system(size: fontSize, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(isActive ? Tokens.ink : Tokens.segmentInactive)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: Tokens.radiusControlInner)
                                    .fill(Tokens.segmentThumb)
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
                .stroke(Tokens.segmentTrackStroke, lineWidth: 1)
        )
        .opacity(disabled ? 0.62 : 1)
    }
}
