import SwiftUI

struct QuestionView: View {
    @EnvironmentObject private var app: AppState
    @State private var draft = ""
    @State private var syncedDraft = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let question = app.question {
                        Card {
                            Label("Question of the week", systemImage: "text.bubble.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            Text(question.text)
                                .font(.title3.weight(.bold))
                                .padding(.top, 6)
                        }

                        myAnswerCard
                        theirAnswerCard
                    } else {
                        EmptyStateView(
                            icon: "text.bubble",
                            title: "No question yet",
                            message: "This week's question appears here once it's added in Directus."
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Question")
            .refreshable { await app.refresh() }
            .onAppear {
                guard !syncedDraft else { return }
                syncedDraft = true
                draft = app.myAnswer?.body ?? ""
            }
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var myAnswerCard: some View {
        Card {
            Label("Your answer", systemImage: "pencil.and.outline")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $draft)
                .frame(minHeight: 96)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(
                    Color(.tertiarySystemFill).opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(.top, 6)

            HStack {
                if let hint = AnswerRules.hint(for: draft) {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if let answer = app.myAnswer, let updated = answer.updatedAt {
                    Text("Saved \(updated, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await app.saveAnswer(draft) }
                } label: {
                    Text(app.myAnswer == nil ? "Submit" : "Update")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!AnswerRules.isValid(draft) || app.myAnswer?.body == trimmedDraft)
            }
            .padding(.top, 8)
        }
    }

    private var theirAnswerCard: some View {
        Card {
            let partnerName = app.partnerName.isEmpty ? "Player two" : app.partnerName
            Label("\(partnerName)'s answer", systemImage: "person.crop.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let theirs = app.theirAnswer {
                VStack(alignment: .leading, spacing: 6) {
                    Text(theirs.body)
                        .font(.body)
                    if let updated = theirs.updatedAt {
                        Text("Updated \(updated, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 6)
            } else {
                VStack(spacing: 12) {
                    Text("\(partnerName) hasn't answered yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await app.sendNudge() }
                    } label: {
                        Label("Send a nudge", systemImage: "bell")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
    }
}
