/// How long the most recent probes took, oldest first. `nil` stands for a probe
/// that failed.
///
/// A ring buffer: the storage is allocated once, and once it is full the newest
/// sample overwrites the oldest. Recording costs the same after a month as
/// after a minute, and nothing in here grows with the number of probes. It is
/// a class so that the monitor filling it and the graph drawing it share the
/// samples instead of copying them.
@MainActor
final class LatencyHistory {
    /// Half an hour at the default pace.
    static let capacity = 60

    /// Called after every change.
    var onChange: (() -> Void)?

    private var samples = [Duration?](repeating: nil, count: capacity)
    /// Where the next sample goes. In a full buffer that is the oldest one.
    private var next = 0
    private(set) var count = 0

    /// The sample at `index`, with the oldest at 0.
    subscript(index: Int) -> Duration? {
        samples[(next - count + index + Self.capacity) % Self.capacity]
    }

    /// The newest sample. Also `nil` while there is none.
    var last: Duration? {
        count > 0 ? self[count - 1] : nil
    }

    /// The longest of the latencies, or zero without any.
    var peak: Duration {
        // The order doesn't matter here, and the samples in use always start
        // at the front of the storage.
        samples[..<count].reduce(.zero) { max($0, $1 ?? .zero) }
    }

    func append(_ latency: Duration?) {
        // An outage is one mark in the graph, however long it lasts. A minute
        // of retrying every second would otherwise push out everything else.
        if latency == nil, count > 0, last == nil { return }
        samples[next] = latency
        next = (next + 1) % Self.capacity
        count = min(count + 1, Self.capacity)
        onChange?()
    }

    func removeAll() {
        next = 0
        count = 0
        onChange?()
    }
}
