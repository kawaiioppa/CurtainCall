import Foundation
import Testing
@testable import CurtainCall

@MainActor
struct RoomTests {
    @Test func roomDraftRejectsWhitespaceAndInvalidCapacity() {
        var draft = RoomDraft()
        #expect(draft.validationError != nil)
        draft.title = "함께 이야기해요"
        draft.capacity = 1
        #expect(draft.validationError != nil)
        draft.capacity = 10
        #expect(draft.validationError == nil)
        draft.capacity = 11
        #expect(draft.validationError != nil)
    }

    @Test func drinkingAlwaysRequiresAdultVerificationInPayload() throws {
        var draft = RoomDraft()
        draft.title = "  뒤풀이  "
        draft.category = .drinking
        draft.adultOnly = false
        let command = RoomCommand.create(sessionID: UUID(), draft: draft)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as? [String: Any])
        #expect(json["p_adult_only"] as? Bool == true)
        #expect(json["p_title"] as? String == "뒤풀이")
        #expect(json["p_action"] as? String == "create")
        #expect(json["user_id"] == nil)
    }

    @Test func serverErrorsHaveActionableMessages() {
        #expect(RoomFailure.message(code: "ROOM_FULL").contains("정원"))
        #expect(RoomFailure.message(code: "HOST_TRANSFER_REQUIRED").contains("위임"))
        #expect(RoomFailure.message(code: "ROOM_KICKED").contains("강퇴"))
    }
}
