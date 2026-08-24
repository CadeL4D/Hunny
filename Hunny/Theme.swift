import SwiftUI

enum Theme {
    /// Warm honey amber.
    static let accent = Color(red: 1.00, green: 0.68, blue: 0.09)
    static let accentDeep = Color(red: 1.00, green: 0.47, blue: 0.13)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
