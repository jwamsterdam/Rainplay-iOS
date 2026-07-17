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
            // Cap the upper Dynamic Type range so the pixel-tuned hero layout stays intact.
            .dynamicTypeSize(.xSmall ... .accessibility1)
    }
}

#Preview {
    ContentView(model: AppModel())
}
