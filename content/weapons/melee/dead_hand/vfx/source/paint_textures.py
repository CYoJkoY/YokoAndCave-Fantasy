from pathlib import Path
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


OUT = Path(__file__).resolve().parents[1] / 'textures'
OUT.mkdir(exist_ok=True)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def colored(alpha, heat):
    palette = np.array([[28, 4, 67], [89, 21, 159], [157, 59, 225], [211, 130, 255], [237, 221, 255]], dtype=float)
    h = np.clip(heat * 4, 0, 3.999)
    i = h.astype(int)
    rgb = palette[i] * (1 - (h - i)[..., None]) + palette[i + 1] * (h - i)[..., None]
    return Image.fromarray(np.uint8(np.dstack((rgb, np.clip(alpha, 0, 1) * 255))))


def save(image, name):
    pixels = np.array(image)
    pixels[pixels[:, :, 3] == 0, :3] = 0
    Image.fromarray(pixels).save(OUT / name, 'WEBP', lossless=True, exact=True, method=6)


size = 768
y, x = np.mgrid[-1:1:complex(size), -1:1:complex(size)]
r = np.sqrt(x * x + y * y)
a = np.arctan2(y, x)
curl = np.sin(a * 11 + r * 21) * 0.55 + np.sin(a * 23 - r * 17) * 0.25 + np.sin(a * 39 + r * 37) * 0.20
scallop = 0.035 * np.sin(a * 13 + 0.7) + 0.02 * np.sin(a * 29)
outer = 0.91 + scallop
inner = 0.52 + 0.07 * np.sin(a * 9 + r * 5) + 0.045 * np.sin(a * 18)
band = smooth(inner - 0.06, inner + 0.08, r) * (1 - smooth(outer - 0.04, outer + 0.012, r))
edge = np.exp(-((r - (0.81 + scallop * 0.7)) / 0.028) ** 2)
filaments = np.exp(-((r - (0.68 + 0.04 * np.sin(a * 15 + r * 8))) / 0.026) ** 2)
heat = 0.27 + 0.25 * smooth(inner, outer, r) + edge * 0.40 + filaments * 0.19 + curl * 0.07
alpha = band * (0.68 + 0.25 * smooth(-0.6, 0.6, curl))
# Broad curved tongues connect the crescent to the wrist-side shadow.
for center, length, width in [(-1.3, .37, .14), (-.8, .31, .12), (-.25, .42, .15), (.33, .38, .14), (.9, .33, .12), (1.4, .30, .13)]:
    spiral = center + (0.72 - r) * 1.5
    tongue = np.exp(-((a - spiral) / (width * np.maximum(0.08, (r - length) / (0.78 - length)))) ** 2)
    tongue *= smooth(length, length + .09, r) * (1 - smooth(.73, .82, r))
    alpha = np.maximum(alpha, tongue * .82)
    heat = np.maximum(heat, tongue * .55)
arc = colored(alpha, heat)
glow = colored(np.array(arc.getchannel('A').filter(ImageFilter.GaussianBlur(12))) / 255 * .32, np.full_like(r, .32))
glow.alpha_composite(arc)
save(glow.resize((512, 512), Image.Resampling.LANCZOS), 'dead_hand_sweep.webp')


size = 768
seal = Image.new('RGBA', (size, size))
d = ImageDraw.Draw(seal)
cx = cy = size / 2


def polar(radius, angle):
    return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius


def ring_sector(radius, width, angle, span, color):
    pts = [polar(radius + width / 2, t) for t in np.linspace(angle - span / 2, angle + span / 2, 28)]
    pts += [polar(radius - width / 2, t) for t in np.linspace(angle + span / 2, angle - span / 2, 28)]
    d.polygon(pts, fill=color)


