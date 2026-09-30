# RASQ Plugin Contract(案内)

**正典は `orgate-question/rasq-sdk-sample` の [`CONTRACT.md`](http://tui.tail346b42.ts.net:8929/orgate-question/rasq-sdk-sample/-/blob/main/CONTRACT.md)** です(D-394。D-016 を置き換え)。
以前はこのファイルと SDK 側の 2 か所にあり、ずれていました(こちらにだけサイドロードの節 D-306 / D-308、あちらにだけスロット / ActionRef / スキーマの版)。いまは SDK 側に一本化しています。

- ホスト ⇄ プラグインの振る舞い(マニフェスト、`SnsSession`、TL ID、DM、操作語彙と権限、サイドロードの段と制限モード、エラーコード): `CONTRACT.md`
- スロット一覧と各スロットの契約: `schema/slots.json` / `docs/slots.md`(v0.19)
- 境界プロトコル(通信形式 `rasq.boundary/1`)とホスト関数: `PROTOCOL.md` / `docs/host-functions.md` / `schema/*.schema.json`
- マニフェストの JSON Schema: `schema/manifest.schema.json`(v0.5)

このリポジトリで契約を実装している場所: 制限モードの表 = `lib/features/plugins/sideload_trust.dart`(`sideloadCapabilityTable`)、同梱プラグインの出どころ = `assets/plugins/SOURCES.json`(`tool/build_bundled_plugins.sh`)。
契約を変えるときは SDK 側の `CONTRACT.md` を直し、ここは直さない。
