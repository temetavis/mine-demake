// =====================================================================
// C64 MINE DEMAKE - 5_game.ms
// Player, controls, mining, placing, inventory, crafting, mobs,
// HUD and the main init/update/draw lifecycle.
// =====================================================================

// ---------------------------- sound --------------------------------
// microStudio's audio.beep plays a note-SEQUENCE string, e.g.
//   audio.beep("square C5")        - one C5 square blip
//   audio.beep("square duration 100 C4 C4") - short double blip
// playSfx converts a MIDI-ish note number to the closest note name.
NOTE_NAMES = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

playSfx = function(noteNum, durMs, vol)
  local n = clamp(floor(noteNum), 24, 96)
  local name = NOTE_NAMES[n % 12] + (floor(n / 12) - 1)
  local v = 40
  if vol > 0 then
    v = vol
  end
  audio.beep("square duration " + durMs + " volume " + v + " " + name)
end

// ---------------------------- state ------------------------------

G = object
  scene = "title"   // title | play | dead
  time = 0
  deathCount = 0
end

player = object
  x = 0      // world tile coords (float)
  y = 0
  vx = 0
  vy = 0
  dir = 1     // 1 = facing right, -1 = left
  onGround = 0
  hp = 5
  maxHp = 5
  invuln = 0  // frames of invulnerability after damage
  anim = 0    // walk animation timer
  climbing = 0
  miningX = -1
  miningY = -1
  miningProg = 0
end

// inventory: list of object id, count  (hotbar = first 8 slots)
inv = []
sel = 0        // selected hotbar slot 0..7
msg = ""
msgTimer = 0

mobs = []      // list of object x, y, vx, vy, hp, anim, kind

// particles: list of object x, y, vx, vy, life, col
particles = []

// crafting menu open flag + selection
craftOpen = 0
craftSel = 0

// ------------------------- lifecycle ------------------------------

init = function()
  // Build the data tables first: microStudio runs source files in
  // network-arrival order, so anything referencing T/I/GL/CR from another
  // file must be built HERE (init runs after ALL files are loaded),
  // not at the top level of a file.
  defineTiles()
  defineRecipes()
  G.time = 0
  G.scene = "title"
  G.deathCount = 0
  inv = []
  sel = 0
  msg = ""
  msgTimer = 0
  mobs = []
  particles = []
  craftOpen = 0
  craftSel = 0
  player.hp = 5
  player.maxHp = 5
  player.invuln = 0
  player.vx = 0
  player.vy = 0
  player.dir = 1
  player.miningX = -1
  player.miningY = -1
  player.miningProg = 0
  initRender()
  // if the project has an artist-edited "charrom" sprite, use it for all art
  loadCharsetFromSprite()
  startGame()
end

startGame = function()
  local seed = 1 + randInt(99999)
  initWorld(seed)
  buildSurfaceCache()
  // spawn near the world center, on open grass with headroom
  local sx = floor(WORLD_W / 2)
  local best = -1
  local dx = 0
  while dx <= 30 and dx >= -30
    local cand = floor(WORLD_W / 2) + dx
    if cand > 2 and cand < WORLD_W - 3 then
      local sy = surfaceCache[cand] - 2
      // feet on solid ground, 2 tiles of air above
      if isSolid(getTile(cand, sy + 1)) and getTile(cand, sy) == T.AIR and getTile(cand, sy - 1) == T.AIR then
        best = cand
        break
      end
    end
    if dx >= 0 then
      dx = -dx - 1
    else
      dx = -dx
    end
  end
  if best < 0 then
    best = floor(WORLD_W / 2)
  end
  sx = best
  local sy = surfaceCache[sx] - 2
  player.x = sx + 0.5
  player.y = sy
  player.hp = player.maxHp
  giveItem(I.PICK_WOOD, 1)
  giveItem(I.TORCH, 5)
  msg = "DIG! BUILD! SURVIVE!"
  msgTimer = 180
  lightDirty = 1
  spawnMobs()
end

// ------------------------- inventory ------------------------------

giveItem = function(id, count)
  local i = 0
  while i < inv.length
    if inv[i].id == id then
      inv[i].count = inv[i].count + count
      return 1
    end
    i = i + 1
  end
  inv.push(object
    id = id
    count = count
  end)
  return 1
end

takeItem = function(id, count)
  local i = 0
  while i < inv.length
    if inv[i].id == id then
      if inv[i].count < count then
        return 0
      end
      inv[i].count = inv[i].count - count
      if inv[i].count <= 0 then
        inv.splice(i, 1)
        if sel >= inv.length and sel > 0 then
          sel = inv.length - 1
        end
      end
      return 1
    end
    i = i + 1
  end
  return 0
