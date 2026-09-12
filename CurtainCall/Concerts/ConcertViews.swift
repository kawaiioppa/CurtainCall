import SwiftUI

struct ConcertListView: View {
    @State private var store = ConcertStore()
    @State private var filter = ConcertFilter()
    @State private var showsFilters = false

    var body: some View {
        List {
            Section {
                Text("함께 여운을 나눌 공연을 찾아보세요.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(store.performances) { performance in
                NavigationLink(value: performance) {
                    HStack(alignment: .top, spacing: 14) {
                        ConcertPoster(url: performance.posterURL)
                            .frame(width: 64, height: 88).clipShape(.rect(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(performance.title).font(.headline)
                            Text(performance.venue ?? "장소 미정").font(.subheadline)
                            Text("\(performance.startDate) ~ \(performance.endDate)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4)
                }
            }
            if store.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let error = store.errorMessage {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("다시 시도") { Task { await store.loadMore() } }
                }
            } else if store.performances.isEmpty {
                ContentUnavailableView(
                    filter == ConcertFilter() ? "등록된 공연이 없어요" : "검색 결과가 없어요",
                    systemImage: "theatermasks",
                    description: Text(filter == ConcertFilter()
                        ? "공연 정보가 등록되면 이곳에서 확인할 수 있어요."
                        : "공연명이나 날짜·지역 조건을 바꿔보세요.")
                )
            } else if store.hasMore {
                Button("공연 더 보기") { Task { await store.loadMore() } }
            }
        }
        .listStyle(.plain)
        .searchable(text: $filter.title, prompt: "공연명 검색")
        .navigationDestination(for: Performance.self) { ConcertDetailView(performance: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("검색 조건", systemImage: "line.3.horizontal.decrease") { showsFilters = true }
            }
        }
        .sheet(isPresented: $showsFilters) {
            NavigationStack {
                Form {
                    Picker("지역", selection: $filter.region) {
                        Text("전체").tag(String?.none)
                        ForEach(["서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종", "경기", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주"], id: \.self) {
                            Text($0).tag(Optional($0))
                        }
                    }
                    Toggle("관람 날짜 지정", isOn: Binding(
                        get: { filter.date != nil }, set: { filter.date = $0 ? Date() : nil }
                    ))
                    if filter.date != nil {
                        DatePicker("관람 날짜", selection: Binding(
                            get: { filter.date ?? Date() }, set: { filter.date = $0 }
                        ), displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(identifier: "Asia/Seoul")!)
                    }
                    Button("조건 초기화") { filter = ConcertFilter(title: filter.title) }
                }
                .navigationTitle("검색 조건").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("완료") { showsFilters = false } }
            }.presentationDetents([.medium])
        }
        .task(id: filter) {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            await store.search(filter)
        }
        .refreshable { await store.search(filter) }
        .accessibilityIdentifier("concertList")
    }
}

struct ConcertDetailView: View {
    let performance: Performance
    @State private var sessions: [PerformanceSession] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        List {
            Section {
                ConcertPoster(url: performance.posterURL)
                    .frame(maxWidth: .infinity).frame(height: 280)
                    .listRowBackground(Color.clear)
                Text(performance.title).font(.title2.bold())
                Label(performance.venue ?? "장소 미정", systemImage: "mappin.and.ellipse")
                Label("\(performance.startDate) ~ \(performance.endDate)", systemImage: "calendar")
                if let description = performance.description, !description.isEmpty {
                    Text(description).font(.body)
                }
            }
            Section("관람 회차 선택 · 한국 시간") {
                if isLoading { ProgressView("회차를 불러오는 중") }
                else if let error {
                    Text(error).foregroundStyle(.secondary)
                    Button("다시 시도") { Task { await load() } }
                } else if sessions.isEmpty {
                    Text("아직 등록된 회차가 없어요. 관람 일정이 확인되면 선택할 수 있어요.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.startsAt.formatted(Self.sessionFormat))
                                    if session.endsAt == nil {
                                        Text("종료 시간 미정").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }.tint(.primary)
                    }
                }
            }
        }
        .navigationTitle("공연 상세").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PerformanceSession.self) { RoomListView(session: $0) }
        .task { await load() }
        .refreshable { await load() }
    }

    static var sessionFormat: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .shortened,
                         locale: Locale(identifier: "ko_KR"),
                         timeZone: TimeZone(identifier: "Asia/Seoul")!)
    }

    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            sessions = try await ConcertService(client: supabase).sessions(performanceID: performance.id)
        } catch {
            if !Task.isCancelled { self.error = "회차를 불러오지 못했어요. 다시 시도해주세요." }
        }
    }
}

struct ConcertPoster: View {
    let url: String?
    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Rectangle().fill(.quaternary).overlay {
                    Image(systemName: "theatermasks").font(.title).foregroundStyle(.secondary)
                }
            }
        }.accessibilityHidden(true)
    }
}
