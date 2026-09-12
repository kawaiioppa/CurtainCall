import Foundation
import Testing
@testable import CurtainCall

@MainActor
struct ConcertTests {
    @Test func decodesMissingOptionalCatalogueFields() throws {
        let data = Data("""
        {"id":"11111111-1111-1111-1111-111111111111","title":"공연",
         "start_date":"2026-09-13","end_date":"2026-09-15"}
        """.utf8)
        let item = try JSONDecoder().decode(Performance.self, from: data)
        #expect(item.title == "공연")
        #expect(item.posterURL == nil)
        #expect(item.venue == nil)
    }

    @Test func searchesPercentUnderscoreAndBackslashLiterally() {
        let filter = ConcertFilter(title: "  100%_\\공연  ")
        #expect(filter.titlePattern == "%100\\%\\_\\\\공연%")
    }

    @Test func dateFilterUsesSeoulCalendar() {
        let instant = Date(timeIntervalSince1970: 1_789_225_200) // 2026-09-13 00:00 KST
        #expect(ConcertFilter(date: instant).dateString == "2026-09-13")
    }

    @Test func failedNextPageRetainsResultsAndCanRetry() async {
        var shouldFail = true
        let first = (0..<20).map { _ in Self.performance(title: "첫 페이지") }
        let last = Self.performance(title: "마지막")
        let store = ConcertStore { _, offset in
            if offset == 0 { return first }
            if shouldFail { throw URLError(.notConnectedToInternet) }
            return [last]
        }
        await store.search(ConcertFilter())
        await store.loadMore()
        #expect(store.performances == first)
        #expect(store.errorMessage != nil)
        #expect(store.hasMore)
        shouldFail = false
        await store.loadMore()
        #expect(store.performances == first + [last])
        #expect(!store.hasMore)
        #expect(store.errorMessage == nil)
    }

    @Test func oldSearchCannotReplaceNewResults() async {
        var pending: CheckedContinuation<[Performance], Error>?
        var began: CheckedContinuation<Void, Never>?
        let latest = Self.performance(title: "최신")
        let store = ConcertStore { filter, _ in
            if filter.title == "old" {
                return try await withCheckedThrowingContinuation {
                    pending = $0
                    began?.resume()
                }
            }
            return [latest]
        }
        let old = Task { await store.search(ConcertFilter(title: "old")) }
        await withCheckedContinuation { continuation in
            if pending != nil { continuation.resume() } else { began = continuation }
        }
        await store.search(ConcertFilter(title: "new"))
        pending?.resume(returning: [Self.performance(title: "오래된 결과")])
        await old.value
        #expect(store.performances == [latest])
        #expect(!store.isLoading)
    }

    static func performance(title: String) -> Performance {
        Performance(id: UUID(), title: title, posterURL: nil, venue: nil, region: nil,
                    startDate: "2026-09-13", endDate: "2026-09-15", description: nil)
    }
}
