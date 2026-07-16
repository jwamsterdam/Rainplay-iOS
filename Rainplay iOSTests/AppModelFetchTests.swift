import Foundation
@testable import Rainplay_iOS
import Testing

// Tests voor het fetch-beleid van AppModel: 5-min-versheid, meeliften op een
// lopende load, annuleren-bij-locatiewissel (de generatie-guard), retry/back-off,
// géén retry bij 4xx, en het GPS-pad in start(). Gebruikt nep-implementaties van
// ForecastProviding/LocationProviding + een injecteerbare klok — geen echte
// netwerk-/GPS-toegang.
@MainActor
struct AppModelFetchTests {
    // Nep-forecastbron die een closure aanroept (telt calls, kan fouten gooien).
    @MainActor final class StubForecastProvider: ForecastProviding {
        let handler: (ForecastLocation) async throws -> Forecast
        init(_ handler: @escaping (ForecastLocation) async throws -> Forecast) { self.handler = handler }
        func fetchForecast(_ location: ForecastLocation) async throws -> Forecast { try await handler(location) }
    }

    // Forecastbron waarvan calls kunnen blokkeren op een continuation of meteen
    // teruggeven — nodig om de generatie-guard deterministisch te testen.
    @MainActor final class Gate: ForecastProviding {
        var calls: [ForecastLocation] = []
        var immediate: [Int: Forecast] = [:]
        private var conts: [Int: CheckedContinuation<Forecast, Error>] = [:]

        func fetchForecast(_ location: ForecastLocation) async throws -> Forecast {
            let index = calls.count
            calls.append(location)
            if let forecast = immediate[index] { return forecast }
            return try await withCheckedThrowingContinuation { conts[index] = $0 }
        }

        func finish(_ index: Int, with forecast: Forecast) {
            conts[index]?.resume(returning: forecast)
            conts[index] = nil
        }
    }

    // Nep-locatiebron die een vast resultaat teruggeeft (geen CoreLocation).
    final class StubLocationProvider: LocationProviding {
        private(set) var status: LocationStatus = .idle
        private(set) var errorMessage: String?
        private let result: Result<ForecastLocation, Error>
        init(_ result: Result<ForecastLocation, Error>) { self.result = result }
        func currentLocation() async throws -> ForecastLocation {
            switch result {
            case .success(let location): status = .ready; return location
            case .failure(let error): status = .denied; throw error
            }
        }
    }

    @MainActor final class CallLog {
        var locations: [ForecastLocation] = []
        var count: Int { locations.count }
    }

    @MainActor final class Clock {
        var value: Date
        init(_ value: Date) { self.value = value }
    }

