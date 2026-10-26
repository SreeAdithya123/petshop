"""Generates the PETSTA brand artwork (app icon, splash logo, store graphics).

The paw geometry is the same 64x64 mark the web app draws in
src/components/layout/PawMark.jsx; the gradient is AppColors.heroGradient
from lib/theme/app_theme.dart (indigo -> violet -> pink, top-left to
bottom-right).

Requires Pillow. Run from anywhere:

    python mobile/assets/generate_brand_assets.py

Outputs (all committed, so this only needs re-running when the artwork
changes; then re-run `dart run flutter_launcher_icons` and
`dart run flutter_native_splash:create` from the mobile/ folder):

    assets/icon/icon.png                 1024 opaque master icon (iOS + legacy)
    assets/icon/icon_legacy.png          1024 rounded icon for Android < 8
    assets/icon/icon_background.png      1024 adaptive icon background
    assets/icon/icon_foreground.png      1024 adaptive icon foreground
    assets/icon/icon_monochrome.png      1024 Android 13 themed icon layer
    assets/splash/splash_logo.png        512  splash mark (iOS / Android < 12)
    assets/splash/splash_android12.png   1152 splash mark (Android 12+)
    assets/store/play_icon_512.png       512  Google Play hi-res icon
    assets/store/feature_graphic_1024x500.png  Google Play feature graphic
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

PRIMARY = (0x4F, 0x46, 0xE5)
SECONDARY = (0x7C, 0x3A, 0xED)
TERTIARY = (0xEC, 0x48, 0x99)
SHADOW = (0x1E, 0x1B, 0x4B)
WHITE = (255, 255, 255)

# (cx, cy, rx, ry, rotation in degrees) in the 64-unit PawMark space.
PAW = [
    (32, 40, 13, 11, 0),
    (16, 24, 6, 7.5, 0),
    (48, 24, 6, 7.5, 0),
    (22, 14, 5, 6.5, -18),
    (42, 14, 5, 6.5, 18),
]
# Centre of the paw's bounding box in PawMark space.
PAW_CENTER = (32.0, 29.25)
SUPERSAMPLE = 4


def out(*parts):
    path = os.path.join(HERE, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


_GRADIENT_CACHE = {}


def gradient(width, height=None):
    """Three-stop gradient from the top-left to the bottom-right corner,
    identical to AppColors.heroGradient (a copy is returned, so callers may
    paint on it)."""
    height = height or width
    key = (width, height)
    if key not in _GRADIENT_CACHE:
        img = Image.new('RGB', (width, height))
        px = img.load()
        denom = float(width * width + height * height)
        for y in range(height):
            for x in range(width):
                t = (x * width + y * height) / denom
                if t < 0.5:
                    px[x, y] = lerp(PRIMARY, SECONDARY, t / 0.5)
                else:
                    px[x, y] = lerp(SECONDARY, TERTIARY, (t - 0.5) / 0.5)
        _GRADIENT_CACHE[key] = img
    return _GRADIENT_CACHE[key].copy()


def paw_mask(size, scale, cx, cy):
    """Anti-aliased 'L' mask of the paw, `scale` px per mark unit, centred on
    (cx, cy) in a size x size canvas."""
    big = size * SUPERSAMPLE
    mask = Image.new('L', (big, big), 0)
    draw = ImageDraw.Draw(mask)
    for ex, ey, rx, ry, rot in PAW:
        theta = math.radians(rot)
        cos_t, sin_t = math.cos(theta), math.sin(theta)
        pts = []
        for i in range(360):
            a = math.radians(i)
            lx, ly = rx * math.cos(a), ry * math.sin(a)
            ux = ex + lx * cos_t - ly * sin_t
            uy = ey + lx * sin_t + ly * cos_t
            pts.append((
                (cx + (ux - PAW_CENTER[0]) * scale) * SUPERSAMPLE,
                (cy + (uy - PAW_CENTER[1]) * scale) * SUPERSAMPLE,
            ))
        draw.polygon(pts, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def with_shadow(base, mask, blur, dy, opacity):
    """Pastes a soft drop shadow of `mask` onto base (RGB or RGBA)."""
    size = base.size[0]
    shadow = Image.new('L', base.size, 0)
    shadow.paste(mask, (0, dy))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    shadow = shadow.point(lambda v: int(v * opacity))
    layer = Image.new('RGB', (size, size), SHADOW)
    base.paste(layer, (0, 0), shadow)


def glow(base):
    """Soft top-left highlight so the gradient doesn't look flat."""
    size = base.size[0]
    m = Image.new('L', base.size, 0)
    d = ImageDraw.Draw(m)
    d.ellipse((-size * 0.25, -size * 0.45, size * 0.75, size * 0.45), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(size * 0.12)).point(lambda v: int(v * 0.16))
    base.paste(Image.new('RGB', base.size, WHITE), (0, 0), m)


