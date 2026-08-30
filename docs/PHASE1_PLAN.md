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

**M1 進捗(2026-08-22)**: 実装済み — `rasq_plugin_api`(SnsPlugin/SnsSession/ActionDescriptor/ActionRef/PluginManifest/AuthFlow/AccountSession/PluginRegistry/TimelineKind+DynamicTimelines)、`sns_misskey`(MiAuth、TL 4種+`tag:`/`dm:`/`featured`、ノート/通知/ユーザー/関係/検索/絵文字、`hashtags/trend`、DMルーム=限定公開投稿を相手単位に束ねる)、セッション永続化(secure storage; macOS は従来型Keychain)、ログイン画面(Misskeyのみ有効)、規約シート、ホームTL(実データ・無限スクロール・楽観更新)、通知一覧、投稿詳細(スレッド)、トレンドホーム(`hashtags/trend`+Today=`notes/featured`)、トレンドTL(`notes/search-by-tag`、フォロー中の反応は空欄)、DMホーム/DMルーム。macOS 実機で MiAuth→ホームTL まで確認済み。
**M1 残件**: 投稿コンポーザー(次段階: FOW サンプル)、DM送信、Bluesky/Mastodon アダプタ(トークン発行サーバー待ち)、通知4タイル化、ディープリンク callback。

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

**M2 進捗(2026-08-22)**: 実装済み — スレッド展開(親/対象/返信・∨返信ソート・リアクションを表示›)、リアクション表示欄(返信/引用/リアクション[絵文字+数+折りたたみユーザー欄]/共有)、投稿コンポーザー(interstitial FOW: 文字/画像/絵文字FOW/投票/注釈、通常・返信・引用(契約のみ)・DM)、絵文字ピッカー(widget FOW: テキスト挿入 + リアクション長押し)、通知4タイル(アクション/フォロー/投稿/タイマー)+通知プロファイル設定+下ナビ長押し(一括既読/通知オフ)+フォロー中フィルタ、ユーザーページ(UserTileLarge: 通常/自分/制限/ノーヒット、タブ ノート/引用/メディア/クリップ、ピン留め)、フォロー中/フォロワー、フォロー申請(許可/拒否)、ミュート/ブロック一覧(∨ユーザー/ワード/リスト)、全画面ビューワー(PageView+ズーム+下部アクションバー)、投稿コンテキストメニュー(詳細/リンクをコピー/お気に入り/フォロー/ミュート/ブロック/報告/削除)、既読折りたたみ(省略表示)、設定第一階層(テキストベース仕様 `settings_sections.dart`)、プロフィール編集、リスト(一覧/中身/作成/インポート枠)、ブックマーク(お気に入り)、トレンドホーム(`hashtags/trend`+Today)、トレンドTL(ノート/フォロー中/ユーザー + ∨ソート)、DMホーム/ルーム(ダイレクト投稿 + Chat)、ソートメニュー(小型ドロップダウン)。
**M2 残件**: `PostTile` の正式スロット化(avatar/content/media/action/完全置き換え = M3 で実施)、トースト/スナックバー、タイマー通知(ブックマーク/VC)、検索エラー系の残り、コンテキストメニューのプラグイン別項目(M3 登録制)、ワード/リストのブロック、通知プロファイルの永続化、ディープリンク。

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
- ストアサーバー(`ORGATE-server`)との契約は **OpenAPI で確定(D-033)**: `rasq-sdk-sample/openapi/store.yaml` v0 定義済み。WebTransport 化してもペイロード流用
- **M4a(設定・クリップを塞ぐ最小スライス、2026-08-26 決定)**: ① 契約(clips API ✅ / RRL 設定タイル ✅ / store.yaml ✅) → ② 設定 DSL レンダラー + 第二階層の移行(D-031)✅(表示サイズ・モーション抑制の 2 ページ + 実適用) → ③ クリップ(D-032)✅ + **仮想目次**(D-036)✅(2026-08-27。リストTL への目次接続は会話イベント変換関数まで用意済み) → ④ インストーラ(.rasqpkg、D-034) → ⑤ ストア UI 一式
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

| D-012 | FOW はオーバーレイ `fow` レイヤー上の**スタック可**エントリ。下部ドック・上下リサイズ(ドラッグハンドル)・複数時はボトムアップ配置(新しいものが最下部、親はその上に詰まる)。interstitial はスクリム+背面タップで破棄、widget/system は背面操作可。子FOWは親 ownerId で連動クローズ | 提案(実装済) | 導出: Qwenログ「FOWスタックはレンダラー責務」+ ワイヤーフレーム(コンポーザー下の絵文字パネル) |
| D-013 | DM = 限定公開投稿(Misskey `specified`)を相手単位に束ねる + ネイティブChat(`chat/*`, 2025.4+, 無効インスタンスでは自動的に無し)。サンプルは1ルーム1ユーザー | 決定 | 確認: 2026-08-22 |
| D-014 | トレンドホームは第一期サンプルとして SNS 自身の `hashtags/trend`(+Today=`notes/featured`)を使う。トレンドTL: フォロー中=フォロイーの投稿をリアクション順、ユーザー=投稿者をリアクション合計順に `users/show` | 決定 | 確認: 2026-08-22 |
| D-015 | ソートメニューは `∨`(選択中タブ再タップ/セクション見出し)から小型ドロップダウンで「リアクション数 昇順/降順/デフォルト」 | 決定 | 確認: 2026-08-22 |
| D-016 | 契約の正本は `rasq-client/docs/PLUGIN_CONTRACT.md`(= `rasq-sdk-sample/CONTRACT.md`)。M3 の境界プロトコル IDL 化は SDK サンプル側で行う | 決定 | 確認: 2026-08-22 |

