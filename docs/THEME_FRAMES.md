# テーマのデータとテーマフレームの置き場(D-562 / D-563、Central への提案)

rasq-central には手を入れていない。クライアントは同梱の SVG 5 枚と、テストの偽の置き場(`themeSvgRemoteProvider`)で動く。

## テーマのデータ(`RasqThemeSpec`、`lib/features/theme/icon_theme/rasq_theme_spec.dart`)

アイコンに埋め込むテーマ(D-561)・コミュハッシュタグのテーマ・RASQ Atmos のスレッド限定テーマ(第4回)が同じ JSON を使う。

```json
{
  "v": 1,
  "source": "iconEmbed | communityTag | atmos | bundled",
  "basic": {"bgMode": "grad", "grad": 2, "bg": [17,34,68], "text": [255,255,255], "accent": [0,204,255],
            "particle": 3, "amount": 10, "speed": 5, "hint": 5},
  "ext": {"shapes": [[["M",16,2],["L",19,12],["Z"]]], "paths": [[16,0,16,16,16,31]], "angle": 6, "anim": 1, "animSpeed": 3,
          "slots": [{"trig":0,"shape":0,"path":0,"rand":15,"arand":1,"ea":0,"eb":1,"mix":2,"sway":2,"spin":3}]},
  "frames": [{"svg": "sakura", "x": 0.88, "y": 0.1, "size": 0.28, "opacity": 0.45, "rotation": 18}],
  "scope": {"kind": "profile | thread | hashtag", "key": "<スレッドの根の投稿 / ハッシュタグ>"},
  "triggers": [{"kind": "hashtagBadge", "hashtag": "rasq", "svg": "star"},
               {"kind": "actionAnimation", "action": "reaction", "svg": "sparkle"}]
}
```

- `basic` / `ext` はアイコンの四隅に入るものと同じ範囲(色は 0〜255 だが、アイコンに書くときは 4 ビット × 3 に丸める)。
  `ext` は**アイコンの拡張領域(65 バイト)に詰められるものだけ**受ける(アプリは詰めて戻して同じか確かめる)。
  `ext` の代わりに `{"url": "<https:// を省いた配信 URL>"}`(プラグインの配信。アプリはまだ取りに行かない)。
- `frames` は 6 枚まで。位置は画面に対する割合、`size` は短い辺に対する割合。
- 知らない `v`(今は 1 より大きいもの)は読まない。知らない項目は読み飛ばす。

## テーマフレームの SVG の置き場(提案)

```
GET /api/v1/theme-svgs/{id}
  200  Content-Type: image/svg+xml   本文 = SVG(16 KiB まで)
  404  無い
```

- `id` は `^[a-z0-9][a-z0-9_.-]{0,63}$`。同梱の `star` / `sakura` / `wave` / `ring` / `sparkle` は予約(サーバーに同じ名前を置いても
  アプリは同梱を使う)。
- **サーバーでも登録のときに消毒する**(アプリの [SvgLite] と同じ許可リスト: `svg` `g` `path` `polyline` `polygon` `line` `rect`
  `circle` `ellipse` と形・描き方の属性だけ。`script` / `foreignObject` / `image` / `use` / `style` / `href` / `on*` / 外部参照は
  捨てる)。16 KiB・要素 400・数 8,000 を超えるものは登録させない。アプリは受け取ったあとにもう一度消毒し、上限を超えれば描かない。
- 変わらない ID の中身は変えない(`Cache-Control: public, max-age=31536000, immutable`)。中身を変えるときは新しい ID にする。
- 登録(コミュハッシュタグ / Atmos)と、ハッシュタグのテーマの配信・申請の口は docs/TAG_THEMES.md(D-566〜D-568)。
