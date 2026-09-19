import NetworkExtension

/// The judge. Runs inside the network stack and returns allow / drop /
/// remediate for every flow. Heavily sandboxed: no networking, no IPC,
/// no disk writes — rules come read-only from the Shared App Group.
///
/// Counterpart: `FilterControlProvider` (the fetcher) in the sibling target.
final class FilterDataProvider: NEFilterDataProvider {

    // MARK: - Rules state

    private let lock = NSLock()
    private var storedRules: FilterRules = .default

    private var rules: FilterRules {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedRules
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedRules = newValue
        }
    }

    // MARK: - Lifecycle

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        rules = RuleStore.loadRules()
        completionHandler(nil)
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    /// Called after the Control provider calls `notifyRulesChanged()`.
    override func handleRulesChanged() {
        rules = RuleStore.loadRules()
    }

    // MARK: - Flow verdicts

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let rules = self.rules

        // 1. Per-app rule: drop everything from blocked source apps.
        if rules.blocks(appIdentifier: flow.sourceAppIdentifier) {
            return .drop()
        }

        // 2. WebKit flows carry URL metadata (not MITM — iOS hands it over).
        if let browserFlow = flow as? NEFilterBrowserFlow {
            let host = browserFlow.request?.url?.host ?? flow.url?.host ?? ""
            if rules.blocks(host: host) {
                // Shows the iOS standard block page. The map keys resolve
                // against `remediationMap` published by the Control provider.
                return .remediateVerdict(
                    withRemediationURLMapKey: "default",
                    remediationButtonTextMapKey: "default"
                )
            }
            return .allow()
        }

        // 3. Raw socket flows: hostname/IP/port only. TLS payloads stay
        // encrypted, so HTTPS bodies are never visible here.
        if let socketFlow = flow as? NEFilterSocketFlow {
            // `remoteHostname` is nil for plain BSD-socket traffic; a real
            // product would also match the endpoint IP against a CIDR list.
            if let host = socketFlow.remoteHostname, rules.blocks(host: host) {
                return .drop()
            }
            return .allow()
        }

        return .allow()
    }

    // MARK: - Data verdicts (peek path — unused by this sample)

    /// This sample judges flows in `handleNewFlow` only, so it never returns
    /// a `filterData` verdict and these stay as pass-through. To inspect
    /// payload bytes, return
    /// `.filterDataVerdict(filterInbound:peekInboundBytes:filterOutbound:peekOutboundBytes:)`
    /// from `handleNewFlow` and judge here instead.
    override func handleInboundData(
        from flow: NEFilterFlow,
        readBytesStartOffset offset: Int,
        readBytes: Data
    ) -> NEFilterDataVerdict {
        .allow()
    }

    override func handleOutboundData(
        from flow: NEFilterFlow,
        readBytesStartOffset offset: Int,
        readBytes: Data
    ) -> NEFilterDataVerdict {
        .allow()
    }

    override func handleInboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
        .allow()
    }

    override func handleOutboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
        .allow()
    }

    /// Called when the user taps the block page action. This sample keeps
    /// the block; a real product could re-check freshened rules here.
    override func handleRemediation(for flow: NEFilterFlow) -> NEFilterRemediationVerdict {
        .drop()
    }
}