| D-017 | 短押しリアクションの中身はプラグインが決める(Misskey 本番: 予測モデルで最有力絵文字)。**投稿ごとのアクションアイコン差し替え**は SNS プラグイン+配下プラグインの `iconPerPost` 宣言アクションのみ(既定アイコン必須、他プラグインは視認性のため固定) | 決定 | 確認: 2026-08-22 |
| D-018 | 動かす中心は WASM。onnx / llama.cpp 等は `ml.infer` 経由の補助(SmallLM の常時処理は想定外) | 決定 | 確認: 2026-08-22 |
| D-019 | RRL ノードに**意味タグ**(`main_text` `pic` `vote` …)。投稿内容に関係しないノード(Icon 等)には付けない。RAi・TLソート・リレーショナルTL が参照 | 決定 | 確認: 2026-08-22 |
| D-020 | 境界ワイヤは JSON v1(`rasq.boundary/1`)。内部表現は JSON / RRL どちらでも可。性能経路は後で FlatBuffers/ZeroCopy | 決定 | 確認: 2026-08-22 |
| D-021 | **検索ソートUI**: チップ行は常設せず、検索欄フォーカス中(∨トグル)に入力欄を下方向へ拡幅して表示、フィルタ適用後は常時表示(誤タップ防止)。並び替えは昇順/降順ではなく**キー名に方向を内包**(関連順/新しい順/古い順/リアクション多い順)。ジャンルは3個まで直置きボタン、指向性/刺激性・プラグイン・キャッシュネットは ⚙ へ分離。部品は D-015 の小型ドロップダウンを再利用(`RasqSearchFilterBar`) | 決定(実装済) | 確認: 2026-08-25 レビュー |
| D-022 | **関連順とリレーショナルTLのML構成**: ルールベース(ハッシュタグ/本文/表示名/固有名詞マッチ)+ **GLiNER**(ゼロショットNER: ユーザー表示名・一般固有名詞)+ **SigLIP**(画像×テキスト類似、候補が十分多いときのみ)。`ml.infer` 経由(モデルマニフェスト: `gliner-ner` / `siglip-similarity`)。リレーショナルTL v0 仕様: フォロイー投稿に SigLIP+GLiNER+ルールベース → フォロイーの投稿・リノート等のアクション + LTL/トレンドの類似投稿を取得 → (GLiNER/ルールベースで束ね、多ければ SigLIP 併用) → TLにまとめる(要約は無し or mT5)。除外: しきい値から離れた投稿を4件程度したとき / 浮上せず10分?経過。**しきい値 = SigLIP cos 類似度への距離で、初期値は実測が要るためユーザー調整スライダーにする**(設定>リレーショナルTL、指向性/刺激性と同じ独立スライダー部品)。**浮上 = クラスタへの新規投稿 or リノート。自分が関連投稿している場合はその投稿へのアクションも浮上に数える**。**重いので最終版でモデル構成は差し替え前提** | 提案(検索側ルールベース実装済) | 確認: 2026-08-25 |
| D-023 | **`net.fetch` はランタイム内蔵**(wasmi 内の blocking HTTP = ureq+rustls、iOS/Android へそのままクロスコンパイル)。有効時は host_fn コールバックに渡らない。wasm 実行はワーカー isolate(`AsyncWasmPluginController`)で UI 非ブロック | 決定(実装済) | 確認: 2026-08-25 |
| D-024 | **ML 実配線と計算量削減**: `rasq_ml` の `MlGateway` がマニフェストを解決し配置(デバイス onnx runtime[executionProviders で GPU/NPU 指定・多言語モデル]/ サーバー Triton KServe v2 + vLLM OpenAI 互換[GPU])。リレーショナルTLは **SigLIP でフォロイー毎に特徴量の指数移動平均(EMA)→ 著者類似グラフ → Louvain でコミュニティ分割**し、クラスタリングの類似判定を同一コミュニティ内に限定(O(投稿²) → コミュニティ内)。ゲートウェイ未設定時はルールベースに縮退。しきい値スライダーは **50〜100 正規化**(高次元 cos は 0 に張り付かないため) | 決定(実装済・モデル実体の配布は M4) | 確認: 2026-08-25 |
| D-025 | **ローカル SigLIP 実行ポリシー**: HTL アクティブ数が少なく(直近10分の流入 ≤30)**CPU 使用率 75% 未満**ならデバイスで実行(`DevicePolicy`)。指標が取れない/サーバー未構成のときは**ローカルへ倒す**(試験手段がローカルのみのため)。EMA はホストストレージに永続化(`relational.ema.v1`) | 決定(実装済) | 確認: 2026-08-25 |
| D-026 | **検索ボックス一体型UI**(D-021 改): フィルタは入力欄の下にぶら下げず、**入力欄が下方向に伸びて同じ角丸タイル内に**ソート/期間チップと入れ子のスタジアム形ジャンルボタンが入る(`RasqExpandableSearchBox`)。トレンドTLでは検索欄横に ← を置いてトレンドホームへ戻れ、**入力欄は編集可能のまま次の検索を続けられる**(submit で結果画面を置換) | 決定(実装済) | 確認: 2026-08-25 |
| D-027 | **リレーショナルTL v1 = 会話イベント方式**(D-022/D-024 改、外部アドバイス反映): 空リプ文化の抽出には「既存話題に属するか」ではなく**「どの直前投稿への暗黙応答か / 新話題の開始か」**を投稿ごとに判定する reply-to グラフ構造。リンク採点 = SigLIP cos + 文字 2〜3-gram + エンティティ一致(包含許容)+ ハード/ソフトアンカー(URL・引用先 / #タグ)+ 時間減衰 + ユーザーペア親密度 + 発話交替 + 反応表現(「それな」等は応答の証拠として加点)。**仮 ROOT を保留し後続で遡及確定**(First Story Detection)。しきい値はコミュニティ別適応(無関係ベストスコアの中央値+2.5×MAD)+ユーザーの「束ねやすさ」バイアス(50〜100)。**Louvain は事前分布(±0.05)に格下げ**、**GTL/LTL 連結は停止**、**ユーザー退出(無関係4連投)は廃止して投稿単位所属**、イベント表現は EMA 重心ではなく**固定アンカー+最近プロトタイプの max 類似**、TTL は `clamp(2×投稿間隔Q90, 5分, 30分)` のイベント別適応(休眠はハードアンカー一致で再開)。将来はリンク採点を LightGBM/ロジスティック回帰へ(明示リプライ・同一URL等を弱教師に) | 決定(実装済) | 確認: 2026-08-26 |
| D-028 | **リレーショナルTL の遡り取得と FOW チューニング**: (1) リスト末尾(または空の状態)でさらに引っ張ると遡り窓が **+30 分ずつ**広がり(上限 12 時間、リフレッシュで解除)、home TL の過去ページを `loadMore` しつつ **TTL で沈んだ(DORMANT/CLOSED)会話も窓内なら表示**する — アクティブフォロイーが少ないとき対策。(2) ⚙ はモーダルシートをやめ **widget タイプの FOW**(背面のタイムラインが動いたまま)。**絵文字ピッカー FOW と同じ作法**: キャンセル(バリアクリック・esc 含む)で開いた時点へ巻き戻し、決定で確定。UI は **簡易/詳細の 2 段構成** — 簡易: 束ね判定「束ねやすさ/時間減衰」・重み「類似性(内容+エンティティ)/親密度(ペア親密度+発話交替)」のまとめスライダー(既定比率でスケール)・追加判定「ハードアンカー/反応表現」・「TTL」RangeSlider。「詳細設定」タイル → 全パラメーター(重み内訳・候補ウィンドウ・事前分布・保留)。設定は `relational.settings.v1` に永続化。FOW 基盤のブラックボックス解消(絵文字ピッカーと同じ枠化)は RRL/プラグイン実装時に | 決定(実装済) | 確認: 2026-08-26 |
| D-029 | **ASTell 要約の配線**: リレーショナルTL イベントカードの要約は ASTell_ETS の **mt5_copy.onnx**(mT5-small + copy gate、1.15GB fp32、単発 forward export)で行う。実測構造: `input_ids int64[1,seq]` / `attention_mask int64[1,128]`(**export 時に動的軸が付かず 128 固定** → maxTokens=128 で運用)/ `decoder_input_ids int64[1,dec_seq]` → `logits float32[b,t,250112]`。checker OK・重み内蔵で構造欠落なし、ただし **sentencepiece トークナイザ(spiece.model)が未同梱**(要追加配布)。KV キャッシュが無いためホストが `generation` 設定(decoderStart=0 / eos=1 / greedy)でデコーダーループを回す — model-manifest スキーマに `runtimes.onnx.generation` と tensor semantic `decoder_token_ids` を追加。`MlGateway.summarize` は手段が無ければ null(カードは ROOT 本文にフォールバック)。要約はイベント id ごとに 1 回 | 決定(配線済・デバイス実行器は M4) | 確認: 2026-08-26 |
| D-030 | **会話イベントの参加者拡張**: 自分自身の投稿も会話イベントに含める(ただし**自分のアイコンはイベントタイルに表示しない** — 全員自分のときのみ表示)。リノートは (a) 運ばれた投稿の著者が members/参加者に入り、(b) **リノート主も参加者**になり、(c) リノート主↔著者のペア親密度を近接共起より強く(weight 2)加点 → リノート主の空リプが繋がりやすくなる | 決定(実装済) | 確認: 2026-08-26 |
| D-031 | **設定DSL = RRL のサブセット**(専用スキーマは作らない)。設定ページ = RRL ノード JSON。語彙は既存の `ListTile/SwitchListTile/RadioListTile/ValueListTile/WarningListTile/DestructiveListTile/SectionHeader` に **`SliderListTile` / `RangeSliderListTile` を追加**(rrl-node.schema.json 反映済み)。ホスト設定は wasm 不要の**静的 RRL アセット** + Bind `$.settings.<key>` で設定ストアに接続、変更は call `settings.set`。プラグイン設定ページは同じレンダラー + `storage.safe` で無償対応。第一階層は現行 Dart(settings_sections)のまま、**第二階層以降から DSL 化**。**実装済み(2026-08-26)**: レンダラーに設定タイル 7 種を実装、`rasq.settings-page/1`(settings-page.schema.json)+ `SettingsDslScreen`(`/settings/dsl/:area`)+ `SettingsAreaStore`(KV `<area>.v1`)。第一陣 = 表示サイズ(textScale、**MediaQuery.textScaler に実適用**)とモーションの抑制(reduceMotion、**MediaQuery.disableAnimations に実適用** → MFM が静止画に縮退) | 決定(実装済) | 確認: 2026-08-26 |
| D-032 | **クリップ = SNS ネイティブ + ホスト横断の両方**。(1) SNS ネイティブ: `SnsSession` に clips 群(`clips(userId?) / clipInfo / clipNotes / createClip / deleteClip / addToClip / removeFromClip`、`ClipInfo` モデル)を追加(実装済)。Unsupported → ユーザーページのクリップタブ・メニューを自動非表示。Misskey アダプタが実装する。(2) ホスト横断クリップ: ホストストレージ `clips.host.v1` に post key 参照 + **表示用スナップショット**(元投稿消滅対策)を保存。SNS を跨いで 1 クリップに混在可、端末ローカル(同期は将来 RASQ アカウント)。`ClipInfo.isHost = true` で同一モデルに載せ、UI では RASQ バッジで区別。「クリップに追加」はコンテキストメニューから追加先選択シート(ネイティブ/ホスト)。**実装済み(2026-08-27)**: Misskey アダプタ(clips/list・users/clips・clips/notes・create/delete/add-note/remove-note)、ホスト横断ストア(`clips.host.v1`、スナップショット保存・重複排除・再起動復元)、リスト画面のクリップ節・ユーザーページのクリップタブ・投稿メニュー「クリップに追加」(新規作成つき)、クリップTL 画面 | 決定(実装済) | 確認: 2026-08-27 |
| D-036 | **仮想目次**(クリップ/リスト/TL の投稿列に重ねるナビゲーション索引、外部アドバイス反映): 投稿を再編成せず**参照だけ**持つ `IndexEntry`(label/postKeys/representative=根拠 2〜3 件/participants/confidence/state)。見出しは **LLM 生成ではなく実在語**(優先: 手動見出し > 共通ハッシュタグ > エンティティ > 混在名詞 n-gram > URL ドメイン > 投稿者 > 日付)、適切な語が無ければ「関連投稿 N件」「話題を特定できない投稿」。**最大 2 階層**(3 階層は自動分類の誤りが目立つ)。束ねは貪欲ラベル被覆(親ラベルと全被覆語は子分割から除外)。**クリップ = 内容ベースで閲覧時に再計算・件数順** / **リスト・TL = 会話イベント(D-027)をそのまま章に変換**(進行中 → 最近終了順、確信度が上がったら命名される遅延確定)。UI はクリップTL 最上位の折りたたみ目次、章タップで絞り込みトグル(スクロール移動は後日)。GTL/トレンドは見出し補強にも混ぜない。**リストTL 接続済み(2026-08-27)**: リスト詳細の投稿タブに「いま話されていること」(会話イベント章 = ●進行中/○休眠 + 参加人数、単発投稿は 1 バケツ)。TOC は共有部品 `VirtualIndexToc` | 決定(実装済) | 確認: 2026-08-27 |
| D-037 | **リレーショナルページ + クリップ置き場の整理**: (1) リレーショナルタイルのドロップダウン展開を廃止し**個別ページへ遷移**(タイル = 実在語見出し + **1 行要約**、ページ = GroupAvatar +「◯◯+N人」+ 実在語見出し + **3 行要約**(ASTell)+ キーワードチップ + 投稿列 — リレーショナルページのデザイン.png 準拠)。ヘッダーは共通部品 `EventStyleHeader` で、**クリップページの説明部も同じブロック**(説明文・件数・所有者/非公開/横断の別を caption に)。(2) クリップの置き場: **リスト欄 = 公開ネイティブのみが既定**(検索ボックス内フィルタ「非公開クリップを表示」で切替、KV `lists.view.v1`)、**ブックマーク欄 = RASQ 横断クリップ + 非公開ネイティブクリップ**(SNS 側に記録されない/自分のための保存はブックマークと同じ置き場)。(3) リスト画面の検索は検索ページと同じ一体型入力欄(`RasqExpandableSearchBox`)に統一 | 決定(実装済) | 確認: 2026-08-27 |
| D-038 | **タブ外ページからの詳細遷移はアプリ直下ルートへ**: タブ外(リスト/クリップ/設定などアプリナビゲータ直下のページ)からタブ配下ルート(`/home/post/…` 等)を push すると、base 側と push 側で **StatefulShellRoute のページ(キー = `ValueKey(route.hashCode)`)が二重マッチ**して `!keyReservation.contains(key)` アサーション → GlobalKey 重複でナビゲーションが壊れる(go_router 17.5、実機・テスト両方で再現)。対処: アプリ直下に **`/post/:id`(+reactions)/ `/user/:id`(+follows)/ `/trend/:tag` の複製ルート**を置き、`pushPost`/`pushUser`/`pushFollows`/`pushTrend`/`replaceTrend` は現在地がタブ配下かで振り分ける(`_inTab`)。タブ配下では従来どおりネスト(グローバルナビ維持) | 決定(実装済・回帰テスト常設) | 確認: 2026-08-27 |
| D-039 | **引用導線・リアクション予測・クリップ説明・Play リンク**: (1) Repost(リノート)ボタンは**組み込みアクションバンドル**: タップでリノート/引用ノートのドロップダウン(引用 → `ComposeQuote` コンポーザー)。ユーザー編集のリスト化とは別レイヤーで、(+) 編集導線には出ない。(2) 短押しリアクションは**事前学習なしのヒューリスティック予測**: 自分のリアクション履歴(KV `reaction.history.v1`、上位64種)× 投稿に付いている既存リアクションの交差 → 自分の最頻 → 無ければアダプタ既定。長押しピッカー・短押しの実行結果は履歴に記録。reaction-predictor モデル(D-017)配線後は ml.infer に置換。(3) クリップ新規作成シートに**説明文入力欄**(ネイティブ/ホスト両対応、表示はクリップページヘッダー等で既対応)。(4) ユーザーページのクリップ/Play タブに **Play(users/flashs)を外部リンク表示**(`PlayInfo` + `SnsSession.userPlays`、RASQ 内では実行しない)。付随修正: overlay の `_AnchoredDropdown` が `LayoutBuilder → Positioned` の ParentDataWidget 違反で開くたび debug 例外 → `CustomSingleChildLayout` 化 | 決定(実装済) | 確認: 2026-08-27 |
| D-040 | **絵文字まわりの刷新**(絵文字ピッカー、絵文字予測周りの改善.md / 絵文字予測.md 反映): (1) **可変幅表示** `RasqCustomEmoji` — 画像幅が高さの 3 倍まで高さ固定・幅可変、超えたら幅 2×高さで固定。**ホバー/長押しチップ**(名前の左横に絵文字、横長なら名前の上)。本文インライン・ピッカー・リアクションタイル共通(ピッカーのセル幅可変は Miria 方式参考)。(2) ピッカー: 「全てのemoji」→**「デフォルト」**(見出し長押し → バンドル編集 FOW は M4 プレースホルダー)、その上に**「予測」欄**。予測は絵文字予測.md の初期統合スコアの縮退版(語句一致 0.4 / 履歴 0.3 / 既存リアクション 0.2 / 最近 0.1 — SigLIP 意味検索・GLiNER PPMI 共起・絵文字側の事前埋め込みは ml.infer 配線後に前段へ追加)。(3) **投稿内リアクション数表示** `RasqReactionChips` — アクションバーの上に角丸タイル(絵文字+数、最大10+「+N」、自分のはハイライト、タップで同調/解除)。(4) **リアクション済み絵文字がボタンに反映**: `ActionIcon.text` / `ActionState.iconText` を追加、Misskey は myReaction を Unicode=テキスト / カスタム=/emoji URL でアイコン化(TL にも反映)。(5) ~~予測絵文字のボタン表示は詳細画面のみ~~ → D-041 で全投稿に拡大 | 決定(実装済・ML 前段は残) | 確認: 2026-08-27 |
| D-041 | **絵文字まわり第 2 弾**: (1) リアクションタイルは**絵文字名が同じ変種(`:cat@.:` / `:cat@remote:`)を 1 タイルに合算**し、代表は**ローカルサーバーの絵文字を優先**。ローカルに無い(=リアクションできない)ものは**枠なし表示・タップ不可**。ImageHash による同一判定は絵文字側の事前計算インデックス導入時に追加。(2) ピッカーの「独自の絵文字」は **visibility_detector による遅延読み込み**(見えたセルだけ画像を読む)+ Wrap の不等幅横配列 — 件数上限(240)を撤去。(3) 予測アルゴリズム改: **合計 2 以上リアクション済みの投稿はその中から選出**、上位ほど**指数関数的(重み 2^-rank)**に出やすい(post.key シードの決定的乱択で表示安定)。**予測表示は未リアクションの全投稿**に拡大(表示タイミングのパッシブ駆動 — 純ローカル計算のみ)。カスタム絵文字の予測は reactionEmojis の画像でボタン表示。(4) **ロング絵文字の表示修正**: `RasqCustomEmoji` が実寸解決前に正方形+contain でレタボ化 → **fitHeight(高さ固定・幅可変)+ 上限 3×h** で即時表示。Misskey の**ローカルカスタムリアクション(`:name@.:`)は reactionEmojis に URL が来ない** → `/emoji/<name>.webp` をマッパーで補完 | 決定(実装済) | 確認: 2026-08-27 |
| D-042 | **絵文字まわり第 3 弾**: (1) ピッカーの 1 行 1 絵文字バグ修正 — セル内の素の `Center` が有界制約で全幅化して Wrap が並べられなかった → `Center(widthFactor: 1)`。(2) **予測リアクションの減光**: 未クリックの予測アイコンは**グレースケール + 70%**(`RasqActionBarItem.mutedIcon`)で「未実行」を区別。(3) リアクションタイルのチップに**リアクションしたユーザー**(アイコン + 名前、最大 5 人 + 「+N人」)— チップを開いたときだけ `reactions(postId, type:)` を遅延ロード(`RasqCustomEmoji.chipDetail` / `RasqReactionChips.usersLoader`)。(4) 実装まとめノート「Misskey 実装まとめ(他SNS展開の判断材料)」を Obsidian へ書き出し | 決定(実装済) | 確認: 2026-08-28 |
| D-043 | **ピッカーのジャンル省略表示とパフォーマンス**: (1) サーバー絵文字は**サーバー設定のジャンル(category)毎に省略表示**(ワイヤー準拠): 「サーバー」節の下に「・ジャンル名 + 件数 + ∨」行、折りたたみ時は先頭 12 件(≒1 行)だけ、∨ で全件展開。カテゴリ無しは「その他」。検索中はジャンルを跨いだフラット表示。(2) **展開 5 秒 + FPS 低下の解消**: 数千セルの Wrap 一括ビルド + セル毎 VisibilityDetector が原因 → パネル全体を **`ListView.builder` のフラット行リスト**にし、展開ジャンルも 40 個ずつの Wrap 行に分割して**画面に入った行だけビルド**。visibility_detector は廃止(依存も削除 — ListView の遅延ビルドが同役割をゼロコストで果たす)。予測計算もメモ化(毎ビルドの全カスタム走査をやめる) | 決定(実装済) | 確認: 2026-08-28 |
| D-044 | **SNS プラグイン設定の DSL 化**(設定周り、Misskey 残件の最後): SNS プラグインが `rasq.settings-page/1` の JSON を **`SnsPlugin.settingsPages`** で提供し、ホストが同じ設定 DSL レンダラーで描画する。`area` は短名(account 等)でホストが `sns.<pluginId>.` を前置(名前空間強制)、ルート `/settings/dsl/sns.<area>`、保存は KV `sns.<pluginId>.<area>.v1`。ローカルページの値は変更毎に **`SnsSession.applySettings(area, values)`** でプラグインへ即時反映(TL は snsSettingValuesProvider を watch → 変更で自動再取得)。**`source: "remote"`** ページは KV を使わず **`settingsRead`/`settingsWrite`**(楽観反映 + 失敗巻き戻し + アラート)でサーバー保存。`on: {"tap": "web.open"}` = `k` をパスに web 版へ逃がす(パスワード必要系)。Misskey 実装: **アカウント**(remote: `i`/`i/update` — isLocked/isExplorable/hideOnlineStatus/publicReactions/isBot/isCat、キーは許可リスト制)/**タイムライン**(withRenotes 全 TL + withReplies は home/local/social のみ)/**プライバシーとセーフモード**(sensitiveMedia: blur/show/hide + openCw — post_row が SafetySettings で適用、hide は表示 index→元 index を写像してビューワーに渡す)/**セキュリティ**(MiAuth 権限一覧の日本語ラベル表示 + web 誘導) | 決定(実装済) | 確認: 2026-08-28 |
| D-045 | **コンポーザー投稿オプション + MFM ピッカー + システム通知 + 権限**: (1) **FOW ヘッダー右側の空きスペース**に `FowSpec.headerTrailing`(非破壊追加)でコントロールを配置 — 公開設定ドロップダウン(パブリック/ホーム/フォロワー)・連合トグル(localOnly)・リアクション受け入れドロップダウン(全て/いいねのみ/外部からはいいね/非センシティブのみ/非センシティブ&外部からはいいねのみ = Misskey `reactionAcceptance` 語彙)。状態は `composeOptionsProvider`(本文と共有、起動中は前回値を記憶)、`NewPost.localOnly/reactionAcceptance` 追加 → notes/create へ。(2) **MFM/Markdown ピッカー**(コンポーザーヘッダーの `</>` → 子 FOW): ホーム = 関数名+説明文の縦リスト(コアセット PROTOCOL §2.3 = プレビューが必ず動く範囲)、サブページ = 上にプレビュー(サンプル文字列+ランダムなサーバー絵文字をホストレンダラーで実描画)+ 下にプロパティータイル(左名前/右入力欄、フラグは Switch)、右上「決定」で挿入。挿入は `composerInsertBridgeProvider`(ValueNotifier)経由で本文側が選択範囲を prefix…suffix で包み、**カーソルは中身部分**へ。MFM 非対応 SNS には Markdown カタログ。(3) **システム通知**: `NotificationKind.system` + `NotificationItem.title/body`、Misskey の app/roleAssigned/achievementEarned/login/test/exportCompleted → system、**未知タイプも system に縮退**(落とさない)。通知画面に専用タイル + 通知プロファイルに「システム通知を表示する」。(4) **権限不足の解消**: MiAuth スコープに `write:account`(i/update: Bot設定・クリップ/リスト作成系の 403 原因)+ `write:votes` を追加。**既存トークンには反映されない → 再ログイン必要**。remote 設定の保存失敗時に PERMISSION_DENIED/403 なら再ログイン誘導を表示。(5) **DM 新規作成導線**: DM ホームに「新規メッセージ」→ ユーザー検索シート → 既存ルーム再利用 or 新規ルームでコンポーザー付きルーム画面へ。おまけ: ドロップダウン項目の長ラベルを折り返し可能に(overflow 修正) | 決定(実装済) | 確認: 2026-08-28 |
| D-046 | **D-045 の配置修正 + リレーショナルTL のゲスト遡及**: (1) MFM/Markdown ピッカーの起動ボタンは **コンポーザー下部ツールバー**(絵文字の隣)へ移動 — FOW ヘッダー右側は公開設定/連合/リアクション受け入れの 3 つに。挿入ブリッジ(ValueNotifier)は不要になり削除、ピッカーの onApply が本文の `_wrapSelection` を直接呼ぶ。(2) DM 新規作成は **投稿と同じ + FAB**(タブ行のアイコンから変更)。(3) **ゲスト(リノート/引用で運ばれてきた非フォロイー)の投稿もリレーショナルTL が見る**: `relationalGuestPostsProvider` が最近紹介されたゲスト最大 8 人の userPosts を紹介時刻の 12h 前まで取得(取得完了までゲスト無しで表示 → 届いたら再構築)。エンジンはフォロイーのイベント確定後の**後段パス**で接続するため、**引用より前の投稿にも過去方向リンク**できる(時間減衰は lastActivity ではなく最も近い所属投稿基準、挿入は時系列位置 = 先行投稿が新しい開始点になる)。**脱退は厳しめ**: ゲストは既存イベントへのリンクのみ(ROOT を作らない = 無関係投稿は消える)+ しきい値 `+guestBias`(既定 0.07、RelationalSettings で永続化・旧保存値は既定にフォールバック)+ 紹介が古いゲストは取得対象から外れて追跡が自然終了 | 決定(実装済) | 確認: 2026-08-28 |
| D-047 | **ダイレクトモードの公開範囲修正 + 返信/DM コンポーザーの stick FOW 化**: (1) **ダイレクト投稿への返信は specified 固定**(それ以外はサーバーエラー): `Post.localOnly` 追加・`NewPost.directToIds` 追加、宛先 = 親の author + visibleUserIds(自分を除く)を継承し Misskey `visibleUserIds` へ。**連合可視性も親より広げない**(localOnly の親 → 返信/引用も localOnly)。ダイレクト時は公開設定/連合/リアクション受け入れコントロール非表示 + reactionAcceptance 送信なし。(2) **返信/ダイレクト投稿コンポーザー = stick FOW**: `FowConfirmMode.stick` + widget タイプ(スクリム無し・背面操作可)+ ヘッダーレス。折りたたみ = 1 行入力 + ツールバー、フォーカスで**ヘッダー(タイトル + 投稿オプション + ✕)と返信先タイルが上から割り込む**(AnimatedSize + heightFactor 0.15→0.44、非リサイズパネルは AnimatedContainer で高さも滑らかに)。**根本はフッターメニューの上**: `FowSpec.dockAboveFooter` + `OverlayHost.fowDockInset`(アプリがレイアウトから供給 — <840dp で 81.2+SafeArea、キーボード表示中は従来どおりキーボードの上)。通常/引用コンポーザーは従来のインタースティシャルのまま。**注**: FOW 構造は RRL 拡張時(プラグイン挿入・モーション対応)に作り直す前提の v1 | 決定(実装済) | 確認: 2026-08-28 |
| D-048 | **stick FOW の着地修正**(返信コンポーザー現状.png 起票): (1) ドックインセットのずれ修正 — フッター実高さは `RasqSizes.navHeight = 56`(+枠線 1.2)なのに 80 でハードコードしていて約 24px 浮いていた → 実トークン参照に。(2) **FOW = ドラッグハンドル + 角丸四角形枠の集合 {RRL コンポーネント(FOW 内ヘッダー/フッター)}** という原則(ユーザー定義): stick はコンポーザーアクションバーが FOW 内フッター = 枠の下辺になるため**下側も角丸**(`spec.dockAboveFooter` で分岐。画面最下端まで覆う通常 FOW は上側のみ)。(3) stick は**特定の返信/DM ページに張り付く**もの → `routerProvider.routerDelegate` を listen してページ遷移(戻る・タブ切替)で自動消滅(discard) | 決定(実装済) | 確認: 2026-08-28 |
| D-049 | **FOW の高さ段階(スナップ)とドラッグリサイズ**: `FowSpec.heightStops`(factor 昇順配列、呼び出し時に指定・実行中に差し替え可)+ `freeAboveStops`/`freeBelowStops`(端の段階の外側へ**シームレスに動く / それ以上動かない**の指定)。ドラッグ中は即時追従、離すと段階の間なら最寄りへスナップ(`snapToStops`、外側 free はそのまま)。`userResized` フラグで呼び出し側の自動フィットが手動調整を上書きしない。パネル高さはドラッグ中以外 AnimatedContainer(180ms)— 複数 FOW の過渡期に合計が超えるのは OverflowBox で上へ逃がす。**stick コンポーザーの「全部ピッタリ」計算**: ハンドル復活 + レイアウト後にコンテンツ実測(割り込みヘッダーは AnimatedSize の見かけ高さを自然高さに補正するのでアニメ非依存・タイマー不要)→ 段階 = [折りたたみフィット, 展開フィット] を動的更新、展開時は一旦フィット高さへ。分母はキーボード/フッタードックを引いた実利用可能高さ(`fowDockInsetOf` を共有) | 決定(実装済) | 確認: 2026-08-28 |
| D-050 | **常駐 stick + ドラッグ時テキスト消失修正**: (1) スレッド詳細の返信タイル(_ReplyBarPlaceholder)と DM ルームの疑似入力バーを廃止し、**ページを開いたら縮小状態の stick コンポーザーが常駐**する形に(`showComposer(resident: true, onPosted:)`)。常駐は送信で閉じず下書きリセット + 縮小(返信メンション/CW の下書きプリセットは**最初のフォーカスまで遅延**して縮小状態を保ち、送信後に再アーム)。✕ = 折りたたみ(閉じるのはページ遷移のみ)。ページへ**戻ってきた**ときも `manager.contains(composerFowId)` + `ModalRoute.isCurrent` を見て置き直す。(2) **ハンドル操作で入力テキストが消える問題**: ドラッグ開始/終了で `SizedBox ⇄ AnimatedContainer` を切り替えていたため Element が作り直され TextField の State ごと消えていた → **常に AnimatedContainer 1 種**(ドラッグ中は duration 0)に修正。(3) `fowDockInsetOf` をルーター対応: タブ外のアプリ直下ページ(D-038 の複製ルート)はフッターが無いので持ち上げない | 決定(実装済) | 確認: 2026-08-29 |
| D-051 | **✕ の下書きフローと通常コンポーザー/ピッカーの同手法化**: (1) **下書き**(アプリ起動中メモリ、`composeDraftsProvider`): ターゲット毎(normal / reply:postKey / quote:postKey / dm:roomId)にテキスト+注釈を 1 件保持、開くと復元・送信で消える(添付/投票は対象外)。(2) **常駐 stick の ✕**: 自動入力のメンション(+親の CW)だけなら黙って閉じる(滞在中は再表示しない)。入力があるときは「下書きに保存して閉じる / 破棄して閉じる」の確認シート。(3) **通常/引用コンポーザーを stick と同手法化**: ヘッダーレス(タイトル+投稿オプション+✕はパネル内ヘッダー)+ フッター上ドック + 角丸 + ピッタリ高さ段階。ただしインタースティシャルのままで、**余白(スクリム)クリックで自動的に下書きへ入って消失**(ポップアップなし。dispose の自動保存はマイクロタスク遅延 — unmount 中の provider 変更禁止)。(4) **絵文字/MFM ピッカーも同手法化**: 角丸(dockAboveFooter)+ `barrierBehavior: dismissDiscard` で**余白クリックで消失**(層になっているときは最前面から順に閉じる)。副修正: 常駐 stick の「✕で閉じた」判定はナビゲーション反映後(endOfFrame 待ち)に isCurrent で行う | 決定(実装済) | 確認: 2026-08-29 |
| D-052 | **FOW 外枠と最前面表示 + リアクションピッカーのアクションボタン同伴 + コンポーザーヘッダー 3 分割**: (1) FOW の外枠は**グレーの線**(outlineVariant)で全パネル共通、**影は最前面(最新)のパネルだけ** — 複数 FOW を開いたときの判別。**グレーアウト(スクリム)はインタースティシャル(+ボタンの投稿コンポーザー)だけ**: ピッカー類の余白クリック消失は透明バリアで受ける(背面を暗くしない)。(2) **投稿への絵文字コンポーザー(リアクションピッカー)に対象投稿のアクションボタンを同伴**: 基本**下付き**、パネル高さが最小配列(240px)より小さいと判定されたら**逆付き(上)**。バーの枠を**ピンチ(2 本指縮小)で逆サイドへ移動**(未実装の第3カラムへの移動も将来同じ手法)。(3) **コンポーザーヘッダー**: 「キャンセル」(左揃え)/「投稿/返信」(太字・中央)/「下書き」(青文字・右揃え、保存して閉じる。内容が無ければ無効)。キャンセル = 従来の ✕ フロー(常駐はメンションのみなら即閉じ・入力ありは確認)。投稿オプション(公開設定/連合/リアクション受け入れ)は下部ツールバーへ移動 | 決定(実装済) | 確認: 2026-08-29 |
| D-053 | **リアクションピッカーの付き方をワイヤーフレーム準拠に + 文字サイズ統一**(現状.png / 最新の全てのワイヤーフレーム.pdf 1p 左下起票): (1) 既定は**下方向へつく** = アクションバーがパネル**上辺**、ドラッグハンドルは**反対側の外縁(下辺)**。ホスト側の上辺ハンドルは消し、パネル内の外縁ハンドル(`FowSpec.dragging` ノーティファイア経由でホストが即時追従)に置き換え。(2) **バー(ヘッダー枠)を掴んで上下ドラッグ → 掴んでいる間はハンドル消失、離した位置で上付き/下付き(+ハンドルを出す側)が決定**(24px 未満は据え置き)。ピンチ方式 (D-052) は置き換え。自動判定(高さ < 240px で逆付き)は維持、手動指定が優先。未実装の第3カラムへの移動も将来同じ手法。(3) **文字サイズを絵文字ピッカー側に統一**: コンポーザー本文入力 = bodySmall(ピッカー検索欄と同じ)、ヘッダータイトル = titleMedium(FOW ヘッダーと同じ) | 決定(実装済) | 確認: 2026-08-29 |
| D-054 | **リアクションピッカーを完全ヘッダーレスに**(スクショ起票: ヘッダーが FOW の外に見える + アクションバーが枠内で増殖して見える): アクションバー同伴時は FOW の「閉じる/タイトル」行を出さず、**バー自体が角丸枠の上辺(= 掴めるヘッダー枠)**になる。閉じるのは余白クリック / esc。枠線の二重化も解消(パネル上枠線はヘッダー有りのときだけ、バーの枠線は内側 1 本のみ)。コンポーザー子の絵文字ピッカー(バー無し)は従来のヘッダー付きのまま | 決定(実装済) | 確認: 2026-08-29 |
| D-055 | **リアクションピッカーのヘッダー行復活 + 複製バー撤去**(スクショ起票): D-054 の完全ヘッダーレスを撤回 — **閉じる/タイトルのヘッダー行は残す**(クロームは 2 系統を維持: ①ヘッダー行系 ②アクションバー系=バーが枠の縁・掴んで離した側に付く)。パネル内に**呼び出し元投稿のアクションバーの複製を置くのは誤り**(「謎のアクションバー」に見える + バグ源)と指摘 → 撤去し、リアクションピッカーは①に戻す。ワイヤーフレーム 1p 左下の「付き方」の本来形 = **タイムライン上の実物のアクションバーに FOW をアンカーする**で、FOW 再設計(RRL 拡張・第3カラム)時に②系統で実装する。②系統のコード(バー上辺/掴んで反転/外縁ハンドル)は EmojiPanel に休眠のまま残しテストでカバー | 決定(実装済) | 確認: 2026-08-29 |
| D-056 | **M5 方針(プラグイン/RRL 統合)+ 第3カラム v1**: 入力は「デバイス側の基本思想.pdf」(主)と「WFをベースにざっくり.md」(参考 — placement 表/variant 軸の語彙)。骨格 = プラグイン 2 面(**画面コンストラクタ** RRL 受け渡し / **イベントハンドラー** 関数呼び出し)+ レンダラー 2 種(通常ページ / **タイムラインレンダラー** = Widget コンポーネント+ソート+投稿カスタマイザ)+ カルクレーター = MlGateway。決定: ①着手順 **カラム分け→FOW→TL**(Surface 土台は各段で薄く) ②**wasm は非同期 v2 を先に**(Worker isolate + 非同期 host-fn) ③**関連TL は wasm 移植するが TL プラグイン扱いにしない**(アカウントバンドル全アカウントの TL を見る特別枠 — SNS プラグインの icon/body タグ付けが必須なのはこのため。カスタム TL のみ通常 TL プラグイン)。実装第 1 弾 = **第3カラム v1**: `ThirdColumnStore.open/close`(補助面 API、M5c で FOW の移動先になる)、空時は検索(KV `thirdColumn.v1` の `empty`、カラムの歯車から search/none を切替)。詳細: Obsidian「M5 方針 (プラグイン・RRL統合)」 | 決定(v1 実装済) | 確認: 2026-08-29 |
| D-057 | **ペインモデル(previous/current 交互)+ カラム幅変動 + FOW 幅 1200 上限**: タブレット幅のページオープン規則 — **第2カラムから開く**と第2は表示そのまま**検索ホーム幅(320)へ縮み**、新ページが第3カラム(広)に出る。**第3カラムから開く**と居たページが**第2カラム(router へ push)に移動**し、新ページが第3カラムへ。空の第3カラムは検索(狭)で第2が広い。実装: `openPageInPanes`(pushPost/pushUser/pushTrend が経由、タブ配下のみ)+ `PaneScope`(第3カラム発の判定)+ entry に location/extra(第2へ移すときの router push 用)。第3カラムの ✕/破棄時はページ常駐コンポーザーも一緒に閉じる。幅は AnimatedContainer(200ms)。**FOW 幅はページ幅または 1200px**: 広い画面では 1200px 上限で中央寄せ(カラム別の幅追従・カラム間移行での幅変更は M5c) | 決定(実装済) | 確認: 2026-08-29 |
| D-058 | **ペインの戻りは小画面モードと同じ < で完結(✕ は出さない)**: ページ entry のヘッダーは常に **<(戻る)** のみ — previous があれば取り戻し(第2カラムの router 複製は最深マッチ一致時だけ pop)、無ければ閉じて検索へ(一発では閉じない)。**< 長押しで「どこまで戻るか」のドロップダウン**(previous チェーンのタイトル一覧 + 閉じる。選ぶと途中の router 複製をまとめて pop して一気に戻る)。✕ を持つのは補助面(location 無し = FOW 移動など)だけ | 決定(実装済) | 確認: 2026-08-29 |
| D-059 | **ペイン戻りをページ自身の < に統合**(起票: カラム専用ヘッダーとページヘッダーの二重でズレる): 第3カラムのページ entry はカラム専用ヘッダー行を出さず**全面表示**。戻り(D-058 の paneBack + 長押しの「どこまで戻るか」)は **RasqPageHeader の < ボタン**が PaneScope を見て実行する(将来この長押し履歴を他画面の < にも広げる予定)。カラムヘッダー(タイトル+✕)を持つのは補助面(location 無し)だけ | 決定(実装済) | 確認: 2026-08-29 |
| D-060 | **FOW を掴んで第3カラムへ移動**(M5c 第 1 弾): ドラッグハンドル(またはリアクションピッカーのバー=ヘッダー枠)を**右へ 100px 以上掴んで動かす**と、FOW を閉じて同じ面を第3カラムの補助面(タイトル+✕)として開く — 幅はカラムに追従(「カラム間移行で幅も変わる」の実現)。機構は `FowSpec.onMoveAside`(オーバーレイは「横へ掴まれた」ことだけ検知し、移動先はアプリが渡す)+ EmojiPanel の `onMoveAside`(バー掴み)。対象: 絵文字ピッカー(リアクション/コンポーザー子)と MFM ピッカー。第3カラム側でのピック/決定も元のコールバックがそのまま動き、closeOnPick 相当で面が閉じる。コンポーザーの移動は下書きストア経由の再構築で実現予定(次段) | 決定(実装済) | 確認: 2026-08-29 |
| D-061 | **カラム移動の視覚追従 + 第3カラム内リンク切れ修正**(実機起票): (1) 最大画面で「中央に固定されて動かない」ように見えた → 移動可能な FOW はハンドルを掴んでいる間**パネルが右へついてくる**(Matrix4 平行移動、離すとしきい値未満は中央へアニメ復帰・超えたら第3カラムへ)。(2) 第3カラム内ページの相対リンクが `matchedLocation`(第2カラムのルート)基準で壊れていた → **pushReactions** は PaneScope の entry.location 基準に + ペイン規則で開く。**pushFollows** もペイン対応。**replaceTrend** は第3カラム内では entry を差し替え(`replacePageInPane` — previous を引き継ぎ第2カラムへは移さない) | 決定(実装済) | 確認: 2026-08-29 |
| D-062 | **FOW 横ドッキング(役割分担 + 壁で最大化)**(起票: ハンドル横移動は上方向操作の誤爆源): D-060 の「第3カラムの中身に変換」方式を撤回し、**FOW をオーバーレイのままカラムへ横ドッキング**する方式に。①**役割分担**: ドラッグハンドル = 縦リサイズ専用に戻す。**FOW 内ヘッダー/フッター(`FowMoveGrip`)を掴む = 左右カラム間移動**(コンポーザーはヘッダー行とツールバー、ピッカーはクロームヘッダー行、リアクションピッカーのバー系統はバー自体)。②FOW は**カラム中心に揃いカラム枠内に収まる幅**でドック(`FowSpec.columnIndex` + `OverlayHost.fowColumns` でアプリがカラム幾何を供給、モバイルは単一スロット=全幅 1200 上限)。掴んでいる間はパネルが横追従。③**両端の壁に 50px 以上めり込ませたとき最大化**(スナップ後の幅基準で判定 — 幅広パネルの隣カラム移動では最大化しない)。開いた側のカラムに初期ドック(`fowColumnOf`: 第3カラムのページ発 → 第3カラム側) | 決定(実装済) | 確認: 2026-08-29 |
| D-063 | **横ドッキングの微調整(しきい値 + 壁付けピン)**(起票: 広いカラムで移動判定が厳しい / 壁付けが中央最大化になってしまう): ①カラム間移動の判定を**ウィンドウ幅の 1 割**に — 最寄りカラムが変わらなくても 1 割以上動かしていれば隣のカラムへ移す(従来は中心間の中点越えが必要で、808px カラムだと 280px 以上引っ張る必要があった)。②壁へ 50px 以上めり込ませたときは**中央への全幅最大化ではなく壁付けピン**: 壁側に**検索ホーム幅(`OverlayHost.fowPinnedWidth` = `kSearchHomeColumnWidth`)・最大高さ**で張り付く(1 カラム全面占領、元画面は覆わない)。`FowSpec.maximized` → `pinnedWall`(-1/0/1)。ピン中は小さな揺れでは外れず、内側へ 1 割以上動かすとカラム揃えへ戻る | 決定(実装済) | 確認: 2026-08-30 |
| D-064 | **FOW の RRL surface 化 第1弾 = `fow.open`/`fow.close` の実配線**(M5c): WASM プラグインが RRL ツリー付きで実 FOW を開けるようにした。①`RasqHostEnvironment` に fow.* の検証(id/root 必須 = D01、type ∉ 許可 = E01、未配線 = E01)+ `onFow` 中継口と `fowPermissions`(既定 widget のみ)。②ワーカー isolate は fow.* を**fire-and-forget でメインへ中継**(wasm には即 `{opened:true}` = 受理。UI isolate 非ブロックの非同期 v2 方式)。③両コントローラに `WasmFowSurfaceMixin`: `onFowOpen`(root を rev1 snapshot として `RrlDocument` 化した `WasmFowRequest`)/`onFowClose` コールバック + `notifyFowClosed`(FOW クローズ → プラグインの `onClosed` 関数を call。**マイクロタスクへ逃がして wasm 再入を防止**)。④アプリ層(dev 画面)がワイヤ spec → `FowSpec` 写像(ヘッダー行クローム、dockAboveFooter、columnIndex=`fowColumnOf`、barrier=dismissDiscard、ownerId で一括クローズ)し `WasmFowView`(RrlRenderer)を中身に。⑤プロトコル拡張: `fow.open` に `onClosed?`(閉時に call する関数名、args `{id, reason, result?}`)、同一 id 再要求 = root 差し替え。サンプル Rust プラグインに FOWデモ(pickReaction → 絵文字 FOW → reactFromFow が fow.close)を実装。patch のドキュメント多重化・lifecycle visible/hidden・実物アクションバーへのアンカーは後続 | 決定(実装済) | 確認: 2026-08-30 |
| D-065 | **FOW 付け先の完成 + FOW スイッチャー**(M5c、FOW 動作系はこれで完成): ①**付け先**: 下端ドック(既定)/**アプリヘッダーに下付き**(`FowSpec.attachTop`、上端 = `OverlayHost.fowTopInset` が供給するヘッダー実高さ、角丸は下側のみ・ハンドルは下端でリサイズ向き反転)/**実物アクションボタンへのアンカー**(`FowSpec.anchor` = ボタン矩形。基本下付き = ボタン下辺に FOW 上辺、下の余白が最小段より小さければ上付き。角丸全周)/壁付けピン (D-063)。②**FOW 内ヘッダー/フッター(`FowMoveGrip`)は pan 化して上下移動にも対応**: 縦も**左右と同じ比率(ウィンドウ高さの 1 割)**で確定 — 通常 FOW はヘッダー下付き ⇄ 下側、アンカー FOW は上付き ⇄ 下付きの反転。**アンカー FOW は別カラムへ動かした時点で壁付き表示**(anchor 解除 → `pinnedWall`)。③**重ね表示**: スロット内の縦積み(高さ分割)を廃止し、各 FOW を付け先ごとに独立配置(最前面のみ影 = D-052 維持)。④**FOW スイッチャー**: ドラッグハンドルの**クリック**で移行 — 背景ブラックアウト + FOW をリスト表示(APP スイッチャー風)。選択で前面化し、**親を選ぶと子(ownerId)は自動クローズ**(コンポーザー→絵文字/MFM ピッカー)。✕ で個別クローズ、余白タップ/戻るで復帰。パネルは Offstage で生かして入力状態を保持。リアクションピッカーはボタン長押しの矩形(`RasqActionBarItem.onAnchorLongPress`)でアンカー起動 | 決定(実装済) | 確認: 2026-08-30 |
| D-066 | **FOW スイッチャーのプレビュー + ✕の確認割り込み**(起票: FOW 名だけだと分かりづらい): ①スイッチャーを開く直前に各パネルを `RepaintBoundary`(`FowSpec.previewBoundaryKey`)からキャプチャ(`OverlayManager.openFowSwitcher`、pixelRatio 0.6)し、カード上部に縮小表示(失敗時は名前のみに縮退)。②**✕の割り込み**: `FowSpec.interceptCancel` — 設定時クロームのキャンセルは閉じずにこれを呼ぶ。プロトコル `fow.open` に `onCancel?`(押下時に call する関数名、args `{id}`。指定時ホストは閉じない)を追加し、**プラグインが画面そのままの確認ポップアップ(確認 FOW)を出して自分で fow.close** する。サンプル Rust プラグインで実証: ✕ → `confirmCloseFow` が「閉じますか?」FOW(破棄/続ける)を開き、破棄 = 両方 close・続ける = 確認のみ close | 決定(実装済) | 確認: 2026-08-30 |
| D-067 | **親子 FOW の回避伸縮**(起票: FOW 内のアクションボタンから開いた子 FOW がコンポーザー入力部に被る): ①子 FOW(ownerId = 親 FOW entry の id)は**親の付く方向・カラムに追従**(方向は親側指定 — 親をヘッダー付きへ動かせば子も更新)。②**親は子の高さぶん外側から持ち上がり/下がる**(下ドックなら padBottom += 子高、ヘッダー付きなら padTop += 子高。子の `heightFactor` はレイアウトが購読済みなので**リサイズにリアルタイム追従**、必要なら親自体も縮む)。コンポーザー(親)+ 絵文字/MFM ピッカー(子)は ownerId 連鎖が既存のため自動適用。③**親クローズで子は連動クローズ**(CONTRACT の「子FOWは ownerId で連動」をマネージャーに実装。ownerId が entry id でないプラグイン所有などは影響なし)。④プロトコル `fow.open` に `parentId?` を追加(「persistent 包み」の宣言に相当)— サンプルの「閉じますか?」確認 FOW を子として実証 | 決定(実装済) | 確認: 2026-08-30 |
| D-068 | **回避伸縮の方式修正 = FowChildGap**(起票: D-067 の「ホストが親パネルを持ち上げる」は違う — **FOW ウィジェット内に高さ可変 padding を置いて高さを変える**方式): ①ホストの持ち上げを撤回 — 親の**枠は根本に付いたまま子の高さぶん伸びる**だけ(`h += 子高`)。②`FowSpec.childGapTop/childGapBottom`(ValueNotifier)— ホストのレイアウトが子の付いている側と高さをリアルタイムに書く(子がいなければ 0)。③**`FowChildGap` ウィジェット**(高さ可変 padding、子なし = 0px)— FOW ウィジェット内に置くとその側の子の高さに伸び、アクションバー/入力部を子の反対側へ押し出す。コンポーザーは**アクションバーの前後**に 1 つずつ配置(下ドック時は後ろ側が伸びてバーが子ピッカーの上辺に載る。親の付け先が変われば伸びる側も切り替わる)。RRL 側の gap ノード(persistent 包みの L2 化)は placement 語彙の露出と一緒に後続 | 決定(実装済) | 確認: 2026-08-30 |
| D-069 | **リプライ元の省略タイル + 返信TL/引用TL の振り分け**(起票: TL/リプライ欄で 1 つ前の投稿が思った形で出ない): ①`Post.replyTo`/`replyToId` を追加(Misskey `note.reply` を写像、純リノートにも継承)。②**`RasqReplyParentTile`**(L2、ワイヤーフレーム p.5 DM ルームの「1件の添付リンク」タイル準拠): 小アバター + 名前、右端に「N件の添付ファイル/1件の添付リンク」、本文 1 行抜粋、下の返信へ**スレッド線(stem)**。接着は `ReplyParentRow`(spans/絵文字/pushPost)。③TL のリプライは PostRow が上に積む(`showReplyParent`)。スレッド展開画面は ancestors を省略タイル化(全文 PostRow をやめる)、直接の返信には出さない(孫返信のみ)。④**ユーザーページに「返信」タブを追加**し振り分け: `UserPostsFilter.replies`(返信のみ)/ quotes(引用のみ)/ **posts は両方を除外**(純リノートは残る)— タブ = ノート/返信/引用/メディア/クリップ | 決定(実装済) | 確認: 2026-08-30 |
| D-070 | **返信欄ドロップダウンの改良(振り分けの操作系)**: 投稿ページ(スレッド展開)の「∨」— ①**短押し = 並び順**: 関連順(SigLIP)/リアクション数/キーワード順(GLiNER)/デフォルト(`ThreadSortOrder`。SigLIP/GLiNER 配線までは関連TLと同じルールベース近似 = `ruleBasedSimilarity`/特徴語一致)。②**長押し = 欄の切り替え**(`ThreadSectionMode`): 引用(リノート = リノートした人。**リアクション数は無効**、関連/キーワードは**プロフィールからソート** = `extractFeaturesText`)/返信/リアクション(**Misskey のみ表示**、`ReactionSections` を公開して埋め込み)/共有(引用ノート = 新 API `SnsSession.quotes`、Misskey は notes/renotes から引用のみ)。③**設定はキャッシュに残す**: KV `threadReplies.v1`(order/mode)で全スレッド共有。リアクション画面の共有タブも placeholder → 引用ノート一覧に | 決定(実装済) | 確認: 2026-08-30 |
| D-071 | **返信欄はリプライだけ**(起票: Twitter 等に寄せる): Misskey の `notes/children` はリプライと引用リノートが混ざって返る — スレッド展開の返信欄・リアクション画面の返信タブは **`replyTo`/`replyToId` を持つ投稿だけに絞る**(引用は D-070 の「共有(引用ノート)」欄で見る)。絞り込みは表示側(SNS 非依存、D-069 のモデルを利用) | 決定(実装済) | 確認: 2026-08-30 |
| D-072 | **M5c 続き: placement 語彙の露出 + ジオメトリ登録簿 + lifecycle**: ①**`RrlGeometryRegistry`**(rrl_renderer): `role` 付きノードを登録し、矩形は呼ばれた時点の RenderBox から解決(スクロール追従)。コントローラが 1 個持ち `RrlHost.geometry` に渡す — FOW の実物アンカーと将来の `geometry.lookup`/RAi 位置検索の土台。②プロトコル `fow.open` 拡張: `spec.attachTop`(ヘッダー下付き)+ **`anchor {node?|role?}` = 自ドキュメントの実物ノードへアンカー**(ホストが登録簿から現在矩形を解決、不可なら通常ドックに縮退)。サンプルはリアクション FOW を呼び出し元バーの key にアンカー(バー key はタイル毎に一意化)。③**lifecycle mount/unmount**: v1 wasm ABI では `call("lifecycle", {kind, surface})` として届く(mount は論理マウント一度だけ — 同一 id 差し替えでは送らない。未対応プラグインの C01 は無視)。visible/hidden は TL レンダラー(M5e)で。patch のドキュメント多重化は次段 | 決定(実装済) | 確認: 2026-08-30 |
| D-073 | **patch のドキュメント多重化(M5c 完了)**: ①patch メッセージに **`surface?`**(FOW surface の id)を追加 — 指定時は該当 FOW ドキュメント(open 時 rev 1)へ原子適用。rev 不一致・未知 surface は**破棄**(プラグインは再 `fow.open` で resync)。本体ドキュメントは従来どおり(不一致 → snapshot resync)。②引き取りの口: v1 は call の戻り値 **`patch: true`** でホストが `patch()` を引き取る(`treeUpdated` の姉妹)。③`WasmFowView` はコントローラ通知のたびに `fowDocument(id)` から最新を読み直す(FOW を開いたまま差分更新)。サンプルで実証: リアクション FOW の「+1」→ `setProp` の surface patch でカウンターだけ更新 | 決定(実装済) | 確認: 2026-08-30 |
| D-074 | **M5d 開始: SnsSession 契約の boundary 写像 v1**(基本思想「イベントハンドラー関数は抽象的な関数で共通化 → SnsSession 契約の boundary 写像として wasm 化」): ①**Post ワイヤ `rasq.post/1`**(`SnsWire`、rasq_models): 投稿/ユーザー/メディア/投票/Page の JSON codec(quote/replyTo 再帰込み)。閲覧アカウントのキー付けはワイヤに含めず取り込み時にホストが与える。②**`WasmSnsSession`**(SnsSessionBase 拡張): 抽象関数を `call("sns.<fn>")` に写し、result.error はコード付き `SnsApiException` へ(ホストのエラービュー/リトライがそのまま効く)。未実装関数は UnsupportedError のまま = UI を隠す既定。v1 は `sns.timeline {kind, limit, cursor?}` → `{page}`。③サンプル Rust に `sns.timeline` 実装(net.fetch を RRL 版 timeline と共用)、dev 画面「境界TL」ボタンで **Post ワイヤ → ホストの PostRow パイプライン実描画**を実証。PROTOCOL §4.3 に規約明記。残り: sns.* の増線(thread/createPost/performAction…)+ 実セッション登録の口 | 決定(実装済) | 確認: 2026-08-30 |
| D-033 | **ストア契約 = OpenAPI**(protobuf にしない): `rasq-sdk-sample/openapi/store.yaml` をクライアント側から先に定義(v0 済み)。REST/JSON、将来 WebTransport 化してもペイロードのスキーマは流用。エンドポイント: home / 検索(探索フィルタ) / プラグインページ(常設安全性ブロック SafetyBlock・互換性 Compatibility) / manifest(構成取得=インストール確認シートの根拠、`permissionsAdded` で権限増加を明示) / artifacts(DL) / reviews(実利用済み・開発者返信・参考になった) / releases / bookmarks。状態表記は `PluginStatus` enum(審査中/公開中/更新あり/警告/停止/取り下げ/非公開/ベータ/失効)で統一し rasq_design のステータストークンと 1:1 | 決定 | 確認: 2026-08-26 |
| D-034 | **配布物フォーマット**: `.rasqpkg` = **Zstd 圧縮 tar**(manifest.json + wasm + RRL/RSL アセット + models/)。整合性は**アーティファクト毎の SHA-512**(モデルは model-manifest の sha512 と一致必須)、署名は **ed25519(ストア鍵)**。インポート(サイドロード)は開発者鍵 + 警告表示。**ML モデル実体(mt5_copy.onnx / spiece.model / gguf 等)は `kind: model` の遅延ダウンロード可能アーティファクト**として同じ機構で配布(D-024/D-029 の「M4 ストアで配布」の実体) | 決定 | 確認: 2026-08-26 |
| D-035 | **設定値の保存規約**: ホスト設定 = アカウント毎 KV(sessionStorage)にキー `<area>.<name>.v1` の JSON(既存の `actionBar.post.v1` / `relational.settings.v1` / `relational.ema.v1` / `clips.host.v1` が先行例)。アカウント非依存(外観など)はグローバル KV。プラグイン設定 = `storage.safe`(プラグイン名前空間、ホストは中身に触らない)。設定 DSL の Bind `$.settings.<key>` はこの KV に解決される | 決定 | 確認: 2026-08-26 |

**既知の課題**: 絵文字ピッカー FOW は投票欄(PollEditor)へ挿入できない(Miria 系でも同様の挙動、優先度低)/ 大画面(タブレット)で第3カラムが使われない(M0 残件) / 通知プロファイル未永続化。

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
