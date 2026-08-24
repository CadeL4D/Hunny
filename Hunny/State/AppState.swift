import Foundation
import SwiftUI

/// Single source of truth: configuration, connection, weekly data, scoring and
/// every write action. The UI is a pure function of this state.
@MainActor
final class AppState: ObservableObject {
    // MARK: Configuration

    private static let serverKey = "hunny.server-url"
    private static let tokenKey = "hunny.static-token"
    private static let nameKey = "hunny.display-name"

    @Published var serverURLString: String
    @Published var token: String
    @Published var displayName: String

    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab = 0

    // MARK: Live data

    @Published private(set) var userID: String?
    @Published private(set) var players: [Player] = []
    @Published private(set) var tasks: [OwnTask] = []
    @Published private(set) var completions: [TaskCompletion] = []
    @Published private(set) var competitionTask: CompetitionTask?
    @Published private(set) var claim: CompetitionClaim?
    @Published private(set) var question: Question?
    @Published private(set) var answers: [Answer] = []
    @Published private(set) var unseenNudges: [Nudge] = []

    private var pollTask: Task<Void, Never>?

    init() {
        serverURLString = UserDefaults.standard.string(forKey: Self.serverKey) ?? "https://your-directus.example.com"
        token = Keychain.load(Self.tokenKey) ?? ""
        displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
    }

    var isConfigured: Bool {
        normalizedBaseURL != nil && !token.isEmpty && !displayName.isEmpty
    }

    var normalizedBaseURL: URL? {
        var candidate = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !candidate.hasPrefix("http://") && !candidate.hasPrefix("https://") {
            candidate = "https://" + candidate
        }
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return url
    }

    private var client: DirectusClient? {
        guard let base = normalizedBaseURL, !token.isEmpty else { return nil }
        return DirectusClient(baseURL: base, token: token)
    }

    // MARK: Derived

    var mePlayer: Player? { players.first { $0.user == userID } }
    var opponent: Player? { players.first { $0.user != userID } }

    var myCompletions: [TaskCompletion] { completions.filter { $0.user == userID } }
    var partnerCompletions: [TaskCompletion] { completions.filter { $0.user != userID } }

    var myPoints: Int {
        myCompletions.count + (claim?.user == userID ? 1 : 0)
    }

    var partnerPoints: Int {
        let partnerClaimed = claim != nil && claim?.user != userID
        return partnerCompletions.count + (partnerClaimed ? 1 : 0)
    }

    var myAnswer: Answer? { answers.first { $0.user == userID } }
    var theirAnswer: Answer? { answers.first { $0.user != userID } }

    func completionsThisWeek(for task: OwnTask) -> [TaskCompletion] {
        myCompletions.filter { $0.task == task.id }
    }

    /// Weekly tasks (1×) can be completed once per week; daily tasks can be
    /// completed once per day, up to their weekly cap.
    func canComplete(_ task: OwnTask) -> Bool {
        let mine = completionsThisWeek(for: task)
        if task.maxPerWeek <= 1 { return mine.isEmpty }
        let doneToday = mine.contains { $0.completedOn == Week.todayKey }
        return !doneToday && mine.count < task.maxPerWeek
    }

    // MARK: Connection

    func saveConfiguration(url: String, token: String, name: String) {
        serverURLString = url
        self.token = token
        displayName = name
        UserDefaults.standard.set(url, forKey: Self.serverKey)
        UserDefaults.standard.set(name, forKey: Self.nameKey)
        Keychain.save(token, for: Self.tokenKey)
    }

    func signOut() {
        Keychain.delete(Self.tokenKey)
        UserDefaults.standard.removeObject(forKey: Self.serverKey)
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        serverURLString = "https://your-directus.example.com"
        token = ""
        displayName = ""
        isReady = false
        userID = nil
        players = []
        tasks = []
        completions = []
        competitionTask = nil
        claim = nil
        question = nil
        answers = []
        unseenNudges = []
        stopPolling()
    }

