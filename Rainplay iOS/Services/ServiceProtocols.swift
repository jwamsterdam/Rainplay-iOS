import Foundation

// Abstracties voor de externe afhankelijkheden van AppModel (dependency
// inversion). Zo is de app-state te testen met nep-implementaties, zonder echte
// netwerk- of GPS-toegang, en zijn de concrete clients verwisselbaar.

@MainActor
protocol ForecastProviding {
    func fetchForecast(_ location: ForecastLocation) async throws -> Forecast
}

protocol LocationProviding: AnyObject {
    var status: LocationStatus { get }
    var errorMessage: String? { get }
    func currentLocation() async throws -> ForecastLocation
}
