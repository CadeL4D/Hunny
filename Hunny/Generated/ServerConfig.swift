import Foundation

/// Build-time configuration. CI overwrites this file with real values from the
/// DIRECTUS_URL and DIRECTUS_TOKEN repository secrets just before building —
/// the committed copy stays empty so neither ever appears in a public commit.
/// The injected values are base64-encoded so they aren't trivially visible in
/// the shipped binary.
enum ServerConfig {
    static let encodedDefaultURL: String? = nil
    static let encodedDefaultToken: String? = nil

    static var defaultBaseURLString: String? {
        encodedValue(encodedDefaultURL)
    }

    static var defaultToken: String? {
        encodedValue(encodedDefaultToken)
    }

    private static func encodedValue(_ encoded: String?) -> String? {
        guard let encoded,
              let data = Data(base64Encoded: encoded),
              let string = String(data: data, encoding: .utf8),
              !string.isEmpty
        else { return nil }
        return string
    }
}
