const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const set = require('./medals.js');
const names = Object.keys(set), CELL = 256, COLS = 5, ROWS = Math.ceil(names.length / COLS);
const svg = (s, size) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="${size}" height="${size}">${s}</svg>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: COLS * CELL, height: ROWS * CELL } });
  await p.setContent(`<html><body style="margin:0;background:transparent">${names.map((n, i) => `<div style="position:absolute;left:${(i % COLS) * CELL}px;top:${Math.floor(i / COLS) * CELL}px">${svg(set[n], CELL)}</div>`).join('')}</body></html>`);
  await p.screenshot({ path: path.join(__dirname, 'medals.png'), omitBackground: true });
  const map = {}; names.forEach((n, i) => map[n] = [(i % COLS) * CELL, Math.floor(i / COLS) * CELL]);
  fs.writeFileSync(path.join(__dirname, 'medals.json'), JSON.stringify({ cell: CELL, map }));
  await p.setContent(`<html><body style="margin:0;background:#1b2226">${names.map((n, i) => `<div style="position:absolute;left:${(i % COLS) * CELL}px;top:${Math.floor(i / COLS) * CELL}px">${svg(set[n], CELL)}</div>`).join('')}</body></html>`);
  await p.screenshot({ path: path.join(__dirname, 'preview.png') });
  await b.close();
})();
