import SwiftUI

struct MyRoomsView: View {
    @State private var rooms: [Room] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var generation = UUID()

    var body: some View {
        List {
            if isLoading && rooms.isEmpty { ProgressView("참여한 방을 불러오는 중") }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
                Button("다시 시도") { Task { await load() } }
            } else if !isLoading && rooms.isEmpty {
                ContentUnavailableView("참여 중인 방이 없어요", systemImage: "person.2",
                                       description: Text("공연을 선택하고 뒤풀이 방에 참여해보세요."))
            }
            ForEach(rooms) { room in
                NavigationLink { RoomDetailView(roomID: room.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(room.title).font(.headline)
                        Text("\(room.category.label) · \(room.memberCount)/\(room.capacity)명")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("내 참여 방")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let request = UUID()
        generation = request
        isLoading = true
        errorMessage = nil
        defer { if request == generation { isLoading = false } }
        do {
            let result = try await RoomService(client: supabase).myRooms()
            try Task.checkCancellation()
            guard request == generation else { return }
            rooms = result
        } catch {
            if request == generation && !Task.isCancelled { errorMessage = RoomFailure.message(for: error) }
        }
    }
}
