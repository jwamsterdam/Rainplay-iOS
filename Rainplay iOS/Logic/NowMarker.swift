import Foundation

// Pure, klok-geïnjecteerde positiehelper voor de "nu"-marker op de grafiek.
// 1:1 geport uit de PWA (src/lib/nowMarker.ts).
//
// De grafiek verdeelt n punten volgens een banden-model: punt i beslaat de band
// [i/n, (i+1)/n] en zijn CENTRUM ligt op fractie (i + 0.5)/n over de plot
// (hetzelfde model als de lucht-gradient, zie SkyGradient.swift). Deze functie
// geeft terug waar de huidige kloktijd in dat model valt als fractie in [0,1];
// de view projecteert dat naar pixels: x = plotX + fractie * plotBreedte.
//
// `now` wordt geïnjecteerd (nooit intern Date() lezen) zodat de berekening
// deterministisch en unit-testbaar is.
//
// Vergelijkt op volledige isoTime (datum + tijd) zodat vensters over middernacht
// (bijv. +6 uur: 23:00 → 04:30 de volgende dag) correct werken — een kale
// minuten-sinds-middernacht-vergelijking breekt daar, omdat 0:00 (0) vóór
// 23:00 (1380) sorteert en de marker om middernacht naar de rechterrand springt.

/// Horizontale positie van `now` als fractie in [0,1] over de plot, volgens het
/// band-centrum-model: het centrum van punt i ligt op (i + 0.5)/n.
///
/// Interpoleert in tijd tussen de twee omsluitende punten, dus het resultaat is
/// ((i + 0.5) + t)/n waarbij t de tijdfractie tussen punt i en i+1 is.
///
/// Het resultaat wordt GECLAMPT naar [0,1]: valt `now` vóór het eerste punt
/// (bijv. een +2/+6-uur-venster dat net na nu begint) dan pint hij op de
/// linkerrand; valt hij ná het laatste punt dan op de rechterrand.
///
/// Geeft ALLEEN nil terug bij degenereerde invoer (minder dan 2 punten — dan
/// valt er niets te interpoleren); de aanroeper rendert dan niets.
func nowFraction(isoTimes: [String], now: Date) -> Double? {
    let n = isoTimes.count
    guard n >= 2 else { return nil }

    let nowMs = now.timeIntervalSince1970 * 1000
    let timestamps = isoTimes.map { IsoTime.ms($0) }

    // Zoek de laatste bracket i waarvoor timestamps[i] <= nowMs.
    // timestamps is monotoon stijgend (middernacht-veilig via isoTime-datums).
    var i = 0
    while i < n - 2 && timestamps[i + 1] <= nowMs { i += 1 }
    var span = timestamps[i + 1] - timestamps[i]
    if span == 0 { span = 1 }
    let t = (nowMs - timestamps[i]) / span

    let fraction = (Double(i) + 0.5 + t) / Double(n)
    return min(1, max(0, fraction))
}
