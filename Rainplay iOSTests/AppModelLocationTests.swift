import Foundation
@testable import Rainplay_iOS
import Testing

// Tests voor het opslaan/verwijderen van locaties in AppModel: nieuwe locaties
// worden bewaard, het maximum wordt afgedwongen, en verwijderen valt netjes
// terug op een resterende (of de default) locatie. Geen netwerk/GPS: de
// forecastbron is een no-op stub.
@MainActor
struct AppModelLocationTests {
    @MainActor final class StubForecastProvider: ForecastProviding {
        func fetchForecast(_ location: ForecastLocation) async throws -> Forecast {
            Forecast(currentTemperature: 0, hourly: [], minutely15: [], sunriseTimes: [:], sunsetTimes: [:])
        }
    }

    private func makeModel() -> AppModel {
        AppModel(
            defaults: UserDefaults(suiteName: "rainplay.tests.\(UUID().uuidString)")!,
            forecastProvider: StubForecastProvider()
        )
    }

    private func location(_ name: String) -> ForecastLocation {
        ForecastLocation(id: name, name: name, latitude: 0, longitude: 0, source: .manual)
    }

    @Test func choosingNewLocationSavesAndSelectsIt() {
        let model = makeModel()

        let added = model.chooseLocation(location("Utrecht"))

        #expect(added)
        #expect(model.savedLocations.count == 1)
        #expect(model.selectedLocation.name == "Utrecht")
    }

    @Test func choosingSameLocationTwiceDoesNotDuplicate() {
        let model = makeModel()

        model.chooseLocation(location("Utrecht"))
        let addedAgain = model.chooseLocation(location("Utrecht"))

        #expect(addedAgain)
        #expect(model.savedLocations.count == 1)
    }

    @Test func savingStopsAtMaximum() {
        let model = makeModel()

        for i in 0..<model.maxSavedLocations {
            #expect(model.chooseLocation(location("Plaats \(i)")))
        }

        #expect(model.savedLocations.count == model.maxSavedLocations)
        #expect(!model.canAddLocation)

        // De zesde locatie wordt geweigerd; selectie én lijst blijven ongewijzigd.
        let overflow = model.chooseLocation(location("Zesde"))
        #expect(!overflow)
        #expect(model.savedLocations.count == model.maxSavedLocations)
        #expect(model.selectedLocation.name == "Plaats \(model.maxSavedLocations - 1)")
    }

    @Test func selectingAlreadySavedLocationStillWorksAtMaximum() {
        let model = makeModel()
        for i in 0..<model.maxSavedLocations {
            model.chooseLocation(location("Plaats \(i)"))
        }

        // Ook aan het maximum blijft het kiezen van een bestaande locatie werken.
        let selected = model.chooseLocation(location("Plaats 0"))

        #expect(selected)
        #expect(model.selectedLocation.name == "Plaats 0")
        #expect(model.savedLocations.count == model.maxSavedLocations)
    }

    @Test func deletingSelectedLocationFallsBackToRemaining() {
        let model = makeModel()
        model.chooseLocation(location("Utrecht"))
        model.chooseLocation(location("Delft"))

        model.deleteLocation(location("Delft")) // de huidige selectie

        #expect(model.savedLocations.count == 1)
        #expect(model.selectedLocation.name == "Utrecht")
        #expect(model.canAddLocation)
    }

    @Test func deletingLastLocationFallsBackToDefault() {
        let model = makeModel()
        model.chooseLocation(location("Utrecht"))

        model.deleteLocation(location("Utrecht"))

        #expect(model.savedLocations.isEmpty)
        #expect(ForecastLocation.isSame(model.selectedLocation, .defaultLocation))
    }
}
