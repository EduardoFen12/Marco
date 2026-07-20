//
//  MarcoShortcuts.swift
//  Marco
//

import AppIntents

/// Frases registradas para invocação por voz/Shortcuts sem setup manual do usuário.
struct MarcoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UpcomingDatesIntent(),
            phrases: [
                "Quais datas estão chegando no \(.applicationName)",
                "Datas chegando no \(.applicationName)",
                "Mostrar próximas datas no \(.applicationName)",
            ],
            shortTitle: "Datas chegando",
            systemImageName: "calendar"
        )
    }
}
