import Foundation
import Observation

@Observable
@MainActor
final class ConcertStore {
    private(set) var performances: [Performance] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var errorMessage: String?
    private var filter = ConcertFilter()
    private var generation = UUID()
    private var offset = 0
    private let fetch: (ConcertFilter, Int) async throws -> [Performance]

    init(fetch: @escaping (ConcertFilter, Int) async throws -> [Performance] = {
        try await ConcertService(client: supabase).performances(filter: $0, offset: $1)
    }) {
        self.fetch = fetch
    }

    func search(_ filter: ConcertFilter) async {
        generation = UUID()
        self.filter = filter
        offset = 0
        performances = []
        hasMore = true
        await load(generation: generation)
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        await load(generation: generation)
    }

    private func load(generation request: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await fetch(filter, offset)
            try Task.checkCancellation()
            guard generation == request else { return }
            let existingIDs = Set(performances.map(\.id))
            performances.append(contentsOf: page.filter { !existingIDs.contains($0.id) })
            offset += page.count
            hasMore = page.count == ConcertService.pageSize
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            errorMessage = "공연을 불러오지 못했어요. 연결을 확인하고 다시 시도해주세요."
        }
    }
}
