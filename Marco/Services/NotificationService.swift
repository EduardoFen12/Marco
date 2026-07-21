//
//  NotificationService.swift
//  Marco
//

import Foundation
import UserNotifications

/// As 3 camadas de lembrete de uma `ImportantDate`.
enum NotificationLayer: String, CaseIterable {
    case week
    case day
    case onDay

    /// Quantos dias antes da ocorrência esta camada dispara.
    var daysBefore: Int {
        switch self {
        case .week: return 7
        case .day: return 1
        case .onDay: return 0
        }
    }

    var body: String {
        switch self {
        case .week: return "Falta 1 semana"
        case .day: return "Falta 1 dia"
        case .onDay: return "É hoje!"
        }
    }
}

/// Trigger calculado para uma camada de notificação: identificador determinístico +
/// `DateComponents` para um `UNCalendarNotificationTrigger` recorrente anual.
struct NotificationTriggerSpec: Equatable { 
    let layer: NotificationLayer
    let identifier: String
    let dateComponents: DateComponents
}

/// Agenda e cancela as notificações locais das 3 camadas (1 semana antes, 1 dia antes, no dia)
/// de uma `ImportantDate`. A lógica de cálculo dos triggers é pura e testável sem tocar
/// `UNUserNotificationCenter`; `schedule`/`cancel` são wrappers finos sobre o center.
enum NotificationService {
    static func identifiers(for importantDate: ImportantDate) -> [String] {
        NotificationLayer.allCases.map { identifier(for: importantDate, layer: $0) }
    }

    static func identifier(for importantDate: ImportantDate, layer: NotificationLayer) -> String {
        switch layer {
        case .week: return "\(importantDate.id.uuidString)-week"
        case .day: return "\(importantDate.id.uuidString)-day"
        case .onDay: return "\(importantDate.id.uuidString)-onDay"
        }
    }

    /// Calcula os triggers das 3 camadas a partir da próxima ocorrência de `importantDate.date`.
    /// Puro (sem I/O) — usado tanto pelo agendamento real quanto pelos testes.
    static func triggerSpecs(
        for importantDate: ImportantDate,
        from referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [NotificationTriggerSpec] {
        let occurrence = importantDate.nextOccurrence(from: referenceDate, calendar: calendar)
        return NotificationLayer.allCases.compactMap { layer in
            guard let fireDate = calendar.date(byAdding: .day, value: -layer.daysBefore, to: occurrence) else {
                return nil
            }
            var components = calendar.dateComponents([.month, .day], from: fireDate)
            components.hour = importantDate.notificationHour
            components.minute = importantDate.notificationMinute
            return NotificationTriggerSpec(
                layer: layer,
                identifier: identifier(for: importantDate, layer: layer),
                dateComponents: components
            )
        }
    }

    /// Cancela as notificações pendentes das 3 camadas, pede permissão (se ainda não concedida)
    /// e agenda novamente. Chamado tanto na criação quanto na edição de uma `ImportantDate`.
    static func schedule(_ importantDate: ImportantDate, center: UNUserNotificationCenter = .current()) async {
        cancel(importantDate, center: center)

        // ponytail: ignora erro/negação da permissão — add(request) ainda registra o pending
        // request mesmo sem autorização (só a entrega fica bloqueada), então o agendamento
        // não depende do usuário ter concedido permissão.
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        for spec in triggerSpecs(for: importantDate) {
            let content = UNMutableNotificationContent()
            content.title = importantDate.name
            content.body = spec.layer.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: spec.dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: spec.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Cancela as 3 notificações pendentes de uma `ImportantDate` (chamado na exclusão).
    static func cancel(_ importantDate: ImportantDate, center: UNUserNotificationCenter = .current()) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: importantDate))
    }
}
