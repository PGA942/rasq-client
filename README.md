# RASQ Client

プラグインベース・クロスプラットフォームSNSクライアント **RASQ** の Flutter アプリ(第一期)。
対応バックエンドは Fediverse / AT Protocol(Bluesky・Misskey・Mastodon)。プラグインUIは独自宣言型DSL(RRL)をWASM上で動かし、Dart側レンダラーが描画する。

- 実装計画・決定台帳: [`docs/PHASE1_PLAN.md`](docs/PHASE1_PLAN.md)
- サーバー側: 別リポジトリ `ORGATE-server`

## 構成(pub workspace モノレポ)

```
/                     rasq_client  — Flutterアプリ本体(ワークスペースルート)
  lib/app/            MaterialApp / go_router / Riverpod providers
  lib/shell/          レイアウト(モバイル/タブレット)・ヘッダー4種・グローバルナビ・サイドバー
  lib/features/       画面(home / search / vc / notifications / dm / settings / catalog)
  lib/mock/           M0〜M2用モックデータ
packages/
  rasq_models/        共通データモデル(Post/User/Media/Poll/ErrorCode/AccountId)
  rasq_design/        デザイントークン・テーマ・L2 Standard Components(ホスト実装)
  rasq_overlay/       Overlay Manager(階層・同時表示・クローズ挙動・競合ルール)+ プリセット
  rasq_store/         Store/Signal(アクション状態・既読・フォロー状態・キャッシュ)
```

今後追加予定: `rasq_plugin_api`(SnsPlugin契約/ActionRef/function.json)、`sns_bluesky` / `sns_misskey` / `sns_mastodon`、`rrl_core` / `rrl_renderer` / `plugin_runtime`。

## 開発

```bash
flutter pub get          # ワークスペース全体を解決
flutter analyze          # ルート + packages/*
flutter test             # アプリ
for p in packages/*; do (cd "$p" && flutter test); done
flutter run              # 起動。サイドバー →「コンポーネントカタログ (dev)」で部品一覧
```

Web クライアント(D-295 / D-456)は Central の `/app/` で配る形に作る(`--base-href /app/`、path の URL):

```bash
RASQ_CENTRAL_URL=https://central.example ORGATE_BASE_URL=https://orgate.example tool/web/build_web.sh
# → build/web を Central の CENTRAL_WEB_APP_DIR に置く(rasq-central docs/API.md 4c')
```

プラグインのサイドロード(「WASMプラグイン試験 (dev)」から読み込む / スロットに登録する)は、**自分の開発者鍵で署名した
`.rasqpkg`(`rasq build` が隣に `.sig.json` を出す)とアプリ同梱のものだけフル機能**、ほかは**制限モード**
(通信 / GPU / `storage.unsafe` / interstitial・system の FOW / `composer.open`・`astell.share`・`mute.add`・`url.open` が閉、fuel は半分)。
試験画面の全権限は debug ビルドだけ。表は `lib/features/plugins/sideload_trust.dart`(D-308、rasq-sdk-sample `CONTRACT.md` §8)。

静的チェック(CI の `flutter` の analyze / `semgrep` / `osv` / `deny`。GitLab の SAST と秘密情報の検出は別に回る):

```sh
flutter analyze                                    # analysis_options.yaml: strict-casts + lint(packages/* も同じ規則)
cp -r .semgrep /tmp/semgrep-rules && semgrep --test --metrics=off /tmp/semgrep-rules   # 規則の例で規則そのものを確かめる(隠しディレクトリの中では見つからない)
semgrep scan --metrics=off --error --config .semgrep --exclude .semgrep --exclude build --exclude .dart_tool --exclude vendor lib packages test tool web
osv-scanner scan --lockfile pubspec.lock --lockfile tool/zstd-wasm/Cargo.lock   # 依存の既知の脆弱性
(cd tool/zstd-wasm && cargo deny check)            # Web 版 zstd wasm の Rust 依存 (deny.toml)
```

`.semgrep/` はこのコードベースの約束: ログに出るトークン、タイムアウトの無い HTTP 要求、ランタイムの
ネイティブ net.fetch / gpu.compute に渡す権限ゲート (`nativeFetchEnabled` / `effectiveFetchHosts` / `gpuComputeEnabled`)、接続先の照合の写し
(`fetchHostPermitted` の 1 か所だけ)、`launchUrl` の外部ブラウザ固定、外部コマンド、Web 版 Worker の
接続先 / リダイレクトの確認、`eval` / `innerHTML` / `dart:html`。確かめたうえでの例外は、その行の前に
`// nosemgrep: <規則の id> — 理由` と書く。

設計原則(抜粋):

- **状態はDSLの外**: 状態は `rasq_store` の Notifier に置き、コンポーネントは Props で受け取るだけ(SNSプラグイン → Store → Props)。
- **オーバーレイは必ず Overlay Manager 経由**: `showDialog` / `showModalBottomSheet` を直接呼ばない。
- **L2 Standard Component はホスト実装**: 画面側でも RRL 側でも同じ部品を使う。ジオメトリトークン(spacing・最小タップ域44dp)はプラグインから変更不可。
- **スケルトンローディング禁止**: ローディングサークル(`RasqLoading`)を使い、表示可能になったら一瞬で出す。
