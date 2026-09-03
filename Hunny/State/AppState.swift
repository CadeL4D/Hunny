import Foundation
import SwiftUI

/// Single source of truth: configuration, connection, weekly data, scoring and
/// every write action. The UI is a pure function of this state.
///
/// There is no login. Each device is identified purely by the two names typed
/// at setup ("your name" and "their name"), which must match across devices
/// exactly — the app compares them case-sensitively, client-side. All API
/// traffic uses the server address and token compiled into the build.
@MainActor
final class AppState: ObservableObject {
    // MARK: Configuration

    private static let myNameKey = "hunny.my-name"
    private static let partnerNameKey = "hunny.partner-name"

    @Published var myName: String
    @Published var partnerName: String

    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab = 0

    // MARK: Live data

    @Published private(set) var players: [Player] = []
    @Published private(set) var tasks: [OwnTask] = []
    @Published private(set) var completions: [TaskCompletion] = []
    @Published private(set) var competitionTask: CompetitionTask?
    @Published private(set) var claim: CompetitionClaim?
    /// Monthly race data: everything earned in the last `Month.historyDepth`
    /// months — the current race plus the history sheet. `completions` above
    /// stays week-scoped.
    @Published private(set) var historyCompletions: [TaskCompletion] = []
    @Published private(set) var historyClaims: [CompetitionClaim] = []
    @Published private(set) var question: Question?
    @Published private(set) var answers: [Answer] = []
    @Published private(set) var unseenNudges: [Nudge] = []

    /// Every task, retired ones included — data for the hidden task editor.
    /// `tasks` above stays active-only for the regular UI.
    @Published private(set) var allTasks: [OwnTask] = []

    private var pollTask: Task<Void, Never>?
    /// Nudges we've already fired a local notification for — stops the 20s
    /// poll from re-alerting on the same unseen nudge all week.
    private var nudgeAlertIDs = Set<Int>()

    init() {
        let defaults = UserDefaults.standard
        myName = defaults.string(forKey: Self.myNameKey) ?? ""
        partnerName = defaults.string(forKey: Self.partnerNameKey) ?? ""
        DiagnosticLog.shared.record(
            "launch · me=\(myName.isEmpty ? "—" : myName) partner=\(partnerName.isEmpty ? "—" : partnerName) server=\(normalizedBaseURL?.absoluteString ?? "none")"
        )
    }

    /// The server is fixed at build time — injected from the DIRECTUS_URL and
    /// DIRECTUS_TOKEN secrets. Nothing server-related is user-editable.
    private var serverURLString: String {
        ServerConfig.defaultBaseURLString ?? ""
    }

    private var effectiveToken: String {
        ServerConfig.defaultToken ?? ""
    }

    var isConfigured: Bool {
        normalizedBaseURL != nil
            && !effectiveToken.isEmpty
            && !myName.isEmpty
            && !partnerName.isEmpty
            && myName != partnerName
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
        guard let base = normalizedBaseURL, !effectiveToken.isEmpty else { return nil }
        return DirectusClient(baseURL: base, token: effectiveToken)
    }

    // MARK: Derived

    /// True once the partner device has connected at least once with the
    /// exact same name we typed for them.
    var partnerHasJoined: Bool {
        players.contains { $0.name == partnerName }
    }

    var myCompletions: [TaskCompletion] { completions.filter { $0.player == myName } }
    var partnerCompletions: [TaskCompletion] { completions.filter { $0.player == partnerName } }

    var myPoints: Int {
        myCompletions.count + (claim?.player == myName ? 1 : 0)
    }

    var partnerPoints: Int {
        let partnerClaimed = claim != nil && claim?.player == partnerName
        return partnerCompletions.count + (partnerClaimed ? 1 : 0)
    }

    /// Points each player earned in the given "yyyy-MM" month — completions
    /// by the day they were done plus head-to-head claims. Only the two known
    /// names count, same as the weekly columns.
    func monthScores(_ monthKey: String) -> (mine: Int, theirs: Int) {
        let monthCompletions = historyCompletions.filter { Month.contains($0.completedOn, monthKey) }
        let monthClaims = historyClaims.compactMap(\.claimedAt).filter { Month.contains($0, monthKey) }
        let mine = monthCompletions.filter { $0.player == myName }.count
            + monthClaims.filter { $0.player == myName }.count
        let theirs = monthCompletions.filter { $0.player == partnerName }.count
            + monthClaims.filter { $0.player == partnerName }.count
        return (mine, theirs)
    }

