// =====================================================================
// C64 MINE DEMAKE - 3_world.ms
// World storage, procedural generation and lighting.
//
// The world is WORLD_W x WORLD_H tiles. Each tile is a number (tile id).
// world[row] is a list of WORLD_W numbers; row 0 = the sky row, larger
// rows go DOWN (screen-like, not math-like).
// =====================================================================

world = []
worldSeed = 1

// sky scroll offset (px) for sun/clouds/stars
skyScroll = 0

// lighting: per-tile light 0..3; recomputed on demand
lightMap = []
lightDirty = 1

initWorld = function(seed)
  worldSeed = seed
  world = []
  lightMap = []
  for y = 0 to WORLD_H - 1
    local row = []
    local lrow = []
    for x = 0 to WORLD_W - 1
      row.push(T.AIR)
      lrow.push(0)
    end
    world.push(row)
    lightMap.push(lrow)
  end
  genTerrain()
  lightDirty = 1
end

// ----------------------- terrain generation -----------------------

genTerrain = function()
  local s = worldSeed

  // 1) height map: layered smooth noise, flat enough to walk on
  local heights = []
  for x = 0 to WORLD_W - 1
    local h = 0
    h = h + smoothNoise(x * 0.03, s) * 10
    h = h + smoothNoise(x * 0.09, s + 7) * 5
    h = h + smoothNoise(x * 0.25, s + 13) * 2
    local hy = 24 + floor(h) - 8
    heights.push(hy)
  end
  // 2) biome map: 0 normal, 1 desert (sand), 2 mountain (stone)
  local biomes = []
  for x = 0 to WORLD_W - 1
    local b = smoothNoise(x * 0.02, s + 31)
    if b > 0.72 then
      biomes.push(1)
    elsif b < 0.22 then
      biomes.push(2)
    else
      biomes.push(0)
    end
  end
  local x = 0
  while x < WORLD_W
    // widen biome patches: at least 12 tiles
    local b = biomes[x]
    local run = 1
    while x + run < WORLD_W and biomes[x + run] == b and run < 12
      run = run + 1
    end
    for i = 0 to run - 1
      if x + i < WORLD_W then
        biomes[x + i] = b
      end
    end
    x = x + run
  end

  // 3) fill columns
  for x = 0 to WORLD_W - 1
    local hy = heights[x]
    local b = biomes[x]
    for y = 0 to WORLD_H - 1
      local t = T.AIR
      if y == WORLD_H - 1 then
        t = T.BEDROCK
      elsif y >= hy + 18 then
        t = T.STONE
      elsif y >= hy + 3 then
        if b == 1 then
          t = T.SAND
        else
          t = T.DIRT
        end
      elsif y >= hy then
        if b == 1 then
          t = T.SAND
        elsif b == 2 and y == hy then
          t = T.STONE
        else
          t = T.GRASS
        end
      end
      world[y][x] = t
    end
    // desert: sand down deeper
    if b == 1 then
      for y = hy to min(hy + 5, WORLD_H - 2)
        world[y][x] = T.SAND
      end
    end
  end

  // 4) caves: cellular noise blobs in stone/dirt region
  for cy = 30 to WORLD_H - 4
    for x = 2 to WORLD_W - 3
      local n = noise1(x * 7.13 + cy * 3.7, s + 99)
      local n2 = noise1(x * 3.1 + cy * 11.7, s + 55)
      if n > 0.78 or n2 > 0.93 then
        if world[cy][x] != T.BEDROCK then
          world[cy][x] = T.AIR
        end
      end
    end
  end
  // carve short horizontal tunnels so caves connect
  local tunnels = 12
  for i = 1 to tunnels
    local tx = randInt(WORLD_W - 8) + 4
    local ty = 34 + randInt(WORLD_H - 40)
    local len = 8 + randInt(20)
    local dir = 1
    if random.next() < 0.5 then
      dir = -1
    end
    for j = 0 to len
      local px = tx + dir * j
      if px > 1 and px < WORLD_W - 2 and ty > 1 and ty < WORLD_H - 2 then
        if world[ty][px] != T.BEDROCK and world[ty][px] != T.WATER then
          world[ty][px] = T.AIR
        end
        // slight vertical wobble
        if random.next() < 0.3 then
          local wy = ty + randInt(2)
          if wy > 1 and wy < WORLD_H - 2 and px > 1 and px < WORLD_W - 2 then
            if world[wy][px] != T.BEDROCK and world[wy][px] != T.WATER then
              world[wy][px] = T.AIR
            end
          end
        end
      end
    end
  end

  // 5) ore veins (in stone only)
  placeVein = function(id, count, y0, y1, size)
    for i = 1 to count
      local vx = randInt(WORLD_W - 2) + 1
      local vy = y0 + randInt(y1 - y0)
      for j = 0 to size - 1
        local ox = vx + randInt(3) - 1
        local oy = vy + randInt(3) - 1
        if ox > 0 and ox < WORLD_W - 1 and oy > 0 and oy < WORLD_H - 1 then
          if world[oy][ox] == T.STONE then
            world[oy][ox] = id
          end
        end
      end
    end
  end
  placeVein(T.COAL, 40, 26, WORLD_H - 4, 6)
  placeVein(T.IRON, 26, 30, WORLD_H - 4, 5)
  placeVein(T.GOLD, 10, 40, WORLD_H - 4, 3)
  placeVein(T.DIAMOND, 6, 46, WORLD_H - 3, 2)
  placeVein(T.GRAVEL, 18, 28, WORLD_H - 6, 8)

  // 6) water pools: fill cave air pockets below sky level with water
  //    (simple flood from the bottom of caves up to a random level)
  local pools = 8
  for i = 1 to pools
    local px = randInt(WORLD_W - 10) + 5
    // find a cave air tile in mid depths
    local found = 0
    local py = 0
    for y = 32 to WORLD_H - 6
      if world[y][px] == T.AIR and world[y + 1][px] != T.AIR then
        py = y
        found = 1
        break
      end
    end
    if found then
      local depth = 1 + randInt(2)
      for y = py to py + depth - 1
        for x2 = max(0, px - 2) to min(WORLD_W - 1, px + 2)
          if world[y][x2] == T.AIR then
            world[y][x2] = T.WATER
          end
        end
      end
    end
  end

  // 7) lava lake at the bottom
  for y = WORLD_H - 4 to WORLD_H - 2
    for x = 1 to WORLD_W - 2
      if world[y][x] == T.AIR then
        world[y][x] = T.LAVA
      end
    end
  end

  // 8) trees on grass
  local x2 = 3
  while x2 < WORLD_W - 3
    local hy = heights[x2]
    if biomes[x2] == 0 and world[hy][x2] == T.GRASS then
      if random.next() < 0.25 then
        local th = 2 + randInt(2)
        for ty2 = hy - th to hy - 1
          world[ty2][x2] = T.WOOD
        end
        // canopy
        for dy = -1 to 0
          for dx = -2 to 2
            local lx = x2 + dx
            local ly = hy - th + dy - 1
            if lx > 0 and lx < WORLD_W - 1 and ly > 0 then
              if world[ly][lx] == T.AIR then
                world[ly][lx] = T.LEAVES
              end
            end
          end
        end
        world[hy - th - 2][x2] = T.LEAVES
        x2 = x2 + 3
      end
    end
    x2 = x2 + 1
  end

  // 9) a few surface torches near spawn for a warm start
  for i = 1 to 3
    local tx2 = WORLD_W / 2 + randInt(9) - 4
    local hy2 = heights[tx2]
    if world[hy2 - 1][tx2] == T.AIR then
      world[hy2 - 1][tx2] = T.TORCH
    end
  end
