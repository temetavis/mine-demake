// =====================================================================
// C64 MINE DEMAKE - 0_core.ms
// Palette, configuration and small shared helpers.
// ---------------------------------------------------------------------
// The C64's video chip (VIC-II) offers exactly 16 colors. Every single
// pixel this game draws comes from this palette and nothing else.
// Hex values are the measured "Pepto" VIC-II values (PAL).
// =====================================================================

// ----------------------------- palette ------------------------------

C64 = [
  "#000000", //  0 black
  "#FFFFFF", //  1 white
  "#68372B", //  2 red
  "#70A4B2", //  3 cyan
  "#6F3D86", //  4 purple
  "#588D43", //  5 green
  "#352879", //  6 blue
  "#B8C70F", //  7 yellow
  "#6F4F25", //  8 brown
  "#433900", //  9 dark brown (light brown on PAL)
  "#9A6759", // 10 light red / second brown family tone
  "#444444", // 11 dark gray
  "#6C6C6C", // 12 medium gray
  "#9AD284", // 13 light green
  "#6C5EB5", // 14 light blue
  "#959595"  // 15 light gray
]

// Color RAM: per-cell ink nibble (0..15) indexes C64. Note that
// both browns and all three grays are present and used.
CR = object
  BLACK = 0
  WHITE = 1
  RED = 2
  CYAN = 3
  PURPLE = 4
  GREEN = 5
  BLUE = 6
  YELLOW = 7
  BROWN = 8
  DKBRN = 9
  LTRED = 10
  DKGRY = 11
  MDGRY = 12
  LTGRN = 13
  LTBLU = 14
  LTGRY = 15
end

// The virtual screen is a fixed 320x200 pixel canvas made of 40x25
// char cells of 8x8 "fat pixels" (C64 multicolor chars: 4x8 pixels).
SCREEN_W = 320
SCREEN_H = 200
COLS = 40
ROWS = 25
CELL = 8

// The game world is one column of tiles wider than the screen plus
// boundary, so the camera can scroll one char at a time.
WORLD_W = 256
WORLD_H = 64

// Shared per-frame multicolor ink registers (like a C64 color settings)
// - one common background + the two shared inks. The glyph ROM below
//   draws with ink values 0..3; 0 always maps to the background color.
INK_BG   = CR.BLACK
INK_1    = CR.WHITE
INK_2    = CR.BROWN
INK_3    = CR.GREEN

// Title of the browser tab / project description
GAME_TITLE = "MINE DEMAKE '64"

// --------------------------- tiny helpers ---------------------------

clamp = function(v, lo, hi)
  if v < lo then
    return lo
  elsif v > hi then
    return hi
  end
  return v
end

lerp = function(a, b, t)
  return a + (b - a) * t
end

// sign without branching weirdness
sgn = function(v)
  if v > 0 then
    return 1
  elsif v < 0 then
    return -1
  end
  return 0
end

// seedable random helpers (microStudio's global random is seeded per run)
rand01 = function()
  return random.next()
end

randInt = function(n)
  return floor(random.next() * n)
end

randRange = function(lo, hi)
  return lo + floor(random.next() * (hi - lo + 1))
end

// one-dimensional value noise for terrain generation
noise1 = function(x, seed)
  local n = sin(x * 12.9898 + seed * 78.233) * 43758.5453
  return n - floor(n)
end

smoothNoise = function(x, seed)
  local i = floor(x)
  local f = x - i
  local a = noise1(i, seed)
  local b = noise1(i + 1, seed)
  return lerp(a, b, f * f * (3 - 2 * f))
end
