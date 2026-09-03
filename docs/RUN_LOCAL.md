# ローカルで動かす(クライアント + orgate-server)

第一期のクライアントを、手元の `orgate-server` に繋いだ状態で起動する手順。
検証時に踏んだ落とし穴も併記する。

## 1. サーバーを立てる

```sh
cd ../orgate-server
cp .env.example .env
./scripts/gen-store-key.sh >> .env                 # 署名鍵を固定する
echo "ORGATE_ADMIN_TOKEN=$(openssl rand -hex 24)" >> .env
docker compose up --build
```

掲載物を投入して一巡させる(45 項目の契約テストを兼ねる):

```sh
ORGATE_ADMIN_TOKEN=<.env の値> ./scripts/smoke.sh http://127.0.0.1:8080
```

## 2. wasm プラグインをビルドする

クライアントは `assets/plugins/*.wasm` を同梱している。SDK 側を触ったら
ビルドして置き直す:

```sh
cd ../rasq-sdk-sample/rust
cargo build --release --target wasm32-unknown-unknown -p misskey-wasm-sample -p mastodon-wasm
cp target/wasm32-unknown-unknown/release/misskey_wasm_sample.wasm ../../rasq-client/assets/plugins/
cp target/wasm32-unknown-unknown/release/mastodon_wasm.wasm       ../../rasq-client/assets/plugins/
```

## 3. クライアントを起動する

接続先はビルド時に焼き込む(起動後に設定 →「RASQ サーバー」からも変えられる):

```sh
flutter run -d linux --dart-define=ORGATE_BASE_URL=http://127.0.0.1:8080
```

署名済みストアだけを許可するビルドにするなら、公開鍵も焼き込む
(`GET /api/v1/store-key` の `publicKey`):

```sh
flutter run -d linux \
  --dart-define=ORGATE_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=ORGATE_STORE_PUBLIC_KEY=<base64>
```

`ORGATE_BASE_URL` を渡さなければ、ストアはモック、RASQ アカウントは最初の
ログインアカウントからの流用に縮退する(サーバー無しでも動く)。

## 動いていることの確かめ方

- 起動ログに `orgate: using http://127.0.0.1:8080` が出る。
- **端末登録が実際に走ったか**はサーバー側で見るのが確実:

  ```sh
  psql "$DATABASE_URL" -c "SELECT a.handle, a.created_at, t.device_id
                             FROM accounts a JOIN auth_tokens t ON t.account_id = a.id
                         ORDER BY a.created_at DESC LIMIT 5;"
  ```

  RASQ アカウントは**シェルが描画された時点**で作られる(`rasqAccountProvider`
  を見ている最初の画面)。ログイン画面だけを見て閉じた場合は作られない。
- ログイン → Mastodon →(インスタンス名を入れて)🔍 で、実インスタンスの
  名称・バージョン・管理人・アイコンが出れば、
  **UI → wasm プラグイン → `net.fetch` → 実 API** の一本道が通っている。

## ヘッドレス環境(CI / コンテナ)での注意

デスクトップ版をコンテナで動かす場合に踏んだもの:

- **必要なパッケージ**: `clang cmake ninja-build pkg-config libgtk-3-dev
  liblzma-dev libsecret-1-dev`。`libsecret` が無いと
  `flutter_secure_storage_linux` の CMake 設定で落ちる。
- **失敗した configure のキャッシュが残る**と、次のビルドが
  `CMAKE_INSTALL_PREFIX=/usr/local` のままになり、バンドルが
  `build/linux/x64/debug/bundle` ではなく `/usr/local` へ入る。
  一度失敗したら `rm -rf build/linux` してからやり直す。
- **キーリング**: `flutter_secure_storage` は Secret Service を使う。
  ヘッドレスだと「Choose password for new keyring」のダイアログが出て
  **アプリが起動時にブロックする**。`dbus-launch` + `gnome-keyring-daemon
  --unlock` を先に立てるか、ダイアログを閉じる必要がある。
- **Web ビルドは通らない**: `rasq_wasm_runtime` が `dart:ffi`(wasmi)を使う
  ため。Web 版は第一期の後回し対象(PHASE1_PLAN §0.3)。
