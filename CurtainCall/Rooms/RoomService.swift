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

extension RoomService {
    func command(_ request: RoomCommand) async throws -> UUID {
        try await client.rpc("room_command", params: request).execute().value
    }

    func snapshot(roomID: UUID) async throws -> RoomSnapshot {
        let userID = try await client.auth.session.user.id
        let rooms: [Room] = try await client.from("rooms").select()
            .eq("id", value: roomID).execute().value
        let members: [RoomMember] = try await client.from("room_members").select()
            .eq("room_id", value: roomID).eq("status", value: "active")
            .order("joined_at").order("user_id").execute().value
        return RoomSnapshot(room: rooms.first, members: members, userID: userID)
    }

    func myRooms() async throws -> [Room] {
        struct Membership: Decodable { let room: Room }
        let userID = try await client.auth.session.user.id
        let memberships: [Membership] = try await client.from("room_members")
            .select("room:rooms!inner(*)").eq("user_id", value: userID)
            .eq("status", value: "active").execute().value
        return memberships.map(\.room).sorted {
            $0.expiresAt == $1.expiresAt ? $0.id.uuidString < $1.id.uuidString : $0.expiresAt < $1.expiresAt
        }
    }

    func listing(sessionID: UUID) async throws -> RoomListing {
        let rooms = try await rooms(sessionID: sessionID)
        let joined = try await myRooms()
        return RoomListing(rooms: rooms, joinedRoomIDs: Set(joined.map(\.id)))
    }
}