end

// ------------------------- world access --------------------------

getTile = function(x, y)
  if x < 0 or x >= WORLD_W or y < 0 or y >= WORLD_H then
    return T.BEDROCK
  end
  if world.length == 0 then
    return T.AIR
  end
  return world[y][x]
end

setTile = function(x, y, t)
  if x < 0 or x >= WORLD_W or y < 0 or y >= WORLD_H then
    return 0
  end
  world[y][x] = t
  lightDirty = 1
  return 1
end

// -------------------------- lighting ------------------------------

// Light levels 0..3. Sky tiles above ground are lit by the sun.
// Light sources (torches, lava) push light into neighbors, decreasing
// by 1 per tile. Recompute only when something changed (lightDirty).
worldReady = function()
  // lightMap rows are built by initWorld; if it has not run yet
  // (e.g. after a live reload, before init() rebuilds the world),
  // lighting must not touch it
  return lightMap.length == WORLD_H
end

computeLight = function()
  if lightDirty == 0 then
    return 0
  end
  if worldReady() == 0 then
    return 0
  end
  lightDirty = 0
  local queue = []
  for y = 0 to WORLD_H - 1
    for x = 0 to WORLD_W - 1
      local l = 0
      local t = world[y][x]
      local ti = TILES[t]
      if ti.light > 0 then
        l = ti.light
      end
      // ambient sun light applies to every tile by depth
      l = max(l, ambientLight(x, y))
      lightMap[y][x] = l
      if l > 0 then
        queue.push(x)
        queue.push(y)
        queue.push(l)
      end
    end
  end
  // BFS spread
  local qi = 0
  while qi < queue.length
    local x = queue[qi]
    local y = queue[qi + 1]
    local l = queue[qi + 2]
    qi = qi + 3
    if l > 1 then
      local nl = l - 1
      // 4 neighbors
      if x > 0 then
        if lightMap[y][x - 1] < nl then
          lightMap[y][x - 1] = nl
          queue.push(x - 1)
          queue.push(y)
          queue.push(nl)
        end
      end
      if x < WORLD_W - 1 then
        if lightMap[y][x + 1] < nl then
          lightMap[y][x + 1] = nl
          queue.push(x + 1)
          queue.push(y)
          queue.push(nl)
        end
      end
      if y > 0 then
        if lightMap[y - 1][x] < nl then
          lightMap[y - 1][x] = nl
          queue.push(x)
          queue.push(y - 1)
          queue.push(nl)
        end
      end
      if y < WORLD_H - 1 then
        if lightMap[y + 1][x] < nl then
          lightMap[y + 1][x] = nl
          queue.push(x)
          queue.push(y + 1)
          queue.push(nl)
        end
      end
    end
  end
  return 1
end

// Ambient (sun) light by DEPTH relative to the surface column:
// everything above/at the surface is fully lit (3); below the surface the
// light fades over a few rows (3 -> 2 -> 1 -> 0) so shallow ground is
// visible while deep caves stay black until torch-lit. Depth-based (not
// sky-access-based) so hillside walls and areas under tree canopies are
// lit too, and shallow cave mouths glow.
ambientLight = function(x, y)
  local s = surfaceCache[x]
  local d = y - s
  if d < 0 then
    return 3
  end
  // d = 0..2 -> 3, 3..5 -> 2, 6..8 -> 1, 9+ -> 0
  local a = 3 - floor(d / 3)
  if a < 0 then
    a = 0
  end
  return a
end

getLight = function(x, y)
  if x < 0 or x >= WORLD_W or y < 0 or y >= WORLD_H then
    return 0
  end
  if lightMap.length == 0 then
    return 0
  end
  return lightMap[y][x]
end
