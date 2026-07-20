//
//  MarcoTests.swift
//  MarcoTests
//
//  Created by Eduardo Garcia Fensterseifer on 16/07/26.
//

import Testing
import Foundation
@testable import Marco

struct MarcoTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

}

struct ImportantDateNextOccurrenceTests {
    let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func ocorrenciaAindaNaoPassouEsteAno() {
        // Aniversário em 31/05, hoje é 20/07/2026 → passou este ano, próxima é 2027.
        let importantDate = ImportantDate(name: "Mari", date: date(1990, 5, 31), type: .birthday)
        let today = date(2026, 7, 20)

        let next = importantDate.nextOccurrence(from: today, calendar: calendar)

        #expect(calendar.component(.year, from: next) == 2027)
        #expect(calendar.component(.month, from: next) == 5)
        #expect(calendar.component(.day, from: next) == 31)
    }

    @Test func ocorrenciaAindaNaoChegouEsteAno() {
        // Aniversário em 25/12, hoje é 20/07/2026 → ainda não chegou este ano.
        let importantDate = ImportantDate(name: "Natal", date: date(2000, 12, 25), type: .commemorative)
        let today = date(2026, 7, 20)

        let next = importantDate.nextOccurrence(from: today, calendar: calendar)

        #expect(calendar.component(.year, from: next) == 2026)
        #expect(calendar.component(.month, from: next) == 12)
        #expect(calendar.component(.day, from: next) == 25)
    }

    @Test func ocorrenciaHojeContaComoProximaOcorrencia() {
        let importantDate = ImportantDate(name: "Hoje", date: date(1995, 7, 20), type: .birthday)
        let today = date(2026, 7, 20)

        let next = importantDate.nextOccurrence(from: today, calendar: calendar)

        #expect(calendar.isDate(next, inSameDayAs: today))
        #expect(importantDate.daysUntilNextOccurrence(from: today, calendar: calendar) == 0)
    }

    @Test func viradaDeAno() {
        // Hoje 20/12, data comemorativa em 02/01 → próxima ocorrência é ano seguinte.
        let importantDate = ImportantDate(name: "Ano Novo", date: date(2000, 1, 2), type: .commemorative)
        let today = date(2026, 12, 20)

        let next = importantDate.nextOccurrence(from: today, calendar: calendar)

        #expect(calendar.component(.year, from: next) == 2027)
        #expect(calendar.component(.month, from: next) == 1)
        #expect(calendar.component(.day, from: next) == 2)
    }

    @Test func fevereiro29EmAnoNaoBissextoPulaParaProximoBissexto() {
        // Hoje é 01/03/2026 (não bissexto): a próxima ocorrência de 29/02 deve ser 2028 (bissexto).
        let importantDate = ImportantDate(name: "Bissexto", date: date(2000, 2, 29), type: .birthday)
        let today = date(2026, 3, 1)

        let next = importantDate.nextOccurrence(from: today, calendar: calendar)

        #expect(calendar.component(.year, from: next) == 2028)
        #expect(calendar.component(.month, from: next) == 2)
        #expect(calendar.component(.day, from: next) == 29)
    }

    @Test func fevereiro29NoProprioAnoBissexto() {
        // Hoje é 10/01/2028 (bissexto): a próxima ocorrência de 29/02 é no mesmo ano.
        let importantDate = ImportantDate(name: "Bissexto", date: date(2000, 2, 29), type: .birthday)
        let today = date(2028, 1, 10)

        let next = importantDate.nextOccurrence(from: today, calendar: calendar)

        #expect(calendar.component(.year, from: next) == 2028)
        #expect(calendar.component(.month, from: next) == 2)
        #expect(calendar.component(.day, from: next) == 29)
    }

    @Test func fevereiro29JaPassouNoAnoBissextoVaiParaProximoBissexto() {
        // Hoje é 01/03/2028 (já passou 29/02 deste ano bissexto) → próxima é 2032.
        let importantDate = ImportantDate(name: "Bissexto", date: date(2000, 2, 29), type: .birthday)
        let today = date(2028, 3, 1)

        let next = importantDate.nextOccurrence(from: today, calendar: calendar)

        #expect(calendar.component(.year, from: next) == 2032)
        #expect(calendar.component(.month, from: next) == 2)
        #expect(calendar.component(.day, from: next) == 29)
    }

