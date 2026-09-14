import Foundation
import Supabase

enum RoomCategory: String, Codable, CaseIterable, Identifiable {
    case meal, cafe, drinking
    var id: Self { self }
    var label: String {
        switch self {
        case .meal: "식사"
        case .cafe: "카페"
        case .drinking: "술자리"
        }
    }
}

struct RoomDraft: Equatable {
    var title = ""
    var description = ""
    var category: RoomCategory = .cafe
    var adultOnly = false
    var capacity = 4

    var requiresAdultVerification: Bool { adultOnly || category == .drinking }

    var validationError: String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "방 제목을 입력해주세요." }
        if trimmed.count > 80 { return "방 제목은 80자 이내로 입력해주세요." }
        if description.count > 1000 { return "소개는 1000자 이내로 입력해주세요." }
        if !(2...10).contains(capacity) { return "정원은 2명부터 10명까지예요." }
        return nil
    }
}

struct RoomCommand: Encodable {
    let pAction: String
    let pRoomID: UUID?
    let pSessionID: UUID?
    let pTitle: String?
    let pDescription: String
    let pCategory: String
    let pAdultOnly: Bool
    let pCapacity: Int
    let pTargetID: UUID?

    enum CodingKeys: String, CodingKey {
        case pAction = "p_action", pRoomID = "p_room_id", pSessionID = "p_session_id"
        case pTitle = "p_title", pDescription = "p_description", pCategory = "p_category"
        case pAdultOnly = "p_adult_only", pCapacity = "p_capacity", pTargetID = "p_target_id"
    }

    static func create(sessionID: UUID, draft: RoomDraft) -> Self {
        Self(pAction: "create", pRoomID: nil, pSessionID: sessionID,
             pTitle: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
             pDescription: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
             pCategory: draft.category.rawValue, pAdultOnly: draft.requiresAdultVerification,
             pCapacity: draft.capacity, pTargetID: nil)
    }

    static func join(roomID: UUID) -> Self {
        Self(pAction: "join", pRoomID: roomID, pSessionID: nil, pTitle: nil, pDescription: "",
             pCategory: "cafe", pAdultOnly: false, pCapacity: 2, pTargetID: nil)
    }
}

struct Room: Decodable, Identifiable, Hashable {
    let id: UUID
    let sessionID: UUID
    let hostUserID: UUID
    let hostNickname: String
    let title: String
    let description: String
    let category: RoomCategory
    let adultOnly: Bool
    let capacity: Int
    let memberCount: Int
    let expiresAt: Date

    func canOpen(isMember: Bool) -> Bool {
        expiresAt > Date() && (isMember || memberCount < capacity)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, capacity
        case hostUserID = "host_user_id"
        case sessionID = "session_id", hostNickname = "host_nickname", adultOnly = "adult_only"
        case memberCount = "member_count", expiresAt = "expires_at"
    }
}

enum RoomFailure {
    static func message(for error: Error) -> String {
        guard let error = error as? PostgrestError else {
            return "연결을 확인하고 다시 시도해주세요."
        }
        return message(code: error.message)
    }

    static func losesAccess(_ error: Error) -> Bool {
        guard let error = error as? PostgrestError else { return false }
        return ["ROOM_UNAVAILABLE", "ROOM_ACCESS_DENIED", "ROOM_KICKED", "AUTH_REQUIRED", "ACCOUNT_SUSPENDED"].contains(error.message)
    }

    static func message(code: String) -> String {
        switch code {
        case "ROOM_FULL": "방 정원이 가득 찼어요."
        case "HOST_TRANSFER_REQUIRED": "방장은 먼저 다른 참여자에게 방장을 위임해주세요."
        case "ROOM_KICKED": "이 방에서 강퇴되어 다시 입장할 수 없어요."
        case "ADULT_VERIFICATION_REQUIRED": "성인 확인을 완료한 회원만 참여할 수 있어요."
        case "SCHEDULE_UNAVAILABLE": "회차 종료 시간이 확인되지 않아 방을 만들 수 없어요."
        case "CREATION_DEADLINE_PASSED": "방 생성 가능 시간이 지났어요."
        case "ROOM_UNAVAILABLE": "종료되었거나 더 이상 이용할 수 없는 방이에요."
        case "ROOM_ACCESS_DENIED": "이 방의 참여자가 아니에요."
        case "AUTH_REQUIRED": "이메일 인증 후 다시 로그인해주세요."
        case "ACCOUNT_SUSPENDED": "이용이 제한된 계정이에요."
        case "HOST_REQUIRED": "방장만 변경할 수 있어요."
        case "INVALID_TARGET": "참여자 정보가 변경됐어요. 새로고침 후 다시 시도해주세요."
        case "CAPACITY_BELOW_MEMBERS": "현재 참여 인원보다 정원을 줄일 수 없어요."
        case "INVALID_ROOM": "방 제목과 정원을 확인해주세요."
        default: "방 요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }
}


enum RoomAction: String { case leave, kick, transfer, update }

extension RoomCommand {
    static func manage(_ action: RoomAction, roomID: UUID, targetID: UUID? = nil, draft: RoomDraft? = nil) -> Self {
        Self(pAction: action.rawValue, pRoomID: roomID, pSessionID: nil,
             pTitle: draft?.title.trimmingCharacters(in: .whitespacesAndNewlines),
             pDescription: draft?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
             pCategory: draft?.category.rawValue ?? "cafe", pAdultOnly: draft?.requiresAdultVerification ?? false,
             pCapacity: draft?.capacity ?? 2, pTargetID: targetID)
    }
}

struct RoomMember: Decodable, Identifiable, Equatable {
    enum Status: String, Decodable { case active, left, kicked }
    let roomID: UUID
    let userID: UUID
    let nickname: String
    let status: Status
    var id: UUID { userID }
    enum CodingKeys: String, CodingKey {
        case roomID = "room_id", userID = "user_id", nickname, status
    }
}

struct RoomSnapshot {
    let room: Room?
    let members: [RoomMember]
    let userID: UUID
    var isMember: Bool { members.contains { $0.userID == userID && $0.status == .active } }
    var isHost: Bool { isMember && room?.hostUserID == userID }
}

struct RoomListing {
    let rooms: [Room]
    let joinedRoomIDs: Set<UUID>
}
