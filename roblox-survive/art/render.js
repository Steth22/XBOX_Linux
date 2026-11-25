const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  for (const [mode, w, h] of [["icon", 512, 512], ["thumb1", 1920, 1080], ["thumb2", 1920, 1080]]) {
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    await p.goto('file://' + __dirname + '/scene.html#' + mode);
    await p.waitForFunction(() => document.title === 'ready', null, { timeout: 15000 }).catch(() => {});
    await p.waitForTimeout(800);
    await p.screenshot({ path: __dirname + `/${mode}.png` });
    await p.close();
  }
  await b.close();
})();
