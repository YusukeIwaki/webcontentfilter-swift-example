import SwiftUI

struct ContentView: View {
    @StateObject private var settings = FilterSettings()

    /// Rules currently published in the Shared App Group (written by the
    /// Control provider). Shown here for transparency; the app never edits.
    private var rules: FilterRules { RuleStore.loadRules() }

    var body: some View {
        NavigationStack {
            Form {
                Section("フィルター状態") {
                    Text(settings.statusMessage)
                    Toggle("有効化", isOn: Binding(
                        get: { settings.isEnabled },
                        set: { settings.setEnabled($0) }
                    ))
                    .disabled(settings.isBusy)
                    Button("状態を再読込") { settings.refresh() }
                        .disabled(settings.isBusy)
                }

                Section("ブロック中ホスト (rules.json v\(rules.version))") {
                    if rules.blockedHosts.isEmpty {
                        Text("なし")
                    } else {
                        ForEach(rules.blockedHosts, id: \.self) { host in
                            Text(host).font(.caption.monospaced())
                        }
                    }
                }

                Section("メモ") {
                    Text("端末全体フィルターの正規の有効化経路は、MDM 配布の構成プロファイルです。この画面のスイッチは NEFilterManager API の動作確認用で、Supervised でない端末では保存に失敗します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Content Filter")
            .onAppear { settings.refresh() }
        }
    }
}
