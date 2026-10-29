// Drives the game headlessly through a scripted play session and saves
// PNG snapshots for visual inspection. Also asserts palette compliance.

const fs = require("fs");
const path = require("path");
const { MsRunner } = require("../tools/msrun");
const { renderFrame } = require("../tools/snapshot");

const ROOT = path.resolve(__dirname, "..");
const SNAP = path.join(ROOT, "test", "snapshots");
fs.mkdirSync(SNAP, { recursive: true });

const r = new MsRunner({});
r.loadSources();
r.start();

const key = (k) => {
  r.env.keyboard[k] = 1;
};
const unkey = (k) => {
  r.env.keyboard[k] = 0;
};
const press = (k) => {
  key(k);
  r.env.keyboard.press[k] = 1;
  r.frame();
  r.env.keyboard.press[k] = 0;
  unkey(k);
};

function snap(name, n = 1) {
  for (let i = 1; i < n; i++) r.frame();
  // one clean frame: update then draw, capturing this frame's calls
  r.env.screen.newFrame();
  r.env.screen.drawCount = 0;
  r.call("update");
  r.call("draw");
  const count = r.env.screen.drawCount;
  renderFrame(r.env.screen.frameCalls, 3, path.join(SNAP, name + ".png"));
  console.log(`snapshot ${name}: ${count} draw calls`);
  return count;
}

function assertPalette() {
  const bad = r.env.screen.badColors;
  if (bad.length) {
    console.error("PALETTE VIOLATIONS:", JSON.stringify(bad.slice(0, 10)));
    process.exit(1);
  }
  console.log("palette OK — colors used:", [...r.env.screen.allColors].length, "of 16");
}

// ---- title screen ----
snap("01_title", 1);
assertPalette();

// start game
press("SPACE");
snap("02_game_start", 5);
assertPalette();

// walk right for 2 seconds, snapshots along the way
key("RIGHT");
snap("03_walk_right", 60);
snap("04_walk_right2", 60);
assertPalette();
unkey("RIGHT");

// face right and mine the tile in front (hold X)
key("X");
snap("05_mining", 40);
assertPalette();
unkey("X");

const inv0 = JSON.parse(JSON.stringify(r.env.globalObj.inv));
console.log("inventory:", inv0.map((s) => `${s.id}x${s.count}`).join(", "));
const px = r.env.globalObj.player.x;
const py = r.env.globalObj.player.y;
console.log("player pos:", px.toFixed(2), py.toFixed(2));
const scene = r.env.globalObj.G.scene;
console.log("scene:", scene);
if (scene !== "play") { console.error("FAIL: not in play scene"); process.exit(1); }

// run 10 seconds total to exercise lighting, mobs, particles
let maxDraw = 0;
for (let i = 0; i < 600; i++) {
  r.env.screen.newFrame();
  r.env.screen.drawCount = 0;
  maxDraw = Math.max(maxDraw, r.frame());
}
console.log("600 frames OK; max draw calls in one frame:", maxDraw);
assertPalette();
snap("06_late_game", 1);

// verify framebuffer state sanity
const g = r.env.globalObj;
console.log("world size:", g.world.length, "x", g.world[0].length);
console.log("light computed:", g.lightDirty === 0 ? "yes" : "no (dirty)");
const lit = g.lightMap.reduce((a, row) => a + row.reduce((b, v) => b + (v > 0 ? 1 : 0), 0), 0);
console.log("lit tiles:", lit);
if (lit === 0) { console.error("FAIL: no light anywhere"); process.exit(1); }
console.log("ALL PLAY TESTS PASSED");
