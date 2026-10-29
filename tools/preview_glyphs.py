#!/usr/bin/env python3
"""Renders a large, readable preview of selected charset glyphs with the
sample game colors (white text, brown accent, gray main) for inspection."""

import re
import sys
from PIL import Image, ImageDraw

VIC2 = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x68, 0x37, 0x2B), (0x70, 0xA4, 0xB2),
    (0x6F, 0x3D, 0x86), (0x58, 0x8D, 0x43), (0x35, 0x28, 0x79), (0xB8, 0xC7, 0x0F),
    (0x6F, 0x4F, 0x25), (0x43, 0x39, 0x00), (0x9A, 0x67, 0x59), (0x44, 0x44, 0x44),
    (0x6C, 0x6C, 0x6C), (0x9A, 0xD2, 0x84), (0x6C, 0x5E, 0xB5), (0x95, 0x95, 0x95),
]

src = open("ms/1_charset.ms").read()
ROM = re.findall(r'"([0-3]{32})"', src)
GLS = re.findall(r"^\s+(\w+) = (\d+)$", src[src.index("GL = object"):], re.M)
GL = {k: int(v) for k, v in GLS}

SCALE = 12  # px per fat pixel


def glyph_img(idx, bg, accent, main, white=(0xFF, 0xFF, 0xFF)):
    img = Image.new("RGB", (4 * SCALE, 8 * SCALE), VIC2[bg])
    d = ImageDraw.Draw(img)
    data = ROM[idx]
    for r in range(8):
        for c in range(4):
            k = int(data[r * 4 + c])
            col = {0: VIC2[bg], 1: white, 2: VIC2[accent], 3: VIC2[main]}[k]
            d.rectangle([c * SCALE, r * SCALE, c * SCALE + SCALE - 1, r * SCALE + SCALE - 1], fill=col)
    return img


def render_group(title, names, bg, accent, main, cols=8):
    cw, ch = 4 * SCALE + 8, 8 * SCALE + 18
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGB", (cols * cw, rows * ch), (40, 40, 40))
    d = ImageDraw.Draw(img)
    for i, n in enumerate(names):
        idx = GL.get(n)
        if idx is None:
            idx = ord(n) if len(n) == 1 else 0
        gi = glyph_img(idx, bg, accent, main)
        x = (i % cols) * cw
        y = (i // cols) * ch
        img.paste(gi, (x + 4, y + 14))
        d.text((x + 4, y + 2), n, fill=(255, 255, 0))
    return img


groups = [
    ("FONT (white on blue)", [chr(c) for c in range(65, 91)] + ["0", "1", "2", "3", "4", "5", "6"], 6, 1, 1),
    ("TILES (grass green / dirt brown)", ["grass", "dirt", "stone", "bedrock", "sand", "gravel", "wood", "leaves"], 0, 13, 5),
    ("ORES (stone gray + ore accent)", ["coal", "iron", "gold", "diamond", "planks", "torch", "craft", "ladder"], 0, 1, 12),
    ("WATER (light blue on blue)", ["water0", "water1", "water2", "water3", "lava0", "lava1", "lava2", "lava3"], 6, 14, 3),
    ("PLAYER (skin lt.red, suit blue)", ["player_r0", "player_r1", "player_r2", "player_r3", "player_l0", "player_l1", "player_jump", "player_climb"], 0, 10, 6),
    ("MOBS + UI", ["slime0", "slime1", "slime2", "heartfull", "heartempty", "sun", "moon", "cloud"], 0, 13, 5),
    ("ITEMS (wood brown / iron white)", ["i_stick", "i_coal", "i_iron", "i_gold", "i_diamond", "i_pick_wood", "i_pick_iron", "i_sword_iron"], 0, 8, 12),
]
imgs = [render_group(t, n, b, a, m) for t, n, b, a, m in groups]
W = max(i.width for i in imgs)
H = sum(i.height + 26 for i in imgs)
out = Image.new("RGB", (W, H), (0, 0, 0))
d = ImageDraw.Draw(out)
y = 0
for (t, _, _, _, _), im in zip(groups, imgs):
    d.text((4, y + 4), t, fill=(255, 255, 0))
    out.paste(im, (0, y + 22))
    y += im.height + 26
out.save("docs/charset_grouped.png")
print("wrote docs/charset_grouped.png", out.size)
