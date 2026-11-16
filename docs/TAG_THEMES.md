# ハッシュタグのテーマ: コミュハッシュタグと RASQ Atmos(D-582〜D-584、Central への提案)

rasq-central には手を入れていない。クライアントは機能フラグ(`lib/app/feature_flags.dart`、**既定は無効**)の下で、
この文書の口を呼ぶ形まで作ってある。無効のときは入口(設定の行・画面の飾り)を出さず、下の口も呼ばない。
テストは偽のサーバー(`package:http/testing` の MockClient)で確かめている。

- コミュハッシュタグのテーマ(`communityTagThemes`): 自分のコミュニティのハッシュタグにテーマを付ける。**サブスク加入 +
  自分のコミュニティのタグを宣伝した投稿を添えて申請**し、審査で通ると、そのタグのページ(トレンドのタグの TL)を開いた人に、
  そのページの表示だけテーマが付く。
- RASQ Atmos(`atmos`、アドハッシュタグ): ハッシュタグがフック。付いた投稿に SVG のアイコン / アクションのボタンで SVG の
  アニメーション / そのスレッドの表示だけのテーマ。**計測はインプレッション = RASQ アプリへの配信回数だけ**(サーバーで数える)。
  規模が大きくなるまで無効。広告主の申し込み・審査・請求はこの文書の外(Web の管理画面などで決める)。

テーマの中身は第3回のテーマのデータ(`RasqThemeSpec`、docs/THEME_FRAMES.md)をそのまま使う。

## 1. 配る 1 件(コミュハッシュタグと Atmos で共通)

```json
{
  "id": "ct_01HZX…",                       // ^[A-Za-z0-9_-]{1,64}$
  "kind": "community | atmos",
  "tag": "rasqart",                          // 先頭の # なし。アプリは小文字にして比べる。空白・記号なしの 64 字まで
  "theme": { "v": 1, "basic": {…}, "frames": [ … ], "triggers": [ … ] },   // RasqThemeSpec(THEME_FRAMES.md)
  "thread": true,                            // Atmos だけ: スレッドの表示だけのテーマを付けるか
  "until": "2026-12-31T15:00:00Z"            // 配信の終わり(省略可)。過ぎたものはアプリが使わない
}
```

- アプリは `theme.source` を `kind` から(`communityTag` / `atmos`)、`theme.scope` を `{"kind":"hashtag","key":<tag>}` に
  **置き換える**(サーバーの値は見ない)。Atmos のスレッドのテーマは、表示のときに `thread`(根の投稿)の範囲にする。
- `frames` は 6 枚まで(多い分は捨てる)。SVG は ID で `GET /api/v1/theme-svgs/{id}`(THEME_FRAMES.md)から引き、アプリは
  受け取ったあとにも `SvgLite.parseStrict`(16 KiB・要素 400・数 8,000)で消毒する。
- コミュハッシュタグは `triggers` を持たない(来ても捨てる)。
- Atmos の `triggers`(8 個まで):
  - `{"kind":"hashtagBadge","hashtag":"<tag>","svg":"<id>"}` — そのタグの投稿の名前の行に SVG のアイコン。`hashtag` が
    その 1 件の `tag` と違うものは捨てる。
  - `{"kind":"actionAnimation","action":"<id か種類>","svg":"<id>","motion":"pop|spin|float|burst"}` — そのタグの投稿で、
    そのアクションのボタンを押したときに 1 回再生。`action` はアクションの ID(`reaction` / `renote` / `like` …)か種類
    (`Reaction` / `Repost` …、大文字小文字は見ない)。`motion` は**アプリが決まった動きで静止した SVG を動かす**名前
    (知らない名前は `pop`)。**SVG の `<animate>` / `<set>` / スクリプト / 外部参照は使えない**(登録のときに捨てる。アプリの
    消毒でも残らない)。端末の「動きを減らす」では再生しない。
- 同じ `kind` で同じ `tag` が複数あれば、アプリは先のものだけ使う。サーバーは 1 つのタグに 1 件だけ配ること。

## 2. 一覧の配信 — `GET /api/v1/tag-themes?via=app`

```
200 {"entries": [ <1 件>, … ], "refreshSeconds": 21600}
```

- **認証なしで取る**(アプリはトークンを付けない)。アプリは**どのタグを見ているかを送らない**: 有効な一覧をまるごと取り、
  手元で投稿のハッシュタグと突き合わせる。一覧は 500 件まで(超えた分はアプリが捨てる)。
- `refreshSeconds`(900〜86400、省略は 21600)ごとにアプリが取り直す。アプリの起動のあいだに 1 回目を取る。
- 有効なもの(審査済み・期間内・サブスクが有効なコミュハッシュタグ / 配信中の Atmos)だけを載せる。
- 取れない(5xx / 通信できない)ときは、アプリは飾りを出さないだけ。