for i in range(12):
    angle = i * math.tau / 12
    ring_sector(302, 14, angle, .40, (113, 37, 185, 210))
    ring_sector(302, 4, angle, .39, (222, 171, 255, 235))
    ring_sector(226, 21, angle + .12, .31, (83, 22, 142, 180))
    ring_sector(222, 6, angle + .12, .28, (181, 98, 244, 220))
    # Each glyph is a filled, tapered shard with a dark inset and a luminous spine.
    def glyph(points, color):
        pts = []
        for px, py in points:
            rad = 263 + px
            pts.append((cx + math.cos(angle) * rad - math.sin(angle) * py,
                        cy + math.sin(angle) * rad + math.cos(angle) * py))
        d.polygon(pts, fill=color)
    glyph([(-17, -12), (3, -16), (20, 2), (4, 18), (-7, 12), (7, 1), (-2, -5), (-16, 7)], (179, 94, 240, 235))
    glyph([(-11, -10), (1, -11), (13, 1), (5, 10), (7, 0), (-1, -6)], (235, 193, 255, 245))
    if i % 3 == 0:
        d.polygon([polar(323, angle - .03), polar(349, angle), polar(323, angle + .03), polar(311, angle)], fill=(199, 127, 249, 220))

for i in range(5):
    angle = -math.pi / 2 + i * math.tau / 5
    ring_sector(148, 26, angle + .26, .85, (95, 25, 159, 180))
    pts = [polar(102, angle - .22), polar(171, angle - .04), polar(196, angle + .09), polar(142, angle + .12), polar(89, angle + .42)]
    d.polygon(pts, fill=(158, 65, 215, 220))
    d.polygon([polar(116, angle - .09), polar(171, angle + .01), polar(142, angle + .08), polar(108, angle + .23)], fill=(216, 159, 253, 240))
d.polygon([(384, 317), (433, 362), (420, 413), (384, 446), (349, 413), (335, 362)], fill=(94, 25, 156, 230))
d.polygon([(384, 337), (413, 367), (402, 398), (384, 425), (365, 398), (355, 367)], fill=(192, 113, 243, 240))
d.polygon([(384, 352), (394, 378), (384, 409), (375, 378)], fill=(241, 212, 255, 255))
blur = seal.filter(ImageFilter.GaussianBlur(13))
blur.alpha_composite(seal)
save(blur.resize((384, 384), Image.Resampling.LANCZOS), 'dead_hand_sigil.webp')


size = 192
y, x = np.mgrid[0:1:complex(size), -1:1:complex(size)]
axis = .23 * np.sin(y * 5.5) - .14
width = .34 * np.sin(np.clip(y * 1.04, 0, 1) * math.pi) ** .85
body = np.exp(-((x - axis) / np.maximum(.012, width)) ** 2 * 2)
body *= smooth(.025, .16, y) * (1 - smooth(.83, 1.0, y))
core = np.exp(-((x - axis - .03) / np.maximum(.008, width * .38)) ** 2 * 2) * smooth(.25, .6, y)
ember = colored(body, .38 + body * .23 + core * .35)
save(ember.resize((64, 64), Image.Resampling.LANCZOS), 'dead_hand_ember.webp')

source = Image.open(OUT.parents[1] / 'dead_hand_layer3.webp').convert('RGBA').resize((512, 512), Image.Resampling.LANCZOS)
pixels = np.array(source, dtype=float) / 255.0
luminance = pixels[:, :, :3] @ np.array([0.25, 0.55, 0.20])
fuel = pixels[:, :, 3] * (0.18 + 0.82 * smooth(0.025, 0.40, luminance))
fuel_image = Image.fromarray(np.uint8(fuel * 255))
body = np.array(fuel_image.filter(ImageFilter.GaussianBlur(5.5))) / 255.0
veil = np.array(fuel_image.filter(ImageFilter.GaussianBlur(13))) / 255.0
core = np.array(fuel_image.filter(ImageFilter.GaussianBlur(2.5))) / 255.0
y, x = np.mgrid[0:1:512j, 0:1:512j]
heat = np.clip(0.32 + body * 0.45 + core * 0.25 + 0.05 * np.sin(x * 11 - y * 7), 0, 1)
flame = colored(np.clip(body * 0.95 + veil * 0.30, 0, 0.92), heat)
save(flame.resize((256, 256), Image.Resampling.LANCZOS), 'dead_hand_flame.webp')

print('Painted 4 transparent dead hand textures:', OUT)