    @Test func diasRestantesConsideraVirada() {
        let importantDate = ImportantDate(name: "Ano Novo", date: date(2000, 1, 2), type: .commemorative)
        let today = date(2026, 12, 31)

        // 31/12 → 02/01 do ano seguinte = 2 dias.
        #expect(importantDate.daysUntilNextOccurrence(from: today, calendar: calendar) == 2)
    }
}

struct NotificationServiceTests {
    let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func geraAs3CamadasComIdentificadoresDeterministicos() {
        let importantDate = ImportantDate(name: "Mari", date: date(1990, 5, 31), type: .birthday)
        let today = date(2026, 1, 1)

        let specs = NotificationService.triggerSpecs(for: importantDate, from: today, calendar: calendar)

        #expect(specs.count == 3)
        #expect(specs.map(\.layer) == [.week, .day, .onDay])
        #expect(specs.map(\.identifier) == [
            "\(importantDate.id.uuidString)-week",
            "\(importantDate.id.uuidString)-day",
            "\(importantDate.id.uuidString)-onDay",
        ])
    }

    @Test func camadaNoDiaUsaDiaMesDaProximaOcorrencia() {
        let importantDate = ImportantDate(name: "Mari", date: date(1990, 5, 31), type: .birthday)
        let today = date(2026, 1, 1)

        let onDay = NotificationService.triggerSpecs(for: importantDate, from: today, calendar: calendar)
            .first { $0.layer == .onDay }!

        #expect(onDay.dateComponents.month == 5)
        #expect(onDay.dateComponents.day == 31)
        #expect(onDay.dateComponents.hour == NotificationService.defaultHour)
        #expect(onDay.dateComponents.minute == NotificationService.defaultMinute)
    }

    @Test func camadasDeAvisoSaoDeslocadasParaTras() {
        // Próxima ocorrência: 31/05. 1 semana antes → 24/05. 1 dia antes → 30/05.
        let importantDate = ImportantDate(name: "Mari", date: date(1990, 5, 31), type: .birthday)
        let today = date(2026, 1, 1)

        let specs = NotificationService.triggerSpecs(for: importantDate, from: today, calendar: calendar)
        let week = specs.first { $0.layer == .week }!
        let day = specs.first { $0.layer == .day }!

        #expect(week.dateComponents.month == 5)
        #expect(week.dateComponents.day == 24)
        #expect(day.dateComponents.month == 5)
        #expect(day.dateComponents.day == 30)
    }

    @Test func deslocamentoAtravessaViradaDeMes() {
        // Próxima ocorrência: 02/01/2027. 1 semana antes → 26/12/2026. 1 dia antes → 01/01/2027.
        let importantDate = ImportantDate(name: "Ano Novo", date: date(2000, 1, 2), type: .commemorative)
        let today = date(2026, 12, 20)

        let specs = NotificationService.triggerSpecs(for: importantDate, from: today, calendar: calendar)
        let week = specs.first { $0.layer == .week }!
        let day = specs.first { $0.layer == .day }!
        let onDay = specs.first { $0.layer == .onDay }!

        #expect(week.dateComponents.month == 12)
        #expect(week.dateComponents.day == 26)
        #expect(day.dateComponents.month == 1)
        #expect(day.dateComponents.day == 1)
        #expect(onDay.dateComponents.month == 1)
        #expect(onDay.dateComponents.day == 2)
    }

    @Test func naoQuebraParaDataEm29DeFevereiro() {
        // Não deve travar/forçar unwrap mesmo quando a ocorrência recai numa sequência
        // envolvendo 29/02 em ano não-bissexto.
        let importantDate = ImportantDate(name: "Bissexto", date: date(2000, 2, 29), type: .birthday)
        let today = date(2026, 3, 1)

        let specs = NotificationService.triggerSpecs(for: importantDate, from: today, calendar: calendar)

        #expect(specs.count == 3)
    }

    @Test func identifiersRetornaOsMesmos3IdsDosTriggers() {
        let importantDate = ImportantDate(name: "Mari", date: date(1990, 5, 31), type: .birthday)

        let ids = Set(NotificationService.identifiers(for: importantDate))
        let specIds = Set(NotificationService.triggerSpecs(for: importantDate).map(\.identifier))

        #expect(ids == specIds)
    }
}
