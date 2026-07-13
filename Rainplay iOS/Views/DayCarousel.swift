import SwiftUI

// Swipebare dag-carousel (src/components/DayCarousel.tsx). Native TabView in
// page-stijl, two-way gekoppeld aan model.selectedDay. Elk paneel toont de
// grafiek voor die dag; het laad-/foutpaneel deelt de plek.
struct DayCarousel: View {
    @Bindable var model: AppModel

    private func hours(for day: DayOption) -> [HourlyWeather] {
        visiblePoints(
            forecast: model.forecast,
            day: day,
            horizon: model.selectedHorizon,
            now: model.currentDate
        )
    }

    // As-schaal per dag. Alleen bij "Hele dag" is de as gedeeld over alle dagen
    // (zodat je bij het swipen echt de temperatuurverschillen ziet). Bij de
    // detailweergaves +6/+2 krijgt elk paneel z'n eigen, losgekoppelde as.
    private func geometry(for day: DayOption) -> ChartGeometry {
        if model.selectedHorizon == .heleDag {
            let range = ChartGeometry.temperatureRange(across: DayOption.allCases.map(hours(for:)))
            return ChartGeometry(temperatureRange: range)
        }
        return ChartGeometry(hours: hours(for: day))
    }

    var body: some View {
        TabView(selection: $model.selectedDay) {
            ForEach(DayOption.allCases) { day in
                panel(for: day)
                    .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 300)
    }

    @ViewBuilder
    private func panel(for day: DayOption) -> some View {
        if model.isLoading {
            loadingPanel(text: "Weer laden")
        } else if model.loadFailed {
            loadingPanel(text: "Weerdata niet beschikbaar", showRetry: true)
        } else {
            DayChart(
                hours: hours(for: day),
                horizon: model.selectedHorizon,
                cellColors: model.cellColors,
                showTemp: model.showTemp,
                showRain: model.showRain,
                showIcons: model.showIcons,
                twilightRadiation: model.twilightRadiation,
                geometry: geometry(for: day),
                now: model.currentDate,
                isToday: day == .vandaag,
                currentTemperatureC: day == .vandaag ? model.forecast?.currentTemperature : nil
            )
            .padding(.horizontal, 4)
        }
    }

    private func loadingPanel(text: String, showRetry: Bool = false) -> some View {
        VStack(spacing: 14) {
            Text(text)
            if showRetry {
                Button("Opnieuw proberen") { model.retry() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.ink)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .background(Tokens.best, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
            }
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(Tokens.inkMuted)
        .frame(maxWidth: .infinity)
        .frame(height: 238)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusPanel))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.radiusPanel).stroke(Tokens.border, lineWidth: 1)
        )
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }
}
