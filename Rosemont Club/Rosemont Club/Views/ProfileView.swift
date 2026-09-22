import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(
                    eyebrow: "Your place in the neighborhood",
                    title: model.user.map { "Hello, \($0.firstName)." } ?? "Hello, neighbor.",
                    text: "A small profile. A little more connection."
                )
                if let user = model.user {
                    SignedInProfile(user: user)
                } else {
                    VStack(spacing: 12) {
                        EmptyState(systemName: "person.2", title: "Join the community", text: "Sign in to follow groups, RSVP, vote, and verify your Rosemont residency.")
                        Button("Sign in or create an account") { model.authPresented = true }.buttonStyle(.primary)
                        if model.hasSavedSession, model.biometricLockEnabled {
                            Button {
                                Task { await model.unlockWithBiometrics() }
                            } label: {
                                Label("Unlock with \(Biometrics.name)", systemImage: Biometrics.symbol)
                            }
                            .buttonStyle(.secondary)
                        }
                    }
                }
                VStack(spacing: 0) {
                    NavigationLink(value: Route.about) { ListLinkRow(title: "About the Club") }.buttonStyle(.plain)
                    Divider().overlay(Color.line)
                    NavigationLink(value: Route.governance) { ListLinkRow(title: "Governance & feedback") }.buttonStyle(.plain)
                    Divider().overlay(Color.line)
                    Link(destination: ExternalLinks.website) { ListLinkRow(title: "rosemont.club on the web") }.buttonStyle(.plain)
                }
            }
            .pageGutter()
            .padding(.vertical, 12)
        }
        .background(Color.paper)
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .clubDestinations()
    }
}

