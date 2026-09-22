import Foundation
import Observation
import SwiftUI
import os

/// Central state: directory records, the signed-in neighbor, the Firebase session,
/// and the biometric lock. Views read it through the environment.
@MainActor
@Observable
final class AppModel {
    // Directory
    var records: [Entity] = []
    var user: Member?
    var loading = true
    var loadError: String?

    // Session & lock
    private(set) var session: FirebaseSession?
    var isLocked = false
    var unlockError: String?
    var biometricLockEnabled: Bool {
        didSet { UserDefaults.standard.set(biometricLockEnabled, forKey: Keys.biometric) }
    }
    /// True when a sign-in is saved on this device (biometric-protected or not).
    var hasSavedSession: Bool { Keychain.exists(account: Keys.session) }

    // UI
    var notice: String?
    var authPresented = false
    var config = AppConfig.cached()
    /// A universal link waiting to be shown once records are loaded.
    var pendingLink: DeepLink?
    private let google = GoogleSignIn()
    private let appleReauth = AppleReauthorization()

    private var backgroundedAt: Date?
    private var refreshTask: Task<Void, Never>?

    enum Keys {
        static let session = "firebase-session"
        static let biometric = "club.rosemont.biometricLock"
        static let lockAfter: TimeInterval = 120
    }

    init() {
        biometricLockEnabled = UserDefaults.standard.bool(forKey: Keys.biometric)
        #if DEBUG
        DebugSeams.apply(to: self)
        #endif
    }

    var api: APIClient {
        APIClient { [weak self] in try await self?.validToken() }
    }

    var auth: FirebaseAuth { FirebaseAuth(config: config) }

    var isSignedIn: Bool { session != nil && user != nil }

    // MARK: - Lifecycle

