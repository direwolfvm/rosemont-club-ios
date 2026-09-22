import Foundation

/// A signed-in Firebase identity. Persisted (refresh token only matters long-term) in the Keychain.
struct FirebaseSession: Codable, Equatable {
    var idToken: String
    var refreshToken: String
    var localId: String
    var email: String
    var expiresAt: Date

    var needsRefresh: Bool { expiresAt.timeIntervalSinceNow < 300 }
}

enum AuthError: LocalizedError {
    case firebase(String)
    case network

    var errorDescription: String? {
        switch self {
        case .network: return "We could not reach the sign-in service. Check your connection and try again."
        case .firebase(let code):
            switch code.split(separator: " ").first.map(String.init) ?? code {
            case "EMAIL_EXISTS": return "An account with that email already exists. Try signing in instead."
            case "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND", "INVALID_EMAIL":
                return "We could not sign you in. Check your email and password and try again."
            case "WEAK_PASSWORD": return "Choose a password with at least 8 characters."
            case "TOO_MANY_ATTEMPTS_TRY_LATER": return "Too many attempts. Please wait a few minutes and try again."
            case "USER_DISABLED": return "This account has been disabled."
            case "TOKEN_EXPIRED", "INVALID_REFRESH_TOKEN", "USER_NOT_FOUND", "INVALID_ID_TOKEN":
                return "Your session has expired. Please sign in again."
            case "CREDENTIAL_TOO_OLD_LOGIN_AGAIN":
                return "For your security, please sign in again and then retry."
            case "WRONG_ACCOUNT":
                return "That sign-in belongs to a different account. Confirm with the sign-in you use for this account."
            case "OPERATION_NOT_ALLOWED":
                return "That sign-in method is not enabled yet. Please use another option."
            default:
                // Keep the code visible so support can diagnose unexpected failures.
                let short = code.split(separator: " ").first.map(String.init) ?? code
                return "We could not complete that request (\(short)). Check your details and try again."
            }
        }
    }
}

/// Direct client of the Firebase Identity Toolkit REST API, scoped to the shared
/// Identity Platform tenant the website uses. No Firebase SDK is required.
struct FirebaseAuth {
    var config: AppConfig
    var session: URLSession = .shared

    private var identity: URL { URL(string: "https://identitytoolkit.googleapis.com/v1/")! }
    private var identityV2: URL { URL(string: "https://identitytoolkit.googleapis.com/v2/")! }
    private var secure: URL { URL(string: "https://securetoken.googleapis.com/v1/")! }

    func signIn(email: String, password: String) async throws -> FirebaseSession {
        let r: TokenResponse = try await post("accounts:signInWithPassword", [
            "email": email, "password": password, "returnSecureToken": true, "tenantId": config.tenantId,
        ])
        return r.session(email: email)
    }

