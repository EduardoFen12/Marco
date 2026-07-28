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
    /// Evento anual vs. único (T43) — só aparece no card "Quando" para tipos não-aniversário
    /// (aniversário é sempre anual, ver `whenCard`). Default **desligado** ao criar (decisão do
    /// usuário, diferente do default `true` do modelo, que é só pra migração); em edição vence o
    /// valor persistido.
    @State private var isAnnual: Bool
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
        _isAnnual = State(initialValue: importantDate?.isAnnual ?? false)
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(.secondary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(Color("MarcosGreen"))
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
            .overlay(alignment: .bottomLeading) {
                // (T38, mock 24:61) Só faz sentido na criação — em edição a data já existe.
                if importantDate == nil {
                    Text("NOVO REGISTRO")
                        .font(.caption2.bold())
                        .kerning(0.5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color("MarcoDeepGreen")))
                        .foregroundStyle(.white)
                        .padding(16)
                }
            }
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
            HStack(spacing: 10) {
                Image(systemName: "person")
                    .foregroundStyle(Color("MarcoLabelSecondary"))
                TextField("Nome", text: $name)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color("MarcoCream"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Mantém a lógica atual (T14): seletor completo de data para não-aniversário/não-anual,
    /// dia/mês (+ ano opcional/idade calculada pra aniversário) para os demais. Ícone + pill à
    /// direita (T38, mock `24:61`) via `PillDatePicker` (ramo com ano) e via o par de `Picker`
    /// (`.menu`, ramo dia/mês — T14 não usa `DatePicker` ali) estilizado com o mesmo fundo/cápsula.
    ///
    /// T43: `type == .birthday` é sempre anual (switch nem aparece). Os demais tipos ganham o
    /// `Toggle` "Evento anual" — ligado reaproveita o mesmo par de `Picker` dia/mês do aniversário
    /// (sem "Ano de nascimento"); desligado usa o `PillDatePicker` de data completa (já existente).
    private var whenCard: some View {
        FormSectionCard(label: "Quando") {
            VStack(alignment: .leading, spacing: 12) {
                if type == .birthday {
                    monthDayPickerRow

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
                    Toggle("Evento anual", isOn: $isAnnual)
                        .onChange(of: isAnnual) { _, newValue in
                            // Mantém `date` e o par dia/mês em sincronia ao alternar. Ao desligar,
                            // usa a próxima ocorrência futura do dia/mês (nunca o ano fixo 2000
                            // de `birthdayDate`, que deixaria o evento único já "passado").
                            if newValue {
                                let components = Calendar.current.dateComponents([.month, .day], from: date)
                                birthdayMonth = components.month ?? birthdayMonth
                                birthdayDay = components.day ?? birthdayDay
                            } else {
                                date = ImportantDate.nextOccurrence(ofMonth: birthdayMonth, day: birthdayDay, from: .now, calendar: .current)
                            }
                        }

                    if isAnnual {
                        monthDayPickerRow
                    } else {
                        HStack {
                            FieldIconLabel(systemImage: "calendar", title: "Data")
                            Spacer()
                            PillDatePicker(title: "Data", selection: $date, displayedComponents: .date)
                        }
                    }
                }
            }
        }
    }

    /// Par de `Picker` (mês/dia, `.menu`) contra o ano bissexto fixo 2000 — reaproveitado pelo
    /// ramo aniversário e pelo ramo não-aniversário com "Evento anual" ligado (T43).
    private var monthDayPickerRow: some View {
        HStack(spacing: 12) {
            FieldIconLabel(systemImage: "calendar", title: "Data")
            Spacer()
            HStack(spacing: 2) {
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
            .marcoFieldPill()
            .onChange(of: birthdayMonth) {
                let validDays = Self.daysInBirthdayMonth(birthdayMonth)
                if !validDays.contains(birthdayDay) {
                    birthdayDay = validDays.last ?? 1
                }
            }
        }
    }

    /// Horário do lembrete (T13) + toggle "Definir hora do evento" (T26) — ambos preservados.
    /// Ícone + pill à direita (T38) igual ao `DatePicker` de "Quando".
    private var remindersCard: some View {
        FormSectionCard(label: "Lembretes") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    FieldIconLabel(systemImage: "bell", title: "Hora do lembrete")
                    Spacer()
                    PillDatePicker(title: "Hora do lembrete", selection: $notificationTime, displayedComponents: .hourAndMinute)
                }

                Toggle("Definir hora do evento", isOn: $hasEventTime)
                if hasEventTime {
                    HStack {
                        FieldIconLabel(systemImage: "bell", title: "Hora do evento")
                        Spacer()
                        PillDatePicker(title: "Hora do evento", selection: $eventTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
        }
    }

    /// Seletor em menu, não segmentado: com o 4º tipo (`.appointment`) os rótulos do
    /// `.segmented` truncavam ("Commemo…", "Compromi…"). Mesma pill `MarcoMint` das linhas
    /// "Data"/"Hora" (T38), com o símbolo do tipo selecionado como ícone à esquerda.
    private var categoryCard: some View {
        FormSectionCard(label: "Categoria") {
            HStack {
                FieldIconLabel(systemImage: type.symbolName, title: "Tipo")
                Spacer()
                Picker("Tipo", selection: $type) {
                    ForEach(DateType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .marcoFieldPill()
            }
        }
    }

    /// Mesmo seletor em menu de "Categoria" — substitui os chips em `FlowLayout` da T37 (mock
    /// `24:61`), que ocupavam duas linhas do form para uma escolha só. "Nenhum" (seção 3.9 da
    /// spec, sem correspondente no mock) é o caso `nil` do menu.
    private var relationshipCard: some View {
        FormSectionCard(label: "Relacionamento") {
            HStack {
                FieldIconLabel(systemImage: "person.2", title: "Relação")
                Spacer()
                Picker("Relacionamento", selection: $relationship) {
                    Text("Nenhum").tag(Relationship?.none)
                    ForEach(Relationship.allCases, id: \.self) { option in
                        Text(option.displayName).tag(Relationship?.some(option))
                    }
                }
                .marcoFieldPill()
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

    /// Botão "Salvar" do rodapé (T35) — mesma ação do `checkmark` do toolbar. Ícone à esquerda do
    /// texto (T38, mock `24:61`).
    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label("Salvar", systemImage: "square.and.arrow.down")
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
        // T43: aniversário é sempre anual; os demais tipos usam o valor do `Toggle`. Anual (dos
        // dois casos) grava `date` contra o ano fixo 2000 (dia/mês, convenção do model); não-anual
        // grava a data completa escolhida no `PillDatePicker`, ano incluso.
        let finalIsAnnual = type == .birthday ? true : isAnnual
        let finalDate = finalIsAnnual ? Self.birthdayDate(month: birthdayMonth, day: birthdayDay) : date
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
            importantDate.isAnnual = finalIsAnnual
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
                photoData: photoData,
                isAnnual: finalIsAnnual
            )
            ImportantDate.insert(newDate, into: modelContext)
            savedDate = newDate
        }
        Task { await NotificationService.schedule(savedDate) }
        dismiss()
    }
}

/// Ícone + texto usados como `label` das linhas "Data"/"Hora do lembrete"/"Hora do evento"
/// (T38, mock `24:61`) — passada como `label` de `DatePicker`, que desenha o valor (o controle
/// nativo) por conta própria à direita; esta view só cuida do ícone + texto à esquerda.
private struct FieldIconLabel: View {
    let systemImage: String
    let title: LocalizedStringResource

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("MarcoLabel"))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color("MarcosGreen"))
        }
    }
}

/// `DatePicker` compacto embrulhado numa pill `MarcoMint` (T38, mock `24:61`), usado à direita
/// das linhas "Data"/"Hora do lembrete"/"Hora do evento". **Não recria o controle**: continua
/// sendo `DatePicker` + `.datePickerStyle(.compact)`, o mesmo seletor nativo de T13/T14/T26
/// (teclado, acessibilidade, popover de calendário/roda intactos) — só com `.labelsHidden()`
/// por cima, para a pill embrulhar visualmente só o valor (o `FieldIconLabel`, fora desta view,
/// já repete o texto ao lado). O `title` continua passado ao `DatePicker` (não `EmptyView()`):
/// `.labelsHidden()` só esconde o label visualmente, não o remove — é a partir dele que o
/// VoiceOver deriva o nome do campo ("Data", "Hora do lembrete", "Hora do evento").
///
/// **Limite confirmado em runtime (não só na documentação):** o chip que o `.compact` desenha
/// para o valor é um controle UIKit por baixo — o texto sempre sai preto e nem `.tint` nem
/// `.foregroundStyle` mudam essa cor (testado lado a lado no simulador; sem efeito observável).
/// Só o fundo por trás é estilizável, por isso a pill fica `MarcoMint`/texto preto em vez do
/// texto `MarcoDarkGreen` do mock — o mais próximo possível sem recriar o seletor.
/// Pill mint dos `Picker` em menu ("Tipo", "Relação", mês/dia), pareada com a do
/// `PillDatePicker` para os campos do form ficarem idênticos.
///
/// O chip nativo do `DatePicker` `.compact` desenha um `tertiarySystemFill` próprio por cima do
/// que estiver atrás dele (medido em runtime: a mint sai de `81,233,214` para `90,205,193`) e
/// pinta o valor com a cor de label do sistema — nada disso é estilizável. Então é a pill do
/// menu que copia o `DatePicker`, não o contrário: mesmo fill por cima da mint, mesma cor de
/// texto (`.primary`), e sem padding vertical porque os dois controles já têm a mesma altura
/// intrínseca (~34pt) — foi o padding de 6 que deixava a pill do menu mais alta que a de data.
private extension View {
    func marcoFieldPill() -> some View {
        labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .tint(.primary)
            .padding(.horizontal, 12)
            .background {
                Color("MarcoMint")
                    .overlay(Color(uiColor: .tertiarySystemFill))
            }
            .clipShape(Capsule())
    }
}

private struct PillDatePicker: View {
    let title: LocalizedStringResource
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents

    var body: some View {
        DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Color("MarcoDarkGreen"))
            .background(Color("MarcoMint"))
            .clipShape(Capsule())
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
