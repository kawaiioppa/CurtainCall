import SwiftUI

struct ContentView: View {
    @State private var auth = AuthStore()

    var body: some View {
        NavigationStack {
            Group {
                if auth.isRestoring {
                    ProgressView("로그인 상태 확인 중")
                } else if let user = auth.user {
                    HomeView(auth: auth, email: user.email ?? "")
                } else {
                    AuthView(auth: auth)
                }
            }
            .navigationTitle(auth.user == nil ? "" : "CurtainCall")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.indigo)
        .task { await auth.observeSession() }
        .onOpenURL { url in Task { await auth.handleCallback(url) } }
    }
}

#Preview {
    ContentView()
}
