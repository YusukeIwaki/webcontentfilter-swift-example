import NetworkExtension

/// The fetcher. Downloads filtering rules over HTTPS and publishes them to
/// the Shared App Group for the Data provider. Has network access but can
/// never see flow content (`request` / `response` are always nil here).
///
/// Counterpart: `FilterDataProvider` (the judge) in the sibling target.
/// Handoff of a completion handler into an unstructured task. NE invokes each
/// handler exactly once from the code below, so the transfer is safe — the
/// wrapper just says so to Swift 6's strict concurrency checking.
private struct SendableCompletion<T>: @unchecked Sendable {
    let handler: (T) -> Void
    func callAsFunction(_ value: T) { handler(value) }
}

/// Stateless across threads (all work uses locals + `RuleStore` statics, and
/// `remediationMap` is set once in `startFilter`), so sharing the instance
/// between the framework callbacks and the refresh tasks below is safe.
final class FilterControlProvider: NEFilterControlProvider, @unchecked Sendable {

    // MARK: - Lifecycle

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        // Strings for the iOS standard block page. `NE_FLOW_URL` etc. are
        // expanded by the system; see NEFilterProvider.h.
        let urls: [String: NSObject] = [
            "default": "https://filter.example.com/blocked?url=NE_FLOW_URL" as NSString
        ]
        let buttons: [String: NSObject] = ["default": "Request Access" as NSString]
        remediationMap = [
            NEFilterProviderRemediationMapRemediationURLs: urls,
            NEFilterProviderRemediationMapRemediationButtonTexts: buttons
        ]
        let completion = SendableCompletion(handler: completionHandler)
        Task {
            await refreshRulesFromServer()
            completion(nil)
        }
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    // MARK: - Rules sourcing

    /// `serverAddress` is NOT a relay/proxy destination. It is a config value
    /// telling *this* provider where to fetch rules from. This sample uses
    /// the convention `<serverAddress>/rules.json`.
    private func refreshRulesFromServer() async {
        defer { notifyRulesChanged() }

        guard
            let address = filterConfiguration.serverAddress,
            let baseURL = URL(string: address)
        else {
            // No server configured: fall back to built-in defaults.
            try? RuleStore.saveRules(.default)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(
                from: baseURL.appendingPathComponent("rules.json")
            )
            let rules = try JSONDecoder().decode(FilterRules.self, from: data)
            try RuleStore.saveRules(rules)
        } catch {
            // Fail-open for this sample: keep last-known rules so one bad
            // fetch does not brick the device's networking.
            if RuleStore.rulesFileURL.flatMap({ try? Data(contentsOf: $0) }) == nil {
                try? RuleStore.saveRules(.default)
            }
        }
    }

    // MARK: - On-demand verdicts (needRules path)

    /// Called when the Data provider returns `.needRules()`. Refresh rules,
    /// then ask Data to judge the flow again.
    override func handleNewFlow(
        _ flow: NEFilterFlow,
        completionHandler: @escaping (NEFilterControlVerdict) -> Void
    ) {
        let completion = SendableCompletion(handler: completionHandler)
        Task {
            await refreshRulesFromServer()
            completion(.updateRules())
        }
    }

    override func handleRemediation(
        for flow: NEFilterFlow,
        completionHandler: @escaping (NEFilterControlVerdict) -> Void
    ) {
        completionHandler(.drop(withUpdateRules: false))
    }
}
