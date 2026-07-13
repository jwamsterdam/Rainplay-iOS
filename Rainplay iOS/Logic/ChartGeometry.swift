import Foundation

// Pure grafiek-geometrie: de dubbele-as-normalisatie waarmee de temperatuurlijn
// op dezelfde y-schaal als de regen-bars past. Losgetrokken uit de DayChart-view
// zodat de rekenlogica (grenzen, ticks, terugrekenen) apart testbaar is —
// consistent met score/venster/gradient die ook pure helpers zijn.
struct ChartGeometry: Equatable {
    let maxMM: Double
    let tempMin: Double
    let tempMax: Double

    // Uit een expliciet temperatuurbereik (het gemeten data-min/max). Zo kan één
    // gedeelde geometrie over alle dag-panelen worden gebruikt, zodat de grafieken
    // vergelijkbaar zijn bij het swipen.
    //
    // Marges: onder ≥1° afgerond op even graden (nette basis + ticks); boven een
    // strakke ~1° (niet opgerond naar even, dat gaf tot ~3° lucht) zodat de lijn
    // dicht bij de bovenrand komt en een warme dag ook echt "hoog" oogt.
    init(temperatureRange range: ClosedRange<Double>?, maxMM: Double = 3) {
        self.maxMM = maxMM
        guard let range else {
            tempMin = 0
            tempMax = 20
            return
        }
        var lo = ((range.lowerBound - 1) / 2).rounded(.down) * 2
        let hi = (range.upperBound + 1).rounded(.up)
        if lo >= hi { lo = hi - 2 }                      // vlakke reeks → toch een bereik
        tempMin = lo
        tempMax = hi
    }

    // Gemak: één grafiek op basis van z'n eigen uren.
    init(hours: [HourlyWeather], maxMM: Double = 3) {
        self.init(temperatureRange: ChartGeometry.temperatureRange(in: hours), maxMM: maxMM)
    }

    // Het gemeten temperatuurbereik van één set uren (nil bij leeg).
    static func temperatureRange(in hours: [HourlyWeather]) -> ClosedRange<Double>? {
        let temps = hours.map(\.temperatureC)
        guard let lo = temps.min(), let hi = temps.max() else { return nil }
        return lo...hi
    }

    // Het gecombineerde bereik over meerdere sets uren (voor een gedeelde as over
    // alle dag-panelen).
    static func temperatureRange(across groups: [[HourlyWeather]]) -> ClosedRange<Double>? {
        let temps = groups.flatMap { $0.map(\.temperatureC) }
        guard let lo = temps.min(), let hi = temps.max() else { return nil }
        return lo...hi
    }

    // °C → positie op het regen-domein (0...maxMM).
    func normalizedTemp(_ celsius: Double) -> Double {
        guard tempMax > tempMin else { return 0 }
        return (celsius - tempMin) / (tempMax - tempMin) * maxMM
    }

    // Tick-temperaturen voor de rechter-as: even stappen vanaf tempMin, plus altijd
    // de bovenste aswaarde (tempMax) zodat de hoogste temperatuur zichtbaar is. Een
    // tick vlak onder de top wordt weggelaten om overlappende labels te voorkomen.
    var tempTicks: [Double] {
        let step = max(2, ((tempMax - tempMin) / 4 / 2).rounded() * 2)
        var ticks = Array(stride(from: tempMin, to: tempMax, by: step))
        if let last = ticks.last, tempMax - last < 2 { ticks.removeLast() }
        ticks.append(tempMax)
        return ticks
    }

    // Positie op het regen-domein → afgeronde °C (rechter-as-label terugrekenen).
    func temperature(atNormalized position: Double) -> Int {
        Int((tempMin + position / maxMM * (tempMax - tempMin)).rounded())
    }
}