    func signUp(email: String, password: String, displayName: String) async throws -> FirebaseSession {
        let r: TokenResponse = try await post("accounts:signUp", [
            "email": email, "password": password, "returnSecureToken": true, "tenantId": config.tenantId,
        ])
        var s = r.session(email: email)
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            let u: TokenResponse = try await post("accounts:update", [
                "idToken": s.idToken, "displayName": name, "returnSecureToken": true,
            ])
            if let t = u.idToken, !t.isEmpty { s.idToken = t }
            if let rt = u.refreshToken, !rt.isEmpty { s.refreshToken = rt }
            if let e = u.expiresIn, let secs = Double(e) { s.expiresAt = Date().addingTimeInterval(secs) }
        }
        return s
    }

    func sendEmailVerification(idToken: String) async throws {
        let _: TokenResponse = try await post("accounts:sendOobCode", [
            "requestType": "VERIFY_EMAIL", "idToken": idToken, "tenantId": config.tenantId,
            "continueUrl": AppConfig.baseURL.absoluteString,
        ])
    }

    func sendPasswordReset(email: String) async throws {
        let _: TokenResponse = try await post("accounts:sendOobCode", [
            "requestType": "PASSWORD_RESET", "email": email, "tenantId": config.tenantId,
            "continueUrl": AppConfig.baseURL.absoluteString,
        ])
    }

    /// Signs in with an Apple identity token from `ASAuthorizationAppleIDCredential`.
    /// `rawNonce` is the unhashed nonce whose SHA-256 was sent in the Apple request.
    func signIn(appleIDToken: String, rawNonce: String) async throws -> FirebaseSession {
        let r: TokenResponse = try await post("accounts:signInWithIdp", [
            "postBody": "id_token=\(appleIDToken)&providerId=apple.com&nonce=\(rawNonce)",
            "requestUri": AppConfig.baseURL.absoluteString,
            "returnSecureToken": true,
            "tenantId": config.tenantId,
        ])
        return r.session(email: "")
    }

    /// Sign-in providers linked to the account (`password`, `google.com`, `apple.com`, …).
    func providers(idToken: String) async throws -> [String] {
        let r: LookupResponse = try await post("accounts:lookup", ["idToken": idToken, "tenantId": config.tenantId])
        return r.users?.first?.providerUserInfo?.compactMap(\.providerId) ?? []
    }

    /// Revokes the account's Sign in with Apple tokens through Firebase, using a fresh
    /// Apple authorization code. Required before deleting an account that used Apple.
    func revokeAppleTokens(authorizationCode: String, idToken: String) async throws {
        let _: TokenResponse = try await post("accounts:revokeToken", [
            "providerId": "apple.com", "tokenType": "CODE", "token": authorizationCode,
            "idToken": idToken, "tenantId": config.tenantId,
        ], base: identityV2)
    }

    /// Permanently deletes the Firebase account behind `idToken`.
    func deleteAccount(idToken: String) async throws {
        let _: TokenResponse = try await post("accounts:delete", ["idToken": idToken, "tenantId": config.tenantId])
    }

    /// Sets the display name on the Firebase account (used after Apple sign-in, which
    /// only provides the name on the first authorization).
    func setDisplayName(_ name: String, idToken: String) async throws {
        let _: TokenResponse = try await post("accounts:update", ["idToken": idToken, "displayName": name, "returnSecureToken": false])
    }

    /// Signs in with a Google ID token obtained natively (see `GoogleSignIn`).
    func signIn(googleIDToken: String) async throws -> FirebaseSession {
        let r: TokenResponse = try await post("accounts:signInWithIdp", [
            "postBody": "id_token=\(googleIDToken)&providerId=google.com",
            "requestUri": AppConfig.baseURL.absoluteString,
            "returnSecureToken": true,
            "tenantId": config.tenantId,
        ])
        return r.session(email: "")
    }

    func refresh(_ s: FirebaseSession) async throws -> FirebaseSession {
        var request = URLRequest(url: secure.appending(path: "token").appending(queryItems: [.init(name: "key", value: config.apiKey)]))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(s.refreshToken)".data(using: .utf8)
        let (data, response) = try await perform(request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw firebaseError(data) }
        let r = try JSONDecoder().decode(RefreshResponse.self, from: data)
        return FirebaseSession(
            idToken: r.id_token,
            refreshToken: r.refresh_token,
            localId: r.user_id,
            email: s.email,
            expiresAt: Date().addingTimeInterval(Double(r.expires_in) ?? 3600)
        )
    }

    // MARK: - Plumbing

    private func post<T: Decodable>(_ method: String, _ body: [String: Any], base: URL? = nil) async throws -> T {
        var request = URLRequest(url: (base ?? identity).appending(path: method).appending(queryItems: [.init(name: "key", value: config.apiKey)]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await perform(request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw firebaseError(data) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var r = request
        r.timeoutInterval = 30
        do { return try await session.data(for: r) } catch { throw AuthError.network }
    }

    private func firebaseError(_ data: Data) -> AuthError {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? [String: Any],
           let message = err["message"] as? String {
            return .firebase(message)
        }
        return .firebase("UNKNOWN")
    }

    private struct TokenResponse: Decodable {
        var idToken: String?
        var refreshToken: String?
        var localId: String?
        var email: String?
        var expiresIn: String?

        func session(email fallbackEmail: String) -> FirebaseSession {
            FirebaseSession(
                idToken: idToken ?? "",
                refreshToken: refreshToken ?? "",
                localId: localId ?? "",
                email: email ?? fallbackEmail,
                expiresAt: Date().addingTimeInterval(Double(expiresIn ?? "3600") ?? 3600)
            )
        }
    }

    private struct LookupResponse: Decodable {
        struct User: Decodable {
            struct Provider: Decodable { var providerId: String? }
            var providerUserInfo: [Provider]?
        }
        var users: [User]?
    }

    private struct RefreshResponse: Decodable {
        var id_token: String
        var refresh_token: String
        var user_id: String
        var expires_in: String
    }
}
