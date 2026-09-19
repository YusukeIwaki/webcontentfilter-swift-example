# mobileconfig リファレンス（WebContentFilter / Plugin）

`PayloadType = com.apple.webcontent-filter`、
`FilterType = Plugin` の場合のキー仕様。
正本は Apple Device Management ドキュメント。

## 必須キー

| キー | 型 | 説明 |
|---|---|---|
| `PluginBundleID` | string | フィルターを提供する**アプリ**の Bundle ID。OS がこの値で構成とアプリを関連付け、内包の Network Extension を起動する |
| `UserDefinedName` | string | 設定に表示される構成の表示名 |

`PluginBundleID` は「Extension 自体を直接指す」ものではなく、
**Provider extension を内包するアプリと構成を関連付ける ID**と理解する。

## 任意キー（Plugin 用）

| キー | 型 | 既定 | 説明 |
|---|---|---|---|
| `FilterBrowsers` | bool | false | WebKit 通信を `NEFilterBrowserFlow` として渡す |
| `FilterSockets` | bool | false | socket 通信を `NEFilterSocketFlow` として渡す |
| `ServerAddress` | string | — | IP / hostname / URL。Provider への**設定値**（下記） |
| `UserName` | string | — | サービス用ユーザー名 |
| `Password` | string | — | サービス用パスワード |
| `Organization` | string | — | プラグインへ渡す組織名 |
| `PayloadCertificateUUID` | string | — | 同一プロファイル内証明書 payload の UUID（認証用） |
| `VendorConfig` | dict | — | ベンダー独自辞書 |
| `ContentFilterUUID` | string | — | Per-App フィルター用 ID（iOS 16+。教師なし/User Enrollment では必須） |
| `FilterURLs` | bool | false | iOS 26+ URL Filter を有効化（`URLFilterParameters` が必須に） |
| `URLFilterParameters` | dict | — | iOS 26+ URL Filter 用パラメータ（[別紙](url-filter-ios26.md)） |

`FilterBrowsers` / `FilterSockets` の少なくとも一方を true にしないと
フィルターは実質何もしない。

## PluginBundleID と ServerAddress の切り分け（重要）

```text
PluginBundleID ──「誰がフィルターするの？」
    → OS が意味を理解して使う。アプリと構成の紐付け。

ServerAddress ──「そのフィルター製品のバックエンドはどこ？」
    → OS は解釈しない。Provider に設定として渡すだけ。
```

```text
                   MDM
                    │
         WebContentFilter payload
                    │
        ┌───────────┴────────────┐
        │                        │
 PluginBundleID              ServerAddress
 com.example.filter          filter.example.com
        │                        │
        │ このアプリを使う       │ 設定値として渡す
        ▼                        ▼
┌──────────────────────────────────────────┐
│ com.example.filter                       │
│                                          │
│  NEFilterControlProvider                 │
│       │  filterConfiguration.serverAddress を参照
│       │  HTTPS でルール取得               │
│       ▼                                  │
│  Shared App Group (rules.db)             │
│       │                                  │
│       ▼                                  │
│  NEFilterDataProvider ── allow / drop    │
└──────────────────────────────────────────┘
```

よくある誤解:

- `ServerAddress` を書いてもプロキシ構成には**ならない**。
  通信が `filter.example.com` を経由することはない。
- `ServerAddress` は省略可。ルールをアプリ内蔵にして外部更新しない設計なら不要。
- `VendorConfig` との違いは「Apple が標準化した枠か、ベンダー独自か」のみ。
  `serverAddress` / `username` / `organization` / `vendorConfiguration`
  として Provider 側に渡る。

## 設定値の対応表

| プロファイルキー | Provider 側の参照先 |
|---|---|
| `ServerAddress` | `filterConfiguration.serverAddress` |
| `UserName` | `filterConfiguration.username` |
| `Organization` | `filterConfiguration.organization` |
| `VendorConfig` | `filterConfiguration.vendorConfiguration` |
| `Password` | `filterConfiguration.passwordReference`（keychain 参照） |
| 証明書 payload | `filterConfiguration.identityReference`（keychain 参照） |

## サンプル

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>FilterType</key>
            <string>Plugin</string>
            <key>PluginBundleID</key>
            <string>com.example.filter</string>
            <key>UserDefinedName</key>
            <string>Example Filter</string>
            <key>FilterBrowsers</key>
            <true/>
            <key>FilterSockets</key>
            <true/>
            <key>ServerAddress</key>
            <string>https://filter.example.com</string>
            <key>Organization</key>
            <string>Example Inc.</string>
            <key>VendorConfig</key>
            <dict>
                <key>tenantId</key>
                <string>customer-123</string>
                <key>policyId</key>
                <string>school-policy</string>
            </dict>
            <key>PayloadIdentifier</key>
            <string>com.example.filter.webcontentfilter</string>
            <key>PayloadType</key>
            <string>com.apple.webcontent-filter</string>
            <key>PayloadUUID</key>
            <string>PUT-UUID-HERE</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>Example Filter Profile</string>
    <key>PayloadIdentifier</key>
    <string>com.example.filter.profile</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>PUT-UUID-HERE</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
```

## Per-App フィルター（iOS 16+）

WebContentFilter payload に `ContentFilterUUID` を入れ、
対象 Managed App の属性にも同じ `ContentFilterUUID` を設定すると、
そのアプリ群の通信だけがフィルター対象になる。
User Enrollment / BYOD を想定した機能で、
教師なし端末・User Enrollment では `ContentFilterUUID` が必須。