    func start() async {
        // Restore a saved session. Biometric-protected sessions wait for the lock screen.
        if hasSavedSession {
            if biometricLockEnabled {
                isLocked = true
            } else if let data = try? Keychain.load(account: Keys.session),
                      let saved = try? JSONDecoder().decode(FirebaseSession.self, from: data) {
                session = saved
            }
        } else if biometricLockEnabled {
            biometricLockEnabled = false
        }
        async let fresh = AppConfig.fetch()
        await refresh()
        config = await fresh
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = Date()
        case .active:
            defer { backgroundedAt = nil }
            guard biometricLockEnabled, session != nil, let since = backgroundedAt,
                  Date().timeIntervalSince(since) > Keys.lockAfter else { return }
            lock()
        default:
            break
        }
    }

    /// Drops the in-memory session so the next use requires Face ID / Touch ID.
    func lock() {
        guard biometricLockEnabled, hasSavedSession else { return }
        session = nil
        user = nil
        isLocked = true
        unlockError = nil
    }

    func unlockWithBiometrics() async {
        unlockError = nil
        do {
            guard let data = try Keychain.load(account: Keys.session, prompt: "Unlock your Rosemont Club sign-in"),
                  let saved = try JSONDecoder().decode(FirebaseSession?.self, from: data) else {
                throw KeychainError.authenticationFailed
            }
            var s = saved
            if s.needsRefresh { s = try await auth.refresh(s) }
            session = s
            try? persistSession()
            isLocked = false
            await refresh()
        } catch let error as KeychainError {
            if case .userCancelled = error { unlockError = nil } else { unlockError = error.localizedDescription }
        } catch {
            unlockError = error.localizedDescription
        }
    }

    /// Leave the lock screen without unlocking: the saved session stays for next time.
    func continueWithoutUnlocking() {
        isLocked = false
        unlockError = nil
        Task { await refresh() }
    }

    // MARK: - Data

    func refresh() async {
        refreshTask?.cancel()
        let task = Task { await self.load() }
        refreshTask = task
        await task.value
    }

    private func load() async {
        loadError = nil
        loading = records.isEmpty
        do {
            async let list: [Entity] = api.get("entities")
            async let me: Member? = session == nil ? nil : api.get("me")
            let (entities, member) = try await (list, me)
            guard !Task.isCancelled else { return }
            records = entities
            user = member
        } catch let error as APIError where error.isUnauthorized {
            // Token rejected: clear the session but keep browsing publicly.
            await signOut(remote: false)
            loadError = "Please sign in again."
            if let list: [Entity] = try? await api.get("entities") { records = list }
        } catch {
            loadError = error.localizedDescription
        }
        loading = false
    }

    func entity(id: String) -> Entity? { records.first { $0.id == id } }

    func entity(kind: Kind, slug: String) -> Entity? { records.first { $0.kind == kind && $0.slug == slug } }

    func list(_ kind: Kind) -> [Entity] { records.filter { $0.kind == kind && $0.isListed } }

    func content(_ slug: String) -> Entity? { records.first { $0.kind == .content && $0.slug == slug } }

    func tags(scope: String) -> [String] {
        records.filter { $0.kind == .tags && $0.scope == scope && $0.status == .active }.map(\.name)
    }

    /// The soonest upcoming event, preferring featured ones, as on the website homepage.
    var nextEvent: (event: Entity, date: String)? {
        list(.events)
            .filter { !$0.locked && $0.status == .active }
            .sorted { Int($0.featured ? 1 : 0) > Int($1.featured ? 1 : 0) }
            .compactMap { e in Occurrences.upcoming(for: e, count: 1).first.map { (e, $0) } }
            .min { $0.1 < $1.1 }
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        let s = try await auth.signIn(email: email, password: password)
        try await adopt(s)
    }

    func register(email: String, password: String, displayName: String) async throws {
        let s = try await auth.signUp(email: email, password: password, displayName: displayName)
        try? await auth.sendEmailVerification(idToken: s.idToken)
        try await adopt(s)
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, let me = user, me.displayName != name {
            if let updated: Member = try? await api.patch("me", ProfileUpdate(displayName: name, bio: me.bio)) {
                user = updated
            }
        }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        let s = try await auth.signIn(appleIDToken: idToken, rawNonce: rawNonce)
        // Apple only sends the name on the first authorization; keep it.
        if let fullName {
            let name = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                try? await auth.setDisplayName(name, idToken: s.idToken)
                try await adopt(s)
                if let me = user, me.displayName == "Neighbor" || me.displayName.isEmpty,
                   let updated: Member = try? await api.patch("me", ProfileUpdate(displayName: name, bio: me.bio)) {
                    user = updated
                }
                return
            }
        }
        try await adopt(s)
    }

    /// Deletes the neighbor's Club data on the server, then the shared sign-in itself.
    /// Accounts that used Sign in with Apple first re-authorize so Apple's tokens can be revoked.
    func deleteAccount() async throws {
        guard let token = try await validToken() else { throw AuthError.firebase("INVALID_ID_TOKEN") }
        let providers = (try? await auth.providers(idToken: token)) ?? []
        if providers.contains("apple.com") {
            let code = try await appleReauth.authorizationCode()
            try await auth.revokeAppleTokens(authorizationCode: code, idToken: token)
        }
        let _: ServerMessage = try await api.post("me/delete", EmptyBody())
        try await auth.deleteAccount(idToken: token)
        await signOut()
        notify("Your account has been deleted.")
    }

    func signInWithGoogle() async throws {
        let idToken = try await google.signIn()
        let s = try await auth.signIn(googleIDToken: idToken)
        try await adopt(s)
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(email: email)
    }

    private func adopt(_ s: FirebaseSession) async throws {
        session = s
        isLocked = false
        // First authenticated call creates the Club profile server-side if needed.
        let me: Member = try await api.get("me")
        user = me
        try? persistSession()
        await refresh()
    }

    func signOut(remote: Bool = true) async {
        session = nil
        user = nil
        isLocked = false
        Keychain.delete(account: Keys.session)
        biometricLockEnabled = false
        if remote { await refresh() }
    }

    /// Turns the biometric lock on or off for the saved session.
    func setBiometricLock(_ on: Bool) throws {
        guard session != nil else { return }
        if on && !Biometrics.available { throw KeychainError.biometryUnavailable }
        biometricLockEnabled = on
        do { try persistSession() } catch {
            biometricLockEnabled = !on
            try? persistSession()
            throw error
        }
    }

    private func persistSession() throws {
        guard let session else { return }
        let data = try JSONEncoder().encode(session)
        try Keychain.save(data, account: Keys.session, biometric: biometricLockEnabled)
    }

    /// Returns a fresh ID token, refreshing through Firebase when it is about to expire.
    func validToken() async throws -> String? {
        guard var s = session else { return nil }
        if s.needsRefresh {
            s = try await auth.refresh(s)
            session = s
            try? persistSession()
        }
        return s.idToken
    }

    // MARK: - Universal links

    /// Accepts `https://rosemont.club/{kind}/{slug}` and the top-level pages the
    /// association file covers. Unknown paths are ignored (Safari keeps them).
    func open(url: URL) {
        guard let link = DeepLink(url: url) else { return }
        pendingLink = link
    }

    // MARK: - Actions shared by screens

    func notify(_ message: String) {
        notice = message
        Task {
            try? await Task.sleep(for: .seconds(4))
            if notice == message { notice = nil }
        }
    }

    /// Runs an action, surfacing errors as a notice. Presents sign-in when required.
    @discardableResult
    func perform(_ success: String? = nil, _ action: () async throws -> Void) async -> Bool {
        do {
            try await action()
            if let success { notify(success) }
            return true
        } catch let error as APIError where error.isUnauthorized {
            await signOut(remote: false)
            authPresented = true
            notify("Please sign in again.")
        } catch {
            notify(error.localizedDescription)
        }
        return false
    }

    func requireSignIn() -> Bool {
        if user == nil { authPresented = true; return false }
        return true
    }
}

