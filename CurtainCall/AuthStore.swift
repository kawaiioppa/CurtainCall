import Foundation
import Observation
import Supabase

enum SignUpOutcome: Equatable {
    case awaitingConfirmation
    case signedIn
    case failed
}

@Observable
@MainActor
final class AuthStore {
    private(set) var user: User?
    private(set) var isRestoring = true
    private(set) var isBusy = false
    private(set) var isPasswordRecovery = false
    var errorMessage: String?
    var notice: String?
    private(set) var confirmationEmail: String?
    private(set) var resendAvailableAt = Date.distantPast
    private let callbackSession: (URL) async throws -> Session
    private let localSignOut: () async throws -> Void

    init(
        callbackSession: @escaping (URL) async throws -> Session = {
            try await supabase.auth.session(from: $0)
        },
        localSignOut: @escaping () async throws -> Void = {
            try await supabase.auth.signOut(scope: .local)
        }
    ) {
        self.callbackSession = callbackSession
        self.localSignOut = localSignOut
    }

    func clearError() {
        errorMessage = nil
    }

    func observeSession() async {
        for await (event, session) in supabase.auth.authStateChanges {
            if Task.isCancelled { return }
            applyAuthState(event: event, session: session)
        }
    }

    func applyAuthState(event: AuthChangeEvent, session: Session?) {
        let activeUser = AuthSessionPolicy.activeUser(from: session)
        user = activeUser
        if event == .passwordRecovery {
            isPasswordRecovery = activeUser != nil
        } else if event == .signedOut {
            isPasswordRecovery = false
        }

        // With the new initial-session behavior, an expired local session is
        // emitted before its refresh completes. Keep the loading state until
        // the refresh emits a valid session or signs the user out.
        if event != .initialSession || session == nil || session?.isExpired == false {
            isRestoring = false
        }
    }

    func signIn(email: String, password: String) async {
        guard !isBusy else { return }
        errorMessage = AuthValidation.login(email: email, password: password)
        guard errorMessage == nil else { return }
        isBusy = true
        notice = nil
        defer { isBusy = false }
        do {
            let session = try await supabase.auth.signIn(email: normalized(email), password: password)
            user = session.user
            isPasswordRecovery = false
            confirmationEmail = nil
        } catch {
            if let authError = error as? AuthError, authError.errorCode.rawValue == "email_not_confirmed" {
                confirmationEmail = normalized(email)
            }
            show(error)
        }
    }

    func requestPasswordReset(email: String) async {
        guard !isBusy else { return }
        let email = normalized(email)
        errorMessage = AuthValidation.validateEmail(email)
        guard errorMessage == nil else { return }
        isBusy = true
        notice = nil
        defer { isBusy = false }
        do {
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: Self.callbackURL)
            notice = "비밀번호 재설정 메일을 보냈어요. 받은편지함과 스팸함을 확인해주세요."
        } catch { show(error) }
    }

    func completePasswordReset(password: String, confirmation: String) async -> Bool {
        guard !isBusy else { return false }
        errorMessage = AuthValidation.passwordReset(password: password, confirmation: confirmation)
        guard errorMessage == nil else { return false }
        isBusy = true
        notice = nil
        defer { isBusy = false }
        do {
            user = try await supabase.auth.update(user: UserAttributes(password: password))
            isPasswordRecovery = false
            notice = "비밀번호를 변경했어요."
            return true
        } catch {
            show(error)
            return false
        }
    }

    func signInWithOAuth(provider: Provider) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        notice = nil
        defer { isBusy = false }

#if canImport(AuthenticationServices)
        do {
            let session = try await supabase.auth.signInWithOAuth(
                provider: provider,
                redirectTo: Self.callbackURL
            )
            user = session.user
            confirmationEmail = nil
        } catch is CancellationError {
            notice = "소셜 로그인을 취소했어요."
        } catch {
            errorMessage = "소셜 로그인에 실패했어요. Supabase 제공자 설정을 확인해주세요."
        }
