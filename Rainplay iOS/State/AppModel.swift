import Foundation
import Observation
import os

/// Central app state. Persists selection and settings (including colors, layers,
/// and twilight) via UserDefaults.
@MainActor
@Observable
final class AppModel {
    // MARK: - Selection

    var selectedDay: DayOption = .vandaag {
        didSet {
            // The time horizon applies only to Today; otherwise reset to full day.
            if selectedDay != .vandaag && selectedHorizon != .heleDag {
                selectedHorizon = .heleDag
            }
        }
    }

    var selectedHorizon: HorizonOption = .heleDag

    var selectedLocation: ForecastLocation {
        didSet {
            persist(selectedLocation, key: Keys.selectedLocation)
            guard oldValue.latitude != selectedLocation.latitude
                || oldValue.longitude != selectedLocation.longitude else { return }
            // New coordinates: drop the cache and reload.
            forecast = nil
            dataTimestamp = nil
            Task { await loadForecast() }
        }
    }

    var savedLocations: [ForecastLocation] {
        didSet { persist(savedLocations, key: Keys.savedLocations) }
    }

    /// Maximum number of manually saved locations; beyond this the user must
    /// remove one before adding a new one.
    let maxSavedLocations = 5

    var canAddLocation: Bool { savedLocations.count < maxSavedLocations }

    // MARK: - Settings (persistent)

    var cellColors: CellColors {
        didSet { persist(cellColors, key: Keys.cellColors) }
    }

    var showTemp: Bool { didSet { defaults.set(showTemp, forKey: Keys.showTemp) } }
    var showRain: Bool { didSet { defaults.set(showRain, forKey: Keys.showRain) } }
    var showIcons: Bool { didSet { defaults.set(showIcons, forKey: Keys.showIcons) } }

    /// W/m² threshold below which the twilight blend is active (Settings slider).
    var twilightRadiation: Double {
        didSet { defaults.set(twilightRadiation, forKey: Keys.twilightRadiation) }
    }

