import SwiftUI

struct TicketsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAddTicket = false
    @State private var editingTicket: LotteryTicket?
    @State private var deletingTicket: LotteryTicket?

    var body: some View {
        AppScreen {
            Group {
                if store.tickets.isEmpty {
                    EmptyStateView(
                        systemImage: "ticket",
                        title: "tickets.empty.title",
                        message: "tickets.empty.message",
                        actionTitle: "tickets.add"
                    ) {
                        showAddTicket = true
                    }
                } else {
                    List {
                        ForEach(store.tickets) { ticket in
                            TicketCard(ticket: ticket)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTicket = ticket }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        editingTicket = ticket
                                    } label: {
                                        Label("tickets.result", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deletingTicket = ticket
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingTicket = ticket
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("tab.tickets")
        .toolbar {
            Button {
                showAddTicket = true
            } label: {
                Label("tickets.add", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAddTicket) {
            NavigationStack { TicketFormView() }
        }
        .sheet(item: $editingTicket) { ticket in
            NavigationStack { TicketFormView(ticket: ticket) }
        }
        .confirmationDialog(
            "tickets.delete.title",
            isPresented: Binding(
                get: { deletingTicket != nil },
                set: { if !$0 { deletingTicket = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("common.delete", role: .destructive) {
                if let deletingTicket {
                    store.deleteTicket(id: deletingTicket.id)
                }
                deletingTicket = nil
            }
            Button("common.cancel", role: .cancel) { deletingTicket = nil }
        }
    }
}

private struct TicketCard: View {
    @EnvironmentObject private var store: AppStore
    let ticket: LotteryTicket

    private var presentation: (title: LocalizedStringKey, icon: String, color: Color) {
        if ticket.status == .won {
            return ("ticket.card.winner", "trophy.fill", Color(hex: 0x20C997))
        }
        if ticket.status == .lost {
            return ("ticket.status.lost", "xmark", Color(hex: 0xE65361))
        }
        if ticket.drawDate > Date() {
            return ("ticket.card.active", "checkmark", Color(hex: 0x06499E))
        }
        return ("ticket.card.awaiting", "hourglass", Color(hex: 0xFFB31A))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x06499E))
                    .frame(width: 42, height: 42)
                    .background(AppTheme.goldColor.opacity(0.82), in: Circle())
                    .shadow(color: AppTheme.goldColor.opacity(0.32), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text(ticket.number)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color(hex: 0x171B35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(String(format: String(localized: "ticket.series.year.value"), ticket.series, Calendar.current.component(.year, from: ticket.drawDate)))
                        .font(.subheadline)
                        .foregroundStyle(.black)
                }

                Spacer(minLength: 6)

                Label(presentation.title, systemImage: presentation.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(presentation.color, in: Capsule())
                    .shadow(color: presentation.color.opacity(0.3), radius: 6, y: 3)
            }

            Divider()
                .overlay(Color(hex: 0xD9DEEA))

            HStack(spacing: 8) {
                Image(systemName: "clock")
                Text("ticket.card.draw")
                Text(ticket.drawDate, format: .dateTime.month(.abbreviated).day().year())
                Spacer()
                if ticket.status == .won {
                    Text("+\(store.format(ticket.winnings, currency: ticket.currency))")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: 0x148B68))
                } else {
                    Text(store.format(ticket.cost, currency: ticket.currency))
                        .fontWeight(.semibold)
                    }
            }
            .font(.subheadline)
            .foregroundStyle(.black)

            if !ticket.note.isEmpty {
                Text(ticket.note)
                    .font(.footnote)
                    .foregroundStyle(.black)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: Color(hex: 0x2476FF).opacity(0.48), radius: 16, y: 8)
        .padding(.vertical, 4)
    }
}

private struct TicketFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    private let existingTicket: LotteryTicket?
    @State private var number: String
    @State private var series: String
    @State private var drawDate: Date
    @State private var cost: Decimal
    @State private var currency: CurrencyCode
    @State private var status: TicketStatus
    @State private var winnings: Decimal
    @State private var note: String
    @State private var isChecked: Bool
    @State private var validationMessage: String?

    init(ticket: LotteryTicket? = nil) {
        existingTicket = ticket
        _number = State(initialValue: ticket?.number ?? "")
        _series = State(initialValue: ticket?.series ?? "")
        _drawDate = State(initialValue: ticket?.drawDate ?? Date())
        _cost = State(initialValue: ticket?.cost ?? 0)
        _currency = State(initialValue: ticket?.currency ?? .eur)
        _status = State(initialValue: ticket?.status ?? .pending)
        _winnings = State(initialValue: ticket?.winnings ?? 0)
        _note = State(initialValue: ticket?.note ?? "")
        _isChecked = State(initialValue: ticket?.isChecked ?? false)
    }

    var body: some View {
        Form {
            Section("ticket.details") {
                LabeledContent("ticket.number") {
                    TextField("ticket.number.example", text: $number)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                }
                LabeledContent("ticket.series") {
                    TextField("ticket.series.example", text: $series)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                }
                DatePicker("ticket.draw.date", selection: $drawDate, displayedComponents: .date)
            }

            Section("ticket.finance") {
                LabeledContent("ticket.cost") {
                    TextField("ticket.amount.example", value: $cost, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
                Picker("ticket.currency", selection: $currency) {
                    ForEach(CurrencyCode.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                Picker("ticket.status", selection: $status) {
                    ForEach(TicketStatus.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                if status == .won {
                    LabeledContent("ticket.winnings") {
                        TextField("ticket.amount.example", value: $winnings, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                Toggle("ticket.checked", isOn: $isChecked)
            }

            Section("ticket.note") {
                TextEditor(text: $note)
                    .frame(minHeight: 100)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .glassFormBackground()
        .navigationTitle(existingTicket == nil ? "tickets.add" : "tickets.edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save", action: save)
            }
        }
        .keyboardDoneToolbar()
    }

    private func save() {
        let cleanNumber = number.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSeries = series.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNumber.isEmpty, !cleanSeries.isEmpty else {
            validationMessage = String(localized: "ticket.validation.required")
            return
        }
        guard cost >= 0, winnings >= 0 else {
            validationMessage = String(localized: "ticket.validation.amount")
            return
        }

        let ticket = LotteryTicket(
            id: existingTicket?.id ?? UUID(),
            number: cleanNumber,
            series: cleanSeries,
            drawDate: drawDate,
            cost: cost,
            currency: currency,
            status: status,
            winnings: status == .won ? winnings : 0,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            isChecked: isChecked,
            createdAt: existingTicket?.createdAt ?? Date()
        )
        if existingTicket == nil {
            store.addTicket(ticket)
        } else {
            store.updateTicket(ticket)
        }
        dismiss()
    }
}

struct CalendarView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDate = Date()
    @State private var selectedEvent: DrawEvent?

    private var eventForSelectedDate: DrawEvent? {
        store.events.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(spacing: 16) {
                    DatePicker(
                        "calendar.select",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(AppTheme.goldColor)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                    .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }

                    if let event = eventForSelectedDate {
                        EventSummaryCard(event: event) {
                            selectedEvent = event
                        }
                    } else {
                        EmptyStateView(
                            systemImage: "calendar.badge.exclamationmark",
                            title: "calendar.no.draw.title",
                            message: "calendar.no.draw.message"
                        )
                        .frame(minHeight: 220)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("tab.calendar")
        .sheet(item: $selectedEvent) { event in
            NavigationStack { EventEditorView(event: event) }
        }
        .onAppear {
            if let next = store.events.first(where: { $0.date >= Date() }) {
                selectedDate = next.date
            }
        }
    }
}

private struct EventSummaryCard: View {
    @EnvironmentObject private var store: AppStore
    let event: DrawEvent
    let edit: () -> Void

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("calendar.draw.title", systemImage: "sparkles")
                    .font(.headline)
                Text(store.formatDate(event.date))
                    .font(.title2.bold())
                Label(
                    event.broadcastTime.formatted(date: .omitted, time: .shortened),
                    systemImage: "tv"
                )
                if event.jackpot > 0 {
                    Label(
                        store.format(event.jackpot, currency: event.currency),
                        systemImage: "eurosign.circle"
                    )
                }
                if event.reminderScheduled {
                    Label("calendar.reminder.scheduled", systemImage: "bell.badge.fill")
                        .foregroundStyle(.green)
                }
                Button("common.edit", action: edit)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var event: DrawEvent
    @State private var message: String?

    init(event: DrawEvent) {
        _event = State(initialValue: event)
    }

    var body: some View {
        Form {
            Section("calendar.details") {
                DatePicker(
                    "calendar.broadcast",
                    selection: $event.broadcastTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                LabeledContent("calendar.jackpot") {
                    TextField("ticket.amount.example", value: $event.jackpot, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
                Picker("ticket.currency", selection: $event.currency) {
                    ForEach(CurrencyCode.allCases) { Text($0.rawValue).tag($0) }
                }
                LabeledContent("calendar.url") {
                    TextField("calendar.url.example", text: $event.officialURL)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            Section {
                Button {
                    Task {
                        store.updateEvent(event)
                        message = await store.scheduleReminder(for: event)
                        if message == nil { dismiss() }
                    }
                } label: {
                    Label("calendar.remind", systemImage: "bell.fill")
                }
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(.red)
                }
            }
        }
        .glassFormBackground()
        .navigationTitle("calendar.edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save") {
                    store.updateEvent(event)
                    dismiss()
                }
            }
        }
        .keyboardDoneToolbar()
    }
}
