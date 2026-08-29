import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var app: AppState
    @State private var showingSettings = false

    private var weeklyTasks: [OwnTask] { app.tasks.filter { $0.maxPerWeek <= 1 } }
    private var dailyTasks: [OwnTask] { app.tasks.filter { $0.maxPerWeek > 1 } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ScoreHeader()

                    if app.tasks.isEmpty {
                        EmptyStateView(icon: "checklist", title: "No tasks yet")
                    } else {
                        if !weeklyTasks.isEmpty {
                            section(title: "Once this week", tasks: weeklyTasks)
                        }
                        if !dailyTasks.isEmpty {
                            section(title: "Once a day this week", tasks: dailyTasks)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: app.completions)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tasks")
            .refreshable { await app.refresh() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SetupView(editing: true)
                }
            }
        }
    }

    private func section(title: String, tasks: [OwnTask]) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(doneCount(tasks)) / \(totalCount(tasks))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)

            ForEach(tasks) { task in
                TaskCard(task: task)
            }
        }
    }

    private func doneCount(_ tasks: [OwnTask]) -> Int {
        tasks.reduce(0) { partial, task in
            partial + min(app.completionsThisWeek(for: task).count, max(task.maxPerWeek, 1))
        }
    }

    private func totalCount(_ tasks: [OwnTask]) -> Int {
        tasks.reduce(0) { $0 + max($1.maxPerWeek, 1) }
    }
}

struct TaskCard: View {
    @EnvironmentObject private var app: AppState
    let task: OwnTask

    private var completions: [TaskCompletion] { app.completionsThisWeek(for: task) }
    private var fullyDone: Bool { completions.count >= max(task.maxPerWeek, 1) }
    private var doneToday: Bool { completions.contains { $0.completedOn == Week.todayKey } }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.accentGradient, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(fullyDone, color: .secondary)
                    .foregroundStyle(fullyDone ? .secondary : .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if task.maxPerWeek > 1 {
                    ProgressDots(count: task.maxPerWeek, filled: completions.count)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            completionControl
        }
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    @ViewBuilder
    private var completionControl: some View {
        if app.canComplete(task) {
            Button {
                Task { await app.completeTask(task) }
            } label: {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .buttonStyle(TaskButtonStyle())
        } else {
            // Done — tap to undo an accidental completion.
            Button {
                Task { await app.uncompleteTask(task) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(TaskButtonStyle())
        }
    }

    private var iconName: String {
        if let icon = task.icon, !icon.isEmpty { return icon }
        return "circle.dotted"
    }

    private var subtitle: String {
        if task.maxPerWeek <= 1 {
            return completions.isEmpty ? "Worth 1 point this week" : "Completed · +1 point"
        }
        if doneToday { return "Done today · \(completions.count) of \(task.maxPerWeek) this week" }
        return "Once a day · up to \(task.maxPerWeek) points"
    }
}

struct TaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
