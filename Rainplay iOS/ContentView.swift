//
//  ContentView.swift
//  Rainplay iOS
//
//  Created by jan.willem.hennink on 09/07/2026.
//

import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        WeatherScreen(model: model)
            // Laat tekst meeschalen met de Dynamic Type-voorkeur, maar begrens de
            // bovenkant zodat het pixel-getunede hero-ontwerp niet uit elkaar valt.
            .dynamicTypeSize(.xSmall ... .accessibility1)
    }
}

#Preview {
    ContentView(model: AppModel())
}
