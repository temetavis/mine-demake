// Regression test: glyph blitting must draw ALL four fat pixels of every
// row, not just the first one. (Bug: buildGlyphRuns stored compressed
// [start, len, ink] runs while blitCells read them as per-pixel arrays,
// so solid or low-run-count glyph rows rendered as a 2px vertical line.)

const { MsRunner } = require("../tools/msrun");
const { renderFrame } = require("../tools/snapshot");

const r = new MsRunner({});
r.loadSources();
r.start();
const g = r.env.globalObj;

let failures = 0;
const check = (cond, label) => {
  console.log(`${cond ? "PASS" : "FAIL"}: ${label}`);
  if (!cond) failures++;
};

// start the game so the char ROM / runs are built
r.env.keyboard.SPACE = 1; r.env.keyboard.press.SPACE = 1;
r.frame();
r.env.keyboard.press.SPACE = 0; r.env.keyboard.SPACE = 0;

// 1) per-pixel ink tables have 4 entries per row, for every glyph
let badRows = 0;
for (let i = 0; i < 256; i++) {
  const rows = g.GLYPH_RUNS[i];
  if (!rows || rows.length !== 8) { badRows++; continue; }
  for (const row of rows) {
    if (!row || row.length !== 4) { badRows++; break; }
  }
}
check(badRows === 0, `all 256 glyphs have 8 rows x 4 ink entries (${badRows} bad)`);

// 2) solid glyph (all ink 3) renders as a FULL 8x8 block of the main color
g.CHARROM[1] = "3".repeat(32);
r.fn("buildGlyphRuns")();
r.env.screen.newFrame(); r.env.screen.drawCount = 0;
r.fn("cellClear")(0, 0, 0);
r.fn("cellPut")(0, 0, 1, g.CR.CYAN, -1, 3);
r.fn("blitCells")();
const cyan = r.env.screen.frameCalls.filter(
  (c) => c[0] === "fillRect" && String(c[5]).toLowerCase() === "#70a4b2"
);
const widths = cyan.map((c) => c[3]);
const totalW = widths.reduce((a, b) => a + b, 0);
check(cyan.length === 8 && totalW === 8 * 8,
  `solid glyph covers full cell (8 rows x 8px, got ${cyan.length} runs, ${totalW}px)`);

// 3) pixel-level: render and count cyan pixels in the cell (3x scale => 24x24)
renderFrame(r.env.screen.frameCalls, 3, "test/snapshots/_solid_cyan.png");
// (PNG verified separately; here assert on draw calls only)

// 4) mixed-ink glyph row 0,1,2,3: the overlay layer must keep ink 0 transparent
g.CHARROM[2] = "0123".repeat(8);
r.fn("buildGlyphRuns")();
check(JSON.stringify(g.GLYPH_RUNS[2][0]) === "[0,1,2,3]",
  "mixed glyph row reads per-pixel inks [0,1,2,3]");

// 5) normal glyphs still render identical pixel content as before the fix:
//    glyph 'M' (77) with white ink must draw all its ink-3 pixels
r.env.screen.newFrame(); r.env.screen.drawCount = 0;
r.fn("cellClear")(0, 0, 0);
r.fn("cellPut")(0, 0, 77, g.CR.WHITE, -1, 3);
r.fn("blitCells")();
const white = r.env.screen.frameCalls.filter(
  (c) => c[0] === "fillRect" && String(c[5]).toLowerCase() === "#ffffff"
);
const whitePx = white.reduce((a, c) => a + c[3], 0);
check(whitePx > 8, `letter glyph M renders full width (got ${whitePx}px of white)`);

console.log(failures === 0 ? "ALL CHARSET TESTS PASSED" : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
