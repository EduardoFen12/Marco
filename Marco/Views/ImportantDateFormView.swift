//
//  ImportantDateFormView.swift
//  Marco
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

/// Tela de criação/edição de uma `ImportantDate`. Passe `importantDate: nil` para criar
/// uma nova data ou a instância existente para editá-la.
///
/// Redesenho T35: campos agrupados em cards por seção (`FormSectionCard`, label flutuante),
/// sem `Form`/`List` nativos. As sugestões de IA (T11/T23) migraram para
/// `ImportantDateDetailView` (T32) — este form não faz mais nenhuma chamada ao
/// `AISuggestionService`.
struct ImportantDateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let importantDate: ImportantDate?

    @State private var name: String
    @State private var date: Date
    @State private var birthdayMonth: Int
    @State private var birthdayDay: Int
    @State private var type: DateType
    @State private var relationship: Relationship?
    @State private var notes: String
    @State private var birthYearText: String
    @State private var notificationTime: Date
    @State private var hasEventTime: Bool
    @State private var eventTime: Date
    @State private var photoData: Data?
    @State private var photoPickerItem: PhotosPickerItem?

    init(importantDate: ImportantDate?) {
        self.importantDate = importantDate
        _name = State(initialValue: importantDate?.name ?? "")
        _date = State(initialValue: importantDate?.date ?? .now)
        let referenceDate = importantDate?.date ?? .now
        let components = Calendar.current.dateComponents([.month, .day], from: referenceDate)
        _birthdayMonth = State(initialValue: components.month ?? 1)
        _birthdayDay = State(initialValue: components.day ?? 1)
        _type = State(initialValue: importantDate?.type ?? .birthday)
        _relationship = State(initialValue: importantDate?.relationship)
        _notes = State(initialValue: importantDate?.notes ?? "")
        _birthYearText = State(initialValue: importantDate?.birthYear.map(String.init) ?? "")
        _notificationTime = State(initialValue: Self.time(
            hour: importantDate?.notificationHour ?? 9,
            minute: importantDate?.notificationMinute ?? 0
        ))
        let eventHour = importantDate?.eventHour
        let eventMinute = importantDate?.eventMinute
        _hasEventTime = State(initialValue: eventHour != nil && eventMinute != nil)
        _eventTime = State(initialValue: Self.time(hour: eventHour ?? 12, minute: eventMinute ?? 0))
        _photoData = State(initialValue: importantDate?.photoData)
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Componentes de hora/minuto extraídos de `time`, prontos para gravar em
    /// `notificationHour`/`notificationMinute`.
    static func timeComponents(from time: Date, calendar: Calendar = .current) -> (hour: Int, minute: Int) {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return (components.hour ?? 9, components.minute ?? 0)
    }

    /// Monta um `Date` de referência com a hora/minuto informados — usado para inicializar
    /// o `DatePicker` de hora a partir dos valores salvos em `notificationHour`/`notificationMinute`.
    static func time(hour: Int, minute: Int, calendar: Calendar = .current, referenceDate: Date = .now) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate) ?? referenceDate
    }

    /// Compõe a data de um aniversário a partir de mês/dia escolhidos nos `Picker`s, contra o
    /// ano bissexto fixo 2000 (mesma convenção do model — ver `ImportantDate.swift`), para 29/02
    /// ser sempre selecionável independente do ano de nascimento.
    static func birthdayDate(month: Int, day: Int, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: month, day: day)) ?? .now
    }

    /// Dias válidos do mês informado, contra o ano fixo 2000 (bissexto — fevereiro sempre tem 29).
    static func daysInBirthdayMonth(_ month: Int, calendar: Calendar = .current) -> [Int] {
        let reference = calendar.date(from: DateComponents(year: 2000, month: month, day: 1)) ?? .now
        let range = calendar.range(of: .day, in: .month, for: reference) ?? 1..<32
        return Array(range)
    }

    /// Parseia o campo opcional "Ano de nascimento" para `Int?` — `nil` se vazio ou inválido.
    static func parseBirthYear(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Redimensiona `image` para no máximo `maxDimension` no maior lado (preservando proporção) e
    /// comprime como JPEG — nunca grava o arquivo bruto do `PhotosPicker` em `photoData`. Função
    /// pura (`nonisolated static`), testável direto sem tocar a view.
    static func compressedPhotoData(
        from image: UIImage,
        maxDimension: CGFloat = 800,
        compressionQuality: CGFloat = 0.7
    ) -> Data? {
        let size = image.size
        let largestSide = max(size.width, size.height)
        let scale = largestSide > maxDimension ? maxDimension / largestSide : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        // `scale = 1` faz o JPEG codificado ter exatamente `targetSize` em pixels — sem isso, o
        // renderer usa a escala nativa da tela (2x/3x) e o `UIImage(data:)` recarregado (que
        // assume escala 1 por padrão) reportaria `size` maior que `maxDimension`.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoHeader
                identificationCard
                whenCard
                remindersCard
                categoryCard
                relationshipCard
                notesCard
                saveButton
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color("MarcoCream").ignoresSafeArea())
        .navigationTitle(importantDate == nil ? "Nova data" : "Editar data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if importantDate == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(!isNameValid)
                .accessibilityLabel(Text("Salvar"))
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task { await loadPickedPhoto(newItem) }
        }
        // Empurrada a partir do Detalhe ao editar (T36, mock Figma): esconde a tab bar. Quando
        // esta view é a "Nova Data" aberta via sheet (`ImportantDateListView`), o modificador é
        // inofensivo — a tab bar já fica coberta pela apresentação modal, sem depender dele.
        .toolbar(.hidden, for: .tabBar)
    }

    /// Banner de foto (T31): ~192pt de altura, cantos com radius 32. Sem foto, mostra um estado
    /// vazio com borda tracejada + ícone + texto, claramente tocável (não um ícone de câmera
    /// sobreposto à imagem). Tocar em qualquer estado abre o `PhotosPicker`.
    private var photoHeader: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            Group {
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color("MarcoCardFill"))
                        RoundedRectangle(cornerRadius: 32)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundStyle(Color("MarcoLabelSecondary").opacity(0.4))
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title)
                            Text("Adicionar foto")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Color("MarcoLabelSecondary"))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 192)
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photoData == nil ? Text("Adicionar foto") : Text("Trocar foto"))
        .padding(.top, 8)
    }

    @MainActor
    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        photoData = Self.compressedPhotoData(from: uiImage)
    }

    // MARK: - Cards

    private var identificationCard: some View {
        FormSectionCard(label: "Identificação") {
            TextField("Nome", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color("MarcoCream"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Mantém a lógica atual (T14): seletor completo de data para não-aniversário, dia/mês +
    /// ano opcional (com idade calculada) para aniversário.
    private var whenCard: some View {
        FormSectionCard(label: "Quando") {
            VStack(alignment: .leading, spacing: 12) {
                if type == .birthday {
                    HStack(spacing: 12) {
                        Picker("Mês", selection: $birthdayMonth) {
                            ForEach(Array(Calendar.current.monthSymbols.enumerated()), id: \.offset) { index, symbol in
                                Text(symbol.capitalized).tag(index + 1)
                            }
                        }
                        Picker("Dia", selection: $birthdayDay) {
                            ForEach(Self.daysInBirthdayMonth(birthdayMonth), id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: birthdayMonth) {
                        let validDays = Self.daysInBirthdayMonth(birthdayMonth)
                        if !validDays.contains(birthdayDay) {
                            birthdayDay = validDays.last ?? 1
                        }
                    }

                    TextField("Ano de nascimento (opcional)", text: $birthYearText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color("MarcoCream"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let ageLabel = ImportantDate.ageLabel(forAge: importantDate?.age()) {
                        Text(ageLabel)
                            .font(.footnote)
                            .foregroundStyle(Color("MarcoLabelSecondary"))
                    }
                } else {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
            }
        }
    }

    /// Horário do lembrete (T13) + toggle "Definir hora do evento" (T26) — ambos preservados.
    private var remindersCard: some View {
        FormSectionCard(label: "Lembretes") {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("Hora do lembrete", selection: $notificationTime, displayedComponents: .hourAndMinute)
                Toggle("Definir hora do evento", isOn: $hasEventTime)
                if hasEventTime {
                    DatePicker("Hora do evento", selection: $eventTime, displayedComponents: .hourAndMinute)
                }
            }
        }
    }

    private var categoryCard: some View {
        FormSectionCard(label: "Categoria") {
            Picker("Tipo", selection: $type) {
                ForEach(DateType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    /// Chips quebram em múltiplas linhas (T37, mock Figma `24:61`) em vez de rolar horizontalmente
    /// — `FlowLayout` abaixo. "Nenhum" (seção 3.9 da spec, sem correspondente no mock) entra no
    /// mesmo fluxo, totalizando 6 chips.
    private var relationshipCard: some View {
        FormSectionCard(label: "Relacionamento") {
            FlowLayout(spacing: 8) {
                RelationshipChip(title: "Nenhum", isSelected: relationship == nil) {
                    relationship = nil
                }
                ForEach(Relationship.allCases, id: \.self) { option in
                    RelationshipChip(title: option.displayName, isSelected: relationship == option) {
                        relationship = option
                    }
                }
            }
        }
    }

    private var notesCard: some View {
        FormSectionCard(label: "Anotações") {
            TextField("Notas (opcional)", text: $notes, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color("MarcoCream"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Botão "Salvar" do rodapé (T35) — mesma ação do `checkmark` do toolbar.
    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Salvar")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("MarcosGreen"))
        .disabled(!isNameValid)
        .padding(.top, 4)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDate = type == .birthday ? Self.birthdayDate(month: birthdayMonth, day: birthdayDay) : date
        let finalBirthYear = type == .birthday ? Self.parseBirthYear(birthYearText) : nil
        let (hour, minute) = Self.timeComponents(from: notificationTime)
        let (eventHour, eventMinute): (Int?, Int?) = hasEventTime
            ? { let (h, m) = Self.timeComponents(from: eventTime); return (h, m) }()
            : (nil, nil)

        let savedDate: ImportantDate
        if let importantDate {
            importantDate.name = trimmedName
            importantDate.date = finalDate
            importantDate.type = type
            importantDate.relationship = relationship
            importantDate.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            importantDate.birthYear = finalBirthYear
            importantDate.notificationHour = hour
            importantDate.notificationMinute = minute
            importantDate.eventHour = eventHour
            importantDate.eventMinute = eventMinute
            importantDate.photoData = photoData
            savedDate = importantDate
        } else {
            let newDate = ImportantDate(
                name: trimmedName,
                date: finalDate,
                type: type,
                relationship: relationship,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                birthYear: finalBirthYear,
                notificationHour: hour,
                notificationMinute: minute,
                eventHour: eventHour,
                eventMinute: eventMinute,
                photoData: photoData
            )
            ImportantDate.insert(newDate, into: modelContext)
            savedDate = newDate
        }
        Task { await NotificationService.schedule(savedDate) }
        dismiss()
    }
}

/// Card de seção com label estática acima do card (T37, conferido contra o mock Figma `24:61`):
/// título pequeno e discreto em *sentence case*, fora do container com fundo/clip — usado por
/// todas as seções do form ("Identificação", "Quando", "Lembretes", "Categoria",
/// "Relacionamento", "Anotações"). Não é floating label animado estilo Material.
private struct FormSectionCard<Content: View>: View {
    let label: LocalizedStringResource
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(Color("MarcoLabelSecondary"))
            content
                .padding(16)
                .background(Color("MarcoCardFill"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

/// Chip selecionável de `Relationship` (T35), incl. a opção "Nenhum" — substitui o `Picker`
/// antigo por uma fileira de cápsulas roláveis horizontalmente.
private struct RelationshipChip: View {
    let title: LocalizedStringResource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Color("MarcosGreen") : Color("MarcoBeige")))
                .foregroundStyle(isSelected ? Color.white : Color("MarcoLabel"))
        }
        .buttonStyle(.plain)
    }
}

/// Layout mínimo (protocolo `Layout`, iOS 16+) que distribui subviews em fileiras, quebrando
/// para a linha seguinte quando a largura proposta estoura (T37, mock Figma `24:61`) — usado
/// pelos chips de "Relacionamento" para não rolar horizontalmente. Não é um sistema de layout
/// genérico/configurável, só o suficiente para quebrar linha por largura.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let computedRows = rows(for: subviews, maxWidth: maxWidth)
        let height = computedRows.reduce(CGFloat(0)) { $0 + $1.maxHeight } + CGFloat(max(0, computedRows.count - 1)) * spacing
        let width = computedRows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let computedRows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in computedRows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct Row {
        let items: [RowItem]
        let width: CGFloat
        let maxHeight: CGFloat
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var computedRows: [Row] = []
        var items: [RowItem] = []
        var width: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let widthIfAppended = items.isEmpty ? size.width : width + spacing + size.width
            if widthIfAppended > maxWidth, !items.isEmpty {
                computedRows.append(Row(items: items, width: width, maxHeight: maxHeight))
                items = []
                width = 0
                maxHeight = 0
            }
            width = items.isEmpty ? size.width : width + spacing + size.width
            maxHeight = max(maxHeight, size.height)
            items.append(RowItem(subview: subview, size: size))
        }
        if !items.isEmpty {
            computedRows.append(Row(items: items, width: width, maxHeight: maxHeight))
        }
        return computedRows
    }
}

#Preview("Criar") {
    NavigationStack {
        ImportantDateFormView(importantDate: nil)
    }
    .modelContainer(for: ImportantDate.self, inMemory: true)
}

#Preview("Editar") {
    NavigationStack {
        ImportantDateFormView(importantDate: ImportantDate(
            name: "Mari",
            date: .now,
            type: .birthday,
            relationship: .partner,
            notes: "Gosta de plantas"
        ))
    }
    .modelContainer(for: ImportantDate.self, inMemory: true)
}
