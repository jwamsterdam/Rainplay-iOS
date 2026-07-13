import Foundation
import Network

// Offline-detectie via NWPathMonitor, vervangt useNetworkStatus.ts uit de PWA.

@Observable
final class NetworkMonitor {
    private(set) var isOffline = false

    // Meldt herstel van de verbinding, zodat de app dan opnieuw kan laden
    // (zoals refetchOnReconnect in de PWA).
    var onReconnect: (() -> Void)?

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = self.isOffline
                self.isOffline = path.status != .satisfied
                if wasOffline && !self.isOffline {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "rainplay.network-monitor"))
    }
}
