import Foundation

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
             pCategory: draft.category.rawValue, pAdultOnly: draft.adultOnly || draft.category == .drinking,
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
    let hostNickname: String
    let title: String
    let description: String
    let category: RoomCategory
    let adultOnly: Bool
    let capacity: Int
    let memberCount: Int
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, capacity
        case sessionID = "session_id", hostNickname = "host_nickname", adultOnly = "adult_only"
        case memberCount = "member_count", expiresAt = "expires_at"
    }
}

enum RoomFailure {
    static func message(code: String) -> String {
        switch code {
        case "ROOM_FULL": "방 정원이 가득 찼어요."
        case "HOST_TRANSFER_REQUIRED": "방장은 먼저 다른 참여자에게 방장을 위임해주세요."
        case "ROOM_KICKED": "이 방에서 강퇴되어 다시 입장할 수 없어요."
        case "ADULT_VERIFICATION_REQUIRED": "성인 확인을 완료한 회원만 참여할 수 있어요."
        case "SCHEDULE_UNAVAILABLE": "회차 종료 시간이 확인되지 않아 방을 만들 수 없어요."
        case "CREATION_DEADLINE_PASSED": "방 생성 가능 시간이 지났어요."
        default: "방 요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }
}
