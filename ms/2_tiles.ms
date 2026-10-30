// =====================================================================
// C64 MINE DEMAKE - 2_tiles.ms
// Block, item and recipe definitions. Pure data: add a new block by
// adding one entry here, then draw its glyph in the charROM (see
// tools/genchars.py or the charrom sprite) and pick colors.
// ---------------------------------------------------------------------
// tile = object
//   id     = unique number (0 = air)
//   glyph  = GL.* charROM index for the cell
//   main   = "main" ink color RAM index (ink 3)
//   accent = "accent" ink color RAM index (ink 2), -1 = same as main
//   solid  = 1 when the player collides with it
//   hard   = 0..3 mining resistance; 3 needs an iron pick
//   drop   = item id you get when mined
//   light  = 0..3 emitted light level (torch = 3)
//   liquid = 1 for water/lava
//   bg     = 1 when it should render as sky (air above ground)
// =====================================================================

// tile ids
T = object
  AIR = 0
  GRASS = 1
  DIRT = 2
  STONE = 3
  BEDROCK = 4
  SAND = 5
  GRAVEL = 6
  COAL = 7
  IRON = 8
  GOLD = 9
  DIAMOND = 10
  WOOD = 11
  LEAVES = 12
  PLANKS = 13
  TORCH = 14
  CRAFT = 15
  LADDER = 16
  WATER = 17
  LAVA = 18
end

// item ids (>= 200 to never collide with tiles)
I = object
  NONE = 0
  STICK = 200
  COAL = 201
  IRON = 202
  GOLD = 203
  DIAMOND = 204
  PICK_WOOD = 210
  PICK_STONE = 211
  PICK_IRON = 212
  SWORD_WOOD = 213
  SWORD_IRON = 214
  DIRT = 2
  STONE = 3
  SAND = 5
  GRAVEL = 6
  WOOD = 11
  LEAVES = 12
  PLANKS = 13
  TORCH = 14
  CRAFT = 15
  LADDER = 16
end

TILES = []

// NOTE: in microScript 2.0, 0 == null is TRUE (verified against the VM),
// so "if def.hard == null" would also catch hard = 0. Every tiledef below
// therefore sets ALL fields explicitly; this function only fills in a
// display name when missing.
tiledef = function(def)
  if def.name == 0 then
    def.name = "?"
  end
  TILES.push(def)
end

