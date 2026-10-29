#!/usr/bin/env python3
"""
C64 MINE DEMAKE - charset generator.

Single source of truth for the 256-glyph multicolor charROM:
  * emits ms/1_charset.ms      (microScript 2.0 data, human-editable)
  * emits sprites/charrom.png  (sprite sheet, editable in microStudio's editor)
  * emits docs/charset_preview.png (visual reference)

Glyph format: 4x8 MULTICOLOR pixels (like a C64 multicolor char cell, where
every cell is 8x8 screen pixels but pixels are double-wide). Each pixel is
a digit 0..3 selecting the ink:
  0 = common background (shared; the sky / border color)
  1 = shared highlight ink (white)
  2 = per-cell ACCENT color (color RAM lo nibble)
  3 = per-cell MAIN color   (color RAM hi nibble)
That is exactly "2 colors/char + common background" (plus a shared white).

Art is written with characters:  .  = 0,  W  = 1,  a  = 2,  m  = 3.

PNG role colors (what the game reads back from sprites/charrom.png):
  0 -> #000000   1 -> #FFFFFF   2 -> #68372B   3 -> #70A4B2
Every color in the PNG is an exact VIC-II palette value, so the sheet stays
palette-pure while being editable in microStudio's sprite editor.
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MS_PATH = os.path.join(ROOT, "ms", "1_charset.ms")
PNG_PATH = os.path.join(ROOT, "sprites", "charrom.png")
PREVIEW_PATH = os.path.join(ROOT, "docs", "charset_preview.png")

VIC2 = [
    "000000", "FFFFFF", "68372B", "70A4B2", "6F3D86", "588D43", "352879",
    "B8C70F", "6F4F25", "433900", "9A6759", "444444", "6C6C6C", "9AD284",
    "6C5EB5", "959595",
]
ROLE_COLORS = ["#000000", "#FFFFFF", "#68372B", "#70A4B2"]
CHAR2DIG = {".": "0", "W": "1", "a": "2", "m": "3", "3": "3"}


def mk(art):
    """art: list of 8 strings (4 chars each) -> 32-digit string."""
    assert len(art) == 8, f"need 8 rows, got {len(art)}: {art!r}"
    out = []
    for row in art:
        assert len(row) == 4, f"need 4 cols, got {row!r}"
        out.append("".join(CHAR2DIG[c] for c in row))
    return "".join(out)


def mirror(art):
    return [row[::-1] for row in art]


def place(rows, top=1, width=3):
    """Place rows (3-wide font art) into an 8-row 4-col cell at `top`."""
    grid = [["." for _ in range(4)] for _ in range(8)]
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            grid[top + y][x] = c
    return ["".join(r) for r in grid]


# =====================================================================
# FONT (ASCII 32..127) - chunky 3x5 letters in a 4x8 multicolor cell,
# drawn with digit 3 (per-cell main color) so text can be any color.
# =====================================================================
FONT = {
    " ": [],
    "!": ["#", "#", "#", ".", "#"],
    '"': ["#.#", "#.#"],
    "#": ["#.#", "###", "#.#", "###", "#.#"],
    "$": ["###", "#..", "###", "..#", "###"],
    "%": ["#.#", "..#", ".#.", "#..", "#.#"],
    "&": ["##.", "#.#", "##.", "#.#", "#.#"],
    "'": ["#", "#"],
    "(": [".##", "#..", "#..", "#..", ".##"],
    ")": ["##.", "..#", "..#", "..#", "##."],
    "*": [".#.", "#.#", ".#.", "#.#", ".#."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    ",": ["#", "#"],
    "-": ["...", "...", "###", "...", "..."],
    ".": ["#"],
    "/": ["..#", ".#.", ".#.", ".#.", "#.."],
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"],
    "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", ".#."],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": [".#.", "#.#", ".#.", "#.#", ".#."],
    "9": [".#.", "#.#", "###", "..#", "##."],
    ":": [".", "#", ".", "#"],
    ";": [".", "#", ".", "#", "#"],
    "<": ["..#", ".#.", "#..", ".#.", "..#"],
    "=": ["...", "###", "...", "###", "..."],
    ">": ["#..", ".#.", "..#", ".#.", "#.."],
    "?": ["##.", "..#", ".#.", "...", ".#."],
    "@": [".#.", "#.#", "#.#", "#.#", ".#."],
    "A": [".#.", "###", "#.#", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", ".##", "..#"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", ".#.", "#..", "###"],
    "[": ["##", "#.", "#.", "#.", "##"],
    "\\": ["#..", ".#.", ".#.", ".#.", "..#"],
    "]": ["##", ".#", ".#", ".#", "##"],
    "^": [".#.", "#.#"],
    "_": ["", "", "", "", "", "###"],
    "`": ["#..", ".#."],
    "{": ["##.", "#..", ".#.", "..#", "##."],
    "|": ["#", "#", "#", "#", "#"],
    "}": [".##", "..#", ".#.", "#..", "##."],
    "~": ["", "", ".##", "##.", ""],
}
# lowercase letters render as uppercase (authentic C64 default charset)
for c in "abcdefghijklmnopqrstuvwxyz":
    FONT[c] = FONT[c.upper()]
FONT["|"] = ["#"] * 5

# =====================================================================
# GAME GLYPHS (128..255)
# =====================================================================
G = {}  # name -> art (list of 8 strings, chars: . W a m)

# ---- UI ----
G["cursor"] = mk([
    "W..W",
    "....",
    "....",
    "....",
    "....",
    "....",
    "....",
    "W..W",
])
G["crack1"] = mk([
    "....",
    "..3.",
    ".3..",
    "....",
    "..3.",
    "....",
    ".3..",
    "....",
])
G["crack2"] = mk([
    "..3.",
    ".33.",
    "33..",
    "..33",
    ".33.",
    "3.3.",
    "..3.",
    "...3",
])
G["crack3"] = mk([
    ".33.",
    "3.33",
    "333.",
    ".333",
    "33.3",
    "3.33",
    ".33.",
    "3.3.",
])
G["arrowup"] = mk([
    "....",
    ".mm.",
    "mmmm",
    ".mm.",
    "....",
    "....",
    "....",
    "....",
])
G["arrowdn"] = mk([
    "....",
    "....",
    "....",
    "....",
    ".mm.",
    "mmmm",
    ".mm.",
    "....",
])
G["heartfull"] = mk([
    "....",
    ".mm.",
    "mWmm",
    "mmmm",
    ".mm.",
    "..m.",
    "....",
    "....",
])
G["heartempty"] = mk([
    "....",
    ".mm.",
    "m..m",
    "m..m",
    ".m..",
    "....",
    "....",
    "....",
])
G["sparkle"] = mk([
    "....",
    "..W.",
    "....",
    "W...",  # small + offset dot
    "....",
    "....",
    "....",
    "....",
])

# ---- sky ----
G["sun"] = mk([
    ".mm.",
    "mWam",
    "mWam",
    "maam",
    "maam",
    "mmmm",
    ".mm.",
    "....",
])
G["moon"] = mk([
    "..mm",
    ".m..",
    "m...",
    "m...",
    "m...",
    ".m..",
    ".mm.",
    "....",
])
G["cloud"] = mk([
    "....",
    "..m.",
    ".mmm",
    "mmmm",
    "mmmm",
    ".mm.",
    "....",
    "....",
])
G["star"] = mk([
    "....",
    "....",
    "..W.",
    "....",
    "....",
    ".W..",
    "....",
    "....",
])

# ---- tiles ----
G["grass"] = mk([
    "mmmm",
    "m.m.",
    "amma",
    "a.aa",
    "aa.a",
    "a.aa",
    "aaa.",
    "aaaa",
])
G["dirt"] = mk([
    "a.aa",
    "aa.a",
    "a.aa",
    "aaaa",
    "aa.a",
    "a.aa",
    "aaaa",
    "aa.a",
])
G["stone"] = mk([
    "mmmm",
    "m..m",
    "mmam",
    "mamm",
    "ammm",
    "mmam",
    "mamm",
    "mmmm",
])
G["bedrock"] = mk([
    "m.am",
    "amma",
    "m.ma",
    "amam",
    "maam",
    "amma",
    "m.ma",
    "amam",
])
G["sand"] = mk([
    "mmmm",
    "m.m.",
    "mmaa",
    "ammm",
    "mmam",
    "mamm",
    "ammm",
    "mmmm",
])
G["gravel"] = mk([
    "m.am",
    "amma",
    "amam",
    "mama",
    "amma",
    "amam",
    "mama",
    "amma",
])
G["coal"] = mk([
    "mmmm",
    "m0.m".replace("0", "."),
    "mm.m",
    "m.mm",
    ".mmm",
    "mm.m",
    "m.mm",
    "mmmm",
])
G["iron"] = mk([
    "mmmm",
    "mW.m",
    "mmWm",
    "m.mm",
    "Wmmm",
    "mmWm",
    "m.mm",
    "mmmm",
])
G["gold"] = mk([
    "mmmm",
    "ma.m",
    "mmam",
    "m.am",
    "ammm",
    "mmam",
    "m.am",
    "mmmm",
])
G["diamond"] = mk([
    "mmmm",
    "ma.m",
    "mmam",
    "m.ma",
    "ammm",
    "mmam",
    "m.ma",
    "mmmm",
])
G["wood"] = mk([
    "amma",
    "a.ma",
    "am.a",
    "a.ma",
    "am.a",
    "a.ma",
    "am.a",
    "amma",
])
G["leaves"] = mk([
    "m.ma",
    "amm.",
    "m.ma",
    "ammm",
    "m.ma",
    "am.m",
    "m.ma",
    "ammm",
])
G["planks"] = mk([
    "aaaa",
    "mmmm",
    "aaaa",
    "amam",
    "aaaa",
    "mmmm",
    "aaaa",
    "amam",
])
G["torch"] = mk([
    "..W.",
    ".mmm",
    ".mam",
    "..a.",
    "..a.",
    "..a.",
    "..a.",
    "..a.",
])
G["craft"] = mk([
    "aWma",
    "ammm",
    "aaaa",
    "a..a",
    "m..m",
    "m..m",
    "m..m",
    "m..m",
])
G["ladder"] = mk([
    "a..a",
    "a..a",
    "aaaa",
    "a..a",
    "a..a",
    "aaaa",
    "a..a",
    "a..a",
])
G["water0"] = mk([
    "maam",
    "mmma",
    "ammm",
    "maam",
    "mmma",
    "ammm",
    "maam",
    "mmma",
])
G["water1"] = mk([
    "aamm",
    "maam",
    "mmma",
    "aamm",
    "maam",
    "mmma",
    "aamm",
    "maam",
])
G["water2"] = mk([
    "mmaa",
    "aamm",
    "maam",
    "mmaa",
    "aamm",
    "maam",
    "mmaa",
    "aamm",
])
G["water3"] = mk([
    "ammm",
    "mmaa",
    "aamm",
    "ammm",
    "mmaa",
    "aamm",
    "ammm",
    "mmaa",
])
G["lava0"] = mk([
    "mmmm",
    "m.am",
    "mmma",
    "ammm",
    "m.am",
    "mmma",
    "ammm",
    "mmmm",
])
G["lava1"] = mk([
    "mmam",
    "mmma",
    "m.am",
    "mmma",
    "ammm",
    "m.am",
    "mmma",
    "ammm",
])
G["lava2"] = mk([
    "ammm",
    "m.am",
    "mmma",
    "ammm",
    "mmam",
    "mmma",
    "m.am",
    "mmma",
])
G["lava3"] = mk([
    "mmma",
    "ammm",
    "mmma",
    "m.am",
    "ammm",
    "mmma",
    "mmam",
    "mmma",
])

# ---- entities ----
PLAYER_BASE = [
    ".mm.",  # 0: skin (m = main? no: face uses accent) -- see below
]
# player: m=main (blue shirt/pants), a=accent (skin), W=white (goggles)
G["player_r0"] = mk([
    ".aa.",
    "aWWa",
    ".mm.",
    "amma",
    ".mm.",
    ".mm.",
    ".m.m",
    ".m.m",
])
G["player_r1"] = mk([
    ".aa.",
    "aWWa",
    ".mm.",
    "amma",
    ".mm.",
    ".mm.",
    ".mm.",
    "m..m",
])
G["player_r2"] = mk([
    ".aa.",
    "aWWa",
    ".mm.",
    "amma",
    ".mm.",
    ".mm.",
    ".m.m",
    ".m.m",
])
G["player_r3"] = mk([
    ".aa.",
    "aWWa",
    ".mm.",
    "amma",
    ".mm.",
    ".mm.",
    "m..m",
    ".mm.",
])
for i in range(4):
    art = [
        ".aa.",
        "aWWa",
        ".mm.",
        "amma",
        ".mm.",
        ".mm.",
        [".m.m", ".mm.", ".m.m", "m..m"][i],
        [".m.m", "m..m", ".m.m", ".mm."][i],
    ]
    G[f"player_r{i}"] = mk(art)
    G[f"player_l{i}"] = mk(mirror(art))
G["player_jump"] = mk([
    ".aa.",
    "aWWa",
    "amm.",
    ".mm.",
    ".mm.",
    ".mm.",
    "m..m",
    "....",
])
G["player_ljump"] = mk(mirror([
    ".aa.",
    "aWWa",
    "amm.",
    ".mm.",
    ".mm.",
    ".mm.",
    "m..m",
    "....",
]))
G["player_climb"] = mk([
    ".aa.",
    "aWWa",
    "amma",
    ".ma.",
    ".mm.",
    ".mm.",
    ".m.m",
    ".m.m",
])
# slime: m=main (green body), a=accent (light highlight), W=white eyes
G["slime0"] = mk([
    "....",
    "....",
    "....",
    ".am.",
    "amma",
    "mWWm",
    "mmmm",
    "mmmm",
])
G["slime1"] = mk([
    "....",
    "....",
    ".am.",
    "amma",
    "mWWm",
    "mmmm",
    "mmmm",
    "mmmm",
])
G["slime2"] = mk([
    "....",
    "....",
    "....",
    ".am.",
    "amma",
    "mWWm",
    "mmmm",
    "mmmm",
])

# ---- item icons ----
G["i_stick"] = mk([
    "...a",
    "..aa",
    ".aa.",
    "aa..",
    "a...",
    "....",
    "....",
    "....",
])
G["i_coal"] = mk([
    "....",
    ".mm.",
    "mmWm",
    "mmmm",
    ".mm.",
    "....",
    "....",
    "....",
])
G["i_iron"] = mk([
    "....",
    "....",
    ".mmm",
    "mWWWm"[:4],
    "mmmm",
    "....",
    "....",
    "....",
])
G["i_gold"] = mk([
    "....",
    "....",
    ".am.",
    "amma",
    "aaaa",
    "....",
    "....",
    "....",
])
G["i_diamond"] = mk([
    "....",
    "..m.",
    ".mmm",
    "mmmm",
    ".mm.",
    "....",
    "....",
    "....",
])
G["i_pick_wood"] = mk([
    "....",
    ".aaa",
    "a..a",
    "...a",
    "..a.",
    ".a..",
    "a...",
    "....",
])
G["i_pick_stone"] = mk([
    "....",
    ".mmm",
    "m..m",
    "...a",
    "..a.",
    ".a..",
    "a...",
    "....",
])
G["i_pick_iron"] = mk([
    "....",
    ".WWW",
    "W..W",
    "...a",
    "..a.",
    ".a..",
    "a...",
    "....",
])
G["i_sword_wood"] = mk([
    "..a.",
    "..a.",
    ".a..",
    ".a..",
    "a...",
    "ma..",
    "....",
    "....",
])
G["i_sword_iron"] = mk([
    "..W.",
    "..W.",
    ".W..",
    ".W..",
    "W...",
    "mW..",
    "....",
    "....",
])

# =====================================================================
# GLYPH INDEX ASSIGNMENT
# =====================================================================
IDX = {}
IDX["blank"] = 0
for i, name in enumerate([
    "cursor", "crack1", "crack2", "crack3", "arrowup", "arrowdn",
    "heartfull", "heartempty", "sparkle",
]):
    IDX[name] = 1 + i
for code in range(32, 128):
    IDX[f"ascii{code}"] = code
start = 128
for name in [
    "sun", "moon", "cloud", "star", "grass", "dirt", "stone", "bedrock",
    "sand", "gravel", "coal", "iron", "gold", "diamond", "wood", "leaves",
    "planks", "torch", "craft", "ladder",
    "water0", "water1", "water2", "water3",
    "lava0", "lava1", "lava2", "lava3",
    "player_r0", "player_r1", "player_r2", "player_r3",
    "player_l0", "player_l1", "player_l2", "player_l3",
    "player_jump", "player_ljump", "player_climb",
    "slime0", "slime1", "slime2",
    "i_stick", "i_coal", "i_iron", "i_gold", "i_diamond",
    "i_pick_wood", "i_pick_stone", "i_pick_iron",
    "i_sword_wood", "i_sword_iron",
]:
    IDX[name] = start
    start += 1

# build the 256-glyph table
GLYPHS = ["0" * 32] * 256
for name, art in G.items():
    GLYPHS[IDX[name]] = art
for code in range(32, 128):
    ch = chr(code)
    rows = FONT.get(ch, FONT.get(ch.upper(), []))
    top = 1
    if ch in ".,'":
        top = 3
    elif ch == '"':
        top = 2
    elif ch in ":;`":
        top = 2
    elif ch == "_":
        top = 6
    elif ch in "^~":
        top = 1
    GLYPHS[code] = art

# also expose ascii glyph helpers as named constants
NAMED_OUTPUT = {k: v for k, v in IDX.items()}

# =====================================================================
# EMIT microScript
# =====================================================================
def emit_ms():
    lines = []
    lines.append("// =====================================================================")
    lines.append("// C64 MINE DEMAKE - 1_charset.ms   (GENERATED by tools/genchars.py)")
    lines.append("// ---------------------------------------------------------------------")
    lines.append("// The 256-glyph MULTICOLOR CHAR ROM. One look for the whole game:")
    lines.append("// every tile, item, creature and letter is an 8x8 cell of double-wide")
    lines.append("// pixels, like the C64's multicolor charset mode.")
    lines.append("//")
    lines.append("// Each glyph is 32 digits = 8 rows x 4 columns. Digit = ink:")
    lines.append("//   0 = common background (sky/border, shared by all cells)")
    lines.append("//   1 = shared highlight ink (white)")
    lines.append("//   2 = per-cell ACCENT color (color RAM)")
    lines.append("//   3 = per-cell MAIN color   (color RAM)")
    lines.append("// i.e. 2 free colors per char + a common background (plus white).")
    lines.append("//")
    lines.append("// You can ALSO edit the art without touching code: open the sprite")
    lines.append("// \"charrom\" in microStudio's sprite editor (sprites/charrom.png).")
    lines.append("// Each 8x8 cell of that sheet is one glyph, in reading order; use the")
    lines.append("// 4 role colors  black/white/red/cyan  for inks 0/1/2/3 (exact VIC-II")
    lines.append("// values). If that sprite exists, the game loads glyphs from it.")
    lines.append("// =====================================================================")
    lines.append("")
    lines.append("CHARROM = [")
    for i in range(256):
        name = None
        for k, v in IDX.items():
            if v == i:
                name = k
                break
        label = f"{i:3d}"
        if name:
            label += f" ({name})"
        lines.append(f'  "{GLYPHS[i]}",  // {label}')
    lines.append("]")
    lines.append("")
    lines.append("// ---- glyph index constants (use these in code, never raw numbers) ----")
    lines.append("GL = object")
    for k in sorted(IDX, key=lambda n: IDX[n]):
        lines.append(f"  {k} = {IDX[k]}")
    lines.append("end")
    lines.append("")
    with open(MS_PATH, "w") as f:
        f.write("\n".join(lines) + "\n")


# =====================================================================
# EMIT PNG sprite sheet (16x16 cells of 8x8 px = 128x128)
# =====================================================================
def emit_png():
    from PIL import Image

    img = Image.new("RGB", (128, 128), (0, 0, 0))
    px = img.load()
    for i in range(256):
        cx = (i % 16) * 8
        cy = (i // 16) * 8
        data = GLYPHS[i]
        for r in range(8):
            for c in range(4):
                d = int(data[r * 4 + c])
                color = tuple(int(ROLE_COLORS[d][j:j + 2], 16) for j in (1, 3, 5))
                for xx in range(2):
                    px[cx + c * 2 + xx, cy + r] = color
    os.makedirs(os.path.dirname(PNG_PATH), exist_ok=True)
    img.save(PNG_PATH)

    # preview sheet with sample colors: white/brown/medium gray
    prev = Image.new("RGB", (128 * 2, 128 * 2), (0, 0, 0))
    ppx = prev.load()
    sample = {
        0: (0, 0, 0),
        1: (255, 255, 255),
        2: (0x6F, 0x4F, 0x25),
        3: (0x6C, 0x6C, 0x6C),
    }
    for i in range(256):
        cx = (i % 16) * 16
        cy = (i // 16) * 16
        data = GLYPHS[i]
        for r in range(8):
            for c in range(4):
                d = int(data[r * 4 + c])
                col = sample[d]
                for yy in range(2):
                    for xx in range(4):
                        ppx[cx + c * 4 + xx, cy + r * 2 + yy] = col
    os.makedirs(os.path.dirname(PREVIEW_PATH), exist_ok=True)
    prev.save(PREVIEW_PATH)


if __name__ == "__main__":
    emit_ms()
    emit_png()
    print(f"wrote {MS_PATH}")
    print(f"wrote {PNG_PATH}")
    print(f"wrote {PREVIEW_PATH}")
    print(f"glyphs used: {len(G)} art glyphs + font, highest index {max(IDX.values())}")
