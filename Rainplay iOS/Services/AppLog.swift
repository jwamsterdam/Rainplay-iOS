import Foundation
import os

// Gecentraliseerde os.Logger-categorieën per laag. Zichtbaar in Console.app en de
// Xcode-console, filterbaar op subsystem/category — zodat problemen bij anderen
// (of op afstand) te diagnosticeren zijn zonder de gebruiker met technische
// details lastig te vallen in de UI.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Rainplay"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let state = Logger(subsystem: subsystem, category: "state")
}
