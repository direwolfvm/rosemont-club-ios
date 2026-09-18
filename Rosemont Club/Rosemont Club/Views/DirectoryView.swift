import SwiftUI

/// Groups, events, or resources list with search and (for resources) the finder.
struct DirectoryView: View {
    @Environment(AppModel.self) private var model
    var kind: Kind
    @State private var query = ""
    @State private var who = ""
    @State private var need = ""
    @State private var calendarFile: URL?
    @State private var showShare = false

    private var items: [Entity] {
        let base = model.list(kind)
        switch kind {
        case .resources:
            return ResourceFinder.filter(base, who: who, need: need, query: query)
        case .events:
            let q = query.lowercased()
            return base
                .filter { q.isEmpty || matches($0, q) }
                .map { ($0, Occurrences.upcoming(for: $0, count: 1).first ?? "9999") }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
        default:
            let q = query.lowercased()
            return base.filter { q.isEmpty || matches($0, q) }
        }
    }

    private func matches(_ e: Entity, _ q: String) -> Bool {
        [e.name, e.locked ? "" : e.summary, e.locked ? "" : e.description].joined(separator: " ").lowercased().contains(q)
    }

    private var heading: (eyebrow: String, text: String) {
        switch kind {
        case .groups: ("Your neighborhood, at a glance", "Find your people. Connect in the places and conversations you already use.")
        case .events: ("Your neighborhood, at a glance", "Make a little time for your neighborhood. Everyone is welcome.")
        default: ("Your neighborhood, at a glance", "A little local knowledge, all in one place.")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeading(eyebrow: heading.eyebrow, title: kind.label, text: heading.text)
                if kind == .resources { ResourceFinder(who: $who, need: $need) }
                if kind == .events {
                    Button {
                        Task { await downloadCalendar() }
                    } label: {
                        Label("Download calendar (.ics)", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.secondaryCompact)
                }
                Text(model.loading ? "Loading…" : "\(items.count) \(items.count == 1 ? kind.singular : kind.label.lowercased())")
                    .font(.footnote)
                    .foregroundStyle(Color.mutedInk)
                if let error = model.loadError, items.isEmpty {
                    NoticeText(text: error, error: true)
                    Button("Try again") { Task { await model.refresh() } }.buttonStyle(.secondaryCompact)
                }
                LazyVStack(spacing: 12) {
                    ForEach(items) { EntityCard(entity: $0) }
                }
                if items.isEmpty && !model.loading && model.loadError == nil {
                    EmptyState(systemName: "magnifyingglass", title: "No matches just yet.", text: "Try a different search or suggest something for the directory.")
                    Button("Clear filters") { query = ""; who = ""; need = "" }.buttonStyle(.secondary)
                }
            }
            .pageGutter()
            .padding(.vertical, 12)
        }
        .background(Color.paper)
        .searchable(text: $query, prompt: "Search \(kind.label.lowercased())")
        .refreshable { await model.refresh() }
        .navigationTitle(kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let calendarFile { ShareSheet(items: [calendarFile]) }
        }
        .clubDestinations()
    }

    private func downloadCalendar() async {
        await model.perform {
            let data = try await model.api.raw("calendar")
            let url = FileManager.default.temporaryDirectory.appending(path: "rosemont-club.ics")
            try data.write(to: url, options: .atomic)
            calendarFile = url
            showShare = true
        }
    }
}
