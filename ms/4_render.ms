// =====================================================================
// C64 MINE DEMAKE - 4_render.ms
// The renderer. Everything on screen is drawn through one char-cell
// framebuffer: 40x25 cells, each with a glyph index and color RAM
// entries (bg + main + accent), like a real C64 screen.
//
// TWO LAYERS, like real C64 hardware:
//   * BASE layer (world + sky): ink 0 pixels show the cell's own
//     background color (like the VIC-II background register, but we
//     keep one per cell so caves can be black while the sky is blue).
//   * OVERLAY layer (player, mobs, particles, HUD): ink 0 pixels are
//     TRANSPARENT (like hardware sprites), the base layer shows
//     through.
//
// The 320x200 virtual screen is emitted with run-merged fillRect calls
// (one per horizontal same-color run), 8 pixel rows per cell row.
// =====================================================================

// base layer buffers
cellGlyph = []   // 40*25 glyph indices
cellMain = []    // main ink (color RAM)
cellAccent = []  // accent ink (color RAM)
cellBg = []      // background ink for ink-0 pixels
cellLight = []   // light 0..3 applied to the cell

// overlay layer buffers (glyph -1 = none)
ovGlyph = []
ovMain = []
ovAccent = []

// glyph pixel run cache: for each glyph, per row: [colStart, len, ink]
GLYPH_RUNS = []

// dim color lookup: SHADE[c][level] = palette index to draw instead.
// Index by LIGHT LEVEL: level 3 = full color, 2 = dim, 1 = darker, 0 = black.
// (Levels are ordered darkest-first here; resolveInk indexes [light].)
SHADE = [
  [0,0,0,0],    // 0 black stays black
  [0,11,15,1],  // 1 white: black -> dk.gray -> lt.gray -> white
  [0,0,9,2],    // 2 red: black -> black -> dk.brn -> red
  [0,11,11,3],  // 3 cyan: black -> dk.gray -> dk.gray -> cyan
  [0,0,11,4],   // 4 purple: black -> black -> dk.gray -> purple
  [0,9,11,5],   // 5 green: black -> dk.brn -> dk.gray -> green
  [0,0,11,6],   // 6 blue: black -> black -> dk.gray -> blue
  [0,9,8,7],    // 7 yellow: black -> dk.brn -> brown -> yellow
  [0,0,9,8],    // 8 brown: black -> black -> dk.brn -> brown
  [0,0,9,9],    // 9 dark brown
  [0,9,2,10],   // 10 lt.red: black -> dk.brn -> red -> lt.red
  [0,0,9,11],   // 11 dk.gray: black -> black -> dk.brn -> dk.gray
  [0,0,11,12],  // 12 md.gray: black -> black -> dk.gray -> md.gray
  [0,11,5,13],  // 13 lt.green: black -> dk.gray -> green -> lt.green
  [0,11,6,14],  // 14 lt.blue: black -> dk.gray -> blue -> lt.blue
  [0,11,11,15]  // 15 lt.gray: black -> dk.gray -> dk.gray -> lt.gray
]

initRender = function()
  local i = 0
  cellGlyph = []
  cellMain = []
  cellAccent = []
  cellBg = []
  cellLight = []
  ovGlyph = []
  ovMain = []
  ovAccent = []
  while i < COLS * ROWS
    cellGlyph.push(0)
    cellMain.push(0)
    cellAccent.push(-1)
    cellBg.push(0)
    cellLight.push(3)
    ovGlyph.push(-1)
    ovMain.push(0)
    ovAccent.push(-1)
    i = i + 1
  end
  buildGlyphRuns()
end