end

countItem = function(id)
  local i = 0
  while i < inv.length
    if inv[i].id == id then
      return inv[i].count
    end
    i = i + 1
  end
  return 0
end

// hotbar slot item (or 0 = empty hand)
slotItem = function(n)
  if n < inv.length then
    return inv[n].id
  end
  return 0
end

// -------------------------- crafting -----------------------------

defineRecipes = function()
  RECIPES = []
  // basic - no station needed
  recipedef(T.PLANKS, 4, [[T.WOOD, 1]], 0)
  recipedef(I.STICK, 4, [[T.PLANKS, 2]], 0)
  recipedef(T.TORCH, 4, [[I.STICK, 1], [I.COAL, 1]], 0)
  recipedef(T.CRAFT, 1, [[T.PLANKS, 4]], 0)
  recipedef(T.LADDER, 3, [[T.PLANKS, 3]], 0)
  // tools - need a crafting table nearby
  recipedef(I.PICK_WOOD, 1, [[T.PLANKS, 3], [I.STICK, 2]], 1)
  recipedef(I.PICK_STONE, 1, [[T.STONE, 3], [I.STICK, 2]], 1)
  recipedef(I.SWORD_WOOD, 1, [[T.PLANKS, 2], [I.STICK, 1]], 1)
  // iron gear
  recipedef(I.PICK_IRON, 1, [[I.IRON, 3], [I.STICK, 2]], 1)
  recipedef(I.SWORD_IRON, 1, [[I.IRON, 2], [I.STICK, 1]], 1)
end

// craftable list cached when the menu opens
craftList = []

refreshCraftList = function()
  craftList = []
  local i = 0
  while i < RECIPES.length
    local r = RECIPES[i]
    local ok = 1
    local j = 0
    while j < r.need.length
      if countItem(r.need[j][0]) < r.need[j][1] then
        ok = 0
        break
      end
      j = j + 1
    end
    if r.station == 1 then
      if nearCraftingTable() == 0 then
        ok = 0
      end
    end
    if ok then
      craftList.push(r)
    end
    i = i + 1
  end
end

nearCraftingTable = function()
  local px = floor(player.x)
  local py = floor(player.y)
  local dy = -2
  while dy <= 2
    local dx = -2
    while dx <= 2
      if getTile(px + dx, py + dy) == T.CRAFT then
        return 1
      end
      dx = dx + 1
    end
    dy = dy + 1
  end
  return 0
end

doCraft = function()
  if craftSel < craftList.length then
    local r = craftList[craftSel]
    local j = 0
    while j < r.need.length
      takeItem(r.need[j][0], r.need[j][1])
      j = j + 1
    end
    giveItem(r.out, r.count)
    playSfx(72, 120, 50)
    msg = "CRAFTED " + itemName(r.out)
    msgTimer = 90
    refreshCraftList()
  end
end

// ---------------------------- mobs ---------------------------------

spawnMobs = function()
  mobs = []
  local i = 0
  while i < 6
    local mx = randInt(WORLD_W - 8) + 4
    local my = surfaceCache[mx] - 1
    if getTile(mx, my) == T.AIR then
      mobs.push(object
        x = mx + 0.5
        y = my
        vx = 0
        vy = 0
        hp = 2
        anim = 0
        kind = "slime"
      end)
    end
    i = i + 1
  end
end

// -------------------------- gameplay -------------------------------

TICK = 1 / 60
GRAVITY = 30       // tiles per second^2
MOVE_SPEED = 6     // tiles per second
JUMP_VY = 12       // initial jump velocity

update = function()
  G.time = G.time + 1
  if G.scene == "title" then
    updateTitle()
    return 0
  end
  if G.scene == "dead" then
    if keyboard.press.SPACE or keyboard.press.ENTER then
      init()
      // restart straight into a fresh game, skipping the title screen
      G.scene = "play"
    end
    return 0
  end

  updatePlayer()
  updateMobs()
  updateParticles()
  updateMining()
  updateCamera()
  computeLight()
  liquidFrame = floor(G.time / 20) % 4
  skyScroll = skyScroll + 0.02
  if msgTimer > 0 then
    msgTimer = msgTimer - 1
  end
end

updateTitle = function()
  if keyboard.press.SPACE or keyboard.press.ENTER then
    G.scene = "play"
    msgTimer = 120
  end
