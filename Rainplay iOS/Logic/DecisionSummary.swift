import Foundation

// Afgeleide kop-informatie voor het hoofdscherm, één keer berekend uit de
// forecast + selectie i.p.v. verspreid (en meermaals) in de view. Zo bestaat er
// één bron van waarheid voor de temperatuur, het beste-moment-venster en de
// adviesteksten, en draait bestOutdoorWindow niet 3× per render.
struct DecisionSummary: Equatable {
    var temperature: Int?
    var dateLabel: String
    var bestStartTime: String
    var summaryLabel: String
}

func decisionSummary(
    forecast: Forecast?,
    day: DayOption,
    horizon: HorizonOption,
    now: Date
) -> DecisionSummary {
    let hours = visiblePoints(forecast: forecast, day: day, horizon: horizon, now: now)
    let window = bestOutdoorWindow(hours)

    // "Vandaag" toont de live huidige temperatuur; andere dagen het daggemiddelde.
    // nil = nog geen data (de view toont dan een placeholder i.p.v. een plausibel
    // ogend maar verzonnen getal).
    let temperature: Int?
    if day == .vandaag {
        temperature = forecast?.currentTemperature
    } else {
        temperature = averageTemperature(hours) ?? forecast?.currentTemperature
    }

    return DecisionSummary(
        temperature: temperature,
        dateLabel: headerDateLabel(forecast?.hourly ?? [], day: day),
        bestStartTime: window?.startTime ?? "--:--",
        summaryLabel: outdoorSummaryLabel(hours, bestWindow: window)
    )
}
