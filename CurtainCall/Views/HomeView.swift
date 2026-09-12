import SwiftUI

struct HomeView: View {
    let auth: AuthStore
    let email: String

    var body: some View {
        ConcertListView()
            .safeAreaInset(edge: .bottom) { AuthFeedbackView(auth: auth) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Text(email)
                        Button("로그아웃") { Task { await auth.signOut() } }
                            .disabled(auth.isBusy).accessibilityIdentifier("signOut")
                    } label: { Label("내 계정", systemImage: "person.crop.circle") }
                }
            }
    }
}
