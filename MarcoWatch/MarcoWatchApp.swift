//
//  MarcoWatchApp.swift
//  MarcoWatch
//

import SwiftUI

@main
struct MarcoWatchApp: App {
    init() {
        WatchConnectivityReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchDateListView()
        }
    }
}
