import AuthenticationServices
import CryptoKit
import SwiftUI

/// Sign in, create an account, or reset a password. Presented as a sheet.
/// After registration, a short welcome step offers Face ID / Touch ID and residency verification.
struct AuthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in", register = "Create account"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .signIn
    @State private var reset = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var busy = false
    @State private var error: String?
    @State private var welcome = false
    @State private var registered = false
    @State private var biometricChoice = Biometrics.available
    @State private var goToProfile = false
    @State private var appleNonce = ""
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focus: Field?

    enum Field { case name, email, password }

    private var valid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard e.contains("@"), e.contains(".") else { return false }
        if reset { return true }
        if mode == .register { return password.count >= 8 && !name.trimmingCharacters(in: .whitespaces).isEmpty }
        return !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if welcome { welcomeStep } else { form }
                }
                .pageGutter()
                .padding(.vertical, 12)
            }
            .background(Color.paper)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BrandMark(size: 30) }
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Your neighborhood starts here")
            Text(reset ? "Reset your password" : mode == .register ? "Hello, neighbor." : "Welcome back.")
                .font(.pageTitle).foregroundStyle(Color.ink)
            Text("One account for The Rosemont Club and Alex311 Visibility.").foregroundStyle(Color.mutedInk)

            if !reset {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in error = nil }
            }

            if !reset, mode == .signIn, model.hasSavedSession, model.biometricLockEnabled {
                Button {
                    Task {
                        busy = true
                        await model.unlockWithBiometrics()
                        busy = false
                        if model.user != nil { dismiss() } else if let e = model.unlockError { error = e }
                    }
                } label: {
                    Label("Sign in with \(Biometrics.name)", systemImage: Biometrics.symbol)
                }
                .buttonStyle(.secondary)
                .disabled(busy)
            }

            if !reset {
                SignInWithAppleButton(.continue) { request in
                    appleNonce = Self.randomNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(appleNonce)
                } onCompletion: { result in
                    Task { await apple(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(busy)
                Button {
                    Task { await google() }
                } label: {
                    Label("Continue with Google", systemImage: "globe")
                }
                .buttonStyle(.secondary)
                .disabled(busy)
                HStack { Rectangle().fill(Color.line).frame(height: 1); Text("or").font(.footnote).foregroundStyle(Color.mutedInk); Rectangle().fill(Color.line).frame(height: 1) }
            }
            if mode == .register, !reset {
                LabeledField(label: "Display name", hint: "How neighbors will see you. You can change it later.") {
                    TextField("First and last name", text: $name)
                        .textFieldStyle(ClubFieldStyle())
                        .textContentType(.name)
                        .submitLabel(.next)
                        .focused($focus, equals: .name)
                        .onSubmit { focus = .email }
                }
            }
            LabeledField(label: "Email") {
                TextField("Email address", text: $email)
                    .textFieldStyle(ClubFieldStyle())
                    .textContentType(mode == .register ? .username : .emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(reset ? .send : .next)
                    .focused($focus, equals: .email)
                    .onSubmit { if reset { Task { await submit() } } else { focus = .password } }
            }
            if !reset {
                LabeledField(label: "Password", hint: mode == .register ? "At least 8 characters." : nil) {
                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textContentType(mode == .register ? .newPassword : .password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($focus, equals: .password)
                        .onSubmit { Task { await submit() } }
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(Color.mutedInk)
                        }
                        .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.line))
                }
            }
            if let error { NoticeText(text: error, error: true) }
            Button {
                Task { await submit() }
            } label: {
                Text(busy ? "Please wait…" : reset ? "Send reset email" : mode == .register ? "Create account" : "Sign in with email")
            }
            .buttonStyle(.primary)
            .disabled(busy || !valid)

            HStack {
                if reset {
                    Button("Back to sign in") { reset = false; error = nil }
                } else {
                    Button(mode == .register ? "Already a member? Sign in" : "New here? Create an account") {
                        mode = mode == .register ? .signIn : .register
                        error = nil
                    }
                    Spacer()
                    Button("Forgot password?") { reset = true; error = nil }
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.brand)

            Text("We use the existing Firebase sign-in service. Your profile and Club permissions stay separate from Alex311.")
                .font(.footnote).foregroundStyle(Color.mutedInk)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "hand.wave").font(.system(size: 34)).foregroundStyle(Color.brand)
            Eyebrow(text: "You're in the Club")
            Text((registered ? "Welcome, " : "Welcome back, ") + (model.user?.firstName ?? "neighbor") + ".").font(.pageTitle).foregroundStyle(Color.ink)
            Text((registered ? "We sent a verification email to \(email). " : "") + "A couple of optional steps make the app easier to use.")
                .foregroundStyle(Color.mutedInk)
            if Biometrics.available {
                Toggle(isOn: $biometricChoice) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Unlock with \(Biometrics.name)", systemImage: Biometrics.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                        Text("Skip the password next time. Your sign-in stays in the device Keychain.").font(.footnote).foregroundStyle(Color.mutedInk)
                    }
                }
                .tint(Color.brand)
                .card()
            }
            let verified = model.user?.verifiedResident == true
            if !verified {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Verify your residency", systemImage: "checkmark.shield").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                    Text("Unlock resident-only groups and event details. Your address is checked against the Club boundary and never stored.").font(.footnote).foregroundStyle(Color.mutedInk)
                }
                .card()
            }
            if let error { NoticeText(text: error, error: true) }
            if verified {
                Button("Continue") { finish(goToProfile: false) }.buttonStyle(.primary)
            } else {
                Button("Verify residency now") { finish(goToProfile: true) }.buttonStyle(.primary)
                Button("Maybe later") { finish(goToProfile: false) }.buttonStyle(.secondary)
            }
        }
    }

    private func submit() async {
        guard valid, !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            if reset {
                try await model.sendPasswordReset(email: e)
                model.notify("If an account exists, a password reset email is on its way.")
                dismiss()
            } else if mode == .register {
                try await model.register(email: e, password: password, displayName: name)
                registered = true
                welcome = true
            } else {
                try await model.signIn(email: e, password: password)
                if Biometrics.available, !model.biometricLockEnabled {
                    welcomeAfterSignIn()
                } else {
                    dismiss()
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func apple(_ result: Result<ASAuthorization, Error>) async {
        guard !busy else { return }
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { self.error = "Apple sign-in did not finish. Please try again." }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                self.error = "Apple sign-in did not finish. Please try again."; return
            }
            busy = true; error = nil
            defer { busy = false }
            do {
                try await model.signInWithApple(idToken: token, rawNonce: appleNonce, fullName: credential.fullName)
                if Biometrics.available, !model.biometricLockEnabled { welcomeAfterSignIn() } else { dismiss() }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private static func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func google() async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await model.signInWithGoogle()
            if Biometrics.available, !model.biometricLockEnabled { welcomeAfterSignIn() } else { dismiss() }
        } catch GoogleSignIn.Error.cancelled {
            // Nothing to report.
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Returning neighbors get a one-tap offer to enable biometrics.
    private func welcomeAfterSignIn() {
        welcome = true
    }

    private func finish(goToProfile: Bool) {
        if Biometrics.available {
            do { try model.setBiometricLock(biometricChoice) } catch { self.error = error.localizedDescription; return }
        }
        if goToProfile { model.notify("Verify your residency from the You tab.") }
        dismiss()
    }
}
