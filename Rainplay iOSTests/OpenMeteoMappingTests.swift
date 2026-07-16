import Foundation
@testable import Rainplay_iOS
import Testing

// Decode + normalisatie van een Open-Meteo-respons naar het interne model,
// getest met JSON-fixtures (geen netwerk).
struct OpenMeteoMappingTests {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    private let validJSON = """
    {
      "daily": { "time": ["2026-07-09"], "sunrise": ["2026-07-09T05:30"], "sunset": ["2026-07-09T22:00"] },
      "current": { "temperature_2m": 20.6 },
      "hourly": {
        "time": ["2026-07-09T00:00", "2026-07-09T12:00"],
        "temperature_2m": [15, 20],
        "precipitation": [0, 0],
        "precipitation_probability": [10, 0],
        "cloud_cover": [90, 10],
        "shortwave_radiation": [0, 400],
        "weather_code": [3, 1],
        "is_day": [0, 1]
      },
      "minutely_15": {
        "time": ["2026-07-09T00:15"],
        "precipitation": [0],
        "weather_code": [3],
        "cloud_cover": [90],
        "shortwave_radiation": [0],
        "is_day": [0]
      }
    }
    """

    @Test func mapsCurrentHourlyAndMinutely() throws {
        let forecast = try makeForecast(from: data(validJSON))

        #expect(forecast.currentTemperature == 21)          // 20.6 afgerond
        #expect(forecast.hourly.count == 2)

        let night = forecast.hourly[0]
        #expect(night.time == "00:00")
        #expect(night.kind == .cloud)                        // nacht → bewolkt
        #expect(night.score == 6)                            // nacht-cap
        #expect(night.sunsetMs != nil)                       // gekoppeld aan daily sunset

        let midday = forecast.hourly[1]
        #expect(midday.kind == .sun)
        #expect(midday.score == 10)

        #expect(forecast.minutely15.count == 1)
        // Kwartier-punt erft de temperatuur van het dichtstbijzijnde uur (00:00 → 15°).
        #expect(forecast.minutely15[0].temperatureC == 15)
    }

    @Test func missingMinutelyYieldsEmptyArray() throws {
        let noMinutely = """
        {
          "daily": { "time": ["2026-07-09"], "sunrise": ["2026-07-09T05:30"], "sunset": ["2026-07-09T22:00"] },
          "current": { "temperature_2m": 18 },
          "hourly": {
            "time": ["2026-07-09T00:00"],
            "temperature_2m": [15],
            "precipitation": [0],
            "precipitation_probability": [10],
            "cloud_cover": [90],
            "shortwave_radiation": [0],
            "weather_code": [3],
            "is_day": [0]
          }
        }
        """
        let forecast = try makeForecast(from: data(noMinutely))
        #expect(forecast.minutely15.isEmpty)
        #expect(forecast.hourly.count == 1)
    }

    @Test func malformedJSONThrowsUnexpectedStructure() {
        #expect(throws: ForecastError.unexpectedStructure) {
            _ = try makeForecast(from: data("{ \"nonsense\": true }"))
        }
    }

    // Een geldige respons waarin Open-Meteo optionele velden weglaat mag NIET de
    // hele decode laten falen; de ontbrekende velden vallen terug op 0.
    @Test func toleratesMissingOptionalHourlyFields() throws {
        let sparse = """
        {
          "daily": { "time": ["2026-07-09"], "sunrise": ["2026-07-09T05:30"], "sunset": ["2026-07-09T22:00"] },
          "current": { "temperature_2m": 18 },
          "hourly": {
            "time": ["2026-07-09T12:00"],
            "temperature_2m": [20]
          }
        }
        """
        let forecast = try makeForecast(from: data(sparse))
        #expect(forecast.hourly.count == 1)
        let hour = forecast.hourly[0]
        #expect(hour.precipitationMm == 0)
        #expect(hour.precipitationProbability == 0)
        #expect(hour.cloudCover == 0)
        #expect(hour.temperatureC == 20)
    }
}
