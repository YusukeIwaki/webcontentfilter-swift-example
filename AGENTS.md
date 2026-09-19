# AGENTS.md — webcontentfilter-swift-example

iOS Web Content Filter（Plugin サブタイプ）の Swift サンプル実装プロジェクト。
MDM 構成プロファイル + Network Extension（Data / Control Provider）で、
オンデバイスの通信フィルタリングを実現する。

## アーキテクチャ（4者構成）

```text
MDM (mobileconfig) ──設定を配布──▶ iOS
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             ▼                             │
        │  NEFilterDataProvider ── allow / drop / remediate / peek  │  判定する
        │        ▲                                                  │  (sandbox強、
        │        │ ルール共有 (Shared App Group, Data側は読取専用)     │   ネット不可)
        │        │                                                  │
        │  NEFilterControlProvider ── HTTPSでルール取得・更新        │  調達する
        │        ▲                                                  │  (ネット可、
        │        │ filter.example.com                              │   通信内容は不可視)
        │                                                     本体アプリ │
        │  本体アプリ ── NEFilterManager で構成登録/有効化 (Screen Time経路) │
        └───────────────────────────────────────────────────────────┘
```

詳細は [docs/architecture.md](docs/architecture.md)。

## 不変条件（実装前に必ず押さえる）

- **Filter ≠ VPN/Proxy**。通信を外部サーバーへ転送しない。判定は端末内で完結する。
- **HTTPS 本文は読めない**。Socket flow の TLS ペイロードは暗号化されたまま。
  WebKit 由来の通信のみ `NEFilterBrowserFlow` として URL / request / parentURL が見える（MITM ではない）。
- **Data / Control の分離はプライバシー設計**。Data は通信内容を見られるが外部送信不可、
  Control は通信できるが内容を見られない（`request`/`response` は Control 側では常に nil）。
- **Data 側の永続化は Shared App Group の読取のみ**。書くのは Control 側。
  ルール更新通知は `notifyRulesChanged()` → `handleRulesChanged()`。
- **iOS では端末全体フィルターは同時に1つのみ**（`NEFilterManager.isEnabled`
  を立てると他アプリのフィルターは無効化される）。

## デプロイ経路（TN3134準拠）

| 経路 | 条件 | 最小OS |
|---|---|---|
| MDM + 構成プロファイル（端末全体） | Supervised 端末 | iOS 9 |
| Screen Time（Family Controls） | 18歳未満 child + 親承認 | iOS 15 |
| Per-App（managed app のみ対象） | MDM + `ContentFilterUUID` | iOS 16 |
| URL Filter（新API、別建て） | 制限なし（プロファイル駆動） | iOS 26 |

詳細は [docs/deployment.md](docs/deployment.md)。

## リポジトリ構成（予定）

```text
.agents/skills/ios-content-filter/  プロジェクトスキル（本ドメインの開発知識）
docs/                               詳細ドキュメント（API・プロファイル・URL Filter等）
FilterApp/                          本体アプリ (NEFilterManager 操作・UI) ※未作成
FilterDataProvider/                 Data Provider appex ※未作成
FilterControlProvider/              Control Provider appex ※未作成
profiles/                           検証用 .mobileconfig ※未作成
```

## 開発規約

- 言語は Swift（既存 Obj-C ラッパー不要）。API の正本は SDK ヘッダー。
  署名に迷ったら `docs/content-filter-api.md` を見て、それでも不明なら
  Xcode の `NetworkExtension.framework/Headers` を直接確認する。
- iOS 18+ では `NEFilterSocketFlow.remoteEndpoint` を使わない。
  `remoteFlowEndpoint`（`Network.NWEndpoint`）を使う（前者は deprecated）。
- Data Provider にネットワーク・IPC・書込みを持ち込まない。
  ルールの取得・更新は必ず Control 側に寄せる。
- プロファイルのキー仕様は [docs/profile-reference.md](docs/profile-reference.md) が正本。
  `PluginBundleID`（必須）と `UserDefinedName`（必須）を忘れない。
- 新機能の検討時は `docs/url-filter-ios26.md` を確認し、
  従来型 Content Filter でやるべきか URL Filter でやるべきかを切り分ける。

## ドキュメント索引

- [docs/architecture.md](docs/architecture.md) — 4者構成とデータフロー
- [docs/content-filter-api.md](docs/content-filter-api.md) — Swift API リファレンス（従来型）
- [docs/profile-reference.md](docs/profile-reference.md) — mobileconfig キー仕様（Plugin）
- [docs/deployment.md](docs/deployment.md) — デプロイ経路・entitlement・Xcode 設定
- [docs/url-filter-ios26.md](docs/url-filter-ios26.md) — iOS 26 URL Filter
- [docs/references.md](docs/references.md) — 一次情報リンク集

## スキル

`.agents/skills/ios-content-filter/` — このリポジトリで Content Filter
開発を行うエージェント向けの要点集。本文書と docs/ を正本として参照する。
