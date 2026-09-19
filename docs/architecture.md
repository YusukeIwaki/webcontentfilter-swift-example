# アーキテクチャ — 4者構成とデータフロー

iOS Web Content Filter（`FilterType = Plugin`）は、名前から想像される
「Safari プラグイン」ではなく、**MDM が端末内の Network Extension を指名し、
OS のネットワークスタックに Content Filter として組み込む仕組み**である。

## 登場人物

```text
MDM ── WebContentFilter payload ──▶ iOS
      FilterType = Plugin
      PluginBundleID = com.example.filter ──┐
                                            │ このアプリを使う
                                            ▼
                              ┌──────────────────────────────┐
                              │ Filter.app                   │
                              │                              │
                              │ NEFilterControlProvider      │  調達担当
                              │   filter.example.com から    │
                              │   ルール取得 → 共有領域へ書込 │
                              │              │               │
                              │              ▼               │
                              │     Shared App Group         │
                              │      (rules.db 等)           │
                              │              │               │
                              │              ▼               │
                              │ NEFilterDataProvider         │  判定担当
                              │   flow ごとに allow / drop / │
                              │   remediate / peek を返す    │
                              └──────────────────────────────┘
```

| 役割 | 実体 | できること | できないこと |
|---|---|---|---|
| MDM / プロファイル | `com.apple.webcontent-filter` payload | フィルターの有効化、設定値の配布 | 通信の観測・判定 |
| 本体アプリ | Filter.app | （Screen Time 経路では）`NEFilterManager` で構成登録 | フィルター処理自体 |
| Control Provider | `NEFilterControlProvider` appex | HTTPS 通信、ルール取得・保存、`notifyRulesChanged()` | 通信内容の観測（`request`/`response` は常に nil） |
| Data Provider | `NEFilterDataProvider` appex | flow 判定、peek、ブロックページ指示 | ネット・IPC・ディスク書込（App Group は読取専用） |

## 判定フロー

```text
Safari / WebView / アプリ
        │
        ▼
iOS Network Stack
        │
        ▼
NEFilterDataProvider.handleNewFlow(flow)
        │
        ├─ NEFilterBrowserFlow ── request.url / parentURL / sourceAppIdentifier で判定
        │
        └─ NEFilterSocketFlow ── remoteHostname / endpoint / port / protocol / sourceAppIdentifier で判定
        │
        ├─ allow ────────────────────────▶ 本来の接続先へ
        ├─ drop ─────────────────────────▶ 遮断
        ├─ remediate ────────────────────▶ iOS 標準のブロックページ表示
        ├─ filterData (peek N bytes) ────▶ handleInbound/OutboundData で再判定
        └─ needRules ──▶ Control に問合せ ──▶ allow/drop/updateRules
```

## ルール更新フロー

```text
filter.example.com
        │ HTTPS (Control のみ可)
        ▼
NEFilterControlProvider
        │ 書込
        ▼
Shared App Group (rules.db)
        │ 読取専用
        ▼
NEFilterDataProvider.handleRulesChanged()  ← notifyRulesChanged() で起動
```

ポイント:

- `ServerAddress` は「OS が通信を中継する宛先」ではない。
  Control Provider に渡される**設定値**（「ルール取得先はここ」）である。
  VPN の ServerAddress とは意味が全く異なる。詳細は
  [profile-reference.md](profile-reference.md)。
- Data Provider が直接サーバーへ問い合わせないのは意図的。
  判定者が外部送信できると「誰がどこへアクセスしたか」を漏らせるため、
  Apple が sandbox で封じている（[一次情報](references.md) 参照）。

## 見える情報の境界

```text
WebKit 通信 (FilterBrowsers=true)
  → NEFilterBrowserFlow: URL, NSURLRequest, parentURL, response(受信後)
  → iOS 自身が知っている情報を渡される。TLS 復号（MITM）ではない。

一般 socket 通信 (FilterSockets=true)
  → NEFilterSocketFlow: hostname/IP/port, socket family/type/protocol,
     sourceAppIdentifier, (peek すれば暗号化されたバイト列)
  → HTTPS 本文は読めない。

Control Provider 側
  → flow のメタ情報のみ。request/response は常に nil。
```

## iOS 26 URL Filter との関係

iOS 26+ では従来型に加え、OS 自身が高性能な URL 単位フィルタリングを行う
URL Filter API が追加された（Bloom prefilter + PIR による匿名判定）。
従来型 Data/Control Provider とは別建ての仕組み。
詳細は [url-filter-ios26.md](url-filter-ios26.md)。
