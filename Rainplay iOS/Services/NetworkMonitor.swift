import Foundation
import Network

// Offline detection via NWPathMonitor.

@Observable
final class NetworkMonitor {
    private(set) var isOffline = false

    /// Signals that the connection was restored so the app can reload.
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