    func connect() async {
        guard let client, !isReady || userID == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let me = try await client.me()
            userID = me.id
            try await upsertPlayer(named: displayName, userID: me.id)
            isReady = true
            startPolling()
            await refresh()
        } catch {
            errorMessage = "Couldn't connect: \(error.localizedDescription)"
            Haptics.warning()
        }
    }

    private func upsertPlayer(named name: String, userID uid: String) async throws {
        guard let client else { return }
        let query = [
            "filter": Filter.eq("user", uid),
            "fields": "id,user,name",
            "limit": "1",
        ]
        let existing = try await client.list(Player.self, from: "items/players", query: query)
        if var player = existing.first {
            if player.name != name {
                let updated: Player = try await client.update(
                    Player.self, "items/players/\(player.id)", body: ["name": name]
                )
                player = updated
            }
            players = [player]
        } else {
            let created: Player = try await client.create(
                Player.self, in: "items/players", body: ["user": uid, "name": name]
            )
            players = [created]
        }
    }

    // MARK: Sync

    /// Pulls everything the current week needs. Pass `quiet: true` for
    /// background polling so a dropped connection doesn't nag with alerts.
    func refresh(quiet: Bool = false) async {
        guard let client else { return }
        let week = Week.currentKey
        isLoading = true
        defer { isLoading = false }

        do {
            async let playersAsync = client.list(Player.self, from: "items/players", query: [
                "fields": "id,user,name", "sort": "id", "limit": "10",
            ])
            async let tasksAsync = client.list(OwnTask.self, from: "items/own_tasks", query: [
                "filter": Filter.eq("active", true),
                "fields": "id,title,detail,icon,max_per_week",
                "sort": "sort,id",
                "limit": "200",
            ])
            async let completionsAsync = client.list(TaskCompletion.self, from: "items/task_completions", query: [
                "filter": Filter.eq("week_start", week),
                "fields": "id,user,task,week_start,completed_on",
                "limit": "1000",
            ])
            async let competitionsAsync = client.list(CompetitionTask.self, from: "items/competition_tasks", query: [
                "filter": Filter.eq("week_start", week),
                "fields": "id,title,detail,week_start",
                "limit": "1",
            ])
            async let questionsAsync = client.list(Question.self, from: "items/questions", query: [
                "filter": Filter.eq("week_start", week),
                "fields": "id,text,week_start",
                "limit": "1",
            ])

            let (loadedPlayers, loadedTasks, loadedCompletions, loadedCompetition, loadedQuestion) =
                try await (playersAsync, tasksAsync, completionsAsync, competitionsAsync, questionsAsync)

            players = loadedPlayers
            tasks = loadedTasks
            completions = loadedCompletions
            competitionTask = loadedCompetition.first
            question = loadedQuestion.first

            if let competition = loadedCompetition.first {
                let claims = try await client.list(CompetitionClaim.self, from: "items/competition_claims", query: [
                    "filter": Filter.eq("task", competition.id),
                    "fields": "id,task,user,claimed_at",
                    "limit": "1",
                ])
                claim = claims.first
            } else {
                claim = nil
            }

            if let question = loadedQuestion.first {
                answers = try await client.list(Answer.self, from: "items/answers", query: [
                    "filter": Filter.eq("question", question.id),
                    "fields": "id,question,user,body,updated_on",
                    "limit": "10",
                ])
                if let uid = userID {
                    unseenNudges = try await client.list(Nudge.self, from: "items/nudges", query: [
                        "filter": Filter.eq("to_user", uid, nullField: "seen_on"),
                        "fields": "id,question,from_user,to_user,seen_on",
                        "sort": "-id",
                        "limit": "20",
                    ])
                }
            } else {
                answers = []
                unseenNudges = []
            }
        } catch {
            if !quiet {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Actions

    func completeTask(_ task: OwnTask) async {
        guard canComplete(task), let uid = userID, let client else { return }
        let body: [String: Any] = [
            "user": uid,
            "task": task.id,
            "week_start": Week.currentKey,
            "completed_on": Week.todayKey,
            "dedupe_key": "\(uid):\(task.id):\(Week.todayKey)",
        ]
        do {
            let completion: TaskCompletion = try await client.create(
                TaskCompletion.self, in: "items/task_completions", body: body
            )
            completions.append(completion)
            Haptics.success()
        } catch {
            handleFailure(error)
        }
    }

    func claimCompetition() async {
        guard let competition = competitionTask,
              let uid = userID,
              let client,
              claim == nil
        else { return }
        let body: [String: Any] = [
            "user": uid,
            "task": competition.id,
            "dedupe_key": "task:\(competition.id)",
        ]
        do {
            let created: CompetitionClaim = try await client.create(
                CompetitionClaim.self, in: "items/competition_claims", body: body
            )
            claim = created
            Haptics.success()
        } catch {
            handleFailure(error)
        }
    }

    func saveAnswer(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let question, let uid = userID, let client else { return }
        do {
            if let existing = myAnswer {
                let updated: Answer = try await client.update(
                    Answer.self, "items/answers/\(existing.id)", body: ["body": trimmed]
                )
                answers = answers.map { $0.id == updated.id ? updated : $0 }
            } else {
                let created: Answer = try await client.create(Answer.self, in: "items/answers", body: [
                    "user": uid,
                    "question": question.id,
                    "body": trimmed,
                    "dedupe_key": "\(question.id):\(uid)",
                ])
                answers.append(created)
            }
            Haptics.success()
        } catch {
            handleFailure(error)
        }
    }

    func sendNudge() async {
        guard let question, let uid = userID, let opponent, let client else { return }
        let body: [String: Any] = [
            "question": question.id,
            "from_user": uid,
            "to_user": opponent.user,
        ]
        do {
            _ = try await client.create(Nudge.self, in: "items/nudges", body: body)
            Haptics.tap()
        } catch {
            handleFailure(error)
        }
    }

    func acknowledgeNudges() async {
        guard let client, !unseenNudges.isEmpty else { return }
        for nudge in unseenNudges {
            _ = try? await client.update(
                Nudge.self, "items/nudges/\(nudge.id)", body: ["seen_on": ISO.now]
            )
        }
        unseenNudges = []
    }

    /// Unique-violation errors mean the database already has what we tried to
    /// write (both devices raced) — just resync rather than showing an error.
    private func handleFailure(_ error: Error) {
        if let apiError = error as? APIError, apiError.isUniqueViolation {
            Task { await refresh(quiet: true) }
        } else {
            errorMessage = error.localizedDescription
            Haptics.warning()
        }
    }

    // MARK: Polling

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            startPolling()
        default:
            stopPolling()
        }
    }

    private func startPolling() {
        guard pollTask == nil, isConfigured else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self, !Task.isCancelled else { return }
                await self.refresh(quiet: true)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
