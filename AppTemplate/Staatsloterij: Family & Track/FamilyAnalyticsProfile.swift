import Charts
import PhotosUI
import SwiftUI

struct FamilyDrawView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showParticipantForm = false
    @State private var prizeText = ""
    @State private var selectedPrizeID: UUID?
    @State private var winner: FamilyDrawResult?
    @State private var isDrawing = false
    @State private var validationMessage: String?

    private var selectedPrize: FamilyPrize? {
        store.prizes.first { $0.id == selectedPrizeID }
    }

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionTitle("family.participants", systemImage: "person.3.fill")

                    if store.participants.isEmpty {
                        EmptyStateView(
                            systemImage: "person.crop.circle.badge.plus",
                            title: "family.participants.empty.title",
                            message: "family.participants.empty.message",
                            actionTitle: "family.participant.add"
                        ) {
                            showParticipantForm = true
                        }
                        .frame(minHeight: 220)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 16) {
                            ForEach(store.participants) { participant in
                                Menu {
                                    Button("common.delete", role: .destructive) {
                                        store.deleteParticipant(id: participant.id)
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        ParticipantAvatar(participant: participant)
                                        Text(participant.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                            Button {
                                showParticipantForm = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .frame(width: 64, height: 64)
                                        .background(Color.secondary.opacity(0.12), in: Circle())
                                    Text("family.participant.add")
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    sectionTitle("family.prizes", systemImage: "gift.fill")

                    HStack {
                        TextField("family.prize.placeholder", text: $prizeText)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            addPrize()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .accessibilityLabel("family.prize.add")
                    }

                    if !store.prizes.isEmpty {
                        Picker("family.prize.select", selection: $selectedPrizeID) {
                            Text("family.prize.none").tag(UUID?.none)
                            ForEach(store.prizes) { prize in
                                Text(prize.title).tag(Optional(prize.id))
                            }
                        }
                        .pickerStyle(.menu)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.prizes) { prize in
                                    Button {
                                        selectedPrizeID = prize.id
                                    } label: {
                                        Text(prize.title)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedPrizeID == prize.id
                                                    ? AppTheme.goldColor.opacity(0.35)
                                                    : Color.secondary.opacity(0.12),
                                                in: Capsule()
                                            )
                                    }
                                    .contextMenu {
                                        Button("common.delete", role: .destructive) {
                                            store.deletePrize(id: prize.id)
                                            if selectedPrizeID == prize.id { selectedPrizeID = nil }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DrawMachineView(isDrawing: isDrawing)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        startDraw()
                    } label: {
                        Label("family.spin", systemImage: "circle.dotted.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDrawing)

                    if !store.familyResults.isEmpty {
                        sectionTitle("family.archive", systemImage: "clock.arrow.circlepath")
                        ForEach(store.familyResults.prefix(10)) { result in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(result.participantName).fontWeight(.semibold)
                                    Text(result.prizeTitle).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(result.date, format: .dateTime.day().month())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                            .contextMenu {
                                Button("common.delete", role: .destructive) {
                                    store.deleteFamilyResult(id: result.id)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("tab.family")
        .sheet(isPresented: $showParticipantForm) {
            NavigationStack { ParticipantFormView() }
        }
        .fullScreenCover(item: $winner) { result in
            WinnerView(result: result)
        }
        .keyboardDoneToolbar()
        .onAppear {
            if selectedPrizeID == nil {
                selectedPrizeID = store.prizes.first?.id
            }
        }
    }

    private func sectionTitle(_ key: LocalizedStringKey, systemImage: String) -> some View {
        Label(key, systemImage: systemImage)
            .serifTitle()
    }

    private func addPrize() {
        let clean = prizeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.addPrize(title: clean)
        selectedPrizeID = store.prizes.last?.id
        prizeText = ""
    }

    private func startDraw() {
        guard !store.participants.isEmpty else {
            validationMessage = String(localized: "family.validation.participants")
            return
        }
        guard let selectedPrize else {
            validationMessage = String(localized: "family.validation.prize")
            return
        }
        validationMessage = nil
        isDrawing = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            winner = store.performFamilyDraw(prize: selectedPrize)
            isDrawing = false
        }
    }
}

private struct DrawMachineView: View {
    let isDrawing: Bool
    @State private var boostStartedAt = Date.distantPast

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let boostElapsed = max(0, context.date.timeIntervalSince(boostStartedAt))
            let boostPhase = 5.4 * (1 - exp(-boostElapsed / 0.62))

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.82), AppTheme.blueColor.opacity(0.28)],
                            center: .center,
                            startRadius: 18,
                            endRadius: 130
                        )
                    )
                    .overlay(Circle().stroke(AppTheme.goldColor, lineWidth: 6))

                ForEach(0..<10, id: \.self) { index in
                    DrawMachineBall()
                        .offset(ballOffset(index: index, time: time, boostPhase: boostPhase))
                }
            }
        }
        .frame(width: 240, height: 240)
        .frame(maxWidth: .infinity)
        .onChange(of: isDrawing) { _, drawing in
            if drawing {
                boostStartedAt = Date()
            }
        }
        .accessibilityLabel("family.machine")
    }

    private func ballOffset(index: Int, time: TimeInterval, boostPhase: Double) -> CGSize {
        let seed = Double(index) * 1.73
        let basePhase = time * (0.62 + Double(index % 4) * 0.07) + boostPhase
        let x = sin(basePhase * (1.07 + Double(index % 3) * 0.11) + seed) * 66
            + cos(basePhase * 1.91 + seed * 0.7) * 14
        let y = cos(basePhase * (0.93 + Double(index % 5) * 0.08) + seed * 1.2) * 64
            + sin(basePhase * 1.67 + seed) * 14
        return CGSize(width: x, height: y)
    }
}

private struct DrawMachineBall: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.95), AppTheme.goldColor, Color(hex: 0xC88400)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 34
                    )
                )

            if UIImage(named: "family_draw_machine") != nil {
                Image("family_draw_machine")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.overlay)
            }

            Circle()
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .shadow(color: AppTheme.blueColor.opacity(0.25), radius: 4, y: 2)
    }
}

