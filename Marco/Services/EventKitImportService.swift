//
//  EventKitImportService.swift
//  Marco
//

import EventKit
import Foundation

/// Busca eventos do Calendário do aparelho (incl. o calendário de Aniversários) como candidatos
/// a `ImportantDate` (T17). Permissão pedida sob demanda; qualquer falha (negada, restrita ou
/// erro de fetch) degrada para lista vazia — nunca propaga erro nem derruba o app.
enum EventKitImportService {
    /// Busca eventos num intervalo razoável (hoje até +2 anos) e os converte em candidatos de
    /// importação. `nonisolated` e bloqueante por dentro (`events(matching:)` é síncrono) — por
    /// isso roda fora do MainActor, para não travar a UI durante a varredura.
    nonisolated static func fetchCandidates(store: EKEventStore = EKEventStore()) async -> [ImportCandidate] {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            break
        case .notDetermined:
            do {
                guard try await store.requestFullAccessToEvents() else { return [] }
            } catch {
                return []
            }
        case .restricted, .denied, .writeOnly:
            return []
        @unknown default:
            return []
        }

        let calendar = Calendar.current
        let start = Date.now
        guard let end = calendar.date(byAdding: .year, value: 2, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        return events.compactMap { event in
            candidate(
                name: event.title,
                date: event.startDate,
                isBirthday: event.birthdayContactIdentifier != nil || event.calendar?.type == .birthday
            )
        }
    }

    /// Converte os campos relevantes de um `EKEvent` num `ImportCandidate`. Lógica pura, sem
    /// tocar o EventKit — testável isoladamente. `birthYear` sempre `nil` (EventKit não expõe o
    /// ano de nascimento diretamente). `nil` quando título, data, ou mês/dia da data estão ausentes.
    static func candidate(name: String?, date: Date?, isBirthday: Bool, calendar: Calendar = .current) -> ImportCandidate? {
        guard let date else { return nil }
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedName.isEmpty else { return nil }
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day,
              let normalizedDate = calendar.date(from: DateComponents(year: 2000, month: month, day: day)) else {
            return nil
        }
        return ImportCandidate(
            name: trimmedName,
            date: normalizedDate,
            type: isBirthday ? .birthday : .commemorative,
            birthYear: nil,
            source: .calendar
        )
    }
}
