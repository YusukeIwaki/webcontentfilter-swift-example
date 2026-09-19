# サンプルアプリ — コンポーネントと責務

`FilterApp` / `FilterDataProvider` / `FilterControlProvider` の3ターゲット構成。
各プロセスの責務が一目で分かることを優先した最小実装。

## 責務分担

| ターゲット | 種別 | 役割 | できること | しないこと |
|---|---|---|---|---|
| FilterApp | 本体アプリ | 登録・表示係 | `NEFilterManager` で構成の load/save/有効化、状態とルールの表示 | 通信の判定・ルールの編集 |
| FilterDataProvider | appex (`filter-data`) | 判定係 | flow ごとの allow / drop / remediate、`handleRulesChanged` で再読込 | ネット・IPC・書込（App Group は読取専用） |
| FilterControlProvider | appex (`filter-control`) | 調達係 | `serverAddress` から rules.json 取得→App Group へ保存、`notifyRulesChanged`、remediationMap 公開 | 通信内容の観測 |
| FilterShared | 共通ソース（3者にコンパイル組込） | 型とIO | `FilterRules` モデル＋照合、`RuleStore` の load/save、App Group 定数 | ビジネスロジック |

```text
FilterControlProvider ──HTTPS──▶ filter.example.com/rules.json
        │ 書込
        ▼
Shared App Group (rules.json) ◀── FilterApp は表示のみ
        │ 読取
        ▼
FilterDataProvider ── allow / drop / remediate ──▶ ネットワークスタック
```

ソース配置は [AGENTS.md](../AGENTS.md) の構成図を参照。

## ビルド

```sh
xcodegen generate   # ContentFilter.xcodeproj を生成（コミット対象外）
./adhoc_build.sh    # archive → IPA 書き出しまで自動実行
# 成果物: build/adhoc/export/FilterApp.ipa
```

- `TEAM_ID`（既定 `6KG5EF3BN2`）、`EXPORT_METHOD`（既定 `release-testing`）
  は環境変数で上書き可。
- Xcode 26 で `ad-hoc` は非推奨名になったため既定は `release-testing`
  （登録デバイス向けテストIPAという意味は同じ）。

## 署名の前提条件（初回のみ手作業）

CLI の自動署名だけでは完結しないため、初回は以下が必須。

1. ポータルで App Group `group.io.github.yusukeiwaki.exampleswiftwebcontentfilter` を作成。
2. 3つの App ID（本体・`.data`・`.control`）に Network Extensions +
   App Groups（手順1の group を選択）を付与し、Save → Confirm まで完了。
3. チーム用の Apple Development 証明書をこの Mac に用意
   （秘密鍵が手元にあること）。
4. Xcode > Settings > Accounts に Apple ID を追加。

2回目以降は `./adhoc_build.sh` のみで回る。スクリプトは毎回
xcodegen 再生成 → capability 宣言 → Xcode 管理プロファイルの掃除 →
archive → export を行う。

## xcodegen 運用の注意（重要）

- `*.entitlements` は **xcodegen が所有**する。`project.yml` の
  `entitlements.properties` が正本であり、`xcodegen generate` 実行で
  ファイルが上書きされる。entitlements を直書きしても消える。
- `SystemCapabilities`（Signing & Capabilities 相当）は xcodegen が
  表現できないため、`adhoc_build.sh` 内の `declare_capabilities` が
  生成直後の pbxproj に注入する。Xcode GUI で開く場合も
  `./adhoc_build.sh` 経由の生成物を推奨。
- 生成物（`*.xcodeproj`、`build/`、`.ipa`）はコミットしない。
