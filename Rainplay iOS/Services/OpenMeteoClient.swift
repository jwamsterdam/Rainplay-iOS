import Foundation
import os

// Open-Meteo forecast-client, geport uit de PWA
// (src/api/openMeteo.ts + src/api/schemas/openMeteoSchema.ts).
// Codable vervangt de Zod-runtimevalidatie.

enum ForecastError: Error, Equatable {
    case timeout
    case httpStatus(Int)
    case unexpectedStructure

    // HTTP-status zodat de fetch-laag kan besluiten een 4xx (vooral 429
    // rate-limit) NIET opnieuw te proberen.
    var status: Int? {
        if case .httpStatus(let code) = self { return code }
        return nil
    }
}

private let forecastURL = "https://api.open-meteo.com/v1/forecast"

// Breek een blijvend hangend verzoek af zodat de fetch faalt in plaats van
// eeuwig in "laden" te blijven. ~10 s is ruim voor een mobiele radio en maakt
// een echte storing toch snel zichtbaar.
private let fetchTimeoutSeconds: TimeInterval = 10

// MARK: - Response-structuur (spiegelt openMeteoSchema.ts)

private struct OpenMeteoResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let sunrise: [String]
        let sunset: [String]
    }

    struct Current: Decodable {
        let temperature_2m: Double
    }

    // Alleen `time` en `temperature_2m` zijn hard vereist; de rest is optioneel
    // zodat een geldige respons waarin Open-Meteo één veld weglaat (komt voor bij
    // bepaalde modellen/locaties) niet de héle decode laat falen. numberAt vult
    // een ontbrekend veld met de fallback 0 — net als de Zod-tolerantie in de PWA.
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let precipitation: [Double]?
        let precipitation_probability: [Double]?
        let cloud_cover: [Double]?
        let shortwave_radiation: [Double]?
        let weather_code: [Double]?
        let is_day: [Double]?
    }

    struct Minutely15: Decodable {
        let time: [String]
        let precipitation: [Double]?
        let weather_code: [Double]?
        let cloud_cover: [Double]?
        let shortwave_radiation: [Double]?
        let is_day: [Double]?
    }

    let daily: Daily
    let current: Current
    let hourly: Hourly
    let minutely_15: Minutely15?
}

// MARK: - Client

// Productie-implementatie van ForecastProviding. Stateless, dus Sendable.
struct OpenMeteoClient: ForecastProviding {
    func fetchForecast(_ location: ForecastLocation) async throws -> Forecast {
        try await fetchOpenMeteoForecast(location)
    }
}

// MARK: - Fetch

func fetchOpenMeteoForecast(_ location: ForecastLocation) async throws -> Forecast {
    var components = URLComponents(string: forecastURL)!
    components.queryItems = [
        URLQueryItem(name: "latitude", value: String(location.latitude)),
        URLQueryItem(name: "longitude", value: String(location.longitude)),
        // Vraag exact de velden op die we ook echt decoderen/gebruiken — geen
        // dode payload op een mobiele verbinding.
        URLQueryItem(name: "current", value: "temperature_2m"),
        URLQueryItem(name: "hourly", value: [
            "temperature_2m", "precipitation", "precipitation_probability",
            "cloud_cover", "shortwave_radiation", "weather_code", "is_day",
        ].joined(separator: ",")),
        URLQueryItem(name: "minutely_15", value: [
            "precipitation", "weather_code", "cloud_cover", "shortwave_radiation", "is_day",
        ].joined(separator: ",")),
        URLQueryItem(name: "daily", value: "sunrise,sunset"),
        URLQueryItem(name: "forecast_minutely_15", value: "24"),
        URLQueryItem(name: "forecast_days", value: "7"),
        URLQueryItem(name: "timezone", value: "auto"),
    ]

    var request = URLRequest(url: components.url!)
    request.timeoutInterval = fetchTimeoutSeconds

    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch let error as URLError where error.code == .timedOut {
        AppLog.network.warning("Open-Meteo verzoek timede out na \(fetchTimeoutSeconds, privacy: .public)s")
        throw ForecastError.timeout
    }

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        AppLog.network.error("Open-Meteo gaf HTTP \(http.statusCode, privacy: .public)")
        throw ForecastError.httpStatus(http.statusCode)
    }

    return try makeForecast(from: data)
}

// Pure decode + normalisatie van een Open-Meteo-respons naar het interne
// Forecast-model. Los van het netwerk zodat het met JSON-fixtures getest kan
// worden (het iOS-equivalent van de aparte, testbare Zod-schema's in de PWA).
func makeForecast(from data: Data) throws -> Forecast {
    let decoded: OpenMeteoResponse
    do {
        decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
    } catch {
        // Bewaar de echte decode-reden in de log; de UI ziet alleen de nette fout.
        AppLog.network.error("Open-Meteo decode mislukt: \(error.localizedDescription, privacy: .public)")
        throw ForecastError.unexpectedStructure
    }

    // Datum-parsing één keer vooraf i.p.v. per punt herhaald: dit was de
    // decode-hotspot (nearestHourlyIndexFor herparste alle 168 uur-strings vóór
    // elk kwartierpunt = ~4000 DateFormatter-parses). Nu ~168 + 7.
    let hourlyMs = decoded.hourly.time.map(IsoTime.ms)

    var sunriseTimes: [String: String] = [:]
    var sunsetTimes: [String: String] = [:]
    var sunsetMsByDate: [String: Double] = [:]
    for (i, date) in decoded.daily.time.enumerated() {
        sunriseTimes[date] = formatHour(valueAt(decoded.daily.sunrise, i) ?? "")
        let sunset = valueAt(decoded.daily.sunset, i) ?? ""
        sunsetTimes[date] = formatHour(sunset)
        if !sunset.isEmpty { sunsetMsByDate[date] = IsoTime.ms(sunset) }
    }

    return Forecast(
        currentTemperature: Int(decoded.current.temperature_2m.rounded()),
        hourly: decoded.hourly.time.enumerated().map { index, time in
            toHourlyWeather(decoded, index: index, isoTime: time, sunsetMsByDate: sunsetMsByDate)
        },
        minutely15: decoded.minutely_15.map { minutely in
            minutely.time.enumerated().map { index, time in
                toMinutelyWeather(decoded, minutely: minutely, index: index, isoTime: time,
                                  hourlyMs: hourlyMs, sunsetMsByDate: sunsetMsByDate)
            }
        } ?? [],
        sunriseTimes: sunriseTimes,
        sunsetTimes: sunsetTimes
    )
}