end

updatePlayer = function()
  local p = player
  // horizontal input
  local ax = 0
  if keyboard.LEFT then
    ax = -1
    p.dir = -1
  elsif keyboard.RIGHT then
    ax = 1
    p.dir = 1
  end
  p.vx = ax * MOVE_SPEED

  // climbing ladders
  p.climbing = 0
  if getTile(floor(p.x), floor(p.y)) == T.LADDER then
    p.climbing = 1
    p.vy = 0
    if keyboard.UP then
      p.vy = -MOVE_SPEED * 0.7
    elsif keyboard.DOWN then
      p.vy = MOVE_SPEED * 0.7
    end
  end

  if p.climbing == 0 then
    // jump (edge-triggered so holding UP doesn't auto-bounce)
    if keyboard.press.UP and p.onGround then
      p.vy = -JUMP_VY
      p.onGround = 0
    end
    p.vy = p.vy + GRAVITY * TICK
    if p.vy > 20 then
      p.vy = 20
    end
  end

  // move with tile collision (x axis then y axis)
  moveAxis(p, p.vx * TICK, 0)
  p.onGround = moveAxis(p, 0, p.vy * TICK) == 2
  if p.onGround then
    p.vy = 0
  end

  // lava / drown damage
  local feet = getTile(floor(p.x), floor(p.y))
  if feet == T.LAVA then
    damagePlayer(1)
  end

  // fell out of the world?
  if p.y > WORLD_H then
    damagePlayer(5)
  end

  // walk animation
  if ax != 0 and p.onGround then
    p.anim = p.anim + 1
  else
    p.anim = 0
  end

  if p.invuln > 0 then
    p.invuln = p.invuln - 1
  end

  // hotbar selection
  if keyboard.press.N1 then sel = 0 end
  if keyboard.press.N2 then sel = 1 end
  if keyboard.press.N3 then sel = 2 end
  if keyboard.press.N4 then sel = 3 end
  if keyboard.press.N5 then sel = 4 end
  if keyboard.press.N6 then sel = 5 end
  if keyboard.press.N7 then sel = 6 end
  if keyboard.press.N8 then sel = 7 end
  if keyboard.press.WHEELUP or keyboard.press.E then
    sel = (sel + 1) % 8
  end
  if keyboard.press.WHEELDOWN or keyboard.press.Q then
    sel = (sel + 7) % 8
  end

  // crafting menu
  if keyboard.press.C then
    if craftOpen then
      craftOpen = 0
    else
      craftOpen = 1
      craftSel = 0
      refreshCraftList()
    end
  end
  if craftOpen then
    if keyboard.press.UP or keyboard.press.W then
      craftSel = max(0, craftSel - 1)
    end
    if keyboard.press.DOWN or keyboard.press.S then
      craftSel = min(craftList.length - 1, craftSel + 1)
    end
    if keyboard.press.SPACE or keyboard.press.ENTER then
      doCraft()
    end
    return 0
  end

  // mining and placing use the mouse-adjacent tile in facing direction
  aimTile = function()
    local tx = floor(p.x) + p.dir
    local ty = floor(p.y)
    if keyboard.UP then
      ty = ty - 1
      tx = floor(p.x)
    end
    if keyboard.DOWN then
      ty = ty + 1
      tx = floor(p.x)
    end
    return [tx, ty]
  end

  // mining: hold X or mouse button
  if keyboard.X or mouse.pressed then
    local a = aimTile()
    if a[0] != p.miningX or a[1] != p.miningY then
      p.miningX = a[0]
      p.miningY = a[1]
      p.miningProg = 0
    end
    mineTick(a[0], a[1])
  else
    p.miningX = -1
    p.miningY = -1
    p.miningProg = 0
  end

  // placing: tap Z
  if keyboard.press.Z then
    local a = aimTile()
    placeTile(a[0], a[1])
  end
end

