# Content Filter API リファレンス（従来型 / Swift）

正本は Xcode SDK の `NetworkExtension.framework/Headers`。
以下は iOS 開発に必要な部分の抜粋（確認 SDK: iPhoneOS.sdk / Xcode 同梱）。

## NEFilterDataProvider（判定担当）

`NetworkExtension.NEFilterDataProvider` を継承する。Extension point は
`com.apple.networkextension.filter-data`。

```swift
final class FilterDataProvider: NEFilterDataProvider {

    // 新規 flow の判定。必須オーバーライド。
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict

    // peek 要求後の inbound/outbound データ判定。必須オーバーライド。
    override func handleInboundData(from flow: NEFilterFlow,
                                    readBytesStartOffset offset: Int,
                                    readBytes: Data) -> NEFilterDataVerdict
    override func handleOutboundData(from flow: NEFilterFlow,
                                     readBytesStartOffset offset: Int,
                                     readBytes: Data) -> NEFilterDataVerdict

    // flow 終端時の最終判定。必須オーバーライド。
    override func handleInboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict
    override func handleOutboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict

    // ユーザーがブロックページから remediate 要求した時。iOS のみ。
    override func handleRemediation(for flow: NEFilterFlow) -> NEFilterRemediationVerdict

    // Control が notifyRulesChanged() を呼んだ時。ルールを再読込する。iOS のみ。
    override func handleRulesChanged()
}
```

macOS 専用（iOS では使えない）: `applySettings`,
`resumeFlow(_:with:)`, `updateFlow(_:using:forDirection:)`。

### 起動・停止（基底 `NEFilterProvider`）

```swift
override func startFilter(completionHandler: @escaping (Error?) -> Void)
override func stopFilter(with reason: NEProviderStopReason,
                         completionHandler: @escaping () -> Void)

// 現在の構成（プロファイル/MDM 由来）。KVO 監視可。
var filterConfiguration: NEFilterProviderConfiguration { get }

// shouldReport を立てた verdict の結果通知。iOS 11+。
override func handleReport(_ report: NEFilterReport)
```

## Verdict 一覧

### NEFilterNewFlowVerdict（新規 flow 用）

```swift
.filterDataVerdict(filterInbound:peekInboundBytes:filterOutbound:peekOutboundBytes:)
    // 「最初の N bytes を見てから決める」。peek 用。
.allow()   // 通過
.drop()    // 遮断
.remediate(withRemediationURLMapKey:remediationButtonTextMapKey:)
    // iOS 標準のブロックページを表示。キーは Control の remediationMap 参照。
    // URL キーに nil を渡すと Data 側に handleRemediation(for:) が呼ばれる。
.urlAppendString(withMapKey:)  // URL への文字列付加（Safe Search 用等）
.needRules()  // Control に判断を委譲。iOS のみ。
```

共通プロパティ: `shouldReport`（iOS 11+。Control の `handleReport` へ通知。
`needRules` より軽い一方向の報告手段）。

### NEFilterDataVerdict（peek 後のデータ判定用）

```swift
.allow()
.drop()
.remediate(withRemediationURLMapKey:remediationButtonTextMapKey:)
.dataVerdictWithPassBytes(_:peekBytes:)  // さらに N bytes 通して M bytes 見る
.needRules()  // iOS のみ
```

### NEFilterControlVerdict（Control が返す用。iOS のみ）

```swift
.allow(withUpdateRules:)
.drop(withUpdateRules:)
.updateRules()  // 「ルールを置いたので Data 側で再判定して」
```

### NEFilterRemediationVerdict（`handleRemediation` の戻り。iOS のみ）

```swift
.allow()
.drop()
.needRules()
```

## NEFilterControlProvider（調達担当）

`NetworkExtension.NEFilterControlProvider` を継承する。Extension point は
`com.apple.networkextension.filter-control`。

