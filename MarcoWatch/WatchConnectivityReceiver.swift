//
//  WatchConnectivityReceiver.swift
//  MarcoWatch
//

import Foundation
import WatchConnectivity

extension Notification.Name {
    /// Disparada (na main thread) sempre que um snapshot novo chega do iPhone e é persistido.
    static let watchSnapshotUpdated = Notification.Name("watchSnapshotUpdated")
}

/// Recebe o snapshot das próximas datas enviado pelo iPhone via `WCSession
/// .updateApplicationContext(_:)` e persiste localmente (`WatchSnapshotStore`). `activationDidCompleteWith`
/// é o único método obrigatório do lado do Watch — `sessionDidBecomeInactive`/`sessionDidDeactivate`
/// não existem em watchOS (ver SPEC seção 7).
final class WatchConnectivityReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityReceiver()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?
    ) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data,
              let snapshots = try? JSONDecoder().decode([WatchDateSnapshot].self, from: data) else { return }
        WatchSnapshotStore.save(snapshots)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .watchSnapshotUpdated, object: nil)
        }
    }
}
