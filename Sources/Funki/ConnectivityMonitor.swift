import Foundation
import Network
import os

enum Status: Equatable {
    case checking
    case online
    case offline(Failure)
    case paused
}

/// Keeps track of whether the internet is reachable.
///
/// Two sources feed into the status:
///
/// - `NWPathMonitor` reports network changes the moment they happen and costs
///   nothing in between. Every change triggers a check, and while no network is
///   usable at all Funki doesn't probe, it just waits for the next change.
/// - HTTP probes confirm that the network actually leads to the internet. While
///   online they run at a relaxed pace. As soon as one fails they run back to
///   back until the connection has returned.
@MainActor
final class ConnectivityMonitor {
    /// While online, patience avoids false alarms on a slow connection. While
    /// retrying, a fresh attempt is worth more than waiting on an old one.
    private static let relaxedTimeout: TimeInterval = 5
    private static let retryTimeout: TimeInterval = 3

    /// Failed probes in a row it takes to go from online to offline, so a
    /// single lost request doesn't flip the status.
    private static let failuresUntilOffline = 2

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Funki", category: "status")

    var onChange: ((Status) -> Void)?

    private(set) var status = Status.checking {
        didSet {
            guard status != oldValue else { return }
            Self.log.info("\(String(describing: self.status), privacy: .public)")
            onChange?(status)
        }
    }

    /// Changes take effect immediately, starting with a fresh check.
    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            if settings.endpoint != oldValue.endpoint { history.removeAll() }
            checkNow()
        }
    }

    /// How long the latest probes took. It starts over with a new server,
    /// since the latencies of two servers don't compare.
    let history = LatencyHistory()

    private var pathUpdates: Task<Void, Never>?
    private var probing: Task<Void, Never>?
    private var failures = 0
    private var hasNetwork = false
    private var activity: NSObjectProtocol?

    init(settings: Settings) {
        self.settings = settings
    }

    func start() {
        guard pathUpdates == nil else { return }
        status = .checking
        // The monitor reports the current path right away, which kicks off the
        // first check.
        pathUpdates = Task {
            for await path in NWPathMonitor() {
                networkChanged(isUsable: path.status != .unsatisfied)
            }
        }
    }

    /// Stops everything, including the path monitor. A paused Funki does nothing.
    func pause() {
        pathUpdates?.cancel()
        pathUpdates = nil
        hasNetwork = false
        stopProbing()
        status = .paused
    }

    /// Probes right away and continues the regular rhythm from there.
    func checkNow() {
        guard hasNetwork else { return }
        probing?.cancel()
        probing = Task {
            while !Task.isCancelled {
                let started = ContinuousClock.now
                let result = await Probe.run(
                    settings.endpoint,
                    timeout: isUrgent ? Self.retryTimeout : Self.relaxedTimeout
                )
                guard !Task.isCancelled else { return }
                record(result)

                // The result decides the pace. The interval counts from the
                // start of the probe, so one that ran into its timeout is
                // followed by the next without further delay. While online, a
                // generous tolerance lets the system batch the check with
                // other wakeups.
                let interval = Duration.seconds(isUrgent ? settings.retryInterval : settings.checkInterval)
                try? await Task.sleep(
                    until: started + interval,
                    tolerance: isUrgent ? .milliseconds(100) : interval / 6
                )
            }
        }
    }

    /// Whether the connection is down or in doubt, which calls for the fast pace.
    private var isUrgent: Bool {
        status != .online || failures > 0
    }

    private func networkChanged(isUsable: Bool) {
        hasNetwork = isUsable
        if isUsable {
            checkNow()
        } else {
            stopProbing()
            status = .offline(.noNetwork)
        }
    }

    private func record(_ result: Result<Duration, Failure>) {
        switch result {
        case .success(let latency):
            failures = 0
            status = .online
            history.append(latency)
        case .failure(let failure):
            failures += 1
            if status != .online || failures >= Self.failuresUntilOffline {
                status = .offline(failure)
            }
            history.append(nil)
        }
        preventAppNap(isUrgent)
    }

    private func stopProbing() {
        probing?.cancel()
        probing = nil
        failures = 0
        preventAppNap(false)
    }

    /// App Nap throttles the timers of apps without visible windows. That is
    /// welcome while online, but it would delay noticing that the connection is
    /// back, so Funki opts out for as long as it is retrying.
    private func preventAppNap(_ prevent: Bool) {
        if prevent, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Waiting for the internet connection to return"
            )
        } else if !prevent, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}
