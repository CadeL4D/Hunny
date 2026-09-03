import SwiftUI

/// Month-by-month history behind the score header's monthly row: the month
/// in progress on top (marked "so far"), then every previous month the data
/// pull covers, each with its winner crowned. Months nobody scored in are
/// left out.
struct MonthHistoryView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    private struct MonthRecord: Identifiable {
        let monthKey: String
        let isCurrent: Bool
        let mine: Int
        let theirs: Int

        var id: String { monthKey }
        var total: Int { mine + theirs }
    }

    private var records: [MonthRecord] {
        Month.historyKeys.map { monthKey in
            let scores = app.monthScores(monthKey)
            return MonthRecord(
                monthKey: monthKey,
                isCurrent: monthKey == Month.key,
                mine: scores.mine,
                theirs: scores.theirs
            )
        }
        .filter { $0.total > 0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    Text("Nothing to score yet — points show up here once you start earning them.")
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { record in
                    row(record)
                }
            }
            .navigationTitle("Monthly Score")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ record: MonthRecord) -> some View {
        let leaderName: String?
        if record.mine > record.theirs {
            leaderName = app.myName.isEmpty ? "You" : app.myName
        } else if record.theirs > record.mine {
            leaderName = app.partnerName.isEmpty ? "Them" : app.partnerName
        } else {
            leaderName = nil
        }

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Month.label(forKey: record.monthKey) + (record.isCurrent ? " · so far" : ""))
                    .font(.subheadline.weight(.semibold))
                Text("you \(record.mine) · them \(record.theirs)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let leaderName {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.05))
                    Text(leaderName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            } else {
                Text("Tied")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
