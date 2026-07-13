import CoreLocation
import Foundation
import os

// GPS + plaatsnaam, vervangt useCurrentLocation.ts + googleMaps.ts uit de PWA.
// CLGeocoder doet de reverse geocoding — geen Google Maps API-key meer nodig.

enum LocationStatus {
    case idle
    case locating
    case ready
    case denied
    case unsupported
    case error
}

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate, LocationProviding {
    private(set) var status: LocationStatus = .idle
    private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        // Plaatsnauwkeurigheid volstaat voor een weerbericht (de PWA gebruikte
        // ook enableHighAccuracy: false) en spaart batterij.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    private struct LocationFailure: Error {
        var message: String
        var denied: Bool
    }

    /// Vraagt de huidige GPS-locatie op, inclusief plaatsnaam via reverse
    /// geocoding. Gooit bij weigering of falen; de status/foutmelding-props
    /// zijn dan al gezet met dezelfde Nederlandse teksten als de PWA.
    func currentLocation() async throws -> ForecastLocation {
        status = .locating
        errorMessage = nil

        do {
            try await ensureAuthorization()

            let location = try await withCheckedThrowingContinuation { continuation in
                locationContinuation = continuation
                manager.requestLocation()
            }

            let latitude = roundCoordinate(location.coordinate.latitude)
            let longitude = roundCoordinate(location.coordinate.longitude)
            var name = "Huidige locatie"
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                name = placemark.locality
                    ?? placemark.subAdministrativeArea
                    ?? placemark.administrativeArea
                    ?? "Huidige locatie"
            }

            status = .ready
            return ForecastLocation(
                id: "gps",
                name: name,
                latitude: latitude,
                longitude: longitude,
                source: .gps,
                updatedAt: Date().timeIntervalSince1970 * 1000
            )
        } catch let failure as LocationFailure {
            status = failure.denied ? .denied : .error
            errorMessage = failure.message
            AppLog.location.notice("Locatie geweigerd/gefaald: \(failure.message, privacy: .public)")
            throw failure
        } catch {
            status = .error
            errorMessage = "Locatie ophalen lukte niet."
            AppLog.location.error("Locatie ophalen mislukt: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func ensureAuthorization() async throws {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return
        case .denied, .restricted:
            throw LocationFailure(message: "Geen locatietoegang.", denied: true)
        default:
            throw LocationFailure(message: "Locatie ophalen lukte niet.", denied: false)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
