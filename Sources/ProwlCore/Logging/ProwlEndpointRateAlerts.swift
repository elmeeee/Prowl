import Foundation

/// Rules for surfacing a one-shot “hot endpoint” flag on the request that reaches a call-count threshold.
public struct ProwlEndpointRateAlertRule: Sendable, Hashable, Identifiable {
    public enum Match: Sendable, Hashable {
        case urlContains(String)
        case urlRegularExpression(pattern: String)
    }

    public let id: UUID
    public let match: Match
    public let threshold: Int

    public init(id: UUID = UUID(), match: Match, threshold: Int) {
        self.id = id
        self.match = match
        self.threshold = max(1, threshold)
    }
}

/// Namespace for configuring in-process endpoint hit counting (cleared when you call ``resetCounters()``).
public enum ProwlEndpointRateAlerts {
    public static var rules: [ProwlEndpointRateAlertRule] {
        get { ProwlEndpointRateAlertCoordinator.shared.rules }
        set { ProwlEndpointRateAlertCoordinator.shared.rules = newValue }
    }

    public static func resetCounters() {
        ProwlEndpointRateAlertCoordinator.shared.reset()
    }
}

final class ProwlEndpointRateAlertCoordinator: @unchecked Sendable {
    static let shared = ProwlEndpointRateAlertCoordinator()

    private let lock = NSLock()
    private var rulesStorage: [UUID: ProwlEndpointRateAlertRule] = [:]
    private var orderedRuleIDs: [UUID] = []
    private var counts: [String: Int] = [:]

    private init() {}

    var rules: [ProwlEndpointRateAlertRule] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return orderedRuleIDs.compactMap { rulesStorage[$0] }
        }
        set {
            lock.lock()
            rulesStorage = Dictionary(uniqueKeysWithValues: newValue.map { ($0.id, $0) })
            orderedRuleIDs = newValue.map(\.id)
            counts.removeAll(keepingCapacity: true)
            lock.unlock()
        }
    }

    func reset() {
        lock.lock()
        counts.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    /// Increments counters for matching rules. Returns `true` if at least one rule’s threshold is reached on this request.
    func evaluateAndIncrement(method: String, url: URL?, absoluteURLString: String) -> Bool {
        lock.lock()
        let snapshotRules = orderedRuleIDs.compactMap { rulesStorage[$0] }
        lock.unlock()

        guard snapshotRules.isEmpty == false else { return false }

        let signature = Self.endpointSignature(method: method, url: url)
        var fired = false

        lock.lock()
        defer { lock.unlock() }

        for rule in snapshotRules {
            guard matches(rule.match, absoluteURLString: absoluteURLString) else { continue }
            let key = "\(rule.id.uuidString)|\(signature)"
            let next = (counts[key] ?? 0) + 1
            counts[key] = next
            if next == rule.threshold {
                fired = true
            }
        }

        return fired
    }

    private static func endpointSignature(method: String, url: URL?) -> String {
        guard let url else { return "\(method.uppercased())|" }
        let host = url.host ?? ""
        let path = url.path.isEmpty ? "/" : url.path
        return "\(method.uppercased())|\(host)\(path)"
    }

    private func matches(_ match: ProwlEndpointRateAlertRule.Match, absoluteURLString: String) -> Bool {
        switch match {
        case .urlContains(let fragment):
            return absoluteURLString.contains(fragment)
        case .urlRegularExpression(let pattern):
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return false
            }
            let range = NSRange(location: 0, length: absoluteURLString.utf16.count)
            return regex.firstMatch(in: absoluteURLString, options: [], range: range) != nil
        }
    }
}