private struct SignedInProfile: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    var user: Member

    @State private var name: String
    @State private var bio: String
    @State private var address = ""
    @State private var busy = false
    @State private var result: String?
    @State private var activity = Activity()
    @State private var biometricError: String?
    @State private var confirmDelete = false

    init(user: Member) {
        self.user = user
        _name = State(initialValue: user.displayName)
        _bio = State(initialValue: user.bio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            profileCard
            securityCard
            residencyCard
            activitySection
            deleteCard
            if user.admin {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Volunteer administration", systemImage: "gearshape").font(.cardTitle).foregroundStyle(Color.ink)
                    Text("People, permissions, the community inbox, and content editing live on the website's admin pages.").font(.system(size: 15)).foregroundStyle(Color.mutedInk)
                    Button { openURL(AppConfig.baseURL.appending(path: "admin")) } label: {
                        Label("Open admin on rosemont.club", systemImage: "arrow.up.right").labelStyle(TrailingIconLabelStyle())
                    }
                    .buttonStyle(.secondaryCompact)
                }
                .card()
            }
        }
        .task { if let a: Activity = try? await model.api.get("activity") { activity = a } }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your profile").font(.sectionTitle).foregroundStyle(Color.ink)
            Text("\(user.email) · \(user.roleLabel)").font(.footnote).foregroundStyle(Color.mutedInk)
            LabeledField(label: "Display name") {
                TextField("Display name", text: $name).textFieldStyle(ClubFieldStyle()).textContentType(.name)
            }
            LabeledField(label: "Short bio (optional)") {
                TextField("A line or two about you", text: $bio, axis: .vertical).lineLimit(2...5).textFieldStyle(ClubFieldStyle())
            }
            Button("Save profile") { Task { await saveProfile() } }
                .buttonStyle(.primary)
                .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
            Text("Your email is not listed in a public member directory.").font(.footnote).foregroundStyle(Color.mutedInk)
            Button {
                Task { await model.signOut() }
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.clay)
        }
        .card()
    }

    private var deleteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delete your account").font(.cardTitle).foregroundStyle(Color.ink)
            Text("Removes your Club profile, group follows, RSVPs, poll responses, and feedback, then deletes your sign-in. The same sign-in is shared with Alex311 Visibility, so it stops working there too. This cannot be undone.")
                .font(.footnote).foregroundStyle(Color.mutedInk)
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete account", systemImage: "trash")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.clay)
        }
        .card()
        .sheet(isPresented: $confirmDelete) { DeleteAccountView(user: user) }
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sign-in security", systemImage: Biometrics.symbol).font(.cardTitle).foregroundStyle(Color.ink)
            if Biometrics.available {
                Toggle(isOn: Binding(
                    get: { model.biometricLockEnabled },
                    set: { on in
                        biometricError = nil
                        do { try model.setBiometricLock(on) } catch { biometricError = error.localizedDescription }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Require \(Biometrics.name)").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                        Text("Your saved sign-in is stored in the Secure Enclave-backed Keychain and only unlocks with \(Biometrics.name).")
                            .font(.footnote).foregroundStyle(Color.mutedInk)
                    }
                }
                .tint(Color.brand)
                if model.biometricLockEnabled {
                    Button { model.lock() } label: { Label("Lock now", systemImage: "lock") }
                        .buttonStyle(.secondaryCompact)
                    Text("The app also locks itself after a couple of minutes in the background.").font(.footnote).foregroundStyle(Color.mutedInk)
                }
            } else {
                Text("Enroll Face ID or Touch ID and set a device passcode to unlock the app without a password.")
                    .font(.footnote).foregroundStyle(Color.mutedInk)
            }
            if let biometricError { NoticeText(text: biometricError, error: true) }
        }
        .card()
    }

    private var residencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.shield").font(.system(size: 28)).foregroundStyle(Color.brand)
            Eyebrow(text: "Neighbors, with privacy")
            Text(user.verifiedResident ? "You're a verified Rosemont resident." : "Verify your Rosemont residency")
                .font(.sectionTitle).foregroundStyle(Color.ink)
            Text("Access resident-only groups, event details, and resources.").foregroundStyle(Color.mutedInk)
            VStack(alignment: .leading, spacing: 6) {
                step(1, "Enter your Alexandria address")
                step(2, "We check the Club boundary")
                step(3, "Only the result is saved")
            }
            Text("Your address is sent to the U.S. Census geocoder to locate it. We do not store the address or coordinates, and administrators cannot see them. This is an address-location check, not proof that you occupy a home.")
                .font(.footnote).foregroundStyle(Color.mutedInk)
            if user.verifiedResident {
                Label("Verified" + (user.verificationDate.flatMap(ISO8601.parse).map { " " + $0.formatted(date: .abbreviated, time: .omitted) } ?? ""), systemImage: "checkmark")
                    .foregroundStyle(Color.success).fontWeight(.semibold)
            } else {
                LabeledField(label: "Alexandria street address") {
                    TextField("Street address, Alexandria, VA ZIP", text: $address)
                        .textFieldStyle(ClubFieldStyle())
                        .textContentType(.fullStreetAddress)
                        .autocorrectionDisabled()
                }
                Button(busy ? "Checking and discarding address…" : "Verify residency") { Task { await verify() } }
                    .buttonStyle(.primary)
                    .disabled(busy || address.trimmingCharacters(in: .whitespaces).count < 8)
            }
            if let result { NoticeText(text: result) }
            Button(user.reviewRequested ? "Volunteer review requested" : "Need help? Request volunteer review") { Task { await requestReview() } }
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.brand)
                .disabled(user.reviewRequested)
            HStack(spacing: 4) {
                Text("The boundary was provided by the community on September 17, 2026.")
                NavigationLink(value: Route.about) { Text("See the outline.").fontWeight(.semibold).foregroundStyle(Color.brand) }
            }
            .font(.footnote).foregroundStyle(Color.mutedInk)
        }
        .card()
        .background(Color.mist.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).frame(width: 22, height: 22).background(Color.brandFill, in: Circle())
            Text(text).font(.system(size: 15)).foregroundStyle(Color.ink)
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your groups & gatherings").font(.sectionTitle).foregroundStyle(Color.ink)
            let follows = activity.groups.filter { $0.status != "none" }.compactMap { g in model.entity(id: g.entityId).map { ($0, g.status) } }
            let rsvps = activity.events.filter(\.attending).compactMap { r in model.entity(id: r.entityId).map { ($0, r.date) } }
            if follows.isEmpty && rsvps.isEmpty {
                Text("Follow a group or RSVP to a gathering and it will show up here.").font(.system(size: 15)).foregroundStyle(Color.mutedInk).padding(.vertical, 6)
            }
            ForEach(follows, id: \.0.id) { item, status in
                NavigationLink(value: item) { ListLinkRow(title: item.name, detail: status) }.buttonStyle(.plain)
                Divider().overlay(Color.line)
            }
            ForEach(rsvps, id: \.1) { item, date in
                NavigationLink(value: item) { ListLinkRow(title: item.name, detail: Occurrences.longDate(date)) }.buttonStyle(.plain)
                Divider().overlay(Color.line)
            }
            Text("Things you look after").font(.sectionTitle).foregroundStyle(Color.ink).padding(.top, 20)
            let owned = model.records.filter { $0.ownerIds.contains(user.id) }
            if owned.isEmpty {
                Text("Want to help maintain a group or resource? Use \"Help look after this listing\" on its page.").font(.system(size: 15)).foregroundStyle(Color.mutedInk).padding(.vertical, 6)
            }
            ForEach(owned) { item in
                NavigationLink(value: item) { ListLinkRow(title: item.name, detail: item.kind.label) }.buttonStyle(.plain)
                Divider().overlay(Color.line)
            }
        }
    }

    // MARK: Actions

    private func saveProfile() async {
        busy = true; defer { busy = false }
        await model.perform("Your profile is saved.") {
            let updated: Member = try await model.api.patch("me", ProfileUpdate(displayName: name.trimmingCharacters(in: .whitespaces), bio: bio))
            model.user = updated
        }
    }

    private func verify() async {
        busy = true; defer { busy = false }
        result = nil
        let submitted = address
        address = ""
        await model.perform {
            let r: ServerMessage = try await model.api.post("residency", AddressBody(address: submitted))
            if r.verifiedResident == true {
                result = "Your address falls inside the Club boundary. You're verified."
            } else if r.matched == true {
                result = "That address falls outside the current Club boundary. You can request volunteer review."
            } else {
                result = "We could not confidently match that address. Try the full address or request volunteer review."
            }
            await model.refresh()
        }
    }

    private func requestReview() async {
        await model.perform("Your review request is saved. Please do not send your address through feedback.") {
            let _: ServerMessage = try await model.api.post("residency/review", EmptyBody())
            await model.refresh()
        }
    }
}

