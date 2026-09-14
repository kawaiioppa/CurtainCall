import Foundation
import Supabase

// Only the SwiftPM verification target compiles this file. Never part of the iOS app.
private final class VerificationStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws {
        lock.lock(); defer { lock.unlock() }; values[key] = value
    }
    func retrieve(key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }; return values[key]
    }
    func remove(key: String) throws {
        lock.lock(); defer { lock.unlock() }; values[key] = nil
    }
}

let supabase = SupabaseClient(
    supabaseURL: URL(string: "http://127.0.0.1:1")!, supabaseKey: "verification-only",
    options: .init(auth: .init(storage: VerificationStorage(), autoRefreshToken: false,
                               emitLocalSessionAsInitialSession: true))
)
