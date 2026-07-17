import Foundation
import os

/// Centralized os.Logger categories per layer. Visible in Console.app and the Xcode
/// console and filterable by subsystem/category, so issues can be diagnosed remotely
/// without surfacing technical detail in the UI.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Rainplay"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let state = Logger(subsystem: subsystem, category: "state")
}
