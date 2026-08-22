# RASQ Client 第一期 実装計画

最終更新: 2026-08-22
根拠資料: `SNSブラウザ(RASQ) 何をやる.md` / `RASQ_UI_Elements.md` / `RASQ_UI_status.md` / `現状の全てのワイヤーフレーム.pdf` / Qwen壁打ちログ(決定台帳 D-000〜D-004)

> 書き方のルール: 各項目に【決定】【提案】【未決】を付ける。【決定】には根拠(原典:資料名 / 確認:日付 / 導出:D-XXX)を添える。根拠が書けないものは【決定】にしない(D-000準拠)。

---

## 0. 第一期のスコープ

### 0.1 第一期に含めるもの【決定 / 原典:何をやる.md】

| 領域 | 内容 | 備考 |
|---|---|---|
| タイムラインプロバイド | SNSプラグイン(イベントハンドラー部=function.json + 画面コンストラクタ部=RRL)→レンダラー→TL | RRL/FOW/レンダラーの土台そのもの |
| リレーショナルTL | フォロイー投稿+トレンドから類似投稿をまとめるTL(sbert蒸留+mT5ざっくり要約+Rouvain) | モデル実行はオンデバイス前提。後から差し替え可能な構成にする |
| トレンド | SNSトレンド+AsTell+リレーショナルTL見出しの統合、指向性/刺激性、トレンドプロバイダープラグイン | 検索ホームに埋め込み |
| 投稿コンポーザー | FOW(interstitial)+全画面子FOWでのファイル編集、Stickオプション、予測変換Hook | 絵文字/MFM/投票/画像編集 |
| AsTell(VC) | VCホーム/参加/作成/共有/文字起こし/退出、WebRTC+WebTransport | サーバー側(ピア/ログ/配信)が別途必要 |
| 通常DM | SNSプラグイン経由のDM(限定公開をDM扱いにするSNS含む) | RASQアカウントDMは第二期 |
| プラグインストア | ストアホーム/プラグインページ/管理/インストール(Zstd+SHA-512+署名)/レビュー/自動アップデート | サーバー側も第一期。別リポ `ORGATE-server`(1リポで足りる想定)。クライアント側契約をこちらで先に定義して共有 |
| メディアビューワープラグイン | 全画面表示時の呼び出しボタン→RRLをシームレスに画面へ描画(画像翻訳など) | 新設プラグイン種(D-004 ③)。TL内スロットでは内容変換不可 |
| RAi(インストラクションモードのみ) | リファレンス(ActionReference.jsonl)をローカルハイブリッドDB(SQLite+vector)で検索→画面上のコンポーネント位置へRAiウィジェットを移動 | アシスタント/マクロは第二期 |
| 基盤画面 | ログイン(マルチPDS)/利用規約/通知/ユーザーページ/プロフィール編集/フォロー関連/リスト/ミュート・ブロック/設定/サイドバー/エラー・空状態 | UI_status「完了」群 |

### 0.2 第一期に含めないが「口だけ用意する」もの【決定 / 原典:何をやる.md 注釈】

- データスクレイパー/リスト(サーバー側): **サーバーフォールアップ関数の呼び出し口**(インターフェース)のみ定義
- RASQアカウントDM: **SNSアカウント→RASQアカウントの表示**(AsTellでも使う)のみ実装、送受信は未実装
- RAiアシスタント/マクロモード: RAiホームの画面枠とモード切替トグルのみ
- プラグインコンストラクションモード(第四期): なし

### 0.3 第一期でも後回しにしてよいもの【提案】

- Web版全般(UI_status: アプリ版完成後)
- チャイルドセーフ(設定変更はWebコンソール完結のため、アプリ側は第一期末に制限TL/投稿回数表示だけ入れる)
- 初回オンボーディング(プラグインなし最小フローを先に固めてから)

---

## 1. アーキテクチャ方針

### 1.1 全体像【提案】

