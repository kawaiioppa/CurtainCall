import Foundation
import Testing
import Supabase
@testable import CurtainCall

struct CurtainCallTests {
    @Test func expiredRestoredSessionIsNotAcceptedAsSignedIn() {
        let user = User(
            id: UUID(), appMetadata: [:], userMetadata: [:], aud: "authenticated",
            email: "user@example.com", createdAt: Date(), updatedAt: Date()
        )
        let expiredSession = Session(
            accessToken: "expired", tokenType: "bearer", expiresIn: 3600,
            expiresAt: Date.distantPast.timeIntervalSince1970,
            refreshToken: "refresh", user: user
        )

        #expect(AuthSessionPolicy.activeUser(from: expiredSession) == nil)
        #expect(AuthSessionPolicy.activeUser(from: nil) == nil)
    }

    @Test @MainActor func invalidSignupReturnsFailureAndKeepsError() async {
        let auth = AuthStore()

        let outcome = await auth.signUp(
            email: "a@example.com", password: "123",
            confirmation: "123", nickname: "닉네임"
        )

        #expect(outcome == .failed)
        #expect(auth.errorMessage == "비밀번호는 8자 이상으로 입력해주세요.")
        #expect(!auth.isBusy)
        #expect(auth.user == nil)
    }

    @Test func rejectsInvalidSignup() {
        #expect(AuthValidation.signup(email: "invalid", password: "password123", confirmation: "password123", nickname: "닉네임") != nil)
        #expect(AuthValidation.signup(email: "a@example.com", password: "123", confirmation: "123", nickname: "닉네임") != nil)
        #expect(AuthValidation.signup(email: "a@example.com", password: "password123", confirmation: "different", nickname: "닉네임") != nil)
        #expect(AuthValidation.signup(email: "a@example.com", password: "password123", confirmation: "password123", nickname: "  ") != nil)
    }

    @Test func acceptsValidSignup() {
        #expect(AuthValidation.signup(email: "a@example.com", password: "password123", confirmation: "password123", nickname: "커튼콜") == nil)
    }

    @Test func loginDoesNotApplyNewPasswordPolicy() {
        #expect(AuthValidation.login(email: "a@example.com", password: "old") == nil)
        #expect(AuthValidation.login(email: "a@example.com", password: "") != nil)
    }

    @Test func validatesPasswordReset() {
        #expect(AuthValidation.passwordReset(password: "123", confirmation: "123") == "비밀번호는 8자 이상으로 입력해주세요.")
        #expect(AuthValidation.passwordReset(password: "password123", confirmation: "different") == "비밀번호가 일치하지 않아요.")
        #expect(AuthValidation.passwordReset(password: "password123", confirmation: "password123") == nil)
    }
}
