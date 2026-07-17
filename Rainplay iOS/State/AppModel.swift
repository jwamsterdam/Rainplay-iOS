import Foundation
import Observation
import os

// Centrale app-state, vervangt de Jotai-atoms + TanStack Query uit de PWA.
// Persistentie via UserDefaults (de gebruiker koos ervoor om, anders dan de
// PWA, óók kleuren/lagen/schemering te bewaren).

@MainActor
@Observable
final class AppModel {
    // MARK: - Selectie

    var selectedDay: DayOption = .vandaag {
        didSet {
            // Zelfde effect als in WeatherScreen.tsx: de tijdshorizon geldt
            // alleen voor Vandaag en springt anders terug naar "Hele dag".
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
            // Nieuwe coördinaten = nieuwe "queryKey": cache weggooien en opnieuw laden.
            forecast = nil
            dataTimestamp = nil
            Task { await loadForecast() }
        }
    }

    var savedLocations: [ForecastLocation] {
        didSet { persist(savedLocations, key: Keys.savedLocations) }
    }

    // Maximaal aantal handmatig opgeslagen locaties; daarboven moet de gebruiker
    // er eerst één verwijderen voordat een nieuwe kan worden toegevoegd.
    let maxSavedLocations = 5

    // Is er nog ruimte om een nieuwe locatie op te slaan?
    var canAddLocation: Bool { savedLocations.count < maxSavedLocations }

    // MARK: - Instellingen (persistent)

    var cellColors: CellColors {
        didSet { persist(cellColors, key: Keys.cellColors) }
    }

    var showTemp: Bool { didSet { defaults.set(showTemp, forKey: Keys.showTemp) } }
    var showRain: Bool { didSet { defaults.set(showRain, forKey: Keys.showRain) } }
    var showIcons: Bool { didSet { defaults.set(showIcons, forKey: Keys.showIcons) } }

    // W/m²-drempel waaronder de schemering-blend actief is (Settings-slider).
    var twilightRadiation: Double {
        didSet { defaults.set(twilightRadiation, forKey: Keys.twilightRadiation) }
    }

    // Voorkeur voor de temperatuureenheid; canonieke data blijft Celsius, dit
    // werkt alleen op de presentatiegrens. Bewaard als rawValue-string.
    var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }

    // Voorkeur voor de tijdnotatie (12/24-uurs); canonieke tijden blijven
    // isoTime, dit werkt alleen op de presentatiegrens. Bewaard als rawValue.
    var timeFormat: TimeFormat {
        didSet { defaults.set(timeFormat.rawValue, forKey: Keys.timeFormat) }
    }

    // Voorkeur voor de datumnotatie; werkt alleen op de presentatiegrens.
    var dateFormat: DateStyle {
        didSet { defaults.set(dateFormat.rawValue, forKey: Keys.dateFormat) }
    }

    // MARK: - Forecast-state

    private(set) var forecast: Forecast?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var dataTimestamp: Date?

    // Bij een koude start met GPS wachten we met laden tot de locatie
    // "settled" is, zodat er niet éérst voor de placeholder-default en daarna
    // nóg eens voor de echte GPS-coördinaten gefetcht wordt.
    private(set) var locationResolved = false

    let locationService: any LocationProviding
    let networkMonitor = NetworkMonitor()

    private let defaults: UserDefaults
    // Injecteerbaar (dependency inversion) zodat tests nep-implementaties kunnen
    // leveren zonder echte netwerk-/GPS-toegang. Standaard de echte clients.
    private let forecastProvider: any ForecastProviding
    // Injecteerbare klok zodat de 5-min-versheidsgrens deterministisch te testen is.
    private let now: () -> Date

    // Eén klokbron voor de UI: views lezen dit i.p.v. zelf Date() in hun body aan
    // te roepen, zodat de kop en de grafiek op dezelfde "nu" gebaseerd zijn en in
    // previews/tests injecteerbaar blijven.
    var currentDate: Date { now() }
    private var loadTask: Task<Void, Never>?
    // Loopt op bij elke nieuwe load; alleen de load met het actuele nummer mag
    // state wegschrijven. Zo kan een geannuleerde/verouderde fetch (bijv. na een
    // locatiewissel) niets meer overschrijven.
    private var loadGeneration = 0

    // Data is 5 min vers; daarna triggert terugkeer naar de app of herstel van
    // de verbinding een nieuwe fetch (zoals staleTime in de PWA).
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
        // De concrete clients hier construeren (niet als default-argument): onder
        // MainActor-isolatie is hun init @MainActor, en default-argumenten worden
        // nonisolated geëvalueerd.
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

    // MARK: - Levenscyclus

    /// Koude start: probeer eenmalig GPS wanneer er geen opgeslagen locatie is
    /// (zelfde gedrag als useCurrentLocation in de PWA), en laad daarna de
    /// forecast precies één keer.
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
            // refreshLocation() zet selectedLocation en triggert dáár al een
            // fetch; locationResolved eerst zetten voorkomt een dubbele.
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

    /// App komt terug naar de voorgrond (scenePhase → .active).
    func appBecameActive() async {
        await loadForecastIfStale()
    }

    // MARK: - Locatie

    @discardableResult
    func refreshLocation() async throws -> ForecastLocation {
        let location = try await locationService.currentLocation()
        selectedLocation = location
        return location
    }

    // Selecteert een locatie en bewaart hem indien nog niet opgeslagen. Geeft
    // false terug wanneer het opslaan-maximum bereikt is en het om een nieuwe
    // locatie gaat; de selectie verandert dan niet zodat de UI feedback kan tonen.
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

    // MARK: - Forecast laden

    func loadForecast() async {
        // Annuleer een eventuele lopende load (bijv. voor de vorige locatie) en
        // start er één voor de huidige selectedLocation. De generatie-guard in
        // performLoad zorgt dat de geannuleerde load geen state meer schrijft.
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        let task = Task { await performLoad(generation: generation) }
        loadTask = task
        await task.value
    }

    func loadForecastIfStale() async {
        guard locationResolved else { return }
        // Loopt er al een load? Lift dan mee i.p.v. een tweede request te sturen
        // (dekt snel achter elkaar foreground + reconnect af).
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
        // Al vervangen voordat we begonnen? Dan niets doen.
        guard generation == loadGeneration else { return }
        if forecast == nil { isLoading = true }
        loadFailed = false

        // Zelfde retry-beleid als de PWA: een afgebroken mobiele verbinding
        // wordt nog 2x geprobeerd met oplopende vertraging; een 4xx (vooral
        // 429 rate-limit) niet — dat hamert een overbelaste API alleen verder.
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

        // Alleen de actuele (niet-geannuleerde/vervangen) load mag state zetten.
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

    // MARK: - Persistentie-helpers

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
