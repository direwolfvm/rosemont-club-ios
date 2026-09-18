import SwiftUI

/// Group, event, resource, poll, or consultation page. Mirrors the website's `Detail`.
struct DetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    var item: Entity

    @State private var entity: Entity
    @State private var joinStatus = "none"
    @State private var selectedDate = ""
    @State private var attending = false
    @State private var members: [MembershipRow] = []
    @State private var results: PollResults?
    @State private var selectedOption: Int?
    @State private var busy = false
    @State private var showEventEditor = false
    @State private var calendarFile: URL?
    @State private var showShare = false

    init(item: Entity) {
        self.item = item
        _entity = State(initialValue: item)
    }

    private var e: Entity { entity }
    private var dates: [String] { e.locked ? [] : Occurrences.upcoming(for: e) }
    private var activeDate: String { selectedDate.isEmpty ? (dates.first ?? "") : selectedDate }
    private var override: DateOverride? { e.overrides.first { $0.date == String(activeDate.prefix(10)) } }
    private var group: Entity? { model.records.first { $0.id == e.groupId && !$0.locked } }
    private var canManage: Bool { e.canManage(model.user) }

    var body: some View {
        ScrollView {
            if e.locked {
                lockedPage
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if e.kind == .events { eventSidebar }
                    if e.kind == .groups { groupSidebar }
                    if !e.description.isEmpty { Paragraphs(text: e.description) }
                    if let group {
                        HStack(spacing: 4) {
                            Text("Hosted by").foregroundStyle(Color.mutedInk)
                            NavigationLink(value: group) { Text(group.name).fontWeight(.semibold).foregroundStyle(Color.brand) }
                        }
                        .font(.system(size: 15))
                    }
                    if e.kind == .groups { groupBody }
                    if e.kind == .events { eventBody }
                    if e.kind == .polls { pollBody }
                    if !e.website.isEmpty, let url = URL(string: e.website) {
                        Button { openURL(url) } label: {
                            Label(e.kind == .consultations ? "Participate on NeighborVote" : "Visit website", systemImage: "arrow.up.right")
                                .labelStyle(TrailingIconLabelStyle())
                        }
                        .buttonStyle(.primary)
                    }
                    if !e.audienceTags.isEmpty || !e.topicTags.isEmpty {
                        FlowTags(tags: e.audienceTags + e.topicTags)
                    }
                    related
                    if !e.contactEmail.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Get in touch").font(.cardTitle).foregroundStyle(Color.ink)
                            if let url = URL(string: "mailto:" + e.contactEmail) {
                                Button(e.contactEmail) { openURL(url) }.foregroundStyle(Color.brand)
                            }
                        }
                        .card()
                    }
                    if [.groups, .events, .resources].contains(e.kind), !canManage {
                        FeedbackPanel(entityId: e.id, ownership: true)
                    }
                    if canManage {
                        NoticeText(text: "You look after this listing. Edit it on rosemont.club, where the full editor lives.")
                        Button { openURL(AppConfig.baseURL.appending(path: "\(e.kind.rawValue)/\(e.slug)")) } label: {
                            Label("Open on the website", systemImage: "arrow.up.right").labelStyle(TrailingIconLabelStyle())
                        }
                        .buttonStyle(.secondaryCompact)
                    }
                }
                .pageGutter()
                .padding(.vertical, 14)
            }
        }
        .background(Color.paper)
        .navigationTitle(e.kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: AppConfig.baseURL.appending(path: "\(e.kind.rawValue)/\(e.slug)")) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task(id: "\(e.id)-\(model.user?.id ?? "")") { await loadExtras() }
        .sheet(isPresented: $showEventEditor) { EventEditor(entity: e, start: activeDate).ignoresSafeArea() }
        .sheet(isPresented: $showShare) { if let calendarFile { ShareSheet(items: [calendarFile]) } }
        .clubDestinations()
    }

    // MARK: Sections

    private var lockedPage: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock").font(.system(size: 32)).foregroundStyle(Color.brand)
            Eyebrow(text: "A little privacy for our neighbors")
            Text(e.name).font(.pageTitle).foregroundStyle(Color.ink).multilineTextAlignment(.center)
            Text("Details are available to \(e.audienceLabel.lowercased()). Private invitations, locations, and contact details stay with their intended audience.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.mutedInk)
            if model.user == nil {
                Button("Sign in to continue") { model.authPresented = true }.buttonStyle(.primary)
            } else {
                NavigationLink(value: Route.profile) { Text("Verify your Rosemont residency") }.buttonStyle(.primary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: e.audienceLabel + (e.status != .active ? " · \(e.status.rawValue)" : ""))
            Text(e.name).font(.pageTitle).foregroundStyle(Color.ink)
            if !e.summary.isEmpty {
                Text(e.summary).font(.system(size: 17)).foregroundStyle(Color.mutedInk)
            }
            if !e.image.isEmpty, let url = URL(string: e.image) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: { Color.mist }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(e.imageAlt.isEmpty ? e.name : e.imageAlt)
            }
        }
    }

    private var groupBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Join the conversation").font(.sectionTitle).foregroundStyle(Color.ink)
            if !e.joinInstructions.isEmpty { Text(e.joinInstructions).foregroundStyle(Color.ink) }
            ForEach(Array(e.channels.enumerated()), id: \.offset) { _, c in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bubble.left").foregroundStyle(Color.brand).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.label.isEmpty ? c.type : c.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                        if !c.instructions.isEmpty { Text(c.instructions).font(.system(size: 15)).foregroundStyle(Color.mutedInk) }
                        if !c.url.isEmpty, let url = URL(string: c.url) {
                            Button { openURL(url) } label: {
                                Label("Open \(c.type)", systemImage: "arrow.up.right").labelStyle(TrailingIconLabelStyle()).font(.system(size: 14, weight: .semibold))
                            }
                        }
                        if !c.email.isEmpty, let url = URL(string: "mailto:" + c.email) {
                            Button(c.email) { openURL(url) }.font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                .card(padding: 14)
            }
            if e.channels.isEmpty {
                NoticeText(text: "Communication details are available to eligible members. Visit your profile to check your residency status.")
            }
            if canManage, !members.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Group followers & requests").font(.cardTitle).foregroundStyle(Color.ink)
                    ForEach(members) { m in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(m.displayName).foregroundStyle(Color.ink)
                                Text(m.status).font(.footnote).foregroundStyle(Color.mutedInk)
                            }
                            Spacer()
                            if m.status == "requested" {
                                Button("Approve") { Task { await approve(m) } }.buttonStyle(.secondaryCompact).disabled(busy)
                            }
                        }
                        .padding(.vertical, 6)
                        Divider().overlay(Color.line)
                    }
                }
                .card()
            }
            let gatherings = model.records.filter { $0.kind == .events && $0.groupId == e.id && !$0.locked && $0.status == .active }
            if !gatherings.isEmpty {
                Text("Group gatherings").font(.sectionTitle).foregroundStyle(Color.ink)
                VStack(spacing: 0) {
                    ForEach(gatherings) { g in
                        NavigationLink(value: g) { ListLinkRow(title: g.name, detail: Occurrences.upcoming(for: g, count: 1).first.map(Occurrences.shortDate)) }.buttonStyle(.plain)
                        Divider().overlay(Color.line)
                    }
                }
            }
        }
    }

    private var eventBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About the gathering").font(.sectionTitle).foregroundStyle(Color.ink)
            HStack(alignment: .top, spacing: 12) {
                infoTile(icon: "calendar", title: "When") {
                    Text(e.recurrence.summary)
                    if let m = e.recurrence.monthsSummary { Text(m).font(.footnote).foregroundStyle(Color.mutedInk) }
                    Text("All times are Eastern time.").font(.footnote).foregroundStyle(Color.mutedInk)
                }
                infoTile(icon: "mappin.and.ellipse", title: "Where") {
                    Text(override?.location.nilIfEmpty ?? e.location)
                    if !e.streetAddress.isEmpty { Text(e.streetAddress).font(.footnote).foregroundStyle(Color.mutedInk) }
                    if !e.mapUrl.isEmpty, let url = URL(string: e.mapUrl) {
                        Button("Open map ↗") { openURL(url) }.font(.footnote.weight(.semibold))
                    } else if !e.streetAddress.isEmpty,
                              let url = URL(string: "https://maps.apple.com/?q=" + (e.streetAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) {
                        Button("Open in Maps ↗") { openURL(url) }.font(.footnote.weight(.semibold))
                    }
                }
            }
            if let sponsor = (override?.sponsor.nilIfEmpty ?? e.sponsor.nilIfEmpty) {
                NoticeText(text: "With thanks to \(sponsor).")
            }
            if !e.notes.isEmpty { Text(e.notes).font(.system(size: 15)).foregroundStyle(Color.ink) }
        }
    }

    private func infoTile<C: View>(icon: String, title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.brand)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
            content().font(.system(size: 15)).foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private var eventSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your next gathering", systemImage: "calendar").font(.cardTitle).foregroundStyle(Color.ink)
            if !dates.isEmpty, e.status == .active {
                Picker("Choose a date", selection: Binding(get: { activeDate }, set: { selectedDate = $0 })) {
                    ForEach(dates, id: \.self) { d in
                        Text("\(Occurrences.longDate(d)) · \(Occurrences.time(d))").tag(d)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.brand)
                if e.rsvp {
                    Button {
                        Task { await toggleRSVP() }
                    } label: {
                        Label(attending ? "Going · cancel RSVP" : "I'll be there", systemImage: attending ? "checkmark" : "hand.wave")
                    }
                    .buttonStyle(.primary)
                    .disabled(busy)
                }
                Button { showEventEditor = true } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.secondary)
                HStack {
                    if let g = Occurrences.googleCalendarURL(for: e, start: activeDate) {
                        Button("Google Calendar ↗") { openURL(g) }
                    }
                    Spacer()
                    Button("Download .ics") { Task { await downloadCalendar() } }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brand)
            } else {
                Text(e.status == .cancelled ? "This event is cancelled." : "No upcoming dates are scheduled.").foregroundStyle(Color.mutedInk)
            }
        }
        .card()
    }

    private var groupSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("You belong here.", systemImage: "person.2").font(.cardTitle).foregroundStyle(Color.ink)
            Text(e.membership == "request" ? "Ask to join this group." : "Keep this group close. Follow it from your profile.")
                .font(.system(size: 15)).foregroundStyle(Color.mutedInk)
            Button {
                Task { await toggleJoin() }
            } label: {
                Text(joinLabel)
            }
            .buttonStyle(.primary)
            .disabled(busy)
            Text("Following here does not automatically join an external chat.").font(.footnote).foregroundStyle(Color.mutedInk)
        }
        .card()
    }

    private var joinLabel: String {
        switch joinStatus {
        case "requested": "Request sent · withdraw"
        case "none": e.membership == "request" ? "Request to join" : "Follow this group"
        default: "Following · unfollow"
        }
    }

    private var pollBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your preference").font(.sectionTitle).foregroundStyle(Color.ink)
            ForEach(Array(e.options.enumerated()), id: \.offset) { i, option in
                Button {
                    selectedOption = i
                } label: {
                    HStack {
                        Image(systemName: selectedOption == i ? "largecircle.fill.circle" : "circle").foregroundStyle(Color.brand)
                        Text(option).foregroundStyle(Color.ink)
                        Spacer()
                        if let counts = results?.counts, i < counts.count {
                            Text("\(counts[i])").fontWeight(.semibold).foregroundStyle(Color.mutedInk)
                        }
                    }
                    .padding(12)
                    .background(selectedOption == i ? Color.mist : Color.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.line))
                }
                .buttonStyle(.plain)
            }
            Button {
                Task { await vote() }
            } label: {
                Text(busy ? "Saving…" : "Save my response")
            }
            .buttonStyle(.primary)
            .disabled(busy || selectedOption == nil || !e.pollIsOpen)
            Text("One response per account; you can update yours while the poll is open. Only aggregate results are shown." + closesText)
                .font(.footnote).foregroundStyle(Color.mutedInk)
            if let total = results?.total, results?.counts != nil {
                Text("\(total) responses so far.").font(.system(size: 15)).foregroundStyle(Color.ink)
            } else {
                Text("Results are shown " + (e.resultsVisibility == "after-close" ? "after the poll closes." : e.resultsVisibility == "admins" ? "to administrators only." : "after you respond."))
                    .font(.system(size: 15)).foregroundStyle(Color.ink)
            }
        }
    }

    private var closesText: String {
        guard let d = ISO8601.parse(e.closes) else { return "" }
        return " Closes " + d.formatted(date: .abbreviated, time: .shortened) + "."
    }

    private var related: some View {
        let ids = e.relatedGroups + e.relatedEvents + e.relatedResources
        let items = ids.compactMap { model.entity(id: $0) }
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Related").font(.cardTitle).foregroundStyle(Color.ink).padding(.bottom, 4)
                    ForEach(items) { r in
                        NavigationLink(value: r) { ListLinkRow(title: r.name, detail: r.kind.label) }.buttonStyle(.plain)
                        Divider().overlay(Color.line)
                    }
                }
            }
        }
    }

    // MARK: Data

    private func loadExtras() async {
        guard !e.locked else { return }
        if let fresh: Entity = try? await model.api.get("entities/\(e.id)") { entity = fresh }
        if e.kind == .groups, model.user != nil {
            if let s: ServerMessage = try? await model.api.get("entities/\(e.id)/join") { joinStatus = s.status ?? "none" }
            if canManage, let rows: [MembershipRow] = try? await model.api.get("entities/\(e.id)/members") { members = rows }
        }
        if e.kind == .polls, let r: PollResults = try? await model.api.get("entities/\(e.id)/results") {
            results = r
            selectedOption = r.selected
        }
        await loadRSVP()
    }

    private func loadRSVP() async {
        guard e.kind == .events, model.user != nil, !activeDate.isEmpty else { return }
        if let s: ServerMessage = try? await model.api.get("entities/\(e.id)/rsvp", query: [.init(name: "date", value: activeDate)]) {
            attending = s.attending ?? false
        }
    }

    private func toggleJoin() async {
        guard model.requireSignIn() else { return }
        busy = true; defer { busy = false }
        await model.perform {
            let s: ServerMessage = try await model.api.post("entities/\(e.id)/join", JoinBody(join: joinStatus == "none"))
            joinStatus = s.status ?? "none"
            model.notify(joinStatus == "none" ? "You are no longer following this group." : joinStatus == "requested" ? "Your membership request is saved." : "You're following this group.")
        }
    }

    private func toggleRSVP() async {
        guard model.requireSignIn() else { return }
        busy = true; defer { busy = false }
        let next = !attending
        await model.perform(next ? "You're on the list. See you there!" : "Your RSVP was cancelled.") {
            let _: ServerMessage = try await model.api.post("entities/\(e.id)/rsvp", RSVPBody(date: activeDate, attending: next))
            attending = next
        }
    }

    private func vote() async {
        guard model.requireSignIn(), let option = selectedOption else { return }
        busy = true; defer { busy = false }
        await model.perform("Your response is saved.") {
            let _: ServerMessage = try await model.api.post("entities/\(e.id)/vote", VoteBody(option: option))
            results = try await model.api.get("entities/\(e.id)/results")
        }
    }

    private func approve(_ m: MembershipRow) async {
        busy = true; defer { busy = false }
        await model.perform("Request approved.") {
            let _: ServerMessage = try await model.api.post("entities/\(e.id)/members", MembershipBody(userId: m.userId, status: "member"))
            members = try await model.api.get("entities/\(e.id)/members")
        }
    }

    private func downloadCalendar() async {
        await model.perform {
            let data = try await model.api.raw("calendar/\(e.id)")
            let url = FileManager.default.temporaryDirectory.appending(path: "\(e.slug).ics")
            try data.write(to: url, options: .atomic)
            calendarFile = url
            showShare = true
        }
    }
}

