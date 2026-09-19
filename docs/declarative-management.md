# 宣言型デバイス管理（DDM）— WebContentFilter Plugin

構成プロファイル（`profiles/ExampleFilter.mobileconfig`）を使わない配布方法。
MDM サーバーが Declaration プロトコルで配信する JSON。

正本スキーマ: [`webcontent-filter.plugin.yaml`](https://github.com/apple/device-management/blob/release/declarative/declarations/configurations/webcontent-filter.plugin.yaml)
（`com.apple.configuration.webcontent-filter.plugin`）

## 前提・注意

- **iOS 27.0+ が必要**（スキーマの `introduced: '27.0'`）。それ以前の OS は
  構成プロファイル版を使うこと。
- 許可される登録形態: supervised / device / user / local。スコープは system。
- `apply: multiple` のため複数宣言を共存できる。
- 本リポジトリの宣言例: [../declarations/webcontent-filter-plugin.json](../declarations/webcontent-filter-plugin.json)
  （mobileconfig 版と同等の設定内容）。

## 宣言エンベロープ

ペイロードの鍵はスキーマ通りだが、DDM では以下の外枠が必須。

| フィールド | 説明 |
|---|---|
| `Type` | `com.apple.configuration.webcontent-filter.plugin` 固定 |
| `Identifier` | 宣言の一意識別子（MDM サーバー管理） |
| `ServerToken` | 同期用トークン。内容変更のたびに MDM サーバーが更新する |
| `Payload` | 下記の設定本体 |

## プロファイルとの対応表

| mobileconfig キー | DDM での指定先 | 備考 |
|---|---|---|
| `UserDefinedName` | `Payload.VisibleName`（必須） | 表示名 |
| `PluginBundleID` | `Payload.PluginBundleID`（必須） | フィルターアプリの ID |
| `FilterBrowsers` | `Payload.Filter.Browsers.Enabled` | 省略時は無効 |
| `FilterSockets` | `Payload.Filter.Sockets.Enabled` | 省略時は無効 |
| （なし） | `Payload.Filter.Sockets.ProviderComposedIdentifier` | **Enabled=true なら必須**。iOS では Data Provider appex の Bundle ID（本サンプルでは `....contentfilter.data`） |
| `ServerAddress` | `Payload.ServerAddress` | 任意 |
| `Organization` | `Payload.Organization` | 任意 |
| `VendorConfig` | `Payload.VendorConfig` | 任意辞書 |
| `UserName` / `Password` | `Payload.Authentication.CredentialsAssetReference` | 資産宣言への参照（後述） |
| 証明書 payload | `Payload.Authentication.IdentityAssetReference` | 資産宣言への参照（後述） |
| `ContentFilterUUID` | `Payload.ContentFilterUUID` | Per-App 用。教師なし/User Enrollment では必須 |
| `FilterURLs` 系 | `Payload.Filter.URLs.*` | iOS 26+ の URL Filter（[別紙](url-filter-ios26.md)）。DDM 宣言自体は iOS 27+ の枠組み |

## 関連 asset・configuration の要否

**本サンプルの最小構成では不要。** 宣言1件のみで動作する。
以下は使う場合だけ追加する。

### 1. ユーザー名/パスワード認証を使う場合

`Authentication.CredentialsAssetReference` に
`com.apple.asset.credential.userpassword` 資産宣言の Identifier を指定し、
資産宣言を別途配信する。

```json
{
  "Type": "com.apple.asset.credential.userpassword",
  "Identifier": "filter-service-credentials",
  "ServerToken": "example-server-token-0002",
  "Payload": {
    "UserName": "filter-user",
    "Password": "REPLACE-ME"
  }
}
```

### 2. 証明書認証を使う場合

`Authentication.IdentityAssetReference` に以下のいずれかの資産宣言を指定する。

- `com.apple.asset.credential.identity`（証明書同梱）
- `com.apple.asset.credential.scep` / `.acme`（動的発行）

mobileconfig の `PayloadCertificateUUID` に相当する。

### 3. URL Filter の PIR を使う場合

`Filter.URLs.Parameters.PIR.AuthenticationTokenAssetReference` に
Bearer [REDACTED] 入りの `userpassword` 資産（`Password` フィールドにトークン）を
指定する。上記1と同型の資産宣言を追加する。

### 4. Per-App フィルターにする場合

別の configuration 宣言は不要。代わりに以下が必要。

- 本宣言に `ContentFilterUUID` を含める。
- 対象 Managed App 側のアプリ属性（app attributes）に**同一の**
  `ContentFilterUUID` を設定する（アプリ配布時の MDM サーバー設定）。

### 不要なもの

- Data/Control Provider 用の追加 configuration はない。`Sockets` の
  `ProviderComposedIdentifier` で Data Provider を指名するだけである。
- フィルターアプリ自体のインストールは通常のアプリ配布で行う
  （宣言とは別枠）。
