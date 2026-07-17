import Charts
import SwiftUI

// De gecombineerde weer-grafiek (src/components/DayChartRecharts.tsx), gebouwd
// met native Swift Charts: regen-bars, temperatuurlijn met tweede as,
// lucht-gradient als plot-achtergrond, score-badges + weericonen boven de plot,
// gestippelde nu-lijn en verticale tijdlabels.
//
// De view stuurt alleen de rendering aan; de dubbele-as-wiskunde zit in
// ChartGeometry (Logic), en de losse lagen zijn aparte subviews hieronder.
struct DayChart: View {
    let hours: [HourlyWeather]
    let horizon: HorizonOption
    let cellColors: CellColors
    let showTemp: Bool
    let showRain: Bool
    let showIcons: Bool
    let twilightRadiation: Double
    var temperatureUnit: TemperatureUnit = .system
    var timeFormat: TimeFormat = .system
    // Gedeeld over alle 4 de dag-panelen (zelfde temp-as), zodat ze vergelijkbaar
    // zijn bij het swipen. Bevat ook maxMM voor de regen-as.
    let geometry: ChartGeometry
    var now: Date = Date()
    var isToday: Bool = false
    var currentTemperatureC: Int?

    private var rainMax: Double { geometry.rainMax }

    // De grafiek-as gebruikt `hour.time` als categorie-identiteit (uniek per
    // punt), maar toont een geformatteerde tijd/weekdag. Deze map koppelt de
    // identiteit aan de weergavestring, op basis van de gekozen tijdnotatie.
    private var tickLabels: [String: String] {
        Dictionary(hours.map { ($0.time, tickLabel(for: $0)) }, uniquingKeysWith: { first, _ in first })
    }

    // Uur-punten ("HH:mm") → compacte tijd zónder AM/PM (smalle, geroteerde
    // as); week-punten (dagsleutel zonder ":") → locale-aware weekdag-afkorting.
    private func tickLabel(for hour: HourlyWeather) -> String {
        if hour.time.contains(":") {
            return axisTimeString(isoTime: hour.isoTime, format: timeFormat)
        }
        return weekdayLabel(date: IsoTime.date(hour.isoTime))
    }

    private let plotHeight: CGFloat = 232
    private let topRowsHeight: CGFloat = 64   // ruimte boven de plot voor score + iconen

    var body: some View {
        let geo = geometry
        return Chart {
            if showRain { rainBars }
            if showTemp { temperatureLine(geo) }
        }
        .chartXScale(domain: hours.map(\.time))
        .chartYScale(domain: 0...rainMax)
        .chartYAxis { yAxis(geo) }
        .chartXAxis { xAxis }
        .chartYAxis(showRain || showTemp ? .automatic : .hidden)
        .chartBackground { proxy in
            plotRect(proxy) { rect in
                SkyGradientBackground(hours: hours, colors: cellColors, twilightRadiation: twilightRadiation)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                Rectangle()
                    .stroke(Tokens.grid, lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .chartOverlay { proxy in
            plotRect(proxy) { rect in
                ChartScoreIconRows(hours: hours, showIcons: showIcons, proxy: proxy, rect: rect, topRowsHeight: topRowsHeight, timeFormat: timeFormat)
                if isToday, let fraction = nowFraction(isoTimes: hours.map(\.isoTime), now: now) {
                    ChartNowLine(
                        x: rect.minX + fraction * rect.width,
                        rect: rect,
                        currentTemperatureC: currentTemperatureC,
                        temperatureUnit: temperatureUnit
                    )
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(height: plotHeight)
        .padding(.top, topRowsHeight)
        .padding(.horizontal, 4)
    }

    // MARK: - Marks

    @ChartContentBuilder
    private var rainBars: some ChartContent {
        // Eén blauwe bar met afgeronde top. (Geen witte halo-bar meer: die werd
        // rondom afgerond en piepte onderaan uit als witte nub; het onder de
        // nullijn beginnen om dat weg te kappen tekende de bar juist ónder de as.)
        ForEach(Array(hours.enumerated()), id: \.offset) { _, hour in
            if hour.precipitationMm > 0 {
                BarMark(
                    x: .value("tijd", hour.time),
                    y: .value("mm", hour.precipitationMm),
                    width: .fixed(16)
                )
                .foregroundStyle(Tokens.rain)
                .cornerRadius(4)
            }
        }
    }

    @ChartContentBuilder
    private func temperatureLine(_ geo: ChartGeometry) -> some ChartContent {
        ForEach(Array(hours.enumerated()), id: \.offset) { _, hour in
            LineMark(
                x: .value("tijd", hour.time),
                y: .value("temp", geo.normalizedTemp(hour.temperatureC)),
                series: .value("s", "temp")
            )
            .foregroundStyle(Tokens.temperature)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.linear)
        }
        ForEach(Array(hours.enumerated()), id: \.offset) { _, hour in
            PointMark(x: .value("tijd", hour.time), y: .value("temp", geo.normalizedTemp(hour.temperatureC)))
                .foregroundStyle(Tokens.temperature)
                .symbolSize(28)
        }
    }

    // MARK: - Axes

    @AxisContentBuilder
    private func yAxis(_ geo: ChartGeometry) -> some AxisContent {
        AxisMarks(position: .leading, values: geo.rainTicks) { value in
            if showRain {
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(verbatim: "\(Int(v))").foregroundStyle(Tokens.axisLabel)
                    }
                }
            }
        }
        AxisMarks(position: .trailing, values: geo.tempTicks.map(geo.normalizedTemp)) { value in
            if showTemp, let pos = value.as(Double.self) {
                AxisValueLabel {
                    Text(temperatureString(celsius: geo.temperature(atNormalized: pos), unit: temperatureUnit))
                        .foregroundStyle(Tokens.tempAxisLabel)
                }
            }
        }
    }

    @AxisContentBuilder
    private var xAxis: some AxisContent {
        let labels = tickLabels
        AxisMarks(values: hours.map(\.time)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 5]))
                .foregroundStyle(Tokens.grid)
            AxisValueLabel {
                if let key = value.as(String.self) {
                    Text(labels[key] ?? key)
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.axisLabel)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: 16, height: 40)
                }
            }
        }
    }

    // Reikt de gemeten plot-rechthoek aan de content door (gedeeld door de
    // background- en overlay-lagen), zodat de uitlijning op één plek zit.
    @ViewBuilder
    private func plotRect<Content: View>(_ proxy: ChartProxy, @ViewBuilder content: @escaping (CGRect) -> Content) -> some View {
        GeometryReader { geo in
            if let anchor = proxy.plotFrame {
                content(geo[anchor])
            }
        }
    }
}

