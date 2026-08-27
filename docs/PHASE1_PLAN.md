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
