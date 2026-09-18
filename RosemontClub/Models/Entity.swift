import Foundation

/// Directory kinds served by `/api/entities`. Mirrors `lib/schema.ts` on the website.
enum Kind: String, Codable, CaseIterable, Hashable {
    case groups, events, resources, polls, content, tags, consultations

    var label: String {
        switch self {
        case .groups: "Groups"
        case .events: "Events"
        case .resources: "Resources"
        case .polls: "Quick polls"
        case .consultations: "Community questions"
        case .content: "Site content"
        case .tags: "Tags"
        }
    }

    var singular: String {
        switch self {
        case .groups: "group"
        case .events: "event"
        case .resources: "resource"
        case .polls: "poll"
        case .consultations: "consultation"
        case .content: "section"
        case .tags: "tag"
        }
    }

    var systemImage: String {
        switch self {
        case .events: "calendar"
        case .groups: "person.2"
        case .resources: "safari"
        default: "bubble.left.and.bubble.right"
        }
    }
}

enum Visibility: String, Codable, Hashable {
    case `public`, members, residents

    var audienceLabel: String {
        switch self {
        case .residents: "Verified residents"
        case .members: "Club members"
        case .public: "Everyone welcome"
        }
    }
}

enum EntityStatus: String, Codable, Hashable {
    case active, draft, archived, cancelled
}

struct Channel: Codable, Hashable {
    var type: String = "Other"
    var label: String = ""
    var url: String = ""
    var email: String = ""
    var instructions: String = ""
    var visibility: Visibility = .residents

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.string(.type, "Other")
        label = c.string(.label)
        url = c.string(.url)
        email = c.string(.email)
        instructions = c.string(.instructions)
        visibility = c.decodeEnum(.visibility, .residents)
    }
}

struct Recurrence: Codable, Hashable {
    var frequency: String = "none"
    var interval: Int = 1
    var weekday: Int = 2
    var nth: Int = 2
    var months: [Int] = []
    var until: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frequency = c.string(.frequency, "none")
        interval = c.int(.interval, 1)
        weekday = c.int(.weekday, 2)
        nth = c.int(.nth, 2)
        months = (try? c.decode([Int].self, forKey: .months)) ?? []
        until = c.string(.until)
    }

    /// Human description used on the event page ("Second Wednesday of the month").
    var summary: String {
        switch frequency {
        case "nth-weekday":
            let ordinals = ["First", "Second", "Third", "Fourth", "Fifth"]
            let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let ordinal = ordinals[max(0, min(4, nth - 1))]
            let day = days[max(0, min(6, weekday))]
            return "\(ordinal) \(day) of the month"
        case "weekly":
            return interval == 1 ? "Every week" : "Every \(interval) weeks"
        case "monthly":
            return interval == 1 ? "Every month" : "Every \(interval) months"
        default:
            return "One-time gathering"
        }
    }

    var monthsSummary: String? {
        guard !months.isEmpty else { return nil }
        let symbols = Calendar.current.shortMonthSymbols
        return months.compactMap { m in (1...12).contains(m) ? symbols[m - 1] : nil }.joined(separator: " · ")
    }
}

struct DateOverride: Codable, Hashable {
    var date: String = ""
    var cancelled: Bool = false
    var location: String = ""
    var sponsor: String = ""

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.string(.date)
        cancelled = c.bool(.cancelled)
        location = c.string(.location)
        sponsor = c.string(.sponsor)
    }
}

