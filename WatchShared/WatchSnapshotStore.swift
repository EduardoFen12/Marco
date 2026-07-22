//
//  WatchSnapshotStore.swift
//  WatchShared
//

import Foundation
import WidgetKit

/// Persistência local do snapshot recebido via WatchConnectivity — App Group **próprio do Watch**
/// (`group.Eduardo.Marco.watch`), compartilhado só entre `MarcoWatch` e `MarcoWatchWidgets` (ambos
/// no mesmo dispositivo/processo; diferente do App Group do iPhone, que não atravessa pro Watch —
/// ver SPEC seção 7). Usado pelo app do Watch (grava ao receber contexto novo) e pela extensão de
/// complication (lê pra montar a timeline).
enum WatchSnapshotStore {
    static let appGroupID = "group.Eduardo.Marco.watch"
    private static let key = "upcomingDates"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Datas recebidas do iPhone, ordenadas por proximidade da próxima ocorrência.
    static func load() -> [WatchDateSnapshot] {
        guard let data = defaults?.data(forKey: key),
              let snapshots = try? JSONDecoder().decode([WatchDateSnapshot].self, from: data) else {
            return []
        }
        return snapshots.sorted { $0.nextOccurrence < $1.nextOccurrence }
    }

    /// Grava o snapshot novo e pede pro WidgetKit recarregar a complication.
    static func save(_ snapshots: [WatchDateSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        defaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
