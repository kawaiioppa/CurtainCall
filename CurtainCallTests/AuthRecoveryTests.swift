import Foundation
import Supabase
import Testing
@testable import CurtainCall

@MainActor
struct AuthRecoveryTests {
    @Test func recoveryCallbackWaitsForVerifiedSession() async {
        var callback: CheckedContinuation<Session, Error>?
        var callbackStarted: CheckedContinuation<Void, Never>?
        let session = Self.session()
        let auth = AuthStore(callbackSession: { _ in
            try await withCheckedThrowingContinuation { continuation in
                callback = continuation
                callbackStarted?.resume()
            }
        })

        let handling = Task {
            await auth.handleCallback(Self.callbackURL(type: "recovery"))
        }
        await withCheckedContinuation { continuation in
            if callback != nil {
                continuation.resume()
            } else {
                callbackStarted = continuation
            }
        }

        #expect(!auth.isPasswordRecovery)

        callback?.resume(returning: session)
        await handling.value

        #expect(auth.isPasswordRecovery)
        #expect(auth.user == session.user)
    }

    @Test func failedRecoveryCallbackPreservesPreviousValidSession() async {
        let session = Self.session()
        let auth = AuthStore(callbackSession: { url in
            if url.query?.contains("type=recovery") == true {
                throw URLError(.badServerResponse)
            }
            return session
        })
        await auth.handleCallback(Self.callbackURL(type: "signup"))

        await auth.handleCallback(Self.callbackURL(type: "recovery"))

        #expect(!auth.isPasswordRecovery)
        #expect(auth.user == session.user)
        #expect(auth.errorMessage != nil)
    }

    @Test func callbackWithoutTypePreservesVerifiedRecoveryEvent() async {
        let session = Self.session()
        var auth: AuthStore!
        auth = AuthStore(callbackSession: { _ in
            auth.applyAuthState(event: .passwordRecovery, session: session)
            return session
        })

        await auth.handleCallback(URL(string: "curtaincall://auth/callback?code=verified-code")!)

        #expect(auth.isPasswordRecovery)
        #expect(auth.user == session.user)
    }

    @Test func passwordRecoveryEventRequiresAnActiveSession() {
        let auth = AuthStore()

        auth.applyAuthState(event: .passwordRecovery, session: nil)

        #expect(!auth.isPasswordRecovery)
        #expect(auth.user == nil)
    }

    @Test func signedOutEventClearsPasswordRecovery() {
        let auth = AuthStore()
        auth.applyAuthState(event: .passwordRecovery, session: Self.session())
        #expect(auth.isPasswordRecovery)

        auth.applyAuthState(event: .signedOut, session: nil)

        #expect(!auth.isPasswordRecovery)
        #expect(auth.user == nil)
    }

    @Test func cancellingRecoverySignsOutBeforeLeavingRecovery() async {
        let session = Self.session()
        let auth = AuthStore(
            callbackSession: { _ in session },
            localSignOut: {}
        )
        await auth.handleCallback(Self.callbackURL(type: "recovery"))

        await auth.cancelPasswordRecovery()

        #expect(!auth.isPasswordRecovery)
        #expect(auth.user == nil)
        #expect(auth.errorMessage == nil)
    }

    @Test func failedRecoveryCancellationDoesNotExposeSessionToHome() async {
        let session = Self.session()
        let auth = AuthStore(
            callbackSession: { _ in session },
            localSignOut: { throw URLError(.notConnectedToInternet) }
        )
        await auth.handleCallback(Self.callbackURL(type: "recovery"))

        await auth.cancelPasswordRecovery()

        #expect(auth.isPasswordRecovery)
        #expect(auth.user == session.user)
        #expect(auth.errorMessage != nil)
    }

    private static func callbackURL(type: String) -> URL {
        URL(string: "curtaincall://auth/callback?type=\(type)")!
    }

    private static func session() -> Session {
        let now = Date()
        let user = User(
            id: UUID(),
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            email: "user@example.com",
            createdAt: now,
            updatedAt: now
        )
        return Session(
            accessToken: "access-token",
            tokenType: "bearer",
            expiresIn: 3_600,
            expiresAt: now.addingTimeInterval(3_600).timeIntervalSince1970,
            refreshToken: "refresh-token",
            user: user
        )
    }
}
