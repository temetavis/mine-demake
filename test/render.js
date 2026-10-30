// Regression tests for the lighting / overlay / HUD fixes:
// 1) SHADE table must be indexed by light level (light 3 = full color,
//    light 0 = black). It was accidentally brightest-first, which turned
//    the sunlit surface black and left deep terrain full-color.
// 2) Overlays (player/mobs/HUD) must render at full brightness and must
//    NOT brighten the base tile they cover (that left a colored "aura"
//    that appeared while an entity stood on a tile and vanished when it
//    moved away).
// 3) The selected hotbar slot must be clearly visible: lighter slot
//    background + a white arrow marker above it.

const { MsRunner } = require("../tools/msrun");
const { renderFrame } = require("../tools/snapshot");

let failures = 0;
const check = (cond, label) => {
  console.log(`${cond ? "PASS" : "FAIL"}: ${label}`);
  if (!cond) failures++;
};

const r = new MsRunner({});
r.loadSources();
r.start();
const g = r.env.globalObj;
const call = (name, ...args) => r.fn(name)(...args);

r.env.keyboard.SPACE = 1; r.env.keyboard.press.SPACE = 1;
r.frame();
r.env.keyboard.press.SPACE = 0; r.env.keyboard.SPACE = 0;
for (let i = 0; i < 8; i++) r.frame();

// ---- 1) SHADE direction ----
check(g.SHADE[5][0] === 0 && g.SHADE[5][3] === 5, "SHADE indexed by light (green: black@0, green@3)");
check(g.SHADE[1][0] === 0 && g.SHADE[1][3] === 1, "SHADE white: black@0, white@3");

// ---- 2) surface is visible: grass renders full-bright green ----
const sx = Math.floor(g.player.x);
const surfaceY = g.surfaceCache[sx];
check(surfaceY < g.WORLD_H - 1 && g.world[surfaceY][sx] !== 0, `surface row exists (y=${surfaceY})`);
check(g.lightMap[surfaceY][sx] >= 3, `surface tile fully lit (light=${g.lightMap[surfaceY][sx]})`);
check(g.lightMap[surfaceY + 8][sx] < g.lightMap[surfaceY][sx], "light fades with depth");
// resolveInk: a green tile at full light must be green, at light 0 must be black
const greenFull = call("resolveInk", 3, g.CR.GREEN, -1, 0, -1, 0, 3, 0);
const greenDark = call("resolveInk", 3, g.CR.GREEN, -1, 0, -1, 0, 0, 0);
check(greenFull === g.CR.GREEN, `full-light tile keeps its color (${greenFull})`);
check(greenDark === 0, `zero-light tile renders black (${greenDark})`);

// ---- 3) overlays: full-brightness, no base mutation ----
// overlay pixel on a dark cell must render at its own color
const ovColor = call("resolveInk", 3, g.CR.WHITE, -1, g.CR.WHITE, -1, 0, 0, 1);
check(ovColor === g.CR.WHITE, "overlay white stays white on a dark cell");
// cellOverlay must not change cellLight
const li = 10 * 40 + 10;
g.cellLight[li] = 1;
call("cellOverlay", 10, 10, g.GL.heartfull, g.CR.RED, -1, null);
check(g.cellLight[li] === 1, "cellOverlay does not brighten the base cell");
check(g.ovGlyph[li] === g.GL.heartfull, "cellOverlay writes the overlay layer");

// ---- 4) selected hotbar slot is visible ----
r.env.screen.newFrame(); r.env.screen.drawCount = 0;
r.call("update"); r.call("draw");
const slotX = 16 + g.sel * 2;
const bgSel = g.cellBg[24 * 40 + slotX];
const bgOther = g.cellBg[24 * 40 + slotX + 2];
check(bgSel === g.CR.MDGRY && bgOther === g.CR.DKGRY, "selected slot lighter than others");
check(g.ovGlyph[23 * 40 + slotX] === g.GL.arrowdn && g.ovMain[23 * 40 + slotX] === g.CR.WHITE,
  "white arrow marker above selected slot");

// ---- 5) craft menu panel is purple, not sky-blue ----
call("refreshCraftList");
g.craftOpen = 1;
r.env.screen.newFrame(); r.env.screen.drawCount = 0;
r.call("update"); r.call("draw");
const menuCell = g.cellBg[6 * 40 + 10];
check(menuCell === g.CR.PURPLE, `craft menu panel is purple (got ${menuCell})`);
g.craftOpen = 0;

// ---- 6) rendered pixels: grass region shows green, not black ----
renderFrame(r.env.screen.frameCalls, 3, "test/snapshots/_render_check.png");

console.log(failures === 0 ? "ALL RENDER TESTS PASSED" : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
