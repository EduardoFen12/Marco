//
//  NotificationDelegate.swift
//  Marco
//

import Foundation
import UserNotifications
import Observation

/// Sinaliza para a UI que deve navegar até o detalhe de uma `ImportantDate`, a partir de uma
/// ação de notificação. Injetado no ambiente da app; `ImportantDateListView` observa
/// `pendingImportantDateID` e navega quando ele muda.
@Observable
final class NotificationNavigationCoordinator {
    var pendingImportantDateID: UUID?
}

/// Trata as ações das notificações interativas (T22).
///
/// - "Adiar": reagenda essa notificação específica para daqui a 3 horas — curto prazo (mesmo
///   dia), o suficiente pra não interromper o usuário agora mas lembrar de novo em breve.
/// - "Abrir para mensagem" e o toque direto (ação default) levam ao detalhe da data, onde o
///   usuário já encontra o botão "Gerar mensagem" (T11).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Duração do adiamento da ação "Adiar".
    static let snoozeInterval: TimeInterval = 3 * 60 * 60

    private let coordinator: NotificationNavigationCoordinator

    init(coordinator: NotificationNavigationCoordinator) {
        self.coordinator = coordinator
    }

    /// Novo horário de disparo da ação "Adiar", a partir de um instante de referência — lógica
    /// pura, testável sem `UNUserNotificationCenter`.
    static func snoozeFireDate(from referenceDate: Date = .now) -> Date {
        referenceDate.addingTimeInterval(snoozeInterval)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Mostra a notificação mesmo com o app em foreground.
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo[NotificationService.importantDateIDKey] as? String,
              let id = UUID(uuidString: idString) else {
            completionHandler()
            return
        }

        switch response.actionIdentifier {
        case NotificationService.snoozeActionIdentifier:
            let request = response.notification.request
            Task {
                await Self.reschedule(request, center: center)
                completionHandler()
            }
        case NotificationService.openMessageActionIdentifier, UNNotificationDefaultActionIdentifier:
            coordinator.pendingImportantDateID = id
            completionHandler()
        default:
            completionHandler()
        }
    }

    /// Reagenda a notificação recebida para `snoozeFireDate()`, preservando conteúdo e
    /// identificador — é um adiamento pontual, não recalcula os triggers das 3 camadas.
    private static func reschedule(_ request: UNNotificationRequest, center: UNUserNotificationCenter) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        let newRequest = UNNotificationRequest(identifier: request.identifier, content: request.content, trigger: trigger)
        try? await center.add(newRequest)
    }
}
