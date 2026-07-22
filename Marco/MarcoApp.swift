//
//  MarcoApp.swift
//  Marco
//
//  Created by Eduardo Garcia Fensterseifer on 16/07/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct MarcoApp: App {
    @State private var notificationCoordinator: NotificationNavigationCoordinator
    private let notificationDelegate: NotificationDelegate

    init() {
        let coordinator = NotificationNavigationCoordinator()
        _notificationCoordinator = State(initialValue: coordinator)
        // Guardado como propriedade (não local) — `UNUserNotificationCenter.delegate` é `weak`.
        notificationDelegate = NotificationDelegate(coordinator: coordinator)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        WatchConnectivityService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(notificationCoordinator)
        }
        .modelContainer(Persistence.container)
    }
}
