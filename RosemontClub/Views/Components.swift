import SwiftUI
import UIKit
import EventKit
import EventKitUI

/// In-app navigation targets beyond entity detail pages.
enum Route: Hashable {
    case about
    case governance
    case profile
    case directory(Kind)
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color.brand)
    }
}

struct SectionHeading<Trailing: View>: View {
    var eyebrow: String?
    var title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, eyebrow: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.eyebrow = eyebrow
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow { Eyebrow(text: eyebrow) }
                Text(title).font(.sectionTitle).foregroundStyle(Color.ink)
            }
            Spacer()
            trailing.font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.brand)
        }
    }
}

struct PageHeading: View {
    var eyebrow: String
    var title: String
    var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: eyebrow)
            Text(title).font(.pageTitle).foregroundStyle(Color.ink)
            Text(text).font(.body).foregroundStyle(Color.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SmallTag: View {
    var text: String
    var locked = false
    var body: some View {
        HStack(spacing: 4) {
            if locked { Image(systemName: "lock.fill").font(.system(size: 9)) }
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.brand)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.mist, in: Capsule())
    }
}

struct TileIcon: View {
    var systemName: String
    var size: CGFloat = 38
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(Color.brand)
            .frame(width: size, height: size)
            .background(Color.mist, in: RoundedRectangle(cornerRadius: 9))
    }
}

/// A directory card, matching the website's `content-card`.
struct EntityCard: View {
    var entity: Entity

    var body: some View {
        NavigationLink(value: entity) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TileIcon(systemName: entity.kind.systemImage)
                    SmallTag(text: entity.cardTag, locked: entity.locked)
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(Color.mutedInk).font(.system(size: 14, weight: .semibold))
                }
                if entity.kind == .events, !entity.locked, let date = Occurrences.upcoming(for: entity, count: 1).first {
                    HStack(spacing: 6) {
                        Text(Occurrences.shortDate(date)).fontWeight(.semibold)
                        Text(Occurrences.time(date)).foregroundStyle(Color.mutedInk)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clay)
                }
                Text(entity.name).font(.cardTitle).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                Text(entity.locked ? "Details available to \(entity.audienceLabel.lowercased())." : entity.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.mutedInk)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    if entity.kind == .events, !entity.locked {
                        Image(systemName: "mappin").font(.system(size: 12))
                        Text(entity.location).lineLimit(1)
                    } else {
                        Text(entity.kind == .groups ? "Find your people" : "Take a look")
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brand)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

struct ListLinkRow: View {
    var title: String
    var detail: String?
    var body: some View {
        HStack {
            Text(title).foregroundStyle(Color.ink).fontWeight(.medium)
            Spacer()
            if let detail { Text(detail).font(.footnote).foregroundStyle(Color.mutedInk) }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.mutedInk)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct EmptyState: View {
    var systemName: String
    var title: String
    var text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName).font(.system(size: 30)).foregroundStyle(Color.brand)
            Text(title).font(.sectionTitle).foregroundStyle(Color.ink)
            Text(text).multilineTextAlignment(.center).foregroundStyle(Color.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

/// Splits description text on blank lines, like the website's `Paragraphs`.
struct Paragraphs: View {
    var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, p in
                Text(p).font(.system(size: 16)).lineSpacing(4).foregroundStyle(Color.ink)
            }
        }
    }
}

struct LabeledField<Content: View>: View {
    var label: String
    var hint: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink)
            content
            if let hint { Text(hint).font(.footnote).foregroundStyle(Color.mutedInk) }
        }
    }
}

struct NoticeText: View {
    var text: String
    var error = false
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(error ? Color.clay : Color.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((error ? Color.clay : Color.brand).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BrandMark: View {
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.brandFill, in: RoundedRectangle(cornerRadius: size * 0.28))
    }
}

/// Bottom banner for transient notices from `AppModel.notify`.
struct NoticeBanner: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ink, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}

