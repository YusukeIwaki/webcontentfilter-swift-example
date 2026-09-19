# iOS 26 URL Filter

iOS 26+ で追加された、従来型 Content Filter とは別建ての仕組み。
OS 自身が URL 単位の高性能フィルタリングを行い、ベンダー側は
Bloom prefilter の配布と PIR サーバーの運用を担う。

## 構成要素

```text
WebContentFilter payload (FilterURLs=true, URLFilterParameters={...})
        │
        ▼
iOS (URL 要求を横取りして判定)
        │
        ├─ オンデバイス Bloom prefilter で一次判定
        │     ▲
        │     │ NEURLFilterControlProvider.fetchPrefilter() で定期取得
        │     │ (既定 86400s, 最小 2700s)
        ▼     │
PIR 交換で確定判定（問合せ URL を事業者に晒さない）
  PIRServerURL / PIRPrivacyPassIssuerURL / PIRAuthenticationToken
        │
        ▼
allow / deny (+ URLFilterFailClosed で失敗時ポリシー)
```

## プロファイルキー

`FilterURLs = true` のとき `URLFilterParameters` が必須。

| キー | 必須 | 説明 |
|---|---|---|
| `URLFilterControlProviderBundleIdentifier` | Yes | URL filter control provider appex の Bundle ID |
| `URLFilterControlProviderDesignatedRequirement` | macOS で必須 | appex の designated requirement |
| `PIRServerURL` | Yes | Private Information Retrieval サーバーの URL |
| `PIRPrivacyPassIssuerURL` | Yes | Privacy Pass Issuer の URL |
| `PIRAuthenticationToken` | Yes | ユーザー単位の Bearer [REDACTED]。PIR 交換用の匿名認証トークン取得に使用 |
| `URLFilterFailClosed` | No（既定 false） | true なら判定不能時（PIR 通信失敗等）にブロック。false なら許可 |
| `URLPrefilterFetchFrequency` | No（既定 86400） | prefilter 再取得の間隔（秒）。最小 2700 |

## Swift API（SDK 確認済み）

`NEURLFilterControlProvider` は Swift ネイティブの protocol
（`ExtensionFoundation.AppExtension` 準拠）。iOS 26+。

```swift
public protocol NEURLFilterControlProvider: AppExtension {
    func start() async throws
    func stop(reason: NEProviderStopReason) async throws
    func fetchPrefilter(existingPrefilterTag: String?) async throws -> NEURLFilterPrefilter?
}

public struct NEURLFilterPrefilter {
    public enum PrefilterData {
        case smallFilter(Data)
        case temporaryFilepath(URL)
    }
    public let tag: String
    public let data: PrefilterData
    public let bitCount: Int
    public let hashCount: Int
    public let murmurSeed: UInt32
}
```

`bitCount` / `hashCount` / `murmurSeed` の存在が示す通り、
prefilter は Murmur ハッシュの Bloom filter である。

関連 API:

- `NEURLFilter.verdict(for: URL) async -> NEURLFilter.Verdict`
  （`.unknown` / `.allow` / `.deny`）— Apple 製ネットワーキング枠組みを
  使わないアプリが自発的に URL を検証するための API。
  ヘッダー曰く「Deny の URL には接続すべきでない」。
- `NEURLFilterManager.shared` — `isEnabled` / `shouldFailClosed` /
  `prefilterFetchInterval` 等の管理オブジェクト。
- Entitlement 値: `url-filter-provider`。
- TN3134: iOS / macOS とも app extension、最小 OS 26.0、特段の制限なし。

## 従来型との使い分け

| 観点 | 従来型 Content Filter | URL Filter |
|---|---|---|
| 判定主体 | 自作 Data Provider（flow 単位） | OS（URL 単位） |
| 可視情報 | flow メタ・peek バイト | 完全な URL |
| ルール形式 | 自由（自作） | Bloom prefilter + PIR サーバー |
| プライバシー | sandbox 分離で担保 | PIR で問合せ URL を秘匿 |
| 最小OS | iOS 9（Supervised）/ 15 / 16 | iOS 26 |
| 向き | socket 単位制御・per-app・独自ポリシー | 大規模 URL ブロックリスト |

## 注意

- URL Filter の Control Provider 拡張種別・Info.plist 設定の詳細は、
  本書作成時点では MDM キー（`URLFilterControlProviderBundleIdentifier`）
  と Swift protocol 定義からの推定に留まる。実装時は WWDC セッションと
  最新ドキュメント（`NetworkExtension/url-filters`）で裏を取ること。
- 本リポジトリの当面の PoC 対象は従来型 Content Filter。
  URL Filter は調査・将来対応の位置付け。
