import SwiftUI

struct CompeteView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScoreHeader()

                    if let competition = app.competitionTask {
                        competitionCard(competition)
                    } else {
                        EmptyStateView(
                            icon: "flag.checkered",
                            title: "No head-to-head this week",
                            message: "When this week's competition task is added in Directus, the race opens here."
                        )
                    }
                }
                .padding(16)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: app.claim)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Compete")
            .refreshable { await app.refresh() }
        }
    }

    private func competitionCard(_ competition: CompetitionTask) -> some View {
        Card {
            Label("Head-to-head", systemImage: "flag.checkered.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)

            Text(competition.title)
                .font(.title3.weight(.bold))
                .padding(.top, 6)

            if let detail = competition.detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Divider()
                .padding(.vertical, 8)

            if let claim = app.claim {
                claimResult(claim)
            } else {
                claimButton
            }
        }
    }

    private func claimResult(_ claim: CompetitionClaim) -> some View {
        let mine = claim.user == app.userID
        return HStack(spacing: 12) {
            Image(systemName: mine ? "trophy.fill" : "bolt.slash.fill")
                .font(.title3)
                .foregroundStyle(mine ? Theme.accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(mine
                     ? "You claimed it first"
                     : "\(app.opponent?.name ?? "The other player") claimed it first")
                    .font(.body.weight(.semibold))
                if let claimedAt = claim.claimedAt {
                    Text(claimedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var claimButton: some View {
        VStack(spacing: 10) {
            Button {
                Task { await app.claimCompetition() }
            } label: {
                Label("I've done it — claim the point", systemImage: "hand.tap.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)

            Text("First device to claim wins the point for the week. No take-backs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