```
┌──────────────────────────── rasq_client (Flutter app) ────────────────────────────┐
│ app shell (layout / nav / header 4種 / routing)                                   │
│ ├─ Overlay Manager  ←─ L4 Host-owned Surface (FOW / BottomSheet / Modal / Dropdown)│
│ ├─ Store / Signal   ←─ 「状態はDSLの外」。SNSプラグイン→Store→Props                  │
│ ├─ Design System    ←─ tokens(色/spacing/最小タップ域) + L2 Standard Components    │
│ ├─ Screens          ←─ ワイヤーフレーム各画面。L2部品+Storeで組む                     │
│ └─ Plugin Host      ←─ SnsPlugin インターフェース(Dart直書き実装 ↔ WASMプラグイン)    │
│        │                                                                           │
│        ▼                                                                           │
│   RRL Renderer (rrl_core / rrl_renderer)                                          │
│   Snapshot+Patch 受信 → 境界再検証 → L1-L3ノード → Widget化 / イベント→ActionRef     │
│        ▲                                                                           │
│   WASM Runtime (plugin_runtime) ← iOSはインタープリタ前提                            │
└────────────────────────────────────────────────────────────────────────────────────┘
```

- **「Dart直書きSNSアダプタ」を先に作り、WASMプラグインと同じ `SnsPlugin` 契約を満たさせる**。これで画面側の実装がRRL/WASMの完成を待たずに進み、後からWASM版へ差し替えられる。
- L2 Standard Component は**ホスト実装**(D-002)。RRLからは Props 供給のみ。画面側も同じ部品を直接使うので、第一期で作る部品が後でそのままRRLの標準部品になる。
- Overlay Manager / Listレイアウトルール / FOWタイプ権限は**レンダラー側サービス**(Qwenログ §1 統合方針3)として独立。

### 1.2 パッケージ分割【提案】 — Dart pub workspace(モノレポ)

| パッケージ | 役割 | 依存 |
|---|---|---|
| `/`(ワークスペースルート=`rasq_client` アプリ本体) | Flutterアプリ(画面・ルーティング・DI)。既存の platform フォルダを動かさないためルートに据え置き | 下記すべて |
| `packages/rasq_design` | デザイントークン、テーマ、L2 atomic/composite部品 | flutter |
| `packages/rasq_overlay` | Overlay Manager(階層・スタック/排他・クローズ挙動・競合ルール) | flutter |
| `packages/rasq_store` | Store/Signal、既読・アクション状態・フォロー状態、キャッシュ(TTL/容量) | — |
| `packages/rasq_plugin_api` | `SnsPlugin` 等のホスト側インターフェース、function.json スキーマ、ActionRef、エラーコード体系 | — |
| `packages/rrl_core` | RRLノードモデル(L1〜L4)、Snapshot/Patch/Call/Lifecycle 型、検証ゲート、安定ID | — |
| `packages/rrl_renderer` | RRL→Widget、イベントルーティング、geometry registry(RAi位置検索/role検証共用)、AdSlot挿入 | rrl_core, rasq_design, rasq_overlay |
| `packages/plugin_runtime` | WASMランタイム抽象+実装、境界シリアライズ、プラグインのライフサイクル/クラッシュ隔離 | rrl_core, rasq_plugin_api |
| `packages/sns_bluesky` / `sns_misskey` / `sns_mastodon` | Dart直書きSNSアダプタ(第一期の実稼働経路) | rasq_plugin_api |
| `packages/rasq_models` | 共通データモデル(Post/User/Notification/DM/Poll/Media…)、freezed | — |

> 【決定 / 確認: 2026-08-22】pub workspace モノレポで開始。RRL/ランタイムは将来プラグインSDKとしても切り出すため、最初からパッケージ境界を切る。サーバー側は別リポ `ORGATE-server`。

### 1.3 技術選定【提案 / 要検証】

| 項目 | 候補 | 理由 / 注意 |
|---|---|---|
| 状態管理 | `flutter_riverpod`(+ `riverpod_generator`) | 【決定 / 確認: 2026-08-22】「状態はDSLの外」原則に合う。Store/SignalをProviderで表現 |
| ルーティング | `go_router` | タブレット2ペイン/ディープリンク(Push通知→投稿詳細/ブックマーク)に対応しやすい |
| モデル | `freezed` + `json_serializable` | 不変モデル、RRLノードのパターンマッチ |
| ローカルDB/キャッシュ | `drift`(SQLite) | TL/DMキャッシュ、RAiハイブリッドDB(SQLite+vector拡張)と同系 |
| 秘匿ストレージ | `flutter_secure_storage` | アクセストークン(通知専用トークン含む) |
| Bluesky | `bluesky` / `atproto`(atproto.dart) | PDS変更・マルチPDS対応 |
| Misskey | `misskey_dart` | MFM描画は自前(RichText/RSL) |
| Mastodon | `mastodon_api` 等 | 無料API・OAuth取得可能なインスタンスに限定(第一期は一部インスタンス) |
| WASMランタイム | `wasm_run`(wasmi/wasmtime)系 or wasm3/WAMR を FFI | **iOSはJIT不可→インタープリタ**。M3冒頭でスパイク必須 |
| WebRTC | `flutter_webrtc` | AsTell。WebTransportはDart側ライブラリが薄いので要調査 |
| オンデバイス推論 | `onnxruntime` / `tflite_flutter`、LLMは `llama.cpp` 系FFI | sbert蒸留/GRU/mT5。第一期はまずサーバー or スタブで動かし、後で載せ替え |
| 画像 | `cached_network_image`, `photo_view` | MediaGrid / 全画面表示 |
| テスト | `flutter_test`, `golden_toolkit`, `mocktail` | L2部品はゴールデンで固定 |

