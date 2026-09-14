import Foundation
import Testing
import Supabase
@testable import CurtainCall

@MainActor
struct RoomFlowTests {
    @Test func mapsActualDatabaseExceptionInsteadOfDebugDescription() {
        let error = PostgrestError(code: "P0001", message: "ROOM_FULL")
        #expect(RoomFailure.message(for: error) == RoomFailure.message(code: "ROOM_FULL"))
    }

    @Test func memberCanOpenFullRoomButVisitorCannotJoin() {
        let room = Self.room(memberCount: 2)
        #expect(room.canOpen(isMember: true))
        #expect(!room.canOpen(isMember: false))
    }

    @Test func drinkingDraftDisplaysTheRestrictionItSends() {
        var draft = RoomDraft()
        draft.category = .drinking
        #expect(draft.requiresAdultVerification)
    }

    @Test func revokedMembershipClearsPreviouslyLoadedParticipants() async {
        let actor = UUID()
        let room = Self.room(hostID: actor)
        var revoked = false
        let store = RoomStore(roomID: room.id, fetch: { _ in
            RoomSnapshot(room: room, members: revoked ? [] : [Self.member(actor, roomID: room.id)], userID: actor)
        }, command: { _ in room.id })
        await store.load()
        #expect(store.snapshot?.members.count == 1)
        revoked = true
        await store.load()
        #expect(store.snapshot == nil)
        #expect(store.hasLostAccess)
    }

    @Test func failedLeaveKeepsRoomOpenAndShowsReason() async {
        let actor = UUID()
        let room = Self.room(hostID: actor)
        let store = RoomStore(roomID: room.id, fetch: { _ in
            RoomSnapshot(room: room, members: [Self.member(actor, roomID: room.id)], userID: actor)
        }, command: { _ in throw PostgrestError(code: "P0001", message: "HOST_TRANSFER_REQUIRED") })
        await store.load()
        await store.perform(.leave)
        #expect(!store.hasLeft)
        #expect(store.snapshot != nil)
        #expect(store.errorMessage == RoomFailure.message(code: "HOST_TRANSFER_REQUIRED"))
    }

    @Test func successfulLeaveClearsRoomAndDoesNotReloadIt() async {
        let actor = UUID()
        let room = Self.room(hostID: actor)
        var loads = 0
        let store = RoomStore(roomID: room.id, fetch: { _ in
            loads += 1
            return RoomSnapshot(room: room, members: [Self.member(actor, roomID: room.id)], userID: actor)
        }, command: { request in
            #expect(request.pAction == "leave")
            #expect(request.pRoomID == room.id)
            return room.id
        })
        await store.load()
        await store.perform(.leave)
        #expect(store.hasLeft)
        #expect(store.snapshot == nil)
        #expect(loads == 1)
    }

    @Test func lateLoadCannotRestoreRoomAfterLeaving() async {
        let actor = UUID()
        let room = Self.room(hostID: actor)
        var pending: CheckedContinuation<RoomSnapshot, Error>?
        var started: CheckedContinuation<Void, Never>?
        var suspend = false
        let snapshot = RoomSnapshot(room: room, members: [Self.member(actor, roomID: room.id)], userID: actor)
        let store = RoomStore(roomID: room.id, fetch: { _ in
            if suspend {
                return try await withCheckedThrowingContinuation {
                    pending = $0
                    started?.resume()
                }
            }
            return snapshot
        }, command: { _ in room.id })
        await store.load()
        suspend = true
        let oldLoad = Task { await store.load() }
        await withCheckedContinuation { continuation in
            if pending != nil { continuation.resume() } else { started = continuation }
        }
        await store.perform(.leave)
        pending?.resume(returning: snapshot)
        await oldLoad.value
        #expect(store.hasLeft)
        #expect(store.snapshot == nil)
    }

    static func room(hostID: UUID = UUID(), memberCount: Int = 1) -> Room {
        Room(id: UUID(), sessionID: UUID(), hostUserID: hostID, hostNickname: "방장",
             title: "공연 뒤풀이", description: "", category: .cafe, adultOnly: false,
             capacity: 2, memberCount: memberCount, expiresAt: Date().addingTimeInterval(3600))
    }

    static func member(_ userID: UUID, roomID: UUID) -> RoomMember {
        RoomMember(roomID: roomID, userID: userID, nickname: "관객", status: .active)
    }
}
