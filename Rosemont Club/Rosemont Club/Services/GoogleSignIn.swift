import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Native Google sign-in without the Google SDK: an OAuth authorization-code flow with
/// PKCE through `ASWebAuthenticationSession`, using the Firebase project's iOS OAuth
/// client. The resulting Google ID token is exchanged with Firebase (`signInWithIdp`).
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum Error: LocalizedError {
        case cancelled, noCode, exchangeFailed
        var errorDescription: String? {
            switch self {
            case .cancelled: "Google sign-in was cancelled."
            case .noCode, .exchangeFailed: "Google sign-in did not finish. Please try again."
            }
        }
    }

    private var session: ASWebAuthenticationSession?

    /// Returns a Google ID token for the signed-in account.
    func signIn() async throws -> String {
        let verifier = Self.randomURLSafe(32)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let state = Self.randomURLSafe(16)
        let redirect = AppConfig.googleReversedClientID + ":/oauth2redirect"
        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        auth.queryItems = [
            .init(name: "client_id", value: AppConfig.googleClientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let s = ASWebAuthenticationSession(url: auth.url!, callbackURLScheme: AppConfig.googleReversedClientID) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                    continuation.resume(throwing: Error.cancelled)
                } else {
                    continuation.resume(throwing: error ?? Error.noCode)
                }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            session = s
            s.start()
        }
        session = nil
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else { throw Error.noCode }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = [
            "code": code, "client_id": AppConfig.googleClientID, "redirect_uri": redirect,
            "grant_type": "authorization_code", "code_verifier": verifier,
        ].map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = obj["id_token"] as? String else { throw Error.exchangeFailed }
        return idToken
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }

    private static func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URL
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
