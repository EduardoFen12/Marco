//
//  ImportantDate.swift
//  Marco
//

import Foundation
import SwiftData

@Model
final class ImportantDate {
    var id: UUID
    var name: String
    var date: Date
    var type: DateType
    var relationship: Relationship?
    var notes: String?
    /// Ano de nascimento, opcional; só relevante quando `type == .birthday`. Separado de `date`
    /// (que guarda dia/mês contra o ano bissexto fixo 2000) para habilitar `age(on:)`.
    var birthYear: Int?
    /// Hora/minuto do lembrete desta data específica; vale para as 3 camadas de notificação.
    /// Novos campos com default — lightweight migration do SwiftData para stores existentes.
    var notificationHour: Int = 9
    var notificationMinute: Int = 0
    /// Hora/minuto em que o evento em si acontece (ex: aniversário às 19h) — distinto de
    /// `notificationHour`/`notificationMinute`, que só controlam o lembrete. `nil` em ambos
    /// (default) = evento sem hora definida, comportamento preservado. Campos opcionais novos,
    /// default `nil` — lightweight migration do SwiftData para stores existentes.
    var eventHour: Int?
    var eventMinute: Int?
    var createdAt: Date
    /// Foto da data (T30/T31), gravada já redimensionada/comprimida pelo form — não o arquivo
    /// bruto do `PhotosPicker`. `.externalStorage` deixa o SwiftData decidir se guarda inline ou
    /// num arquivo à parte conforme o tamanho, em vez de inchar a linha da tabela. Campo opcional
    /// novo, default `nil` — lightweight migration do SwiftData para stores existentes.
    @Attribute(.externalStorage) var photoData: Data?
    /// Data em destaque (mostrada no card do topo da Home, T33). Exclusividade (só uma por vez) e
    /// a regra de nascimento (1ª data criada num store vazio nasce em destaque) são responsabilidade
    /// de `ImportantDate.insert(_:into:)`/`markAsFeatured(in:)` — ponto único de escrita, não deve
    /// ser setada diretamente pelos call sites de criação/edição. Campo novo com default `false` —
    /// lightweight migration do SwiftData para stores existentes.
    var isFeatured: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        type: DateType,
        relationship: Relationship? = nil,
        notes: String? = nil,
        birthYear: Int? = nil,
        notificationHour: Int = 9,
        notificationMinute: Int = 0,
        eventHour: Int? = nil,
        eventMinute: Int? = nil,
        createdAt: Date = .now,
        photoData: Data? = nil,
        isFeatured: Bool = false
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
        self.photoData = photoData
        self.isFeatured = isFeatured
    }
}

// MARK: - Destaque (isFeatured)

extension ImportantDate {
    /// Ponto único de escrita para inserir uma nova `ImportantDate` no `context`. Aplica a regra
    /// de nascimento em destaque (T30): quando o store está vazio no momento da inserção, a data
    /// nasce em destaque; do contrário nasce sem destaque. Todo fluxo de criação (form, App
    /// Intent, importação) deve chamar este método em vez de `context.insert` diretamente, para
    /// a regra e a exclusividade valerem em todos os lugares.
    static func insert(_ importantDate: ImportantDate, into context: ModelContext) {
        let isStoreEmpty = ((try? context.fetchCount(FetchDescriptor<ImportantDate>())) ?? 0) == 0
        context.insert(importantDate)
        if isStoreEmpty {
            importantDate.markAsFeatured(in: context)
        }
    }

    /// Marca esta data como destaque, desmarcando todas as demais no `context` — ponto único de
    /// escrita da exclusividade de `isFeatured` (garante no máximo uma data em destaque por vez).
    func markAsFeatured(in context: ModelContext) {
        let selfID = id
        let othersFeatured = FetchDescriptor<ImportantDate>(
            predicate: #Predicate { $0.isFeatured && $0.id != selfID }
        )
        if let others = try? context.fetch(othersFeatured) {
            for other in others {
                other.isFeatured = false
            }
        }
        isFeatured = true
    }
}

// MARK: - Próxima ocorrência

extension ImportantDate {
    /// Próxima ocorrência anual (dia/mês de `date`) a partir de `referenceDate`.
    /// Se a data cair no próprio `referenceDate`, essa é a ocorrência retornada (0 dias restantes).
    func nextOccurrence(from referenceDate: Date = .now, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return date }
        return Self.nextOccurrence(ofMonth: month, day: day, from: referenceDate, calendar: calendar)
    }

    /// Dias restantes (inteiro, pode ser 0 hoje) até a próxima ocorrência.
    func daysUntilNextOccurrence(from referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let occurrence = nextOccurrence(from: referenceDate, calendar: calendar)
        return calendar.dateComponents([.day], from: startOfToday, to: occurrence).day ?? 0
    }

    /// Idade que a pessoa completa na próxima ocorrência do aniversário (ano da ocorrência
    /// menos `birthYear`). `nil` quando `birthYear` não está preenchido.
    func age(on referenceDate: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let birthYear else { return nil }
        let occurrence = nextOccurrence(from: referenceDate, calendar: calendar)
        return calendar.component(.year, from: occurrence) - birthYear
    }

    /// Calcula a próxima data (dia `day`/mês `month`, ignorando ano) que seja igual ou posterior
    /// a `referenceDate`. Testa o ano corrente e o próximo; para 29/02 numa sequência de anos
    /// não-bissextos, avança até o próximo ano bissexto (ponytail: laço linear, ok para o alcance
    /// de poucos anos até o próximo bissexto — trocar por cálculo direto se isso virar hot path).
    static func nextOccurrence(ofMonth month: Int, day: Int, from referenceDate: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: referenceDate)
        let currentYear = calendar.component(.year, from: today)

        var year = currentYear
        while true {
            if let candidate = exactDate(year: year, month: month, day: day, calendar: calendar) {
                let candidateDay = calendar.startOfDay(for: candidate)
                if candidateDay >= today {
                    return candidateDay
                }
            }
            year += 1
        }
    }

    /// Constrói a data para `year`/`month`/`day`, retornando `nil` se ela não existir nesse ano
    /// (ex: 29/02 fora de ano bissexto) em vez de deixar o `Calendar` normalizar para o dia seguinte.
    private static func exactDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else { return nil }
        return date
    }
}