// returns 0 = no move, 1 = moved, 2 = landed on ground
moveAxis = function(p, dx, dy)
  local moved = 0
  if dx != 0 then
    local nx = p.x + dx
    // check the two feet/head corners
    local x0 = floor(nx - 0.3)
    local x1 = floor(nx + 0.3)
    local y0 = floor(p.y)
    local y1 = floor(p.y - 0.99)
    local hit = 0
    if isSolid(getTile(x0, y0)) or isSolid(getTile(x0, y1)) then
      hit = 1
    end
    if isSolid(getTile(x1, y0)) or isSolid(getTile(x1, y1)) then
      hit = 1
    end
    if hit == 0 then
      p.x = nx
      moved = 1
    end
  end
  if dy != 0 then
    // player is ~1 tile tall: body spans floor(ny-0.99)..floor(ny)
    local ny = p.y + dy
    local y0 = floor(ny)
    local y1 = floor(ny - 0.99)
    local x0 = floor(p.x - 0.3)
    local x1 = floor(p.x + 0.3)
    local hit = 0
    if isSolid(getTile(x0, y0)) or isSolid(getTile(x1, y0)) then
      hit = 2
    end
    if isSolid(getTile(x0, y1)) or isSolid(getTile(x1, y1)) then
      hit = max(hit, 1)
    end
    if hit == 0 then
      p.y = ny
      moved = 1
    else
      return hit
    end
  end
  return moved
end

damagePlayer = function(n)
  if player.invuln > 0 then
    return 0
  end
  player.hp = player.hp - n
  player.invuln = 60
  playSfx(52, 200, 60)
  if player.hp <= 0 then
    G.deathCount = G.deathCount + 1
    G.scene = "dead"
    msg = "YOU DIED"
  end
  return 1
end

// mining one aim tile: progress accumulates each frame while held
mineTick = function(tx, ty)
  local t = getTile(tx, ty)
  if t == T.AIR then
    return 0
  end
  local ti = TILES[t]
  if ti.hard >= 99 then
    return 0
  end
  local tool = toolPower(slotItem(sel))
  if ti.hard > tool then
    if player.miningProg == 0 then
      msg = "NEED BETTER PICK"
      msgTimer = 60
    end
    return 0
  end
  player.miningProg = player.miningProg + 1
  // mining speed: hardness 0 = 12 frames, 1 = 30, 2 = 60, 3 = 100
  local need = 12 + ti.hard * 24
  if player.miningProg >= need then
    // break it
    setTile(tx, ty, T.AIR)
    buildSurfaceCache()
    if ti.drop > 0 then
      giveItem(ti.drop, 1)
    end
    spawnParticles(tx + 0.5, ty + 0.5, ti.main)
    playSfx(48 + randInt(12), 60, 40)
    player.miningProg = 0
  end
  return 1
end

placeTile = function(tx, ty)
  local id = slotItem(sel)
  if id == 0 then
    return 0
  end
  // can't place inside the player (the player occupies one tile row)
  local px = floor(player.x)
  local py = floor(player.y)
  if tx == px and ty == py then
    return 0
  end
  if getTile(tx, ty) != T.AIR then
    return 0
  end
  // must touch an existing tile (no floating placement)
  if isSolid(getTile(tx - 1, ty)) == 0 and isSolid(getTile(tx + 1, ty)) == 0 and
     isSolid(getTile(tx, ty - 1)) == 0 and isSolid(getTile(tx, ty + 1)) == 0 and
     getTile(tx - 1, ty) != T.LADDER and getTile(tx + 1, ty) != T.LADDER and
     getTile(tx, ty + 1) != T.LADDER then
    return 0
  end
  // only placeable things: tiles + torch (not tools/ores as items)
  if id < 200 and id != T.COAL and id != T.IRON and id != T.GOLD and id != T.DIAMOND and id != T.BEDROCK then
    takeItem(id, 1)
    setTile(tx, ty, id)
    buildSurfaceCache()
    playSfx(79, 50, 40)
    return 1
  end
  return 0
end

updateMobs = function()
  local i = 0
  while i < mobs.length
    local m = mobs[i]
    // hop toward the player occasionally
    m.anim = m.anim + 1
    if m.y > WORLD_H then
      m.hp = 0
    end
    if m.hp <= 0 then
      mobs.splice(i, 1)
    else
      // gravity + wander
      m.vy = m.vy + GRAVITY * TICK
      local moved = moveAxisMob(m, 0, m.vy * TICK)
      if moved == 2 then
        m.vy = 0
        // hop
        if random.next() < 0.01 then
          m.vy = -8
          m.vx = randInt(3) - 1
        end
      end
      moveAxisMob(m, m.vx * TICK, 0)
      // touch damage
      local dx = abs(m.x - player.x)
      local dy = abs(m.y - player.y)
      if dx < 0.8 and dy < 1 then
        if damagePlayer(1) then
          player.vx = sgn(player.x - m.x) * 6
          player.vy = -6
        end
      end
      i = i + 1
    end
  end
end

