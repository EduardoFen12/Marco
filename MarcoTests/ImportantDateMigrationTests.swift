//
//  ImportantDateMigrationTests.swift
//  MarcoTests
//

import Testing
import Foundation
import SwiftData
@testable import Marco

/// T30: `photoData`/`isFeatured` foram adicionados a `ImportantDate` como campos opcionais/com
/// default — lightweight migration do SwiftData, sem `SchemaMigrationPlan` na produção. Este
/// teste reproduz esse cenário de verdade: grava um store com o schema *anterior* a T30 (sem os
/// dois campos novos, mesmo formato do "V1") e depois abre o mesmo arquivo com o schema atual da
/// produção (`Marco.ImportantDate`, "V2"), via um `SchemaMigrationPlan` só de teste com um
/// estágio `.lightweight` — confirmando que dados antigos sobrevivem e os campos novos entram
/// com seus defaults, sem quebrar a abertura do store.
private enum ImportantDateSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [ImportantDate.self] }

    /// Espelha o formato de `Marco.ImportantDate` imediatamente antes da T30 (estado da T26):
    /// sem `photoData`/`isFeatured`.
    @Model
    final class ImportantDate {
        var id: UUID
        var name: String
        var date: Date
        var type: Marco.DateType
        var relationship: Marco.Relationship?
        var notes: String?
        var birthYear: Int?
        var notificationHour: Int = 9
        var notificationMinute: Int = 0
        var eventHour: Int?
        var eventMinute: Int?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            date: Date,
            type: Marco.DateType,
            relationship: Marco.Relationship? = nil,
            notes: String? = nil,
            birthYear: Int? = nil,
            notificationHour: Int = 9,
            notificationMinute: Int = 0,
            eventHour: Int? = nil,
            eventMinute: Int? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.date = date
            self.type = type
            self.relationship = relationship
            self.notes = notes
            self.birthYear = birthYear
            self.notificationHour = notificationHour
            self.notificationMinute = notificationMinute
            self.eventHour = eventHour
            self.eventMinute = eventMinute
            self.createdAt = createdAt
        }
    }
}

private enum ImportantDateSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Marco.ImportantDate.self] }
}

private enum ImportantDateTestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ImportantDateSchemaV1.self, ImportantDateSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: ImportantDateSchemaV1.self, toVersion: ImportantDateSchemaV2.self)]
    }
}

struct ImportantDateMigrationTests {
    @Test func storeGravadoAntesDaT30AbreComOSchemaAtualSemQuebrarEComDefaults() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarcoMigrationTest-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
        }

        // 1) Grava um store no formato anterior à T30 (sem photoData/isFeatured).
        do {
            let legacyConfiguration = ModelConfiguration(
                schema: Schema([ImportantDateSchemaV1.ImportantDate.self]), url: storeURL
            )
            let legacyContainer = try ModelContainer(
                for: Schema([ImportantDateSchemaV1.ImportantDate.self]), configurations: legacyConfiguration
            )
            let legacyContext = ModelContext(legacyContainer)
            let legacyDate = ImportantDateSchemaV1.ImportantDate(
                name: "Mari", date: .now, type: .birthday
            )
            legacyContext.insert(legacyDate)
            try legacyContext.save()
        }

        // 2) Reabre o mesmo arquivo com o schema atual (com photoData/isFeatured) via migration plan.
        let currentConfiguration = ModelConfiguration(schema: Schema([ImportantDate.self]), url: storeURL)
        let currentContainer = try ModelContainer(
            for: Schema([ImportantDate.self]),
            migrationPlan: ImportantDateTestMigrationPlan.self,
            configurations: currentConfiguration
        )
        let currentContext = ModelContext(currentContainer)
        let migrated = try currentContext.fetch(FetchDescriptor<ImportantDate>())

        #expect(migrated.count == 1)
        #expect(migrated.first?.name == "Mari")
        #expect(migrated.first?.photoData == nil)
        #expect(migrated.first?.isFeatured == false)
    }
}
