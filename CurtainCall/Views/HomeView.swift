import SwiftUI

struct HomeView: View {
    let auth: AuthStore
    let email: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48)).foregroundStyle(.tint)
            Text("반가워요!").font(.largeTitle.bold())
            Text(email).foregroundStyle(.secondary)
            Text("공연이 끝나도, 이야기는 계속돼요.")
            AuthFeedbackView(auth: auth)
            Button("로그아웃") { Task { await auth.signOut() } }
                .buttonStyle(.bordered).disabled(auth.isBusy)
                .accessibilityIdentifier("signOut")
        }.padding()
    }
}