// Convert CHARROM digit strings into per-pixel ink tables for blitting.
// GLYPH_RUNS[glyph][row] is a flat list of 4 ink digits (0 bg, 1 white,
// 2 accent, 3 main) - one per fat pixel column.
buildGlyphRuns = function()
  GLYPH_RUNS = []
  local i = 0
  while i < 256
    local runs = []
    local g = CHARROM[i]
    local r = 0
    while r < 8
      local rowInks = []
      local c = 0
      while c < 4
        rowInks.push(g.charCodeAt(r * 4 + c) - 48)
        c = c + 1
      end
      runs.push(rowInks)
      r = r + 1
    end
    GLYPH_RUNS.push(runs)
    i = i + 1
  end
end

// If a "charrom" sprite exists (artist-edited in microStudio), read its
// pixels back into CHARROM. Each 8x8 cell of the 128x128 sheet is one
// glyph, in reading order; the 4 role colors map to inks:
//   black -> 0, white -> 1, red -> 2, cyan -> 3
loadCharsetFromSprite = function()
  local spr = sprites["charrom"]
  if spr == 0 then
    return 0
  end
  if spr.ready == 0 then
    return 0
  end
  local img = spr.frames[0]
  if img.width < 128 or img.height < 128 then
    return 0
  end
  local i = 0
  while i < 256
    local cx = (i % 16) * 8
    local cy = floor(i / 16) * 8
    local g = ""
    local r = 0
    while r < 8
      local c = 0
      while c < 4
        local px = img.getRGB(cx + c * 2, cy + r)
        local ink = 0
        if px.R == 255 and px.G == 255 then
          ink = 1
        elsif px.R == 104 and px.G == 55 then
          ink = 2
        elsif px.R == 112 and px.G == 164 then
          ink = 3
        end
        g = g + ink
        c = c + 1
      end
      r = r + 1
    end
    CHARROM[i] = g
    i = i + 1
  end
  buildGlyphRuns()
  return 1
end

// ---------------------- cell framebuffer API ----------------------

cellClear = function(glyph, main, bg)
  local i = 0
  while i < COLS * ROWS
    cellGlyph[i] = glyph
    cellMain[i] = main
    cellAccent[i] = -1
    cellBg[i] = bg
    cellLight[i] = 3
    ovGlyph[i] = -1
    i = i + 1
  end
end

cellPut = function(cx, cy, glyph, main, accent, light)
  if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS then
    return 0
  end
  local i = cy * COLS + cx
  cellGlyph[i] = glyph
  cellMain[i] = main
  if accent >= 0 then
    cellAccent[i] = accent
  else
    cellAccent[i] = -1
  end
  if light >= 0 then
    cellLight[i] = light
  else
    cellLight[i] = 3
  end
  return 1
end

cellSetBg = function(cx, cy, bg)
  if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS then
    return 0
  end
  cellBg[cy * COLS + cx] = bg
  return 1
end

// overlay: ink 0 is transparent. glyph < 0 = skip.
// Overlays are hardware-sprite-like: they render with their own colors
// at full brightness and never modify the base cell they cover (the
// tile underneath keeps its own world light).
cellOverlay = function(cx, cy, glyph, main, accent, light)
  if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS then
    return 0
  end
  if glyph < 0 then
    return 0
  end
  local i = cy * COLS + cx
  ovGlyph[i] = glyph
  ovMain[i] = main
  ovAccent[i] = accent
  return 1
end

cellOverlayText = function(cx, cy, s, main, accent)
  local x = cx
  local n = s.length
  local i = 0
  while i < n
    local code = s.charCodeAt(i)
    if code >= 97 and code <= 122 then
      code = code - 32
    end
    if x >= 0 and x < COLS then
      cellOverlay(x, cy, code, main, accent, 0)
    end
    x = x + 1
    i = i + 1
  end
  return x - cx
end

// --------------------------- text ---------------------------------

// text string -> BASE cells (uppercase C64 style)
cellText = function(cx, cy, s, main)
  local x = cx
  local n = s.length
  local i = 0
  while i < n
    local code = s.charCodeAt(i)
    if code >= 97 and code <= 122 then
      code = code - 32
    end
    cellPut(x, cy, code, main, -1, 3)
    x = x + 1
    i = i + 1
  end
  return x - cx
