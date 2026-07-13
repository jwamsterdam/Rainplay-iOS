import Foundation
import os

// Gratis, sleutelloze geocoding via Open-Meteo (dezelfde provider als de
// forecast). Geport uit de PWA (src/api/geocoding.ts). Geeft meerdere
// kandidaten terug zodat het locatieveld autocomplete-suggesties kan tonen.
// Zie https://open-meteo.com/en/docs/geocoding-api

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

    // Begrens het verzoek zodat een hangende mobiele verbinding de zoek-Task niet
    // eindeloos laat wachten (zelfde bescherming als OpenMeteoClient).
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 10

    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        AppLog.network.error("Geocoding gaf HTTP \(http.statusCode, privacy: .public)")
        throw GeocodingError.httpStatus(http.statusCode)
    }

    let decoded: GeocodingResponse
    do {
        decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
    } catch {
        AppLog.network.error("Geocoding decode mislukt: \(error.localizedDescription, privacy: .public)")
        throw GeocodingError.unexpectedStructure
    }
    guard let results = decoded.results else { return [] }

    return results.map { result in
        ForecastLocation(
            id: "geo-\(result.id)",
            // Alleen de plaatsnaam — de header toont die letterlijk. Het land
            // blijft apart zodat de zoeklijst "Plaats, Land" kan tonen zonder
            // provincie-ruis.
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
    (value * 10_000).rounded() / 10_000
}
