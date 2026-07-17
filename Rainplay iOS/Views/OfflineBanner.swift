import SwiftUI

/// Banner shown only when the network is unavailable.
struct OfflineBanner: View {
    let isOffline: Bool

    var body: some View {
        if isOffline {
            Text("offline.banner")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(hex: "#f59e0b"))
        }
    }
}
