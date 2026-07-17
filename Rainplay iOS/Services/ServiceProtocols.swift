import Foundation

// Abstractions for AppModel's external dependencies (dependency inversion), so app
// state can be tested with fake implementations without real network or GPS access,
// and the concrete clients stay interchangeable.

@MainActor
protocol ForecastProviding {
    func fetchForecast(_ location: ForecastLocation) async throws -> Forecast
}

protocol LocationProviding: AnyObject {
    var status: LocationStatus { get }
    var errorMessage: String? { get }
    func currentLocation() async throws -> ForecastLocation
}
