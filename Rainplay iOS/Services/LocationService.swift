import CoreLocation
import Foundation
import os

// GPS plus place name. CLGeocoder handles reverse geocoding, so no API key is needed.

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
        // City-level accuracy is enough for a weather report and saves battery.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    private struct LocationFailure: Error {
        var message: String
        var denied: Bool
    }

    /// Resolves the current GPS location, including a place name via reverse geocoding.
    /// Throws on denial or failure; the status and error-message properties are already
    /// set by then.
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
            AppLog.location.notice("Location denied/failed: \(failure.message, privacy: .public)")
            throw failure
        } catch {
            status = .error
            errorMessage = "Locatie ophalen lukte niet."
            AppLog.location.error("Location fetch failed: \(error.localizedDescription, privacy: .public)")
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

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
