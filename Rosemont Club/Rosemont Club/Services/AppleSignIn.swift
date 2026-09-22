import AuthenticationServices
import Foundation
import UIKit

/// Re-runs Sign in with Apple to obtain a fresh, single-use authorization code.
/// Used before account deletion so Firebase can revoke the neighbor's Apple tokens,
/// as Apple requires for apps that offer Sign in with Apple.
@MainActor
final class AppleReauthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    enum Error: LocalizedError {
        case cancelled, noCode
        var errorDescription: String? {
            switch self {
            case .cancelled: "Account deletion was cancelled. Confirm with Apple to continue."
            case .noCode: "Apple did not return an authorization. Please try again."
            }
        }
    }

    private var continuation: CheckedContinuation<String, Swift.Error>?
    private var controller: ASAuthorizationController?

    func authorizationCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let code = (authorization.credential as? ASAuthorizationAppleIDCredential)?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            if let code { self.continuation?.resume(returning: code) } else { self.continuation?.resume(throwing: Error.noCode) }
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
