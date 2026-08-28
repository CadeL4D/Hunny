import Foundation

/// The question's answer has to be a real answer: at least 10 words and
/// more than 20 characters, so ten one-letter tokens can't pass as words.
/// web/app.js's `AnswerRules` mirrors this exactly.
enum AnswerRules {
    static let minimumWords = 10
    static let characterFloor = 20

    static func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > characterFloor else { return false }
        return words(in: trimmed) >= minimumWords
    }

    static func words(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// "10-word minimum · 4 to go", or nil once the answer qualifies.
    static func hint(for text: String) -> String? {
        guard !isValid(text) else { return nil }
        let remaining = max(0, minimumWords - words(in: text))
        return "10-word minimum · \(remaining) to go"
    }
}