end

cellTextC = function(cx, cy, s, main)
  return cellText(cx - floor(s.length / 2), cy, s, main)
end

cellOverlayTextC = function(cx, cy, s, main, accent)
  return cellOverlayText(cx - floor(s.length / 2), cy, s, main, accent)
end

// ---------------------- world -> cells ----------------------------

// camera position in world tiles (float)
camX = 0
camY = 0

// water/lava animation frame (0..3)
liquidFrame = 0

worldToCell = function()
  local tx = floor(camX)
  local ty = floor(camY)
  for cy = 0 to ROWS - 1
    for cx = 0 to COLS - 1
      local wx = tx + cx
      local wy = ty + cy
      local t = getTile(wx, wy)
      local g = 0
      local main = 0
      local accent = -1
      local light = 3
      local bg = 0
      local idx = cy * COLS + cx
      if t == T.AIR then
        if wy >= surfaceHint(wx) then
          // underground air: black background, no glyph
          g = 0
          main = 0
          bg = 0
          light = getLight(wx, wy)
        else
          g = skyGlyph(wx, wy)
          main = skyMain(wx, wy)
          bg = CR.BLUE
          light = 3
        end
      else
        local ti = TILES[t]
        g = ti.glyph
        if ti.liquid == 1 then
          g = liquidGlyph(t, wx, wy)
        end
        main = ti.main
        if ti.accent >= 0 then
          accent = ti.accent
        end
        light = getLight(wx, wy)
        if t == T.WATER or t == T.LAVA then
          bg = main
        else
          bg = 0
        end
      end
      cellGlyph[idx] = g
      cellMain[idx] = main
      cellAccent[idx] = accent
      cellBg[idx] = bg
      cellLight[idx] = light
      ovGlyph[idx] = -1
    end
  end
end

// quick per-column surface row cache for sky shading
surfaceCache = []

buildSurfaceCache = function()
  surfaceCache = []
  for x = 0 to WORLD_W - 1
    local y = 0
    while y < WORLD_H
      local t = world[y][x]
      if t != T.AIR and t != T.WATER and t != T.TORCH and t != T.LADDER and t != T.LEAVES then
        break
      end
      y = y + 1
    end
    surfaceCache.push(y)
  end
end

surfaceHint = function(wx)
  if wx < 0 or wx >= WORLD_W then
    return 999
  end
  return surfaceCache[wx]
end

// decorative sky glyphs: stars, sun, clouds (world-anchored)
skyGlyph = function(wx, wy)
  local n = noise1(wx * 3.7 + wy * 91.3, 42)
  if n > 0.93 then
    return GL.star
  end
  local sx = (floor(skyScroll * 0.25) + 5) % WORLD_W
  if wy == 3 and wx == sx then
    return GL.sun
  end
  local c1x = (floor(skyScroll * 0.5) + 14) % WORLD_W
  if wy == 5 and (wx - c1x + WORLD_W) % WORLD_W < 3 then
    return GL.cloud
  end
  local c2x = (floor(skyScroll * 0.3) + 30) % WORLD_W
  if wy == 8 and (wx - c2x + WORLD_W) % WORLD_W < 2 then
    return GL.cloud
  end
  return 0
end

skyMain = function(wx, wy)
  local n = noise1(wx * 3.7 + wy * 91.3, 42)
  if n > 0.93 then
    return CR.WHITE
  end
  if skyGlyph(wx, wy) == GL.sun then
    return CR.YELLOW
  end
  if skyGlyph(wx, wy) == GL.cloud then
    return CR.WHITE
  end
  return CR.BLUE
end

// animated liquid glyphs
liquidGlyph = function(t, wx, wy)
  local f = liquidFrame
  if t == T.WATER then
    return GL.water0 + ((wx + wy + f) % 4)
  end
  return GL.lava0 + ((wx * 2 + wy + f) % 4)