---

## 2. マイルストーン

### M0 基盤(目安: 最初の着手単位)【提案】

- ワークスペース/パッケージ雛形、lint、CI(`flutter analyze` / `flutter test` をGitLab CIに追加)
- `rasq_design`: カラートークン(`#02EFFD` / `#3274B5` / `#F09937` / `#1E4C7C` / `#FFFFFF` / `#ADC5FA` / `#D5D5D5`)、spacing/marginトークン、最小タップ域44dp、タイポグラフィ、ライト/ダーク
- L2 atomic: `Avatar`(LIVE/VC中/グループ)、`Badge`、`RichText`(RSLスパン対応の器)、`MediaGrid`(1/2/3+枚、センシティブぼかし、タイル単位)、`ActionButton`(4バリエーション)、`Timestamp`、`Button`、`ListTile`系6種+`SectionHeader`、`Input`
- `rasq_overlay`: Overlay Manager(階層順/スタック・排他/クローズ挙動/競合ルールの表をそのまま実装)、`BottomSheet`/`AlertDialog`/`Dropdown`(画面端で位置反転)/`Sidebar`
- app shell: モバイル(ヘッダー+コンテンツ+グローバルナビ)/タブレット(サイドバー固定+2ペイン、VC位置)、ヘッダー4種、コラプシブルヘッダー+タブ(固定/拡張可能、5項目以上で横スクロール、上限10)
- `rasq_store`: Store骨格、既読/アクション済み/カウント/フォロー状態、キャッシュ方針(TTL/容量上限)
- エラーコード体系(000-999 HTTP / A設定 / B影響設定 / C受け渡し / D破損 / E規制 / F予約)とエラー/空状態/ローディング部品(スケルトンではなくローディングサークル)
- モックデータで Widgetbook 的なカタログ画面

**M0 進捗(2026-08-22)**: 実装済み — pub workspace(`packages/rasq_models` / `rasq_design` / `rasq_overlay` / `rasq_store`)、トークン+ライト/ダークテーマ、L2 atomic(`RasqAvatar`/`RasqGroupAvatar`/`RasqBadge`/`RasqPill`/`RasqSnsPill`/`RasqRichText`(RSLスパン)/`RasqMediaGrid`/`RasqActionButton`/`RasqTimestamp`/`RasqTogglePillButton`/`RasqGradientButton`/`RasqIconButton`/ListTile系6種+`RasqSectionHeader`/`RasqInput`/`RasqSearchBar`)、`RasqTabs`(4/5/10ルール)+`RasqCollapsibleTabScaffold`、`RasqErrorView`/`RasqInlineErrorTile`/`RasqEmptyView`/`RasqLoading`、Overlay Manager(階層・スタック/排他・クローズ挙動・競合・端反転ドロップダウン・プリセット3種)、Store(アクション/既読/フォロー/TTLキャッシュ)、アプリシェル(モバイル/タブレット・ヘッダー4種・グローバルナビ・サイドバー)、画面枠(ホームTL/検索/VC/通知/DM/設定/カタログ)、テスト(20本)、GitLab CI。
**M0 残件**: Widgetbook化(現状は `/catalog` 画面)、Web向けCJKフォント(Noto Sans JP)同梱、VCウィジェット(ヘッダー)の本実装、タブレット第3カラムの中身。

### M1 SNSアダプタ(Dart直書き)+認証

