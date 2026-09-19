# webcontentfilter-swift-example

iOS Web Content Filter（`FilterType = Plugin`）の Swift サンプル実装プロジェクト。
MDM 構成プロファイル + Network Extension（Data / Control Provider）による
オンデバイス通信フィルタリングを、動くコードで学ぶためのリポジトリ。

## ビルド

```sh
xcodegen generate
./adhoc_build.sh   # → build/adhoc/export/FilterApp.ipa
```

初回の署名前提条件は [docs/sample-app.md](docs/sample-app.md) 参照。

## 入り口

- [AGENTS.md](AGENTS.md) — 全体像・不変条件・開発規約（エージェントも人間もまずここ）
- [docs/architecture.md](docs/architecture.md) — 4者構成とデータフロー
- [docs/content-filter-api.md](docs/content-filter-api.md) — Swift API リファレンス
- [docs/profile-reference.md](docs/profile-reference.md) — mobileconfig キー仕様
- [docs/deployment.md](docs/deployment.md) — デプロイ経路・entitlement・Xcode 設定
- [docs/url-filter-ios26.md](docs/url-filter-ios26.md) — iOS 26 URL Filter
- [docs/references.md](docs/references.md) — 一次情報リンク集
- [docs/sample-app.md](docs/sample-app.md) — サンプル構成・ビルド・署名手順
- `.agents/skills/ios-content-filter/` — 開発用プロジェクトスキル
