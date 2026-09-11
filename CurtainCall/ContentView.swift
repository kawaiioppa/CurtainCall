import SwiftUI
import Supabase

struct ContentView: View {
    @State private var auth = AuthStore()
    @State private var isSignup = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var nickname = ""

    var body: some View {
        NavigationStack {
            Group {
                if auth.isRestoring {
                    ProgressView("로그인 상태 확인 중")
                } else if let user = auth.user {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(.tint)
                        Text("반가워요!").font(.largeTitle.bold())
                        Text(user.email ?? "").foregroundStyle(.secondary)
                        Text("공연이 끝나도, 이야기는 계속돼요.")
                        feedback
                        Button("로그아웃") { Task { await auth.signOut() } }
                            .buttonStyle(.bordered).disabled(auth.isBusy)
                            .accessibilityIdentifier("signOut")
                    }.padding()
                } else {
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

                            feedback

                            Button {
                                Task {
                                    if isSignup {
                                        await auth.signUp(email: email, password: password, confirmation: confirmation, nickname: nickname)
                                        if auth.confirmationEmail != nil {
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
                }
            }
            .navigationTitle(auth.user == nil ? "" : "CurtainCall")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.indigo)
        .task { await auth.observeSession() }
        .onOpenURL { url in Task { await auth.handleCallback(url) } }
        .onChange(of: isSignup) { _, _ in auth.errorMessage = nil }
        .onChange(of: auth.user?.id) { _, _ in password = ""; confirmation = "" }
    }

    @ViewBuilder
    private var feedback: some View {
        if let error = auth.errorMessage {
            Text(error).font(.callout).foregroundStyle(.red)
                .accessibilityIdentifier("authError")
        }
        if let notice = auth.notice {
            Text(notice).font(.callout).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