private struct ParticipantFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var emoji = "🙂"
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ParticipantAvatar(
                        participant: FamilyParticipant(name: name, emoji: emoji, photoData: photoData),
                        size: 100
                    )
                    Spacer()
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("family.photo.choose", systemImage: "photo.on.rectangle")
                }
                .onChange(of: selectedPhoto) {
                    Task {
                        if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                            photoData = data
                        }
                    }
                }
            }

            Section("family.participant.details") {
                TextField("family.participant.name", text: $name)
                LabeledContent("family.participant.emoji") {
                    TextField("family.participant.emoji.example", text: $emoji)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let validationMessage {
                Section { Text(validationMessage).foregroundStyle(.red) }
            }
        }
        .glassFormBackground()
        .navigationTitle("family.participant.add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save") {
                    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else {
                        validationMessage = String(localized: "family.validation.name")
                        return
                    }
                    store.addParticipant(name: clean, emoji: emoji, photoData: photoData)
                    dismiss()
                }
            }
        }
        .keyboardDoneToolbar()
    }
}

private struct WinnerView: View {
    @Environment(\.dismiss) private var dismiss
    let result: FamilyDrawResult

    var body: some View {
        ZStack {
            AppBackground()
            ConfettiView()
            VStack(spacing: 24) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(AppTheme.goldColor)
                Text("family.winner.title")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(result.participantName)
                    .font(.largeTitle.bold())
                Text(result.prizeTitle)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                Button("common.done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.goldColor)
                    .foregroundStyle(.black)
            }
            .foregroundStyle(.white)
            .padding(32)
        }
    }
}

private struct ConfettiView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if UIImage(named: "winner_confetti_overlay") != nil {
                    Image("winner_confetti_overlay")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    ForEach(0..<30, id: \.self) { index in
                        Capsule()
                            .fill(index.isMultiple(of: 3) ? AppTheme.goldColor : .white)
                            .frame(width: 8, height: 18)
                            .rotationEffect(.degrees(Double(index * 37)))
                            .position(
                                x: CGFloat((index * 47) % 100) / 100 * proxy.size.width,
                                y: CGFloat((index * 83) % 100) / 100 * proxy.size.height
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(0.9)
    }
}

struct AnalyticsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = 0

