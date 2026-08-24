import Foundation

// Codable models mirroring the Directus collections in docs/DIRECTUS_SETUP.md.
// There are no Directus user accounts: players are identified by the exact
// (case-sensitive) name strings typed on each device, and all name matching
// happens in the app. Week keys are "yyyy-MM-dd" strings for the Monday that
// starts the week.

struct Player: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
}

struct OwnTask: Codable, Identifiable, Hashable {
    let id: Int
    var title: String
    var detail: String?
    var icon: String?
    var maxPerWeek: Int
    // Only the hidden task editor fetches these; the regular list query
    // leaves them out and they decode as nil.
    var sort: Int?
    var active: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, detail, icon, sort, active
        case maxPerWeek = "max_per_week"
    }
}

struct TaskCompletion: Codable, Identifiable, Hashable {
    let id: Int
    let player: String
    let task: Int
    var weekStart: String
    var completedOn: String

    enum CodingKeys: String, CodingKey {
        case id, player, task
        case weekStart = "week_start"
        case completedOn = "completed_on"
    }
}

struct CompetitionTask: Codable, Identifiable, Hashable {
    let id: Int
    var title: String
    var detail: String?
    var weekStart: String

    enum CodingKeys: String, CodingKey {
        case id, title, detail
        case weekStart = "week_start"
    }
}

struct CompetitionClaim: Codable, Identifiable, Hashable {
    let id: Int
    let task: Int
    let player: String
    var claimedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, task, player
        case claimedAt = "claimed_at"
    }
}

struct Question: Codable, Identifiable, Hashable {
    let id: Int
    var text: String
    var weekStart: String

    enum CodingKeys: String, CodingKey {
        case id, text
        case weekStart = "week_start"
    }
}

struct Answer: Codable, Identifiable, Hashable {
    let id: Int
    let question: Int
    let player: String
    var body: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, question, player, body
        case updatedAt = "updated_on"
    }
}

struct Nudge: Codable, Identifiable, Hashable {
    let id: Int
    let question: Int
    let fromPlayer: String
    let toPlayer: String
    var seenOn: Date?

    enum CodingKeys: String, CodingKey {
        case id, question
        case fromPlayer = "from_player"
        case toPlayer = "to_player"
        case seenOn = "seen_on"
    }
}
