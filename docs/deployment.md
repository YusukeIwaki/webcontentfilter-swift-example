# デプロイ・Xcode 設定

## デプロイ経路（TN3134準拠）

Content Filter Provider（従来型）の iOS 要件:

| 梱包 | 最小OS | 制限 |
|---|---|---|
| app extension | iOS 9 | **Supervised 端末のみ**（MDM 配布の構成プロファイル） |
| app extension | iOS 15 | Screen Time API 利用アプリ（child 端末 + 親承認） |
| app extension | iOS 16 | Per-App（managed device の managed app のみ対象） |

補足:

- Screen Time 経路では本体アプリに Family Controls capability が必要で、
  18歳未満の child として承認された端末でのみ動作する。
  App Store 提出前に Family Controls entitlement の利用許可申請が必要。
- Per-App では MDM が `ContentFilterUUID` でフィルターと対象アプリを紐付ける。
  対象アプリは MDM 経由インストールが必須。
- URL Filter（iOS 26+）は別建てで、TN3134 上は特段の制限なし。
  [url-filter-ios26.md](url-filter-ios26.md) 参照。

## Entitlement / Capability

Network Extension capability を有効化し、Content Filter を選択する。
entitlement の実体:

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>content-filter-provider</string>
</array>
```

- 本体アプリと両 appex（Data / Control）に付与する。
- Team ID を揃え、App Group（ルール共有用）を3ターゲット共通で有効化する。
  Data 側は読取専用として扱う（[architecture.md](architecture.md)）。
- URL Filter 用には別値 `url-filter-provider` がある。

## Xcode ターゲット構成

```text
FilterApp/                  本体アプリ
  Info.plist
  FilterApp.entitlements     (networkextension + app-group)
FilterDataProvider/         Network Extension ターゲット
  Info.plist                (NSExtensionPointIdentifier 下記)
  FilterDataProvider.entitlements
FilterControlProvider/      Network Extension ターゲット
  Info.plist
  FilterControlProvider.entitlements
```

Extension point（Xcode 定義で確認済み）:

| ターゲット | NSExtensionPointIdentifier | Principal class |
|---|---|---|
| Data | `com.apple.networkextension.filter-data` | `NEFilterDataProvider` サブクラス |
| Control | `com.apple.networkextension.filter-control` | `NEFilterControlProvider` サブクラス |

Info.plist（Data 側の例）:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.networkextension.filter-data</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).FilterDataProvider</string>
</dict>
```

## 検証

- 端末全体フィルターの動作確認には Supervised 端末 + MDM（または
  Apple Configurator でのプロファイル投入）が必要。
  シミュレーターでは Network Extension のフィルタリング動作は検証できない。
- 検証用プロファイルは `profiles/` に `.mobileconfig` として置く
  （[profile-reference.md](profile-reference.md) のサンプルを起点にする）。
- デバッグ時は Data / Control の2プロセスにアタッチする必要がある。
  Xcode の Debug → Attach to Process で各 appex を選択する。
- `NEFilterManager` 経路（Screen Time 以外）で保存した構成は、
  MDM 配布の構成とは別物。PoC ではどちらで有効化したかを混同しないこと。