    /// Preferred temperature unit; canonical data stays in Celsius, this applies
    /// only at the presentation boundary. Stored as a rawValue string.
    var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }

    /// Preferred time notation (12/24-hour); canonical times stay as `isoTime`,
    /// this applies only at the presentation boundary. Stored as a rawValue string.
    var timeFormat: TimeFormat {
        didSet { defaults.set(timeFormat.rawValue, forKey: Keys.timeFormat) }
    }

    /// Preferred date notation; applies only at the presentation boundary.
    var dateFormat: DateStyle {
        didSet { defaults.set(dateFormat.rawValue, forKey: Keys.dateFormat) }
    }

    // MARK: - Forecast state

    private(set) var forecast: Forecast?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var dataTimestamp: Date?

    /// On a cold start with GPS, loading waits until the location has settled, so
    /// it does not fetch first for the placeholder default and again for the real
    /// GPS coordinates.
    private(set) var locationResolved = false

    let locationService: any LocationProviding
    let networkMonitor = NetworkMonitor()

    private let defaults: UserDefaults
    /// Injectable (dependency inversion) so tests can supply fakes without real
    /// network/GPS access. Defaults to the real clients.
    private let forecastProvider: any ForecastProviding
    /// Injectable clock so the 5-minute freshness window is deterministically testable.
    private let now: () -> Date

    /// Single clock source for the UI: views read this instead of calling `Date()`
    /// in their body, so the header and chart share the same "now" and stay
    /// injectable in previews/tests.
    var currentDate: Date { now() }
    private var loadTask: Task<Void, Never>?
    /// Incremented on each new load; only the load with the current number may
    /// write state. A cancelled/stale fetch (e.g. after a location change) can no
    /// longer overwrite anything.
    private var loadGeneration = 0

    /// Data is fresh for 5 minutes; after that, returning to the app or restoring
    /// the connection triggers a new fetch.
    private let staleInterval: TimeInterval = 5 * 60

    private enum Keys {
        static let selectedLocation = "rainplay.selectedLocation"
        static let savedLocations = "rainplay.savedLocations"
        static let cellColors = "rainplay.cellColors"
        static let showTemp = "rainplay.showTemp"
        static let showRain = "rainplay.showRain"
        static let showIcons = "rainplay.showIcons"
        static let twilightRadiation = "rainplay.twilightRadiation"
        static let temperatureUnit = "rainplay.temperatureUnit"
        static let timeFormat = "rainplay.timeFormat"
        static let dateFormat = "rainplay.dateFormat"
    }

    init(
        defaults: UserDefaults = .standard,
        forecastProvider: (any ForecastProviding)? = nil,
        locationProvider: (any LocationProviding)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        // Construct the concrete clients here rather than as default arguments:
        // under MainActor isolation their init is @MainActor, and default
        // arguments are evaluated nonisolated.
        self.forecastProvider = forecastProvider ?? OpenMeteoClient()
        self.locationService = locationProvider ?? LocationService()
        self.now = now
        selectedLocation = Self.restore(ForecastLocation.self, key: Keys.selectedLocation, from: defaults)
            ?? .defaultLocation
        savedLocations = Self.restore([ForecastLocation].self, key: Keys.savedLocations, from: defaults) ?? []
        cellColors = Self.restore(CellColors.self, key: Keys.cellColors, from: defaults) ?? .defaults
        showTemp = defaults.object(forKey: Keys.showTemp) as? Bool ?? true
        showRain = defaults.object(forKey: Keys.showRain) as? Bool ?? true
        showIcons = defaults.object(forKey: Keys.showIcons) as? Bool ?? true
        twilightRadiation = defaults.object(forKey: Keys.twilightRadiation) as? Double
            ?? defaultTwilightRadiationWm2
        temperatureUnit = (defaults.string(forKey: Keys.temperatureUnit)
            .flatMap(TemperatureUnit.init(rawValue:))) ?? .system
        timeFormat = (defaults.string(forKey: Keys.timeFormat)
            .flatMap(TimeFormat.init(rawValue:))) ?? .system
        dateFormat = (defaults.string(forKey: Keys.dateFormat)
            .flatMap(DateStyle.init(rawValue:))) ?? .system

        networkMonitor.onReconnect = { [weak self] in
            Task { await self?.loadForecastIfStale() }
        }
    }

    // MARK: - Lifecycle

    /// Cold start: try GPS once when there is no saved location, then load the
    /// forecast exactly once.
    func start() async {
        guard !locationResolved else { return }

        // UI tests launch with this argument to skip the CoreLocation permission
        // prompt (which would block automation on a clean simulator); fall back
        // to the stored/default location and just load.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingSkipLocation") {
            locationResolved = true
            await loadForecast()
            return
        }

        if selectedLocation.source == .fallback {
            // refreshLocation() sets selectedLocation and already triggers a fetch
            // there; setting locationResolved first avoids a duplicate.
            locationResolved = true
            let hadLocation = (try? await refreshLocation()) != nil
            if !hadLocation {
                await loadForecast()
            }
        } else {
            locationResolved = true
            await loadForecast()
        }
    }

    /// App returns to the foreground (scenePhase → .active).
    func appBecameActive() async {
        await loadForecastIfStale()
    }

    // MARK: - Location

    @discardableResult
    func refreshLocation() async throws -> ForecastLocation {
        let location = try await locationService.currentLocation()
        selectedLocation = location
        return location
    }

    /// Selects a location and saves it if not already stored. Returns false when
    /// the save limit is reached for a new location; the selection then stays
    /// unchanged so the UI can show feedback.
    @discardableResult
    func chooseLocation(_ location: ForecastLocation) -> Bool {
        if savedLocations.contains(where: { ForecastLocation.isSame($0, location) }) {
            selectedLocation = location
            return true
        }
        guard canAddLocation else { return false }
        savedLocations.append(location)
        selectedLocation = location
        return true
    }

    func deleteLocation(_ location: ForecastLocation) {
        savedLocations.removeAll { ForecastLocation.isSame($0, location) }
        if ForecastLocation.isSame(selectedLocation, location) {
            selectedLocation = savedLocations.first ?? .defaultLocation
        }
    }

    // MARK: - Loading the forecast

    func loadForecast() async {
        // Cancel any in-flight load and start one for the current selectedLocation.
        // The generation guard in performLoad keeps the cancelled load from writing state.
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        let task = Task { await performLoad(generation: generation) }
        loadTask = task
        await task.value
    }

    func loadForecastIfStale() async {
        guard locationResolved else { return }
        // If a load is already running, join it instead of sending a second
        // request (covers rapid foreground + reconnect).
        if let loadTask {
            await loadTask.value
            return
        }
        if let dataTimestamp, forecast != nil,
           now().timeIntervalSince(dataTimestamp) < staleInterval {
            return
        }
        await loadForecast()
    }

    func retry() {
        Task { await loadForecast() }
    }

    private func performLoad(generation: Int) async {
        guard generation == loadGeneration else { return }
        if forecast == nil { isLoading = true }
        loadFailed = false

        // A dropped mobile connection is retried twice more with increasing delay;
        // a 4xx (especially 429 rate-limit) is not, to avoid hammering an
        // overloaded API.
        let location = selectedLocation
        var attempt = 0
        var loaded: Forecast?
        var didFail = false
        while true {
            if Task.isCancelled { break }
            do {
                loaded = try await forecastProvider.fetchForecast(location)
                break
            } catch is CancellationError {
                break
            } catch let error as URLError where error.code == .cancelled {
                break
            } catch {
                if let status = (error as? ForecastError)?.status, (400..<500).contains(status) {
                    didFail = true
                    break
                }
                if attempt >= 2 {
                    didFail = true
                    break
                }
                let delay = min(pow(2, Double(attempt)), 8)
                try? await Task.sleep(for: .seconds(delay))
                attempt += 1
            }
        }

        // Only the current (non-cancelled/replaced) load may set state.
        guard generation == loadGeneration else { return }
        if let loaded {
            forecast = loaded
            dataTimestamp = now()
        } else if didFail {
            loadFailed = true
            AppLog.state.error("Forecast laden definitief mislukt na \(attempt + 1, privacy: .public) poging(en)")
        }
        isLoading = false
        loadTask = nil
    }

    // MARK: - Persistence helpers

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func restore<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
