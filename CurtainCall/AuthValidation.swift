import Foundation

enum AuthValidation {
    nonisolated static func login(email: String, password: String) -> String? {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
            return "올바른 이메일 주소를 입력해주세요."
        }
        guard !password.isEmpty else { return "비밀번호를 입력해주세요." }
        return nil
    }

    nonisolated static func signup(email: String, password: String, confirmation: String, nickname: String) -> String? {
        if let error = login(email: email, password: password) { return error }
        guard !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "닉네임을 입력해주세요." }
        guard password.count >= 8 else { return "비밀번호는 8자 이상으로 입력해주세요." }
        guard password == confirmation else { return "비밀번호가 일치하지 않아요." }
        return nil
    }
}
