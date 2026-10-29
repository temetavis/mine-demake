// Gameplay scenario test - seed-agnostic: uses the game's own functions
// (mineTick, placeTile, crafting, damage) at known coordinates, plus
// keyboard-driven physics that doesn't depend on world layout.

const { MsRunner } = require("../tools/msrun");

const r = new MsRunner({});
r.loadSources();
r.start();
const g = r.env.globalObj;

let failures = 0;
const check = (cond, label) => {
  console.log(`${cond ? "PASS" : "FAIL"}: ${label}`);
  if (!cond) failures++;
};

const call = (name, ...args) => r.fn(name)(...args);

// start the game
r.env.keyboard.SPACE = 1; r.env.keyboard.press.SPACE = 1;
r.frame();
r.env.keyboard.press.SPACE = 0; r.env.keyboard.SPACE = 0;
check(g.G.scene === "play", "game starts in play scene");
check(g.inv.some((s) => s.id === 210), "starts with wood pick");
check(g.inv.some((s) => s.id === 14 && s.count === 5), "starts with 5 torches");

// find a flat spawn area and clear 3x4 of air with floor for the tests
const px = Math.floor(g.player.x);
const py = Math.floor(g.player.y);
const TX = 200; // test area away from spawn, in column 200
// clear area (rows above the floor too - the player is ~1 tile tall,
// so the head row must be air as well)
for (let y = 26; y <= 33; y++) for (let x = TX - 1; x <= TX + 2; x++) call("setTile", x, y, 0);
for (let x = TX - 1; x <= TX + 2; x++) call("setTile", x, 34, 3); // stone floor
call("buildSurfaceCache");
// teleport player into the test area, then settle until onGround
g.player.x = TX + 0.5;
g.player.y = 30;
g.player.vx = 0; g.player.vy = 0;
let settled = 0;
for (let i = 0; i < 120 && !settled; i++) {
  r.frame();
  if (g.player.onGround === 1 && Math.abs(g.player.vy) < 0.01) settled = i;
}
check(g.player.onGround === 1, `player stands on placed floor (y=${g.player.y.toFixed(2)})`);

// ---- mining: put dirt in front, mine it ----
call("setTile", TX + 1, 32, 2); // dirt at head/body level in front
check(call("mineTick", TX + 1, 32) === 1, "mineTick progresses on dirt");
for (let i = 0; i < 12; i++) call("mineTick", TX + 1, 32);
check(g.world[32][TX + 1] === 0, "dirt mined to air after 13 ticks");
check(g.inv.some((s) => s.id === 2), "dirt added to inventory");

// hardness gate: diamond ore needs iron pick (tool power 3)
call("setTile", TX + 1, 32, 10); // diamond ore
g.player.miningProg = 0;
const selSave = g.sel;
// hand selected (slot with dirt) -> toolPower 0, hardness 3 -> no progress
const minedHard = call("mineTick", TX + 1, 32);
check(minedHard === 0 && g.world[32][TX + 1] === 10, "diamond NOT minable without iron pick");

// with iron pick: craftable check happens later; place iron pick in inventory and select
call("giveItem", 212, 1); // iron pick
const ipIdx = g.inv.findIndex((s) => s.id === 212);
g.sel = Math.min(ipIdx, 7);
for (let i = 0; i < 130; i++) call("mineTick", TX + 1, 32);
check(g.world[32][TX + 1] === 0, "diamond minable with iron pick");
check(g.inv.some((s) => s.id === 204), "diamond item collected");
g.sel = selSave;

// ---- crafting flow (wood -> planks -> sticks -> table) ----
call("giveItem", 11, 2); // wood (2 wood -> 8 planks: enough for sticks + table)
call("refreshCraftList");
check(g.craftList.some((rc) => rc.out === 13), "planks recipe available with wood");
const pIdx = g.craftList.findIndex((rc) => rc.out === 13);
g.craftSel = pIdx;
call("doCraft");
check(g.inv.some((s) => s.id === 13 && s.count >= 4), "crafted 4 planks from 1 wood");

// craft the table FIRST (uses all 4 planks), then planks again for sticks
call("refreshCraftList");
const tIdx = g.craftList.findIndex((rc) => rc.out === 15);
check(tIdx >= 0, "crafting table recipe available");
g.craftSel = tIdx;
call("doCraft");
check(g.inv.some((s) => s.id === 15), "crafted crafting table");

// second wood -> planks -> sticks
call("refreshCraftList");
const pIdx2 = g.craftList.findIndex((rc) => rc.out === 13);
check(pIdx2 >= 0, "planks recipe still available (2nd wood)");
g.craftSel = pIdx2;
call("doCraft");
const sIdx = g.craftList.findIndex((rc) => rc.out === 200);
call("refreshCraftList");
const sIdx2 = g.craftList.findIndex((rc) => rc.out === 200);
check(sIdx2 >= 0, "sticks recipe available with planks");
g.craftSel = sIdx2;
call("doCraft");
check(g.inv.some((s) => s.id === 200), "crafted sticks");

