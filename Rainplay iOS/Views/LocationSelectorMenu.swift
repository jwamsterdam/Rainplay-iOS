import SwiftUI
import UIKit

// Locatiekiezer (src/components/LocationSelector.tsx). Native sheet met de
// huidige-locatie-rij (GPS), opgeslagen locaties (met verwijderknop voor
// handmatige) en een zoekveld met debounce.
struct LocationSelectorMenu: View {
    @Bindable var model: AppModel
    @Binding var isPresented: Bool

    @Environment(\.openURL) private var openURL

    @State private var query = ""
    @State private var suggestions: [ForecastLocation] = []
    @State private var isSearching = false
    @State private var searchError: String?

    private var gpsLocation: ForecastLocation? {
        model.selectedLocation.source == .gps ? model.selectedLocation : nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    currentLocationRow
                    if model.locationService.status == .denied {
                        locationDeniedRow
                    }
                }

                if !model.savedLocations.isEmpty {
                    Section("Opgeslagen") {
                        ForEach(model.savedLocations, id: \.key) { location in
                            savedRow(location)
                        }
                        .onDelete(perform: deleteManual)
                    }
                }

                Section("Plaats zoeken") {
                    TextField("Plaats zoeken", text: $query)
                        .autocorrectionDisabled()
                    if isSearching {
                        Text("Zoeken...").font(.footnote).foregroundStyle(Tokens.inkSoft)
                    }
                    if let searchError {
                        Text(searchError).font(.footnote).foregroundStyle(Tokens.scoreBad)
                    }
                    ForEach(suggestions, id: \.key) { suggestion in
                        Button {
                            choose(suggestion)
                        } label: {
                            HStack {
                                Text(suggestion.name).foregroundStyle(Tokens.ink)
                                Spacer()
                                if let country = suggestion.country {
                                    Text(country).font(.footnote).foregroundStyle(Tokens.inkSoft)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Locatie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { isPresented = false }
                }
            }
            .task(id: query) { await runSearch() }
        }
    }

    private var currentLocationRow: some View {
        Button {
            Task {
                do {
                    _ = try await model.refreshLocation()
                    isPresented = false
                } catch {
                    // Blijf open; status is nu .denied → locationDeniedRow toont
                    // een uitleg met een knop naar Instellingen.
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(gpsLocation?.name ?? "Huidige locatie")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.ink)
                    Text(model.locationService.status == .locating ? "Locatie ophalen..." : "GPS locatie")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.inkMuted)
                }
                Spacer()
                Image(systemName: "location.fill")
                    .foregroundStyle(Tokens.accent)
                    .rotationEffect(.degrees(20))
            }
        }
        .disabled(model.locationService.status == .locating)
    }

    // Getoond na een geweigerde locatie-aanvraag: kalme uitleg + directe knop
    // naar de systeeminstellingen (App Review test dit pad expliciet).
    private var locationDeniedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Geen toegang tot je locatie. Zet locatietoegang aan in Instellingen om je huidige plek te gebruiken.")
                .font(.system(size: 13))
                .foregroundStyle(Tokens.inkMuted)
            Button("Open Instellingen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tokens.accent)
        }
    }

    private func savedRow(_ location: ForecastLocation) -> some View {
        Button {
            model.selectedLocation = location
            isPresented = false
        } label: {
            HStack {
                Text(location.name).foregroundStyle(Tokens.ink)
                Spacer()
                if ForecastLocation.isSame(location, model.selectedLocation) {
                    Image(systemName: "checkmark").foregroundStyle(Tokens.accent)
                }
            }
        }
    }

    private func deleteManual(_ offsets: IndexSet) {
        for index in offsets {
            let location = model.savedLocations[index]
            if location.source == .manual {
                model.deleteLocation(location)
            }
        }
    }

    private func choose(_ location: ForecastLocation) {
        model.chooseLocation(location)
        query = ""
        suggestions = []
        searchError = nil
        isPresented = false
    }

    private func runSearch() async {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard search.count >= minLocationQueryLength else {
            suggestions = []
            isSearching = false
            searchError = nil
            return
        }

        // Debounce: 250 ms wachten; wordt geannuleerd zodra query verandert.
        try? await Task.sleep(for: .milliseconds(250))
        if Task.isCancelled { return }

        isSearching = true
        searchError = nil
        do {
            let results = try await searchLocations(search)
            if Task.isCancelled { return }
            suggestions = results
            searchError = results.isEmpty ? "Geen plaatsen gevonden." : nil
        } catch {
            if Task.isCancelled { return }
            searchError = "Zoeken lukte niet."
            suggestions = []
        }
        isSearching = false
    }
}