/// Wrapping row of small tags.
struct FlowTags: View {
    var tags: [String]
    var body: some View {
        var width: CGFloat = 0, height: CGFloat = 0
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(tags.enumerated()), id: \.offset) { i, tag in
                    SmallTag(text: tag)
                        .padding([.trailing, .bottom], 6)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width { width = 0; height -= d.height }
                            let result = width
                            if i == tags.count - 1 { width = 0 } else { width -= d.width }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if i == tags.count - 1 { height = 0 }
                            return result
                        }
                }
            }
        }
        .frame(height: CGFloat((tags.count / 3 + 1)) * 30)
    }
}

/// "What's on your mind?" / "Help look after this listing" panel.
struct FeedbackPanel: View {
    @Environment(AppModel.self) private var model
    var entityId: String = ""
    var ownership = false
    @State private var message = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TileIcon(systemName: "envelope")
            Text(ownership ? "Help look after this listing" : "What's on your mind?").font(.cardTitle).foregroundStyle(Color.ink)
            Text(ownership
                 ? "Offer to maintain this page. A volunteer will review the request."
                 : "Suggest a group, offer to help, or share a neighborhood idea. The volunteer team can read your message.")
                .font(.system(size: 15)).foregroundStyle(Color.mutedInk)
            if model.user != nil {
                LabeledField(label: "Your message", hint: "Please don't include your home address or sensitive personal information.") {
                    TextField("", text: $message, axis: .vertical)
                        .lineLimit(4...8)
                        .textFieldStyle(ClubFieldStyle())
                }
                Button {
                    Task { await send() }
                } label: {
                    Label(busy ? "Sending…" : "Send to the volunteers", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.primary)
                .disabled(busy || message.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
            } else {
                Button("Sign in to share an idea") { model.authPresented = true }.buttonStyle(.primary)
            }
        }
        .card()
    }

    private func send() async {
        busy = true; defer { busy = false }
        await model.perform("Thanks. Your message has been shared with the volunteer team.") {
            let _: ServerMessage = try await model.api.post("feedback", FeedbackBody(message: message, entityId: entityId, type: ownership ? "ownership" : "feedback"))
            message = ""
        }
    }
}
