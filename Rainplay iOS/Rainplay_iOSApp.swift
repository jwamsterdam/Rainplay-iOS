//
//  Rainplay_iOSApp.swift
//  Rainplay iOS
//
//  Created by jan.willem.hennink on 09/07/2026.
//

import SwiftUI

// swiftlint:disable:next type_name
@main
struct Rainplay_iOSApp: App { // Xcode-generated @main name; underscore is intentional
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await model.appBecameActive() }
                    }
                }
        }
    }
}
