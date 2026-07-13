import SwiftUI

// Hoofdscherm (src/screens/WeatherScreen.tsx). Hero met foto-achtergrond en de
// witte "decision sheet" eronder met ronde bovenhoeken.
struct WeatherScreen: View {
    @Bindable var model: AppModel
    @State private var settingsOpen = false
    @State private var locationMenuOpen = false

    // Alle afgeleide kop-informatie in één keer berekend (temperatuur, datum,
    // beste-moment-venster, adviesteksten) — zie DecisionSummary.
    private var summary: DecisionSummary {
        decisionSummary(
            forecast: model.forecast,
            day: model.selectedDay,
            horizon: model.selectedHorizon,
            now: model.currentDate
        )
    }

    var body: some View {
        let summary = summary
        return VStack(spacing: 0) {
            OfflineBanner(isOffline: model.networkMonitor.isOffline)
            hero(summary)
            Spacer(minLength: 0)
            decisionSheet()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // De hero-foto vult het volledige scherm ACHTER de content; door hem als
        // achtergrond te zetten (i.p.v. als ZStack-laag) blijft de content zelf
        // binnen de safe area — anders schuift de kop achter de Dynamic Island.
        .background(heroBackground)
        .sheet(isPresented: $settingsOpen) {
            SettingsSheet(model: model)
        }
        .sheet(isPresented: $locationMenuOpen) {
            LocationSelectorMenu(model: model, isPresented: $locationMenuOpen)
        }
    }

    // MARK: - Hero

    private var heroBackground: some View {
        Image("WeatherHero")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .overlay(
                RadialGradient(
                    colors: [.white.opacity(0.22), .clear],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 0,
                    endRadius: 260
                )
                .ignoresSafeArea()
            )
    }

    private func hero(_ summary: DecisionSummary) -> some View {
        VStack(spacing: 0) {
            // Locatiekiezer + tandwiel
            ZStack(alignment: .topTrailing) {
                Button {
                    locationMenuOpen = true
                } label: {
                    HStack(spacing: 8) {
                        Text(model.selectedLocation.name)
                            .font(.system(size: 28, weight: .semibold))
                        if model.selectedLocation.source == .gps {
                            Image(systemName: "location.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Tokens.accent)
                                .rotationEffect(.degrees(20))
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Tokens.ink)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button {
                    settingsOpen = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.18), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Instellingen")
            }
            .padding(.horizontal, 4)

            VStack(spacing: 2) {
                Text(model.selectedDay.rawValue)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Tokens.heroDayLabel)
                if !summary.dateLabel.isEmpty {
                    Text(summary.dateLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.heroDateLabel)
                }
                Text(summary.temperature.map { "\($0)°" } ?? "--°")
                    .font(.system(size: 96, weight: .semibold))
                    .foregroundStyle(Tokens.inkStrong)
                    .accessibilityLabel(summary.temperature.map { "\($0) graden" } ?? "Temperatuur onbekend")
                Text("Buiten vanaf \(summary.bestStartTime)")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Tokens.inkStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(summary.summaryLabel)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Tokens.heroSubtitle)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        // Ruimte tussen de subtitel en de bovenrand van de witte decision-sheet.
        .padding(.bottom, 22)
    }

    // MARK: - Decision sheet

    private func decisionSheet() -> some View {
        VStack(spacing: 0) {
            DayCarousel(model: model)
                .padding(.top, 4)

            VStack(spacing: 9) {
                SegmentedControl(
                    options: HorizonOption.allCases,
                    selection: $model.selectedHorizon,
                    label: { $0.rawValue },
                    disabled: model.selectedDay != .vandaag
                )
                SegmentedControl(
                    options: DayOption.allCases,
                    selection: $model.selectedDay,
                    label: { $0.displayLabel }
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 5)

            Text("Weather data by Open-Meteo")
                .font(.system(size: 12))
                .foregroundStyle(Tokens.inkSoft)
                .padding(.top, 14)
        }
        .padding(.top, 14)
        .padding(.horizontal, 10)
        // Trekt de attributie iets richting de home-indicator (net als de PWA,
        // die ~16px van de safe-area-inset aftrekt) zodat de ondermarge niet te
        // groot wordt; de witte achtergrond loopt er wél achterlangs door.
        .padding(.bottom, -14)
        .frame(maxWidth: .infinity)
        .background(
            Tokens.surface
                .clipShape(.rect(topLeadingRadius: Tokens.radiusSheet, topTrailingRadius: Tokens.radiusSheet))
                .shadow(color: Color(red: 46 / 255, green: 81 / 255, blue: 112 / 255, opacity: 0.14), radius: 20, y: -12)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
