import Foundation

/// Filter rules shared by all three processes.
///
/// - Written by: `FilterControlProvider` (the only writer).
/// - Read by: `FilterDataProvider` (read-only by sandbox design) and the host
///   app (for display).
public struct FilterRules: Sendable, Codable, Equatable {
    public var version: Int
    /// Host suffixes to block, e.g. "tracker.example.net" blocks
    /// "tracker.example.net" and "*.tracker.example.net".
    public var blockedHosts: [String]
    /// Source-app bundle IDs whose traffic is always dropped.
    public var blockedApps: [String]

    public init(version: Int, blockedHosts: [String], blockedApps: [String]) {
        self.version = version
        self.blockedHosts = blockedHosts
        self.blockedApps = blockedApps
    }

    /// Built-in fallback used when no rules file exists yet.
    public static let `default` = FilterRules(
        version: 1,
        blockedHosts: ["blocked.example.test"],
        blockedApps: []
    )

    public func blocks(host: String) -> Bool {
        let target = host.lowercased()
        guard !target.isEmpty else { return false }
        return blockedHosts.contains { rule in
            let suffix = rule.lowercased()
            return target == suffix || target.hasSuffix("." + suffix)
        }
    }

    public func blocks(appIdentifier: String?) -> Bool {
        guard let appIdentifier, !appIdentifier.isEmpty else { return false }
        return blockedApps.contains(appIdentifier)
    }
}
