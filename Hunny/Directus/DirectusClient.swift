import Foundation

struct APIError: LocalizedError {
    let status: Int
    let message: String

    var errorDescription: String? { message }

    /// Directus reports unique-constraint violations as a 400/409 whose message
    /// mentions the constraint — MySQL says "duplicate entry", Postgres and
    /// SQLite say "unique". Hunny leans on these for race-proof writes.
    var isUniqueViolation: Bool {
        guard status == 400 || status == 409 else { return false }
        let lowered = message.lowercased()
        return lowered.contains("unique") || lowered.contains("duplicate")
    }

    static func from(status: Int, data: Data) -> APIError {
        struct Failure: Decodable {
            struct Detail: Decodable { let message: String? }
            let errors: [Detail]?
        }
        let detail = try? JSONDecoder().decode(Failure.self, from: data)
        if let message = detail?.errors?.compactMap(\.message).first {
            return APIError(status: status, message: message)
        }
        // Not a Directus error envelope — show what the body actually was
        // (proxy block pages, HTML, empty bodies…) instead of a bare status.
        let snippet = String(data: data.prefix(200), encoding: .utf8)
            .map { " — \($0)" } ?? " — <\(data.count) non-UTF8 bytes>"
        return APIError(status: status, message: "Request failed (HTTP \(status))\(snippet)")
    }
}

/// Small helpers for building Directus `filter` query values as JSON strings.
enum Filter {
    static func json(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func eq(_ field: String, _ value: Any) -> String {
        json([field: ["_eq": value]])
    }

    /// `field == value AND nullField IS NULL`
    static func eq(_ field: String, _ value: Any, nullField: String) -> String {
        json(["_and": [
            [field: ["_eq": value]],
            [nullField: ["_null": true]],
        ]])
    }
}

enum DirectusDate {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }
}

/// Thin async REST client for Directus: static-token auth, the standard
/// `{ "data": ... }` envelope, and ISO-8601 timestamps.
final class DirectusClient {
    private let base: URL
    private let token: String
    private let session: URLSession

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = DirectusDate.parse(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognised date: \(raw)"
                )
            }
            return date
        }
        return decoder
    }()

    init(baseURL: URL, token: String) {
        self.base = baseURL
        self.token = token
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
    }

    // MARK: Public surface

    func list<T: Decodable>(_ type: T.Type, from path: String, query: [String: String] = [:]) async throws -> [T] {
        let envelope: Envelope<[T]> = try await get(path, query: query)
        return envelope.data
    }

    func create<T: Decodable>(_ type: T.Type, in path: String, body: [String: Any]) async throws -> T {
        try await send("POST", path, body: body)
    }

    func update<T: Decodable>(_ type: T.Type, _ path: String, body: [String: Any]) async throws -> T {
        try await send("PATCH", path, body: body)
    }

    // MARK: Transport

    private func get<T: Decodable>(_ path: String, query: [String: String]) async throws -> T {
        try await send("GET", path, query: query)
    }

    private func send<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        body: [String: Any]? = nil
    ) async throws -> T {
        let envelope: Envelope<T> = try await sendEnvelope(method, path, query: query, body: body)
        return envelope.data
    }

    private func sendEnvelope<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [String: String],
        body: [String: Any]?
    ) async throws -> Envelope<T> {
        var components = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: true
        )!
        if !query.isEmpty {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }

        let started = Date()
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: -1, message: "No response from the server")
        }
        let elapsed = String(format: "%.0fms", Date().timeIntervalSince(started) * 1000)
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "no content-type"

        guard (200..<300).contains(http.statusCode) else {
            let error = APIError.from(status: http.statusCode, data: data)
            DiagnosticLog.shared.record("\(method) \(path) → \(http.statusCode) [\(contentType)] \(elapsed) — \(error.message)")
            throw error
        }

        do {
            let envelope = try DirectusClient.decoder.decode(Envelope<T>.self, from: data)
            DiagnosticLog.shared.record("\(method) \(path) → \(http.statusCode) [\(contentType)] \(elapsed) · \(data.count)B")
            return envelope
        } catch {
            let detail = Self.describe(error, data: data)
            DiagnosticLog.shared.record("\(method) \(path) → \(http.statusCode) [\(contentType)] \(elapsed) — DECODE FAILED · \(detail)")
            throw APIError(status: http.statusCode, message: "\(method) \(path): \(detail)")
        }
    }

    /// Turns a DecodingError into something a human can act on: what was
    /// expected, where, and a preview of the body that didn't match.
    private static func describe(_ error: DecodingError, data: Data) -> String {
        func path(_ keys: [CodingKey]) -> String {
            keys.isEmpty ? "root" : keys.map(\.stringValue).joined(separator: ".")
        }
        let summary: String
        switch error {
        case .keyNotFound(let key, let context):
            summary = "missing '\(key.stringValue)' at \(path(context.codingPath))"
        case .typeMismatch(let type, let context):
            summary = "expected \(type) at \(path(context.codingPath))"
        case .valueNotFound(let type, let context):
            summary = "unexpected null for \(type) at \(path(context.codingPath))"
        case .dataCorrupted(let context):
            summary = context.debugDescription
        @unknown default:
            summary = String(describing: error)
        }
        let preview = String(data: data.prefix(300), encoding: .utf8)
            .map { " body: \($0)" } ?? " body: <\(data.count) non-UTF8 bytes>"
        return summary + preview
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let data: T
}
