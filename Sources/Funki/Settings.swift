import Foundation

/// Everything the user can change. `Settings()` holds the defaults.
struct Settings: Equatable {
    /// The user's own server, or `nil` to use Apple's.
    var customURL: URL?

    /// Seconds between checks while online.
    var checkInterval = 30

    /// Seconds between checks while offline.
    var retryInterval = 1

    static let minimumCheckInterval = 5
    static let minimumRetryInterval = 1

    var endpoint: Endpoint {
        customURL.map { Endpoint(url: $0) } ?? .apple
    }

    static func load() -> Settings {
        let defaults = UserDefaults.standard
        var settings = Settings()
        settings.customURL = defaults.string(forKey: "customURL").flatMap(parseURL)
        // `integer(forKey:)` is 0 for a missing key, which keeps the default.
        if case let seconds = defaults.integer(forKey: "checkInterval"), seconds >= minimumCheckInterval {
            settings.checkInterval = seconds
        }
        if case let seconds = defaults.integer(forKey: "retryInterval"), seconds >= minimumRetryInterval {
            settings.retryInterval = seconds
        }
        return settings
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(customURL?.absoluteString, forKey: "customURL")
        defaults.set(checkInterval, forKey: "checkInterval")
        defaults.set(retryInterval, forKey: "retryInterval")
    }

    /// Turns user input into an http(s) URL. A bare host name gets `https://`.
    static func parseURL(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: text.contains("://") ? text : "https://" + text, encodingInvalidCharacters: false),
            let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = url.host(), !host.isEmpty
        else { return nil }
        return url
    }
}
