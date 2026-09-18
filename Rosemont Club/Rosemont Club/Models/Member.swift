import Foundation

/// The signed-in neighbor's private Club profile, as returned by `/api/me`.
struct Member: Codable, Identifiable, Hashable {
    var id: String
    var email: String = ""
    var displayName: String = "Neighbor"
    var bio: String = ""
    var photoURL: String = ""
    var admin: Bool = false
    var disabled: Bool = false
    var verifiedResident: Bool = false
    var verificationDate: String?
    var verificationMethod: String?
    var reviewRequested: Bool = false
    var createdAt: String = ""

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = c.string(.email)
        displayName = c.string(.displayName, "Neighbor")
        bio = c.string(.bio)
        photoURL = c.string(.photoURL)
        admin = c.bool(.admin)
        disabled = c.bool(.disabled)
        verifiedResident = c.bool(.verifiedResident)
        verificationDate = try? c.decodeIfPresent(String.self, forKey: .verificationDate)
        verificationMethod = try? c.decodeIfPresent(String.self, forKey: .verificationMethod)
        reviewRequested = c.bool(.reviewRequested)
        createdAt = c.string(.createdAt)
    }

    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    var roleLabel: String { admin ? "Administrator" : "Member" }
}

/// `/api/activity`: the viewer's group follows and RSVPs.
struct Activity: Codable {
    struct GroupFollow: Codable, Hashable {
        var entityId: String
        var status: String
    }
    struct EventRSVP: Codable, Hashable {
        var entityId: String
        var date: String
        var attending: Bool
    }
    var groups: [GroupFollow] = []
    var events: [EventRSVP] = []
}

struct MembershipRow: Codable, Identifiable, Hashable {
    var userId: String
    var status: String
    var displayName: String
    var id: String { userId }
}

struct PollResults: Codable {
    var hidden: Bool?
    var counts: [Int]?
    var total: Int?
    var selected: Int?
}

struct ServerMessage: Codable {
    var message: String?
    var ok: Bool?
    var status: String?
    var attending: Bool?
    var verifiedResident: Bool?
    var matched: Bool?
}
