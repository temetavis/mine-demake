// Renders the mock screen's draw-call log to a PNG snapshot.
// The game draws its 320x200 virtual screen centered via fillRect calls in
// logical screen space (center origin, y-up). This rasterizer replays those
// calls with the same nearest-neighbor semantics as the browser canvas.

const { encodePng } = require("./pngcodec");
const { PALETTE_RGB } = require("./msrun");

const W = 320;
const H = 200;

// map palette hex -> index
const PAL = {};
PALETTE_RGB.forEach((rgb, i) => {
  PAL["#" + rgb.map((v) => v.toString(16).padStart(2, "0")).join("")] = i;
});

function renderFrame(calls, scale = 3, file) {
  const img = Buffer.alloc(W * H * 4, 0);
  img.fill(255, 0, W * H * 4 - W * H); // fully black with alpha
  for (let i = 3; i < W * H * 4; i += 4) img[i] = 255;
  const setPx = (x, y, color) => {
    if (x < 0 || y < 0 || x >= W || y >= H) return;
    const o = (y * W + x) * 4;
    img[o] = color[0]; img[o + 1] = color[1]; img[o + 2] = color[2];
  };
  // logical -> virtual pixel: virtual screen is 320x200 centered at (0,0)
  const toPx = (x, y) => [Math.round(x + W / 2), Math.round(-y + H / 2)];
  for (const call of calls) {
    if (call[0] === "fillRect") {
      const [, x, y, w, h, color] = call;
      const c = PAL[String(color).toLowerCase()];
      if (!c && c !== 0) continue;
      const rgb = PALETTE_RGB[c];
      const [cx, cy] = toPx(x, y);
      const x0 = cx - w / 2, x1 = cx + w / 2;
      const y0 = cy - h / 2, y1 = cy + h / 2;
      for (let py = Math.floor(y0); py < Math.ceil(y1); py++) {
        for (let px = Math.floor(x0); px < Math.ceil(x1); px++) {
          setPx(px, py, rgb);
        }
      }
    } else if (call[0] === "clear") {
      const c = PAL[String(call[1]).toLowerCase()];
      const rgb = c === undefined ? [0, 0, 0] : PALETTE_RGB[c];
      for (let i = 0; i < W * H; i++) {
        const o = i * 4;
        img[o] = rgb[0]; img[o + 1] = rgb[1]; img[o + 2] = rgb[2];
      }
    }
  }
  if (scale > 1) {
    const scaled = Buffer.alloc(W * scale * H * scale * 4);
    for (let y = 0; y < H * scale; y++) {
      const sy = Math.floor(y / scale);
      for (let x = 0; x < W * scale; x++) {
        const sx = Math.floor(x / scale);
        const s = (sy * W + sx) * 4;
        const d = (y * W * scale + x) * 4;
        scaled[d] = img[s]; scaled[d + 1] = img[s + 1]; scaled[d + 2] = img[s + 2]; scaled[d + 3] = 255;
      }
    }
    if (file) encodePng(scaled, W * scale, H * scale, file);
    return scaled;
  }
  if (file) encodePng(img, W, H, file);
  return img;
}

module.exports = { renderFrame };
