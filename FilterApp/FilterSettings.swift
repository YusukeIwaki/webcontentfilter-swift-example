import Foundation
import NetworkExtension

/// `NEFilterManager` is documented thread-safe ("Instances of this class are
/// thread safe" in NEFilterManager.h); the wrapper says so to Swift 6 so the
/// manager can cross into the MainActor hops below.
private struct SendableFilterManager: @unchecked Sendable {
    let manager: NEFilterManager
}

/// `NEFilterManager` wrapper for the host app UI.
///
/// This is the "registrar" role: load / save / enable the filter
/// configuration. It performs no filtering itself.
@MainActor
final class FilterSettings: ObservableObject {
    @Published private(set) var statusMessage: String = "未読込"
    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false

    func refresh() {
        isBusy = true
        let boxed = SendableFilterManager(manager: NEFilterManager.shared())
        boxed.manager.loadFromPreferences { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isBusy = false
                if let error {
                    self.statusMessage = "読込失敗: \(error.localizedDescription)"
                    return
                }
                self.isEnabled = boxed.manager.isEnabled
                self.statusMessage = boxed.manager.isEnabled ? "有効" : "無効"
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        isBusy = true
        let boxed = SendableFilterManager(manager: NEFilterManager.shared())
        boxed.manager.loadFromPreferences { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.isBusy = false
                    self.statusMessage = "読込失敗: \(error.localizedDescription)"
                    return
                }
                let config = NEFilterProviderConfiguration()
                config.filterBrowsers = true
                config.filterSockets = true
                config.serverAddress = "https://filter.example.com"
                config.organization = "Example Inc."
                boxed.manager.providerConfiguration = config
                boxed.manager.localizedDescription = "Example Content Filter"
                boxed.manager.isEnabled = enabled
                boxed.manager.saveToPreferences { [weak self] saveError in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.isBusy = false
                        if let saveError {
                            self.statusMessage = "保存失敗: \(saveError.localizedDescription)"
                            return
                        }
                        self.isEnabled = enabled
                        self.statusMessage = enabled ? "有効" : "無効"
                    }
                }
            }
        }
    }
}