// stone pick needs 3 stone + 2 sticks near a table
call("giveItem", 3, 3); // stone
call("refreshCraftList");
check(!g.craftList.some((rc) => rc.out === 210), "wood pick NOT craftable without table");
// place the table next to the player
const tableInvIdx = g.inv.findIndex((s) => s.id === 15);
g.sel = Math.min(tableInvIdx, 7);
const placed = call("placeTile", TX + 1, 33);
check(placed === 1 && g.world[33][TX + 1] === 15, "crafting table placed");
call("refreshCraftList");
check(g.craftList.some((rc) => rc.out === 211), "stone pick craftable near table (have stone+sticks)");
const spIdx = g.craftList.findIndex((rc) => rc.out === 211);
g.craftSel = spIdx;
call("doCraft");
check(g.inv.some((s) => s.id === 211), "crafted stone pick");

// ---- torch placement and lighting ----
const torchIdx = g.inv.findIndex((s) => s.id === 14);
g.sel = Math.min(torchIdx, 7);
const torchPlaced = call("placeTile", TX - 1, 32);
check(torchPlaced === 1 && g.world[32][TX - 1] === 14, "torch placed");
r.frame();
check(g.lightMap[32][TX - 1] === 3, "torch emits light 3");
check(g.lightMap[31][TX - 1] >= 2, "light spreads above torch");

// ---- physics: walk left along the floor (right side has the table) ----
r.env.keyboard.LEFT = 1;
const x0 = g.player.x;
for (let i = 0; i < 30; i++) r.frame();
r.env.keyboard.LEFT = 0;
check(g.player.x < x0 - 1, `player walks left (${(x0 - g.player.x).toFixed(1)} tiles)`);
check(g.player.onGround === 1, "player stays on ground while walking");

// jump (wait until settled on ground first)
let settle2 = 0;
for (let i = 0; i < 120 && !settle2; i++) {
  r.frame();
  if (g.player.onGround === 1 && Math.abs(g.player.vy) < 0.01) settle2 = 1;
}
const preJumpY = g.player.y;
r.env.keyboard.press.UP = 1;
for (let i = 0; i < 6; i++) r.frame();
r.env.keyboard.press.UP = 0;
const jumpY = g.player.y;
check(jumpY < preJumpY - 0.5, `player jumps (from ${preJumpY.toFixed(2)} to ${jumpY.toFixed(2)})`);
for (let i = 0; i < 60; i++) r.frame();
let landed = 0;
for (let i = 0; i < 120 && !landed; i++) {
  r.frame();
  if (g.player.onGround === 1 && Math.abs(g.player.vy) < 0.01) landed = 1;
}
check(landed === 1, "player lands after jump");

// ---- damage + death + restart ----
call("damagePlayer", 1);
check(g.player.hp === 4 && g.player.invuln > 0, "damage reduces hp, grants invulnerability");
// invulnerability blocks damage
call("damagePlayer", 1);
check(g.player.hp === 4, "invulnerability blocks damage");
g.player.invuln = 0;
call("damagePlayer", 99);
check(g.G.scene === "dead", "player dies at hp<=0");
r.env.keyboard.SPACE = 1; r.env.keyboard.press.SPACE = 1;
r.frame();
r.env.keyboard.press.SPACE = 0; r.env.keyboard.SPACE = 0;
check(g.G.scene === "play", "space restarts after death");
check(g.player.hp === 5, "player respawns at full hp");
// respawn also regenerates a fresh world
check(g.world.length === 64, "world regenerated on restart");
check(g.player.hp === 5, "player respawns at full hp");

// ---- mobs update without crashing; slime near player deals contact damage ----
const mCount = g.mobs.length;
check(mCount > 0, "mobs spawned");
if (g.mobs.length > 0) {
  const m0 = g.mobs[0];
  m0.x = g.player.x + 0.1;
  m0.y = g.player.y;
  g.player.invuln = 0;
  const hpBefore = g.player.hp;
  for (let i = 0; i < 5; i++) r.frame();
  check(g.player.hp === hpBefore - 1 || g.player.invuln > 0, "slime contact damages player");
} else {
  check(false, "no mobs to test contact damage");
}

// ---- palette compliance over 120 frames ----
r.env.screen.badColors = [];
for (let i = 0; i < 120; i++) {
  r.env.screen.newFrame();
  r.env.screen.drawCount = 0;
  r.frame();
}
check(r.env.screen.badColors.length === 0, "no palette violations over 120 frames");
const perFrame = r.env.screen.drawCount;
check(perFrame > 1000 && perFrame < 60000, `draw calls per frame in sane range (${perFrame})`);

console.log(failures === 0 ? "ALL GAMEPLAY TESTS PASSED" : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