```swift
final class FilterControlProvider: NEFilterControlProvider {

    // needRules  verdict に対する問合せ応答。必須オーバーライド。
    func handleNewFlow(_ flow: NEFilterFlow,
                       completionHandler: @escaping (NEFilterControlVerdict) -> Void)

    // remediate + needRules に対する応答。必須オーバーライド。
    func handleRemediation(for flow: NEFilterFlow,
                           completionHandler: @escaping (NEFilterControlVerdict) -> Void)

    // ブロックページに差し込む URL / ボタン文言の辞書。
    var remediationMap: [String: [String: NSObject]]?
    // 例: [NEFilterProviderRemediationMapRemediationURLs: ["Key1": "https://..."]]
    // URL 内で NE_FLOW_URL / NE_FLOW_HOSTNAME / NE_ORGANIZATION / NE_USERNAME が展開可。

    var urlAppendStringMap: [String: String]?

    // Data 側へ帯域外でルール変更を通知。iOS のみ。
    func notifyRulesChanged()
}
```

注意: Control 側に渡る `NEFilterBrowserFlow` の `request` / `response` は
常に nil（ヘッダー明記）。Control は通信内容を見られない。

## NEFilterFlow（判定対象）

```swift
// 基底 NEFilterFlow
var url: URL?                      // WebKit 由来の場合のみ非 nil
var sourceAppIdentifier: String?   // 通信元アプリの Bundle ID。iOS 11+。
var sourceAppVersion: String?      // iOS 11+
var sourceAppUniqueIdentifier: Data?  // ビルド単位の一意識別子。iOS 11+
var direction: NETrafficDirection  // iOS 13+
var identifier: UUID               // iOS 13.1+

// NEFilterBrowserFlow (FilterBrowsers=true, iOS のみ)
var request: URLRequest?   // Control 側では常に nil
var response: URLResponse? // レスポンス受信後に非 nil。Control 側では常に nil
var parentURL: URL?        // サブリソースを発生させた親ページ。なければ nil

// NEFilterSocketFlow (FilterSockets=true)
var remoteHostname: String?       // iOS 14+。Network.framework/URLSession 由来のみ。
var remoteFlowEndpoint: NWEndpoint?  // iOS 18+。こちらを使う。
var localFlowEndpoint: NWEndpoint?   // iOS 18+。こちらを使う。
var socketFamily: Int32   // PF_INET 等
var socketType: Int32     // SOCK_STREAM 等
var socketProtocol: Int32 // IPPROTO_TCP 等
```

非推奨: `remoteEndpoint` / `localEndpoint`（`NWEndpoint` 型）は
iOS 18 で deprecated。`remoteFlowEndpoint` / `localFlowEndpoint`
（`Network.NWEndpoint`）を使う。

注意:

- `remoteHostname` は BSD socket 直叩きの通信では nil になり得る。
  その場合は endpoint（IP）や socket 情報で判定する。
- endpoint は `handleNewFlow` 時点で nil のことがあり、データ受信後に
  設定される（ヘッダー明記）。nil を許容する実装にする。

## NEFilterProviderConfiguration（設定値の受渡し）

`filterConfiguration` で取得。MDM プロファイルのキーと対応する。

| プロパティ | 対応プロファイルキー | 備考 |
|---|---|---|
| `filterBrowsers` | `FilterBrowsers` | WebKit 通信を見るか |
| `filterSockets` | `FilterSockets` | socket 通信を見るか |
| `serverAddress` | `ServerAddress` | ルール取得先等の設定値。OS は解釈しない |
| `username` | `UserName` | |
| `organization` | `Organization` | |
| `vendorConfiguration` | `VendorConfig` | ベンダー独自辞書 |
| `passwordReference` | `Password`（+ keychain） | keychain 参照データ |
| `identityReference` | 証明書 payload | keychain 参照データ |

## NEFilterManager（本体アプリ側）

`NEFilterManager.shared()` で取得。構成の load / save / remove と有効化。

```swift
let manager = NEFilterManager.shared()
manager.loadFromPreferences { _ in
    manager.providerConfiguration = config  // NEFilterProviderConfiguration
    manager.localizedDescription = "..."
    manager.isEnabled = true
    manager.saveToPreferences { _ in }
}
```

注意: iOS で `isEnabled = true` にすると他アプリのフィルター構成は
無効化される（端末全体フィルターは同時に1つのみ）。
MDM 配布の構成は `NEFilterManager` では上書きできない。