// MARK: - Lagen (elk één verantwoordelijkheid)

// Lucht/helderheid-verloop als plot-achtergrond.
private struct SkyGradientBackground: View {
    let hours: [HourlyWeather]
    let colors: CellColors
    let twilightRadiation: Double

    var body: some View {
        let stops = buildSkyGradientStops(hours, colors: colors, twilightWm2: twilightRadiation)
            .map { Gradient.Stop(color: Color($0.color), location: $0.offset) }
        LinearGradient(
            stops: stops.isEmpty ? [Gradient.Stop(color: .clear, location: 0)] : stops,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// Score-badges + weericonen boven de plot, uitgelijnd op de banden via de proxy.
private struct ChartScoreIconRows: View {
    let hours: [HourlyWeather]
    let showIcons: Bool
    let proxy: ChartProxy
    let rect: CGRect
    let topRowsHeight: CGFloat
    var timeFormat: TimeFormat = .system

    var body: some View {
        ForEach(Array(hours.enumerated()), id: \.offset) { _, hour in
            if let xInPlot = proxy.position(forX: hour.time) {
                let x = rect.minX + xInPlot
                // Score-badge + icoon vormen samen één rij, verticaal gecentreerd in de
                // ruimte tussen de bovenrand van de sheet en de top van de grafiek.
                scoreBadge(hour)
                    .position(x: x, y: rect.minY - topRowsHeight + 16)
                if showIcons {
                    WeatherIcon(kind: hour.kind, size: 20)
                        .position(x: x, y: rect.minY - topRowsHeight + 40)
                        .accessibilityLabel(Text("a11y.timeWeather \(spokenTime(hour)) \(hour.kind.localizedText)"))
                }
            }
        }
    }

    // Leesbaar tijdstip voor VoiceOver: uur-punten in de gekozen notatie,
    // week-punten als weekdag.
    private func spokenTime(_ hour: HourlyWeather) -> String {
        if hour.time.contains(":") {
            return timeString(isoTime: hour.isoTime, format: timeFormat)
        }
        return weekdayLabel(date: IsoTime.date(hour.isoTime))
    }

    // Eén VoiceOver-element met leesbaar label ("Score 8 om 14:00").
    private func scoreBadge(_ hour: HourlyWeather) -> some View {
        ZStack {
            Circle().fill(scoreColor(hour.score)).frame(width: 22, height: 22)
            Text(verbatim: "\(hour.score)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("a11y.scoreAtTime \(hour.score) \(spokenTime(hour))"))
    }
}

// Rood gestippelde "nu"-lijn met temperatuur-label.
private struct ChartNowLine: View {
    let x: CGFloat
    let rect: CGRect
    let currentTemperatureC: Int?
    var temperatureUnit: TemperatureUnit = .system

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
            .stroke(Tokens.nowMarker, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            (currentTemperatureC.map { Text(verbatim: temperatureString(celsius: $0, unit: temperatureUnit)) } ?? Text("chart.now"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Tokens.nowMarker)
                .padding(.horizontal, 2)
                .background(.white.opacity(0.85))
                .position(x: x - 14, y: rect.minY + 8)
        }
    }
}

#Preview {
    let base = "2026-07-09"
    let sample: [HourlyWeather] = (0..<12).map { i in
        let h = i * 2
        let iso = "\(base)T\(String(format: "%02d", h)):00"
        let kinds: [WeatherKind] = [.cloud, .cloud, .cloud, .cloud, .partly, .sun, .sun, .partly, .partly, .cloud, .cloud, .cloud]
        let kind = kinds[i]
        let isDay = h >= 6 && h <= 21
        let precip = i == 3 ? 0.6 : (i == 9 ? 5.4 : 0)
        let temp = 16.0 + Double(i)
        return HourlyWeather(
            isoTime: iso,
            time: "\(String(format: "%02d", h)):00",
            temperatureC: temp,
            score: outdoorScore(precipitationMm: precip, temperatureC: temp, kind: kind, isDay: isDay),
            precipitationMm: precip,
            precipitationProbability: 20,
            cloudCover: 40,
            radiation: isDay ? 300 : 0,
            isDay: isDay,
            kind: kind
        )
    }
    return DayChart(
        hours: sample,
        horizon: .heleDag,
        cellColors: .defaults,
        showTemp: true,
        showRain: true,
        showIcons: true,
        twilightRadiation: defaultTwilightRadiationWm2,
        geometry: ChartGeometry(hours: sample),
        isToday: true,
        currentTemperatureC: 22
    )
    .padding()
}
