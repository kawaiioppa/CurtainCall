import SwiftUI

struct RoomListView: View {
    let session: PerformanceSession
    @State private var rooms: [Room] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var joiningRoomID: UUID?

    var body: some View {
        List {
            Section {
                Text(session.startsAt.formatted(ConcertDetailView.sessionFormat))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("새로 들어온 사람도 이전 대화를 볼 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.secondary); Button("다시 시도") { Task { await load() } } }
            } else if rooms.isEmpty {
                ContentUnavailableView("아직 방이 없어요", systemImage: "bubble.left.and.bubble.right", description: Text("첫 번째 뒤풀이 방을 만들어보세요."))
            } else {
                ForEach(rooms) { room in
                    RoomRow(room: room, isJoining: joiningRoomID == room.id) {
                        Task { await join(room) }
                    }
                }
            }
        }
        .navigationTitle("뒤풀이 방")
        .toolbar { Button("방 만들기", systemImage: "plus") { isCreating = true }.disabled(isLoading) }
        .sheet(isPresented: $isCreating) {
            NavigationStack { RoomCreateView(sessionID: session.id) { isCreating = false; Task { await load() } } }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { rooms = try await RoomService(client: supabase).rooms(sessionID: session.id) }
        catch { if !Task.isCancelled { errorMessage = "방 목록을 불러오지 못했어요." } }
    }

    private func join(_ room: Room) async {
        joiningRoomID = room.id; defer { joiningRoomID = nil }
        do { try await RoomService(client: supabase).join(roomID: room.id); await load() }
        catch { errorMessage = RoomFailure.message(code: String(describing: error)) }
    }
}

private struct RoomRow: View {
    let room: Room
    let isJoining: Bool
    let join: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(room.title).font(.headline)
                if room.adultOnly { Text("19+").font(.caption.bold()).foregroundStyle(.red) }
                Spacer()
                Text("\(room.memberCount)/\(room.capacity)").font(.subheadline).foregroundStyle(.secondary)
            }
            Text(room.description.isEmpty ? "소개 없음" : room.description)
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            HStack {
                Label(room.hostNickname, systemImage: "person")
                Text(room.category.label).padding(.leading, 4)
                Spacer()
                Button(room.memberCount >= room.capacity ? "정원 마감" : "입장") { join() }
                    .buttonStyle(.borderedProminent).disabled(room.memberCount >= room.capacity || isJoining)
            }.font(.caption)
        }.padding(.vertical, 4)
    }
}

struct RoomCreateView: View {
    let sessionID: UUID
    let onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RoomDraft()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("방 정보") {
                TextField("방 제목", text: $draft.title).textInputAutocapitalization(.never)
                TextField("소개 (선택)", text: $draft.description, axis: .vertical).lineLimit(3...6)
                Picker("유형", selection: $draft.category) { ForEach(RoomCategory.allCases) { Text($0.label).tag($0) } }
                Toggle("성인 전용", isOn: $draft.adultOnly).disabled(draft.category == .drinking)
                Stepper("정원 \(draft.capacity)명", value: $draft.capacity, in: 2...10)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Section { Button(isSaving ? "만드는 중…" : "방 만들기") { Task { await create() } }.disabled(isSaving || draft.validationError != nil) }
        }
        .navigationTitle("방 만들기").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
    }

    private func create() async {
        guard draft.validationError == nil else { return }
        isSaving = true; errorMessage = nil; defer { isSaving = false }
        do { _ = try await RoomService(client: supabase).create(sessionID: sessionID, draft: draft); onCreated(); dismiss() }
        catch { errorMessage = RoomFailure.message(code: String(describing: error)) }
    }
}
