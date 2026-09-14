import SwiftUI

struct RoomListView: View {
    let session: PerformanceSession
    @State private var rooms: [Room] = []
    @State private var joinedRoomIDs: Set<UUID> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionError: String?
    @State private var isCreating = false
    @State private var joiningRoomID: UUID?
    @State private var openedRoomID: UUID?
    @State private var generation = UUID()

    var body: some View {
        List {
            Section {
                Text(session.startsAt.formatted(ConcertDetailView.sessionFormat))
                    .font(.subheadline).foregroundStyle(.secondary)
                if session.endsAt == nil {
                    Text("종료 시간이 확인되면 방을 만들 수 있어요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if isLoading && rooms.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("다시 시도") { Task { await load() } }
                }
            }
            if !isLoading && errorMessage == nil && rooms.isEmpty {
                ContentUnavailableView("아직 방이 없어요", systemImage: "bubble.left.and.bubble.right",
                                       description: Text("첫 번째 뒤풀이 방을 만들어보세요."))
            }
            ForEach(rooms) { room in
                RoomRow(room: room, isMember: joinedRoomIDs.contains(room.id),
                        isBusy: joiningRoomID != nil) { Task { await open(room) } }
            }
        }
        .navigationTitle("뒤풀이 방")
        .toolbar {
            Button("방 만들기", systemImage: "plus") { isCreating = true }
                .disabled(isLoading || session.endsAt == nil)
        }
        .sheet(isPresented: $isCreating) {
            NavigationStack {
                RoomCreateView(sessionID: session.id) { roomID in
                    isCreating = false
                    openedRoomID = roomID
                }
            }
        }
        .navigationDestination(item: $openedRoomID) { RoomDetailView(roomID: $0) }
        .alert("방 요청을 완료하지 못했어요", isPresented: Binding(
            get: { actionError != nil }, set: { if !$0 { actionError = nil } }
        )) { Button("확인", role: .cancel) {} } message: { Text(actionError ?? "") }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let request = UUID()
        generation = request
        isLoading = true
        errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await RoomService(client: supabase).listing(sessionID: session.id)
            try Task.checkCancellation()
            guard request == generation else { return }
            rooms = result.rooms
            joinedRoomIDs = result.joinedRoomIDs
        } catch {
            if request == generation && !Task.isCancelled { errorMessage = RoomFailure.message(for: error) }
        }
    }

    private func open(_ room: Room) async {
        guard joiningRoomID == nil else { return }
        if joinedRoomIDs.contains(room.id) { openedRoomID = room.id; return }
        joiningRoomID = room.id
        defer { joiningRoomID = nil }
        do {
            try await RoomService(client: supabase).join(roomID: room.id)
            joinedRoomIDs.insert(room.id)
            openedRoomID = room.id
        } catch { actionError = RoomFailure.message(for: error) }
    }
}

private struct RoomRow: View {
    let room: Room
    let isMember: Bool
    let isBusy: Bool
    let open: () -> Void

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
                Text(room.category.label)
                Spacer()
                Button(isMember ? "방 열기" : room.memberCount >= room.capacity ? "정원 마감" : "입장", action: open)
                    .buttonStyle(.borderedProminent)
                    .disabled(!room.canOpen(isMember: isMember) || isBusy)
            }.font(.caption)
        }.padding(.vertical, 4)
    }
}

struct RoomCreateView: View {
    let sessionID: UUID
    let onCreated: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RoomDraft()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("방 정보") {
                RoomDraftFields(draft: $draft)
                Picker("유형", selection: $draft.category) {
                    ForEach(RoomCategory.allCases) { Text($0.label).tag($0) }
                }
                Toggle("성인 전용", isOn: Binding(
                    get: { draft.requiresAdultVerification }, set: { draft.adultOnly = $0 }
                )).disabled(draft.category == .drinking)
            }
            if draft.requiresAdultVerification {
                Section {
                    Text("성인 확인 기능을 준비 중이에요. 현재는 성인 전용 방과 술자리 방을 만들 수 없어요.")
                        .foregroundStyle(.secondary)
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Section {
                Button(isSaving ? "만드는 중…" : "방 만들기") { Task { await create() } }
                    .disabled(isSaving || draft.validationError != nil || draft.requiresAdultVerification)
            }
        }
        .disabled(isSaving)
        .navigationTitle("방 만들기").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() }.disabled(isSaving) } }
        .interactiveDismissDisabled(isSaving)
    }

    private func create() async {
        guard !isSaving, draft.validationError == nil, !draft.requiresAdultVerification else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let roomID = try await RoomService(client: supabase).create(sessionID: sessionID, draft: draft)
            onCreated(roomID)
            dismiss()
        } catch { errorMessage = RoomFailure.message(for: error) }
    }
}

struct RoomDraftFields: View {
    @Binding var draft: RoomDraft
    var body: some View {
        TextField("방 제목", text: $draft.title).textInputAutocapitalization(.never)
        TextField("소개 (선택)", text: $draft.description, axis: .vertical).lineLimit(3...6)
        Stepper("정원 \(draft.capacity)명", value: $draft.capacity, in: 2...10)
        if let error = draft.validationError, !draft.title.isEmpty {
            Text(error).font(.caption).foregroundStyle(.red)
        }
    }
}