    var myMonthPoints: Int { monthScores(Month.key).mine }

    var partnerMonthPoints: Int { monthScores(Month.key).theirs }

    var myAnswer: Answer? { answers.first { $0.player == myName } }
    var theirAnswer: Answer? { answers.first { $0.player == partnerName } }

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

    func saveNames(myName: String, partnerName: String) {
        self.myName = myName
        self.partnerName = partnerName
        UserDefaults.standard.set(myName, forKey: Self.myNameKey)
        UserDefaults.standard.set(partnerName, forKey: Self.partnerNameKey)
    }

    func signOut() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.myNameKey)
        defaults.removeObject(forKey: Self.partnerNameKey)
        myName = ""
        partnerName = ""
        isReady = false
        players = []
        tasks = []
        allTasks = []
        completions = []
        historyCompletions = []
        historyClaims = []
        competitionTask = nil
        claim = nil
        question = nil
        answers = []
        unseenNudges = []
        nudgeAlertIDs.removeAll()
        Notifications.cancelAll()
        stopPolling()
    }

    func connect() async {
        guard isConfigured else { return }
        guard let client else {
            errorMessage = "This build has no server configured. Install an official build from the GitHub Releases page."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            do {
                // Register this name so the other device can see we've joined.
                _ = try await client.create(Player.self, in: "items/players", body: ["name": myName])
            } catch let error as APIError where error.isUniqueViolation {
                // Already registered from an earlier run — fine.
            }
            isReady = true
            startPolling()
            await Notifications.requestAuthorizationIfNeeded()
            Notifications.reschedule(hasUnseenNudges: false, nudgerName: nil)
            await refresh()
        } catch {
            errorMessage = "Couldn't connect: \(error.localizedDescription)"
            Haptics.warning()
        }
    }

    // MARK: Sync

    /// Pulls everything the current week, the monthly race and its history
    /// need. Name-based filtering happens here, in Swift, so it's always
    /// exactly case-sensitive. Pass `quiet: true` for background polling so a
    /// dropped connection doesn't nag with alerts.
    func refresh(quiet: Bool = false) async {
        guard let client else { return }
        let week = Week.currentKey
        isLoading = true
        defer { isLoading = false }

        do {
            // Weeks from the Monday the earliest history month starts in
            // until now — the monthly race and its history need every week
            // that can hold a "completed_on" date in the last
            // Month.historyDepth months. The weekly view is derived from the
            // same rows below.
            let historyStart = Month.start(monthsAgo: Month.historyDepth - 1)
            let historyWindow: [String: Any] = ["_and": [
                ["week_start": ["_gte": Month.firstMondayKey(for: historyStart)]],
                ["week_start": ["_lte": week]],
            ]]
            async let playersAsync = client.list(Player.self, from: "items/players", query: [
                "fields": "id,name", "sort": "id", "limit": "10",
            ])
            async let tasksAsync = client.list(OwnTask.self, from: "items/own_tasks", query: [
                "filter": Filter.eq("active", true),
                "fields": "id,title,detail,icon,max_per_week",
                "sort": "sort,id",
                "limit": "200",
            ])
            async let completionsAsync = client.list(TaskCompletion.self, from: "items/task_completions", query: [
                "filter": Filter.json(historyWindow),
                "fields": "id,player,task,week_start,completed_on",
                "limit": "2000",
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
            async let historyClaimsAsync = client.list(CompetitionClaim.self, from: "items/competition_claims", query: [
                "filter": Filter.json(["claimed_at": ["_gte": ISO.stamp(historyStart)]]),
                "fields": "id,task,player,claimed_at",
                "sort": "id",
                "limit": "100",
            ])

            let (loadedPlayers, loadedTasks, loadedCompletions, loadedCompetition, loadedQuestion, loadedHistoryClaims) =
                try await (playersAsync, tasksAsync, completionsAsync, competitionsAsync, questionsAsync, historyClaimsAsync)

            players = loadedPlayers
            tasks = loadedTasks
            completions = loadedCompletions.filter { $0.weekStart == week }
            historyCompletions = loadedCompletions
            competitionTask = loadedCompetition.first
            question = loadedQuestion.first
            historyClaims = loadedHistoryClaims

            if let competition = loadedCompetition.first {
                let claims = try await client.list(CompetitionClaim.self, from: "items/competition_claims", query: [
                    "filter": Filter.eq("task", competition.id),
                    "fields": "id,task,player,claimed_at",
                    "limit": "1",
                ])
                claim = claims.first
            } else {
                claim = nil
                await carryForwardCompetition()
            }

            if let question = loadedQuestion.first {
                answers = try await client.list(Answer.self, from: "items/answers", query: [
                    "filter": Filter.eq("questions", question.id),
                    "fields": "id,questions,player,body,updated_on",
                    "limit": "10",
                ])
                if !myName.isEmpty {
                    let nudges = try await client.list(Nudge.self, from: "items/nudges", query: [
                        "filter": Filter.eq("questions", question.id),
                        "fields": "id,questions,from_player,to_player,seen_on",
                        "sort": "-id",
                        "limit": "50",
                    ])
                    unseenNudges = nudges.filter { $0.toPlayer == myName && $0.seenOn == nil }
                    let fresh = unseenNudges.filter { !nudgeAlertIDs.contains($0.id) }
                    if !fresh.isEmpty {
                        nudgeAlertIDs.formUnion(fresh.map(\.id))
                        Notifications.nudgeAlert(from: fresh.first?.fromPlayer)
                    }
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

    // MARK: Task administration
    // Hidden editor, opened by tapping your profile avatar five times.

    func loadAllTasks() async throws {
        guard let client else { return }
        allTasks = try await client.list(OwnTask.self, from: "items/own_tasks", query: [
            "fields": "id,title,detail,icon,max_per_week,sort,active",
            "sort": "sort,id",
            "limit": "200",
        ])
    }

    func createTask(title: String, detail: String, icon: String, maxPerWeek: Int) async throws {
        guard let client else {
            throw APIError(status: -1, message: "No server connection")
        }
        var body: [String: Any] = [
            "title": title,
            "max_per_week": max(1, maxPerWeek),
            "sort": (allTasks.compactMap(\.sort).max() ?? 0) + 1,
            // The collection defaults active to false — send it explicitly.
            "active": true,
        ]
        if !detail.isEmpty { body["detail"] = detail }
        if !icon.isEmpty { body["icon"] = icon }
        _ = try await client.create(OwnTask.self, in: "items/own_tasks", body: body)
        await reloadAfterTaskChange()
    }

    func updateTask(_ task: OwnTask, body: [String: Any]) async throws {
        guard let client else {
            throw APIError(status: -1, message: "No server connection")
        }
        _ = try await client.update(OwnTask.self, "items/own_tasks/\(task.id)", body: body)
        await reloadAfterTaskChange()
    }

    private func reloadAfterTaskChange() async {
        try? await loadAllTasks()
        await refresh(quiet: true)
    }

    /// Create or edit this week's head-to-head. Each week gets its own row
    /// (claims hang off the row), but edits persist into future weeks via
    /// `carryForwardCompetition()`.
    func saveCompetition(title: String, detail: String) async throws {
        guard let client else {
            throw APIError(status: -1, message: "No server connection")
        }
        var body: [String: Any] = [
            "title": title,
            "detail": detail.isEmpty ? NSNull() : detail,
        ]
        if let existing = competitionTask {
            _ = try await client.update(
                CompetitionTask.self, "items/competition_tasks/\(existing.id)", body: body
            )
        } else {
            body["week_start"] = Week.currentKey
            _ = try await client.create(CompetitionTask.self, in: "items/competition_tasks", body: body)
        }
        await refresh(quiet: true)
    }

    /// Keeps the head-to-head going without anyone re-adding it each week: if
    /// this week has no row yet, copy the most recent one forward. A unique
    /// violation just means the partner's device won the race — the next
    /// refresh picks up its row. Best-effort; never blocks a refresh.
    private func carryForwardCompetition() async {
        guard let client else { return }
        do {
            let previous = try await client.list(CompetitionTask.self, from: "items/competition_tasks", query: [
                "filter": Filter.json(["week_start": ["_lte": Week.currentKey]]),
                "fields": "id,title,detail,week_start",
                "sort": "-week_start",
                "limit": "1",
            ])
            guard let latest = previous.first, latest.weekStart != Week.currentKey else { return }
            var body: [String: Any] = [
                "title": latest.title,
                "week_start": Week.currentKey,
            ]
            if let detail = latest.detail { body["detail"] = detail }
            competitionTask = try await client.create(
                CompetitionTask.self, in: "items/competition_tasks", body: body
            )
        } catch let error as APIError where error.isUniqueViolation {
            // Partner device copied it first.
        } catch {
            DiagnosticLog.shared.record("carry-forward skipped: \(error.localizedDescription)")
        }
    }

    // MARK: Actions

    func completeTask(_ task: OwnTask) async {
        guard canComplete(task), let client else { return }
        let body: [String: Any] = [
            "player": myName,
            "task": task.id,
            "week_start": Week.currentKey,
            "completed_on": Week.todayKey,
            "dedupe_key": "\(myName):\(task.id):\(Week.todayKey)",
        ]
        do {
            let completion: TaskCompletion = try await client.create(
                TaskCompletion.self, in: "items/task_completions", body: body
            )
            completions.append(completion)
            // Today is definitionally inside the history window.
            historyCompletions.append(completion)
            Haptics.success()
        } catch {
            handleFailure(error)
        }
    }

    /// Undo an accidental completion: removes the most recent one for the
    /// task (today's, if several days are in play — the accidental tap is
    /// always the fresh one).
    func uncompleteTask(_ task: OwnTask) async {
        guard let client else { return }
        let latest = completionsThisWeek(for: task).max { lhs, rhs in
            if lhs.completedOn != rhs.completedOn { return lhs.completedOn < rhs.completedOn }
            return lhs.id < rhs.id
        }
        guard let latest else { return }
        do {
            try await client.delete("items/task_completions/\(latest.id)")
            completions.removeAll { $0.id == latest.id }
            historyCompletions.removeAll { $0.id == latest.id }
            Haptics.tap()
        } catch {
            handleFailure(error)
        }
    }

    func claimCompetition() async {
        guard let competition = competitionTask,
              let client,
              claim == nil
        else { return }
        let body: [String: Any] = [
            "player": myName,
            "task": competition.id,
            "dedupe_key": "task:\(competition.id)",
        ]
        do {
            let created: CompetitionClaim = try await client.create(
                CompetitionClaim.self, in: "items/competition_claims", body: body
            )
            claim = created
            // It just happened, so it's inside the history window; a nil
            // timestamp simply won't count toward any month.
            historyClaims.append(created)
            Haptics.success()
        } catch {
            handleFailure(error)
        }
    }

    func saveAnswer(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AnswerRules.isValid(trimmed), let question, let client else { return }
        do {
            if let existing = myAnswer {
                let updated: Answer = try await client.update(
                    Answer.self, "items/answers/\(existing.id)", body: ["body": trimmed]
                )
                answers = answers.map { $0.id == updated.id ? updated : $0 }
            } else {
                let created: Answer = try await client.create(Answer.self, in: "items/answers", body: [
                    "player": myName,
                    "questions": question.id,
                    "body": trimmed,
                    "dedupe_key": "\(question.id):\(myName)",
                ])
                answers.append(created)
            }
            Haptics.success()
        } catch {
            handleFailure(error)
        }
    }

    func sendNudge() async {
        guard let question, let client, !partnerName.isEmpty else { return }
        let body: [String: Any] = [
            "questions": question.id,
            "from_player": myName,
            "to_player": partnerName,
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
    /// write (both devices raced, or we're already registered) — just resync
    /// rather than showing an error.
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
        case .background:
            // Fresh state before the daily reminders fire without us: the
            // 19:00 text should know about any nudges waiting right now.
            Notifications.reschedule(
                hasUnseenNudges: !unseenNudges.isEmpty,
                nudgerName: unseenNudges.first?.fromPlayer
            )
            stopPolling()
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