- `rasq_plugin_api`: `SnsPlugin` 契約(TL取得/投稿/アクション/通知/DM/検索/ユーザー/リスト/ミュート・ブロック)、`ActionRef`(形式は【提案】のまま)、function.json スキーマ(読み込みのみ)
- **Misskey(MiAuth)を先行**: Bluesky(OAuth)/Mastodon はアクセストークン発行にサーバー側(`ORGATE-server`)が必要なため、`sns_misskey` を先に実装し、`sns_bluesky` / `sns_mastodon` はサーバー側の発行口が立ってから。mixi2は契約だけ
- 関連リポ: `ORGATE-question/misskey-wasm-sample`(SNSプラグインのサンプル。当面は WASM 化せず Dart 直書きで契約を詰める)/ `ORGATE-question/rasq-sdk-sample`(プラグインSDKのサンプル仮組み。設計を詰めてから実際のやり取り=ホスト関数・境界プロトコルを確定)。`SnsPlugin` 契約はまず `rasq_plugin_api` で叩き台を切り、SDK サンプル側へ寄せる
- ログイン(マルチPDS/サーバー検索/ユーザー名+パスワード/新規登録リンク)、利用規約(プラグインごと)、トークン保管、マルチアカウント
- Store へのデータ流入(SNSプラグイン→Store→Props)

### M2 コア画面

- ホームTL(フォロー中/おすすめ)、`PostTile` 3種(通常/埋め込み/スレッドまとめ)+`CollapsedPost`、投票、引用、リンクバナー/VC告知カード
- スレッド展開(404/インナーフレームエラー含む)、リアクションを表示、全画面表示(→オーバーレイ昇格)
- アクションバー(プラグイン登録形式、状態はStore経由、expand合算)、コンテキストメニュー(自身/他ユーザー、プラグイン別)
- 通知(4種タイル、長押しドロップダウン、通知プロファイル設定)、DMホーム/ルーム
- ユーザーページ(通常/自分/制限/ノーヒット/プラグイン表示)、プロフィール編集、フォロー中/フォロワー、フォロー申請
- 検索ホーム(広告枠=AdSlot差し込み地点のみ)、検索エラー系
- リスト検索/中身/インポート、ミュート/ブロック一覧
- 設定トップ/第一階層(テキストベース)、サイドバー、Webコンソールリンク
- 投稿コンポーザー v1(FOWではなく通常BottomSheetで先行: CW/絵文字/投票/画像添付)

### M3 RRL/FOW/プラグインランタイム

- `rrl_core`: ノード4層(D-002)、Snapshot/Patch(Command+rev、原子バッチ)/Call/Lifecycle(mount/unmount/visible/hidden/cancel)、安定ID `{pluginId}:{accountId}:{pluginVersion}:{instanceId}:{explicitKey}`、二段検証(WASM側+境界)
- `rrl_renderer`: L1→Widget、L2はホスト部品へ委譲、`Call/Slot/ForEach/If/Bind/Stream`、イベント→ActionRef、geometry registry、AdSlot挿入ポリシー(検索固定/TL差し込み/外部リンクFOW)、スロット単位障害隔離
- `plugin_runtime`: **WASMランタイム スパイク(iOSインタープリタで性能計測)** → 採用決定 → ホスト関数(`fow.open`/`wasm.call`/`emit`/`alert`/`storage.safe|unsafe`)、クラッシュ隔離(最後の成功スナップショットを描画し続ける)
- FOW 完全版: widget/interstitial/system、confirmMode(`immediate/confirm/saveDiscard/stick`)、Stick複数時のウィジェットスイッチャー、コンポーザーを FOW へ移行、全画面子FOW(画像編集、進む/戻る差分キャッシュ)
- PostTile スロット(avatar/content/media/action/完全置き換え)の操作別権限(D-004)を検証ゲートに実装。interstitial の GPU/ML は審査済みのみ許可
- **メディアビューワープラグイン**(新設種別): 全画面表示の呼び出しボタン→RRLをシームレス描画(`viewer.fullscreen` サーフェス)。TL内スロットでは内容変換不可
- 最初の実プラグイン: 「Dart直書きアダプタと同じ結果を返す WASM SNSプラグイン(Bluesky)」で契約を検証

### M4 プラグインストア(クライアント)+設定DSL

