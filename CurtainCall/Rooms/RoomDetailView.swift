import SwiftUI

struct RoomDetailView: View {
    @State private var store: RoomStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingAction: RoomAction?
    @State private var target: RoomMember?
    @State private var isEditing = false

    init(roomID: UUID) { _store = State(initialValue: RoomStore(roomID: roomID)) }

    var body: some View {
        List {
            if store.hasLostAccess {
                ContentUnavailableView("이 방을 이용할 수 없어요", systemImage: "door.left.hand.open",
                                       description: Text("퇴장·강퇴되었거나 방 이용 기간이 끝났어요."))
                Button("목록으로 돌아가기") { dismiss() }
            } else if let snapshot = store.snapshot, let room = snapshot.room {
                Section {
                    Text(room.title).font(.title2.bold())
                    Text(room.description.isEmpty ? "소개 없음" : room.description)
                    Label(room.category.label, systemImage: "person.2")
                    Text("이용 기한: \(room.expiresAt.formatted(ConcertDetailView.sessionFormat))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("참여자 \(snapshot.members.count)/\(room.capacity)") {
                    ForEach(snapshot.members) { member in
                        HStack {
                            Text(member.nickname)
                            if member.userID == room.hostUserID { Text("방장").font(.caption).foregroundStyle(.tint) }
                            if member.userID == snapshot.userID { Text("나").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            if snapshot.isHost && member.userID != snapshot.userID {
                                Menu {
                                    Button("방장 위임") { target = member; pendingAction = .transfer }
                                    Button("강퇴", role: .destructive) { target = member; pendingAction = .kick }
                                } label: { Label("참여자 관리", systemImage: "ellipsis.circle") }
                                .disabled(store.isWorking || store.isLoading)
                            }
                        }
                    }
                }
                Section {
                    if snapshot.isHost {
                        Button("방 정보 수정") { isEditing = true }
                    }
                    Button("방 나가기", role: .destructive) { target = nil; pendingAction = .leave }
                    if snapshot.isHost && snapshot.members.count > 1 {
                        Text("나가기 전에 다른 참여자에게 방장을 위임해주세요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.disabled(store.isWorking || store.isLoading)
            } else if store.isLoading {
                ProgressView("방을 불러오는 중")
            }
            if let error = store.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                    if !store.hasLostAccess { Button("새로고침") { Task { await store.load() } } }
                }
            }
            if store.isWorking { ProgressView("변경 사항을 적용하는 중") }
        }
        .navigationTitle("내 뒤풀이 방").navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.load() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            repeat {
                await store.load()
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
            } while !Task.isCancelled && !store.hasLeft && !store.hasLostAccess
        }
        .onChange(of: store.hasLeft) { _, left in if left { dismiss() } }
        .confirmationDialog(confirmationTitle, isPresented: Binding(
            get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }
        ), titleVisibility: .visible) {
            Button("확인", role: pendingAction == .transfer ? nil : .destructive) {
                guard let action = pendingAction else { return }
                let targetID = target?.userID
                pendingAction = nil
                Task { await store.perform(action, targetID: targetID) }
            }
            Button("취소", role: .cancel) { pendingAction = nil }
        }
        .sheet(isPresented: $isEditing) {
            if let room = store.snapshot?.room {
                NavigationStack { RoomEditView(store: store, room: room) }
            }
        }
    }

    private var confirmationTitle: String {
        switch pendingAction {
        case .kick: "\(target?.nickname ?? "참여자")님을 강퇴할까요? 이 방에 다시 입장할 수 없어요."
        case .transfer: "\(target?.nickname ?? "참여자")님에게 방장을 위임할까요?"
        default: "방에서 나갈까요?"
        }
    }
}

private struct RoomEditView: View {
    let store: RoomStore
    @State private var draft: RoomDraft
    @Environment(\.dismiss) private var dismiss

    init(store: RoomStore, room: Room) {
        self.store = store
        _draft = State(initialValue: RoomDraft(title: room.title, description: room.description,
                                               category: room.category, adultOnly: room.adultOnly, capacity: room.capacity))
    }

    var body: some View {
        Form {
            RoomDraftFields(draft: $draft)
            if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            Button("저장") {
                Task {
                    await store.perform(.update, draft: draft)
                    if store.errorMessage == nil && !store.hasLostAccess { dismiss() }
                }
            }.disabled(draft.validationError != nil || store.hasLostAccess)
        }
        .disabled(store.isWorking)
        .navigationTitle("방 정보 수정")
        .toolbar { Button("취소") { dismiss() }.disabled(store.isWorking) }
        .interactiveDismissDisabled(store.isWorking)
    }
}
