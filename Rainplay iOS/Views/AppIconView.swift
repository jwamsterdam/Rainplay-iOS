import SwiftUI

// Nagebouwde versie van public/app-icon.svg uit de PWA, in een 512×512-canvas.
// Wordt met ImageRenderer naar een 1024px PNG geëxporteerd voor de AppIcon.
struct AppIconView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#7cc4ff"), location: 0),
                    .init(color: Color(hex: "#f8fbff"), location: 1),
                ],
                startPoint: UnitPoint(x: 100.0 / 512, y: 60.0 / 512),
                endPoint: UnitPoint(x: 420.0 / 512, y: 470.0 / 512)
            )

            Circle()
                .fill(Color(hex: "#ffd76a"))
                .frame(width: 128, height: 128)
                .position(x: 344, y: 160)

            cloud
                .fill(Color.white.opacity(0.94))

            Path { p in
                p.move(to: CGPoint(x: 145, y: 384))
                p.addLine(to: CGPoint(x: 353, y: 384))
            }
            .stroke(Color(hex: "#3094f4"), style: StrokeStyle(lineWidth: 26, lineCap: .round))

            Path { p in
                p.move(to: CGPoint(x: 165, y: 430))
                p.addLine(to: CGPoint(x: 257, y: 430))
            }
            .stroke(Color(hex: "#3094f4").opacity(0.75), style: StrokeStyle(lineWidth: 26, lineCap: .round))
        }
        .frame(width: 512, height: 512)
    }

    // Port van het wolk-pad uit de SVG (relatieve cubic beziers → absolute punten).
    private var cloud: Path {
        var p = Path()
        p.move(to: CGPoint(x: 138, y: 316))
        p.addCurve(to: CGPoint(x: 70, y: 251), control1: CGPoint(x: 100, y: 316), control2: CGPoint(x: 70, y: 287))
        p.addCurve(to: CGPoint(x: 132, y: 186), control1: CGPoint(x: 70, y: 217), control2: CGPoint(x: 97, y: 189))
        p.addCurve(to: CGPoint(x: 231, y: 120), control1: CGPoint(x: 149, y: 146), control2: CGPoint(x: 187, y: 120))
        p.addCurve(to: CGPoint(x: 340, y: 216), control1: CGPoint(x: 287, y: 120), control2: CGPoint(x: 334, y: 162))
        p.addCurve(to: CGPoint(x: 414, y: 298), control1: CGPoint(x: 382, y: 221), control2: CGPoint(x: 414, y: 256))
        p.addCurve(to: CGPoint(x: 328, y: 382), control1: CGPoint(x: 414, y: 344), control2: CGPoint(x: 376, y: 382))
        p.addLine(to: CGPoint(x: 138, y: 382))
        p.closeSubpath()
        return p
    }
}

#Preview {
    AppIconView()
}