def master_icon():
    size = 1024
    img = gradient(size)
    glow(img)
    # 13.5 px per unit: the paw is ~58% of the icon width.
    mask = paw_mask(size, 13.5, size / 2, size / 2 + 6)
    with_shadow(img, mask, blur=18, dy=14, opacity=0.34)
    img.paste(Image.new('RGB', img.size, WHITE), (0, 0), mask)
    return img


def rounded(img, radius_ratio=0.22):
    size = img.size[0]
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=255)
    out_img = img.convert('RGBA')
    out_img.putalpha(m)
    return out_img


def transparent_paw(size, scale, color=WHITE, shadow=False):
    """Paw on a transparent canvas (adaptive foreground / splash / mono)."""
    mask = paw_mask(size, scale, size / 2, size / 2)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    if shadow:
        sh = Image.new('L', (size, size), 0)
        sh.paste(mask, (0, int(size * 0.012)))
        sh = sh.filter(ImageFilter.GaussianBlur(size * 0.016))
        sh = sh.point(lambda v: int(v * 0.34))
        layer = Image.new('RGBA', (size, size), SHADOW + (255,))
        layer.putalpha(sh)
        canvas.alpha_composite(layer)
    paw = Image.new('RGBA', (size, size), color + (255,))
    paw.putalpha(mask)
    canvas.alpha_composite(paw)
    return canvas


def load_font(names, size):
    for name in names:
        for folder in (r'C:\Windows\Fonts', '/usr/share/fonts/truetype/dejavu',
                       '/Library/Fonts', '/System/Library/Fonts/Supplemental'):
            path = os.path.join(folder, name)
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def feature_graphic():
    w, h = 1024, 500
    big = gradient(w, h)
    glow_layer = Image.new('L', (w, h), 0)
    ImageDraw.Draw(glow_layer).ellipse((-220, -260, 560, 300), fill=255)
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(70)).point(lambda v: int(v * 0.16))
    big.paste(Image.new('RGB', (w, h), WHITE), (0, 0), glow_layer)

    mark = transparent_paw(512, 5.6, shadow=True)
    big.paste(mark, (40, (h - 512) // 2 - 6), mark)

    draw = ImageDraw.Draw(big)
    bold = ['segoeuib.ttf', 'arialbd.ttf', 'DejaVuSans-Bold.ttf', 'Arial Bold.ttf']
    regular = ['segoeui.ttf', 'arial.ttf', 'DejaVuSans.ttf', 'Arial.ttf']
    title = load_font(bold, 104)
    tag = load_font(regular, 36)
    draw.text((470, 150), 'PETSTA', font=title, fill=WHITE)
    draw.text((474, 280), 'Pets, supplies and vet care', font=tag, fill=(255, 255, 255))
    draw.text((474, 328), 'from trusted local shops.', font=tag, fill=(255, 255, 255))
    return big


def main():
    icon = master_icon()
    icon.save(out('icon', 'icon.png'), optimize=True)
    rounded(icon).save(out('icon', 'icon_legacy.png'), optimize=True)

    gradient(1024).save(out('icon', 'icon_background.png'), optimize=True)
    # The adaptive icon is masked to a ~66% safe circle: keep the paw inside it.
    transparent_paw(1024, 10.8, shadow=True).save(
        out('icon', 'icon_foreground.png'), optimize=True)
    transparent_paw(1024, 10.8).save(out('icon', 'icon_monochrome.png'), optimize=True)

    transparent_paw(512, 8.0).save(out('splash', 'splash_logo.png'), optimize=True)
    # Android 12 clips the splash icon to a circle 2/3 of the image width.
    transparent_paw(1152, 12.0).save(out('splash', 'splash_android12.png'), optimize=True)

    icon.resize((512, 512), Image.LANCZOS).save(out('store', 'play_icon_512.png'), optimize=True)
    feature_graphic().save(out('store', 'feature_graphic_1024x500.png'), optimize=True)


if __name__ == '__main__':
    main()
