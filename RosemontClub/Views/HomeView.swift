import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var who = ""
    @State private var need = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                hero
                quickNav
                upcoming
                groups
                resources
                questions
                aboutStrip
            }
            .pageGutter()
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Color.paper)
        .refreshable { await model.refresh() }
        .navigationTitle("The Rosemont Club")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { BrandMark(size: 30) }
            ToolbarItem(placement: .topBarTrailing) {
                if model.user == nil {
                    Button("Sign in") { model.authPresented = true }.fontWeight(.semibold)
                } else {
                    NavigationLink(value: Route.profile) {
                        Text(model.user?.displayName.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.brandFill, in: Circle())
                    }
                }
            }
        }
        .clubDestinations()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Color.clay).frame(width: 7, height: 7)
                Text("Rosemont · Alexandria, VA").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.mutedInk)
            }
            Text(model.content("home-intro")?.name ?? "Welcome to the Rosemont Club")
                .font(.heroTitle)
                .foregroundStyle(Color.ink)
            Text(model.content("home-intro")?.summary.nilIfEmpty ?? "Live in Rosemont? You're already in the Club! Use this app to connect with neighbors, find events, and get involved!")
                .font(.system(size: 17))
                .lineSpacing(3)
                .foregroundStyle(Color.mutedInk)
            HStack(spacing: 14) {
                NavigationLink(value: Route.directory(.groups)) {
                    Label("Find your people", systemImage: "arrow.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.primaryCompact)
                NavigationLink(value: Route.about) {
                    Label("Get to know the Club", systemImage: "arrow.up.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "leaf").font(.system(size: 13))
                Text("Good neighbors. Good company. Your Club.")
            }
            .font(.footnote)
            .foregroundStyle(Color.mutedInk)
            HistoryCarousel()
        }
    }

    private var quickNav: some View {
        VStack(spacing: 10) {
            quickLink(Route.directory(.groups), icon: "person.2", title: "Find your people", sub: "Groups & connections")
            quickLink(Route.directory(.events), icon: "calendar", title: "Make a little time", sub: "Events & gatherings")
            quickLink(Route.directory(.resources), icon: "safari", title: "Find what you need", sub: "Neighborhood resources")
            quickLink(Route.governance, icon: "bubble.left.and.bubble.right", title: "Lend your voice", sub: "Questions & ideas")
        }
    }

    private func quickLink(_ route: Route, icon: String, title: String, sub: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                TileIcon(systemName: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                    Text(sub).font(.footnote).foregroundStyle(Color.mutedInk)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.mutedInk)
            }
            .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Upcoming in Rosemont", eyebrow: "Good things happen nearby") {
                NavigationLink(value: Route.directory(.events)) { Label("All events", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle()) }
            }
            if let next = model.nextEvent {
                NavigationLink(value: next.event) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            Text(Occurrences.monthAbbrev(next.date).uppercased()).font(.system(size: 12, weight: .bold)).tracking(1)
                            Text(Occurrences.dayNumber(next.date)).font(.display(36, weight: .semibold))
                            Text(Occurrences.weekday(next.date)).font(.system(size: 11)).lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 84)
                        .padding(.vertical, 14)
                        .background(Color.brandFill, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "Your next neighborhood get-together")
                            Text(next.event.name).font(.cardTitle).foregroundStyle(Color.ink)
                            Text(next.event.summary).font(.system(size: 14)).foregroundStyle(Color.mutedInk).lineLimit(3)
                            Label("\(Occurrences.time(next.date)) · Eastern time", systemImage: "calendar").font(.footnote).foregroundStyle(Color.mutedInk)
                            if !next.event.location.isEmpty {
                                Label(next.event.location, systemImage: "mappin").font(.footnote).foregroundStyle(Color.mutedInk)
                            }
                        }
                        .multilineTextAlignment(.leading)
                    }
                    .card()
                }
                .buttonStyle(.plain)
            } else {
                Text(model.loading ? "Loading the neighborhood calendar…" : "No upcoming events yet. Check back for the next gathering.")
                    .foregroundStyle(Color.mutedInk)
            }
        }
    }

    private var groups: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Find your people", eyebrow: "There's a place for you here") {
                NavigationLink(value: Route.directory(.groups)) { Label("Explore groups", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle()) }
            }
            ForEach(model.list(.groups).sorted { ($0.featured ? 1 : 0) > ($1.featured ? 1 : 0) }.prefix(2)) { EntityCard(entity: $0) }
            VStack(alignment: .leading, spacing: 8) {
                TileIcon(systemName: "leaf")
                Text("A small idea can bring people together.").font(.cardTitle).foregroundStyle(Color.ink)
                Text("A walking group, a shared interest, a way to help. Tell us what you have in mind.").font(.system(size: 15)).foregroundStyle(Color.mutedInk)
                NavigationLink(value: Route.governance) {
                    Label("Suggest a group", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle()).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.brand)
                }
            }
            .card()
            .background(Color.mist.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var resources: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Need something?", eyebrow: "A little local knowledge goes a long way") {
                NavigationLink(value: Route.directory(.resources)) { Label("All resources", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle()) }
            }
            ResourceFinder(who: $who, need: $need)
            let matches = ResourceFinder.filter(model.list(.resources), who: who, need: need, query: "")
                .sorted { ($0.featured ? 1 : 0) > ($1.featured ? 1 : 0) }
                .prefix(3)
            VStack(spacing: 0) {
                ForEach(Array(matches)) { r in
                    NavigationLink(value: r) {
                        HStack(spacing: 12) {
                            Image(systemName: "safari").foregroundStyle(Color.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                                Text(r.locked ? "Available to \(r.audienceLabel)" : r.summary).font(.footnote).foregroundStyle(Color.mutedInk).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.mutedInk)
                        }
                        .padding(.vertical, 12)
                        .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Color.line)
                }
            }
            if matches.isEmpty && !model.loading {
                Text("No resources match those selections. Try another topic.").foregroundStyle(Color.mutedInk)
            }
        }
    }

    private var questions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Community questions", eyebrow: "This is our neighborhood") {
                NavigationLink(value: Route.governance) { Label("How we participate", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle()) }
            }
            CommunityQuestions()
        }
    }

    private var aboutStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "leaf").font(.system(size: 30)).foregroundStyle(Color.brand)
            Eyebrow(text: "Rooted in Rosemont")
            Text("A place with history.\nNew memories to make.").font(.sectionTitle).foregroundStyle(Color.ink)
            Text("From streetcar suburb to the streets we call home. Get to know Rosemont, past and present.").foregroundStyle(Color.mutedInk)
            NavigationLink(value: Route.about) {
                Label("Our neighborhood story", systemImage: "arrow.up.right").labelStyle(TrailingIconLabelStyle())
            }
            .buttonStyle(.secondaryCompact)
        }
        .card(padding: 22)
        .background(Color.mist, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Puts the icon after the text, like the website's link arrows.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon.font(.system(size: 13, weight: .semibold))
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// "Who are you? / What are you looking for?" pickers from the audience and topic tags.
struct ResourceFinder: View {
    @Environment(AppModel.self) private var model
    @Binding var who: String
    @Binding var need: String

    var body: some View {
        VStack(spacing: 10) {
            picker("Who are you?", selection: $who, empty: "Any neighbor", options: model.tags(scope: "audience"))
            picker("What are you looking for?", selection: $need, empty: "All topics", options: model.tags(scope: "topic"))
        }
    }

    private func picker(_ label: String, selection: Binding<String>, empty: String, options: [String]) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink)
            Spacer()
            Picker(label, selection: selection) {
                Text(empty).tag("")
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Color.brand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.line))
    }

    /// Same rules as the website's `filteredResources`.
    static func filter(_ items: [Entity], who: String, need: String, query: String) -> [Entity] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return items.filter { e in
            if e.locked {
                return who.isEmpty && need.isEmpty && (q.isEmpty || e.name.lowercased().contains(q))
            }
            let audienceOK = who.isEmpty || e.audienceTags.contains(who) || e.audienceTags.contains("Anyone")
            let topicOK = need.isEmpty || e.topicTags.contains(need)
            let hay = ([e.name, e.summary, e.description] + e.audienceTags + e.topicTags).joined(separator: " ").lowercased()
            return audienceOK && topicOK && (q.isEmpty || hay.contains(q))
        }
    }
}

/// Polls and NeighborVote consultations, shared by Home and Governance.
struct CommunityQuestions: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TileIcon(systemName: "bubble.left.and.bubble.right")
                Eyebrow(text: "A say in where we go next")
                Text("Big questions deserve a shared conversation.").font(.cardTitle).foregroundStyle(Color.ink)
                Text("We use NeighborVote for substantive community consultations. Here, quick polls help with the everyday things.").font(.system(size: 15)).foregroundStyle(Color.mutedInk)
                Button { openURL(ExternalLinks.neighborVote) } label: {
                    Label("Visit NeighborVote", systemImage: "arrow.up.right").labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.secondaryCompact)
            }
            .card()
            ForEach(model.list(.consultations)) { EntityCard(entity: $0) }
            let polls = model.list(.polls)
            if polls.isEmpty {
                HStack(spacing: 4) {
                    Text("No quick polls are open right now. Have an idea?").foregroundStyle(Color.mutedInk)
                    NavigationLink(value: Route.governance) { Text("Share it").fontWeight(.semibold).foregroundStyle(Color.brand) }
                }
                .font(.system(size: 15))
            } else {
                ForEach(polls) { EntityCard(entity: $0) }
            }
        }
    }
}