// simpler collision for mobs (single point)
moveAxisMob = function(m, dx, dy)
  local res = 0
  if dx != 0 then
    local nx = m.x + dx
    if isSolid(getTile(floor(nx), floor(m.y))) == 0 then
      m.x = nx
    else
      res = 1
    end
  end
  if dy != 0 then
    local ny = m.y + dy
    if isSolid(getTile(floor(m.x), floor(ny))) == 0 then
      m.y = ny
    else
      return 2
    end
  end
  return res
end

updateParticles = function()
  local keep = []
  local i = 0
  while i < particles.length
    local pt = particles[i]
    pt.life = pt.life - 1
    if pt.life > 0 then
      pt.x = pt.x + pt.vx * TICK
      pt.y = pt.y + pt.vy * TICK
      pt.vy = pt.vy + GRAVITY * 0.5 * TICK
      keep.push(pt)
    end
    i = i + 1
  end
  particles = keep
end

spawnParticles = function(x, y, col)
  local i = 0
  while i < 5
    particles.push(object
      x = x
      y = y
      vx = (random.next() - 0.5) * 4
      vy = -random.next() * 4
      life = 15 + randInt(10)
      col = col
    end)
    i = i + 1
  end
end

updateCamera = function()
  // keep the player around the center of the 40x25 view
  local targetX = player.x - COLS / 2 + 0.5
  local targetY = player.y - ROWS / 2 + 1
  camX = clamp(targetX, 0, WORLD_W - COLS)
  camY = clamp(targetY, 0, WORLD_H - ROWS)
end

updateMining = function()
  // mining progress is handled in updatePlayer; nothing else here
  return 0
end

// --------------------------- drawing -------------------------------

draw = function()
  screen.setTranslation(0, 0)
  screen.setScale(1, 1)
  screen.setAlpha(1)
  // clear the border to C64 black first
  screen.clear(C64[CR.BLACK])
  if G.scene == "title" then
    drawTitle()
    return 0
  end
  // world + entities into the cell framebuffer
  worldToCell()
  drawEntities()
  drawHUD()
  if G.scene == "dead" then
    drawDead()
  end
  blitCells()
end

drawTitle = function()
  cellClear(0, 0, 0)
  // big blocky title using overlay text (ink 0 = transparent)
  cellOverlayTextC(20, 6, "MINE DEMAKE '64", CR.YELLOW, -1)
  cellOverlayTextC(20, 8, "A C64-STYLE MINING GAME", CR.LTGRN, -1)
  cellOverlayTextC(20, 10, "ARROWS/WASD MOVE  X MINE", CR.WHITE, -1)
  cellOverlayTextC(20, 11, "Z PLACE  C CRAFT  E/Q SLOT", CR.WHITE, -1)
  cellOverlayTextC(20, 13, "PRESS SPACE TO START", CR.CYAN, -1)
  if floor(G.time / 30) % 2 == 0 then
    cellOverlayTextC(20, 16, "INSERT COIN", CR.LTRED, -1)
  end
  // decorative tile strip at the bottom
  local x = 0
  while x < COLS
    cellPut(x, 22, GL.stone, CR.DKGRY, CR.MDGRY, 3)
    cellPut(x, 23, GL.dirt, CR.BROWN, -1, 3)
    cellPut(x, 24, GL.grass, CR.GREEN, CR.BROWN, 3)
    x = x + 1
  end
  blitCells()
end

drawEntities = function()
  // player: choose glyph by state
  local p = player
  local g = GL.player_r0
  if p.climbing then
    g = GL.player_climb
  elsif p.onGround == 0 then
    if p.dir > 0 then
      g = GL.player_jump
    else
      g = GL.player_ljump
    end
  else
    local frame = floor(p.anim / 8) % 4
    if p.dir > 0 then
      g = GL.player_r0 + frame
    else
      g = GL.player_l0 + frame
    end
  end
  // blink while invulnerable
  if p.invuln > 0 and floor(G.time / 4) % 2 == 0 then
    g = -1
  end
  local cx = floor(p.x - camX)
  local cy = floor(p.y - camY) - 1   // -1: player is 1 tall visually? full cell
  cellOverlay(cx, cy, g, CR.BLUE, CR.LTRED, 3)

  // mining crack overlay
  if p.miningX >= 0 and p.miningProg > 0 then
    local need = 12
    local t = getTile(p.miningX, p.miningY)
    if t > 0 then
      need = 12 + TILES[t].hard * 24
    end
    local stage = floor(p.miningProg / need * 4)
    if stage > 3 then
      stage = 3
    end
    local mcx = floor(p.miningX - camX)
    local mcy = floor(p.miningY - camY)
    if stage > 0 then
      cellOverlay(mcx, mcy, GL.crack1 + stage - 1, CR.WHITE, -1, 3)
    end
  end

  // mobs
  local i = 0
  while i < mobs.length
    local m = mobs[i]
    local frame = floor(m.anim / 20) % 3
    local mx = floor(m.x - camX)
    local my = floor(m.y - camY) - 1
    cellOverlay(mx, my, GL.slime0 + frame, CR.GREEN, CR.LTGRN, 3)
    i = i + 1
  end

  // particles (single fat pixels)
  local q = 0
  while q < particles.length
    local pt = particles[q]
    local px = floor(pt.x - camX)
    local py = floor(pt.y - camY)
    if px >= 0 and px < COLS and py >= 0 and py < ROWS then
      // draw as a tiny overlay glyph: a 1-px dot
      cellOverlay(px, py, GL.sparkle, pt.col, -1, 3)
    end
    q = q + 1
  end
