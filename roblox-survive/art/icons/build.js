// Renders every icon into one transparent sprite sheet (sheet.png + sheet.json) and a tinted preview.
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const icons = require('./icons.js');
const names = Object.keys(icons), CELL = 128, COLS = 8, ROWS = Math.ceil(names.length / COLS);
const svg = (n) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="${CELL - 16}" height="${CELL - 16}">${icons[n]}</svg>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: COLS * CELL, height: ROWS * CELL } });
  const cells = names.map((n, i) => `<div style="position:absolute;left:${(i % COLS) * CELL + 8}px;top:${Math.floor(i / COLS) * CELL + 8}px">${svg(n)}</div>`).join('');
  await p.setContent(`<html><body style="margin:0;background:transparent">${cells}</body></html>`);
  await p.screenshot({ path: path.join(__dirname, 'sheet.png'), omitBackground: true });
  const map = {}; names.forEach((n, i) => map[n] = [(i % COLS) * CELL, Math.floor(i / COLS) * CELL]);
  fs.writeFileSync(path.join(__dirname, 'sheet.json'), JSON.stringify({ cell: CELL, map }));
  // preview: each icon tinted on a dark card with its name
  const colors = ['#ffd35a', '#7ee08a', '#ff7a6a', '#8ecbff', '#e9edf2', '#c9a0ff'];
  const prev = names.map((n, i) => `<div style="display:inline-block;width:120px;height:130px;margin:6px;background:#22282f;border-radius:14px;text-align:center;font:12px sans-serif;color:#9aa">
    <div style="width:72px;height:72px;margin:12px auto 6px;color:${colors[i % colors.length]}">${svg(n).replace(/#fff/g, 'currentColor').replace(/width="\d+" height="\d+"/, 'width="72" height="72"')}</div>${n}</div>`).join('');
  const p2 = await b.newPage({ viewport: { width: 1100, height: 760 } });
  await p2.setContent(`<html><body style="margin:10px;background:#14181d">${prev}</body></html>`);
  await p2.screenshot({ path: path.join(__dirname, 'preview.png'), fullPage: true });
  await b.close();
  console.log('icons:', names.length, 'sheet', COLS * CELL, 'x', ROWS * CELL);
})();