/// A directory record. Locked records (audience the viewer cannot see) only carry
/// id, name, slug, kind and visibility, so every other field has a default.
struct Entity: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var slug: String
    var kind: Kind
    var visibility: Visibility
    var locked: Bool = false
    var summary: String = ""
    var description: String = ""
    var status: EntityStatus = .active
    var ownerIds: [String] = []
    var featured: Bool = false
    var audienceTags: [String] = []
    var topicTags: [String] = []
    var website: String = ""
    var contactEmail: String = ""
    var image: String = ""
    var imageAlt: String = ""
    var membership: String = "open"
    var scope: String = "Rosemont"
    var joinInstructions: String = ""
    var channels: [Channel] = []
    var groupId: String = ""
    var relatedGroups: [String] = []
    var relatedEvents: [String] = []
    var relatedResources: [String] = []
    var start: String = ""
    var end: String = ""
    var timezone: String = "America/New_York"
    var location: String = ""
    var streetAddress: String = ""
    var mapUrl: String = ""
    var sponsor: String = ""
    var notes: String = ""
    var capacity: Int = 0
    var rsvp: Bool = false
    var recurrence = Recurrence()
    var overrides: [DateOverride] = []
    var options: [String] = []
    var opens: String = ""
    var closes: String = ""
    var resultsVisibility: String = "after-vote"
    var createdAt: String = ""
    var updatedAt: String = ""
    /// Server-computed upcoming occurrences, present only on `/api/entities/{id}`.
    var upcoming: [String]? = nil

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = c.string(.name)
        slug = c.string(.slug)
        kind = try c.decode(Kind.self, forKey: .kind)
        visibility = c.decodeEnum(.visibility, .public)
        locked = c.bool(.locked)
        summary = c.string(.summary)
        description = c.string(.description)
        status = c.decodeEnum(.status, .active)
        ownerIds = c.strings(.ownerIds)
        featured = c.bool(.featured)
        audienceTags = c.strings(.audienceTags)
        topicTags = c.strings(.topicTags)
        website = c.string(.website)
        contactEmail = c.string(.contactEmail)
        image = c.string(.image)
        imageAlt = c.string(.imageAlt)
        membership = c.string(.membership, "open")
        scope = c.string(.scope, "Rosemont")
        joinInstructions = c.string(.joinInstructions)
        channels = (try? c.decode([Channel].self, forKey: .channels)) ?? []
        groupId = c.string(.groupId)
        relatedGroups = c.strings(.relatedGroups)
        relatedEvents = c.strings(.relatedEvents)
        relatedResources = c.strings(.relatedResources)
        start = c.string(.start)
        end = c.string(.end)
        timezone = c.string(.timezone, "America/New_York")
        location = c.string(.location)
        streetAddress = c.string(.streetAddress)
        mapUrl = c.string(.mapUrl)
        sponsor = c.string(.sponsor)
        notes = c.string(.notes)
        capacity = c.int(.capacity, 0)
        rsvp = c.bool(.rsvp)
        recurrence = (try? c.decode(Recurrence.self, forKey: .recurrence)) ?? Recurrence()
        overrides = (try? c.decode([DateOverride].self, forKey: .overrides)) ?? []
        options = c.strings(.options)
        opens = c.string(.opens)
        closes = c.string(.closes)
        resultsVisibility = c.string(.resultsVisibility, "after-vote")
        createdAt = c.string(.createdAt)
        updatedAt = c.string(.updatedAt)
        upcoming = try? c.decodeIfPresent([String].self, forKey: .upcoming)
    }

    static func == (lhs: Entity, rhs: Entity) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt && lhs.locked == rhs.locked
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(updatedAt)
        hasher.combine(locked)
    }

    /// Records the website lists in directories: active or cancelled, never drafts/archived.
    var isListed: Bool { status == .active || status == .cancelled }

    var audienceLabel: String { visibility.audienceLabel }

    var cardTag: String {
        if locked { return visibility.audienceLabel }
        switch kind {
        case .groups: return "Neighborhood group"
        case .events: return status == .cancelled ? "Cancelled" : "Gather together"
        case .resources: return topicTags.first ?? "Local resource"
        case .polls: return "Quick poll"
        case .consultations: return "Community question"
        default: return kind.label
        }
    }

    func canManage(_ user: Member?) -> Bool {
        guard let user, !user.disabled else { return false }
        return user.admin || ownerIds.contains(user.id)
    }

    var pollIsOpen: Bool {
        guard status == .active else { return false }
        let now = Date()
        if let o = ISO8601.parse(opens), o > now { return false }
        if let c = ISO8601.parse(closes), c < now { return false }
        return true
    }
}

enum ISO8601 {
    private static let full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let local: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()

    static func parse(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        return full.date(from: s) ?? plain.date(from: s) ?? local.date(from: s)
    }
}

extension KeyedDecodingContainer {
    func string(_ key: Key, _ fallback: String = "") -> String {
        (try? decodeIfPresent(String.self, forKey: key)) ?? fallback
    }
    func int(_ key: Key, _ fallback: Int) -> Int {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return fallback
    }
    func bool(_ key: Key) -> Bool {
        (try? decodeIfPresent(Bool.self, forKey: key)) ?? false
    }
    func strings(_ key: Key) -> [String] {
        (try? decodeIfPresent([String].self, forKey: key)) ?? []
    }
    func decodeEnum<T: RawRepresentable>(_ key: Key, _ fallback: T) -> T where T.RawValue == String {
        guard let raw = try? decodeIfPresent(String.self, forKey: key) else { return fallback }
        return T(rawValue: raw) ?? fallback
    }
}
