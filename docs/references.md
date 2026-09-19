# 一次情報リンク集

本リポジトリのドキュメントは以下を正本として作成した。
仕様の疑義は必ず一次情報を当たり、推定で書かないこと。

## Apple 公式ドキュメント

- TN3134: Network Extension provider deployment（デプロイ要件の正本）
  <https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment>
  Markdown 版: 同 URL + `.md`
- Content filter providers（Data/Control 分離・sandbox の説明）
  <https://developer.apple.com/documentation/networkextension/content-filter-providers>
- WebContentFilter（MDM payload キー仕様）
  <https://developer.apple.com/documentation/devicemanagement/webcontentfilter>
- URL filters（iOS 26+）
  <https://developer.apple.com/documentation/networkextension/url-filters>

## SDK（API 署名の正本）

Xcode の iPhoneOS.sdk 内:

- `NetworkExtension.framework/Headers/NEFilterDataProvider.h`
- `NetworkExtension.framework/Headers/NEFilterControlProvider.h`
- `NetworkExtension.framework/Headers/NEFilterProvider.h`（基底・verdict・report）
- `NetworkExtension.framework/Headers/NEFilterFlow.h`
- `NetworkExtension.framework/Headers/NEFilterProviderConfiguration.h`
- `NetworkExtension.framework/Headers/NEFilterManager.h`
- `NetworkExtension.framework/Headers/NEURLFilter.h`
- `NetworkExtension.framework/Modules/NetworkExtension.swiftmodule/*.swiftinterface`
  （`NEURLFilterControlProvider` / `NEURLFilterPrefilter` / `NEURLFilterManager`）

## その他

- 本知識ベースの起点となった共有チャット「iOS Webコンテントフィルタープラグイン解説」
  <https://chatgpt.com/share/6aad426a-8b3c-83e8-90d7-7ef30ec1e9c6>
  内容は上記一次情報で検証済み。チャットの記述と一次情報が競合した場合は一次情報を優先する。
- Apple Developer Forums の Quinn 回答集（The Wisdom of Quinn）:
  Network Extension entitlements / デプロイ制限の背景理解に有用。
