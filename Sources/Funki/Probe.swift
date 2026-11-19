import Foundation

/// The address Funki requests to find out whether the internet is reachable.
struct Endpoint: Equatable, Sendable {
    let url: URL

    /// Text the response body has to contain. This is what tells real
    /// connectivity apart from a captive portal answering in the server's place.
    var expectedBody: String?

    /// Apple's captive portal check, the server macOS itself relies on. It
    /// answers every path with the same small page.
    static let apple = Endpoint(
        url: URL(string: "http://captive.apple.com")!,
        expectedBody: "Success"
    )
}

/// Why Funki considers the connection to be down.
enum Failure: Error, Equatable {
    /// No network interface is usable, so there is nothing to probe.
    case noNetwork
    /// The request failed or timed out.
    case noResponse
    /// Something answered, but not the way the endpoint should. Typically a
    /// captive portal asking for a login.
    case unexpectedResponse(status: Int)
}

enum Probe {
    /// One session for the lifetime of the app. Nothing is cached or stored, so
    /// memory stays flat no matter how long Funki runs. Disabling the cache also
    /// matters for correctness: Apple serves its check with a one year max-age.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        // Hard limit for a response that keeps trickling in. The timeout passed
        // to `run` only measures how long the connection has been idle.
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }()

    /// Requests the endpoint once. When the internet is reachable, the result
    /// is how long the answer took.
    static func run(_ endpoint: Endpoint, timeout: TimeInterval) async -> Result<Duration, Failure> {
        // Measured here rather than by the caller, so a busy main thread
        // doesn't add to it. This clock stands still while the Mac sleeps.
        let started = SuspendingClock.now
        let request = URLRequest(
            url: endpoint.url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )
        do {
            let (bytes, response) = try await session.bytes(for: request)
            // The headers are all we need in most cases. Cancelling here keeps a
            // custom URL that points at a large page from being downloaded.
            defer { bytes.task.cancel() }

            guard let status = (response as? HTTPURLResponse)?.statusCode else { return .failure(.noResponse) }

            // Over TLS the server has proven its identity, so a redirect is as
            // good as any other answer. Over plain HTTP a redirect is exactly
            // how captive portals intercept requests.
            let isSecure = endpoint.url.scheme?.lowercased() == "https"
            guard (200..<300).contains(status) || (isSecure && (300..<400).contains(status)) else {
                return .failure(.unexpectedResponse(status: status))
            }

            if let expectedBody = endpoint.expectedBody {
                var body: [UInt8] = []
                for try await byte in bytes.prefix(512) { body.append(byte) }
                guard String(decoding: body, as: UTF8.self).contains(expectedBody) else {
                    return .failure(.unexpectedResponse(status: status))
                }
            }
            return .success(SuspendingClock.now - started)
        } catch {
            return .failure(.noResponse)
        }
    }
}

/// Hands redirects back as the response instead of following them.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
