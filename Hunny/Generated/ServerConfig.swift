import Foundation

/// The build-time server URL. CI overwrites this file with the real value from
/// the DIRECTUS_URL repository secret just before building — the committed copy
/// stays empty so the endpoint never appears in a public commit. The injected
/// value is base64-encoded so it isn't trivially visible in the shipped binary.
enum ServerConfig {
    static let encodedDefaultURL: String? = nil

    static var defaultBaseURLString: String? {
        encodedDefaultURL
            .flatMap { Data(base64Encoded: $0) }
            .flatMap { String(data: $0, encoding: .utf8) }
    }
}