end

// ---------------------- framebuffer -> screen ---------------------

// The virtual screen: 320x200 px, logical coords centered (y-up).
// Cell (cx,cy) covers virtual pixels x = cx*8..cx*8+7, raster row
// y = cy*8..cy*8+7. Emits one fillRect per merged same-color run.
//
// NOTE: run state lives in globals (BRUN_*) because microScript 2.0
// closures cannot WRITE outer function locals (writes land in a
// private copy). This is a verified engine limitation.
BRUN_X = 0
BRUN_W = 0
BRUN_COL = -1

brunFlush = function(rowY, halfW)
  if BRUN_COL >= 0 and BRUN_W > 0 then
    screen.fillRect(BRUN_X + BRUN_W / 2 - halfW, rowY, BRUN_W, 1, C64[BRUN_COL])
  end
  BRUN_X = 0
  BRUN_W = 0
  BRUN_COL = -1
end

blitCells = function()
  local halfW = SCREEN_W / 2
  local halfH = SCREEN_H / 2
  for cy = 0 to ROWS - 1
    local rowTop = halfH - cy * CELL
    for r = 0 to 7
      local rowY = rowTop - r - 0.5
      BRUN_X = 0
      BRUN_W = 0
      BRUN_COL = -1
      for cx = 0 to COLS - 1
        local i = cy * COLS + cx
        local baseX = cx * CELL
        local main = cellMain[i]
        local accent = cellAccent[i]
        local bg = cellBg[i]
        local light = cellLight[i]
        local rowRuns = 0
        if GLYPH_RUNS.length > 0 then
          rowRuns = GLYPH_RUNS[cellGlyph[i]][r]
          if rowRuns == 0 then
            rowRuns = GLYPH_RUNS[0][r]
          end
        end
        local ov = ovGlyph[i]
        local ovRuns = 0
        if ov >= 0 and GLYPH_RUNS.length > 0 then
          ovRuns = GLYPH_RUNS[ov][r]
        end
        local c = 0
        if rowRuns == 0 then
          // no glyph data yet (e.g. draw before init on a live reload):
          // skip this cell
          c = 4
        end
        while c < 4
          local ink = rowRuns[c]
          local fromOv = 0
          if ovRuns != 0 and ovRuns[c] > 0 then
            ink = ovRuns[c]
            fromOv = 1
          end
          local col = resolveInk(ink, main, accent, ovMain[i], ovAccent[i], bg, light, fromOv)
          if col == BRUN_COL and baseX + c * 2 == BRUN_X + BRUN_W then
            BRUN_W = BRUN_W + 2
          else
            brunFlush(rowY, halfW)
            BRUN_X = baseX + c * 2
            BRUN_W = 2
            BRUN_COL = col
          end
          c = c + 1
        end
      end
      brunFlush(rowY, halfW)
    end
  end
end

// resolve an ink digit to a palette color index, applying light.
// overlay pixels (fromOverlay) use overlay colors and ignore bg.
resolveInk = function(ink, main, accent, ovMain, ovAccent, bg, light, fromOverlay)
  local c = main
  if fromOverlay then
    c = ovMain
    if ink == 1 then
      c = CR.WHITE
    elsif ink == 2 then
      if ovAccent >= 0 then
        c = ovAccent
      end
    end
  else
    if ink == 0 then
      c = bg
    elsif ink == 1 then
      c = CR.WHITE
    elsif ink == 2 then
      if accent >= 0 then
        c = accent
      else
        c = main
      end
    end
  end
  if fromOverlay then
    // overlays (player, mobs, HUD) are hardware-sprite-like: they carry
    // their own full-brightness colors and are not dimmed by cell light
    return c
  end
  if light < 3 then
    return SHADE[c][light]
  end
  return c
end