// MARK: - UIKit bridges

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Native "Add to Calendar" using the system event editor (no calendar permission needed for the editor UI).
struct EventEditor: UIViewControllerRepresentable {
    var entity: Entity
    var start: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let vc = EKEventEditViewController()
        vc.eventStore = store
        vc.editViewDelegate = context.coordinator
        let event = EKEvent(eventStore: store)
        event.title = entity.name
        event.timeZone = Occurrences.zone
        if let s = Occurrences.date(from: start) {
            event.startDate = s
            let duration: TimeInterval = {
                guard let a = Occurrences.date(from: entity.start), let b = Occurrences.date(from: entity.end) else { return 3600 }
                return max(900, b.timeIntervalSince(a))
            }()
            event.endDate = s.addingTimeInterval(duration)
        }
        let override = entity.overrides.first { $0.date == String(start.prefix(10)) }
        let place = [override?.location.isEmpty == false ? override!.location : entity.location, entity.streetAddress].filter { !$0.isEmpty }
        event.location = place.joined(separator: ", ")
        event.notes = entity.description
        if let url = URL(string: "https://rosemont.club/events/\(entity.slug)") { event.url = url }
        vc.event = event
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

/// Outline of the community-provided residency boundary, drawn from the bundled GeoJSON.
struct BoundaryMap: View {
    private static let rings: [[CGPoint]] = {
        guard let url = Bundle.main.url(forResource: "rosemont-boundary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else { return [] }
        var rings: [[CGPoint]] = []
        for f in features {
            guard let g = f["geometry"] as? [String: Any], let type = g["type"] as? String else { continue }
            let polys: [[[[Double]]]]
            if type == "MultiPolygon", let c = g["coordinates"] as? [[[[Double]]]] { polys = c }
            else if type == "Polygon", let c = g["coordinates"] as? [[[Double]]] { polys = [c] }
            else { continue }
            for poly in polys { for ring in poly { rings.append(ring.map { CGPoint(x: $0[0], y: $0[1]) }) } }
        }
        return rings
    }()

    var body: some View {
        GeometryReader { geo in
            let pts = Self.rings.flatMap { $0 }
            let minX = pts.map(\.x).min() ?? 0, maxX = pts.map(\.x).max() ?? 1
            let minY = pts.map(\.y).min() ?? 0, maxY = pts.map(\.y).max() ?? 1
            let cosLat = cos((minY + maxY) / 2 * .pi / 180)
            let w = (maxX - minX) * cosLat, h = maxY - minY
            let inset: CGFloat = 20
            let scale = min((geo.size.width - inset * 2) / max(w, 0.0001), (geo.size.height - inset * 2) / max(h, 0.0001))
            let ox = (geo.size.width - w * scale) / 2, oy = (geo.size.height - h * scale) / 2
            let path = Path { p in
                for ring in Self.rings {
                    guard let first = ring.first else { continue }
                    func map(_ c: CGPoint) -> CGPoint {
                        CGPoint(x: ox + (c.x - minX) * cosLat * scale, y: oy + (maxY - c.y) * scale)
                    }
                    p.move(to: map(first))
                    for c in ring.dropFirst() { p.addLine(to: map(c)) }
                    p.closeSubpath()
                }
            }
            ZStack {
                Color.mist
                path.fill(Color.brand.opacity(0.25))
                path.stroke(Color.brand, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                Image(systemName: "leaf.fill").foregroundStyle(Color.brand).font(.system(size: 22))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line))
        .accessibilityLabel("Outline of the Rosemont Club neighborhood boundary supplied by the community")
    }
}

/// The homepage's map carousel: today's map and three historic ones.
struct HistoryCarousel: View {
    private let slides: [(image: String, title: String, caption: String)] = [
        ("history-rosemont-map", "The streets we call home", "Rosemont today, with Russell Road, Commonwealth Avenue, and nearby Metro stations."),
        ("history-rosemont-1911", "Rosemont on the map", "A 1911 map labeling Rosemont and the electric railway to Washington."),
        ("history-sanborn-1921", "A neighborhood taking shape", "Sanborn fire insurance map, 1921, with homes and streets marked."),
        ("history-assessment-1963", "Familiar blocks, another era", "Alexandria assessment map 201, 1963."),
    ]
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TabView(selection: $index) {
                ForEach(Array(slides.enumerated()), id: \.offset) { i, slide in
                    Image(slide.image)
                        .resizable()
                        .scaledToFill()
                        .overlay(Color.brand.opacity(0.28).blendMode(.multiply))
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .tag(i)
                        .accessibilityLabel(slide.caption)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line))
            VStack(alignment: .leading, spacing: 2) {
                Text(slides[index].title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink)
                Text(slides[index].caption).font(.footnote).foregroundStyle(Color.mutedInk)
            }
            .animation(.default, value: index)
        }
    }
}
