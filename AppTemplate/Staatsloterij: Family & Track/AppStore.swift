import AVFoundation
import Combine
import Foundation
import Security
import SwiftUI
import UserNotifications

@MainActor
final class AppStore: ObservableObject {
    static let reviewerEmail = "reviewer@familytrack.app"
    static let reviewerPassword = "Review2026!"

    @Published private(set) var data = PersistedAppData()
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let speechSynthesizer = AVSpeechSynthesizer()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("FamilyTrack", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("app-data.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        Task { await load() }
    }

    var profile: UserProfile { data.profile }
    var tickets: [LotteryTicket] { data.tickets.sorted { $0.drawDate > $1.drawDate } }
    var events: [DrawEvent] { data.events.sorted { $0.date < $1.date } }
    var participants: [FamilyParticipant] { data.participants }
    var prizes: [FamilyPrize] { data.prizes }
    var familyResults: [FamilyDrawResult] { data.familyResults.sorted { $0.date > $1.date } }
    var settings: AppSettings { data.settings }

    func load() async {
        defer { isLoading = false }
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileData = try Data(contentsOf: fileURL)
                data = try decoder.decode(PersistedAppData.self, from: fileData)
            } else {
                data.events = Self.generatedEvents()
                data.prizes = [
                    FamilyPrize(title: String(localized: "prize.movie")),
                    FamilyPrize(title: String(localized: "prize.pizza"))
                ]
                try save()
            }
            ensureUpcomingEvents()
            isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
            KeychainPassword.ensureDefaultPassword()
        } catch {
            errorMessage = String(localized: "error.load")
        }
    }

    func signIn(email: String, password: String, isAdult: Bool) -> String? {
        guard isAdult else { return String(localized: "auth.error.age") }
        guard email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == data.profile.email.lowercased(),
              password == KeychainPassword.read() else {
            return String(localized: "auth.error.credentials")
        }
        isAuthenticated = true
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        return nil
    }

    func signOut() {
        isAuthenticated = false
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
    }

    func updateProfile(name: String, email: String) {
        data.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        data.profile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func updateLanguage(_ language: AppLanguage) {
        data.settings.language = language
        persist()
    }

    func changePassword(current: String, new: String, confirmation: String) -> String? {
        guard current == KeychainPassword.read() else {
            return String(localized: "profile.password.current.error")
        }
        guard new.count >= 8 else {
            return String(localized: "profile.password.length.error")
        }
        guard new == confirmation else {
            return String(localized: "profile.password.match.error")
        }
        guard new != current else {
            return String(localized: "profile.password.same.error")
        }
        KeychainPassword.replace(with: new)
        return nil
    }

    func addTicket(_ ticket: LotteryTicket) {
        data.tickets.append(ticket)
        persist()
    }

    func updateTicket(_ ticket: LotteryTicket) {
        guard let index = data.tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        data.tickets[index] = ticket
        persist()
    }

    func deleteTicket(id: UUID) {
        data.tickets.removeAll { $0.id == id }
        persist()
    }

    func updateEvent(_ event: DrawEvent) {
        guard let index = data.events.firstIndex(where: { $0.id == event.id }) else { return }
        data.events[index] = event
        persist()
    }

    func scheduleReminder(for event: DrawEvent) async -> String? {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return String(localized: "calendar.notification.denied") }
            let reminderDate = event.broadcastTime.addingTimeInterval(-3600)
            guard reminderDate > Date() else { return String(localized: "calendar.notification.past") }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "calendar.notification.title")
            content.body = String(localized: "calendar.notification.body")
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let request = UNNotificationRequest(
                identifier: "draw-\(event.id.uuidString)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await center.add(request)
            var updated = event
            updated.reminderScheduled = true
            updateEvent(updated)
            return nil
        } catch {
            return String(localized: "calendar.notification.error")
        }
    }

    func addParticipant(name: String, emoji: String, photoData: Data?) {
        data.participants.append(FamilyParticipant(name: name, emoji: emoji, photoData: photoData))
        persist()
    }

    func deleteParticipant(id: UUID) {
        data.participants.removeAll { $0.id == id }
        persist()
    }

    func addPrize(title: String) {
        data.prizes.append(FamilyPrize(title: title))
        persist()
    }

    func deletePrize(id: UUID) {
        data.prizes.removeAll { $0.id == id }
        persist()
    }

    func performFamilyDraw(prize: FamilyPrize) -> FamilyDrawResult? {
        guard let winner = data.participants.randomElement() else { return nil }
        let result = FamilyDrawResult(
            participantID: winner.id,
            participantName: winner.name,
            prizeTitle: prize.title
        )
        data.familyResults.append(result)
        persist()
        announce(result)
        return result
    }

    func deleteFamilyResult(id: UUID) {
        data.familyResults.removeAll { $0.id == id }
        persist()
    }

    func updateSettings(_ settings: AppSettings) {
        data.settings = settings
        persist()
    }

    func format(_ amount: Decimal, currency: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.locale = Locale.current
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency.symbol)\(amount)"
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = settings.dateFormat == .dayMonth ? "dd.MM.yyyy" : "MM.dd.yyyy"
        return formatter.string(from: date)
    }

    private func ensureUpcomingEvents() {
        let calendar = Calendar.current
        let months = (0..<18).compactMap { calendar.date(byAdding: .month, value: $0, to: Date()) }
        for month in months {
            guard let date = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: month),
                month: calendar.component(.month, from: month),
                day: 10,
                hour: 20
            )) else { continue }
            let exists = data.events.contains { calendar.isDate($0.date, inSameDayAs: date) }
            if !exists {
                data.events.append(Self.makeEvent(on: date))
            }
        }
        persist()
    }

    private static func generatedEvents() -> [DrawEvent] {
        let calendar = Calendar.current
        return (0..<18).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: offset, to: Date()),
                  let date = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: month),
                    month: calendar.component(.month, from: month),
                    day: 10,
                    hour: 20
                  )) else { return nil }
            return makeEvent(on: date)
        }
    }

    private static func makeEvent(on date: Date) -> DrawEvent {
        DrawEvent(
            date: date,
            broadcastTime: date,
            jackpot: 0,
            currency: .eur,
            officialURL: "https://staatsloterij.nederlandseloterij.nl"
        )
    }

    private func announce(_ result: FamilyDrawResult) {
        let utterance = AVSpeechUtterance(
            string: String(
                format: String(localized: "family.announcement"),
                result.participantName,
                result.prizeTitle
            )
        )
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier)
        speechSynthesizer.speak(utterance)
    }

    private func persist() {
        do {
            try save()
        } catch {
            errorMessage = String(localized: "error.save")
        }
    }

    private func save() throws {
        let encoded = try encoder.encode(data)
        try encoded.write(to: fileURL, options: .atomic)
    }
}

private enum KeychainPassword {
    private static let service = "app.familytrack.local-account"
    private static let account = "reviewer"

    static func ensureDefaultPassword() {
        if read() == nil {
            replace(with: AppStore.reviewerPassword)
        }
    }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func replace(with password: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(password.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }
}
