import Foundation
import Supabase

struct ConcertService {
    let client: SupabaseClient
    static let pageSize = 20

    func performances(filter: ConcertFilter, offset: Int) async throws -> [Performance] {
        let query = client.from("performances").select()
        if !filter.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = query.ilike("title", pattern: filter.titlePattern)
        }
        if let region = filter.region { _ = query.eq("region", value: region) }
        if let date = filter.dateString {
            _ = query.lte("start_date", value: date).gte("end_date", value: date)
        }
        return try await query.order("start_date").order("id")
            .range(from: offset, to: offset + Self.pageSize - 1).execute().value
    }

    func sessions(performanceID: UUID) async throws -> [PerformanceSession] {
        try await client.from("performance_sessions").select()
            .eq("performance_id", value: performanceID)
            .order("starts_at").order("id").execute().value
    }
}
