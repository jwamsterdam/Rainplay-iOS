import Foundation
import os

// Free, keyless geocoding via Open-Meteo (same provider as the forecast). Returns
// multiple candidates so the location field can show autocomplete suggestions.
// See https://open-meteo.com/en/docs/geocoding-api

private let searchURL = "https://geocoding-api.open-meteo.com/v1/search"

let minLocationQueryLength = 2

private struct GeocodingResponse: Decodable {
    struct Result: Decodable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
    }

    let results: [Result]?
}

enum GeocodingError: Error {
    case httpStatus(Int)
    case unexpectedStructure
}

func searchLocations(_ query: String) async throws -> [ForecastLocation] {
    let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard search.count >= minLocationQueryLength else { return [] }

    var components = URLComponents(string: searchURL)!
    components.queryItems = [
        URLQueryItem(name: "name", value: search),
        URLQueryItem(name: "count", value: "6"),
        URLQueryItem(name: "language", value: "nl"),
        URLQueryItem(name: "format", value: "json"),
    ]

    // Bound the request so a stalled mobile connection can't leave the search Task
    // waiting forever (same protection as OpenMeteoClient).
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 10

    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        AppLog.network.error("Geocoding returned HTTP \(http.statusCode, privacy: .public)")
        throw GeocodingError.httpStatus(http.statusCode)
    }

    let decoded: GeocodingResponse
    do {
        decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
    } catch {
        AppLog.network.error("Geocoding decode failed: \(error.localizedDescription, privacy: .public)")
        throw GeocodingError.unexpectedStructure
    }
    guard let results = decoded.results else { return [] }

    return results.map { result in
        ForecastLocation(
            id: "geo-\(result.id)",
            // Place name only — the header shows it verbatim. Country stays separate so
            // the search list can render "City, Country" without province noise.
            name: result.name,
            country: result.country,
            latitude: roundCoordinate(result.latitude),
            longitude: roundCoordinate(result.longitude),
            source: .manual,
            updatedAt: Date().timeIntervalSince1970 * 1000
        )
    }
}

func roundCoordinate(_ value: Double) -> Double {
    (value * 10000).rounded() / 10000
}
