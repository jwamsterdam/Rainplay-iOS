import Foundation
import os

enum ForecastError: Error, Equatable {
    case timeout
    case httpStatus(Int)
    case unexpectedStructure

    /// HTTP status, so the fetch layer can skip retrying a 4xx (notably a 429 rate limit).
    var status: Int? {
        if case .httpStatus(let code) = self { return code }
        return nil
    }
}

private let forecastURL = "https://api.open-meteo.com/v1/forecast"

/// Aborts a stalled request so the fetch fails instead of loading forever.
/// ~10s is generous for a mobile radio while still surfacing real outages quickly.
private let fetchTimeoutSeconds: TimeInterval = 10

// MARK: - Response structure

private struct OpenMeteoResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let sunrise: [String]
        let sunset: [String]
    }

    struct Current: Decodable {
        let temperature2m: Double

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
        }
    }

    /// Only `time` and `temperature2m` are required; the rest are optional so a valid
    /// response that omits a field (which Open-Meteo does for some models/locations)
    /// does not fail the whole decode. `numberAt` fills a missing field with 0.
    struct Hourly: Decodable {
        let time: [String]
        let temperature2m: [Double]
        let precipitation: [Double]?
        let precipitationProbability: [Double]?
        let cloudCover: [Double]?
        let shortwaveRadiation: [Double]?
        let weatherCode: [Double]?
        let isDay: [Double]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case precipitation
            case precipitationProbability = "precipitation_probability"
            case cloudCover = "cloud_cover"
            case shortwaveRadiation = "shortwave_radiation"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Minutely15: Decodable {
        let time: [String]
        let precipitation: [Double]?
        let weatherCode: [Double]?
        let cloudCover: [Double]?
        let shortwaveRadiation: [Double]?
        let isDay: [Double]?

        enum CodingKeys: String, CodingKey {
            case time
            case precipitation
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case shortwaveRadiation = "shortwave_radiation"
            case isDay = "is_day"
        }
    }

    let daily: Daily
    let current: Current
    let hourly: Hourly
    let minutely15: Minutely15?

    enum CodingKeys: String, CodingKey {
        case daily
        case current
        case hourly
        case minutely15 = "minutely_15"
    }
}

// MARK: - Client

/// Production implementation of `ForecastProviding`. Stateless, so `Sendable`.
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
        // Request exactly the fields we decode and use to avoid dead payload on a mobile connection.
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
        AppLog.network.warning("Open-Meteo request timed out after \(fetchTimeoutSeconds, privacy: .public)s")
        throw ForecastError.timeout
    }

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        AppLog.network.error("Open-Meteo returned HTTP \(http.statusCode, privacy: .public)")
        throw ForecastError.httpStatus(http.statusCode)
    }

    return try makeForecast(from: data)
}

/// Pure decode and normalization of an Open-Meteo response into the internal
/// `Forecast` model. Separated from the network so it can be tested with JSON fixtures.
func makeForecast(from data: Data) throws -> Forecast {
    let decoded: OpenMeteoResponse
    do {
        // Explicit CodingKeys map Open-Meteo's snake_case onto camelCase properties;
        // more reliable than .convertFromSnakeCase, which won't map `temperature_2m` to `temperature2m`.
        decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
    } catch {
        // Log the real decode reason; the UI only sees the clean error.
        AppLog.network.error("Open-Meteo decode failed: \(error.localizedDescription, privacy: .public)")
        throw ForecastError.unexpectedStructure
    }

    // Parse dates once up front rather than per point: this was the decode hotspot
    // (nearestHourlyIndexFor re-parsed all 168 hourly strings before every 15-minute
    // point = ~4000 DateFormatter parses). Now ~168 + 7.
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
        currentTemperature: Int(decoded.current.temperature2m.rounded()),
        hourly: decoded.hourly.time.enumerated().map { index, time in
            toHourlyWeather(decoded, index: index, isoTime: time, sunsetMsByDate: sunsetMsByDate)
        },
        minutely15: decoded.minutely15.map { minutely in
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

/// Sunset (ms) for the calendar day of `isoTime`, from the precomputed map.
private func sunsetMsFor(_ isoTime: String, _ sunsetMsByDate: [String: Double]) -> Double? {
    sunsetMsByDate[String(isoTime.prefix(10))]
}

private func toHourlyWeather(_ data: OpenMeteoResponse, index: Int, isoTime: String, sunsetMsByDate: [String: Double]) -> HourlyWeather {
    let precipitationMm = numberAt(data.hourly.precipitation ?? [], index)
    let precipitationProbability = numberAt(data.hourly.precipitationProbability ?? [], index)
    let cloudCover = numberAt(data.hourly.cloudCover ?? [], index)
    let radiation = numberAt(data.hourly.shortwaveRadiation ?? [], index)
    let temperatureC = numberAt(data.hourly.temperature2m, index)
    let weatherCode = numberAt(data.hourly.weatherCode ?? [], index)
    let isDay = numberAt(data.hourly.isDay ?? [], index) == 1
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
    // Temperature and precipitation probability aren't available per 15 minutes; use the nearest hour.
    let nearestHourlyIndex = nearestHourlyIndexFor(hourlyMs, targetMs: IsoTime.ms(isoTime))
    let precipitationMm = numberAt(minutely.precipitation ?? [], index)
    let cloudCover = numberAt(minutely.cloudCover ?? [], index)
    let radiation = numberAt(minutely.shortwaveRadiation ?? [], index)
    let weatherCode = numberAt(minutely.weatherCode ?? [], index)
    let isDay = numberAt(minutely.isDay ?? [], index) == 1
    let precipitationProbability = numberAt(data.hourly.precipitationProbability ?? [], nearestHourlyIndex)
    let temperatureC = numberAt(data.hourly.temperature2m, nearestHourlyIndex)
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

/// Index of the nearest hour, using precomputed ms timestamps (no DateFormatter parse per comparison).
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
