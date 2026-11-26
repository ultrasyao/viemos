#!/usr/bin/env python3
"""Buat ikon Viemos (adaptive icon + legacy + ikon 512 untuk Play Store).
Butuh Pillow: pip install pillow. Jalankan dari root repo SETELAH folder android/ ada."""
import pathlib
from PIL import Image, ImageDraw, ImageFilter

BG = (10, 13, 14)
ORANGE = (255, 176, 102)
S = 1024


def logo(size, with_bg):
    """Cincin oranye bercahaya + huruf V."""
    im = Image.new('RGBA', (S, S), BG + (255,) if with_bg else (0, 0, 0, 0))
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    c = S // 2
    r = int(S * 0.30)
    gd.ellipse((c - r, c - r, c + r, c + r), outline=ORANGE + (200,), width=70)
    glow = glow.filter(ImageFilter.GaussianBlur(38))
    im = Image.alpha_composite(im, glow)
    d = ImageDraw.Draw(im)
    d.ellipse((c - r, c - r, c + r, c + r), outline=ORANGE + (255,), width=34)
    # huruf V (poligon tebal)
    w = int(S * 0.20)
    top = c - int(S * 0.13)
    bot = c + int(S * 0.14)
    th = int(S * 0.075)
    d.polygon([(c - w, top), (c - w + th * 1.5, top), (c, bot - th * 1.6),
               (c + w - th * 1.5, top), (c + w, top), (c + th * 0.55, bot),
               (c - th * 0.55, bot)], fill=ORANGE + (255,))
    return im.resize((size, size), Image.LANCZOS)


res = pathlib.Path('android/app/src/main/res')
legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
fore = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}

for k, px in legacy.items():
    d = res / f'mipmap-{k}'
    d.mkdir(parents=True, exist_ok=True)
    # ikon lama: kotak bersudut membulat
    im = logo(px, True)
    mask = Image.new('L', (px, px), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, px - 1, px - 1), radius=px // 5, fill=255)
    out = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    out.save(d / 'ic_launcher.png')

for k, px in fore.items():
    d = res / f'mipmap-{k}'
    d.mkdir(parents=True, exist_ok=True)
    # foreground adaptive: logo di zona aman (66/108 bagian tengah)
    big = logo(int(px * 66 / 108 * 1.45), False)
    canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    o = (px - big.width) // 2
    canvas.paste(big, (o, o), big)
    canvas.save(d / 'ic_launcher_foreground.png')

(res / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
(res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n')
(res / 'values').mkdir(parents=True, exist_ok=True)
(res / 'values/ic_launcher_background.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="ic_launcher_background">#0A0D0E</color>\n</resources>\n')

pathlib.Path('store').mkdir(exist_ok=True)
logo(512, True).convert('RGB').save('store/icon-512.png')
print('icons ok')
