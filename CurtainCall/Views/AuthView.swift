import SwiftUI

struct AuthView: View {
    let auth: AuthStore
    @State private var isSignup = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var nickname = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 40)).foregroundStyle(.tint)
                    Text("CurtainCall").font(.largeTitle.bold())
                    Text("공연의 여운을 함께 나눠요.")
                        .foregroundStyle(.secondary)
                }.padding(.top, 28)

                Picker("인증 방식", selection: $isSignup) {
                    Text("로그인").tag(false)
                    Text("회원가입").tag(true)
                }.pickerStyle(.segmented).disabled(auth.isBusy)

                VStack(spacing: 16) {
                    if isSignup {
                        TextField("닉네임", text: $nickname)
                            .textContentType(.nickname)
                            .accessibilityIdentifier("nickname")
                    }
                    TextField("이메일", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("email")
                    SecureField("비밀번호", text: $password)
                        .textContentType(isSignup ? .newPassword : .password)
                        .accessibilityIdentifier("password")
                    if isSignup {
                        SecureField("비밀번호 확인", text: $confirmation)
                            .textContentType(.newPassword)
                            .accessibilityIdentifier("confirmation")
                        Text("비밀번호는 8자 이상으로 입력해주세요.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.textFieldStyle(.roundedBorder).disabled(auth.isBusy)

                AuthFeedbackView(auth: auth)

                Button {
                    Task {
                        if isSignup {
                            let outcome = await auth.signUp(email: email, password: password, confirmation: confirmation, nickname: nickname)
                            if case .awaitingConfirmation = outcome {
                                isSignup = false
                                password = ""
                                confirmation = ""
                            }
                        } else {
                            await auth.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if auth.isBusy { ProgressView().tint(.white) }
                        Text(isSignup ? "회원가입" : "로그인").fontWeight(.semibold)
                        Spacer()
                    }.padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).disabled(auth.isBusy)
                    .accessibilityIdentifier("authSubmit")

                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                    Text("또는").font(.footnote).foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                }

                VStack(spacing: 10) {
                    Button {} label: {
                        Label("Apple 로그인 준비 중", systemImage: "apple.logo")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .accessibilityIdentifier("appleOAuth")

                    Button {} label: {
                        Label("Google 로그인 준비 중", systemImage: "g.circle")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .accessibilityIdentifier("googleOAuth")
                }

                if auth.confirmationEmail != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(auth.resendAvailableAt.timeIntervalSince(context.date))))
                        Button(remaining > 0 ? "인증 메일 재전송 (\(remaining)초)" : "인증 메일 재전송") {
                            Task { await auth.resendConfirmation() }
                        }.disabled(auth.isBusy || remaining > 0)
                    }
                }
            }.padding(24).frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
        .onChange(of: isSignup) { _, _ in
            auth.clearError()
            password = ""
            confirmation = ""
        }
        .onChange(of: auth.user?.id) { _, _ in
            password = ""
            confirmation = ""
        }
    }
}

struct AuthFeedbackView: View {
    let auth: AuthStore

    var body: some View {
        if let error = auth.errorMessage {
            Text(error).font(.callout).foregroundStyle(.red)
                .accessibilityIdentifier("authError")
        }
        if let notice = auth.notice {
            Text(notice).font(.callout).foregroundStyle(.secondary)
        }
    }
}
