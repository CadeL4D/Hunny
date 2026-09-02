import SwiftUI

/// Scoreboard shown at the top of every tab: the weekly you-vs-them race on
/// top (crown on the leader, week range underneath) and, below a divider, the
/// running monthly total both players build together until it resets on the
/// 1st. The partner column shows a "waiting…" hint until their device has
/// connected with the exact same name.
///
/// Tapping your own avatar five times (quickly) opens the hidden task editor.
struct ScoreHeader: View {
    @EnvironmentObject private var app: AppState
    @State private var showingTaskAdmin = false
    @State private var profileTapCount = 0
    @State private var lastProfileTap: Date?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                PlayerScoreColumn(
                    name: app.myName.isEmpty ? "You" : app.myName,
                    points: app.myPoints,
                    isLeader: app.myPoints > app.partnerPoints,
                    alignedLeading: true,
                    onAvatarTap: handleProfileTap
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

            Divider()

            monthTotalRow
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .sheet(isPresented: $showingTaskAdmin) {
            TaskAdminView()
        }
    }

    /// Combined points since the 1st, both players, with each side's share —
    /// "you 12 · them 9 · resets Oct 1".
    private var monthTotalRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("THIS MONTH")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Text("you \(app.myMonthPoints) · them \(app.partnerMonthPoints) · resets \(Month.resetsLabel)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(app.monthTotalPoints)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
        }
    }

    /// Five taps within 1.5s of each other opens the hidden task editor;
    /// anything slower resets the count so it can't trigger by accident.
    private func handleProfileTap() {
        if let last = lastProfileTap, Date().timeIntervalSince(last) > 1.5 {
            profileTapCount = 0
        }
        lastProfileTap = Date()
        profileTapCount += 1
        guard profileTapCount >= 5 else { return }
        profileTapCount = 0
        lastProfileTap = nil
        Haptics.tap()
        showingTaskAdmin = true
    }
}

private struct PlayerScoreColumn: View {
    let name: String
    let points: Int
    let isLeader: Bool
    let alignedLeading: Bool
    var joined = true
    var onAvatarTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AvatarView(name: name)
                    .onTapGesture { onAvatarTap?() }
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
