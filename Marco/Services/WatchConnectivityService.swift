//
//  WatchConnectivityService.swift
//  Marco
//

import Foundation
import WatchConnectivity

/// Envia pro Apple Watch, via `WCSession.updateApplicationContext(_:)`, um snapshot leve das
/// próximas datas (nome, tipo, próxima ocorrência) — App Group não é compartilhado entre iOS e
/// watchOS (dispositivos físicos separados, ver SPEC seção 7), então a sincronização usa
/// WatchConnectivity, que entrega o estado mais recente mesmo com os dois apps fechados.
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
    }

    /// Ativa a sessão; chamar uma vez no lançamento do app (`MarcoApp.init`).
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Reconstrói o snapshot a partir de todas as `ImportantDate` atuais e envia pro Watch.
    /// Chamado do ponto único de CRUD (`NotificationService.cancel`), junto com o reload do
    /// widget iOS (T20).
    func sync(_ importantDates: [ImportantDate]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let snapshots = importantDates
            .map {
                WatchDateSnapshot(
                    id: $0.id,
                    name: $0.name,
                    kind: WatchDateKind(dateType: $0.type),
                    nextOccurrence: $0.nextOccurrence()
                )
            }
            .sorted { $0.nextOccurrence < $1.nextOccurrence }
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

private extension WatchDateKind {
    init(dateType: DateType) {
        switch dateType {
        case .birthday: self = .birthday
        case .commemorative: self = .commemorative
        case .memorial: self = .memorial
        }
    }
}
