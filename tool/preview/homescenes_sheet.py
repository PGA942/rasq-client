"""ホームページのシーン (D-466) の見本の一覧(コンタクトシート)を作る。

使い方: python3 tool/preview/homescenes_sheet.py <scenes.json のあるディレクトリ> <出力ディレクトリ> [フォント .ttf]
シーン / 端末ごとに 1 枚の PNG(<id>_<device>.png)。段ごとにコマを縮めて並べ、下に段の番号・表示時間・入り方・説明を書く。
コマの上には台本の印を重ねる: タッチ(赤い輪)、RAi(青い丸 = 位置と大きさ、矢印 = 移動元 / 指す先)、
入り方の region(緑の枠)、ライブ映像の場所(橙の枠)。コマは .webp(無ければ同じ名前の .png)を読む。Pillow が要る。
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
font_path = sys.argv[3] if len(sys.argv) > 3 else None
os.makedirs(dst, exist_ok=True)
manifest = json.load(open(os.path.join(src, 'scenes.json'), encoding='utf-8'))
font = ImageFont.truetype(font_path, 15) if font_path else ImageFont.load_default()
small = ImageFont.truetype(font_path, 13) if font_path else ImageFont.load_default()


def load(frame):
    path = os.path.join(src, frame)
    if not os.path.exists(path):
        path = path[: -len('.webp')] + '.png'
    return Image.open(path).convert('RGB')


def wrap(draw, text, width, f):
    lines, cur = [], ''
    for ch in text:
        if draw.textlength(cur + ch, font=f) > width:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


for scene in manifest['scenes']:
    steps = scene['steps']
    dev = manifest['devices'][scene['device']]
    aspect = dev['h'] / dev['w']
    tw = 300 if dev['w'] > dev['h'] else 220
    th = int(tw * aspect)
    cols = 6 if dev['w'] > dev['h'] else 8
    cap_h = 92
    rows = (len(steps) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * (tw + 12) + 12, 40 + rows * (th + cap_h + 12)), 'white')
    d = ImageDraw.Draw(sheet)
    total = sum(s['hold'] for s in steps)
    d.text((12, 10), f"{scene['id']} / {scene['device']} — {len(steps)} 段、{total / 1000:.1f} 秒", fill='black', font=font)
    for i, s in enumerate(steps):
        x0 = 12 + (i % cols) * (tw + 12)
        y0 = 40 + (i // cols) * (th + cap_h + 12)
        img = load(s['frame']).resize((tw, th))
        o = ImageDraw.Draw(img)

        def px(p):
            return (p['x'] * tw, p['y'] * th)

        e = s.get('enter', {})
        if 'region' in e and e.get('type') != 'none':
            l, t, r, b = e['region']
            o.rectangle([l * tw, t * th, r * tw - 1, b * th - 1], outline=(40, 170, 80), width=2)
        v = s.get('video')
        if v:
            l, t, r, b = v['rect']
            o.rectangle([l * tw, t * th, r * tw, b * th], outline=(245, 130, 0), width=3)
            for (l, t, r, b) in v.get('overlays', []):
                o.rectangle([l * tw, t * th, r * tw, b * th], outline=(245, 130, 0), width=1)
        rai = s.get('rai')
        if rai and rai.get('visible'):
            cx, cy = px(rai)
            rad = rai['scale'] * th / 2
            o.ellipse([cx - rad / 2, cy - rad, cx + rad / 2, cy + rad], outline=(30, 90, 230), width=3)
            if 'from' in rai:
                o.line([px(rai['from']), (cx, cy)], fill=(30, 90, 230), width=2)
            if 'pointTo' in rai:
                o.line([(cx, cy), px(rai['pointTo'])], fill=(230, 30, 160), width=2)
        if 'tap' in s:
            tx, ty = px(s['tap'])
            o.ellipse([tx - 9, ty - 9, tx + 9, ty + 9], outline=(220, 0, 0), width=3)
        sheet.paste(img, (x0, y0))
        d.rectangle([x0 - 1, y0 - 1, x0 + tw, y0 + th], outline=(200, 200, 200))
        pose = (rai or {}).get('pose', '-')
        head = f"{i:02d} {os.path.basename(s['frame'])} {s['hold']}ms {e.get('type', 'none')}{('/' + str(e['ms'])) if e.get('ms') else ''} RAi:{pose}"
        d.text((x0, y0 + th + 4), head, fill='black', font=small)
        for k, line in enumerate(wrap(d, s.get('caption', ''), tw, small)[:4]):
            d.text((x0, y0 + th + 22 + k * 17), line, fill=(60, 60, 60), font=small)
    out = os.path.join(dst, f"{scene['id']}_{scene['device']}.png")
    sheet.save(out)
    print(out)
