//
//  ContactsImportService.swift
//  Marco
//

import Contacts
import Foundation

/// Busca aniversários dos Contatos do aparelho como candidatos a `ImportantDate` (T16).
/// Permissão pedida sob demanda; qualquer falha (negada, restrita ou erro de fetch) degrada
/// para lista vazia — nunca propaga erro nem derruba o app.
enum ContactsImportService {
    /// Busca os contatos com aniversário cadastrado e os converte em candidatos de importação.
    /// `nonisolated` e bloqueante por dentro (`enumerateContacts` é síncrono) — por isso roda
    /// fora do MainActor, para não travar a UI durante a varredura.
    nonisolated static func fetchCandidates(store: CNContactStore = CNContactStore()) async -> [ImportCandidate] {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            break
        case .notDetermined:
            guard let granted = try? await store.requestAccess(for: .contacts), granted else { return [] }
        case .denied, .restricted:
            return []
        @unknown default:
            return []
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var candidates: [ImportCandidate] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                guard let birthday = contact.birthday else { return }
                let name = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                guard let candidate = candidate(name: name, birthday: birthday) else { return }
                candidates.append(candidate)
            }
        } catch {
            return []
        }
        return candidates
    }

    /// Converte um `CNContact.birthday` + nome num `ImportCandidate`. Lógica pura, sem tocar o
    /// Contacts framework — testável isoladamente. `nil` quando mês/dia estão ausentes (a API
    /// os declara opcionais) ou o nome está vazio.
    static func candidate(name: String, birthday: DateComponents, calendar: Calendar = .current) -> ImportCandidate? {
        guard let month = birthday.month, let day = birthday.day else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let date = calendar.date(from: DateComponents(year: 2000, month: month, day: day)) ?? .now
        return ImportCandidate(
            name: trimmedName,
            date: date,
            type: .birthday,
            birthYear: birthday.year,
            source: .contacts
        )
    }
}
