import SwiftUI

struct PasswordResetView: View {
    let auth: AuthStore
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("새 비밀번호 설정")
                .font(.largeTitle.bold())
            Text("새 비밀번호를 입력하면 계정에 바로 적용됩니다.")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                SecureField("새 비밀번호", text: $password)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("newPassword")
                SecureField("새 비밀번호 확인", text: $confirmation)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("newPasswordConfirmation")
            }
            .textFieldStyle(.roundedBorder)
            .disabled(auth.isBusy)

            if let error = auth.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let notice = auth.notice {
                Text(notice)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { _ = await auth.completePasswordReset(password: password, confirmation: confirmation) }
            } label: {
                HStack {
                    Spacer()
                    if auth.isBusy { ProgressView().tint(.white) }
                    Text("비밀번호 변경").fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(auth.isBusy)
            .accessibilityIdentifier("completePasswordReset")

            Button("취소하고 로그인으로") {
                Task { await auth.cancelPasswordRecovery() }
            }
            .buttonStyle(.bordered)
            .disabled(auth.isBusy)
            .accessibilityIdentifier("cancelPasswordRecovery")
        }
        .padding(24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }
}
