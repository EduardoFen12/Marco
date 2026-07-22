//
//  WatchDateListView.swift
//  MarcoWatch
//

import SwiftUI

/// Lista das próximas datas no Watch (T21), a partir do snapshot recebido do iPhone via
/// WatchConnectivity e persistido localmente (`WatchSnapshotStore`).
struct WatchDateListView: View {
    @State private var snapshots: [WatchDateSnapshot] = WatchSnapshotStore.load()

    var body: some View {
        NavigationStack {
            List {
                if snapshots.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma data",
                        systemImage: "calendar",
                        description: Text("Abra o Marco no iPhone para sincronizar.")
                    )
                } else {
                    ForEach(snapshots) { snapshot in
                        HStack {
                            Image(systemName: snapshot.kind.symbolName)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snapshot.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(snapshot.daysUntilLabel())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Datas")
        }
        .onAppear { snapshots = WatchSnapshotStore.load() }
        .onReceive(NotificationCenter.default.publisher(for: .watchSnapshotUpdated)) { _ in
            snapshots = WatchSnapshotStore.load()
        }
    }
}

#Preview {
    WatchDateListView()
}