- ストアホーム(今週のトレンド/ブックマーク/検索)、プラグインページ(プレビュー/DL数/評価/レビュー/バージョン/権限)、レビュー一覧・作成、リリースノート
- プラグイン管理(アカウントごとバージョン、アップデート/デプロイ設定、更新ログ)、インポート(外部プラグイン警告)、クラッシュ時マニュアルモード
- インストール関数(Zstd/SHA-512/署名)、自動アップデート、SNSプラグイン更新時の小プラグイン要求バージョン処理
- 設定第一階層以降を FOW/DSL で描画(`ListTile/ToggleListTile/SliderListTile/SectionHeader/DestructiveListTile`)
- ストアサーバー(`ORGATE-server`)との契約(ページ関数/構成取得関数/インストール関数/レビュー関数、WebTransport)は OpenAPI or protobuf で**クライアント側から先に定義**
- ストアは**審査済みプラグインのみ**掲載(D-004 ②)。サイドロードは「プラグインのインポート」導線のみ
- レビュー指摘の取り込み(`プラグインストア周りの話.md`):
  - 高: 権限・安全性の詳細(通信先/投稿・DM・ファイル・クリップボード/GPU/バックグラウンド/外部SDK/広告)、互換性・依存関係(RASQ対応版/OS/必要・競合プラグイン/容量)、アップデート差分と復元(権限増加時は自動更新を止める/ロールバック/旧版維持)、審査結果の詳細と再申請導線(Web側)
  - 中: 探索導線(カテゴリ/SNS別/用途別/無料・広告/公式・検証済み/最近更新/軽量/オフライン)、**インストール確認シート**(できること×許可する権限)、停止・削除・データ削除(内部データ/連携解除/キャッシュ量)、レビュー信頼性(実利用済み/利用バージョン/開発者返信/参考になった/通報/並び替え)、収益化設定(Web側)
  - 低: 状態表記の統一(審査中/公開中/更新あり/警告/停止/取り下げ/非公開/ベータ/失効)を `rasq_design` のステータストークンに
  - 詳細画面上部の常設ブロック: 検証済み/公式/コミュニティ製、安定版・ベータ・最終更新日、利用できるRASQ機能、要求権限の要約、外部通信先とデータの扱い、クラッシュ率・正常起動率、対応OS・容量・必要ランタイム
  - クラッシュ画面: 再起動に加え「今回だけ無効化して起動」「セーフモードで起動」「前バージョンへ戻す」「診断ログを送る(内容確認後)」。WASMなので原因候補プラグインだけ隔離
  - 「ストア掲載プレビュー」(開発者が実ユーザー表示で確認)は Web コンソール側だが、アプリ側にディープリンクで同画面を開ける口を用意

### M5 トレンド / リレーショナルTL / AsTell 【保留 / D-011】

- トレンド設定(指向性/刺激性スライダー=独立部品、CustomPaintレーダー、ジャンル、キャッシュネットワーク)、トレンドTL(検索結果/フォロー中の反応)、ハッシュタグ→トレンドTL
- リレーショナルTL(タイムライン表示/展開表示)。クラスタリングは最初サーバー or 簡易実装、モデルはオンデバイスに後載せ
- AsTell: グローバルVCホーム/タイル、参加/作成FOW、pipBar常駐オーバーレイ(VC FOW 2状態)、共有(投稿/メディア/プラグイン)、文字起こし、エラー/終了挙動、タブレットのVC位置
- 通知のASTell/タイマー通知タイル

### M6 RAi(インストラクション)+仕上げ

- RAiホーム、インストラクションモード入力欄、位置検索関数(geometry registry)→RAiウィジェットのスプライン移動(gltf/three_js相当は第一期では簡易モーション)
- ローカルハイブリッドDB(SQLite+vector)へ ActionReference.jsonl をデプロイ、検索
- オンボーディング(ジャンル探し)、トースト/スナックバー、プラグインクラッシュのフォールバック表示、キャッシュ戦略の最終化

---

## 3. 決定台帳(引き継ぎ)

| ID | 内容 | 状態 | 根拠 |
|---|---|---|---|
| D-000 | 台帳運用(根拠欄必須、推測は【決定】にしない) | 決定 | 確認: Solレビュー反映 |
| D-001 | 実行境界=隔離WASMがRRL AST生成→シリアライズ→Dartレンダラー。Snapshot+delta、安定ID、レンダラー駆動ライフサイクル | 決定 | 確認: 「WASMからデータ受け渡しで合ってる！」 |
| D-002 | L1/L2(atomic・composite)/L3/L4 + レンダラー専用挿入地点(AdSlot)。InputはL2 | 決定 | 確認: Sol 8項目 |
| D-003 | FOW/Action/Component/Override 4分離(概念) | 概念のみ決定 / ActionRef形式は提案 | 同上 |
| D-004 | 操作別権限モデル(PostTileは原典一致)。①TL media(sideload)=`tag_media`のみ ②ストアは審査済みのみ掲載 ③メディアビューワープラグイン新設(全画面時のみRRL描画) ④interstitial GPU/ML=審査済みのみ | 決定 | 確認: 2026-08-22 |
| D-005 | (予約) contentとactionを分けたスロット仕様(旧D1〜D10は素材) | 未決 | — |
| D-006 | (予約) ActionRef形式 `pluginId:accountId:pluginVersion:fn` | 提案 | — |
| D-007 | (予約) WASMランタイム選定(iOSインタープリタ基準) | 未決 | M3スパイクで決める |

