import SwiftUI

/// Weekly scoreboard shown at the top of every tab: you vs. them, crown on
/// the leader, week range underneath. The partner column shows a "waiting…"
/// hint until their device has connected with the exact same name.
struct ScoreHeader: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(spacing: 14) {
            PlayerScoreColumn(
                name: app.myName.isEmpty ? "You" : app.myName,
                points: app.myPoints,
                isLeader: app.myPoints > app.partnerPoints,
                alignedLeading: true
            )

            VStack(spacing: 3) {
                Text("THIS WEEK")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Text(Week.rangeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(Theme.accentGradient)
            }

            PlayerScoreColumn(
                name: app.partnerName.isEmpty ? "Them" : app.partnerName,
                points: app.partnerPoints,
                isLeader: app.partnerPoints > app.myPoints,
                alignedLeading: false,
                joined: app.partnerHasJoined
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct PlayerScoreColumn: View {
    let name: String
    let points: Int
    let isLeader: Bool
    let alignedLeading: Bool
    var joined = true

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AvatarView(name: name)
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.05))
                        .offset(x: 8, y: -4)
                }
            }
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(points)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLeader ? Theme.accent : .primary)
            if !joined {
                Text("waiting to join…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignedLeading ? .leading : .trailing)
    }
}

struct AvatarView: View {
    let name: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accentGradient)
                .frame(width: 40, height: 40)
            Text(initials)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        guard let name, !name.isEmpty else { return "?" }
        return String(name.prefix(2).uppercased())
    }
}
