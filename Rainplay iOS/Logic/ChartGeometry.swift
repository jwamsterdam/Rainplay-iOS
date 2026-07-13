import Foundation

// Pure grafiek-geometrie: de dubbele-as-normalisatie waarmee de temperatuurlijn
// op dezelfde y-schaal als de regen-bars past. Losgetrokken uit de DayChart-view
// zodat de rekenlogica (grenzen, ticks, terugrekenen) apart testbaar is —
// consistent met score/venster/gradient die ook pure helpers zijn.
struct ChartGeometry: Equatable {
    // Bovenkant van de regen-as (mm). Minimaal 3 mm — zo lijkt 1 mm niet ineens
    // "veel" — maar groeit mee zodra de neerslag daarboven komt, zodat balken
    // nooit boven de grafiek uitlopen.
    let rainMax: Double
    let tempMin: Double
    let tempMax: Double

    // Vaste ondergrens van de regen-as.
    static let minimumRainMax: Double = 3

    // Uit een expliciet temperatuurbereik + neerslagpiek (de gemeten data). Zo kan
    // één gedeelde geometrie over alle dag-panelen worden gebruikt, zodat de
    // grafieken vergelijkbaar zijn bij het swipen.
    //
    // Temp-marges: onder ≥1° afgerond op even graden (nette basis + ticks); boven
    // een strakke ~1° (niet opgerond naar even, dat gaf tot ~3° lucht) zodat de
    // lijn dicht bij de bovenrand komt en een warme dag ook echt "hoog" oogt.
    init(temperatureRange range: ClosedRange<Double>?, precipitationMax: Double?) {
        rainMax = max(Self.minimumRainMax, (precipitationMax ?? 0).rounded(.up))

        guard let range else {
            tempMin = 0
            tempMax = 20
            return
        }
        let lo = ((range.lowerBound - 1) / 2).rounded(.down) * 2
        let hi = (range.upperBound + 1).rounded(.up)
        tempMin = lo >= hi ? hi - 2 : lo         // vlakke reeks → toch een bereik
        tempMax = hi
    }

    // Gemak: één grafiek op basis van z'n eigen uren.
    init(hours: [HourlyWeather]) {
        self.init(
            temperatureRange: ChartGeometry.temperatureRange(in: hours),
            precipitationMax: ChartGeometry.precipitationMax(in: hours)
        )
    }

    // MARK: - Gemeten bereiken

    static func temperatureRange(in hours: [HourlyWeather]) -> ClosedRange<Double>? {
        temperatureRange(across: [hours])
    }

    // Gecombineerd temperatuurbereik over meerdere sets uren (gedeelde as).
    static func temperatureRange(across groups: [[HourlyWeather]]) -> ClosedRange<Double>? {
        let temps = groups.flatMap { $0.map(\.temperatureC) }
        guard let lo = temps.min(), let hi = temps.max() else { return nil }
        return lo...hi
    }

    static func precipitationMax(in hours: [HourlyWeather]) -> Double? {
        precipitationMax(across: [hours])
    }

    // Hoogste neerslag over meerdere sets uren (gedeelde as).
    static func precipitationMax(across groups: [[HourlyWeather]]) -> Double? {
        groups.flatMap { $0.map(\.precipitationMm) }.max()
    }

    // MARK: - Temperatuur (rechter-as)

    // °C → positie op het regen-domein (0...rainMax).
    func normalizedTemp(_ celsius: Double) -> Double {
        guard tempMax > tempMin else { return 0 }
        return (celsius - tempMin) / (tempMax - tempMin) * rainMax
    }

    // Even stappen vanaf tempMin, plus altijd de bovenste aswaarde (tempMax) zodat
    // de hoogste temperatuur zichtbaar is. Een tick vlak onder de top wordt
    // weggelaten om overlappende labels te voorkomen.
    var tempTicks: [Double] {
        let step = max(2, ((tempMax - tempMin) / 4 / 2).rounded() * 2)
        var ticks = Array(stride(from: tempMin, to: tempMax, by: step))
        if let last = ticks.last, tempMax - last < 2 { ticks.removeLast() }
        ticks.append(tempMax)
        return ticks
    }

    // Positie op het regen-domein → afgeronde °C (rechter-as-label terugrekenen).
    func temperature(atNormalized position: Double) -> Int {
        Int((tempMin + position / rainMax * (tempMax - tempMin)).rounded())
    }

    // MARK: - Neerslag (linker-as)

    // Tick-waarden voor de regen-as: 0..rainMax in nette hele stappen.
    var rainTicks: [Double] {
        let step = max(1, (rainMax / 3).rounded(.up))
        return Array(stride(from: 0, through: rainMax, by: step))
    }
}
