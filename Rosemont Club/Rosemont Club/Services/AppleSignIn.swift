import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Re-runs Sign in with Apple for an existing user. Returns a fresh identity token (to
/// re-authenticate with Firebase) and the single-use authorization code (so Firebase can
/// revoke Apple's tokens before the account is deleted, as Apple requires).
@MainActor
final class AppleReauthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    struct Result { var identityToken: String; var authorizationCode: String; var rawNonce: String }

    enum Error: LocalizedError {
        case cancelled, noCredential
        var errorDescription: String? {
            switch self {
            case .cancelled: "Account deletion was cancelled. Confirm with Apple to continue."
            case .noCredential: "Apple did not return an authorization. Please try again."
            }
        }
    }

    private var continuation: CheckedContinuation<Result, Swift.Error>?
    private var controller: ASAuthorizationController?
    private var rawNonce = ""

    func authorize() async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            var bytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            rawNonce = bytes.map { String(format: "%02x", $0) }.joined()
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            request.nonce = SHA256.hash(data: Data(rawNonce.utf8)).map { String(format: "%02x", $0) }.joined()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let token = credential?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let code = credential?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            if let token, let code {
                self.continuation?.resume(returning: Result(identityToken: token, authorizationCode: code, rawNonce: self.rawNonce))
            } else {
                self.continuation?.resume(throwing: Error.noCredential)
            }
            self.continuation = nil; self.controller = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Swift.Error) {
        Task { @MainActor in
            let cancelled = (error as? ASAuthorizationError)?.code == .canceled
            self.continuation?.resume(throwing: cancelled ? Error.cancelled : error)
            self.continuation = nil; self.controller = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
