//
//  WatchDateListView.swift
//  MarcoWatch
//

import SwiftUI

/// Lista das próximas datas no Watch (T21), a partir do snapshot recebido do iPhone via
/// WatchConnectivity e persistido localmente (`WatchSnapshotStore`). Visual alinhado ao vocabulário
/// da Fase 3 (T41): cards `MarcoCardFill` com cantos arredondados, símbolo + cor por categoria e o
/// bloco "número grande + DIAS" de `ImportantDateRow` (`ImportantDateListView.swift`), escalado pra
/// caber numa tela de ~184–208pt de largura.
struct WatchDateListView: View {
    @State private var snapshots: [WatchDateSnapshot] = WatchSnapshotStore.load()

    var body: some View {
        NavigationStack {
            List {
                if snapshots.isEmpty {
                    WatchEmptyDatesView()
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(snapshots) { snapshot in
                        WatchDateRow(snapshot: snapshot)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Datas")
        }
        .onAppear { snapshots = WatchSnapshotStore.load() }
        .onReceive(NotificationCenter.default.publisher(for: .watchSnapshotUpdated)) { _ in
            snapshots = WatchSnapshotStore.load()
        }
    }
}

/// Card de uma data na lista do Watch (T41): símbolo + nome à esquerda, dias restantes + "DIAS" à
/// direita, ambos na cor da categoria (`WatchDateKind.categoryColor`) — mesma composição de
/// `ImportantDateRow`, com fontes e padding menores para a tela do Watch.
private struct WatchDateRow: View {
    let snapshot: WatchDateSnapshot

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: snapshot.kind.symbolName)
                .font(.caption2)
                .foregroundStyle(snapshot.kind.categoryColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.name)
                    .font(.footnote.bold())
                    .foregroundStyle(Color("MarcoLabel"))
                Text(snapshot.dateLabel)
                    .font(.caption2)
                    .foregroundStyle(Color("MarcoLabelSecondary"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 2)

            VStack(spacing: 0) {
                Text(snapshot.daysUntil(), format: .number)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.kind.categoryColor)
                Text("DIAS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color("MarcoLabelSecondary"))
            }
            .fixedSize()
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 10))
        .background(Color("MarcoCardFill"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Estado vazio (T41c): mesma mensagem de sempre, restilizada na paleta em vez do
/// `ContentUnavailableView` cru do sistema.
private struct WatchEmptyDatesView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(Color("MarcoLabelSecondary"))
            Text("Nenhuma data")
                .font(.headline)
                .foregroundStyle(Color("MarcoLabel"))
            Text("Abra o Marco no iPhone para sincronizar.")
                .font(.caption2)
                .foregroundStyle(Color("MarcoLabelSecondary"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#Preview {
    WatchDateListView()
}
