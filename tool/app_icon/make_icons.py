#!/usr/bin/env python3
"""アプリアイコンの生成 (D-325)。

元絵はブランドのマーク(`packages/rasq_design/assets/brand/rasq_icon.png`、透過 PNG)。ユーザーが渡した
アイコン画像(`source.jpg`: 白地の中央にマークが 6 割)と同じ構図で、各プラットフォームのランチャー用に書き出す:

- iOS   `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`(Contents.json の一覧どおり、白地・不透明)
- Android 従来の `mipmap-*/ic_launcher.png`(白地)+ アダプティブ(`mipmap-anydpi-v26/ic_launcher.xml`:
          背景 = 白、前景 = `ic_launcher_foreground.png` にマークを 108dp 中の 52% で。円マスクで欠けない大きさ)
- macOS `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`(Big Sur 風: 1 割の余白 + 角丸の白い板)
- Web   `web/icons/Icon-*.png`(maskable は円の安全域に収まるようマークを 50% に)、`web/favicon.png`
- Windows `windows/runner/resources/app_icon.ico`(16〜256)

使い方: `python3 tool/app_icon/make_icons.py`(Pillow が要る)。
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MARK = ROOT / 'packages/rasq_design/assets/brand/rasq_icon.png'
WHITE = (255, 255, 255, 255)


def mark_rgba() -> Image.Image:
    im = Image.open(MARK).convert('RGBA')
    # 透明でない部分の外接矩形で切り出す(余白は構図側で付ける)。
    bbox = im.split()[3].getbbox()
    return im.crop(bbox)


def compose(size: int, mark_ratio: float, *, background: tuple[int, int, int, int] | None = WHITE, mark: Image.Image | None = None) -> Image.Image:
    """[size] 角のキャンバスに、マークを最長辺が [mark_ratio] になる大きさで中央に置く。"""
    mark = mark or mark_rgba()
    canvas = Image.new('RGBA', (size, size), background or (0, 0, 0, 0))
    span = max(1, round(size * mark_ratio))
    scale = span / max(mark.size)
    w, h = max(1, round(mark.width * scale)), max(1, round(mark.height * scale))
    # 大きく描いてから縮める(縁のギザギザを減らす)。
    big = mark.resize((w * 2, h * 2), Image.LANCZOS).resize((w, h), Image.LANCZOS)
    canvas.alpha_composite(big, ((size - w) // 2, (size - h) // 2))
    return canvas


def rounded_plate(size: int, *, margin: float, radius: float, mark_ratio: float) -> Image.Image:
    """macOS 風: 透明な余白 + 角丸の白い板 + マーク。[radius] は板の辺に対する割合。"""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    m = round(size * margin)
    plate = size - m * 2
    # マスクは 4 倍で描いて縮める(角のアンチエイリアス)。
    mask = Image.new('L', (plate * 4, plate * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, plate * 4 - 1, plate * 4 - 1), radius=round(plate * 4 * radius), fill=255)
    mask = mask.resize((plate, plate), Image.LANCZOS)
    body = compose(plate, mark_ratio)
    canvas.paste(body, (m, m), mask)
    return canvas


def save_png(im: Image.Image, path: Path, *, size: int, opaque: bool) -> None:
    out = im.resize((size, size), Image.LANCZOS) if im.size != (size, size) else im
    if opaque:
        flat = Image.new('RGB', out.size, (255, 255, 255))
        flat.paste(out, mask=out.split()[3])
        out = flat
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path, format='PNG', optimize=True)


def ios(master: Image.Image) -> None:
    d = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    contents = json.loads((d / 'Contents.json').read_text())
    done: set[str] = set()
    for img in contents['images']:
        name = img['filename']
        if name in done:
            continue
        done.add(name)
        pt = float(img['size'].split('x')[0])
        px = round(pt * int(img['scale'].rstrip('x')))
        save_png(master, d / name, size=px, opaque=True)


def android(master: Image.Image, mark: Image.Image) -> None:
    res = ROOT / 'android/app/src/main/res'
    dpi = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for name, k in dpi.items():
        save_png(master, res / f'mipmap-{name}/ic_launcher.png', size=round(48 * k), opaque=True)
        fg = compose(round(108 * k), 0.52, background=None, mark=mark)
        save_png(fg, res / f'mipmap-{name}/ic_launcher_foreground.png', size=round(108 * k), opaque=False)
    (res / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
    (res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )
    (res / 'values/ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n'
    )


def macos() -> None:
    d = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    plate = rounded_plate(1024, margin=0.1, radius=0.225, mark_ratio=0.6)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_png(plate, d / f'app_icon_{size}.png', size=size, opaque=False)


def web(master: Image.Image, mark: Image.Image) -> None:
    d = ROOT / 'web'
    for size in (192, 512):
        save_png(master, d / f'icons/Icon-{size}.png', size=size, opaque=True)
        save_png(compose(size, 0.5, mark=mark), d / f'icons/Icon-maskable-{size}.png', size=size, opaque=True)
    save_png(master, d / 'favicon.png', size=32, opaque=True)


def windows(master: Image.Image) -> None:
    path = ROOT / 'windows/runner/resources/app_icon.ico'
    flat = Image.new('RGB', master.size, (255, 255, 255))
    flat.paste(master, mask=master.split()[3])
    flat.resize((256, 256), Image.LANCZOS).save(path, format='ICO', sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])


def main() -> None:
    mark = mark_rgba()
    master = compose(1024, 0.6, mark=mark)
    save_png(master, Path(__file__).with_name('app_icon_1024.png'), size=1024, opaque=True)
    ios(master)
    android(master, mark)
    macos()
    web(master, mark)
    windows(master)
    print('ok')


if __name__ == '__main__':
    main()
