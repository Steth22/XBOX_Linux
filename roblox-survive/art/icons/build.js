// Renders the colour icons and the white UI glyphs into one transparent sheet + a preview.
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const set = require('./icons.js');
const all = [...Object.entries(set.colour).map(([n, s]) => [n, s, false]), ...Object.entries(set.mono).map(([n, s]) => [n, s, true])];
const CELL = 128, COLS = 8, ROWS = Math.ceil(all.length / COLS);
const svg = (s, size) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="${size}" height="${size}">${s}</svg>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: COLS * CELL, height: ROWS * CELL } });
  await p.setContent(`<html><body style="margin:0;background:transparent">${all.map(([n, s], i) => `<div style="position:absolute;left:${(i % COLS) * CELL + 8}px;top:${Math.floor(i / COLS) * CELL + 8}px">${svg(s, CELL - 16)}</div>`).join('')}</body></html>`);
  await p.screenshot({ path: path.join(__dirname, 'sheet.png'), omitBackground: true });
  const map = {}; all.forEach(([n, , mono], i) => map[n] = [(i % COLS) * CELL, Math.floor(i / COLS) * CELL, mono]);
  fs.writeFileSync(path.join(__dirname, 'sheet.json'), JSON.stringify({ cell: CELL, map }));
  const prev = all.map(([n, s, mono]) => `<div style="display:inline-block;width:120px;height:130px;margin:6px;background:#22282f;border-radius:14px;text-align:center;font:12px sans-serif;color:#9aa">
    <div style="width:72px;height:72px;margin:12px auto 6px">${svg(s, 72)}</div>${n}${mono ? ' (UI)' : ''}</div>`).join('');
  const p2 = await b.newPage({ viewport: { width: 1100, height: 700 } });
  await p2.setContent(`<html><body style="margin:10px;background:#14181d">${prev}</body></html>`);
  await p2.screenshot({ path: path.join(__dirname, 'preview.png'), fullPage: true });
  await b.close();
  console.log('icons:', all.length);
})();