### インプレッション(Atmos の計測)

- **インプレッション = RASQ アプリへの配信回数**。`via=app` の要求に 200 を返したとき、載せた Atmos の 1 件ごとに 1 を足す。
- 数えるのは配信した側(Central)だけ。**アプリは閲覧・表示・タップ・アニメーションの再生を送らない**(送る口も作らない)。
  利用者の id・IP・端末の情報は、数に結び付けて残さない(1 時間ごとの合計だけを持つ)。
- `via` が無い要求(Web や開発の道具)は数えない。数え過ぎを避けるため、同じ接続元から `refreshSeconds` より短い間隔で
  来た分は数えない(接続元は合計の判定のあいだだけメモリに置く)。
- 広告主に見せるのは期間ごとのインプレッションの合計だけ。

## 3. コミュハッシュタグの申請(RASQ アカウントのトークンが要る)

### 状態 — `GET /api/v1/me/community-tags`

```json
{
  "subscription": {"active": true, "plan": "RASQ Plus"},
  "limit": 1,
  "applications": [
    {"id": "ct_01…", "tag": "rasqart", "state": "pending|approved|rejected|suspended|withdrawn",
     "theme": { RasqThemeSpec }, "promoUrl": "https://…", "reason": "promo_missing",
     "createdAt": "…", "decidedAt": "…"}
  ]
}
```

- `subscription.active` はサーバーが支払い(ORGATE-Server のサブスク)で確かめた結果。アプリは見せるだけで、申請の
  ボタンを押せるかもこれで決める(最後に決めるのはサーバー)。
- `limit` = 同時に持てるタグ(`pending` / `approved` / `suspended` の数)。既定 1。
- `reason` の名前: `promo_missing`(宣伝の投稿が無い / 消えた / 公開でない / タグを含まない)/ `tag_taken`(ほかの
  コミュニティが使っている)/ `subscription_inactive` / `theme_rejected` / `policy`。アプリは知らない名前なら理由を出さない。

### 申請 — `POST /api/v1/me/community-tags`

```json
{"tag": "rasqart",
 "theme": { RasqThemeSpec(source = communityTag、scope = hashtag) },
 "promo": {"sns": "misskey", "instance": "misskey.example", "postId": "9xyz…", "url": "https://misskey.example/notes/9xyz…"}}
→ 201 {"application": { 状態の 1 件、state = pending }}
→ 4xx {"error": {"code": "subscription_inactive | tag_taken | promo_missing | theme_rejected | limit_reached", "message": "…"}}
```

サーバーが確かめること:

1. **サブスクが有効**(無ければ `403 subscription_inactive`)。数の上限(`409 limit_reached`)。
2. **タグ**: 形(空白・記号なしの 64 字まで、小文字にして比べる)、ほかのコミュニティが `pending` / `approved` で持って
   いない(`409 tag_taken`)。
3. **宣伝の投稿**: `promo` の投稿を、その SNS の公開の API で引き直す(アプリの言うことを信じない)。
   - 作者が**申請した RASQ アカウントにつないだ SNS アカウント**(`sns_links`)であること。
   - 公開の投稿で、本文に `#<tag>` を含むこと。
   - 引けなければ `422 promo_missing`。通ったあとも定期的に引き直し、消えた / 非公開になったら `suspended`
     (`reason = promo_missing`)。
4. **テーマ**: `RasqThemeSpec` として読めること、`frames` は 6 枚まで・ID は登録済みの SVG(または同梱の 5 つ)。
   読めなければ `422 theme_rejected`。
5. 人の審査(タグ・テーマ・宣伝の投稿の中身)で `approved` / `rejected`。結果は通知(既存の Central の通知)で知らせる。

- サブスクが切れたら `suspended`(`reason = subscription_inactive`)にして配信を止め、戻れば `approved` に戻す。

### 取り下げ — `DELETE /api/v1/me/community-tags/{id}`

`204`。`withdrawn` にして配信を止める(タグは空く)。

## 4. SVG の登録(Atmos の広告主 / コミュハッシュタグ)

- テーマの枠・Atmos のアイコンとアニメーションの SVG は、`GET /api/v1/theme-svgs/{id}` の置き場(THEME_FRAMES.md)に
  登録してから ID で指す。登録の口はこの文書では決めない(管理画面)。登録のときに THEME_FRAMES.md の許可リストで消毒し、
  `<animate>` / `<animateTransform>` / `<set>` / `<script>` / `<style>` / `<foreignObject>` / `<image>` / `<use>` /
  `href` / `on*` / 外部参照を捨てる。上限(16 KiB・要素 400・数 8,000)を超えるものは登録させない。
