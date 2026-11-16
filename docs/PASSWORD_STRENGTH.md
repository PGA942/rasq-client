# 弱いパスワードの要件を返す形(ORGATE への提案、D-576)

## 今の形(2026-11-16 に読んで確かめた)

- 判定は **rasq-central ではなく ORGATE**(`orgate-questionproj` の `src/auth/password.rs` の `validate_password_for`、S-019)。
  呼ぶ所: `POST /auth/password`(付ける / 変える)・パスワードの再設定の確かめ(`src/auth/email.rs`、ハンドル無しで 1 回 →
  コードを確かめたあとハンドルつきでもう 1 回)。rasq-central にはパスワードの判定は無い。
- 規則: 長さ 8〜256 字(`400 "password must be 8-256 characters"`)のあと、
  1. 小文字にして `COMMON_PASSWORDS`(24 個)にある → `it is a commonly used password`
  2. 1 種類の字だけ → `it repeats a single character`
  3. ハンドル / 確認済みのメール / メールの `@` より前と同じ(小文字にして)→ `it is the same as your handle or email`
- 返すのは `400`、`{"error": {"code": "400", "message": "password is too weak: <理由>"}}`。**最初に当たった 1 つだけ**で、
  名前つきの理由(`code`)も無い(英語の文で見分けるしかない)。

## アプリがいましていること

- 端末で同じ規則を見て、**当たった要件を全部**チップで出す(`lib/features/onboarding/password_strength.dart`:
  新規登録の ①・設定 → アカウントの保護 → パスワード・パスワードの再設定)。表 `rasqCommonPasswords` はサーバーと同じ 24 個
  (変えるときは両方)。当たっているあいだは「次へ」/「再設定」を押せない(アカウントの保護の「設定」は押せる。サーバーが断る)。
- サーバーが断ったときは、文から要件を 1 つ読み「脆弱なパスワードです(同じ字の繰り返し)」と出す。下の形が来れば一覧を使う。

## 提案する形

```json
HTTP/1.1 400
{"error": {
  "code": "password_weak",
  "message": "<表示の言語の文: 脆弱なパスワードです>",
  "weaknesses": ["common", "repeated", "same_as_identity"]
}}
```

- `code` を名前つきの理由 `password_weak` に(ほかの口の `region_not_served` などと同じ、D-503。`message` は `Accept-Language` で訳す)。
- `weaknesses` は**当たったもの全部**を、上の規則の順で。値は `common` / `repeated` / `same_as_identity`(アプリの
  `PasswordWeakness.wire`)。知らない値はアプリが読み飛ばす(規則を足すときは名前を足し、アプリに文言を足す)。
- 再設定の 1 回目(ハンドルを見る前)は、ハンドルとの一致を入れない(今と同じ。メールの持ち主を探らせない)。
- 長さの誤り(8〜256 字)は今のまま別の答え(要件のチップには入れない)。
- アプリはもう両方の形を読める(`passwordWeaknessesFromServer`。`weaknesses` があればそれ、無ければ今の英語の文)ので、
  サーバーを先に変えても、アプリを先に出しても壊れない。