    private var checkedTickets: [LotteryTicket] { store.tickets.filter(\.isChecked) }
    private var wonTickets: [LotteryTicket] { checkedTickets.filter { $0.status == .won } }
    private var currencyTickets: [LotteryTicket] {
        store.tickets.filter { $0.currency == store.settings.preferredCurrency }
    }

    var body: some View {
        AppScreen {
            VStack {
                Picker("analytics.mode", selection: $selection) {
                    Text("analytics.real").tag(0)
                    Text("analytics.family").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    if selection == 0 {
                        realAnalytics
                    } else {
                        familyAnalytics
                    }
                }
            }
        }
        .navigationTitle("tab.analytics")
    }

    @ViewBuilder
    private var realAnalytics: some View {
        if store.tickets.isEmpty {
            EmptyStateView(
                systemImage: "chart.xyaxis.line",
                title: "analytics.empty.title",
                message: "analytics.empty.message"
            )
            .frame(minHeight: 360)
        } else {
            let winnings = currencyTickets.reduce(Decimal.zero) { $0 + $1.winnings }

            VStack(spacing: 20) {
                AnalyticsPanel {
                    HStack(spacing: 12) {
                        SummaryMetricCard(
                            title: "analytics.total.winnings",
                            value: store.format(winnings, currency: store.settings.preferredCurrency),
                            systemImage: "medal",
                            style: .gold
                        )
                        SummaryMetricCard(
                            title: "analytics.total.tickets",
                            value: currencyTickets.count.formatted(),
                            systemImage: "ticket",
                            style: .light
                        )
                    }
                }

                AnalyticsPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("analytics.winnings.over.time")
                            .font(.system(.title3, design: .serif, weight: .bold))

                        if monthlyWinnings.isEmpty {
                            AnalyticsEmptyState(message: "analytics.no.winnings")
                        } else {
                            VStack(spacing: 7) {
                                Chart(monthlyWinnings) { point in
                                    LineMark(
                                        x: .value("Month", point.month),
                                        y: .value("Winnings", point.winnings)
                                    )
                                    .foregroundStyle(Color(hex: 0x0D438E))
                                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Month", point.month),
                                        y: .value("Winnings", point.winnings)
                                    )
                                    .foregroundStyle(Color(hex: 0xF7BB36))
                                    .symbolSize(65)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .month, count: monthAxisStride)) {
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3]))
                                            .foregroundStyle(Color(hex: 0xDCE4F1))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading) {
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3]))
                                            .foregroundStyle(Color(hex: 0xDCE4F1))
                                        AxisValueLabel()
                                            .foregroundStyle(Color(hex: 0x6F788C))
                                    }
                                }
                                .frame(height: 205)

                                HStack(spacing: 0) {
                                    ForEach(monthAxisMonths, id: \.self) { month in
                                        Text(month, format: .dateTime.month(.abbreviated))
                                            .font(.caption2)
                                            .foregroundStyle(Color(hex: 0x30384A))
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.leading, 34)
                            }
                            .frame(height: 235)
                        }
                    }
                }

                AnalyticsPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("analytics.prize.distribution")
                            .font(.system(.title3, design: .serif, weight: .bold))

                        if prizeDistribution.allSatisfy({ $0.count == 0 }) {
                            AnalyticsEmptyState(message: "analytics.no.winnings")
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 22) {
                                    PrizeDonutChart(items: prizeDistribution)
                                    PrizeLegend(items: prizeDistribution)
                                }
                                VStack(spacing: 20) {
                                    PrizeDonutChart(items: prizeDistribution)
                                    PrizeLegend(items: prizeDistribution)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var familyAnalytics: some View {
        if store.familyResults.isEmpty {
            EmptyStateView(
                systemImage: "person.3.sequence.fill",
                title: "analytics.family.empty.title",
                message: "analytics.family.empty.message"
            )
            .frame(minHeight: 360)
        } else {
            let lucky = mostFrequent(store.familyResults.map(\.participantName))
            let prize = mostFrequent(store.familyResults.map(\.prizeTitle))
            VStack(spacing: 16) {
                MetricCard(
                    title: "analytics.luckiest",
                    value: lucky.map { "\($0.value) (\($0.count))" } ?? "—"
                )
                MetricCard(
                    title: "analytics.frequent.prize",
                    value: prize.map { "\($0.value) (\($0.count))" } ?? "—"
                )
                PremiumCard {
                    VStack(alignment: .leading) {
                        Text("analytics.family.chart").serifTitle()
                        Chart(familyCounts, id: \.name) { item in
                            BarMark(
                                x: .value("Wins", item.count),
                                y: .value("Name", item.name),
                                height: .fixed(16)
                            )
                            .foregroundStyle(AppTheme.goldColor.gradient)
                        }
                        .frame(height: max(180, CGFloat(familyCounts.count * 50)))
                    }
                }
            }
            .padding()
        }
    }

    private var monthlyWinnings: [WinningsPoint] {
        let calendar = Calendar.current
        let winningTickets = currencyTickets.filter { $0.status == .won && $0.winnings > 0 }
        guard
            let firstMonth = currencyTickets
                .map(\.drawDate)
                .min()
                .flatMap({ calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) }),
            let lastTicketMonth = currencyTickets
                .map(\.drawDate)
                .max()
                .flatMap({ calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) })
        else {
            return []
        }

        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let lastMonth = max(lastTicketMonth, currentMonth)
        let groups = Dictionary(grouping: winningTickets) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.drawDate)) ?? $0.drawDate
        }
        var running = Decimal.zero
        var month = firstMonth
        var points: [WinningsPoint] = []

        while month <= lastMonth {
            for ticket in groups[month] ?? [] {
                running += ticket.winnings
            }
            points.append(WinningsPoint(
                month: month,
                winnings: NSDecimalNumber(decimal: running).doubleValue
            ))
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = nextMonth
        }
        return points
    }

    private var monthAxisStride: Int {
        max(1, Int(ceil(Double(monthlyWinnings.count) / 6)))
    }

    private var monthAxisMonths: [Date] {
        let stride = monthAxisStride
        var months = monthlyWinnings.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point.month : nil
        }
        if let last = monthlyWinnings.last?.month, months.last != last {
            months.append(last)
        }
        return months
    }

    private var prizeDistribution: [PrizeDistributionItem] {
        let amounts = currencyTickets
            .filter { $0.status == .won && $0.winnings > 0 }
            .map(\.winnings)
        return [
            PrizeDistributionItem(
                title: "analytics.prize.small",
                count: amounts.filter { $0 < 50 }.count,
                color: Color(hex: 0x0D438E)
            ),
            PrizeDistributionItem(
                title: "analytics.prize.medium",
                count: amounts.filter { $0 >= 50 && $0 < 250 }.count,
                color: Color(hex: 0x1760B6)
            ),
            PrizeDistributionItem(
                title: "analytics.prize.large",
                count: amounts.filter { $0 >= 250 && $0 < 1_000 }.count,
                color: Color(hex: 0xF6BB35)
            ),
            PrizeDistributionItem(
                title: "analytics.prize.jackpot",
                count: amounts.filter { $0 >= 1_000 }.count,
                color: Color(hex: 0xFFD465)
            )
        ]
    }

    private var familyCounts: [(name: String, count: Int)] {
        Dictionary(grouping: store.familyResults, by: \.participantName)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private func mostFrequent(_ values: [String]) -> (value: String, count: Int)? {
        Dictionary(grouping: values, by: { $0 })
            .map { ($0.key, $0.value.count) }
            .max { $0.1 < $1.1 }
    }
}