// Populates TILES and ITEMS. Called from init() (in 5_game.ms) so the
// data tables are only built once ALL source files are loaded -
// microStudio runs source files in network-arrival order, so
// top-level calls here could run before 0_core/1_charset define
// T, I, GL and CR.
defineTiles = function()
  TILES = []
  ITEMS = object
  end
  tiledef(object
    id = T.AIR
    name = "air"
    glyph = 0
    main = CR.BLACK
    accent = -1
    solid = 0
    hard = 1
    drop = 0
    light = 0
    liquid = 0
    climb = 0
    bg = 1
  end)
  tiledef(object
    id = T.GRASS
    name = "grass"
    glyph = GL.grass
    main = CR.GREEN
    accent = CR.BROWN
    solid = 1
    hard = 0
    drop = T.DIRT
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.DIRT
    name = "dirt"
    glyph = GL.dirt
    main = CR.BROWN
    accent = -1
    solid = 1
    hard = 0
    drop = T.DIRT
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.STONE
    name = "stone"
    glyph = GL.stone
    main = CR.DKGRY
    accent = CR.MDGRY
    solid = 1
    hard = 1
    drop = T.STONE
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.BEDROCK
    name = "bedrock"
    glyph = GL.bedrock
    main = CR.DKGRY
    accent = CR.BLACK
    solid = 1
    hard = 99
    drop = 0
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.SAND
    name = "sand"
    glyph = GL.sand
    main = CR.YELLOW
    accent = CR.BROWN
    solid = 1
    hard = 0
    drop = T.SAND
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.GRAVEL
    name = "gravel"
    glyph = GL.gravel
    main = CR.MDGRY
    accent = CR.DKGRY
    solid = 1
    hard = 1
    drop = T.GRAVEL
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.COAL
    name = "coal ore"
    glyph = GL.coal
    main = CR.DKGRY
    accent = CR.BLACK
    solid = 1
    hard = 2
    drop = I.COAL
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.IRON
    name = "iron ore"
    glyph = GL.iron
    main = CR.DKGRY
    accent = CR.WHITE
    solid = 1
    hard = 2
    drop = I.IRON
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.GOLD
    name = "gold ore"
    glyph = GL.gold
    main = CR.DKGRY
    accent = CR.YELLOW
    solid = 1
    hard = 3
    drop = I.GOLD
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.DIAMOND
    name = "diamond ore"
    glyph = GL.diamond
    main = CR.DKGRY
    accent = CR.CYAN
    solid = 1
    hard = 3
    drop = I.DIAMOND
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.WOOD
    name = "wood"
    glyph = GL.wood
    main = CR.BROWN
    accent = CR.DKBRN
    solid = 1
    hard = 0
    drop = T.WOOD
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.LEAVES
    name = "leaves"
    glyph = GL.leaves
    main = CR.GREEN
    accent = CR.LTGRN
    solid = 1
    hard = 0
    drop = I.STICK
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.PLANKS
    name = "planks"
    glyph = GL.planks
    main = CR.LTRED
    accent = CR.BROWN
    solid = 1
    hard = 0
    drop = T.PLANKS
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.TORCH
    name = "torch"
    glyph = GL.torch
    main = CR.BROWN
    accent = CR.YELLOW
    solid = 0
    hard = 0
    drop = T.TORCH
    light = 3
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.CRAFT
    name = "crafting table"
    glyph = GL.craft
    main = CR.LTRED
    accent = CR.BROWN
    solid = 1
    hard = 0
    drop = T.CRAFT
    light = 0
    liquid = 0
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.LADDER
    name = "ladder"
    glyph = GL.ladder
    main = CR.BROWN
    accent = -1
    solid = 0
    hard = 0
    drop = T.LADDER
    light = 0
    liquid = 0
    climb = 1
    bg = 0
  end)
  tiledef(object
    id = T.WATER
    name = "water"
    glyph = GL.water0
    main = CR.BLUE
    accent = CR.LTBLU
    solid = 0
    hard = 99
    drop = 0
    light = 0
    liquid = 1
    climb = 0
    bg = 0
  end)
  tiledef(object
    id = T.LAVA
    name = "lava"
    glyph = GL.lava0
    main = CR.RED
    accent = CR.YELLOW
    solid = 0
    hard = 99
    drop = 0
    light = 3
    liquid = 1
    climb = 0
    bg = 0
  end)
  ITEMS = object
  end
  itemdef(I.STICK, "STICK", GL.i_stick, CR.BROWN, CR.DKBRN)
  itemdef(I.COAL, "COAL", GL.i_coal, CR.DKGRY, CR.BLACK)
  itemdef(I.IRON, "IRON", GL.i_iron, CR.MDGRY, CR.WHITE)
  itemdef(I.GOLD, "GOLD", GL.i_gold, CR.YELLOW, CR.BROWN)
  itemdef(I.DIAMOND, "DIAMOND", GL.i_diamond, CR.CYAN, CR.LTBLU)
  itemdef(I.PICK_WOOD, "WOOD PICK", GL.i_pick_wood, CR.LTRED, CR.BROWN)
  itemdef(I.PICK_STONE, "STONE PICK", GL.i_pick_stone, CR.MDGRY, CR.BROWN)
  itemdef(I.PICK_IRON, "IRON PICK", GL.i_pick_iron, CR.WHITE, CR.BROWN)
  itemdef(I.SWORD_WOOD, "WOOD SWORD", GL.i_sword_wood, CR.LTRED, CR.BROWN)
  itemdef(I.SWORD_IRON, "IRON SWORD", GL.i_sword_iron, CR.WHITE, CR.BROWN)
  itemdef(T.DIRT, "DIRT", GL.dirt, CR.BROWN, -1)
  itemdef(T.STONE, "STONE", GL.stone, CR.DKGRY, CR.MDGRY)
  itemdef(T.SAND, "SAND", GL.sand, CR.YELLOW, CR.BROWN)
  itemdef(T.GRAVEL, "GRAVEL", GL.gravel, CR.MDGRY, CR.DKGRY)
  itemdef(T.WOOD, "WOOD", GL.wood, CR.BROWN, CR.DKBRN)
  itemdef(T.LEAVES, "LEAVES", GL.leaves, CR.GREEN, CR.LTGRN)
  itemdef(T.PLANKS, "PLANKS", GL.planks, CR.LTRED, CR.BROWN)
  itemdef(T.TORCH, "TORCH", GL.torch, CR.BROWN, CR.YELLOW)
  itemdef(T.CRAFT, "CRAFTING", GL.craft, CR.LTRED, CR.BROWN)
  itemdef(T.LADDER, "LADDER", GL.ladder, CR.BROWN, -1)
end

// ---- helpers (top level: safe in any load order) ----
// fast lookup: tile id -> definition
tileInfo = function(id)
  return TILES[id]
end
isSolid = function(id)
  if id == 0 then
    return 0
  end
  if id >= TILES.length then
    return 0
  end
  return TILES[id].solid
end
// -------------------------- items --------------------------
itemdef = function(id, name, glyph, main, accent)
  ITEMS[id] = object
    id = id
    name = name
    glyph = glyph
    main = main
    accent = accent
  end
end

// Pickaxe power: which ore hardness each tool can mine.
// hand=0 -> hardness 0 only; wood pick=1 -> up to 1; iron pick=2 -> all
toolPower = function(itemId)
  if itemId == I.PICK_IRON then
    return 3
  elsif itemId == I.PICK_STONE then
    return 2
  elsif itemId == I.PICK_WOOD then
    return 1
  end
  return 0
end

// ------------------------- crafting -------------------------

// recipe = object
//   out = item id produced, count = how many
//   need = list of [itemId, count] pairs
//   station = 1 when a crafting table must be nearby
RECIPES = []

recipedef = function(out, count, need, station)
  RECIPES.push(object
    out = out
    count = count
    need = need
    station = station
  end)
end

// item name helper for HUD/menus
itemName = function(id)
  local it = ITEMS[id]
  if it then
    return it.name
  end
  if id > 0 and id < TILES.length then
    return TILES[id].name
  end
  return "?"
end

// (recipes defined in 5_game.ms after inventory helpers exist)