#else
        errorMessage = "이 플랫폼에서는 소셜 로그인을 사용할 수 없어요."
#endif
    }

    func signUp(email: String, password: String, confirmation: String, nickname: String) async -> SignUpOutcome {
        guard !isBusy else { return .failed }
        errorMessage = AuthValidation.signup(email: email, password: password, confirmation: confirmation, nickname: nickname)
        guard errorMessage == nil else { return .failed }
        isBusy = true
        notice = nil
        defer { isBusy = false }
        do {
            let result = try await supabase.auth.signUp(
                email: normalized(email), password: password,
                data: ["nickname": .string(nickname.trimmingCharacters(in: .whitespacesAndNewlines))],
                redirectTo: Self.callbackURL
            )
            if let session = result.session {
                user = session.user
                isPasswordRecovery = false
                confirmationEmail = nil
                return .signedIn
            } else {
                confirmationEmail = normalized(email)
                resendAvailableAt = Date().addingTimeInterval(60)
                notice = "가입 가능한 주소라면 인증 메일이 전송돼요. 메일의 링크를 눌러 인증한 뒤 로그인해주세요."
                return .awaitingConfirmation
            }
        } catch {
            show(error)
            return .failed
        }
    }

    func resendConfirmation() async {
        guard !isBusy, let email = confirmationEmail, Date() >= resendAvailableAt else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await supabase.auth.resend(email: email, type: .signup, emailRedirectTo: Self.callbackURL)
            resendAvailableAt = Date().addingTimeInterval(60)
            notice = "인증 메일을 다시 요청했어요. 받은편지함과 스팸함을 확인해주세요."
        } catch { show(error) }
    }

    func handleCallback(_ url: URL) async {
        guard url.scheme == "curtaincall", url.host == "auth", url.path == "/callback" else { return }
        do {
            let session = try await callbackSession(url)
            user = session.user
            if callbackType(from: url) == "recovery" {
                isPasswordRecovery = true
            }
            confirmationEmail = nil
            errorMessage = nil
            notice = nil
        } catch { show(error) }
    }

    func cancelPasswordRecovery() async {
        guard isPasswordRecovery, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        notice = nil
        defer { isBusy = false }
        do {
            try await localSignOut()
            user = nil
            isPasswordRecovery = false
            confirmationEmail = nil
        } catch {
            show(error)
        }
    }

    func signOut() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await localSignOut()
            user = nil
            isPasswordRecovery = false
            confirmationEmail = nil
            notice = nil
        } catch { show(error) }
    }

    private static let callbackURL = URL(string: "curtaincall://auth/callback")!

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func callbackType(from url: URL) -> String? {
        if let type = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "type" })?.value {
            return type
        }
        guard let fragment = url.fragment,
              let components = URLComponents(string: "?\(fragment)") else { return nil }
        return components.queryItems?.first(where: { $0.name == "type" })?.value
    }

    private func show(_ error: Error) {
        if let authError = error as? AuthError {
            switch authError.errorCode.rawValue {
            case "invalid_credentials": errorMessage = "이메일 또는 비밀번호를 확인해주세요."
            case "email_not_confirmed": errorMessage = "이메일 인증을 완료한 뒤 로그인해주세요."
            case "user_already_exists", "email_exists": errorMessage = "이미 가입한 이메일이에요. 로그인해주세요."
            case "weak_password": errorMessage = "더 안전한 비밀번호를 사용해주세요."
            case "over_email_send_rate_limit", "over_request_rate_limit": errorMessage = "요청이 많아요. 잠시 후 다시 시도해주세요."
            default: errorMessage = "인증 요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요."
            }
        } else {
            errorMessage = "연결을 확인하고 다시 시도해주세요."
        }
    }
}

enum AuthSessionPolicy {
    nonisolated static func activeUser(from session: Session?) -> User? {
        guard let session, !session.isExpired else { return nil }
        return session.user
    }
}