private struct WinningsPoint: Identifiable {
    var id: Date { month }
    let month: Date
    let winnings: Double
}

private struct PrizeDistributionItem: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let count: Int
    let color: Color
}

private struct AnalyticsPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color(hex: 0x171B35))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: Color(hex: 0x2476FF).opacity(0.42), radius: 17, y: 9)
    }
}

private enum SummaryMetricStyle {
    case gold
    case light
}

private struct SummaryMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let style: SummaryMetricStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hex: 0x0D438E))
                .lineLimit(2)
            Text(value)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(Color(hex: 0x0D438E))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(
            color: style == .gold
                ? AppTheme.goldColor.opacity(0.34)
                : Color(hex: 0x2476FF).opacity(0.22),
            radius: 12,
            y: 6
        )
    }

    private var background: some ShapeStyle {
        switch style {
        case .gold:
            LinearGradient(
                colors: [Color(hex: 0xFFD665), Color(hex: 0xF5BB32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            LinearGradient(
                colors: [Color.white, Color(hex: 0xEEF4FF)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct PrizeDonutChart: View {
    let items: [PrizeDistributionItem]

    var body: some View {
        Chart(items) { item in
            SectorMark(
                angle: .value("Tickets", item.count),
                innerRadius: .ratio(0.58),
                angularInset: 2
            )
            .cornerRadius(3)
            .foregroundStyle(item.color)
        }
        .chartLegend(.hidden)
        .frame(width: 150, height: 150)
    }
}

private struct PrizeLegend: View {
    let items: [PrizeDistributionItem]

    private var total: Int {
        items.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0x747C8F))
                        Text(percentage(for: item))
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(hex: 0x171B35))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentage(for item: PrizeDistributionItem) -> String {
        guard total > 0 else { return "0%" }
        return (Double(item.count) / Double(total))
            .formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct AnalyticsEmptyState: View {
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundStyle(Color(hex: 0x0D438E))
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: 0x747C8F))
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .serif, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var email = ""
    @State private var settings = AppSettings()
    @State private var showPasswordChange = false
    @State private var saved = false

    var body: some View {
        Form {
            Section("profile.personal") {
                LabeledContent("profile.name") {
                    TextField("profile.name.example", text: $name)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.name)
                }
                LabeledContent("auth.email") {
                    TextField("profile.email.example", text: $email)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Button {
                    showPasswordChange = true
                } label: {
                    Label("profile.change.password", systemImage: "key.fill")
                }
            }

            Section("profile.notifications") {
                Toggle("profile.draw.notifications", isOn: $settings.drawNotifications)
                Toggle("profile.family.notifications", isOn: $settings.familyNotifications)
                Toggle("profile.weekly.summary", isOn: $settings.weeklySummary)
            }

            Section("profile.format") {
                Picker("profile.language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .onChange(of: settings.language) { _, language in
                    store.updateLanguage(language)
                }
                Picker("ticket.currency", selection: $settings.preferredCurrency) {
                    ForEach(CurrencyCode.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("profile.date.format", selection: $settings.dateFormat) {
                    ForEach(DateFormatPreference.allCases) { Text($0.title).tag($0) }
                }
            }

            Section {
                AdultNoticeView()
                Link("home.support.link", destination: URL(string: "https://www.loketkansspel.nl")!)
            }

            Section {
                Button("profile.logout", role: .destructive) {
                    store.signOut()
                }
            }
        }
        .glassFormBackground()
        .navigationTitle("profile.title")
        .toolbar {
            Button("common.save") {
                store.updateProfile(name: name, email: email)
                store.updateSettings(settings)
                saved = true
            }
        }
        .onAppear {
            name = store.profile.name
            email = store.profile.email
            settings = store.settings
        }
        .alert("profile.saved", isPresented: $saved) {
            Button("common.ok", role: .cancel) {}
        }
        .sheet(isPresented: $showPasswordChange) {
            NavigationStack {
                ChangePasswordView()
            }
        }
        .keyboardDoneToolbar()
    }
}

private struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section("profile.change.password") {
                passwordField("profile.current.password", text: $currentPassword)
                    .textContentType(.password)
                passwordField("profile.new.password", text: $newPassword)
                    .textContentType(.newPassword)
                passwordField("profile.confirm.password", text: $confirmation)
                    .textContentType(.newPassword)
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
        .glassFormBackground()
        .navigationTitle("profile.change.password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save") {
                    message = store.changePassword(
                        current: currentPassword,
                        new: newPassword,
                        confirmation: confirmation
                    )
                    if message == nil {
                        dismiss()
                    }
                }
            }
        }
        .keyboardDoneToolbar()
    }

    private func passwordField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
        }
        .padding(.vertical, 3)
    }
}
