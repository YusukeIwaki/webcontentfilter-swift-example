import Foundation

public enum RuleStoreError: Error {
    case noSharedContainer
}

/// JSON persistence for `FilterRules` in the Shared App Group.
///
/// Direction is one-way by design: only the Control provider writes,
/// the Data provider only reads (its sandbox forbids writes anyway).
public enum RuleStore {
    public static var rulesFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)?
            .appendingPathComponent("rules.json")
    }

    /// Read API — used by the Data provider and the host app.
    /// Returns `.default` when no rules file exists yet.
    public static func loadRules() -> FilterRules {
        guard
            let url = rulesFileURL,
            let data = try? Data(contentsOf: url),
            let rules = try? JSONDecoder().decode(FilterRules.self, from: data)
        else {
            return .default
        }
        return rules
    }

    /// Write API — must be called ONLY from the Control provider.
    public static func saveRules(_ rules: FilterRules) throws {
        guard let url = rulesFileURL else {
            throw RuleStoreError.noSharedContainer
        }
        let data = try JSONEncoder().encode(rules)
        try data.write(to: url, options: .atomic)
    }
}
