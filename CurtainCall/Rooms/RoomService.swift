import Foundation
import Supabase

struct RoomService {
    let client: SupabaseClient

    func rooms(sessionID: UUID) async throws -> [Room] {
        try await client.from("rooms").select()
            .eq("session_id", value: sessionID)
            .order("created_at").order("id").execute().value
    }

    func create(sessionID: UUID, draft: RoomDraft) async throws -> UUID {
        try await client.rpc("room_command", params: RoomCommand.create(sessionID: sessionID, draft: draft))
            .execute().value
    }

    func join(roomID: UUID) async throws {
        let _: UUID = try await client.rpc("room_command", params: RoomCommand.join(roomID: roomID))
            .execute().value
    }
}
