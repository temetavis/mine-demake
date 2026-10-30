// Regression test: the game must run WITHOUT any microScript VM warnings.
//
// Guards against:
// - 'X is not defined, will be initialized to an empty object'
//   (assigning_field_to_undefined): computeLight ran on an unbuilt world
//   after a live reload reset lightMap=[] while G.scene survived
// - using_undefined_variable from bare 'null' literals (null is NOT a
//   microScript keyword; it reads an undefined global and warns)
// - using_undefined_variable from optional fields missing on tile defs
//   (0 == null is true, so reading a missing field warns)
// - invoking_non_function when helpers were defined inside defineTiles
//   and called before init ran them

const { MsRunner } = require("../tools/msrun");

let failures = 0;
const check = (cond, label) => {
  console.log(`${cond ? "PASS" : "FAIL"}: ${label}`);
  if (!cond) failures++;
};

function warnCount(r) {
  const w = r.env.microvm.context.warnings;
  let n = 0;
  for (const k of Object.keys(w)) n += Object.keys(w[k]).length;
  return n;
}

// ---- scenario 1: normal play produces ZERO warnings ----
{
  const r = new MsRunner({});
  r.loadSources();
  r.start();
  const g = r.env.globalObj;
  r.env.keyboard.SPACE = 1; r.env.keyboard.press.SPACE = 1;
  r.frame();
  r.env.keyboard.press.SPACE = 0; r.env.keyboard.SPACE = 0;
  // play: walk, mine, open craft menu, place, 200 frames
  r.env.keyboard.RIGHT = 1;
  for (let i = 0; i < 60; i++) r.frame();
  r.env.keyboard.RIGHT = 0;
  r.env.keyboard.X = 1;
  for (let i = 0; i < 30; i++) r.frame();
  r.env.keyboard.X = 0;
  r.env.keyboard.C = 1; r.env.keyboard.press.C = 1;
  r.frame();
  r.env.keyboard.press.C = 0; r.env.keyboard.C = 0;
  for (let i = 0; i < 120; i++) r.frame();
  check(warnCount(r) === 0,
    `normal play has zero warnings (${JSON.stringify(r.env.microvm.context.warnings)})`);
}

// ---- scenario 2: live-reload simulation (update/draw before init) ----
{
  const r = new MsRunner({});
  r.loadSources();
  r.run(); // top-level only: world/lightMap/glyph tables empty
  const g = r.env.globalObj;
  g.G.scene = "play"; // scene survives from the previous session
  r.call("update");
  r.call("draw");
  const w = r.env.microvm.context.warnings;
  check(warnCount(r) === 0,
    `update/draw before init has zero warnings (${JSON.stringify(w)})`);
}

console.log(failures === 0 ? "ALL WARNING TESTS PASSED" : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
