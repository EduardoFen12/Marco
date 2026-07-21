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
        AppShortcut(
            intent: DaysUntilDateIntent(),
            phrases: [
                "Quanto falta para \(\.$date) no \(.applicationName)",
                "Quantos dias faltam para \(\.$date) no \(.applicationName)",
            ],
            shortTitle: "Quanto falta",
            systemImageName: "hourglass"
        )
        AppShortcut(
            intent: AddImportantDateIntent(),
            phrases: [
                "Adicionar data no \(.applicationName)",
                "Nova data importante no \(.applicationName)",
            ],
            shortTitle: "Adicionar data",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: BirthdaysThisMonthIntent(),
            phrases: [
                "Quem faz aniversário esse mês no \(.applicationName)",
                "Aniversários do mês no \(.applicationName)",
            ],
            shortTitle: "Aniversários do mês",
            systemImageName: "gift"
        )
    }
}
