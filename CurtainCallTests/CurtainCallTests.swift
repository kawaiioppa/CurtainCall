import Testing
@testable import CurtainCall

struct CurtainCallTests {
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
}
