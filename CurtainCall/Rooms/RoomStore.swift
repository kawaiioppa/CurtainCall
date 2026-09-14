import Foundation
import Observation

@Observable
@MainActor
final class RoomStore {
    let roomID: UUID
    private(set) var snapshot: RoomSnapshot?
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var hasLeft = false
    private(set) var hasLostAccess = false
    var errorMessage: String?
    private var generation = UUID()
    private let fetch: (UUID) async throws -> RoomSnapshot
    private let command: (RoomCommand) async throws -> UUID

    init(roomID: UUID,
         fetch: @escaping (UUID) async throws -> RoomSnapshot = { try await RoomService(client: supabase).snapshot(roomID: $0) },
         command: @escaping (RoomCommand) async throws -> UUID = { try await RoomService(client: supabase).command($0) }) {
        self.roomID = roomID
        self.fetch = fetch
        self.command = command
    }

    func load() async {
        guard !isWorking, !hasLeft else { return }
        await reload()
    }

    private func reload() async {
        let request = UUID()
        generation = request
        isLoading = true
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await fetch(roomID)
            try Task.checkCancellation()
            guard generation == request, !hasLeft else { return }
            guard let room = result.room, room.expiresAt > Date(), result.isMember else {
                revokeAccess()
                return
            }
            snapshot = result
            hasLostAccess = false
            errorMessage = nil
        } catch {
            guard generation == request, !Task.isCancelled else { return }
            if RoomFailure.losesAccess(error) { revokeAccess() }
            errorMessage = RoomFailure.message(for: error)
        }
    }

    func perform(_ action: RoomAction, targetID: UUID? = nil, draft: RoomDraft? = nil) async {
        guard !isWorking, !hasLeft, !hasLostAccess else { return }
        if action == .update, let error = draft?.validationError {
            errorMessage = error
            return
        }
        generation = UUID() // Invalidate a refresh started before this mutation.
        isLoading = false
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await command(.manage(action, roomID: roomID, targetID: targetID, draft: draft))
            if action == .leave {
                snapshot = nil
                hasLeft = true
            } else {
                await reload()
            }
        } catch {
            if RoomFailure.losesAccess(error) { revokeAccess() }
            errorMessage = RoomFailure.message(for: error)
        }
    }

    private func revokeAccess() {
        snapshot = nil
        hasLostAccess = true
    }
}
