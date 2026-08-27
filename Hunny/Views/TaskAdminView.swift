import SwiftUI

/// Hidden task editor: create, edit and retire personal tasks and the weekly
/// head-to-head straight from the app, so day-to-day changes never need the
/// Directus Data Studio. Opened by tapping your own profile avatar five times
/// in the score header.
struct TaskAdminView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var activeSheet: AdminSheet?

    /// What the editor is currently editing. `competition(nil)` means a
    /// brand-new head-to-head; `competition(task)` edits this week's row.
    private enum AdminSheet: Identifiable {
        case newOwnTask
        case editOwnTask(OwnTask)
        case competition(CompetitionTask?)

        var id: String {
            switch self {
            case .newOwnTask: return "new-own-task"
            case .editOwnTask(let task): return "edit-own-task-\(task.id)"
            case .competition(let existing): return "competition-\(existing?.id ?? 0)"
            }
        }
    }

    private var activeTasks: [OwnTask] { app.allTasks.filter { $0.active ?? true } }
    private var retiredTasks: [OwnTask] { app.allTasks.filter { !($0.active ?? true) } }

    var body: some View {
        NavigationStack {
            List {
                if let loadError {
                    Section {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("Try Again") {
                            Task { await load() }
                        }
                    }
                }

                Section("This Week's Head-to-Head") {
                    if let competition = app.competitionTask {
                        competitionRow(competition)
                    } else {
                        Text("None this week — add one with +.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Active") {
                    if activeTasks.isEmpty && loadError == nil {
                        Text("No tasks yet — tap + to add one.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(activeTasks) { task in
                        row(task)
                    }
                }

                if !retiredTasks.isEmpty {
                    Section("Retired") {
                        ForEach(retiredTasks) { task in
                            row(task)
                        }
                    }
                }
            }
            .overlay {
                if isLoading { ProgressView() }
            }
            .navigationTitle("Manage Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .newOwnTask
                        } label: {
                            Label("Personal task", systemImage: "checklist")
                        }
                        Button {
                            activeSheet = .competition(app.competitionTask)
                        } label: {
                            Label("Head-to-head task", systemImage: "flag.checkered")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newOwnTask:
                    TaskFormView(task: nil)
                case .editOwnTask(let task):
                    TaskFormView(task: task)
                case .competition(let existing):
                    CompetitionFormView(competition: existing)
                }
            }
            .task { await load() }
        }
    }

    private func competitionRow(_ competition: CompetitionTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.accentGradient, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(competition.title)
                    .font(.body.weight(.semibold))
                Text(competitionSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { activeSheet = .competition(competition) }
    }

    private var competitionSubtitle: String {
        if let claim = app.claim {
            return "Claimed by \(claim.player) · repeats weekly"
        }
        return "Unclaimed · repeats weekly"
    }

    private func row(_ task: OwnTask) -> some View {
        let isRetired = !(task.active ?? true)
        return HStack(spacing: 12) {
            Image(systemName: task.icon.nonEmpty ?? "circle.dotted")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.accentGradient, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(isRetired, color: .secondary)
                    .foregroundStyle(isRetired ? .secondary : .primary)
                Text(frequencyLabel(task.maxPerWeek))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Active", isOn: Binding(
                get: { task.active ?? true },
                set: { active in setActive(task, to: active) }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { activeSheet = .editOwnTask(task) }
    }

    private func frequencyLabel(_ maxPerWeek: Int) -> String {
        maxPerWeek <= 1 ? "Once a week" : "Up to \(maxPerWeek)× a week · once a day"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await app.loadAllTasks()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func setActive(_ task: OwnTask, to active: Bool) {
        Task {
            do {
                try await app.updateTask(task, body: ["active": active])
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

/// Create-or-edit form used by the hidden task editor. `task == nil` means
/// a brand-new task; otherwise the fields start from the existing values.
struct TaskFormView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let task: OwnTask?

    @State private var title: String
    @State private var detail: String
    @State private var icon: String
    @State private var maxPerWeek: Int
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var saveError: String?

    init(task: OwnTask?) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _detail = State(initialValue: task?.detail ?? "")
        _icon = State(initialValue: task?.icon ?? "")
        _maxPerWeek = State(initialValue: max(task?.maxPerWeek ?? 1, 1))
        _isActive = State(initialValue: task?.active ?? true)
    }

    private static let suggestedIcons = [
        "figure.run", "dumbbell", "book", "brain.head.profile", "drop",
        "fork.knife", "house", "trash", "paintpalette", "gamecontroller",
        "heart", "moon.zzz",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .submitLabel(.done)
                    TextField("Detail (optional)", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Picker("How often", selection: $maxPerWeek) {
                        Text("Once a week").tag(1)
                        ForEach(2...7, id: \.self) { times in
                            Text("\(times) times a week · once a day max").tag(times)
                        }
                    }
                } footer: {
                    Text("Daily tasks can be completed once per day, up to their weekly limit. Each completion is worth 1 point.")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: icon.isEmpty ? "circle.dotted" : icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Theme.accentGradient, in: Circle())
                        TextField("SF Symbol name (optional)", text: $icon)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.suggestedIcons, id: \.self) { name in
                                Button {
                                    icon = name
                                } label: {
                                    Image(systemName: name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(icon == name ? .white : Theme.accent)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            icon == name ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color(.tertiarySystemFill)),
                                            in: Circle()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("Pick a suggestion or type any SF Symbol name.")
                }

                if task != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    } footer: {
                        Text("Retired tasks keep their history but disappear from the weekly list.")
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || trimmedTitle.isEmpty)
                }
            }
            .disabled(isSaving)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard !trimmedTitle.isEmpty else { return }
        isSaving = true
        do {
            if let task {
                try await app.updateTask(task, body: [
                    "title": trimmedTitle,
                    "detail": detail.isEmpty ? NSNull() : detail,
                    "icon": icon.isEmpty ? NSNull() : icon,
                    "max_per_week": maxPerWeek,
                    "active": isActive,
                ])
            } else {
                try await app.createTask(
                    title: trimmedTitle,
                    detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                    icon: icon.trimmingCharacters(in: .whitespaces),
                    maxPerWeek: maxPerWeek
                )
            }
            Haptics.success()
            dismiss()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}

/// Create-or-edit form for the weekly head-to-head. `competition == nil`
/// means no row exists yet this week; otherwise the current row is edited in
/// place and future weeks inherit the change via carry-forward.
struct CompetitionFormView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let competition: CompetitionTask?

    @State private var title: String
    @State private var detail: String
    @State private var isSaving = false
    @State private var saveError: String?

    init(competition: CompetitionTask?) {
        self.competition = competition
        _title = State(initialValue: competition?.title ?? "")
        _detail = State(initialValue: competition?.detail ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .submitLabel(.done)
                    TextField("Detail (optional)", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("First to finish it claims the win and a bonus point. It repeats every week until you change it here.")
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(competition == nil ? "New Head-to-Head" : "Edit Head-to-Head")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || trimmedTitle.isEmpty)
                }
            }
            .disabled(isSaving)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard !trimmedTitle.isEmpty else { return }
        isSaving = true
        do {
            try await app.saveCompetition(
                title: trimmedTitle,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            Haptics.success()
            dismiss()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        self?.isEmpty == true ? nil : self
    }
}