end

drawHUD = function()
  // hearts row (top-left) on the overlay layer
  local h = 0
  while h < player.maxHp
    local g = GL.heartfull
    if h >= player.hp then
      g = GL.heartempty
    end
    cellOverlay(1 + h, 1, g, CR.RED, -1, null)
    h = h + 1
  end

  // hotbar (bottom)
  local n = 0
  while n < 8
    local id = slotItem(n)
    local g = 0
    local main = CR.DKGRY
    local accent = -1
    if id != 0 then
      local it = ITEMS[id]
      if it then
        g = it.glyph
        main = it.main
        accent = it.accent
      end
    end
    // slot background (base layer, solid dark gray cell)
    cellPut(16 + n * 2, ROWS - 1, 0, CR.DKGRY, -1, 3)
    cellSetBg(16 + n * 2, ROWS - 1, CR.DKGRY)
    if n == sel then
      // selected slot: lighter background + white arrow above it
      cellSetBg(16 + n * 2, ROWS - 1, CR.MDGRY)
      cellOverlay(16 + n * 2, ROWS - 2, GL.arrowdn, CR.WHITE, -1, null)
    end
    if id != 0 then
      cellOverlay(16 + n * 2, ROWS - 1, g, main, accent, null)
    end
    n = n + 1
  end

  // message line
  if msgTimer > 0 then
    cellOverlayTextC(20, 3, msg, CR.YELLOW, -1)
  end

  // depth meter (right side)
  local depth = max(0, floor(player.y - surfaceCache[floor(player.x)]))
  cellOverlayText(COLS - 7, 1, "D" + depth + "M", CR.LTGRN, -1)

  // crafting menu
  if craftOpen then
    drawCraftMenu()
  end
end

drawCraftMenu = function()
  // panel: 22 wide, up to 10 rows, drawn as a solid blue field on the
  // base layer with overlay text on top
  local px0 = 9
  local py0 = 5
  local w = 22
  local h = 3 + craftList.length
  if h > 14 then
    h = 14
  end
  local y = py0
  while y < py0 + h
    local x = px0
    while x < px0 + w
      cellPut(x, y, 0, CR.PURPLE, -1, 3)
      cellSetBg(x, y, CR.PURPLE)
      x = x + 1
    end
    y = y + 1
  end
  cellOverlayText(px0 + 2, py0 + 1, "== CRAFT ==", CR.YELLOW, -1)
  local i = 0
  while i < craftList.length and i < 10
    local r = craftList[i]
    local col = CR.WHITE
    if i == craftSel then
      col = CR.YELLOW
    end
    cellOverlayText(px0 + 1, py0 + 3 + i, " " + itemName(r.out), col, -1)
    i = i + 1
  end
  if craftList.length == 0 then
    cellOverlayText(px0 + 1, py0 + 3, " NOTHING CRAFTABLE", CR.LTGRN, -1)
  end
  cellOverlayText(px0 + 1, py0 + h - 1, " SPACE=CRAFT C=CLOSE", CR.LTGRN, -1)
end

drawDead = function()
  // darken the whole framebuffer by shading every cell
  local i = 0
  while i < COLS * ROWS
    if cellLight[i] > 0 then
      cellLight[i] = cellLight[i] - 1
    end
    i = i + 1
  end
  cellOverlayTextC(20, 11, "YOU DIED", CR.RED, -1)
  cellOverlayTextC(20, 13, "PRESS SPACE TO RETRY", CR.WHITE, -1)
end
