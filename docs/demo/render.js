// Replay a `script` recording in xterm.js, one PNG per frame, with a mouse
// pointer drawn where make.sh clicked. Run by make.sh.
// Usage: node render.js <work dir> <cols> <rows> <fps>
const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer-core");

const [work, cols, rows, fps] = process.argv.slice(2);
const MOVE = 0.7;  // seconds the pointer takes to reach a row before a click

// --log-timing lines are "<delay> <bytes>", or "O <delay> <bytes>" in the multi-stream format
const chunks = [];
let raw = fs.readFileSync(path.join(work, "ts"));
let at = raw.indexOf("\n") + 1;  // after the "Script started" line
let t = 0;
for (const line of fs.readFileSync(path.join(work, "timing"), "utf8").trim().split("\n")) {
  const f = line.split(" ");
  const [delay, n] = f.length === 3 ? [f[1], f[2]] : f;
  if (f.length === 3 && f[0] !== "O") continue;
  t += parseFloat(delay);
  chunks.push({ t, bytes: raw.subarray(at, at + parseInt(n)) });
  at += parseInt(n);
}
const clicks = fs.readFileSync(path.join(work, "clicks"), "utf8").trim().split("\n")
  .map(l => l.split(" ").map(Number)).map(([t, x, y]) => ({ t, x, y }));
const end = clicks[clicks.length - 1].t + 2.5;  // before make.sh detaches the client

// make.sh's fallback fonts, inline: a file:// page can't load fonts from files
const fonts = fs.readdirSync(path.join(work, "fonts")).map(f => `@font-face { font-family: "${path.basename(f, ".font")}";
  src: url(data:application/octet-stream;base64,${fs.readFileSync(path.join(work, "fonts", f)).toString("base64")}); }`).join("\n");
fs.writeFileSync(path.join(work, "index.html"), `<!doctype html><meta charset="utf-8">
<link rel="stylesheet" href="xterm.css"><script src="xterm.js"></script>
<style>
${fonts}
  html, body { margin: 0; background: #1e1f29; }
  #t { padding: 12px 14px; display: inline-block; position: relative; }
  #p { position: absolute; width: 18px; height: 22px; display: none; z-index: 10; }
  #c { position: absolute; width: 26px; height: 26px; margin: -13px; border-radius: 50%;
       border: 2px solid #ffd866; display: none; z-index: 9; }
</style>
<div id="t"><div id="c"></div><svg id="p" viewBox="0 0 18 22"><path d="M1 1 L1 17 L5 13 L8 20 L11 19 L8 12 L14 12 Z"
  fill="#fff" stroke="#000" stroke-width="1.3" stroke-linejoin="round"/></svg></div>
<script>
const term = new Terminal({ cols: ${cols}, rows: ${rows}, fontSize: 14, lineHeight: 1.1,
  fontFamily: '"DejaVu Sans Mono", "Noto Sans Symbols 2", "Noto Sans Symbols", monospace', cursorStyle: "block",
  theme: { background: "#1e1f29", foreground: "#e6e6ef", cursor: "#e6e6ef", cursorAccent: "#1e1f29",
    black: "#21222c", red: "#ff6e6e", green: "#69ff94", yellow: "#ffd866", blue: "#78a9ff",
    magenta: "#ff92df", cyan: "#78dce8", white: "#f8f8f2", brightBlack: "#6272a4" } });
term.open(document.getElementById("t"));
window.feed = b64 => new Promise(done => term.write(Uint8Array.from(atob(b64), c => c.charCodeAt(0)), done));
window.cell = () => {
  const s = document.querySelector(".xterm-screen").getBoundingClientRect();
  const t = document.getElementById("t").getBoundingClientRect();
  return { x: s.left - t.left, y: s.top - t.top, w: s.width / ${cols}, h: s.height / ${rows} };
};
window.pointer = (x, y, ring) => {
  const c = window.cell(), p = document.getElementById("p"), r = document.getElementById("c");
  const px = c.x + (x - 0.5) * c.w, py = c.y + (y - 0.5) * c.h;
  Object.assign(p.style, { display: "block", left: px + "px", top: py + "px" });
  Object.assign(r.style, { display: ring ? "block" : "none", left: px + "px", top: py + "px" });
};
</script>`);

function pointerAt(t) {
  // Starts in the middle of the main pane, glides to each row, rings on the click
  let from = { x: Math.round(cols * 0.45), y: Math.round(rows * 0.55) };
  for (const c of clicks) {
    if (t < c.t - MOVE) return { ...from, ring: false };
    if (t < c.t) {
      const k = (t - (c.t - MOVE)) / MOVE, e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
      return { x: from.x + (c.x - from.x) * e, y: from.y + (c.y - from.y) * e, ring: false };
    }
    if (t < c.t + 0.35) return { x: c.x, y: c.y, ring: true };
    from = c;
  }
  return { ...from, ring: false };
}

(async () => {
  const browser = await puppeteer.launch({ executablePath: "/usr/bin/chromium", args: ["--no-sandbox"] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 800 });
  await page.goto("file://" + path.join(work, "index.html"));
  await page.evaluate(() => Promise.all(["Noto Sans Symbols 2", "Noto Sans Symbols"]
    .map(f => document.fonts.load(`14px "${f}"`, "⏺⎿"))));
  const box = await (await page.$("#t")).boundingBox();
  let next = 0;
  for (let i = 0; i * (1 / fps) <= end; i++) {
    const now = i / fps;
    const due = [];
    while (next < chunks.length && chunks[next].t <= now) due.push(chunks[next++].bytes);
    if (due.length) await page.evaluate(b => window.feed(b), Buffer.concat(due).toString("base64"));
    const p = pointerAt(now);
    await page.evaluate((x, y, r) => window.pointer(x, y, r), p.x, p.y, p.ring);
    await page.screenshot({ path: path.join(work, "frames", String(i).padStart(5, "0") + ".png"), clip: box });
  }
  await browser.close();
})();
