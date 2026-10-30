// Regression test: the game must work no matter what order microStudio
// loads the source files in. microStudio's player executes sources in
// NETWORK-ARRIVAL order (see static/js/play/player.js in the microStudio
// repo: each file is fetched with XHR and stored as it arrives, then
// Runtime runs them in object-key insertion order) - NOT alphabetical.
//
// Bug this guards against: top-level data construction (tiledef/itemdef/
// recipedef calls referencing T, I, GL, CR from other files) breaking when
// a later-numbered file arrives first ("recipedef is not a function").
// All cross-file setup must live in init(), which runs after every file.

const { MsRunner } = require("../tools/msrun");

let failures = 0;
const check = (cond, label) => {
  console.log(`${cond ? "PASS" : "FAIL"}: ${label}`);
  if (!cond) failures++;
};

function scenario(order, label) {
  const r = new MsRunner({});
  r.loadSources(null, order);
  r.start();
  const g = r.env.globalObj;
  // data tables fully built?
  const tables = g.TILES.length === 19 && g.RECIPES.length === 10;
  // crafting works: give wood, planks must become craftable
  r.env.keyboard.SPACE = 1; r.env.keyboard.press.SPACE = 1;
  r.frame();
  r.env.keyboard.press.SPACE = 0; r.env.keyboard.SPACE = 0;
  r.fn("giveItem")(11, 2);
  r.fn("refreshCraftList")();
  const planks = g.craftList.some((rc) => rc.out === 13);
  r.fn("doCraft") && g.craftSel === 0; // craft planks (first in list)
  g.craftSel = g.craftList.findIndex((rc) => rc.out === 13);
  r.fn("doCraft")();
  const gotPlanks = g.inv.some((s) => s.id === 13);
  check(tables && planks && gotPlanks && g.G.scene === "play",
    `${label}: tables + crafting work (tiles=${g.TILES.length}, recipes=${g.RECIPES.length})`);
}

scenario({ reverse: true }, "reverse order (5_game first)");
scenario({ shuffle: true }, "shuffled order #1");
scenario({ shuffle: true }, "shuffled order #2");
scenario({ shuffle: true }, "shuffled order #3");

console.log(failures === 0 ? "ALL LOAD-ORDER TESTS PASSED" : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
