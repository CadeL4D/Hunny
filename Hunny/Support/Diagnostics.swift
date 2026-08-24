import Foundation
import UIKit

/// In-memory record of recent API traffic so on-device failures can be
/// diagnosed without a debugger — copied out through the Diagnostics section
/// of Settings. Keeps the last 200 entries.
final class DiagnosticLog {
    static let shared = DiagnosticLog()

    private static let capacity = 200

    private var entries: [String] = []
    private let lock = NSLock()
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func record(_ line: String) {
        lock.lock()
        entries.append("\(formatter.string(from: Date())) \(line)")
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
        lock.unlock()
    }

    /// Everything a bug report needs: app + OS versions and the recent log.
    func formatted() -> String {
        lock.lock()
        let copy = entries
        lock.unlock()
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let header = [
            "Hunny \(version) (\(build)) · \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium),
            "—",
        ]
        return (header + copy).joined(separator: "\n")
    }
}
