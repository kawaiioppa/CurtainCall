import Foundation

struct Performance: Decodable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let posterURL: String?
    let venue: String?
    let region: String?
    let startDate: String
    let endDate: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, title, venue, region, description
        case posterURL = "poster_url", startDate = "start_date", endDate = "end_date"
    }
}

struct PerformanceSession: Decodable, Identifiable, Hashable {
    let id: UUID
    let performanceID: UUID
    let startsAt: Date
    let endsAt: Date?
    let scheduleSource: String

    enum CodingKeys: String, CodingKey {
        case id
        case performanceID = "performance_id", startsAt = "starts_at"
        case endsAt = "ends_at", scheduleSource = "schedule_source"
    }
}

struct ConcertFilter: Equatable {
    var title = ""
    var region: String?
    var date: Date?

    var titlePattern: String {
        let escaped = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }

    var dateString: String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")!
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