// MARK: - Mapping

// Zonsondergang (ms) voor de kalenderdag van isoTime, uit de vooraf berekende map.
private func sunsetMsFor(_ isoTime: String, _ sunsetMsByDate: [String: Double]) -> Double? {
    sunsetMsByDate[String(isoTime.prefix(10))]
}

private func toHourlyWeather(_ data: OpenMeteoResponse, index: Int, isoTime: String, sunsetMsByDate: [String: Double]) -> HourlyWeather {
    let precipitationMm = numberAt(data.hourly.precipitation ?? [], index)
    let precipitationProbability = numberAt(data.hourly.precipitation_probability ?? [], index)
    let cloudCover = numberAt(data.hourly.cloud_cover ?? [], index)
    let radiation = numberAt(data.hourly.shortwave_radiation ?? [], index)
    let temperatureC = numberAt(data.hourly.temperature_2m, index)
    let weatherCode = numberAt(data.hourly.weather_code ?? [], index)
    let isDay = numberAt(data.hourly.is_day ?? [], index) == 1
    let kind = weatherKind(
        weatherCode: weatherCode,
        precipitationMm: precipitationMm,
        cloudCover: cloudCover,
        radiation: radiation,
        isDay: isDay
    )

    return HourlyWeather(
        isoTime: isoTime,
        time: formatHour(isoTime),
        temperatureC: temperatureC,
        score: outdoorScore(precipitationMm: precipitationMm, temperatureC: temperatureC, kind: kind, isDay: isDay),
        precipitationMm: precipitationMm,
        precipitationProbability: precipitationProbability,
        cloudCover: cloudCover,
        radiation: radiation,
        isDay: isDay,
        kind: kind,
        sunsetMs: sunsetMsFor(isoTime, sunsetMsByDate)
    )
}

private func toMinutelyWeather(
    _ data: OpenMeteoResponse,
    minutely: OpenMeteoResponse.Minutely15,
    index: Int,
    isoTime: String,
    hourlyMs: [Double],
    sunsetMsByDate: [String: Double]
) -> ForecastPoint {
    // Temperatuur en regenkans bestaan niet per kwartier; neem het dichtstbijzijnde uur.
    let nearestHourlyIndex = nearestHourlyIndexFor(hourlyMs, targetMs: IsoTime.ms(isoTime))
    let precipitationMm = numberAt(minutely.precipitation ?? [], index)
    let cloudCover = numberAt(minutely.cloud_cover ?? [], index)
    let radiation = numberAt(minutely.shortwave_radiation ?? [], index)
    let weatherCode = numberAt(minutely.weather_code ?? [], index)
    let isDay = numberAt(minutely.is_day ?? [], index) == 1
    let precipitationProbability = numberAt(data.hourly.precipitation_probability ?? [], nearestHourlyIndex)
    let temperatureC = numberAt(data.hourly.temperature_2m, nearestHourlyIndex)
    let kind = weatherKind(
        weatherCode: weatherCode,
        precipitationMm: precipitationMm,
        cloudCover: cloudCover,
        radiation: radiation,
        isDay: isDay
    )

    return ForecastPoint(
        isoTime: isoTime,
        time: formatHour(isoTime),
        temperatureC: temperatureC,
        score: outdoorScore(precipitationMm: precipitationMm, temperatureC: temperatureC, kind: kind, isDay: isDay),
        precipitationMm: precipitationMm,
        precipitationProbability: precipitationProbability,
        cloudCover: cloudCover,
        radiation: radiation,
        isDay: isDay,
        kind: kind,
        sunsetMs: sunsetMsFor(isoTime, sunsetMsByDate)
    )
}

// Index van het dichtstbijzijnde uur, op basis van vooraf berekende ms-tijdstippen
// (geen DateFormatter-parse meer per vergelijking).
private func nearestHourlyIndexFor(_ hourlyMs: [Double], targetMs: Double) -> Int {
    var nearestIndex = 0
    var nearestDistance = Double.infinity

    for (index, ms) in hourlyMs.enumerated() {
        let distance = abs(ms - targetMs)
        if distance < nearestDistance {
            nearestDistance = distance
            nearestIndex = index
        }
    }

    return nearestIndex
}

private func numberAt(_ values: [Double], _ index: Int) -> Double {
    guard values.indices.contains(index), values[index].isFinite else { return 0 }
    return values[index]
}

private func valueAt<T>(_ values: [T], _ index: Int) -> T? {
    values.indices.contains(index) ? values[index] : nil
}

private func formatHour(_ isoTime: String) -> String {
    guard let tIndex = isoTime.firstIndex(of: "T") else { return "" }
    return String(isoTime[isoTime.index(after: tIndex)...].prefix(5))
}
