import Foundation

// Codable models mirroring the Directus collections in docs/DIRECTUS_SETUP.md.
// Week keys are "yyyy-MM-dd" strings for the Monday that starts the week.

struct DirectusUser: Codable {
    let id: String
    var firstName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
    }
}

struct Player: Codable, Identifiable, Hashable {
    let id: Int
    let user: String
    var name: String
}

struct OwnTask: Codable, Identifiable, Hashable {
    let id: Int
    var title: String
    var detail: String?
    var icon: String?
    var maxPerWeek: Int

    enum CodingKeys: String, CodingKey {
        case id, title, detail, icon
        case maxPerWeek = "max_per_week"
    }
}

struct TaskCompletion: Codable, Identifiable, Hashable {
    let id: Int
    let user: String
    let task: Int
    var weekStart: String
    var completedOn: String

    enum CodingKeys: String, CodingKey {
        case id, user, task
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
    let user: String
    var claimedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, task, user
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
    let user: String
    var body: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, question, user, body
        case updatedAt = "updated_on"
    }
}

struct Nudge: Codable, Identifiable, Hashable {
    let id: Int
    let question: Int
    let fromUser: String
    let toUser: String
    var seenOn: Date?

    enum CodingKeys: String, CodingKey {
        case id, question
        case fromUser = "from_user"
        case toUser = "to_user"
        case seenOn = "seen_on"
    }
}
