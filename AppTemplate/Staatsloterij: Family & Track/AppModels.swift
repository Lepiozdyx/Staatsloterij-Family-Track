import Foundation

enum TicketStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case won
    case lost

    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .pending: "ticket.status.pending"
        case .won: "ticket.status.won"
        case .lost: "ticket.status.lost"
        }
    }
}

enum CurrencyCode: String, Codable, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"

    var id: String { rawValue }
    var symbol: String { self == .eur ? "€" : "$" }
}

struct LotteryTicket: Identifiable, Codable, Equatable {
    var id = UUID()
    var number: String
    var series: String
    var drawDate: Date
    var cost: Decimal
    var currency: CurrencyCode
    var status: TicketStatus
    var winnings: Decimal
    var note: String
    var isChecked: Bool
    var createdAt = Date()
}

struct DrawEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var broadcastTime: Date
    var jackpot: Decimal
    var currency: CurrencyCode
    var officialURL: String
    var reminderScheduled = false
}

struct FamilyParticipant: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var emoji: String
    var photoData: Data?
}

struct FamilyPrize: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
}

struct FamilyDrawResult: Identifiable, Codable, Equatable {
    var id = UUID()
    var participantID: UUID
    var participantName: String
    var prizeTitle: String
    var date = Date()
}

struct UserProfile: Codable, Equatable {
    var name = "Reviewer"
    var email = "reviewer@familytrack.app"
}

enum DateFormatPreference: String, Codable, CaseIterable, Identifiable {
    case dayMonth
    case monthDay

    var id: String { rawValue }
    var title: String { self == .dayMonth ? "DD.MM" : "MM.DD" }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case dutch = "nl"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var title: String {
        switch self {
        case .english: "English"
        case .dutch: "Nederlands"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var drawNotifications = true
    var familyNotifications = false
    var weeklySummary = false
    var preferredCurrency = CurrencyCode.eur
    var dateFormat = DateFormatPreference.dayMonth
    var language = AppLanguage.english

    private enum CodingKeys: String, CodingKey {
        case drawNotifications
        case familyNotifications
        case weeklySummary
        case preferredCurrency
        case dateFormat
        case language
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        drawNotifications = try container.decodeIfPresent(Bool.self, forKey: .drawNotifications) ?? true
        familyNotifications = try container.decodeIfPresent(Bool.self, forKey: .familyNotifications) ?? false
        weeklySummary = try container.decodeIfPresent(Bool.self, forKey: .weeklySummary) ?? false
        preferredCurrency = try container.decodeIfPresent(CurrencyCode.self, forKey: .preferredCurrency) ?? .eur
        dateFormat = try container.decodeIfPresent(DateFormatPreference.self, forKey: .dateFormat) ?? .dayMonth
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
    }
}

struct PersistedAppData: Codable {
    var profile = UserProfile()
    var tickets: [LotteryTicket] = []
    var events: [DrawEvent] = []
    var participants: [FamilyParticipant] = []
    var prizes: [FamilyPrize] = []
    var familyResults: [FamilyDrawResult] = []
    var settings = AppSettings()
}

enum AppTheme {
    static let blue = 0x2962FF
    static let darkBlue = 0x0D47A1
    static let gold = 0xFFD700
}