| D-008 | 第一期の対象SNS = Bluesky / Misskey / Mastodon(無料API・OAuth可のインスタンス限定)。mixi2は契約のみ | 決定 | 確認: 2026-08-22 |
| D-009 | アプリは pub workspace モノレポ、状態管理は Riverpod、サーバーは別リポ `ORGATE-server` | 決定 | 確認: 2026-08-22 |
| D-010 | 認証は Misskey(MiAuth)先行。Bluesky/Mastodon はトークン発行サーバーが立ってから。プラグイン契約は `misskey-wasm-sample`/`rasq-sdk-sample` で仮組みしてから確定 | 決定 | 確認: 2026-08-22 |
| D-011 | **AsTell は当面実装しない**(サービス非依存でサーバー側=STUN/TURN・文字起こし記録・カスタムプラグインホストが未整備。VCタブは枠のみ)。**リレーショナルTL も着手しない**(アルゴリズム未確定)。M5 は保留 | 決定 | 確認: 2026-08-22 |

**M3着手前に閉じるべき項目**: D-005、D-006、D-007。M0〜M2はこれらに依存しない。

---

## 4. 画面 × マイルストーン 対応表(ワイヤーフレーム準拠)

| 画面 | M |
|---|---|
| ログイン/PDS変更/ユーザー名+パスワード/利用規約 | M1 |
| ホームTL(フォロー中/おすすめ)/スレッド展開/リアクションを表示/全画面表示 | M2 |
| 通知/通知プロファイル設定/DMホーム/DMルーム | M2 |
| ユーザーページ各種/プロフィール編集/フォロー・フォロワー/フォロー申請 | M2 |
| 検索ホーム/検索エラー系/リスト検索・中身・インポート/ミュート・ブロック | M2 |
| 設定トップ/第一階層/サイドバー | M2(静的) → M4(DSL化) |
| 投稿コンポーザー(CW/絵文字/投票/画像編集/MFM補完) | M2(v1) → M3(FOW化) |
| FOW/アクションバー/コンテキストメニュー/プラグインボタン編集 | M3 |
| プラグインストア一式/プラグイン管理/クラッシュ時/ブックマーク/レビュー/リリースノート | M4 |
| トレンド設定/トレンドTL/リレーショナルTL | M5 |
| グローバルVCホーム/VC参加・作成/VCコントロール/エラー・終了 | M5 |
| RAiホーム/インストラクション履歴/サーバー提案/オンボーディング | M6 |
| タブレット2カラム/VC表示位置 | M0(枠) → 各Mで中身 |
| プラグインコンソール(Web) | 対象外(別プロジェクト) |

---

## 5. リスクと対策

| リスク | 対策 |
|---|---|
| iOSでのWASM実行性能 | M3冒頭でインタープリタ系の計測スパイク。描画ホットパスはWASMに載せない分業を徹底 |
| RRL仕様の手戻り | M0〜M2をRRL非依存で進め、L2部品は最初からProps駆動・ステートレスで作る |
| バックエンド依存(ストア/AsTell/トレンド/RAiクラウド) | クライアント側で契約(スキーマ)を先に定義し、モックサーバーで開発 |
| オンデバイスML(sbert/GRU/mT5/LFM)の実装コスト | 推論層をインターフェース化し、第一期はサーバー実行 or スタブで画面を完成させる |
| 画面数が多い | ワイヤーフレームの「使い回し」をそのままL2部品の共用に写す(UserRow/ListTile/PluginTile等) |

---

## 6. 確認済み事項(2026-08-22)

1. パッケージ分割: pub workspace モノレポで開始(アプリはルート、`packages/*`)。サーバーは `ORGATE-server`
2. 状態管理: Riverpod
3. 第一期の対象SNS: Bluesky / Misskey / Mastodon(無料API・OAuth可インスタンス限定)
4. D-004 の4セル: ①OK ②(b) ③メディアビューワープラグイン新設 ④(a)