/// Confirms identity, then deletes the account. Firebase requires a recent sign-in to
/// delete, so the neighbor re-enters their password or confirms with Google or Apple.
private struct DeleteAccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var user: Member
    @State private var providers: [String]?
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    private var usesPassword: Bool { providers?.contains("password") ?? true }
    private var usesGoogle: Bool { providers?.contains("google.com") ?? false }
    private var usesApple: Bool { providers?.contains("apple.com") ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "trash").font(.system(size: 30)).foregroundStyle(Color.clay)
                    Text("Delete your account").font(.pageTitle).foregroundStyle(Color.ink)
                    Text("This removes your Club profile, group follows, RSVPs, poll responses, feedback, and any stored address, then permanently deletes the sign-in you share with Alex311 Visibility. This cannot be undone.")
                        .foregroundStyle(Color.mutedInk)
                    Text("First, confirm it's you.").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                    if providers == nil {
                        ProgressView().tint(Color.brand)
                    } else {
                        if usesPassword {
                            LabeledField(label: "Your password for \(user.email)") {
                                SecureField("Password", text: $password)
                                    .textFieldStyle(ClubFieldStyle())
                                    .textContentType(.password)
                            }
                            Button(role: .destructive) { Task { await run(.password(password)) } } label: {
                                Text(busy ? "Deleting…" : "Delete my account")
                            }
                            .buttonStyle(.primary)
                            .disabled(busy || password.isEmpty)
                        }
                        if usesApple {
                            Button(role: .destructive) { Task { await run(.apple) } } label: {
                                Label("Confirm with Apple and delete", systemImage: "apple.logo")
                            }
                            .buttonStyle(.secondary)
                            .disabled(busy)
                        }
                        if usesGoogle {
                            Button(role: .destructive) { Task { await run(.google) } } label: {
                                Label("Confirm with Google and delete", systemImage: "globe")
                            }
                            .buttonStyle(.secondary)
                            .disabled(busy)
                        }
                    }
                    if let error { NoticeText(text: error, error: true) }
                    Button("Keep my account") { dismiss() }.buttonStyle(.secondary).disabled(busy)
                }
                .pageGutter()
                .padding(.vertical, 12)
            }
            .background(Color.paper)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() }.disabled(busy) } }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .task { providers = await model.linkedProviders() }
    }

    private func run(_ reauth: AppModel.Reauthentication) async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await model.deleteAccount(confirmingWith: reauth)
            dismiss()
        } catch AppleReauthorization.Error.cancelled, GoogleSignIn.Error.cancelled {
            // Nothing to report.
        } catch {
            self.error = error.localizedDescription
        }
    }
}