    private func forecast(_ temperature: Int) -> Forecast {
        Forecast(currentTemperature: temperature, hourly: [], minutely15: [], sunriseTimes: [:], sunsetTimes: [:])
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "rainplay.tests.\(UUID().uuidString)")!
    }

    // Defaults met een reeds opgeslagen (niet-default) locatie, zodat start()
    // meteen "resolved" is en één keer laadt — zonder GPS.
    private func seededDefaults(_ location: ForecastLocation) -> UserDefaults {
        let d = defaults()
        if let encoded = try? JSONEncoder().encode(location) {
            d.set(encoded, forKey: "rainplay.selectedLocation")
        }
        return d
    }

    private func location(_ name: String, _ lat: Double, _ lon: Double, source: LocationSource = .manual) -> ForecastLocation {
        ForecastLocation(id: name, name: name, latitude: lat, longitude: lon, source: source)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Laadbeleid

    @Test func successStoresForecast() async {
        let log = CallLog()
        let model = AppModel(defaults: defaults(), forecastProvider: StubForecastProvider { loc in
            log.locations.append(loc); return self.forecast(21)
        })

        await model.loadForecast()

        #expect(log.count == 1)
        #expect(model.forecast?.currentTemperature == 21)
        #expect(model.isLoading == false)
        #expect(model.loadFailed == false)
    }

    @Test func freshDataSkipsRefetch() async {
        let log = CallLog()
        let clock = Clock(Date(timeIntervalSince1970: 1_000_000))
        let model = AppModel(defaults: seededDefaults(location("Seed", 5, 5)), forecastProvider: StubForecastProvider { loc in
            log.locations.append(loc); return self.forecast(21)
        }, now: { clock.value })

        await model.start()                  // laadt één keer, markeert resolved
        await model.loadForecastIfStale()    // klok onveranderd → nog vers

        #expect(log.count == 1)
    }

    @Test func staleDataTriggersRefetch() async {
        let log = CallLog()
        let clock = Clock(Date(timeIntervalSince1970: 1_000_000))
        let model = AppModel(defaults: seededDefaults(location("Seed", 5, 5)), forecastProvider: StubForecastProvider { loc in
            log.locations.append(loc); return self.forecast(21)
        }, now: { clock.value })

        await model.start()                                    // laadt één keer (t0)
        clock.value = clock.value.addingTimeInterval(6 * 60)   // +6 min → verouderd
        await model.loadForecastIfStale()

        #expect(log.count == 2)
    }

    @Test func fourxxDoesNotRetry() async {
        let log = CallLog()
        let model = AppModel(defaults: defaults(), forecastProvider: StubForecastProvider { loc in
            log.locations.append(loc)
            throw ForecastError.httpStatus(429)
        })

        await model.loadForecast()

        #expect(log.count == 1)           // geen retry op 429
        #expect(model.loadFailed == true)
        #expect(model.forecast == nil)
    }

    @Test func transientErrorRetriesThenFails() async {
        let log = CallLog()
        let model = AppModel(defaults: defaults(), forecastProvider: StubForecastProvider { loc in
            log.locations.append(loc)
            throw ForecastError.timeout
        })

        await model.loadForecast()

        #expect(log.count == 3)           // 1 poging + 2 retries
        #expect(model.loadFailed == true)
    }

    @Test func locationChangeIgnoresLateResultFromCancelledLoad() async {
        let gate = Gate()
        gate.immediate[1] = forecast(2)   // tweede call (locatie B) geeft meteen terug
        let model = AppModel(defaults: defaults(), forecastProvider: gate)

        // Locatie A: eerste call blokkeert op de continuation.
        model.selectedLocation = location("A", 1, 1)
        await waitUntil { gate.calls.count == 1 }

        // Locatie B: annuleert de lopende A-load en start B (die meteen teruggeeft).
        model.selectedLocation = location("B", 2, 2)
        await waitUntil { model.forecast?.currentTemperature == 2 }
        #expect(model.forecast?.currentTemperature == 2)

        // A voltooit alsnog (laat) met andere data — mag B niet overschrijven.
        gate.finish(0, with: forecast(1))
        await waitUntil { gate.calls.count >= 2 }
        #expect(model.forecast?.currentTemperature == 2)
    }

    // MARK: - start() met GPS

    @Test func startWithDefaultLocationResolvesViaGPSAndLoadsOnce() async {
        let log = CallLog()
        let gps = location("Testplaats", 1, 2, source: .gps)
        let model = AppModel(
            defaults: defaults(),                                  // geen opgeslagen locatie → source .default
            forecastProvider: StubForecastProvider { loc in log.locations.append(loc); return self.forecast(19) },
            locationProvider: StubLocationProvider(.success(gps))
        )

        await model.start()
        await waitUntil { model.forecast != nil }

        #expect(model.selectedLocation.source == .gps)
        #expect(model.selectedLocation.name == "Testplaats")
        #expect(log.count == 1)                                    // precies één fetch, voor de GPS-coördinaten
        #expect(log.locations.first?.latitude == 1)
    }

    @Test func startFallsBackToDefaultWhenGPSDenied() async {
        let log = CallLog()
        struct Denied: Error {}
        let model = AppModel(
            defaults: defaults(),
            forecastProvider: StubForecastProvider { loc in log.locations.append(loc); return self.forecast(18) },
            locationProvider: StubLocationProvider(.failure(Denied()))
        )

        await model.start()
        await waitUntil { model.forecast != nil }

        #expect(model.selectedLocation.source == .fallback)        // valt terug op Haarlem
        #expect(log.count == 1)
    }
}