/// Website paths the app can show natively.
enum DeepLink: Equatable {
    case entity(kind: Kind, slug: String)
    case route(Route)

    init?(url: URL) {
        guard url.host()?.lowercased() == "rosemont.club" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch parts.count {
        case 0: self = .route(.about); return
        case 1:
            switch parts[0] {
            case "about": self = .route(.about)
            case "governance": self = .route(.governance)
            case "profile", "following": self = .route(.profile)
            case "groups", "events", "resources": self = .route(.directory(Kind(rawValue: parts[0])!))
            default: return nil
            }
        case 2:
            guard let kind = Kind(rawValue: parts[0]), [.groups, .events, .resources, .polls, .consultations].contains(kind) else { return nil }
            self = .entity(kind: kind, slug: parts[1])
        default: return nil
        }
    }
}

#if DEBUG
/// Launch-argument hooks used only for local verification in the simulator.
/// `-seedBiometricSession` stores a dummy biometric-protected session so the lock
/// screen and Face ID path can be exercised without a real account.
enum DebugSeams {
    @MainActor static func apply(to model: AppModel) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-seedBiometricSession") {
            let fake = FirebaseSession(idToken: "debug", refreshToken: "debug-refresh", localId: "debug", email: "debug@example.com", expiresAt: .distantPast)
            if let data = try? JSONEncoder().encode(fake) {
                do {
                    try Keychain.save(data, account: AppModel.Keys.session, biometric: true)
                    model.biometricLockEnabled = true
                    Logger(subsystem: "club.rosemont.ios", category: "debug").error("seeded biometric session; exists=\(Keychain.exists(account: AppModel.Keys.session)) biometrics=\(String(describing: Biometrics.kind))")
                } catch {
                    Logger(subsystem: "club.rosemont.ios", category: "debug").error("seeding failed: \(String(describing: error))")
                }
            }
        }
        if args.contains("-clearSession") {
            Keychain.delete(account: AppModel.Keys.session)
            model.biometricLockEnabled = false
        }
    }
}
#endif
